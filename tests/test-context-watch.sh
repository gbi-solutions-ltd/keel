#!/usr/bin/env bash
# Tests for the context watchdog: lib/context_watch.py and hooks/context-watch.
#
# Driven by synthetic transcripts rather than a live session, for the same reason the rest of this
# suite generates its fixtures: a captured real transcript would be a snapshot of one moment in one
# session, and it would drift from the format without anything saying so. What is asserted here is
# the arithmetic and the hook protocol, both of which are ours.
#
# The one thing these cannot prove is that Claude Code calls the hook with the fields assumed here.
# That needs a live session and is recorded as unverified in CHANGELOG.md.
#
# Run from the repository root.

# The `condition && report_pass || report_fail` idiom is used throughout. It is safe here, and only
# here, because every reporting helper returns 0 explicitly: see the `return 0` on each below.
# shellcheck disable=SC2015
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/hooks/context-watch"
LIB="$ROOT/lib/context_watch.py"
pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

command -v python3 >/dev/null 2>&1 || { printf 'SKIP  python3 absent; the watchdog is inert without it\n'; exit 0; }

# A transcript whose last main-thread assistant turn reports the given cache-read size. The cache
# fields are the point: on a long session input_tokens is 1 and everything else is a cache read, so
# a watchdog reading input_tokens alone would call a full window one token.
transcript() {   # transcript <file> <cache_read_tokens> [model]
    local f="$1" tok="$2" model="${3:-claude-opus-5}"
    {
      printf '{"type":"user","message":{"role":"user","content":"do the thing"}}\n'
      printf '{"type":"assistant","isSidechain":false,"message":{"model":"%s","content":[{"type":"text","text":"working on it"}],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":%s,"output_tokens":0}}}\n' "$model" "$tok"
    } > "$f"
}

# Fire the hook with one event. Prints whatever the hook printed.
fire() {   # fire <event> <transcript> <cwd> [tool_name] [session]
    local event="$1" tr="$2" cwd="$3" tool="${4:-Bash}" sess="${5:-s-$RANDOM}"
    printf '{"hook_event_name":"%s","transcript_path":"%s","cwd":"%s","session_id":"%s","tool_name":"%s"}' \
      "$event" "$tr" "$cwd" "$sess" "$tool" | "$HOOK" 2>/dev/null
}

work="$(mktemp -d)"
mkdir -p "$work/.keel"
printf '{"docs_root":"docs/keel"}\n' > "$work/.keel/profile.json"

# ---- the arithmetic --------------------------------------------------------

transcript "$work/t50.jsonl" 100000
read -r tok win pct _ < <("$LIB" measure "$work/t50.jsonl" 2>/dev/null || python3 "$LIB" measure "$work/t50.jsonl")
[ "$tok" = "100001" ] && ok "occupancy sums the cache fields, not input_tokens alone" \
  || bad "measure" "got $tok tokens, want 100001"
[ "$win" = "200000" ] && ok "the default window is 200k" || bad "measure" "window $win"
[ "$pct" = "50" ] && ok "50 percent of a 200k window is reported as 50" || bad "measure" "pct $pct"

# A million-token session must not be told it is at 500%.
transcript "$work/t1m.jsonl" 100000 'claude-opus-5[1m]'
read -r _ win1m pct1m _ < <(python3 "$LIB" measure "$work/t1m.jsonl")
[ "$win1m" = "1000000" ] && ok "a 1m model is recognised from the transcript" || bad "measure" "window $win1m"
[ "$pct1m" = "10" ] && ok "the same usage against a 1m window is 10 percent" || bad "measure" "pct $pct1m"

# The failure a real transcript found, and the one that mattered most. A genuine 1M session records
# its model as plain `claude-opus-5`: no marker, and no field anywhere naming the window. Measured
# against the assumed 200,000 it came out at 200%, which would have hard-stopped the session on its
# first tool call and never lifted, on exactly the sessions with the most room left.
#
# Occupancy above a tier is proof the window is larger, because the API would have refused the
# request otherwise. The correction only ever goes upward, so it cannot invent room that is absent.
transcript "$work/unmarked1m.jsonl" 400000 'claude-opus-5'
read -r utok uwin upct _ < <(python3 "$LIB" measure "$work/unmarked1m.jsonl")
[ "$upct" -le 100 ] && ok "occupancy is never reported above 100 percent" \
  || bad "measure" "reported $upct%, which would stop the session permanently"
[ "$uwin" = "1000000" ] && ok "a 1m session with no marker is inferred from what it has already used" \
  || bad "measure" "window $uwin for $utok observed tokens"

# The correction must not run the other way. A small session stays on the conservative window, or the
# watchdog silently stops protecting the sessions it was written for.
read -r _ swin _ _ < <(python3 "$LIB" measure "$work/t50.jsonl")
[ "$swin" = "200000" ] && ok "a session inside the default window is not promoted" || bad "measure" "window $swin"

