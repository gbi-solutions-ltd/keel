#!/usr/bin/env bash
# Tests for hooks/done-guard, registered on Stop and SubagentStop.
#
# The guard asserts on emitted JSON rather than exit code, for the same reason sensitive-guard's
# tests do: a hook that exits 0 emitting nothing is indistinguishable from one that is not
# installed. The difference from sensitive-guard is case 8. That guard asks a human whenever it
# cannot answer. This one has no human to ask, because a denied Stop just runs again, so it warns
# and allows. A guard that hangs a session is a guard that gets deleted.

set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="$ROOT_DIR/hooks/done-guard"
pass=0
fail=0

fixture() {   # fixture <root> <gate-json-or-empty> <verify-test-json>
    local root="$1" gate="$2" test_cmd="$3"
    mkdir -p "$root/.keel" "$root/lib" "$root/docs"
    printf '{\n  "verify": {"test": %s},\n  "gates": {%s},\n  "docs_root": "docs"\n}\n' \
        "$test_cmd" "$gate" > "$root/.keel/profile.json"
}

# A Stop event, in the shape the harness actually sends.
#
# It carries NO tool_calls. Stop and SubagentStop receive stop_hook_active, last_assistant_message,
# background_tasks and session_crons plus the common fields; tool_calls exists on PostToolBatch
# alone. Until 2026-09-05 this helper synthesised a tool_calls array, so every case in this file
# fed the guard an event the harness has never produced, and the guard read a field that was never
# there. The suite was green for a gate that could not fire.
#
# What the guard reads instead is the transcript at transcript_path, or agent_transcript_path on
# SubagentStop. The row shape below was verified against a real Claude Code transcript, and
# tests/fixtures/transcripts/claude-stop-edited-no-test.jsonl is one captured from a real turn.
transcript() {   # transcript <path> <edits, space separated> <cmds, pipe separated>
    local out="$1" edits="$2" cmds="$3" p c
    : > "$out"
    printf '{"type":"user","message":{"role":"user","content":"do the thing"}}\n' >> "$out"
    for p in $edits; do
        printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"%s"}}]}}\n' "$p" >> "$out"
    done
    ( IFS='|'; for c in $cmds; do
        [ -n "$c" ] && printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"%s"}}]}}\n' "$c" >> "$out"
      done )
}

event() {   # event <cwd> <stop_hook_active> <edits> <cmds> [hook_event_name]
    local cwd="$1" active="$2" edits="$3" cmds="$4" evname="${5:-Stop}" t
    t="$cwd/.transcript.jsonl"
    transcript "$t" "$edits" "$cmds"
    CWD="$cwd" ACTIVE="$active" EVNAME="$evname" T="$t" python3 -c '
import json, os
ev = {"hook_event_name": os.environ["EVNAME"], "cwd": os.environ["CWD"],
      "session_id": "test", "transcript_path": os.environ["T"],
      "stop_hook_active": os.environ["ACTIVE"] == "1",
      "last_assistant_message": "All set.", "background_tasks": [], "session_crons": []}
if os.environ["EVNAME"] == "SubagentStop":
    ev["agent_transcript_path"] = os.environ["T"]
    ev["agent_id"] = "a1"; ev["agent_type"] = "general-purpose"
print(json.dumps(ev))'
}

check() {   # check <name> <want: deny|warn|none> <root> <active> <edits> <cmds>
    local name="$1" want="$2" root="$3" active="$4" edits="$5" cmds="$6" out
    out="$(event "$root" "$active" "$edits" "$cmds" | ( cd "$root" && "$GUARD" ) 2>/dev/null)"
    case "$want" in
        deny)
            # The word is "block", not "deny". Claude Code's Stop protocol defines exactly one
            # blocking value: `decision` "block" prevents Claude from stopping, and it says of
            # anything else "Omit to allow Claude to stop". keel emitted "deny" from the day this
            # gate was written, so the gate never blocked anything, and these assertions passed
            # because they grep keel's own output rather than asking the harness.
            # Verified 2026-09-05 against code.claude.com/docs/en/hooks, Stop decision control.
            if printf '%s' "$out" | grep -q '"decision": *"block"'; then
                printf '  PASS  %s\n' "$name"; pass=$((pass+1))
            else
                printf '  FAIL  %s (expected deny, got: %s)\n' "$name" "${out:0:90}"; fail=$((fail+1))
            fi ;;
        warn)
            if printf '%s' "$out" | grep -q '"systemMessage"' \
               && ! printf '%s' "$out" | grep -q '"decision": *"block"'; then
                printf '  PASS  %s\n' "$name"; pass=$((pass+1))
            else
                printf '  FAIL  %s (expected a warning, got: %s)\n' "$name" "${out:0:90}"; fail=$((fail+1))
            fi ;;
        none)
            if [ -z "$out" ]; then
                printf '  PASS  %s\n' "$name"; pass=$((pass+1))
            else
                printf '  FAIL  %s (expected nothing, got: %s)\n' "$name" "${out:0:90}"; fail=$((fail+1))
            fi ;;
    esac
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 1. No gate declared: silent, like sensitive-guard with no hard_block_paths.
fixture "$tmp/a" '' '"tests/run-tests.sh"'
check "no gate declared, code edited, no test run" none "$tmp/a" 0 "lib/x.sh" ""

