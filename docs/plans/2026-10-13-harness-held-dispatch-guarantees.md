# Harness-held dispatch guarantees Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task. Tasks 2 and 3 run the real cycle. Task 1 is
> a probe a person runs in a live Claude Code session, and tasks 4 and 5 change text, whose test is
> the applied check below.

**Goal:** a person watching a keel run sees the model each subagent actually runs on, `keel-fanout`
cannot edit files, and the review prompts behind the 2026-10-12 incidents tell a reviewer not to
move the author's index, tree or stash.
**Stories:** none. See "There are no stories, and that is a deviation worth naming" below.
**ADRs:** ADR-0003 (a primitive with no source, version and date is not provided), ADR-0004 (a
guarantee belongs to a repository and harness pair, so what holds on Claude Code only is declared),
ADR-0005 (one skill body across harnesses: nothing here touches a skill body).
**Architecture:** no new skill, hook, gate or profile key. One plugin `settings.json`, generated
from one Python script under `lib/` by a new mode of `tests/generate-harness-artifacts.sh`, one
frontmatter field on `agents/keel-fanout.md`, two capability rows, one path added to the
supply-chain scan's `exec` scope, and sentences added inside three pasted review prompts. Decided in
`docs/ideas/harness-held-dispatch-guarantees.md`, whose open questions 1 to 3 were answered on
2026-10-13.
**Reviewed:** by a dispatched plan reviewer on 2026-10-13. One blocking finding and every should-fix
are applied in this revision; "What the review changed" records them.

## Global constraints