# An explicit setting beats both, which is the only mechanism that is actually correct.
read -r _ cwin cpct _ < <(KEEL_CONTEXT_WINDOW=500000 python3 "$LIB" measure "$work/t50.jsonl")
[ "$cwin" = "500000" ] && [ "$cpct" = "20" ] && ok "an explicit window setting wins over both" \
  || bad "measure" "window $cwin pct $cpct"

# And per project, since the setting belongs with the project rather than with a shell.
printf '{"docs_root":"docs/keel","gates":{"context_window":1000000}}\n' > "$work/.keel/profile.json"
out="$(fire UserPromptSubmit "$work/t50.jsonl" "$work")"
[ -z "$out" ] && ok "gates.context_window is honoured, so 50 percent of 200k is 10 percent of 1m" \
  || bad "measure" "expected silence at 10 percent, got: $out"
printf '{"docs_root":"docs/keel"}\n' > "$work/.keel/profile.json"

# ---- the floor -------------------------------------------------------------
#
# A configured window is a floor, not a ceiling. window_for used to return a configured value
# before it ever reached the observation correction, so a profile saying 200000 on a genuine 1M
# session reported 200% occupancy, hard-stopped it at 170,000 tokens and never lifted. That is the
# same failure the unconfigured path was rewritten to avoid, reintroduced through the profile.
#
# These call window_for directly rather than through `measure`, because main() calls it without a
# configured value: the profile only reaches it through the hook, and the hook asserts thresholds
# rather than the number.
wf() {   # wf <model> <observed> <configured|none>  -> the window window_for returns
    env -u KEEL_CONTEXT_WINDOW python3 -c "
import sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
cfg = sys.argv[3]
print(context_watch.window_for(sys.argv[1],
                               observed=int(sys.argv[2]),
                               configured=int(cfg) if cfg.isdigit() else None))
" "$1" "$2" "$3"
}

got="$(wf claude-opus-5 400000 200000)"
[ "$got" = "1000000" ] && ok "a configured window below observed occupancy is raised" \
  || bad "floor" "got $got, want 1000000: a configured 200000 would stop a 1M session at 170k forever"

got="$(wf claude-opus-5 100001 1000000)"
[ "$got" = "1000000" ] && ok "a configured window above observed occupancy is left alone" \
  || bad "floor" "got $got, want 1000000"

got="$(wf claude-opus-5 100001 none)"
[ "$got" = "200000" ] && ok "with no configured window the conservative default still applies" \
  || bad "floor" "got $got, want 200000"

got="$(wf claude-opus-5 100001 200000)"
[ "$got" = "200000" ] && ok "a session inside its configured window is not promoted" \
  || bad "floor" "got $got, want 200000: the floor must not promote every session"

# ---- the upper bound -------------------------------------------------------
#
# 1,000,000 is the largest context window any current Claude model offers, checked 2026-08-18. It
# is also already the highest value observation can promote to, so bounding the configured value
# there adds no ceiling the observed path did not have. Without it a mistyped extra zero silences
# the watchdog for the life of the project, which is the same harm as the floor bug pointing the
# other way.
got="$(wf claude-opus-5 100001 200000000)"
[ "$got" = "1000000" ] && ok "a profile window above the maximum is bounded" \
  || bad "bound" "got $got, want 1000000: a mistyped window must not silence the watchdog"

got="$(KEEL_CONTEXT_WINDOW=200000000 python3 -c "
import sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
print(context_watch.window_for('claude-opus-5', observed=100001))
")"
[ "$got" = "1000000" ] && ok "an environment window above the maximum is bounded" \
  || bad "bound" "got $got, want 1000000"

got="$(wf claude-opus-5 100001 1000000)"
[ "$got" = "1000000" ] && ok "a window at the maximum is untouched" \
  || bad "bound" "got $got, want 1000000"

grep -q 'min(window, LONG_WINDOW)' "$ROOT/lib/context_watch.py" \
  && ok "the bound is the LONG_WINDOW constant, not a second literal" \
  || bad "bound" "the bound is not expressed as LONG_WINDOW; a larger model would need two edits"

# ---- measure does not depend on where it is run ------------------------------
#
# `measure` and `handoff` are given a transcript and no project. Reading gates.context_window from
# the current directory looked like the obvious way to honour the profile, and it made the same
# transcript report two different windows depending on where the operator happened to stand: from
# this repository, whose own profile sets 1000000, a 100k fixture came back as 10% of 1M instead of
# 50% of 200k. The project has to be passed, never guessed.
mkdir -p "$work/onem/.keel"
printf '{"docs_root":"docs","gates":{"context_window":1000000}}\n' > "$work/onem/.keel/profile.json"
got="$( cd "$work/onem" && env -u KEEL_CONTEXT_WINDOW python3 "$LIB" measure "$work/t50.jsonl" | awk '{print $2}' )"
[ "$got" = "200000" ] && ok "measure ignores the profile of whatever directory it is run from" \
  || bad "measure cwd" "got window $got from a 1m profile in the cwd; the transcript is not that project's"

