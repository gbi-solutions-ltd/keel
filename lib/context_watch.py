#!/usr/bin/env python3
"""Measure how full a session's context window is, and write a handoff when it is nearly gone.

Why this is not guesswork. Claude Code writes a JSONL transcript per session, and every assistant
entry carries the usage the API reported for that request. The size of the last request is what the
context window actually held, so occupancy is read rather than estimated:

    input_tokens + cache_creation_input_tokens + cache_read_input_tokens + output_tokens

The cache fields are the important ones and the easy ones to miss. On a long session `input_tokens`
is routinely 1, because everything before the last message is a cache read. A watchdog that looked
only at `input_tokens` would report a session at 99% of its window as using one token.

Sidechain entries are excluded. A subagent runs in its own context that is discarded when it
returns, so counting its usage would report the main thread as full because a subagent read twenty
files, which is the opposite of what delegation does.

All I/O is here and it is confined to two paths: the transcript, which is read, and the handoff,
which is written. Nothing reaches the network, and there is no branch that runs a command.
"""

import json
import os
import sys
import time

DEFAULT_WINDOW = 200_000
LONG_WINDOW = 1_000_000


def _entries(path):
    """Yield parsed transcript entries, skipping anything unparseable.

    A partially written last line is normal: the hook fires while the session is still appending to
    this file. Skipping a bad line is correct here, where raising would take down a hook that runs
    on every prompt.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    yield json.loads(line)
                except ValueError:
                    continue
    except OSError:
        return


TAIL_BYTES = 512 * 1024


def _tail_entries(path):
    """Parse only the end of the transcript.

    `measure` runs on every prompt and, at the stop threshold, on tool calls. Parsing a multi-megabyte
    transcript each time would make the watchdog the slowest thing in the session, which is a good way
    to have it turned off. The last assistant turn is by definition at the end of the file, so read
    the last chunk and drop the first line, which is almost certainly cut in half.
    """
    try:
        size = os.path.getsize(path)
    except OSError:
        return None
    if size <= TAIL_BYTES:
        return None
    try:
        with open(path, "rb") as fh:
            fh.seek(size - TAIL_BYTES)
            chunk = fh.read()
    except OSError:
        return None
    out = []
    for line in chunk.split(b"\n")[1:]:
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line.decode("utf-8", "replace")))
        except ValueError:
            continue
    return out


def measure(path):
    """Return (tokens, model) for the most recent main-thread assistant turn, or (0, "")."""
    tail = _tail_entries(path)
    if tail is not None:
        tokens, model = _measure_over(tail)
        if tokens:
            return tokens, model
        # No usable turn in the tail. Fall through to the whole file rather than report zero, which
        # would read as an empty context and silence the watchdog exactly when it is needed.
    return _measure_over(_entries(path))


def _measure_over(entries):
    tokens, model = 0, ""
    for d in entries:
        if d.get("type") != "assistant" or d.get("isSidechain"):
            continue
        msg = d.get("message")
        if not isinstance(msg, dict):
            continue
        usage = msg.get("usage")
        if not isinstance(usage, dict):
            continue
        tokens = (
            usage.get("input_tokens", 0)
            + usage.get("cache_creation_input_tokens", 0)
            + usage.get("cache_read_input_tokens", 0)
            + usage.get("output_tokens", 0)
        )
        model = msg.get("model") or model
    return tokens, model


def _positive_int(value):
    """The value as a positive int, or None when it is not one.

    Both sources are read here and neither is normalised before it arrives: a profile carries an
    int, an environment variable carries a string. `bool` is excluded deliberately, because it is
    an `int` in Python and `True` would otherwise be read as a one token window.
    """
    if isinstance(value, bool):
        return None
    if isinstance(value, int) and value > 0:
        return value
    if isinstance(value, str) and value.isdigit() and int(value) > 0:
        return int(value)
    return None


def window_for(model, observed=0, configured=None):
    """The context window this session is working against.

    There is no reliable way to read this. A real 1M session records its model as `claude-opus-5`,
    with no marker, and no field in the transcript carries the window. That was found by running this
    against a real 2.4MB transcript holding 401,247 tokens, which the first version of this function
    reported as 200% of a 200,000 window. A watchdog that reports 200% hard-stops the session
    immediately and never lifts, on exactly the sessions with the most room left.

    So, in order:

    1. `KEEL_CONTEXT_WINDOW` wins over everything below, and is used as set apart from the bound in
       step 5. It is the deliberate override: the test suite uses it to force a small window, and a
       session that knows better can do the same. Nothing raises it, and only the bound lowers it.
    2. Observation beats assumption. Occupancy above a tier is proof the window is larger, since the
       API would have refused the request otherwise. This can only correct upward, so it never
       invents room that is not there.
    3. `gates.context_window` is a floor, not a ceiling. It raises the starting point, and step 2
       may raise it further still. It was a ceiling until 2026-08-18, which is why `keel init` did
       not dare write one: a conservative value would have hard-stopped every larger session at 85%
       of it, permanently, with editing the file the only escape. Being a floor, it cannot lower the
       window below the default either: `KEEL_CONTEXT_WINDOW` is the way to force a smaller one, and
       `keel doctor` says so when a profile sets one that is too small to take effect.
    4. Otherwise the model string, then the conservative default.
    5. Nothing above LONG_WINDOW is returned, from any source. It is the largest context window any
       current model offers, checked 2026-08-18, and already the highest value step 2 can reach, so
       the bound adds no ceiling the observed path did not have. A mistyped extra zero is caught
       rather than silencing the watchdog for the life of the project. When a larger model ships,
       this constant moves and both paths follow.

    The residual error is now the other way round: a configured window larger than the true one
    cannot be corrected downward, because occupancy proves a lower bound and never an upper one.
    """
    env = _positive_int(os.environ.get("KEEL_CONTEXT_WINDOW", "").strip())
    if env is not None:
        return min(env, LONG_WINDOW)

    window = LONG_WINDOW if "1m" in (model or "").lower() else DEFAULT_WINDOW
    if observed > window:
        window = LONG_WINDOW

    floor = _positive_int(configured)
    if floor is not None and floor > window:
        window = floor
    return min(window, LONG_WINDOW)


def _text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(
            b.get("text", "") for b in content
            if isinstance(b, dict) and b.get("type") == "text"
        )
    return ""


def _collect(path):
    """What a mechanical handoff can know without asking the model anything."""
    prompts, files, last_reply = [], [], ""
    for d in _entries(path):
        if d.get("isSidechain"):
            continue
        msg = d.get("message")
        if not isinstance(msg, dict):
            continue
        if d.get("type") == "user":
            text = _text_of(msg.get("content")).strip()
            # A tool result arrives as a user entry with no text of its own. It is not a prompt.
            if text and not text.startswith("<"):
                prompts.append(text)
        elif d.get("type") == "assistant":
            content = msg.get("content")
            text = _text_of(content).strip()
            if text:
                last_reply = text
            if isinstance(content, list):
                for b in content:
                    if not isinstance(b, dict) or b.get("type") != "tool_use":
                        continue
                    if b.get("name") in ("Edit", "Write", "NotebookEdit"):
                        fp = (b.get("input") or {}).get("file_path")
                        if fp and fp not in files:
                            files.append(fp)
    return prompts, files, last_reply


def _trim(s, n):
    s = " ".join(s.split())
    return s if len(s) <= n else s[: n - 1] + "…"


def render_handoff(path, session_id, tokens, window):
    """The facts a resumed session needs, and nothing it can rederive cheaply.

    Deliberately short. A handoff that reproduces the conversation costs the next session the
    context this one just ran out of, which defeats the purpose of stopping.
    """
    prompts, files, last_reply = _collect(path)
    pct = round(100.0 * tokens / window, 1) if window else 0.0
    out = [
        "# Session handoff",
        "",
        "Written mechanically by the keel context watchdog. It records what can be read from",
        "the transcript. Anything that needed judgement, the state of the work and what comes next,",
        "is added by whoever was in the session.",
        "",
        "| | |",
        "|---|---|",
        "| Session | `%s` |" % (session_id or "unknown"),
        "| Context at handoff | %s of %s tokens, %s%% |" % (f"{tokens:,}", f"{window:,}", pct),
        "",
        "## What was asked",
        "",
    ]
    for p in prompts[-5:]:
        out.append("- %s" % _trim(p, 300))
    if not prompts:
        out.append("- Nothing recorded.")
    out += ["", "## Files this session wrote", ""]
    if files:
        out += ["- `%s`" % f for f in files[-30:]]
    else:
        out.append("- None.")
    out += [
        "",
        "## Where it got to",
        "",
        _trim(last_reply, 1200) or "Nothing recorded.",
        "",
        "## Still to do",
        "",
        "TO BE COMPLETED BEFORE STOPPING. State what is unfinished, what the next step is, and any",
        "decision taken that is not yet written down anywhere else. Without this the next session",
        "re-derives it, which costs more than the pause saved.",
        "",
        "## Before this file is discarded",
        "",
        "This file is git-ignored session state, and it is stale the moment work resumes. Anything in",
        "it that outlives the session moves to its real home first: a decision to an ADR under",
        "`decisions/` in the docs root, anything else to the artifact it belongs to. What is left",
        "only here is lost.",
        "",
    ]
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- the hook

WARN_PCT = 70
STOP_PCT = 85

# Writing the handoff needs to read a little and write a little. Denying these at the stop threshold
# would leave the session unable to do the one thing it is being told to do, which is a deadlock
# dressed as a safety feature.
ALWAYS_ALLOWED = {"Write", "Edit", "NotebookEdit", "Read", "TodoWrite", "TaskUpdate", "TaskCreate"}

# Re-measuring on every single tool call would parse the transcript dozens of times a minute for a
# number that moves slowly. Twenty seconds is short enough that the stop lands within one exchange.
CACHE_SECONDS = 20


def _state_dir():
    d = os.path.join(os.environ.get("TMPDIR", "/tmp"), "keel-context-watch")
    try:
        os.makedirs(d, exist_ok=True)
    except OSError:
        return None
    return d


def _profile(cwd):
    try:
        with open(os.path.join(cwd or ".", ".keel", "profile.json"), encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def _thresholds(profile):
    gates = profile.get("gates") or {}

    def pick(env, key, default):
        v = os.environ.get(env, "").strip()
        if v.isdigit():
            return int(v)
        v = gates.get(key)
        return v if isinstance(v, int) else default

    return pick("KEEL_CONTEXT_WARN", "context_warn_pct", WARN_PCT), \
        pick("KEEL_CONTEXT_STOP", "context_stop_pct", STOP_PCT)


def _cached_measure(path, session_id, configured=None):
    """(tokens, window, pct), from a recent cache where one exists."""
    d = _state_dir()
    cache = os.path.join(d, "%s.measure" % (session_id or "nosession")) if d else None
    now = int(time.time())
    if cache and os.path.exists(cache):
        try:
            with open(cache, encoding="utf-8") as fh:
                ts, tok, win = (int(x) for x in fh.read().split())
            if now - ts < CACHE_SECONDS:
                return tok, win, (int(100 * tok / win) if win else 0)
        except (OSError, ValueError):
            pass
    tokens, model = measure(path)
    window = window_for(model, observed=tokens, configured=configured)
    if cache:
        try:
            with open(cache, "w", encoding="utf-8") as fh:
                fh.write("%d %d %d" % (now, tokens, window))
        except OSError:
            pass
    return tokens, window, (int(100 * tokens / window) if window else 0)


def _emit(payload):
    print(json.dumps(payload))


def hook():
    """Read one hook event on stdin and answer it.

    Silent below the warn threshold, and that is the whole cost argument. An ordinary session pays
    nothing: no output means nothing enters the conversation and nothing is invalidated. What the
    hook does emit is appended after everything cached, so it never disturbs the prompt prefix. See
    docs/05.
    """
    try:
        ev = json.load(sys.stdin)
    except ValueError:
        return 0
    if os.environ.get("KEEL_CONTEXT_WATCH", "").lower() in ("off", "0", "false"):
        return 0

    event = ev.get("hook_event_name") or ""
    transcript = ev.get("transcript_path") or ""
    session = ev.get("session_id") or ""
    cwd = ev.get("cwd") or os.getcwd()
    if not transcript or not os.path.exists(transcript):
        return 0

    profile = _profile(cwd)
    if (profile.get("gates") or {}).get("context_watch") is False:
        return 0
    # Deliberately not under docs_root. A handoff is session state, not project knowledge, and it is
    # stale the moment work resumes. Inside the docs tree it is a committed file that `git add -A`
    # sweeps into the next commit; beside the profile it is keel's own state, and git-ignored.
    handoff = os.path.join(cwd, ".keel", "handoff.md")
    warn_at, stop_at = _thresholds(profile)

    tokens, window, pct = _cached_measure(
        transcript, session, configured=(profile.get("gates") or {}).get("context_window"))
    if not tokens:
        return 0

    if event == "PreCompact":
        # Compaction is the one moment the session's own memory is about to be rewritten, so capture
        # what is still readable first. Cheap, silent, and it costs nothing if never used.
        try:
            os.makedirs(os.path.dirname(handoff), exist_ok=True)
            with open(handoff, "w", encoding="utf-8") as fh:
                fh.write(render_handoff(transcript, session, tokens, window))
            _emit({"systemMessage": "keel wrote a mechanical handoff to %s before compacting."
                                    % os.path.relpath(handoff, cwd)})
        except OSError:
            pass
        return 0

    stopped = _stop_marker(session, pct >= stop_at)

    if event == "UserPromptSubmit":
        if pct >= stop_at:
            _emit({"hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": _stop_text(pct, tokens, window, os.path.relpath(handoff, cwd)),
            }})
        elif pct >= warn_at:
            _emit({"hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": _warn_text(pct, stop_at, os.path.relpath(handoff, cwd)),
            }})
        return 0

    if event == "PreToolUse":
        if pct < stop_at:
            return 0
        if (ev.get("tool_name") or "") in ALWAYS_ALLOWED:
            return 0
        # Once the handoff has been refreshed since the stop fired, the session has done what it was
        # asked and is let go. Without this the stop is a wall rather than a pause, and a wall is
        # what makes people set KEEL_CONTEXT_WATCH=off permanently.
        if stopped and os.path.exists(handoff):
            try:
                if os.path.getmtime(handoff) >= os.path.getmtime(stopped):
                    return 0
            except OSError:
                pass
        _emit({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": _stop_text(pct, tokens, window, os.path.relpath(handoff, cwd)),
        }})
        return 0

    return 0


def _stop_marker(session, active):
    """Path of the marker recording when the stop first fired, or None."""
    d = _state_dir()
    if not d:
        return None
    p = os.path.join(d, "%s.stop" % (session or "nosession"))
    if active and not os.path.exists(p):
        try:
            with open(p, "w", encoding="utf-8") as fh:
                fh.write("stop\n")
        except OSError:
            return None
    return p if os.path.exists(p) else None


def _warn_text(pct, stop_at, handoff):
    return (
        "Context is at %d%% of this session's window. At %d%% keel will pause the session.\n"
        "Prefer finishing the current step over starting a new one, and delegate wide reading to a "
        "subagent so its tokens land in a context that is discarded rather than this one.\n"
        "Nothing is required yet. The handoff, when it is needed, goes to %s."
        % (pct, stop_at, handoff)
    )


def _stop_text(pct, tokens, window, handoff):
    return (
        "PAUSE. Context is at %d%% (%s of %s tokens), past the keel stop threshold.\n"
        "\n"
        "Do these, in order, and nothing else:\n"
        "  1. Write or refresh %s: what is done, what is not, the next concrete step, and any\n"
        "     decision taken that is not yet recorded anywhere else.\n"
        "  2. Move anything durable out of it and into its real home, an ADR under the docs root or\n"
        "     the artifact it belongs to. That file is git-ignored and is thrown away once the work\n"
        "     resumes, so decisions left only in it are lost.\n"
        "  3. Tell the user to run /clear and resume by pointing at that file.\n"
        "  4. Stop.\n"
        "\n"
        "Write, Edit and Read still work so you can do this. Other tools are refused until the\n"
        "handoff is written. Continuing past here means the session is compacted mid-task and the\n"
        "reasoning that got you here is summarised away.\n"
        "\n"
        "If this is genuinely wrong, the user can set KEEL_CONTEXT_WATCH=off, or gates.context_watch\n"
        "to false in .keel/profile.json. Do not set either yourself: it is the user's call."
        % (pct, f"{tokens:,}", f"{window:,}", handoff)
    )


def main(argv):
    if len(argv) >= 2 and argv[1] == "hook":
        return hook()
    if len(argv) < 3:
        return 2
    cmd, path = argv[1], argv[2]
    tokens, model = measure(path)
    # The project is passed, never guessed. These two commands are handed a transcript and nothing
    # else, and a transcript does not say which project it belongs to. Inferring it from the current
    # directory made the same transcript report two different windows depending on where the
    # operator stood: run from this repository, whose own profile sets 1000000, a 100k transcript
    # came back as 10% of 1M rather than 50% of 200k. The hook does not have this problem because
    # Claude Code hands it the session's own cwd.
    #
    # With no project named, the window comes from the transcript alone. That is the conservative
    # answer and the one observation corrects upward, so the failure mode is an early warning rather
    # than a session that is never warned at all.
    project = None
    if cmd == "measure" and len(argv) > 3:
        project = argv[3]
    elif cmd == "handoff" and len(argv) > 5:
        project = argv[5]
    configured = None
    if project:
        configured = (_profile(project).get("gates") or {}).get("context_window")
    window = window_for(model, observed=tokens, configured=configured)
    if cmd == "measure":
        pct = int(100 * tokens / window) if window else 0
        print("%d %d %d %s" % (tokens, window, pct, model or "unknown"))
        return 0
    if cmd == "handoff":
        if len(argv) < 4:
            return 2
        out_path, session_id = argv[3], (argv[4] if len(argv) > 4 else "")
        d = os.path.dirname(out_path)
        if d:
            os.makedirs(d, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as fh:
            fh.write(render_handoff(path, session_id, tokens, window))
        print(out_path)
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