Copied verbatim from `.keel/profile.json`, `docs/standards.md`, `lib/harness/capabilities` and the
idea record. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint
  `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
  `verify.typecheck`, `verify.build`, `verify.e2e` and `verify.test_integration` are all `null`.
  CI also runs `ruff check --isolated --no-cache --select E4,E7,E9,F lib/` over the Python in
  `lib/`; it is not a local verify command.
- **`tests/run-tests.sh` takes about 2m30s and more under load.** Where a tool call cannot run that
  long, run its jobs in parallel batches inside one call, and `tests/test-keel.sh` in a call of its
  own at the longest timeout available: alone it took 134 s on 2026-10-13. Say which jobs ran.
- **`shellcheck` may not be installed where a task runs.** If `command -v shellcheck` prints
  nothing, say the lint was not run; CI runs the same command from the profile.
- Never start on `main`. Work lands through a pull request, reviewed by somebody other than its
  author.
- No em dashes and no en dashes, in any file or commit message.
- Prose wraps at 100 columns; table rows and code blocks do not.
- **Every commit carries its own documentation**, `CHANGELOG.md` included. The last plan put every
  changelog entry in its final task and recorded that as a departure; each task here writes its own.
- **No capability row without evidence.** `lib/harness/capabilities`: "Do not add a row you have
  not checked." A row's source is `vendor:` or `probe:`, and its version is the harness's, never
  keel's. Tasks 2 and 3 add rows only from what task 1 recorded.
- A primitive name carries no wire-format word: `tests/test-harness-resolve.sh` rejects `jsonl`,
  `_json`, `message` and `content` in that column.
- `docs/harness-support.md` is generated. Never hand-edit it: regenerate it with
  `tests/generate-harness-artifacts.sh support-page > docs/harness-support.md`.
- No file under `hooks/` that is not a gate: `tests/test-harness-resolve.sh` reads `hooks/*` as the
  gate list. The status line script lives in `lib/`.
- Every rule added states its reason, and the best reasons name a measured failure.
- Commits and pull requests carry no attribution footers.

---

## The applied check

Tasks 4 and 5 change text in shipped files. **Their test is the applied check, not a unit test**:
an invented test for a sentence reads as coverage and checks nothing, which `plan-template.md` calls
worse than an honest gap.

| Command | What it proves |
|---|---|
| `tests/validate-skills.sh` | 0 FAIL, and the WARN count unchanged from the start of the plan (10). Links resolve, dashes are absent |
| `tests/validate-citations.sh` | A cited line is not blank and a cited heading exists |
| `tests/test-doc-claims.sh` | A documented count the tree contradicts, and a top-level entry `docs/06-repo-layout.md` does not show |
| `tests/test-harness-claims.sh` | A `keel:claim` tag the capability manifest does not grant |

## There are no stories, and that is a deviation worth naming

`write-plan` step 1 stops and names `write-user-stories` where no stories exist. There are none,
and no PRD. The input is `docs/ideas/harness-held-dispatch-guarantees.md`, shaped on 2026-10-13,
whose three open questions were put to the user as choices and answered the same day. That is the
shape `docs/plans/2026-10-12-independence-of-a-delegated-review.md` ran under, for the same reason:
the deciding step has been run, and a PRD would restate it.

**What is unmeasured, and the changelog must say so:** no instance of a dispatch label that lied is
on record. Task 2 makes the label checkable; it does not fix a recorded failure. Tasks 3 and 4 do
answer recorded incidents, both on 2026-10-12, which the idea record lists.

## What this plan does not build

From the idea record, so a reader does not mistake silence for an answer:

- **No reviewer in a harness worktree.** Claude Code's subagent worktrees branch from the default
  branch and check out tracked files only, so a reviewer there would review the wrong tree.
- **No `maxTurns` on `keel-fanout`.** The idea record's variant C named one, and the user's answer
  scoped the restriction to edits. No runaway fan-out is on record, and a turn cap ends a read
  silently, which is the failure a fan-out is least able to report.
- **No mismatch flag on the status line.** Answered 2026-10-13: show the model, do not judge it.
- **No Codex equivalent of either.** Codex is declared dark for both, per ADR-0004.
- **No elapsed time, progress summary or queued count on the row.** A status line replaces the
  whole row, so the default row's live progress summary, elapsed time and queued count go. The agent
  type stays, because it is what shows whether a `keel-fanout: ` row runs as the restricted agent.
  Elapsed time could be computed from `startTime`; it is left out because a clock makes the test
  depend on the time it runs.
- **No read-only sentence in `plan-review.md`.** It is a judging dispatch too, but neither incident
  came from it, and the idea record named the prompts that produced them.
- Items 4 to 8 of the idea record, which are decided together later.

---

### Task 1: probe what Claude Code does with a plugin's status line and a plugin agent's tool limit

**Story:** none.
**Run by:** a person, in a live Claude Code session on their own machine. A subagent cannot do this:
the status line renders only in an interactive terminal.
**Files:**
- Create, outside the repository: `/tmp/keel-probe/plugin/.claude-plugin/plugin.json`,
  `/tmp/keel-probe/plugin/settings.json`, `/tmp/keel-probe/plugin/probe.py`,
  `/tmp/keel-probe/plugin/agents/no-write.md`
- Modify: this plan, the "Probe results" section at the end of this task

**Interfaces:**
- Produces: four recorded facts, in "Probe results": whether `${CLAUDE_PLUGIN_ROOT}` resolves in a
  plugin `settings.json` command, the model ID a row received, whether `disallowedTools` held on a
  plugin agent, and the `claude --version` they were observed on. Tasks 2 and 3 consume all four.

**Depends on:** none

**Done when:** "Probe results" below holds a value in all four rows. There is no command: a person
reads a terminal.

**Why a probe and not the docs.** The docs state that a plugin `settings.json` may set
`subagentStatusLine`, and that a row's `model` is "the resolved model the task runs on". They do
not list `settings.json` among the places `${CLAUDE_PLUGIN_ROOT}` resolves, and
`lib/harness/capabilities` will not take a row nobody checked. Ten minutes here decides whether
task 2's command works at all.

- [x] **Step 1.1: Write the probe plugin** Note: Coordinator wrote the four probe files and the work repo under /tmp/keel-probe and read claude --version (2.1.291); steps 1.2 to 1.4 are the person's

```bash
mkdir -p /tmp/keel-probe/plugin/.claude-plugin /tmp/keel-probe/plugin/agents /tmp/keel-probe/work
cat > /tmp/keel-probe/plugin/.claude-plugin/plugin.json <<'EOF'
{ "name": "keel-probe", "version": "0.0.1", "description": "Throwaway probe for keel task 1" }
EOF
cat > /tmp/keel-probe/plugin/settings.json <<'EOF'
{ "subagentStatusLine": { "type": "command", "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/probe.py\"" } }
EOF
cat > /tmp/keel-probe/plugin/probe.py <<'EOF'
import json, os, sys
raw = sys.stdin.buffer.read().decode("utf-8", "replace")
with open("/tmp/keel-probe/log.jsonl", "a") as f:
    f.write(json.dumps({"argv0": sys.argv[0], "env_root": os.environ.get("CLAUDE_PLUGIN_ROOT"), "stdin": raw}) + "\n")
try:
    data = json.loads(raw)
except ValueError:
    sys.exit(0)
for t in data.get("tasks") or []:
    if isinstance(t, dict) and t.get("id"):
        print(json.dumps({"id": t["id"], "content": "PROBE " + str(t.get("model"))}))
EOF
cat > /tmp/keel-probe/plugin/agents/no-write.md <<'EOF'
---
name: no-write
description: Probe agent for keel task 1. Use only when the user names keel-probe:no-write.
model: sonnet
disallowedTools: Edit, Write, NotebookEdit
---

Create the file you are asked to create, using the Write tool. If you have no Write tool, say so
in one line and stop. Do not create the file any other way.
EOF
cd /tmp/keel-probe/work && git init -q . && claude --version
```

- [x] **Step 1.2: Run a session that dispatches the agent, and watch the row** Note: Run by the person in a live session, twice: first with the command using the plugin root variable (no log), then with the absolute path and --debug-file (8 ticks logged). The coordinator did not watch the terminal; it read log.jsonl and debug.log on disk

A user's own `subagentStatusLine` outranks a plugin's, and between two plugins the one loaded last
wins, so first look for another one that would hide the probe's:

```bash
grep -l subagentStatusLine ~/.claude/settings.json ~/.claude/settings.local.json /tmp/keel-probe/work/.claude/settings*.json 2>/dev/null  # supply-chain-scan: allow reads the settings files to look for a competing subagentStatusLine, never writes them
grep -rl subagentStatusLine ~/.claude/plugins 2>/dev/null | head
```

Expected: no output. If either prints a file, note it beside row 1 of the results, and run step 1.2
with that setting moved aside for the session, or read a "settings not applied" result as
unproven rather than as a no.

```bash
cd /tmp/keel-probe/work && claude --plugin-dir /tmp/keel-probe/plugin
```

In the session, send: `Dispatch the keel-probe:no-write agent with this task: create a file named
probe-hello.txt in the current directory containing the word hi. Then tell me what it reported.`

While the agent runs, read its row in the agent panel below the prompt. Expected: `PROBE ` followed
by a model ID. Exit the session when it is done.

- [x] **Step 1.3: Read what the script received, and what the agent could do** Note: Coordinator read log.jsonl and debug.log directly instead of the plan's snippet, which the person's run failed on the first time because no log existed. probe-hello.txt absence was reported by the person

```bash
python3 - <<'EOF'
import json
for line in open("/tmp/keel-probe/log.jsonl"):
    rec = json.loads(line)
    try:
        tasks = json.loads(rec["stdin"]).get("tasks") or []
    except ValueError:
        tasks = []
    print(rec["argv0"], rec["env_root"], [(t.get("description"), t.get("model")) for t in tasks])
EOF
ls /tmp/keel-probe/work/probe-hello.txt
```

Expected: every line's first field is an absolute path ending `/probe.py`, at least one line names
the agent's task with a model ID, and `ls` fails with "No such file or directory". The script runs
on every refresh tick, so read every line rather than the last: the last tick may come after the
agent finished.

**If `/tmp/keel-probe/log.jsonl` does not exist,** the script never ran. Separate the two causes:
replace `\"${CLAUDE_PLUGIN_ROOT}/probe.py\"` in `settings.json` with `/tmp/keel-probe/plugin/probe.py`
and repeat step 1.2. A log now means the variable does not resolve there; still no log means a
plugin's `subagentStatusLine` was not applied at all. Record which.

- [x] **Step 1.4: Record the results here, and commit the plan** Note: The results were recorded and committed in a82e21a. The rm of the probe directory was moved out of this step: step 2.1 reuses the probe plugin, and the coordinator asks before removing it after task 2

Fill the right-hand column below, then:

```bash
git add docs/plans/2026-10-13-harness-held-dispatch-guarantees.md
git commit -m "docs(plans): record the status line and tool-limit probe"
```

The probe directory `/tmp/keel-probe` is kept: step 2.1 reuses its plugin, and the coordinator
removes it after task 2 is committed.

**Probe results**

| Fact | Observed |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}` resolves in a plugin `settings.json` command (yes, no, or "settings not applied") | **no.** With the command `python3 "${CLAUDE_PLUGIN_ROOT}/probe.py"` a full dispatch left no `log.jsonl`, so the script never ran. With the absolute path `python3 /tmp/keel-probe/plugin/probe.py` it ran on all 8 refresh ticks, and its `CLAUDE_PLUGIN_ROOT` was unset (`env_root` null). The plugin's `settings.json` was applied either way: the debug log says `Cached plugin settings with keys: subagentStatusLine`. The first run had no debug log, so the failing command's own error was not seen. |
| Model ID the row received for `keel-probe:no-write` | `claude-sonnet-5-5`, in `tasks[].model`, on the running tick and on every completed tick. The agent's API request in the debug log went to the same model. The main session ran on `claude-sonnet-5-5` too, so this probe cannot show the row's model differing from the parent's. The row also carried `agentType` (`keel-probe:no-write`), `label`, `name`, `effort` and `tokenCount`. |
| `disallowedTools` held: the agent reported no Write tool and `probe-hello.txt` was not created (yes or no) | **yes.** The agent reported it had no Write tool and did not create the file, and it did not fall back to Bash, which it still had. `ls /tmp/keel-probe/work/probe-hello.txt` failed. The report was relayed by the person who ran the session; the debug log shows one turn and no tool use but does not list the agent's tools. |
| `claude --version`, and the date | 2.1.296, 2026-10-13. Observed on the second run, whose debug log names `cc_version=2.1.296`. The first run's version was not recorded: the binary updated from 2.1.291 at 11:06 local, and the work directory was last changed at 11:10. |

**What the results decide.** All three yes: tasks 2 and 3 run as written. `${CLAUDE_PLUGIN_ROOT}`
does not resolve, or the settings were not applied: task 2 stops before step 2.1 and this plan is
amended, because its command depends on it. `disallowedTools` did not hold: task 3 stops before
step 3.1, because the field would claim a restriction nothing enforces. Row 1 was "no" on
2026-10-13, so task 2 was amended; see its opening paragraph and "What the probe changed".

---

### Task 2: show each subagent's resolved model on its row

**Story:** none.
**Amended on 2026-10-13, after task 1.** Row 1 of the probe results is "no": `${CLAUDE_PLUGIN_ROOT}`
does not resolve in a plugin `settings.json` command, and the command runs from the project's
directory, so a path to a script in the plugin has nothing to start from. The script is therefore
inlined into `settings.json` as a `python3 -c` command, and `settings.json` is generated from
`lib/subagent_statusline.py` by a new mode of `tests/generate-harness-artifacts.sh`, the way
`hooks/hooks.json` and `docs/harness-support.md` are generated from their sources. The behaviour
tests run the command read out of `settings.json`, not the source file, because the shipped artifact
is what has to work. Step 2.1 is a second live probe of that exact shape, and everything after it
depends on it. This task runs after tasks 3 and 4, so its anchors name the lines they left.

**What the row keeps and what it loses.** A status line replaces the whole row, not one column of
it (read from the 2.1.296 client by the plan review). The default row is the agent name or type, the
live progress summary or the description, the elapsed time and tokens, and a queued count. The
override keeps the name or type, the description keel wrote, the model and the token count, and
drops the progress summary, the elapsed time and the queued count. That trade is decided: the label
and the model are the point, and the agent type stays so that a `keel-fanout: ` row can be checked
against the agent that carries it, which answers the idea record's open point on screen.

**Run by:** step 2.1 is run before this task is dispatched, by the coordinator, who prepares the
probe, and a person, who runs it in a live session. The implementer's dispatch starts at step 2.2
and carries the filled "Inline probe results" table.
**Files:**
- Create: `lib/subagent_statusline.py` (the readable source; nothing executes this file directly)
- Create: `settings.json` (at the repository root, the plugin root; generated, never edited)
- Modify: `tests/generate-harness-artifacts.sh` (a new mode, `subagent-settings`)
- Modify: `tests/supply-chain-scan.sh` (the plugin `settings.json` joins the `exec` scope)
- Modify: `tests/test-supply-chain.sh`
- Create: `tests/test-subagent-statusline.sh`
- Modify: `tests/run-tests.sh`
- Modify: `lib/harness/capabilities`
- Modify: `docs/harness-support.md` (regenerated, never edited)
- Modify: `docs/standards.md`
- Modify: `docs/06-repo-layout.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: "Inline probe results" rows 4 and 5, from step 2.1 below
- Produces: primitive `subagent_row_model` in `lib/harness/capabilities`, and the claim tag
  `<!-- keel:claim property=subagent_row_model harness=claude -->`. Task 5 reads neither.

**Depends on:** step 2.1's "Inline probe results", with rows 1, 2 and 4 "yes" and row 3 answered.
If row 1, 2 or 4 is "no", stop before step 2.2 and amend this plan again: a status line that does
not run, that runs and is not drawn, or whose model is the parent's and not the agent's, is not
worth building.

**Done when:** `tests/test-subagent-statusline.sh` prints `18 passed, 0 failed` (nine as first
dictated; see the execution record), and
`tests/test-harness-claims.sh`, `tests/test-harness-resolve.sh` and `tests/test-doc-claims.sh` each
exit 0.

- [x] **Step 2.1: Probe the inline command in a live session** Note: Run by the person twice, once by hand with no panel seen, and once by the coordinator in a captured interactive session; see Inline probe results. Row 2 is yes on the captured session only, row 3 was not observed, and the owner chose to proceed

The probe plugin from task 1 is reused. Its `settings.json` is replaced by the shape this task
ships, the script of step 2.4 inlined as `python3 -c '...'`, preceded by four lines that copy stdin
to `/tmp/keel-probe/log-inline.jsonl` so the run leaves evidence. Two agents wait 60 seconds so
their rows stay on screen: one pinned to `sonnet`, one set to `inherit`, and the session runs on a
different parent model, so the two rows can only show the same model if the row reports the parent's
and not the agent's.

A first run on 2026-10-13 (a foreground dispatch, `sleep 25`, no tools pre-approved) proved the
command runs and that the row's model is the agent's own, but not that any row is drawn: the agents
were gone within about ten seconds, probably because the `sleep` prompt cut the wait short, and the
person saw no rows. The docs say the agent panel lists background subagents and say nothing about
foreground ones, so this version tests both, and keeps the first run's findings in the table below.

Prepare, as the coordinator. Save the script text of step 2.4 as
`/tmp/keel-probe/subagent_statusline.py`, then:

```bash
cat > /tmp/keel-probe/prelude.txt <<'EOF'
import io, sys
_raw = sys.stdin.buffer.read()
open("/tmp/keel-probe/log-inline.jsonl", "ab").write(_raw + b"\n")
sys.stdin = io.TextIOWrapper(io.BytesIO(_raw))
EOF
python3 -I - /tmp/keel-probe/subagent_statusline.py /tmp/keel-probe/prelude.txt \
  > /tmp/keel-probe/plugin/settings.json <<'EOF'
import json, sys
code = open(sys.argv[1], encoding="ascii").read()
prelude = open(sys.argv[2]).read()
cmd = "python3 -c '" + (prelude + code).replace("'", "'\\''") + "'"
print(json.dumps({"subagentStatusLine": {"type": "command", "command": cmd}}, indent=2))
EOF
cat > /tmp/keel-probe/plugin/agents/slow.md <<'EOF'
---
name: slow
description: Probe agent for keel task 2. Use only when the user names keel-probe:slow.
model: sonnet
---

Run `sleep 60` with the Bash tool, then reply with the single word done.
EOF
sed -e 's/^name: slow$/name: slow-inherit/' -e 's/^model: sonnet$/model: inherit/' \
    -e 's/keel-probe:slow\./keel-probe:slow-inherit./' \
    /tmp/keel-probe/plugin/agents/slow.md > /tmp/keel-probe/plugin/agents/slow-inherit.md
rm -f /tmp/keel-probe/log-inline.jsonl /tmp/keel-probe/debug2.log
```

Run, by a person, because the status line renders only in an interactive terminal. The session runs
on `haiku` so that it differs from the sonnet agent, and pre-approves `sleep` so that no permission
prompt cuts the minute short:

```bash
cd /tmp/keel-probe/work && claude --model haiku --allowedTools 'Bash(sleep *)' --plugin-dir /tmp/keel-probe/plugin --debug-file /tmp/keel-probe/debug3.log
```

For the background pair, send: `Dispatch the keel-probe:slow agent and the keel-probe:slow-inherit
agent in parallel, both in the background, each with the task "wait until you are finished". Do not
wait for them; tell me when both are running.` Read the panel below the prompt while they run, for
about a minute. When both have finished, for the foreground pair, send: `Now dispatch the same two
agents again in parallel, in the foreground, and wait for both to finish.` Read the screen while
they run. Expected for each row, wherever it appears: the agent type, the description, then
`· <model id>`, then `· <n> tokens`. Then read `/tmp/keel-probe/log-inline.jsonl`, and grep
`subagentStatusLine` in `/tmp/keel-probe/debug3.log` for an `exited` line.

**Inline probe results**

| Fact | Observed |
|---|---|
| 1. The inline `python3 -c` command in a plugin `settings.json` ran (`log-inline.jsonl` has a record per refresh tick, and the debug log has no `subagentStatusLine exited` line) | **yes**, on the first run: 8 ticks logged, two tasks, no `exited` line. Settings applied: `Cached plugin settings with keys: subagentStatusLine` |
| 2. The background pair's rows in the agent panel showed the override: agent type, description, model ID and a token count (what was on screen, in words) | **yes, in a captured session, not on the person's screen.** The coordinator drove a real interactive 2.1.296 session in a 110 by 45 pseudo-terminal and kept the byte stream (`/tmp/keel-probe/pty-run.raw`). The panel under the prompt drew `· Run keel-probe:slow task · claude-sonnet-5-5 · 0 tokens`, later `· 35.6k tokens`, and `· Run keel-probe:slow-inherit task · claude-haiku-5-5 · 0 tokens`; the agent-type prefix is absent from some captured lines only because a terminal repaints changed cells. The person who ran the probe by hand (terminal size unknown, pressed the down arrow once) did not see the model while the agents ran, only at completion and with no token count, and could not say more. That difference is unexplained |
| 3. The foreground pair's rows showed the override, or showed no panel at all (what was on screen, in words) | **not observed.** The harness backgrounded both rounds ("2 background agents launched"), including the round that asked for the foreground, so whether a foreground dispatch gets panel rows is unknown |
| 4. The two model IDs differ: the `slow` row's task carries the sonnet ID and the `slow-inherit` row's task carries the haiku parent's | **yes**, on the first run: `slow` received `claude-sonnet-5-5` and its API request went to `claude-sonnet-5-5`; `slow-inherit` received `claude-haiku-5-5`, the parent's, and its API request went to `claude-haiku-5-5` |
| 5. `claude --version`, the operating system, and the date | 2.1.296 (`cc_version=2.1.296` in the debug log), macOS (Darwin 25.6.0, arm64), 2026-10-13 |

**What the results decide.** Rows 1 and 4 are in. Row 2 yes: build. Row 2 no: the command runs and
its output is not drawn, so a status line nobody sees is not a feature and the task stops. Row 3
yes: build as written. Row 3 "no panel": the feature reaches background dispatches only; stop and
ask, because the standards paragraph and the changelog must then say so, and whether keel's own
dispatches are background ones depends on the harness default, which is not keel's to set.

**Recorded outcome, 2026-10-13.** Rows 1, 2 and 4 are "yes", row 2 on a captured session and not on
the person's own screen; row 3 was not observed. The owner decided to proceed on that evidence. The
claims this task writes are narrowed to match: the standards paragraph and the capability row say
the rows were observed for background agents in a captured session, and that foreground agents, an
installed plugin and Windows were not.

- [x] **Step 2.2: Write the failing test** Note: Delegated implementer extracted the test from the plan by script; later extended from nine to eighteen cases after review (see the execution record)

Create `tests/test-subagent-statusline.sh`, executable (`chmod +x`):

```bash
#!/usr/bin/env bash
# The subagent status line: the settings.json that registers it, and the lib/subagent_statusline.py
# it is generated from. Idea record docs/ideas/harness-held-dispatch-guarantees.md, variant A.
#
# What it must do: put the resolved model beside the label keel wrote, keep the model when the row
# is narrow, and print nothing for anything it cannot read. Printing nothing is the safe failure:
# the harness keeps its default row for any task the script does not name, so a script that cannot
# parse its input leaves the panel as it was rather than blank.
#
# Every behaviour case runs the command read out of settings.json, with `sh -c` and a minimal
# environment, as the harness does, and not the source file: the shipped artifact is what has to
# work. settings.json inlines the script because ${CLAUDE_PLUGIN_ROOT} does not resolve in a plugin
# settings.json (task 1 of docs/plans/2026-10-13-harness-held-dispatch-guarantees.md).
#
# The `condition && ok || bad` idiom is safe here because both helpers return 0.
# shellcheck disable=SC2015
# Single quotes are deliberate: the fixtures are literal JSON.
# shellcheck disable=SC2016
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

# The command the harness runs. Empty when settings.json is missing or unreadable, and every case
# below then fails, because an empty command prints nothing and "prints nothing" is also what a
# correct script does for input it cannot read: without that guard a missing file passed.
CMD="$(python3 -I -c 'import json; print(json.load(open("settings.json"))["subagentStatusLine"]["command"])' 2>/dev/null)"
row() { [ -n "$CMD" ] && printf '%s' "$1" | env -i PATH="$PATH" LC_ALL=C sh -c "$CMD" 2>/dev/null; }

# 1. The point of the script: the model sits after the label, and the label keeps its place first,
#    because a narrow pane truncates the end of a row and the label is what the dispatch wrote.
got="$(row '{"columns":120,"tasks":[{"id":"t1","type":"local_agent","status":"running","description":"inherit: review task 4","model":"claude-opus-5-5","tokenCount":12345}]}')"
want='{"id": "t1", "content": "inherit: review task 4 · claude-opus-5-5 · 12.3k tokens"}'
[ "$got" = "$want" ] && ok "a row with a model shows it after the label" || bad "a row with a model shows it after the label" "got: $got"

# 2. A model is omitted until it resolves. No line means the harness's default row, not a guess.
got="$(row '{"columns":120,"tasks":[{"id":"t2","type":"local_agent","status":"running","description":"keel-fanout: read lib","tokenCount":10}]}')"
[ -n "$CMD" ] && [ -z "$got" ] && ok "a row with no model yet keeps the default rendering" || bad "a row with no model yet keeps the default rendering" "got: $got"

# 3. Each task is judged on its own. The default row leads with the subagent name, or the agent type
#    when it has no name, and an override replaces the whole row, so the lead has to be kept: the
#    agent type is how a keel-fanout: label is checked against the agent that carries it.
got="$(row '{"columns":120,"tasks":[{"id":"a","name":"rev","description":"inherit: x","model":"m1","tokenCount":1},{"id":"b","description":"keel-fanout: y","tokenCount":5},{"id":"c","agentType":"keel:keel-fanout","description":"keel-fanout: z","model":"m2","tokenCount":2}]}')"
want='{"id": "a", "content": "rev · inherit: x · m1 · 1 token"}
{"id": "c", "content": "keel:keel-fanout · keel-fanout: z · m2 · 2 tokens"}'
[ "$got" = "$want" ] && ok "only rows with a model are overridden, and the row keeps its name or agent type" || bad "only rows with a model are overridden, and the row keeps its name or agent type" "got: $got"

# 4. Narrow: the description gives way first, then the token count, and the model never does.
got="$(row '{"columns":40,"tasks":[{"id":"n","description":"keel-fanout: read every file under lib/","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "keel... · claude-sonnet-5-5 · 500 tokens"}'
[ "$got" = "$want" ] && ok "a narrow row shortens the label before the model" || bad "a narrow row shortens the label before the model" "got: $got"

got="$(row '{"columns":20,"tasks":[{"id":"n","description":"keel-fanout: read every file under lib/","model":"claude-sonnet-5-5","tokenCount":500}]}')"
want='{"id": "n", "content": "claude-sonnet-5-5"}'
[ "$got" = "$want" ] && ok "a row too narrow for anything else still shows the model" || bad "a row too narrow for anything else still shows the model" "got: $got"

# 5. Unreadable input prints nothing and exits 0, for every shape it can arrive in.
all_quiet=yes
[ -n "$CMD" ] || all_quiet="no: settings.json holds no command"
for input in 'not json' '[]' '{}' '{"tasks":"x"}' '{"tasks":[1,"a",null]}'; do
    out="$(printf '%s' "$input" | env -i PATH="$PATH" LC_ALL=C sh -c "$CMD" 2>&1)"; rc=$?
    { [ -z "$out" ] && [ "$rc" -eq 0 ]; } || { all_quiet="no: input $input gave rc=$rc out=$out"; break; }
done
[ "$all_quiet" = yes ] && ok "unreadable input prints nothing and exits 0" || bad "unreadable input prints nothing and exits 0" "$all_quiet"

# 6. A description cut inside a surrogate pair (a JS string cut by index) arrives as a lone surrogate
#    escape. Encoding it as strict UTF-8 raises, and one bad row would lose every other row in the
#    same tick, so it is replaced. The backslash is built with printf because the fixture needs a
#    JSON escape inside a shell string.
bs="$(printf '\134')"
got="$(row '{"columns":120,"tasks":[{"id":"s","description":"x '"${bs}"'ud83d","model":"m"},{"id":"t","description":"ok","model":"m"}]}')"
want='{"id": "s", "content": "x ? · m"}
{"id": "t", "content": "ok · m"}'
[ "$got" = "$want" ] && ok "a lone surrogate in one row does not lose the others" || bad "a lone surrogate in one row does not lose the others" "got: $got"

# 7. The registration. Only `agent` and `subagentStatusLine` take effect from a plugin settings.json
#    and every other key is dropped at load, so a second key here would be a setting nobody reads.
#    The command must not lean on the plugin root, which is the variable that does not resolve.
if python3 -I - <<'PY'
import json
s = json.load(open("settings.json"))
assert set(s) == {"subagentStatusLine"}, s
c = s["subagentStatusLine"]
assert set(c) == {"type", "command"} and c["type"] == "command", c
cmd = c["command"]
assert cmd.startswith("python3 -c '") and cmd.endswith("'"), cmd[:40]
assert "CLAUDE_PLUGIN_ROOT" not in cmd
PY
then ok "settings.json registers one inline command and nothing else"
else bad "settings.json registers one inline command and nothing else" "see the assertion above"
fi

# 8. The file is the generator's output for the current source, byte for byte. Without this a person
#    edits lib/subagent_statusline.py, every case above still passes against the old inlined copy,
#    and what ships is not what was reviewed.
if tests/generate-harness-artifacts.sh subagent-settings 2>/dev/null | cmp -s - settings.json
then ok "settings.json is what the generator makes from lib/subagent_statusline.py"
else bad "settings.json is what the generator makes from lib/subagent_statusline.py" "regenerate it: tests/generate-harness-artifacts.sh subagent-settings > settings.json"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

That is nine cases: 1, 2, 3, two under 4, 5, 6, 7 and 8.

- [x] **Step 2.3: Run it and watch it fail** Note: Implementer pasted the red run: 0 passed, 9 failed, with the registration case traceback; the coordinator did not witness it but reproduced the same in a scratch checkout while reviewing the plan

Run: `tests/test-subagent-statusline.sh`
Expected: exit 1, `0 passed, 9 failed`, with a Python traceback from the registration case naming
the missing `settings.json`. Five of the FAIL lines print an empty `got:`, which is the point:
nothing produced a row. Only the unreadable-input and registration cases name the missing file, and
the generated-file case says to regenerate it. **If any case passes here, stop:** it passes against
nothing, and needs a guard before it proves anything. Cases 2 and 5 are the ones that can, which is
why both check `$CMD`.

- [x] **Step 2.4: Write the source, the generator mode and the generated file** Note: Source, generator mode and settings.json written from the plan's blocks; cmp proved them identical. The shipped command later gained -I and the source gained text cleaning, by review

Create `lib/subagent_statusline.py`, mode 644 (the harness runs the inlined copy, never this file).
It is ASCII only, because the generator refuses anything else: the command crosses a shell and an
argument list, and a non-ASCII byte there is a locale question this task will not ask. The middle
dot is built with `chr(0xB7)`.

```python
"""Rewrite each subagent row to show the model it runs on, beside the label keel wrote.

Claude Code runs this as the subagentStatusLine on every refresh tick, with one JSON object on
stdin: a `columns` width and a `tasks` array. It prints one {"id", "content"} JSON line per row it
overrides, and a row it does not name keeps the default rendering. Anything it cannot read prints
nothing, so the panel falls back to the default rows.
"""
import json
import sys

SEP = " " + chr(0xB7) + " "
ELLIPSIS = "..."


def _tokens(n):
    if isinstance(n, bool) or not isinstance(n, (int, float)) or n < 0:
        return ""
    n = int(n)
    if n >= 1000:
        return f"{n / 1000:.1f}k tokens"
    return "1 token" if n == 1 else f"{n} tokens"


def render(task, columns):
    """The row body for one task, or None to leave the default row alone."""
    tid = task.get("id")
    model = task.get("model")
    if not (isinstance(tid, str) and tid and isinstance(model, str) and model):
        return None
    desc = task.get("description")
    if not isinstance(desc, str):
        desc = ""
    # The default row leads with the subagent name, or its agent type when it has none. Keep that:
    # an override replaces the whole row, and the agent type is how a keel-fanout: label is checked
    # against the agent that actually carries it.
    lead = task.get("name")
    if not (isinstance(lead, str) and lead):
        lead = task.get("agentType")
    if isinstance(lead, str) and lead:
        desc = lead + SEP + desc if desc else lead
    tok = _tokens(task.get("tokenCount"))
    tails = [SEP + model + SEP + tok, SEP + model] if tok else [SEP + model]
    if not desc:
        tails = [t[len(SEP):] for t in tails]
    if isinstance(columns, bool) or not isinstance(columns, int) or columns <= 0:
        return desc + tails[0]
    # The label gives way first, then the token count. The model never does: it is the one thing on
    # the row nothing else shows.
    for tail in tails:
        if len(desc) + len(tail) <= columns:
            return desc + tail
        room = columns - len(tail)
        if desc and room >= len(ELLIPSIS) + 1:
            return desc[: room - len(ELLIPSIS)] + ELLIPSIS + tail
    return model


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
    except ValueError:
        return 0
    if not isinstance(data, dict):
        return 0
    tasks = data.get("tasks")
    if not isinstance(tasks, list):
        return 0
    columns = data.get("columns")
    lines = []
    for task in tasks:
        if not isinstance(task, dict):
            continue
        content = render(task, columns)
        if content is not None:
            lines.append(json.dumps({"id": task["id"], "content": content}, ensure_ascii=False))
    if lines:
        # Bytes, not text: under a C locale a text write of the middle dot raises. A lone surrogate
        # (a string cut inside a pair) cannot be encoded strictly, and one bad row must not lose
        # the others in the same tick, so it is replaced.
        sys.stdout.buffer.write(("\n".join(lines) + "\n").encode("utf-8", "replace"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

In `tests/generate-harness-artifacts.sh`, make four edits:

1. In the header, after the line `#        tests/generate-harness-artifacts.sh codex  > hooks/hooks.codex.json`, add the line
   `#        tests/generate-harness-artifacts.sh subagent-settings > settings.json`.
2. Directly above the line `harness="${1:-}"`, add this function, with its comment:

```bash
# ---- the subagent status line registration ---------------------------------
#
# settings.json at the plugin root registers keel's subagent status line, and it INLINES the script
# as a `python3 -c` command instead of naming a file: ${CLAUDE_PLUGIN_ROOT} does not resolve in a
# plugin settings.json (task 1 of docs/plans/2026-10-13-harness-held-dispatch-guarantees.md), so a
# path to lib/subagent_statusline.py would have nothing to start from. Generated for the reason the
# manifests are: the source file is the one a person reads and edits, and a hand-kept copy of it
# inside a JSON string is the one that goes stale. tests/test-subagent-statusline.sh diffs this
# output against the committed file.
#
# The source must be ASCII. The command crosses a shell and an argument list, and what a non-ASCII
# byte does there depends on the locale, so the generator refuses it rather than guess. Each single
# quote in the source is closed, escaped and reopened, which is how a shell single-quotes it.
subagent_settings() {
    python3 -I - "$ROOT/lib/subagent_statusline.py" <<'PY'
import json, sys
code = open(sys.argv[1], encoding="ascii").read()
cmd = "python3 -c '" + code.replace("'", "'\\''") + "'"
print(json.dumps({"subagentStatusLine": {"type": "command", "command": cmd}}, indent=2))
PY
}

```

3. Change the usage line to `usage: %s <harness|support-page|subagent-settings>\n`.
4. Directly after the line `if [ "$harness" = support-page ]; then support_page; exit 0; fi`, add:

```bash
if [ "$harness" = subagent-settings ]; then subagent_settings; exit 0; fi
```

Generate the file: `tests/generate-harness-artifacts.sh subagent-settings > settings.json`.

In `tests/run-tests.sh`, after the line `add "tests/test-agents.sh" "tests/test-agents.sh"`, add:

```bash
add "tests/test-subagent-statusline.sh" "tests/test-subagent-statusline.sh"
```

- [x] **Step 2.5: Run it and watch it pass** Note: Green, and both mutations failed exactly the case named. Coordinator re-ran the test (18 passed, also under /bin/bash 3.2) and the generator comparisons

Run: `tests/test-subagent-statusline.sh`
Expected: `9 passed, 0 failed`, exit 0.

Then prove two cases can fail, on copies outside the tree. The test changes into its own parent
directory, so copy `settings.json`, `lib/` and `tests/` into one temporary directory and
run the copy of the test there.

- Narrow rows: in the copy of `lib/subagent_statusline.py`, change `room >= len(ELLIPSIS) + 1` to
  `room >= 0`, regenerate the copy of `settings.json` with the copy of the generator
  (`tests/generate-harness-artifacts.sh subagent-settings > settings.json`), and run the copied
  test. Expected: one FAIL, "a row too narrow for anything else still shows the model", with
  content `keel-fanout: read every file under l... · claude-sonnet-5-5`.
- Staleness: restore the copy of `settings.json` from the tree, edit only the copy of the source
  (for example change `ELLIPSIS = "..."` to `ELLIPSIS = "~"`), and run the copied test. Expected:
  one FAIL, "settings.json is what the generator makes from lib/subagent_statusline.py", with every
  behaviour case still passing, which is exactly the gap that case exists to close.

Say in the report what each printed, and leave no copy in the tree.

- [x] **Step 2.6: Bring `settings.json` into the supply-chain scan** Note: Implementer pasted the red run (expected exit 1, got 0) before the scope change; 64 then 65 passed after it was gated to plugin repositories. Coordinator re-ran test-supply-chain

`tests/supply-chain-scan.sh` looks for a network call in a file only if it sits under `bin/`,
`hooks/`, `lib/`, `tests/` or `.github/workflows/`, or has the executable bit (its `in_scope`
function). `settings.json` holds a command the harness runs on every refresh tick of every session
and is none of those, so a `curl` appended to it passes the scan, and the only thing between a
hostile edit and the install is case 8 of the new test, which compares the file with the generator.
This step closes that, test first.

In `tests/test-supply-chain.sh`, after the line
`run "a network call inside a hook is rejected" 1 m_nethook`, add:

```bash
m_netsettings() { printf '{"subagentStatusLine":{"type":"command","command":"curl -s https://example.com/x"}}\n' > "$1/settings.json"; }
run "a network call inside the plugin settings.json is rejected" 1 m_netsettings
```

Run: `tests/test-supply-chain.sh`
Expected: exactly one FAIL, "a network call inside the plugin settings.json is rejected: expected
exit 1, got 0", every other case passing. **If it passes, stop:** the scan already covers the file
and this step is not needed.

In `tests/supply-chain-scan.sh`, in `in_scope`, change the line
`bin/*|hooks/*|lib/*|tests/*|.github/workflows/*) return 0 ;;` to
`bin/*|hooks/*|lib/*|tests/*|.github/workflows/*|settings.json) return 0 ;;`, and in the comment
that lists the scopes change
`exec    bin/, hooks/, lib/, tests/, .github/workflows/, and anything with the executable bit` to
`exec    bin/, hooks/, lib/, tests/, .github/workflows/, the plugin settings.json, and anything with the executable bit`.

Run: `tests/test-supply-chain.sh`
Expected: every case passes, the new one included.

Run: `tests/supply-chain-scan.sh`
Expected: the one known finding named in step 2.8 and nothing else; the generated `settings.json`
adds none.

- [x] **Step 2.7: Declare it, per ADR-0004** Note: Row, standards paragraph, stream sentence, python3 sentence, layout and changelog written, then calibrated by review. Placeholders filled: macOS, claude-haiku-5-5, claude-sonnet-5-5, 2.1.296, 2026-10-13

In `lib/harness/capabilities`, insert this row on the line after the row that begins
`provides|claude|agent_tool_denylist|`, filling the bracketed values from "Inline probe
results" rows 4 and 5:

```text
provides|claude|subagent_row_model|probe:a plugin settings.json subagentStatusLine, written as an inline python3 -c command because CLAUDE_PLUGIN_ROOT does not resolve there and loaded with --plugin-dir on <operating system from row 5>, ran for two plugin agents under a parent on <parent model ID from row 4>, showed <sonnet agent model ID from row 4> on the sonnet agent's row and had both rows overridden in a captured interactive session of background agents, step 2.1 of docs/plans/2026-10-13-harness-held-dispatch-guarantees.md|<version from row 5>|<date from row 5>
```

There is deliberately no Codex row: nothing has checked whether Codex renders a dispatch row at all.

Regenerate the support page, and confirm only that one row changed:

```bash
tests/generate-harness-artifacts.sh support-page > docs/harness-support.md
git diff --stat docs/harness-support.md
```

In `docs/standards.md`, in the section "A dispatch names its model, and says so", insert this
paragraph after the paragraph that contains the sentence beginning `**Confirmed on Claude Code**`
(it ends with `references/parallel-batches.md`.), and so before the paragraph task 3 added:

```markdown
**On Claude Code the model is shown as well as stated, since 2026-10-13.** <!-- keel:claim property=subagent_row_model harness=claude -->
keel's `settings.json` sets a subagent status line that writes each running subagent's resolved
model after its description, so a row labelled `keel-fanout: ` that runs on the main model is
visible to the person the label is for. The agent type stays on the row, so the same row shows
whether a `keel-fanout: ` dispatch ran as the `keel-fanout` agent. It shows and does not judge: a
flag would have to know how each harness resolves a profile. A status line replaces the whole row,
so the default row's live progress summary, elapsed time and queued count are not kept. The command
is the script inlined, generated from `lib/subagent_statusline.py` by
`tests/generate-harness-artifacts.sh subagent-settings`, because `${CLAUDE_PLUGIN_ROOT}` does not
resolve in a plugin `settings.json` and a path to the script would have nothing to start from. A
user's own `subagentStatusLine` takes precedence over the plugin's. Observed on macOS with
`--plugin-dir`, for background agents; foreground agents, an installed plugin and Windows were not
observed. Nothing is shown on Codex.
```

In the same section, the paragraph beginning `**The stream does not replace the announcement` says
an interactive developer "has no way to see which model a dispatch went to except by being told"
and calls the announcement "their only cost signal". That stops being true on Claude Code with this
task. Replace the two sentences that begin `It is not available to a developer in an interactive
session` and end `That line is their only cost signal,` (they span a line break) with the text
below, and rewrap the whole paragraph at 100 columns afterwards, because the replacement starts
partway along a line:

```markdown
It is not available to a developer in an interactive session. On Claude Code, since 2026-10-13, the
subagent status line shows each running row's resolved model; on any other harness the developer
has no way to see which model a dispatch went to except by being told. There that line is their
only cost signal,
```

In the paragraph that begins `The eval gap is temporary`, replace its last sentence, which begins
with the backticked word python3 followed by "departure is permanent and scoped to one command" and
ends "gained a hard dependency.", with:

```markdown
The `python3`
departure is permanent and scoped to one command; nothing else in `bin/keel` gained a hard
dependency. The subagent status line, inlined from `lib/subagent_statusline.py` into
`settings.json`, also runs on `python3` and is not a hard dependency: without it the command exits
non-zero, and the 2.1.296 client answers by showing the default rows (read from its source, not
probed).
```

In `docs/06-repo-layout.md`, inside the fenced tree:

- replace the line `│   └── merge-claude-md.sh` with the two lines
  `│   ├── merge-claude-md.sh` and `│   └── subagent_statusline.py`;
- after the line `│   ├── test-session-start.sh`, add `│   ├── test-subagent-statusline.sh`;
- replace the last line of the tree, `└── VERSION`, with `├── VERSION`, and add after it
  `└── settings.json                       # generated by tests/generate-harness-artifacts.sh: the subagent status line. Claude Code only`,
  since `git ls-files` sorts it after `VERSION`.

In `CHANGELOG.md`, add this as the last bullet under `## Unreleased`:

```markdown
- On Claude Code, keel's plugin `settings.json` sets a subagent status line that shows each running
  subagent's resolved model after the label keel wrote, so `inherit: ` and `keel-fanout: ` can be
  checked by the person watching, and the row keeps its agent type, so a `keel-fanout: ` row shows
  whether it ran as the `keel-fanout` agent. It shows the model and does not judge it. A status
  line replaces the whole row, so the default row's live progress summary, elapsed time and queued
  count are not kept. A user's own `subagentStatusLine` takes precedence. The script is inlined as a
  `python3 -c` command, generated from `lib/subagent_statusline.py` by
  `tests/generate-harness-artifacts.sh subagent-settings`, because `${CLAUDE_PLUGIN_ROOT}` does not
  resolve in a plugin `settings.json`. The supply-chain scan now covers that file. No label that
  lied is on record: this makes the label checkable, it does not fix a recorded failure. Not
  available on Codex.
```

- [x] **Step 2.8: Stage, run the suite at the unit boundary, then hand over** Note: Staged by name plus four citation repairs. test-harness-claims 32, test-harness-resolve 56, test-doc-claims 63 passed; run-tests.sh ran whole and exits 1 only on the step 1.2 finding

Stage first: `tests/test-doc-claims.sh` reads `git ls-files`, so an unstaged `settings.json` is
invisible to its layout check and the check passes whether or not the tree line was added.

```bash
git add lib/subagent_statusline.py settings.json tests/generate-harness-artifacts.sh \
        tests/test-subagent-statusline.sh tests/supply-chain-scan.sh tests/test-supply-chain.sh \
        tests/run-tests.sh lib/harness/capabilities docs/harness-support.md docs/standards.md \
        docs/06-repo-layout.md CHANGELOG.md
git status --porcelain
```

Run: `tests/test-harness-claims.sh && tests/test-harness-resolve.sh && tests/test-doc-claims.sh`
Expected: each exits 0.

Run: `tests/run-tests.sh`
Expected: exactly one red, `tests/supply-chain-scan.sh` `[persist-user-claude]`, on the `grep` of
the user's Claude settings in step 1.2 of this plan. Any other red is this task's. Name it in the
report.

Stop there. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(plugin): show each subagent's resolved model beside its label"`.
After that commit, the coordinator asks whether to remove `/tmp/keel-probe`, which holds the probe
plugin and its logs.

**Execution record, written when task 2 ran on 2026-10-13.**

- **Order and probe.** Task 2 ran last, after tasks 3 and 4. Step 2.1 ran before the dispatch: twice
  by the person, who saw no rows, and once by the coordinator as a captured session in a
  pseudo-terminal, which is the evidence for row 2. Row 3 was not observed and the owner proceeded.
- **Delegated.** One implementer, a spec pass and a quality pass at `inherit`, then three rounds of
  fixes, each followed by a delta review. Nothing blocked at any pass.
- **The landed text differs from the blocks above, by review findings, and the files hold the true
  text.** The shipped command is `python3 -I -c`, not `python3 -c`: the harness runs it from the
  project's directory, and a plain `-c` would import a `json.py` found there. The script cleans the
  description, name, agent type and model of non-printable characters, because the harness draws
  `content` as it is and an ESC or OSC sequence in a label could swallow the model. The test went
  from nine cases to eighteen: both a name and an agent type, a missing `columns`, the token count
  giving way before the model, control characters in a label (three cases), the decoy `json.py`, and
  the lone surrogate moved into the row id so the strict-encode defence is still exercised. The
  claims in the standards paragraph and the changelog were narrowed to what was observed, and the
  agent-type claim to an unnamed agent. Three citations in dated idea records were moved to phrase
  anchors.
- **A consider promoted to should-fix by the coordinator.** Putting the root `settings.json` in the
  scan's executable scope would have made `keel scan` and the pre-push hook flag any project's own
  root `settings.json` containing a word such as `curl`, with a finding nothing can suppress. The
  scope now applies only in a plugin repository, with a test for each side.
- **Beyond the Files list.** One token in `docs/plans/2026-08-17-release-readiness.md` (a citation
  of `docs/standards.md` moved by the new lines) and the three citations above. The 2026-08-17
  pointer was already wrong in meaning before this task; the shift only keeps the validator green.
- **Considers skipped on purpose:** wide-character display width; a per-row try/except (a `NaN` or
  infinite `tokenCount` would crash a tick, and the harness cannot emit one); the generator's
  handling of a NUL byte, an empty source or a failed redirect; the cleaning dropping a no-break
  space or a zero-width joiner instead of spacing it; a guard on the decoy case's `mktemp`;
  `agentType` left uncleaned not being pinned by a test (it comes from the agent definition, not the
  dispatching model); token counts at a million printing as `1000.0k`; the citations that were
  already wrong at HEAD (`docs/snapshot.md`, `tests/evals/results.md`, dated plans).
- **What is not established.** Foreground agents, a named agent, an installed plugin, Windows and a
  user's own `subagentStatusLine` taking precedence were not observed. The probed command was a
  plain `python3 -c` of an earlier version of the script, so the shipped command has run only under
  `sh -c` in the suite. The person's own run showed the model only at completion and without a token
  count, and why is unexplained.
- **The same red as tasks 3 and 4.** `tests/run-tests.sh` ran whole twice, and exits 1 only on the
  step 1.2 supply-chain finding. `ruff` was not run (CI only). The last wording-only edit, to the
  changelog and the standards paragraph, was checked by the doc, claim and citation tests and not by
  a third whole run.
- **After the branch review (`review-code`, 2026-10-13).** Two passes found nothing blocking and the
  owner approved fixing the should-fix items, so the landed behaviour differs again from the blocks
  above. The row now overrides only keel-labelled rows (`inherit: ` and `keel-fanout: `), so other
  plugins' and users' agents keep their default row (per the vendor docs, not observed). On a narrow
  pane a row gives way in this order: the lead, then the token count, then the end of the label,
  never the model; the earlier order cut the label first, so widening a pane by one column could
  shorten it. The exact-fit and ellipsis boundaries are pinned, a blank name no longer beats the
  agent type, the changelog bullet restates that no lying label is on record, and the `keel-fanout`
  claim names the three denied tools and not "the file-editing tools". The test is 37 assertions. A
  sweep of 99,600 rows over 166 widths found no crash, no overflow, no garbled row and no label cut
  when it fits. Not fixed: the lead can reappear at a narrower width, because it is shortened only
  when room is left (the label is never cut by it); `agentType` is trusted as the agent definition's
  own text; the considers listed by the reviewers, such as the missing `python3` guard, were left.

---

### Task 3: `keel-fanout` cannot edit files

**Story:** none.
**Files:**
- Modify: `agents/keel-fanout.md`
- Create: `tests/test-agents.sh`
- Modify: `tests/run-tests.sh`
- Modify: `lib/harness/capabilities`
- Modify: `docs/harness-support.md` (regenerated, never edited)
- Modify: `docs/standards.md`
- Modify: `docs/06-repo-layout.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: "Probe results" rows 3 and 4, from task 1
- Produces: primitive `agent_tool_denylist` in `lib/harness/capabilities`, and the claim tag
  `<!-- keel:claim property=agent_tool_denylist harness=claude -->`

**Depends on:** task 1, with row 3 of its results "yes". It runs after task 2 because both edit
`tests/run-tests.sh`, `lib/harness/capabilities`, `docs/standards.md`, `docs/06-repo-layout.md` and
`CHANGELOG.md`, but it does not need task 2's work: where task 2 stopped on its probe row, each
anchor below names the line to use instead.

**Done when:** `tests/test-agents.sh` prints `2 passed, 0 failed`, and
`tests/test-harness-claims.sh` exits 0.

- [x] **Step 3.1: Write the failing test** Note: Delegated implementer created the test and the run-tests line (fallback anchor); the test's parser was later rewritten after review, see the execution record

Create `tests/test-agents.sh`, executable (`chmod +x`):

```bash
#!/usr/bin/env bash
# What keel's shipped agents may do, read from their frontmatter.
#
# keel-fanout reads and reports leads; it never writes. Until 2026-10-13 that was a sentence in its
# body, and a sentence binds only as far as the model follows it. The frontmatter field is enforced
# by Claude Code (task 1 of docs/plans/2026-10-13-harness-held-dispatch-guarantees.md probed it).
# Bash is deliberately NOT denied: fan-out reading runs `git log` and `grep`, and the user chose
# edits-only on 2026-10-13, so a Bash command could still change a file. This test pins both halves.
#
# shellcheck disable=SC2015
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

f=agents/keel-fanout.md
fm="$(awk '/^---$/{c++; if(c>=2) exit; next} c==1' "$f")"
denied="$(printf '%s\n' "$fm" | sed -n 's/^disallowedTools:[[:space:]]*//p')"