# 2. The case the guard exists for.
fixture "$tmp/b" '"done_verified": "required"' '"tests/run-tests.sh"'
check "required: code edited, test never run" deny "$tmp/b" 0 "lib/x.sh" ""

# 3. The test ran, so there is nothing to say.
fixture "$tmp/c" '"done_verified": "required"' '"tests/run-tests.sh"'
check "required: code edited, test run" none "$tmp/c" 0 "lib/x.sh" "tests/run-tests.sh"

# 4. Documentation only. Without this the guard fires on every documentation commit, and a guard
# that cries wolf is deleted alongside sensitive-guard, which shares its hooks.json.
fixture "$tmp/d" '"done_verified": "required"' '"tests/run-tests.sh"'
check "required: only markdown edited" none "$tmp/d" 0 "README.md docs/x.md" ""

# 5. The loop guard. Without it a denied stop denies again, forever, with no human in the loop.
fixture "$tmp/e" '"done_verified": "required"' '"tests/run-tests.sh"'
check "required: stop_hook_active is already true" none "$tmp/e" 1 "lib/x.sh" ""

# 6. Nothing to check against.
fixture "$tmp/f" '"done_verified": "required"' 'null'
check "required: profile has no test command" none "$tmp/f" 0 "lib/x.sh" ""

# 7. warn says it without stopping the turn.
fixture "$tmp/g" '"done_verified": "warn"' '"tests/run-tests.sh"'
check "warn: code edited, test never run" warn "$tmp/g" 0 "lib/x.sh" ""

# 8. Fails open, and says so. The documented difference from sensitive-guard.
mkdir -p "$tmp/h/.keel"
printf '{ "gates": {"done_verified": "required"}, ' > "$tmp/h/.keel/profile.json"   # truncated on purpose
check "unparseable profile warns and allows the stop" warn "$tmp/h" 0 "lib/x.sh" ""

# 9. A subagent is the case the request cared about most, and its message must name it as the
# subject rather than saying "this turn", which reads as the main thread's.
fixture "$tmp/i" '"done_verified": "required"' '"tests/run-tests.sh"'
out="$(event "$tmp/i" 0 "lib/x.sh" "" SubagentStop | ( cd "$tmp/i" && "$GUARD" ) 2>/dev/null)"
if printf '%s' "$out" | grep -q '"decision": *"block"' \
   && printf '%s' "$out" | grep -q 'This subagent'; then
    printf '  PASS  %s\n' "SubagentStop denies and names the subagent"; pass=$((pass+1))
else
    printf '  FAIL  %s (got: %s)\n' "SubagentStop denies and names the subagent" "${out:0:90}"; fail=$((fail+1))
fi

# 9b. An unreadable profile passes in silence and, critically, without bash printing "Permission
# denied" to stderr. A Stop hook surfaces stderr as an error notice, so before the `-r` test this
# put one on the end of every turn. Skipped as root, which can read a 000 file.
if [ "$(id -u)" -eq 0 ]; then
    printf '  SKIP  unreadable profile is silent (running as root)\n'
else
    fixture "$tmp/k" '"done_verified": "required"' '"tests/run-tests.sh"'
    chmod 000 "$tmp/k/.keel/profile.json"
    # The event writer's stderr is silenced too: the guard exits before draining stdin, so python
    # reports a broken pipe that is the test harness's noise, not the guard's output.
    out="$( { event "$tmp/k" 0 "lib/x.sh" "" 2>/dev/null; } | ( cd "$tmp/k" && "$GUARD" ) 2>&1)"
    if [ -z "$out" ]; then
        printf '  PASS  %s\n' "unreadable profile is silent on stdout and stderr"; pass=$((pass+1))
    else
        printf '  FAIL  %s (expected nothing, got: %s)\n' "unreadable profile is silent on stdout and stderr" "${out:0:90}"; fail=$((fail+1))
    fi
    chmod 644 "$tmp/k/.keel/profile.json"
fi

# 10. Off is off, stated rather than assumed. A gate set to off that still fired would be worse
# than one that was never added.
fixture "$tmp/j" '"done_verified": "off"' '"tests/run-tests.sh"'
check "off: code edited, test never run" none "$tmp/j" 0 "lib/x.sh" ""

# The value is pinned against the protocol, not against ourselves. Without this, changing the word
# back to anything at all keeps every case above green, which is how the gate stayed inert.
fixture "$tmp/proto" '"done_verified": "required"' '"tests/run-tests.sh"'
out="$(event "$tmp/proto" 0 "src/a.sh" "" | ( cd "$tmp/proto" && "$GUARD" ) 2>/dev/null)"
if printf '%s' "$out" | grep -q '"decision": *"block"' \
   && ! printf '%s' "$out" | grep -qE '"decision": *"(deny|allow|stop|refuse)"'; then
    printf '  PASS  %s\n' "the Stop decision is the protocol's blocking value and no other"; pass=$((pass+1))