got="$( env -u KEEL_CONTEXT_WINDOW python3 "$LIB" measure "$work/t50.jsonl" "$work/onem" | awk '{print $2}' )"
[ "$got" = "1000000" ] && ok "measure honours a project passed explicitly" \
  || bad "measure cwd" "got window $got, want 1000000 when the project is named"

# ---- the environment override ----------------------------------------------
#
# The profile key is a floor; the environment variable is not. It is the deliberate escape hatch,
# and the suite above depends on it: a test that forces a window smaller than its fixture's
# occupancy has no other way to do it. Untested until now, which made it one refactor away from
# quietly becoming a floor as well.
got="$(KEEL_CONTEXT_WINDOW=50000 python3 -c "
import sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
print(context_watch.window_for('claude-opus-5', observed=100001))
")"
[ "$got" = "50000" ] && ok "the environment window is not raised by observation" \
  || bad "env" "got $got, want 50000: forcing a small window must stay possible"

got="$(KEEL_CONTEXT_WINDOW=500000 python3 -c "
import sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
print(context_watch.window_for('claude-opus-5', observed=1, configured=1000000))
")"
[ "$got" = "500000" ] && ok "the environment window outranks the profile" \
  || bad "env" "got $got, want 500000"

# ---- the cost --------------------------------------------------------------
#
# window_for runs on every prompt and, at the stop threshold, on every tool call. It receives
# everything it needs as arguments, and it must stay that way: a filesystem read here is paid
# dozens of times a minute for a number that moves slowly.
python3 -c "
import inspect, sys
sys.path.insert(0, '$ROOT/lib')
import context_watch
src = inspect.getsource(context_watch.window_for) + inspect.getsource(context_watch._positive_int)
banned = ['open(', 'os.path', 'os.stat', 'os.listdir', 'subprocess', 'socket', 'urllib', 'json.load']
hits = [b for b in banned if b in src]
sys.exit(1 if hits else 0)
" && ok "window_for reads nothing from the filesystem or the network" \
  || bad "cost" "window_for gained an I/O call; it runs on every prompt and every tool call"

# ---- end to end ------------------------------------------------------------
#
# The whole plan in one assertion. A profile written by keel init says 200000. The session has used
# 400000 tokens, which is 200% of the written window and 40% of the real one. Before the floor, the
# hook stopped this session on its first tool call and never lifted. It must now be silent.
transcript "$work/e2e.jsonl" 400000 'claude-opus-5'
printf '{"docs_root":"docs/keel","gates":{"context_window":200000}}\n' > "$work/.keel/profile.json"
out="$(fire UserPromptSubmit "$work/e2e.jsonl" "$work")"
[ -z "$out" ] && ok "a 400k session in a project written with 200000 is silent" \
  || bad "e2e" "expected silence at 40 percent of a raised window, got: $out"

# And the warning still fires for a session that really is filling a 200000 window.
transcript "$work/warn.jsonl" 150000 'claude-opus-5'
out="$(fire UserPromptSubmit "$work/warn.jsonl" "$work")"
case "$out" in *"75%"*) ok "the warn still fires at 75 percent of a genuine 200000 window" ;;
  *) bad "e2e" "the floor silenced a warning that should have fired: $out" ;; esac
printf '{"docs_root":"docs/keel"}\n' > "$work/.keel/profile.json"

# The watchdog does nothing at all without python3, rather than printing an apology on every
# prompt. doctor is what reports the silence; the hook must not.
#
# PATH is emptied rather than pointed at /nonexistent, and bash is resolved to an absolute path
# first. hooks/context-watch is `#!/usr/bin/env bash`, so a PATH with no bash in it fails to exec
# the hook at all: rc 127 and an env error, which never reaches the python3 check being tested.
mkdir -p "$work/empty"
bash_bin="$(command -v bash)"

# Fed from a file, not through a pipe, and that is the whole fix. Diagnosed 2026-09-09 after this
# case failed on CI for the second time with `rc=1 out= err=`.
#
# The hook exits at its `command -v python3 ... || exit 0` line before reading stdin, which is the
# behaviour this case exists to prove. Through a pipe, that leaves the writer writing to a reader
# that has gone: printf takes SIGPIPE, or EPIPE where SIGPIPE is ignored, and this file runs
# `set -o pipefail`, which hands the pipeline the writer's status. Measured both ways: rc=141 with
# the default disposition, rc=1 with SIGPIPE ignored, which is what CI reported. Small payloads
# usually win the race, which is why it passed locally every time and failed on a loaded runner
# twice in a month.
#
# The remedy added after the first failure was to keep the hook's stderr and print it. It could
# never have seen this: the message belongs to the test's own printf, on the test's stderr, which is
# why the report said `err=` with nothing after it. stderr is still kept, because it is the right
# thing to report for any other cause.
printf '{"hook_event_name":"UserPromptSubmit","transcript_path":"%s","cwd":"%s","session_id":"s-np","tool_name":"Bash"}' \
  "$work/e2e.jsonl" "$work" > "$work/no-python.json"