missing=""
for t in Edit Write NotebookEdit; do
    case ", $denied," in *", $t,"*) ;; *) missing="$missing $t" ;; esac
done
[ -z "$missing" ] && ok "keel-fanout is denied every file-editing tool" \
  || bad "keel-fanout is denied every file-editing tool" "not denied:$missing (disallowedTools: '$denied')"

case ", $denied," in
  *", Bash,"*) bad "keel-fanout keeps Bash and sets no tools allowlist" "Bash is denied, which breaks git log and grep reads" ;;
  *) printf '%s\n' "$fm" | grep -q '^tools:' \
       && bad "keel-fanout keeps Bash and sets no tools allowlist" "a tools: line narrows what it inherits" \
       || ok "keel-fanout keeps Bash and sets no tools allowlist" ;;
esac

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

In `tests/run-tests.sh`, after the line task 2 added, or after the line
`add "tests/test-plan.sh"        "tests/test-plan.sh"` if task 2 did not land, add:

```bash
add "tests/test-agents.sh" "tests/test-agents.sh"
```

- [x] **Step 3.2: Run it and watch it fail** Note: Implementer pasted the failing output before adding the field (1 passed, 1 failed); the coordinator did not witness it. The final parser was mutation-tested by two reviewers on copies

Run: `tests/test-agents.sh`
Expected: exit 1, `1 passed, 1 failed`. The FAIL is "keel-fanout is denied every file-editing
tool", naming all three tools. The second case passes today and must keep passing.