else
    printf '  FAIL  %s (got: %s)\n' "the Stop decision is the protocol's blocking value and no other" "${out:0:90}"; fail=$((fail+1))
fi

# A blocking decision must carry a reason: the protocol makes it required when decision is "block".
if printf '%s' "$out" | grep -q '"reason"'; then
    printf '  PASS  %s\n' "a blocking decision carries the required reason"; pass=$((pass+1))
else
    printf '  FAIL  %s (got: %s)\n' "a blocking decision carries the required reason" "${out:0:90}"; fail=$((fail+1))
fi

# Against a transcript captured from a real Claude Code turn, not one this file synthesised.
# Every other case builds its transcript from a shape this file believes in; this one reads a
# recording. If the harness changes that shape, this is the case that goes red.
fixture "$tmp/real" '"done_verified": "required"' '"tests/run-tests.sh"'
real_t="$ROOT_DIR/tests/fixtures/transcripts/claude-stop-edited-no-test.jsonl"
out="$(CWD="$tmp/real" T="$real_t" python3 -c '
import json, os
print(json.dumps({"hook_event_name":"Stop","cwd":os.environ["CWD"],"session_id":"t",
                  "transcript_path":os.environ["T"],"stop_hook_active":False,
                  "last_assistant_message":"Done.","background_tasks":[],"session_crons":[]}))' \
  | ( cd "$tmp/real" && "$GUARD" ) 2>/dev/null)"
if printf '%s' "$out" | grep -q '"decision": *"block"'; then
    printf '  PASS  %s\n' "blocks on a transcript captured from a real turn"; pass=$((pass+1))
else
    printf '  FAIL  %s (got: %s)\n' "blocks on a transcript captured from a real turn" "${out:0:90}"; fail=$((fail+1))
fi

# The cases below pin turn_tool_calls itself. Without them you can delete the body of
# is_real_user, take every row instead of the turn's, stop skipping sidechain rows, or ignore
# agent_transcript_path, and the suite stays green. That was true of this file on 2026-09-05 and is
# the same defect it was rewritten to remove: a suite that agrees with whatever the code does.

row_user()  { printf '{"type":"user","message":{"role":"user","content":"%s"}}\n' "$1"; }
row_meta()  { printf '{"type":"user","isMeta":true,"turnCompanion":true,"message":{"role":"user","content":[{"type":"text","text":"%s"}]}}\n' "$1"; }
row_edit()  { printf '{"type":"assistant"%s,"message":{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"%s"}}]}}\n' "$2" "$1"; }
row_bash()  { printf '{"type":"assistant"%s,"message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"%s"}}]}}\n' "$2" "$1"; }

send() {   # send <root> <transcript> <evname> [agent_transcript]
    local root="$1" t="$2" ev="$3" at="${4:-}"
    CWD="$root" T="$t" EVN="$ev" AT="$at" python3 -c '
import json, os
e={"hook_event_name":os.environ["EVN"],"cwd":os.environ["CWD"],"session_id":"t",
   "transcript_path":os.environ["T"],"stop_hook_active":False,
   "last_assistant_message":"Done.","background_tasks":[],"session_crons":[]}
if os.environ["AT"]: e["agent_transcript_path"]=os.environ["AT"]
print(json.dumps(e))' | ( cd "$root" && "$GUARD" ) 2>/dev/null
}

expect() {   # expect <name> <want: block|quiet|warn> <output>
    local name="$1" want="$2" out="$3" got=1
    case "$want" in
        block) printf '%s' "$out" | grep -q '"decision": *"block"'; got=$? ;;
        quiet) [ -z "$out" ]; got=$? ;;
        warn)  printf '%s' "$out" | grep -q '"systemMessage"'; got=$? ;;
    esac
    if [ "$got" -eq 0 ]; then
        printf '  PASS  %s\n' "$name"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got: %s)\n' "$name" "$want" "${out:0:80}"; fail=$((fail+1))
    fi
}

fixture "$tmp/tc" '"done_verified": "required"' '"tests/run-tests.sh"'

# Turn scoping: an edit belonging to an EARLIER turn is not this turn's work.
{ row_user "first"; row_edit "src/old.py" ""; row_user "second"; } > "$tmp/tc/a.jsonl"
expect "an edit from an earlier turn is not counted" quiet "$(send "$tmp/tc" "$tmp/tc/a.jsonl" Stop)"

# ...and one in this turn is.
{ row_user "first"; row_edit "src/old.py" ""; row_user "second"; row_edit "src/new.py" ""; } > "$tmp/tc/b.jsonl"
expect "an edit in this turn is counted" block "$(send "$tmp/tc" "$tmp/tc/b.jsonl" Stop)"

# A harness-injected row must not reset the boundary. Here the test ran BEFORE the injected row;
# treating that row as a new turn hides the run and blocks a turn that did everything right.
{ row_user "go"; row_edit "src/a.py" ""; row_bash "tests/run-tests.sh" ""; row_meta "skill body"; row_edit "src/b.py" ""; } > "$tmp/tc/c.jsonl"
expect "an injected meta row does not reset the turn" quiet "$(send "$tmp/tc" "$tmp/tc/c.jsonl" Stop)"