out="$(PATH="$work/empty" "$bash_bin" "$HOOK" < "$work/no-python.json" 2>"$work/no-python.err")"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "the watchdog is silent and exits 0 when python3 is absent" \
  || bad "no python" "rc=$rc out=$out err=$(head -3 "$work/no-python.err")"

# A subagent's context is discarded when it returns. Counting it would report the main thread as
# full because a subagent read twenty files, which inverts the reason for delegating at all.
cat > "$work/side.jsonl" <<'T'
{"type":"assistant","isSidechain":false,"message":{"model":"claude-opus-5","content":[],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":20000,"output_tokens":0}}}
{"type":"assistant","isSidechain":true,"message":{"model":"claude-opus-5","content":[],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":190000,"output_tokens":0}}}
T
read -r toks _ _ _ < <(python3 "$LIB" measure "$work/side.jsonl")
[ "$toks" = "20001" ] && ok "a subagent's usage is not counted against the main thread" \
  || bad "measure" "got $toks, want 20001"

# A half-written last line is normal: the hook fires while the session is still appending.
cp "$work/t50.jsonl" "$work/torn.jsonl"
printf '{"type":"assistant","message":{"model":"claude' >> "$work/torn.jsonl"
read -r tornt _ _ _ < <(python3 "$LIB" measure "$work/torn.jsonl")
[ "$tornt" = "100001" ] && ok "a torn final line is skipped rather than fatal" || bad "measure" "got $tornt"

# ---- the thresholds --------------------------------------------------------

transcript "$work/quiet.jsonl" 60000       # 30%
out="$(fire UserPromptSubmit "$work/quiet.jsonl" "$work")"
[ -z "$out" ] && ok "below the warn threshold the hook says nothing at all" \
  || bad "thresholds" "expected silence, got: $out"

transcript "$work/warn.jsonl" 150000       # 75%
out="$(fire UserPromptSubmit "$work/warn.jsonl" "$work")"
case "$out" in *'"additionalContext"'*75*) ok "in the warn band it names the actual percentage" ;;
  *) bad "thresholds" "no warning with a number: $out" ;; esac
case "$out" in *PAUSE*) bad "thresholds" "the warn band told the session to stop" ;;
  *) ok "the warn band does not tell the session to stop" ;; esac

transcript "$work/stop.jsonl" 180000       # 90%
out="$(fire UserPromptSubmit "$work/stop.jsonl" "$work")"
case "$out" in *PAUSE*.keel/handoff.md*) ok "past the stop threshold the prompt hook demands a handoff" ;;
  *) bad "thresholds" "no stop instruction naming .keel/handoff.md: $out" ;; esac
# The handoff is git-ignored, so anything durable in it is lost when it is discarded unless it is
# moved to its real home first. The instruction that says so has to travel with the instruction to
# write the file, or the ignore turns a scratch file into a shredder.
case "$out" in *decisions*) ok "the stop text says durable decisions must be promoted before the handoff goes" ;;
  *) bad "thresholds" "nothing about promoting decisions out of a file that is not kept: $out" ;; esac

# ---- the block, and the way out of it --------------------------------------

out="$(fire PreToolUse "$work/quiet.jsonl" "$work" Bash)"
[ -z "$out" ] && ok "an ordinary tool call below the threshold is untouched" \
  || bad "block" "expected silence, got: $out"

sess="blocked-$$"
out="$(fire PreToolUse "$work/stop.jsonl" "$work" Bash "$sess")"
case "$out" in *'"permissionDecision": "deny"'*) ok "past the stop threshold a tool call is denied" ;;
  *) bad "block" "the call was not denied: $out" ;; esac

# The deadlock this design has to avoid: being told to write a handoff while writing is refused.
for tool in Write Edit Read; do
    out="$(fire PreToolUse "$work/stop.jsonl" "$work" "$tool" "$sess")"
    [ -z "$out" ] && ok "$tool stays available so the handoff can actually be written" \
      || bad "block" "$tool was denied, which makes the instruction impossible: $out"
done

# Once the handoff is written the session is released. A stop that never lifts is a wall, and a wall
# is what makes somebody set KEEL_CONTEXT_WATCH=off and leave it off.
printf '# Session handoff\n\nDone: the thing. Next: the other thing.\n' > "$work/.keel/handoff.md"
out="$(fire PreToolUse "$work/stop.jsonl" "$work" Bash "$sess")"
[ -z "$out" ] && ok "with the handoff written, tool calls are allowed again" \
  || bad "block" "still denied after the handoff was written: $out"
rm -f "$work/.keel/handoff.md"