- [x] **Step 3.3: Add the field** Note: One line after model: sonnet in agents/keel-fanout.md; coordinator read the staged diff

In `agents/keel-fanout.md`, insert one line directly after the line `model: sonnet`:

```yaml
disallowedTools: Edit, Write, NotebookEdit
```

- [x] **Step 3.4: Run it and watch it pass** Note: Coordinator re-ran tests/test-agents.sh (2 passed, 0 failed, also under /bin/bash 3.2) and validate-skills (0 FAIL, 10 WARN)

Run: `tests/test-agents.sh`
Expected: `2 passed, 0 failed`. Then `tests/validate-skills.sh`: 0 FAIL, 10 WARN, because the agents
rule reads name, description and model and ignores other fields.

- [x] **Step 3.5: Declare it, per ADR-0004** Note: Row values 2.1.296 and 2026-10-13 from probe row 4; support page regenerated and identical to the generator; standards paragraph and changelog bullet reworded after review (see the execution record); no Codex row

In `lib/harness/capabilities`, insert on the line after the `subagent_row_model` row task 2 added,
or after the row that begins `provides|claude|validated_word_ceiling|` if task 2 did not land,
filling the bracketed values from "Probe results" row 4:

```text
provides|claude|agent_tool_denylist|probe:a plugin agent with disallowedTools Edit, Write, NotebookEdit reported no Write tool and created no file, task 1 of docs/plans/2026-10-13-harness-held-dispatch-guarantees.md|<version from row 4>|<date from row 4>
```