# Sidechain rows on the MAIN transcript are another agent's work.
{ row_user "go"; row_edit "src/sub.py" ',"isSidechain":true'; } > "$tmp/tc/d.jsonl"
expect "a sidechain edit on the main transcript is skipped" quiet "$(send "$tmp/tc" "$tmp/tc/d.jsonl" Stop)"

# ...but a subagent's OWN transcript is entirely sidechain, so skipping there reads nothing at all.
{ row_user "go"; row_edit "src/sub.py" ',"isSidechain":true'; } > "$tmp/tc/e.jsonl"
expect "a subagent's own all-sidechain transcript is read" block "$(send "$tmp/tc" "$tmp/tc/main.jsonl" SubagentStop "$tmp/tc/e.jsonl")"

# Path selection: the agent transcript is a different file from the main one, and SubagentStop
# must read the agent's. If it read transcript_path it would see the clean main transcript.
{ row_user "go"; } > "$tmp/tc/main.jsonl"
expect "SubagentStop reads agent_transcript_path, not transcript_path" block "$(send "$tmp/tc" "$tmp/tc/main.jsonl" SubagentStop "$tmp/tc/e.jsonl")"

# An empty or wholly unparseable transcript is not a clean turn, and must say so.
: > "$tmp/tc/empty.jsonl"
expect "an empty transcript warns rather than passing silently" warn "$(send "$tmp/tc" "$tmp/tc/empty.jsonl" Stop)"

# A valid-JSON row that is not an object must not crash the hook.
{ row_user "go"; printf '["not","an","object"]\n'; row_edit "src/a.py" ""; } > "$tmp/tc/odd.jsonl"
expect "a non-object row does not crash the hook" block "$(send "$tmp/tc" "$tmp/tc/odd.jsonl" Stop)"

# ---- a transcript in another shape ----------------------------------------
#
# The reader understands a Claude Code transcript and nothing else. A file whose rows parse and none
# of which has a Claude Code shape yields no tool calls, and reading that as a clean turn is a gate
# saying nothing where it should warn. So the guard warns that it did not check the turn, and allows
# the stop: the fail-open direction the header gives, a reminder rather than a turn nobody can end.
not_checked() {   # not_checked <name> <output> <rc>
    local name="$1" out="$2" rc="$3"
    if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 1 ] \
       && printf '%s' "$out" | grep -q '^{"systemMessage": "keel done-guard: .*not in a shape it reads.*so this turn was not checked\."}$' \
       && ! printf '%s' "$out" | grep -q '"decision"'; then
        printf '  PASS  %s\n' "$name"; pass=$((pass+1))
    else
        printf '  FAIL  %s (rc=%s, got: %s)\n' "$name" "$rc" "${out:0:120}"; fail=$((fail+1))
    fi
}

fixture "$tmp/ro" '"done_verified": "required"' '"tests/run-tests.sh"'
{
  printf '{"timestamp":"2026-09-06T07:16:40Z","ordinal":7,"type":"turn_context","payload":{"turn_id":"t1","model":"m"}}\n'
  printf '{"timestamp":"2026-09-06T07:16:47Z","ordinal":14,"type":"response_item","payload":{"type":"custom_tool_call","name":"apply_patch","input":"*** Begin Patch\\n*** Update File: src/a.py\\n*** End Patch","turn_id":"t1"}}\n'
} > "$tmp/ro/rollout.jsonl"
out="$(send "$tmp/ro" "$tmp/ro/rollout.jsonl" Stop)"; rc=$?
not_checked "a rollout-shaped transcript warns that the turn was not checked, and exits 0" "$out" "$rc"

{
  printf '{"type":"event","payload":{"nope":1}}\n'
  printf '{"type":"event","payload":{"nope":1}}\n'
} > "$tmp/ro/event.jsonl"
out="$(send "$tmp/ro" "$tmp/ro/event.jsonl" Stop)"; rc=$?
not_checked "a transcript with no Claude Code row warns that the turn was not checked, and exits 0" "$out" "$rc"

# A real transcript opens with metadata rows that have no Claude Code shape: measured over 500 of
# them, the first Claude Code row was row 3 to 12. The shape check looks at every row, so those
# rows must not turn a real transcript into a warning.
row_type()  { printf '{"type":"%s","sessionId":"t"}\n' "$1"; }
row_say()   { printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]}}\n' "$1"; }
{ row_type mode; row_type queue-operation; row_user "go"; row_say "nothing to change"; } > "$tmp/tc/meta-clean.jsonl"
out="$(send "$tmp/tc" "$tmp/tc/meta-clean.jsonl" Stop)"; rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
    printf '  PASS  %s\n' "metadata rows first and no tool call: silent, exit 0"; pass=$((pass+1))
else
    printf '  FAIL  %s (rc=%s, got: %s)\n' "metadata rows first and no tool call: silent, exit 0" "$rc" "${out:0:80}"; fail=$((fail+1))
fi
{ row_type mode; row_type queue-operation; row_user "go"; row_edit "src/x.py" ""; } > "$tmp/tc/meta-edit.jsonl"
expect "metadata rows first, code edited and no test run: block under required" block "$(send "$tmp/tc" "$tmp/tc/meta-edit.jsonl" Stop)"