# ---- the escape hatch ------------------------------------------------------

out="$(KEEL_CONTEXT_WATCH=off fire PreToolUse "$work/stop.jsonl" "$work" Bash)"
[ -z "$out" ] && ok "KEEL_CONTEXT_WATCH=off disables the watchdog entirely" \
  || bad "hatch" "still fired with the watchdog off: $out"

printf '{"docs_root":"docs/keel","gates":{"context_watch":false}}\n' > "$work/.keel/profile.json"
out="$(fire PreToolUse "$work/stop.jsonl" "$work" Bash)"
[ -z "$out" ] && ok "gates.context_watch=false disables it per project" \
  || bad "hatch" "profile gate ignored: $out"
printf '{"docs_root":"docs/keel"}\n' > "$work/.keel/profile.json"

# Thresholds are configurable, because 85 is a judgement rather than a fact about any model.
out="$(KEEL_CONTEXT_STOP=20 fire PreToolUse "$work/quiet.jsonl" "$work" Bash)"
case "$out" in *deny*) ok "the stop threshold is configurable" ;;
  *) bad "hatch" "KEEL_CONTEXT_STOP was ignored: $out" ;; esac

# ---- the handoff itself ----------------------------------------------------

cat > "$work/rich.jsonl" <<'T'
{"type":"user","message":{"role":"user","content":"add rate limiting to the payouts endpoint"}}
{"type":"assistant","isSidechain":false,"message":{"model":"claude-opus-5","content":[{"type":"text","text":"Added a token bucket."},{"type":"tool_use","name":"Edit","input":{"file_path":"/srv/payments-api/limiter.ts"}}],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":180000,"output_tokens":0}}}
T
out="$(fire PreCompact "$work/rich.jsonl" "$work")"
[ -f "$work/.keel/handoff.md" ] && ok "PreCompact writes the handoff before the context is rewritten" \
  || bad "handoff" "no file written"
h="$(cat "$work/.keel/handoff.md" 2>/dev/null)"
case "$h" in *"add rate limiting to the payouts endpoint"*) ok "the handoff records what was asked" ;;
  *) bad "handoff" "the prompt is missing" ;; esac
case "$h" in *"limiter.ts"*) ok "the handoff records the files that were written" ;;
  *) bad "handoff" "the edited file is missing" ;; esac
case "$h" in *"TO BE COMPLETED"*) ok "the handoff marks what only a human or the session can supply" ;;
  *) bad "handoff" "no placeholder for the judgement part" ;; esac
case "$h" in *decisions*) ok "the template tells the writer to promote decisions before the file goes" ;;
  *) bad "handoff" "the template does not say where a durable decision has to end up" ;; esac
# PreCompact must emit NOTHING. The vendor discards a PreCompact hook's systemMessage and continue
# fields (code.claude.com/docs/en/hooks, verified 2026-09-05), so the announcement this used to
# print was written, serialised and thrown away, and this case used to assert it was there by
# grepping keel's own stdout. The handoff itself is still written; where the next session learns
# about it is hooks/session-start, which already runs on compact. See test-session-start.sh.
case "$out" in
  *systemMessage*) bad "handoff" "PreCompact emitted a systemMessage, which the harness discards: $out" ;;
  "") ok "PreCompact emits nothing, because nothing it emits is honoured" ;;
  *) bad "handoff" "PreCompact emitted something unexpected: $out" ;;
esac

# The handoff is session state, not project knowledge, so its path is keel's own state directory and
# not the docs tree. Written under docs_root it lands inside a committed tree, where `git add -A`
# sweeps it into the next commit. It must not follow docs_root anywhere.
[ -e "$work/docs" ] && bad "handoff" "the handoff was written into the docs tree" \
  || ok "the handoff stays out of the docs tree"
printf '{"docs_root":"documentation"}\n' > "$work/.keel/profile.json"
rm -f "$work/.keel/handoff.md"
fire PreCompact "$work/rich.jsonl" "$work" >/dev/null
[ -f "$work/.keel/handoff.md" ] && [ ! -e "$work/documentation" ] \
  && ok "the handoff path does not follow docs_root" \
  || bad "handoff" "a different docs_root moved the handoff"
printf '{"docs_root":"docs/keel"}\n' > "$work/.keel/profile.json"

# It must fit in a context, since its whole purpose is to be read by the session that replaces this
# one. A handoff that reproduces the conversation costs what the pause just saved.
size=$(wc -c < "$work/.keel/handoff.md" | tr -d ' ')
[ "$size" -lt 8000 ] && ok "the handoff is small enough to be worth reading ($size bytes)" \
  || bad "handoff" "$size bytes is too much to load into a fresh session"

# ---- failure modes ---------------------------------------------------------
#
# A hook that breaks a session is worse than a hook that does nothing, so every one of these must
# produce silence and exit 0 rather than an error.