No Codex row: `lib/harness/codex.sh` writes `.codex/agents/keel-fanout.toml` with a model and an
effort, and nothing has checked whether that format can deny a tool.

Regenerate: `tests/generate-harness-artifacts.sh support-page > docs/harness-support.md`.

In `docs/standards.md`, after the paragraph task 2 added, or if task 2 did not land, after the
paragraph that contains the sentence beginning `**Confirmed on Claude Code**`, insert:

```markdown
**On Claude Code `keel-fanout` cannot edit files, since 2026-10-13.** <!-- keel:claim property=agent_tool_denylist harness=claude -->
Its agent file sets `disallowedTools: Edit, Write, NotebookEdit`, because a fan-out reports leads
and a reader that edits is a writer nobody reviewed. Bash stays, because fan-out reading runs
`git log` and `grep`, so a Bash command could still change a file. Codex's agent file carries no
equivalent, and nothing claims one.
```

In `docs/06-repo-layout.md`, immediately above the line `│   ├── test-apex-export.sh`, add
`│   ├── test-agents.sh`.

In `CHANGELOG.md`, add as the last bullet under `## Unreleased`:

```markdown
- `keel-fanout` cannot edit files on Claude Code: `agents/keel-fanout.md` disallows `Edit`, `Write`
  and `NotebookEdit`, and `tests/test-agents.sh` pins it. Bash stays, because fan-out reading runs
  `git log` and `grep`, so a Bash command could still change a file. No Codex equivalent is
  claimed.
```