# A row is Claude Code's when its message is an object or its type is user, assistant or summary,
# either alone. Each side is tested without the other, so joining them with `and` would warn here.
shape_alone() {   # shape_alone <name> <second row>; a row of no shape, then that row: silent, exit 0
    local out rc
    { printf '{"type":"event"}\n'; printf '%s\n' "$2"; } > "$tmp/tc/alone.jsonl"
    out="$(send "$tmp/tc" "$tmp/tc/alone.jsonl" Stop)"; rc=$?
    if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
        printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s (rc=%s, got: %s)\n' "$1" "$rc" "${out:0:80}"; fail=$((fail+1))
    fi
}
shape_alone "a summary row with no message is a Claude Code row: silent, exit 0" \
    '{"type":"summary","summary":"x"}'
shape_alone "a message row with no type is a Claude Code row: silent, exit 0" \
    '{"message":{"role":"user","content":"x"}}'

# ---- where an edited path lives -----------------------------------------------
#
# An edit outside the repository is not this repository's code: a subagent writing a probe under
# /tmp has changed nothing the suite covers, and blocking it for not running the suite is a false
# block. The root is git's top level, else the event's cwd, and both sides go through realpath,
# because mktemp on macOS hands out /var paths that are really /private/var.
row_write() { printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Write","input":{"file_path":"%s"}}]}}\n' "$1"; }

reason_has() {   # reason_has <name> <output> <text> <want: yes|no>; the output must also block
    local name="$1" out="$2" text="$3" want="$4" has=no
    printf '%s' "$out" | grep -qF "$text" && has=yes
    if printf '%s' "$out" | grep -q '"decision": *"block"' && [ "$has" = "$want" ]; then
        printf '  PASS  %s\n' "$name"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted a block, %s containing %s, got: %s)\n' "$name" "$want" "$text" "${out:0:120}"; fail=$((fail+1))
    fi
}

repo="$tmp/repo"
fixture "$repo" '"done_verified": "required"' '"tests/run-tests.sh"'
git init -q "$repo" 2>/dev/null

# Behaviour 1.
{ row_user "go"; row_write "/tmp/keel-probe/parse.py"; } > "$repo/b1.jsonl"
expect "outside the repository: a SubagentStop whose only write is under /tmp is quiet" quiet \
    "$(send "$repo" "$repo/main.jsonl" SubagentStop "$repo/b1.jsonl")"
{ row_user "go"; row_write "$repo/docs/x.txt"; } > "$repo/b1d.jsonl"
expect "inside the repository: an absolute path under docs_root is made relative to the root and passes" quiet \
    "$(send "$repo" "$repo/b1d.jsonl" Stop)"

# Behaviour 2.
{ row_user "go"; row_edit "$repo/lib/foo.sh" ""; } > "$repo/b2.jsonl"
reason_has "inside the repository: an absolute path is code and the reason names lib/foo.sh" \
    "$(send "$repo" "$repo/b2.jsonl" Stop)" "lib/foo.sh" yes

# Behaviour 3.
{ row_user "go"; row_write "lib/foo.sh"; } > "$repo/b3.jsonl"
expect "a relative path is read against the event cwd, so it is inside and blocks" block \
    "$(send "$repo" "$repo/b3.jsonl" Stop)"
{ row_user "go"; row_write "$repo/docs/x.md"; } > "$repo/b3d.jsonl"
expect "an absolute markdown path inside the repository passes" quiet \
    "$(send "$repo" "$repo/b3d.jsonl" Stop)"

# Behaviour 4.
{ row_user "go"; row_write "$repo/../elsewhere/x.py"; } > "$repo/b4.jsonl"
expect "a path that climbs out of the repository is outside: quiet" quiet \
    "$(send "$repo" "$repo/b4.jsonl" Stop)"

# Behaviour 5.
{ row_user "go"; row_write "/tmp/keel-probe/a.py"; row_edit "$repo/lib/foo.sh" ""; } > "$repo/b5.jsonl"
reason_has "a mix is judged on the inside paths and the reason does not name the outside one" \
    "$(send "$repo" "$repo/b5.jsonl" Stop)" "/tmp/keel-probe/a.py" no

# Behaviour 6. A checkpointed implementer ends on its task's own tests, through verify.test_one or
# verify.test_affected, so those count as a test run by their text before the first `{`. An empty
# prefix would be a substring of every command, so it counts for nothing.
scoped="$tmp/scoped"
fixture "$scoped" '"done_verified": "required"' '"tests/run-tests.sh", "test_one": "go test {path}"'
{ row_user "go"; row_edit "$scoped/a.go" ""; row_bash "go test -count=1 -run TestX ./api/" ""; } > "$scoped/b6.jsonl"
expect "a scoped run through verify.test_one counts as a test run" quiet \
    "$(send "$scoped" "$scoped/b6.jsonl" Stop)"