out="$(fire UserPromptSubmit "$work/does-not-exist.jsonl" "$work")"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "a missing transcript is silent, not an error" \
  || bad "failure" "rc=$rc out=$out"

printf 'not json at all\n' > "$work/garbage.jsonl"
out="$(fire UserPromptSubmit "$work/garbage.jsonl" "$work")"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "an unparseable transcript is silent, not an error" \
  || bad "failure" "rc=$rc out=$out"

out="$(printf 'this is not json' | "$HOOK" 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "a malformed hook event is silent, not an error" \
  || bad "failure" "rc=$rc out=$out"

out="$(fire UserPromptSubmit "$work/stop.jsonl" /nonexistent-project-dir)"; rc=$?
[ "$rc" -eq 0 ] && ok "a cwd with no profile is not an error" \
  || bad "failure" "rc=$rc"

# ---- two transcript shapes, and a third that is neither --------------------
#
# These are the only cases in this file driven by a recording rather than by a shape this file
# believes in. The header above says the suite generates its fixtures; these two are the exception,
# and they are the exception on purpose. What read_usage claims is that it can parse what a harness
# actually writes, and a synthetic file can only prove it parses what we think a harness writes.
# tests/fixtures/transcripts/codex.jsonl is a trimmed capture from codex-cli 0.153.4 and
# claude-stop-edited-no-test.jsonl is one captured from a real Claude Code turn. They are the canary
# section 10.3 of docs/architecture/tiered-multi-harness-support.md requires: when either harness
# changes its transcript shape, these go red rather than the watchdog going quiet.
#
# They are also the evidence behind the two codex rows in lib/harness/capabilities. Delete them and
# those rows assert a parser nothing checks.

FIX="$ROOT/tests/fixtures/transcripts"
usage() {   # usage <fixture> <index 0=tokens 1=kind>
    python3 -c 'import sys;sys.path.insert(0,"lib");import context_watch as c;print(c.read_usage(sys.argv[1])[int(sys.argv[2])])' \
      "$1" "$2"
}

got="$(usage "$FIX/codex.jsonl" 1)"
[ "$got" = codex ] && ok "a Codex transcript is recognised" || bad "a Codex transcript is recognised" "got $got"

got="$(usage "$FIX/claude-stop-edited-no-test.jsonl" 1)"
[ "$got" = claude ] && ok "a Claude Code transcript is recognised" \
  || bad "a Claude Code transcript is recognised" "got $got"

n="$(usage "$FIX/codex.jsonl" 0)"
[ "$n" -gt 0 ] && ok "a Codex transcript yields a token total" || bad "a Codex transcript yields a token total" "got $n"

# The exact number, not merely a positive one, and it pins two separate things that both look
# right while being wrong.
#
# ONE: Codex reports cached_input_tokens INSIDE input_tokens and states the answer as total_tokens,
# where Claude Code reports four disjoint counts that have to be added. The fixture's second record
# is 14018 input, of which 13056 cached, plus 5 output, stating 14023. Summing the fields the Claude
# way gives 27079, so the session would be reported at roughly twice its real occupancy and would
# hard-stop at half the intended threshold.
#
# TWO: one token_usage_record is written per model RESPONSE, not per turn, and this fixture holds
# the two that one turn wrote: 13993 then 14023. Occupancy is the size of the most recent request,
# so the last one wins. Adding them gives 28016, more than the whole window is occupied by, which is
# the same class of error as summing the fields. A fixture holding one usage record cannot tell the
# two apart and leaves both changes green, which is why the second one is in it.
[ "$n" = 14023 ] && ok "the Codex total is the last response's total_tokens, not a sum" \
  || bad "the Codex total" "expected 14023, got $n"

# The window is read, not assumed. The Codex fixture states model_context_window 258400. Assuming
# the 200,000 default would report this session at 129% of a window it is at 5% of, and hard-stop
# every Codex session at 66% of the room it actually has.
w="$(python3 -c 'import sys;sys.path.insert(0,"lib");import context_watch as c;print(c.declared_window(sys.argv[1]))' "$FIX/codex.jsonl")"
[ "$w" = 258400 ] && ok "a Codex transcript states its own context window" \
  || bad "declared window" "expected 258400, got $w"

# Claude Code states none, so the inference in window_for is still what answers for it.
w="$(python3 -c 'import sys;sys.path.insert(0,"lib");import context_watch as c;print(c.declared_window(sys.argv[1]))' "$FIX/claude-stop-edited-no-test.jsonl")"
[ "$w" = 0 ] && ok "a Claude Code transcript states no window, so nothing is invented" \
  || bad "declared window" "expected 0, got $w"

# R-01: a stated window must not change what Claude Code sees. Nothing states one there, so this
# pins that the new parameter defaults to the old behaviour rather than to a window of its own.
w="$(python3 -c 'import sys;sys.path.insert(0,"lib");import context_watch as c;print(c.window_for("claude-opus-5"))')"
[ "$w" = 200000 ] && ok "an unstated window leaves the Claude Code answer unchanged" \
  || bad "window_for default" "expected 200000, got $w"