- [x] **Step 3.6: Stage, run the suite at the unit boundary, then hand over** Note: Staged by name plus one dated-plan cell the checker flagged. test-harness-claims 32, test-harness-resolve 56, test-doc-claims 63 passed. run-tests.sh ran whole and exits 1 only on the step 1.2 supply-chain finding

```bash
git add agents/keel-fanout.md tests/test-agents.sh tests/run-tests.sh lib/harness/capabilities \
        docs/harness-support.md docs/standards.md docs/06-repo-layout.md CHANGELOG.md
git status --porcelain
```

Run: `tests/test-harness-claims.sh && tests/test-harness-resolve.sh && tests/test-doc-claims.sh`
Expected: each exits 0.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named.

Stop there. **Do not commit.** The coordinator commits with
`git commit -m "feat(agents): keel-fanout cannot edit files"`.

**Execution record, written when task 3 ran on 2026-10-13.**

- **Order.** Task 3 ran after task 4 and with task 2 stopped on its probe row (row 1 of the probe
  results is "no"), so every fallback anchor in steps 3.1 and 3.5 applied, and its `CHANGELOG.md`
  bullet follows task 4's.
- **Delegated.** One implementer, a spec pass and a quality pass at `inherit`, then two rounds of
  fixes, each followed by a delta review. Nothing blocked at any pass.