affected="$tmp/affected"
fixture "$affected" '"done_verified": "required"' '"tests/run-tests.sh", "test_affected": "go test {packages}"'
{ row_user "go"; row_edit "$affected/a.go" ""; row_bash "go test ./api/" ""; } > "$affected/b6.jsonl"
expect "a scoped run through verify.test_affected counts as a test run" quiet \
    "$(send "$affected" "$affected/b6.jsonl" Stop)"
empty="$tmp/empty-prefix"
fixture "$empty" '"done_verified": "required"' '"tests/run-tests.sh", "test_one": "{name}"'
{ row_user "go"; row_edit "$empty/a.go" ""; row_bash "echo hi" ""; } > "$empty/b6.jsonl"
expect "a verify.test_one with an empty prefix counts nothing, so the edit still blocks" block \
    "$(send "$empty" "$empty/b6.jsonl" Stop)"

# A scoped prefix counts only where it begins a command: at the start, or after `;`, `&&`, `||`,
# `|`, `(` or a newline. As a bare substring, `tests/` inside a shellcheck argument counted as a
# test run, so a turn that only linted ended unblocked.
begins="$tmp/begins"
fixture "$begins" '"done_verified": "required"' '"tests/run-tests.sh", "test_one": "tests/{name}"'
{ row_user "go"; row_edit "$begins/lib/foo.sh" ""; row_bash "shellcheck -x lib/foo.sh tests/*.sh" ""; } > "$begins/mid.jsonl"
expect "a scoped prefix in the middle of a command is not a test run, so the edit blocks" block \
    "$(send "$begins" "$begins/mid.jsonl" Stop)"
{ row_user "go"; row_edit "$begins/lib/foo.sh" ""; row_bash "tests/test-foo.sh" ""; } > "$begins/start.jsonl"
expect "a command that begins with the scoped prefix is a test run" quiet \
    "$(send "$begins" "$begins/start.jsonl" Stop)"
{ row_user "go"; row_edit "$begins/lib/foo.sh" ""; row_bash "cd /x && tests/test-foo.sh" ""; } > "$begins/cd.jsonl"
expect "the scoped prefix after cd and && begins a command, so it is a test run" quiet \
    "$(send "$begins" "$begins/cd.jsonl" Stop)"
whole="$tmp/whole"
fixture "$whole" '"done_verified": "required"' '"tests/run-tests.sh"'
{ row_user "go"; row_edit "$whole/lib/foo.sh" ""; row_bash "bash tests/run-tests.sh" ""; } > "$whole/b.jsonl"
expect "verify.test still counts as a substring anywhere in a command" quiet \
    "$(send "$whole" "$whole/b.jsonl" Stop)"

# The root comes from git, not the event's cwd. Taken from a cwd of <repo>/lib, the root would put
# <repo>/hooks outside and pass an edit the suite covers.
mkdir -p "$repo/hooks"
{ row_user "go"; row_write "$repo/hooks/x.sh"; } > "$repo/sub.jsonl"
expect "the root is git's top level, so an edit beside the event's cwd still blocks" block \
    "$(send "$repo/lib" "$repo/sub.jsonl" Stop)"

# The repository's parent is exactly "..", which a test for "../" alone would read as inside.
{ row_user "go"; row_write "$repo/.."; } > "$repo/parent.jsonl"
expect "a path that is exactly the repository's parent is outside: quiet" quiet \
    "$(send "$repo" "$repo/parent.jsonl" Stop)"

# The reason names the scoped commands as well as verify.test, so a checkpointed implementer is not
# told to run the suite when its task's own tests satisfy the gate.
{ row_user "go"; row_edit "$scoped/a.go" ""; } > "$scoped/named.jsonl"
reason_has "the reason names verify.test" \
    "$(send "$scoped" "$scoped/named.jsonl" Stop)" "tests/run-tests.sh" yes
reason_has "the reason names verify.test_one's scoped command" \
    "$(send "$scoped" "$scoped/named.jsonl" Stop)" "go test" yes
{ row_user "go"; row_edit "$whole/lib/foo.sh" ""; } > "$whole/named.jsonl"
# shellcheck disable=SC2016  # the backticks are the reason's literal text
reason_has "with no scoped command the reason names verify.test only, as before" \
    "$(send "$whole" "$whole/named.jsonl" Stop)" 'never ran `tests/run-tests.sh`. Run it' yes

# With several commands named, the reason asks for one of them, and a prefix verify.test_one and
# verify.test_affected share is named once rather than offered twice as two choices.
both="$tmp/both"
fixture "$both" '"done_verified": "required"' '"tests/run-tests.sh", "test_one": "go test {path}", "test_affected": "go test {packages}"'
{ row_user "go"; row_edit "$both/a.go" ""; } > "$both/named.jsonl"
out="$(send "$both" "$both/named.jsonl" Stop)"
reason_has "with several commands the reason says Run one" "$out" "Run one" yes
n="$(printf '%s' "$out" | grep -o 'go test' | wc -l | tr -d ' ')"
if [ "$n" = 1 ]; then
    printf '  PASS  %s\n' "a prefix both scoped commands share is named once"; pass=$((pass+1))
else
    printf '  FAIL  %s (named %s times: %s)\n' "a prefix both scoped commands share is named once" "$n" "${out:0:200}"; fail=$((fail+1))