# ...and window_for uses it. Reading the number and then ignoring it leaves every case above green
# while the watchdog still measures Codex against the 200,000 default.
w="$(python3 -c 'import sys;sys.path.insert(0,"lib");import context_watch as c;print(c.window_for("", declared=258400))')"
[ "$w" = 258400 ] && ok "a stated window is what the session is measured against" \
  || bad "stated window" "expected 258400, got $w"

# A stated window is a starting point, not a ceiling: observation still raises it. Otherwise a
# harness that understated its own window would cap the watchdog below the real one permanently.
w="$(python3 -c 'import sys;sys.path.insert(0,"lib");import context_watch as c;print(c.window_for("", observed=300000, declared=258400))')"
[ "$w" = 1000000 ] && ok "observation still raises a stated window" || bad "stated window" "expected 1000000, got $w"

# END TO END, and this is the assertion the codex transcript_turn_usage row in
# lib/harness/capabilities actually rests on. Everything above tests read_usage, which only sniffs.
# What context-watch runs is measure and window_for, and until 2026-09-06 those understood Claude
# Code rows alone: a Codex session measured 0 tokens, hook() returned at `if not tokens`, and the
# watchdog was silent on every turn. A gate the manifest calls active and which never fires is the
# failure this whole design exists to prevent, so it is pinned here as one line: occupancy, window,
# percentage and model, all four read from the rollout rather than assumed.
got="$(python3 "$LIB" measure "$FIX/codex.jsonl")"
[ "$got" = "14023 258400 5 gpt-5.6-terra" ] \
  && ok "context-watch measures a real Codex session end to end" \
  || bad "codex end to end" "expected '14023 258400 5 gpt-5.6-terra', got '$got'"

# A transcript with no assistant turn YET is not an unrecognised one. That is the state of every
# session at its first prompt, and calling it unsupported made the watchdog announce itself inactive
# once per session on a file it understands perfectly well. Found in review: the kind was being
# decided by "did a parser return a number" rather than by the shape of the rows.
fresh="$(mktemp)"
printf '{"type":"user","message":{"role":"user","content":"do the thing"}}\n' > "$fresh"
got="$(usage "$fresh" 1)"
[ "$got" = claude ] && ok "a transcript with no assistant turn yet is recognised, not unsupported" \
  || bad "a transcript with no assistant turn yet is recognised" "got $got"
err="$(printf '{"hook_event_name":"UserPromptSubmit","transcript_path":"%s","cwd":"%s","session_id":"s-fresh"}' \
  "$fresh" "$work" | python3 "$LIB" hook 2>&1 >/dev/null)"
[ -z "$err" ] && ok "and the hook says nothing about it" \
  || bad "and the hook says nothing about it" "stderr was: $err"
rm -f "$fresh"

# A Codex rollout with no usage record yet, the same case on the other harness.
fresh="$(mktemp)"
printf '{"timestamp":"2026-09-06T07:16:38Z","ordinal":0,"type":"session_meta","payload":{"session_id":"x"}}\n' > "$fresh"
got="$(usage "$fresh" 1)"
[ "$got" = codex ] && ok "a Codex rollout with no usage record yet is recognised" \
  || bad "a Codex rollout with no usage record yet is recognised" "got $got"
rm -f "$fresh"

u="$(mktemp)"; printf 'not a transcript\n' > "$u"
got="$(usage "$u" 1)"
[ "$got" = unsupported ] && ok "an unknown format reports unsupported" || bad "an unknown format reports unsupported" "got $got"
n="$(usage "$u" 0)"
[ "$n" != 0 ] && ok "an unknown format does not report zero tokens" \
  || bad "an unknown format does not report zero tokens" "reported 0, which looks like a quiet session"
rm -f "$u"

# The hook says so rather than going quiet. A transcript that exists and does not parse took the
# same silent path as one that is absent until 2026-09-06, so a watchdog that had stopped working
# was indistinguishable from a session using no context.
#
# Fired at lib/context_watch.py directly, not through hooks/context-watch, and that is not a
# convenience. The wrapper ends in `2>/dev/null` on purpose, so that a hook which breaks cannot put
# an error on the end of every turn in the session. This message therefore does not reach a person
# through the hook, by design; keel doctor's watchdog section is the surface that shows it, and
# task 11 of the tiered multi-harness plan is what adds that. What is pinned here is that the
# detection happens and says which, rather than returning the same 0 an idle session returns.
bad_t="$work/unsupported.jsonl"
printf '{"type":"something-else","payload":{"nope":1}}\n' > "$bad_t"
err="$(printf '{"hook_event_name":"UserPromptSubmit","transcript_path":"%s","cwd":"%s","session_id":"s-unsup"}' \
  "$bad_t" "$work" | python3 "$LIB" hook 2>&1 >/dev/null)"