- **The landed text differs from the blocks above, by review findings, and the files hold the true
  text.** The headline "cannot edit files" overclaimed: what holds is that the agent file denies the
  three tools, Bash stays, and nothing pins that a dispatch labelled `keel-fanout: ` selects that
  agent. The `docs/standards.md` paragraph and the changelog bullet say so, and the commit message
  is `feat(agents): deny keel-fanout the file-editing tools` for the same reason. The test's parser
  was rewritten because the dictated one went red on forms a harness reads the same way (CRLF,
  trailing spaces, quotes, no space after commas, a trailing comment) and passed on two it should
  reject (a comment inside a quoted value, a repeated key). It now compares tokens exactly, fails
  closed on a repeated key or a token that is not a tool name, and case 2 fails when the list cannot
  be read. A removed field therefore prints `0 passed, 2 failed`, not the `1 passed, 1 failed` of
  step 3.2. The done condition, `2 passed, 0 failed`, holds as written.
- **Beyond the Files list.** One table cell in
  `docs/plans/2026-09-05-tiered-multi-harness-support.md` was repointed from a line number in
  `tests/run-tests.sh` to the phrase form `tests/run-tests.sh#capped at 4 concurrent`, because the
  new line in that file moved the cited comment and `validate-citations.sh` failed. A sibling bare
  `:65` at line 1436 of that plan is invisible to the checker and was left.
- **Considers skipped on purpose:** a check that fails when the closing `---` is missing or carries
  trailing whitespace; a changelog clause saying no edit by a fan-out agent is on record (the two
  incidents of 2026-10-12 were judging reviewers at `inherit`, which this field does not touch, so
  this bullet claims to answer neither); moving the standards paragraph under a heading of its own;
  a `#Probe results` pointer in the capability row's source; the sibling bare `:65`; YAML list
  forms; `tools :` spelled with a space; `Bash(*)` counting as a bare `Bash`; the paragraph
  generalising from `Write` to all three tools, when the probe saw only `Write` absent.
- **Evidence caveat.** Row 3 of the probe results is the agent's own report, relayed by the person
  who ran the session, plus the absent file. The debug log shows one turn and no tool use and does
  not list the agent's tools.
- **The same red as task 4.** `tests/run-tests.sh` exits 1 only on the supply-chain finding at
  step 1.2 of this plan; every other job passed, `tests/test-keel.sh` included.

---

### Task 4: a judging subagent leaves the author's index, tree and stash alone

**Story:** none. Test: the applied check.
**Files:**
- Modify: `skills/review-code/references/rubric-pass.md`
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `CHANGELOG.md`
- Modify, only where step 4.3 finds a citation this task moved: the citing documents it names

**Interfaces:**
- Produces: nothing other tasks consume

**Depends on:** none of the tasks above for its content. Run it after task 3, because tasks 2, 3
and 4 all edit `CHANGELOG.md`.

**Done when:** `tests/validate-skills.sh` exits 0 with `0 FAIL` and 10 WARN,
`tests/validate-citations.sh` prints `OK`, and this reports `:1` for the first file and `:2` for
the second (the phrase sits on one line in all three places):
`grep -c 'Run no git command that' skills/review-code/references/rubric-pass.md skills/execute-plan/references/subagent-prompts.md`

**Why these sentences, and why inside the prompts.** On 2026-10-12 a spec reviewer briefed "do not
edit anything" ran `git stash` on the tree it was judging to measure a baseline, and a quality
reviewer left a worktree behind. Both prompts forbade edits and said nothing about git commands
that move the index or the stash, or about removing a worktree. The sentences go inside the fenced
prompts because a subagent reads only what it is pasted.

- [x] **Step 4.1: Edit the rubric pass prompt** Note: Delegated implementer; spec and quality passes, then should-fix rewrites of the dictated sentence (see the execution record). Not performed or witnessed by the coordinator beyond reading the staged diff and re-running validate-skills, validate-citations and the done-when grep

In `skills/review-code/references/rubric-pass.md`, inside the fenced prompt:

Replace the line `Do not edit the change. Say what is wrong and let the author fix it.` with:

```text
Do not edit the change. Say what is wrong and let the author fix it. Run no git command that
changes the author's index, working tree or stash: no `stash`, `checkout`, `restore`, `reset`,
`commit`, or `git add` of a file, in their checkout. Read it with `diff`, `log`, `show` and
`status`; `git worktree add` for your own worktree is allowed, because it touches neither. On
2026-10-12 a reviewer ran `git stash` on the tree it was judging; it put it back, and the next one
may not.
```

Replace the words `Remove it when you are done with` with
`Remove it before you report, whatever the outcome, and say that you did, with`. Rewrap that
paragraph at 100 columns.

- [x] **Step 4.2: Edit the two review prompts in `subagent-prompts.md`** Note: Delegated implementer; both copies in subagent-prompts.md are byte-identical and now carry --detach, a temp directory and --force (see the execution record). CHANGELOG bullet added as the last one under Unreleased

In `skills/execute-plan/references/subagent-prompts.md`, insert this paragraph twice: inside the
"2. Spec compliance review" fenced prompt, on its own lines directly above
`Answer five questions:`; and inside the "3. Code quality review" fenced prompt, directly above the
line that begins `Rank findings: blocking, should fix, consider.` Keep a blank line before and
after it.

```text
Do not change the tree you are judging. Run no git command that changes its index, working tree or
stash: no `stash`, `checkout`, `restore`, `reset`, `commit`, or `git add` of a file. Read it with
`diff`, `log`, `show` and `status`. If you create a worktree, remove it before you report, whatever
the outcome.
On 2026-10-12 a spec reviewer ran `git stash` on the tree under review to measure a baseline, and a
quality reviewer left a worktree behind.
```

The paragraph is the same in both prompts on purpose: each is pasted alone, and a rule that sits
inside a prompt a dispatcher pastes does not move to a shared reference.

In `CHANGELOG.md`, add as the last bullet under `## Unreleased`:

```markdown
- The review prompts in `rubric-pass.md` and `subagent-prompts.md` forbid git commands that change
  the author's index, tree or stash, and require removing any worktree the reviewer made, whatever
  the outcome. Both answer incidents of 2026-10-12: a reviewer ran `git stash` on the tree it was
  judging, and another left a worktree behind.
```

- [x] **Step 4.3: Repoint what the insertion moved, then hand over** Note: Delegated implementer repointed four line citations in the PRD and story to phrase anchors; three bare :145-165 citations repointed in a later fix. validate-skills 0 FAIL 10 WARN; validate-citations OK; the full suite exits 1 only on the red named in the execution record

Lines were added to both files, so line citations into them below the insertions now point lower.
Find them:

```bash
grep -rnoE '(rubric-pass|subagent-prompts)\.md:[0-9]+(-[0-9]+)?' --include='*.md' . \
  | grep -v '^./docs/plans/'
```

For each hit, open the cited file at the cited line. If the line no longer holds what the citing
sentence means, replace the `:NNN` with a phrase anchor, `file#<phrase on one line of the target>`,
and read it to confirm. That covers every hit outside `docs/plans/` and `docs/audits/`, including
the PRD and story citations the plan review found failing on its applied copy
(`docs/prd/coding-standards-enforcement.md` and `docs/stories/coding-standards-enforcement.md`).
Inside `docs/plans/` and `docs/audits/`, which are dated records, repoint only what
`tests/validate-citations.sh` fails.

Run: `tests/validate-skills.sh`
Expected: exit 0, `0 FAIL`, 10 WARN.

Run: `tests/validate-citations.sh`
Expected: `OK`.

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named.

```bash
git add skills/review-code/references/rubric-pass.md \
        skills/execute-plan/references/subagent-prompts.md CHANGELOG.md
git status --porcelain
```

Also stage, by name, any file step 4.3 repointed, and list it in the report. Stage exactly those
paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "fix(skills): a judging subagent leaves the author's index, tree and stash alone"`.

**Execution record, written when task 4 ran on 2026-10-13.**

- **Order.** Task 4 ran before tasks 2 and 3, because task 1 is a person's probe and its results
  were not yet recorded. Its `CHANGELOG.md` bullet therefore sits before theirs, not after.
- **Delegated.** One implementer, a spec pass and a quality pass, all at `inherit`, then should-fix
  fixes with a re-review after each. Nothing blocked at any pass.
- **The landed wording differs from the sentences above, by review findings, and the files hold the
  true text.** The quality pass found three defects in the dictated rubric-pass sentence ("neither"
  after three items, a trailing "in their checkout" that scoped unclearly, and a reflowed removal
  sentence that no longer parsed), and that the two `subagent-prompts.md` copies left out
  `--detach`, a temp directory and `--force`. A later pass found that "your own worktree is yours
  to change" could be read as permitting `git stash` there, and `refs/stash` is shared by every
  worktree. The last pass asked for the worktree incident to be named in the rubric-pass prompt.
  Three bare `:145-165` citations in the PRD and story were repointed to `#On a DEVIATES` in the
  same pass. The done condition's two counts hold as written (`:1` and `:2`).