fi

# ---- a command read as a shell reads it ---------------------------------------
#
# The scoped prefix counts where a simple command begins with it after shell tokenising, so the
# common wrappers are seen through and quoted text is not a command. row_bash does not escape JSON,
# so these rows go through a JSON encoder, and each case first reads its row back: a malformed row
# is skipped silently and would block for the wrong reason.
row_cmd() { python3 -c 'import json,sys; print(json.dumps({"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":sys.argv[1]}}]}}))' "$1"; }

shell_case() {   # shell_case <want: quiet|block> <command>; an edit of lib/foo.sh, then the command
    local want="$1" cmd="$2" t="$begins/shell.jsonl" out rc
    { row_user "go"; row_edit "$begins/lib/foo.sh" ""; row_cmd "$cmd"; } > "$t"
    if ! python3 -c 'import json,sys; r=json.loads(open(sys.argv[1]).read().splitlines()[-1]); sys.exit(r["message"]["content"][0]["input"]["command"] != sys.argv[2])' "$t" "$cmd"; then
        printf '  FAIL  %s (the row did not carry the command intact)\n' "$want: $cmd"; fail=$((fail+1)); return
    fi
    out="$(send "$begins" "$t" Stop)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        printf '  FAIL  %s (rc=%s)\n' "$want: $cmd" "$rc"; fail=$((fail+1)); return
    fi
    expect "$want: $(printf '%s' "$cmd" | tr '\n' '~')" "$want" "$out"
}

# Behaviour 1: the wrapped forms count as a run.
shell_case quiet 'bash tests/x.sh'
shell_case quiet './tests/x.sh'
shell_case quiet 'env CI=1 tests/x.sh'
shell_case quiet 'X=1 time tests/x.sh'
shell_case quiet 'make lint & tests/x.sh'
shell_case quiet 'if true; then tests/x.sh; fi'
shell_case quiet "$(printf 'echo hi\ntests/x.sh')"
# shellcheck disable=SC2016  # the $( ) is the command's literal text
shell_case quiet '$(tests/x.sh)'
shell_case quiet '(cd x); tests/x.sh'
shell_case quiet '{ tests/x.sh; }'
# ...and nothing the anchored match did not count before, beyond those forms.
shell_case block 'echo then tests/x.sh'
shell_case block '{tests/a,b}'
shell_case block "echo ';' tests/x.sh"
shell_case block 'make >& tests/x.log'
shell_case block "echo '' tests/x.sh"
shell_case block 'echo "" tests/x.sh'
shell_case block "'then' tests/x.sh"
shell_case block '"{" tests/x.sh'
# A `#` starting a word begins a comment that ends at the newline; one inside a word is no comment.
shell_case quiet "$(printf 'ls # c\ntests/x.sh')"
shell_case quiet 'echo a#b; tests/x.sh'
shell_case block 'ls # tests/x.sh'

# Behaviour 2: quoted text is not a command.
shell_case block 'echo "a;tests/x"'
shell_case block "grep -n 'tests/x' f"
shell_case block 'shellcheck -x lib/foo.sh tests/*.sh'

# Behaviour 3: a command shlex cannot tokenise falls back to the anchored regex.
shell_case quiet "tests/x.sh 'oops"

# ---- every checkout of the repository ---------------------------------------------
#
# Behaviour 4. An edit is inside the repository when it resolves inside any checkout of it, and
# is read against the checkout that holds it. The worktree has the profile because it is committed.
mr="$tmp/main-repo"
fixture "$mr" '"done_verified": "required"' '"tests/run-tests.sh"'
( cd "$mr" && git init -q -b main . && git config user.email t@t.t && git config user.name t \
  && git add .keel/profile.json && git commit -q -m init \
  && git worktree add -q "$tmp/wt" 2>/dev/null && git worktree add -q "$mr/inner" 2>/dev/null )
{ row_user "go"; row_edit "$mr/lib/foo.sh" ""; } > "$tmp/wt-main.jsonl"
expect "from a linked worktree, an edit in the main checkout with no test run blocks" block \
    "$(send "$tmp/wt" "$tmp/wt-main.jsonl" Stop)"
{ row_user "go"; row_write "/tmp/elsewhere/x.py"; } > "$tmp/wt-else.jsonl"
expect "from a linked worktree, an edit outside every checkout passes" quiet \
    "$(send "$tmp/wt" "$tmp/wt-else.jsonl" Stop)"
{ row_user "go"; row_write "$mr/inner/docs/x.txt"; } > "$tmp/wt-inner.jsonl"
expect "a worktree inside the main checkout reads docs_root against its own root" quiet \
    "$(send "$mr" "$tmp/wt-inner.jsonl" Stop)"