printf '%s' "$err" | grep -q 'watchdog inactive' \
  && ok "an unparseable transcript is reported, not silently measured as zero" \
  || bad "unsupported is surfaced" "stderr was: ${err:-<empty>}"

# --- the tail optimisation actually optimises -----------------------------------------------------
#
# _tail_entries exists because parsing a multi-megabyte transcript on every prompt would make the
# watchdog the slowest thing in the session, which its own docstring calls "a good way to have it
# turned off". _measure_parts returned early only when it had BOTH a token count and a declared
# window, and a Claude Code transcript never states a window, so the second condition was never met
# and the whole file was parsed on every cache miss, on every Claude Code session.
#
# Asserted by making the whole-file read impossible rather than by timing it: a timing test on a
# 600KB file is a test that fails on a slow CI box and gets deleted.
# One pad string, built once. Built inside the loop it is 4000 subshells per fixture.
pad="$(printf 'x%.0s' $(seq 1 140))"
big="$work/big.jsonl"
{
  # Padding first, so the file clears TAIL_BYTES (512KB) and the tail path is the one taken.
  i=0; while [ "$i" -lt 4000 ]; do
    printf '{"type":"user","message":{"role":"user","content":"%s"}}\n' "$pad"
    i=$((i+1))
  done
  printf '{"type":"assistant","isSidechain":false,"message":{"model":"claude-opus-5","content":[{"type":"text","text":"t"}],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":34567,"output_tokens":0}}}\n'
} > "$big"
[ "$(wc -c < "$big")" -gt 524288 ] || bad "the tail fixture clears TAIL_BYTES" "file is only $(wc -c < "$big") bytes, so the tail path is not the one under test"

got="$(KEEL_LIB="$LIB" python3 - "$big" <<'PY' 2>&1
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("cw", os.environ["KEEL_LIB"])
cw = importlib.util.module_from_spec(spec); spec.loader.exec_module(cw)
def boom(_path):
    raise AssertionError("whole file parsed")
cw._entries = boom
try:
    print(cw._measure_parts(sys.argv[1])[0])
except AssertionError as e:
    print("WHOLE-FILE: %s" % e)
PY
)"
[ "$got" = 34568 ] && ok "a Claude Code transcript is measured from the tail alone" \
  || bad "a Claude Code transcript is measured from the tail alone" "got: $got"

# And the fallthrough it must NOT lose: a tail with no usable turn still reads the whole file,
# because reporting zero there would read as an empty context and silence the watchdog exactly when
# it is needed. The usage record is at the HEAD, so only a whole-file read can find it.
head_only="$work/head.jsonl"
{
  printf '{"type":"assistant","isSidechain":false,"message":{"model":"claude-opus-5","content":[{"type":"text","text":"t"}],"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":77000,"output_tokens":0}}}\n'
  i=0; while [ "$i" -lt 4000 ]; do
    printf '{"type":"user","message":{"role":"user","content":"%s"}}\n' "$pad"
    i=$((i+1))
  done
} > "$head_only"
got="$(KEEL_LIB="$LIB" python3 - "$head_only" <<'PY' 2>&1
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("cw", os.environ["KEEL_LIB"])
cw = importlib.util.module_from_spec(spec); spec.loader.exec_module(cw)
print(cw._measure_parts(sys.argv[1])[0])
PY
)"
[ "$got" = 77001 ] && ok "a tail with no usable turn still falls through to the whole file" \
  || bad "a tail with no usable turn still falls through to the whole file" "got: $got"

# A Codex rollout DOES state a window, so the fallthrough for the window is kept there: a tail
# carrying a usage record and no token_count must still read the whole file rather than put the
# session back on the 200000 default.
cx="$work/cxbig.jsonl"
{
  printf '{"ordinal":0,"type":"event_msg","payload":{"type":"token_count","info":{"model_context_window":258400}}}\n'
  i=0; while [ "$i" -lt 4000 ]; do
    printf '{"ordinal":1,"type":"response_item","payload":{"type":"message","note":"%s"}}\n' "$pad"
    i=$((i+1))
  done
  printf '{"ordinal":2,"type":"token_usage_record","payload":{"usage":{"input_tokens":91000,"cached_input_tokens":0,"output_tokens":0,"total_tokens":91000}}}\n'
} > "$cx"
got="$(KEEL_LIB="$LIB" python3 - "$cx" <<'PY' 2>&1
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("cw", os.environ["KEEL_LIB"])
cw = importlib.util.module_from_spec(spec); spec.loader.exec_module(cw)
t, m, w = cw._measure_parts(sys.argv[1])
print("%s %s" % (t, w))
PY
)"
[ "$got" = "91000 258400" ] && ok "a Codex tail with no stated window still finds it in the whole file" \
  || bad "a Codex tail with no stated window still finds it in the whole file" "got: $got"

rm -rf "$work"
printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