- **Considers skipped on purpose, not acted on:** a longer banned-command list or "for example"
  before the read commands; a test pinning the three copies together; a coordinator check of
  `git worktree list` and `git stash list` after each review; the range form
  `#Code quality review through #Running the loop` at PRD line 170; the `CHANGELOG.md` bullet saying
  nothing checks the rule; a bare `#On a DEVIATES` in the story that `validate-citations.sh` cannot
  check; "the revert leaves it modified" being imprecise once item 5 says to restore the line.
- **Found and left alone, outside this task:** `docs/prd/standards-assessment.md` line 234 cites
  `:114`, a blank line already at HEAD. The PRD (lines 58 to 61, 122, 170) and the story (lines 15
  and 192) still say "Running the loop" says nothing about a `Blocking` quality finding, which has
  been false since FR-11 shipped. `docs/ideas/harness-held-dispatch-guarantees.md` estimates the
  prompt change at "about forty words across three prompts"; about 330 landed, which task 5 should
  say when it closes the record.
- **A red this task did not cause, since cleared.** `tests/supply-chain-scan.sh` failed on step 1.2
  of this plan (the `persist-user-claude` rule, on the `grep` of the user's Claude settings), so
  `tests/run-tests.sh` exited 1 at `198f8d8` with that one finding. The fix is a per-line
  `supply-chain-scan: allow` with its reason on that command, the exception `docs/standards.md`
  prescribes. The auto mode classifier refused it the first time as a CI bypass and it was reverted;
  it was made as its own commit once the owner approved it.

---

### Task 5: close the idea record

**Story:** none. Test: the applied check.
**Files:**
- Modify: `docs/ideas/harness-held-dispatch-guarantees.md`
- Modify: `README.md`, only if step 5.2 finds a claim this plan made false

**Interfaces:**
- Consumes: the commits of tasks 2, 3 and 4

**Depends on:** tasks 2, 3 and 4

**Done when:** `tests/test-doc-claims.sh` exits 0 and `tests/validate-citations.sh` prints `OK`.

- [x] **Step 5.1: Mark the record built** Note: Delegated implementer; hashes verified with git log; the word count was re-derived by the implementer and by a reviewer (332 net new words in e0c09be: 118, 118 and 96). Two review fixes: python3 -I -c, and a sentence saying the Not decided here items were decided

In `docs/ideas/harness-held-dispatch-guarantees.md`:

- set the Status cell to `built <date>, via docs/plans/2026-10-13-harness-held-dispatch-guarantees.md`,
  where the date is the day the last of tasks 2 to 4 was committed;
- set the Next cell to `Nothing for variants A and C. Items 4 to 8 are decided together`;
- under "Recommendation", add one line per change naming its commit: `Landed: variant A in <sha>,
  variant C in <sha>, the prompt sentences in <sha>`, with the three short hashes from `git log`;
- say in the record's open question 2 that about 330 words landed across the prompts, against the
  "about forty" estimated there: the estimate was low, and the record is the place that made it;
- leave items 4 to 8 and every finding as they are: the record is dated.

- [x] **Step 5.2: Read the README's claims** Note: Implementer and a reviewer each read README.md in full and found no claim the three commits made false, so it is unchanged. tests/test-doc-claims.sh 63 passed, validate-citations OK

Read `README.md`: the status line, the skills table, the hooks and agents description and the tests
section. This plan adds no skill and no agent, so the likely edit is none. Say in the report what
you read and what you changed.

Run: `tests/test-doc-claims.sh`
Expected: exit 0.

Run: `tests/validate-citations.sh`
Expected: `OK`.

```bash
git add docs/ideas/harness-held-dispatch-guarantees.md
git status --porcelain
```

Add `README.md` only if you changed it. Stage exactly those paths and stop. **Do not commit.** The
coordinator commits with `git commit -m "docs(ideas): the dispatch guarantees record is built"`.

---

## What the review changed

A plan reviewer was dispatched on 2026-10-13, model `inherit`, per `plan-review.md`. It ran the
task 2 and task 3 code from this plan's text, applied task 4's edits to a copy, and found (step
numbers in this table are those of the plan as first written; task 2 was renumbered when it was
amended):

| Finding | Rank | What changed |
|---|---|---|
| Task 4's done condition grepped a phrase the new text breaks across two lines, so it reported `:0` | Blocking | The grep now uses `Run no git command that`, which sits on one line in all three places |
| Step 2.4's mutation copy cannot find `settings.json` unless the repository layout is copied too | Should fix | The step copies `settings.json`, `lib/` and `tests/` into one directory |
| No paragraph begins `**Confirmed on Claude Code**`: the phrase is mid-paragraph | Should fix | Step 2.5 anchors on the paragraph that contains it, and names how it ends |
| `docs/standards.md` says an interactive developer cannot see the dispatch model, which task 2 makes false on Claude Code | Should fix | Step 2.5 replaces that sentence |
| A second `python3` user goes unrecorded against the standard's departure | Should fix | Step 2.5 records it, and that its failure mode was not probed |
| Task 3 anchored on lines only task 2 adds, so it could not run if task 2 stopped | Should fix | Every task 3 anchor names a fallback line |
| The probe could read another `subagentStatusLine` as "settings not applied" | Should fix | Step 1.2 looks for one first; step 1.3 reads every logged tick, not the last |
| `tests/test-doc-claims.sh` reads `git ls-files`, so running it before staging checks nothing new | Should fix | Steps 2.6 and 3.6 stage first |
| `tests/test-keel.sh` alone outlasts a 120 s call | Should fix | A global constraint says to run it in its own call |
| Step 4.3 did not say which of twelve citation hits to repoint | Consider | It now says: all outside dated records, and the failing ones inside them |
| The new sentence forbade `add` while the prompt requires `git worktree add` | Consider | The sentence forbids `git add` of a file and allows a worktree |
| The row dropped the default `name` and printed "1 tokens" | Consider | Both fixed; test case 3 now covers them |
| `test-agents.sh` and `settings.json` were placed out of sort order in the layout tree | Consider | Both moved |
| `agentType` on the row, and the plan-review prompt | Consider | Not built, with the reasons in "What this plan does not build" |

## What the probe changed

Task 1 ran on 2026-10-13 and its results are recorded above. Two of its four rows changed the plan.

| Finding | What changed |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}` is unset in a plugin `settings.json` command's environment, and the command runs from the project's directory | Task 2 inlines the script as a `python3 -c` command and generates `settings.json` from `lib/subagent_statusline.py`, with a test that diffs the two. Step 2.1 probes that exact shape before anything is built |
| The same run showed the plugin's `settings.json` was applied and `python3` resolved in the command's shell | The design keeps `python3` and a plugin `settings.json`; no hook, no user-settings write, no second install step |
| `disallowedTools` held on a plugin agent | Task 3 ran as written, apart from the review fixes in its execution record |
| The row carried `agentType` on 2.1.296, and the plan review read in the client that an override replaces the whole row | The agent type is kept on the row, led by the name when there is one. That answers on screen the idea record's open point about whether a `keel-fanout: ` row runs as the restricted agent, at the cost of the progress summary, elapsed time and queued count, which are named as dropped |
| A root `settings.json` command is outside the supply-chain scan's `exec` scope (the plan review appended a `curl` to it and nothing fired) | Step 2.6 adds the file to that scope, test first |
| The first probe's agent and its parent session ran the same model, so its row could not show the agent's model apart from the parent's | Step 2.1 runs the session on `haiku` with a `sonnet` agent and an `inherit` agent, and row 3 of its results must show the two IDs differ |

## Tasks run sequentially, and that is a decision

No concurrent batch. Tasks 2, 3 and 4 all edit `CHANGELOG.md`, and tasks 2 and 3 also share
`tests/run-tests.sh`, `lib/harness/capabilities`, `docs/standards.md` and `docs/06-repo-layout.md`.
Task 1 is a person at a terminal and gates tasks 2 and 3. The order actually run was 1, 4, 3, then
2 after its amendment, because task 2 waited on a second live probe; each task's anchors name the
lines the earlier ones left, so the order changes no instruction.

## Self-review

1. **Stories:** none, by the deviation above. Every change in the idea record's recommendation maps
   to a task: variant A to task 2, variant C to task 3, the prompt sentences to task 4.
2. **Placeholders:** the bracketed values in steps 2.7 and 3.5 and the date and hashes in step 5.1
   are filled from what earlier tasks and probes record, before the step that uses them. Task 3's
   test and the original task 2 were dry-run from this plan's text on 2026-10-13. The amended task
   2 was dry-run again, in a fresh git checkout of HEAD, from its text as extracted: with no
   `settings.json`, 0 passed and 9 failed, with the registration case's traceback; with the source,
   the generator mode and the generated file, 9 passed; the narrow-row mutation failed one case
   with the content step 2.5 names, and the staleness mutation failed only the generated-file case;
   the new supply-chain case failed with "expected exit 1, got 0" before the scope change and the
   suite passed 64 of 64 after it; the scanner's only finding on the finished tree was the known one
   at step 1.2, so the generated `settings.json` adds none; `test-harness-claims`,
   `test-harness-resolve`, `test-doc-claims`, `validate-skills`, `validate-citations` and
   `no-internal-leaks` all passed; the support page changed by one line; and step 2.1's prepare
   block ran as written. Not dry-run: `tests/run-tests.sh` whole, and the live probe itself.
3. **Names:** `subagent_row_model`, `agent_tool_denylist`, `lib/subagent_statusline.py`, the
   generator mode `subagent-settings`, `tests/test-subagent-statusline.sh` and
   `tests/test-agents.sh` are spelled the same in every task.
4. **Verify commands:** `tests/run-tests.sh` and `tests/{name}` from the profile. `ruff` is CI only
   and named as such.
5. **Hand-over:** tasks 2 to 5 stage named paths and name the coordinator's commit. Task 1 is a
   person's probe and commits the plan itself, because it changes nothing else.
6. **Files:** no task depends on a file no task creates. `settings.json` is generated in step 2.4 by
   a mode that step adds, and the two test files are created in the task that first needs them.
7. **Ids:** every step opens `Step <task>.<step>:` and no id repeats.