# Behaviour 5. git runs only when the turn edited something. A shim first on PATH records each call
# and runs the real git; removing git from PATH proves nothing, since the hook catches OSError.
real_git="$(command -v git)"
mkdir -p "$tmp/shim"
printf '#!/bin/sh\necho "$*" >> "%s"\nexec "%s" "$@"\n' "$tmp/shim/calls" "$real_git" > "$tmp/shim/git"
chmod +x "$tmp/shim/git"
{ row_user "go"; row_cmd "ls"; } > "$tmp/noedit.jsonl"
: > "$tmp/shim/calls"
out="$(PATH="$tmp/shim:$PATH" send "$mr" "$tmp/noedit.jsonl" Stop)"; rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -s "$tmp/shim/calls" ]; then
    printf '  PASS  %s\n' "a Stop with no edit runs no git"; pass=$((pass+1))
else
    printf '  FAIL  %s (rc=%s, out=%s, calls=%s)\n' "a Stop with no edit runs no git" "$rc" "${out:0:80}" "$(tr '\n' ';' < "$tmp/shim/calls")"; fail=$((fail+1))
fi
: > "$tmp/shim/calls"
out="$(PATH="$tmp/shim:$PATH" send "$mr" "$tmp/wt-main.jsonl" Stop)"
if [ -s "$tmp/shim/calls" ]; then
    printf '  PASS  %s\n' "a Stop with an edit runs git"; pass=$((pass+1))
else
    printf '  FAIL  %s (no git call recorded, out=%s)\n' "a Stop with an edit runs git" "${out:0:80}"; fail=$((fail+1))
fi

# ---- escapes, comments, the superproject and a long command --------------------------
#
# A backslash before a punctuation token makes it a word, so it separates nothing.
shell_case block 'echo \; tests/x.sh'
# A `#` inside quotes is a word, so it begins no comment and the run after the `;` counts.
shell_case quiet "echo '#'; tests/x.sh"
# A token at the start of the command has nothing before it to escape it, so a backslash at the
# command's end is never read as one: the `#` begins a comment, and the run inside it is no run.
shell_case block "#; tests/x.sh a\\\\"

# An edit in the superproject, made from a submodule's cwd, is in the repository: the submodule's
# own top level and worktree list both stop at the submodule, so only the superproject names it.
sup="$tmp/super"
fixture "$sup" '"done_verified": "required"' '"tests/run-tests.sh"'
( mkdir -p "$tmp/sub-src" && cd "$tmp/sub-src" && git init -q -b main . \
  && git -c user.email=t@t.t -c user.name=t commit -q --allow-empty -m init ) >/dev/null 2>&1
( cd "$sup" && git init -q -b main . && git config user.email t@t.t && git config user.name t \
  && git add .keel/profile.json \
  && git -c protocol.file.allow=always submodule add -q "$tmp/sub-src" sub \
  && git commit -q -m init ) >/dev/null 2>&1
{ row_user "go"; row_edit "$sup/lib/foo.sh" ""; } > "$tmp/super-edit.jsonl"
if [ -d "$sup/sub" ] && [ -e "$sup/sub/.git" ]; then
    expect "from a submodule's cwd, an edit in the superproject with no test run blocks" block \
        "$(send "$sup/sub" "$tmp/super-edit.jsonl" Stop)"
else
    printf '  FAIL  %s\n' "the submodule fixture was not built"; fail=$((fail+1))
fi

# Telling a bare token from a quoted one is linear in the command. A fixed time limit fails a
# correct hook on a slow runner and passes a quadratic one on a fast machine, so the case times a
# heredoc of N lines and one of 4N and asserts on how the time grows: linear gives at most 4,
# quadratic at most 16 (fixed costs pull both lower, about 13 measured), and 8 sits between.
# Each row is written by python, since one argument that size is over Linux's per-argument limit.
heredoc_run() {   # heredoc_run <lines> <transcript>; prints the seconds, the output goes to <transcript>.out
    { row_user "go"; row_edit "$begins/lib/foo.sh" ""; } > "$2"
    python3 -c 'import json,sys
cmd = "cat > f <<'"'"'EOF'"'"'\n" + "a line\n" * int(sys.argv[1]) + "EOF\n; tests/x.sh"
print(json.dumps({"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":cmd}}]}}))' "$1" >> "$2"
    local t0 t1
    t0="$(python3 -c 'import time; print(time.time())')"
    send "$begins" "$2" Stop > "$2.out"
    t1="$(python3 -c 'import time; print(time.time())')"
    python3 -c 'import sys; print("%.3f" % (float(sys.argv[2]) - float(sys.argv[1])))' "$t0" "$t1"
}
small="$(heredoc_run 40000 "$begins/big1.jsonl")"
expect "a 280 KB heredoc followed by a run is judged a run" quiet "$(cat "$begins/big1.jsonl.out")"
large="$(heredoc_run 160000 "$begins/big2.jsonl")"
expect "a 1.1 MB heredoc followed by a run is judged a run" quiet "$(cat "$begins/big2.jsonl.out")"
if python3 -c 'import sys; sys.exit(float(sys.argv[2]) >= 8 * float(sys.argv[1]))' "$small" "$large"; then
    printf '  PASS  %s\n' "four times the command takes under eight times as long ($small s, $large s)"; pass=$((pass+1))
else
    printf '  FAIL  %s (took %s s, then %s s)\n' "four times the command takes under eight times as long" "$small" "$large"; fail=$((fail+1))
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
