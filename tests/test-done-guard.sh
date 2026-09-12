#!/usr/bin/env bash
# Tests for hooks/done-guard, registered on Stop and SubagentStop.
#
# The guard asserts on emitted JSON rather than exit code, for the same reason sensitive-guard's
# tests do: a hook that exits 0 emitting nothing is indistinguishable from one that is not
# installed. The difference from sensitive-guard is case 8. That guard asks a human whenever it
# cannot answer. This one has no human to ask, because a denied Stop just runs again, so it warns
# and allows. A guard that hangs a session is a guard that gets deleted.

set -uo pipefail

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

# ---- Codex rollouts --------------------------------------------------------
#
# Codex hands its hooks a rollout, not a Claude Code transcript. Before 2026-09-06 the reader
# returned an empty list for one, which this hook cannot tell from a turn that ran no tools, so
# every Codex turn passed in silence. These cases are what stop that returning.
#
# The synthetic rows below mirror the shape of tests/fixtures/transcripts/codex.jsonl, which is a
# real capture from codex-cli 0.153.4 and is exercised at the end of this section. Synthetic here
# for the same reason as the Claude cases above: a recording pins one turn, and what these need to
# vary is what the turn did.

cx_user()  { printf '{"timestamp":"2026-09-06T07:16:44Z","ordinal":%s,"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"go"}],"internal_chat_message_metadata_passthrough":{"turn_id":"%s"}}}\n' "$1" "$2"; }
cx_call()  { printf '{"timestamp":"2026-09-06T07:16:47Z","ordinal":%s,"type":"response_item","payload":{"type":"custom_tool_call","name":"exec","input":%s,"internal_chat_message_metadata_passthrough":{"turn_id":"%s"}}}\n' "$1" "$2" "$3"; }

# The exec input as Codex actually writes it: a JS snippet with the command JSON-escaped inside it.
cx_edit_input() { printf '"const r = await tools.exec_command({\\"cmd\\":\\"apply_patch <<EOF\\\\n*** Begin Patch\\\\n*** Update File: %s\\\\n*** End Patch\\\\nEOF\\"});"' "$1"; }
cx_test_input() { printf '"const r = await tools.exec_command({\\"cmd\\":\\"%s\\"});"' "$1"; }

fixture "$tmp/cx" '"done_verified": "required"' '"tests/run-tests.sh"'

# An apply_patch edit with no test run is the case the guard exists for.
{ cx_user 8 t1; cx_call 14 "$(cx_edit_input src/a.py)" t1; } > "$tmp/cx/edit.jsonl"
expect "a Codex apply_patch edit with no test run blocks" block "$(send "$tmp/cx" "$tmp/cx/edit.jsonl" Stop)"

# ...and running the suite clears it, read from the same escaped snippet.
{ cx_user 8 t1; cx_call 14 "$(cx_edit_input src/a.py)" t1; cx_call 15 "$(cx_test_input tests/run-tests.sh)" t1; } > "$tmp/cx/ran.jsonl"
expect "a Codex turn that ran the suite is quiet" quiet "$(send "$tmp/cx" "$tmp/cx/ran.jsonl" Stop)"

# Documentation turns pass on Codex too, the same as on Claude Code.
{ cx_user 8 t1; cx_call 14 "$(cx_edit_input docs/a.md)" t1; } > "$tmp/cx/docs.jsonl"
expect "a Codex documentation edit does not need the suite" quiet "$(send "$tmp/cx" "$tmp/cx/docs.jsonl" Stop)"

# Turn scoping, and on Codex the boundary is STATED rather than inferred: an edit carrying an
# earlier turn_id is not this turn's work. Without the turn_id check this blocks.
{ cx_user 8 t1; cx_call 14 "$(cx_edit_input src/old.py)" t1; cx_user 20 t2; } > "$tmp/cx/old.jsonl"
expect "a Codex edit from an earlier turn is not counted" quiet "$(send "$tmp/cx" "$tmp/cx/old.jsonl" Stop)"

# A rollout carrying NO turn id anywhere. The header's rule is that records with no turn id are
# pre-turn setup and are not this turn's work, and the code applied it only while a turn id had been
# found somewhere: with none, `turn` stayed None, the filter was skipped, and every custom_tool_call
# in the whole file counted as this turn's. So a turn that answered a question was blocked for an
# apply_patch from twenty turns ago, on any rollout shape that carries no turn id.
cx_user_noid() { printf '{"timestamp":"2026-09-06T07:16:44Z","ordinal":%s,"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"go"}]}}\n' "$1"; }
cx_call_noid() { printf '{"timestamp":"2026-09-06T07:16:47Z","ordinal":%s,"type":"response_item","payload":{"type":"custom_tool_call","name":"exec","input":%s}}\n' "$1" "$2"; }
{ cx_user_noid 8; cx_call_noid 14 "$(cx_edit_input src/ancient.py)"; cx_user_noid 20; } > "$tmp/cx/noid.jsonl"
expect "a rollout with no turn id anywhere attributes nothing to this turn" quiet "$(send "$tmp/cx" "$tmp/cx/noid.jsonl" Stop)"

# A Codex rollout with no tool calls is a clean turn, not an unreadable file. It must be quiet
# rather than warn, or every Codex turn that only answered a question ends with a notice.
{ cx_user 8 t1; } > "$tmp/cx/none.jsonl"
expect "a Codex turn with no tool calls is quiet, not a warning" quiet "$(send "$tmp/cx" "$tmp/cx/none.jsonl" Stop)"

# A patch BODY that mentions the test command is content, not a command run. Left unstripped, a
# turn that edits any file quoting `tests/run-tests.sh`, and this repository is full of them, reads
# as having run the suite and the guard goes quiet on the very edit it exists to catch.
cx_sneaky() { printf '"const r = await tools.exec_command({\\"cmd\\":\\"apply_patch <<EOF\\\\n*** Begin Patch\\\\n*** Update File: src/a.py\\\\n+# see tests/run-tests.sh for how to check this\\\\n*** End Patch\\\\nEOF\\"});"'; }
{ cx_user 8 t1; cx_call 14 "$(cx_sneaky)" t1; } > "$tmp/cx/sneaky.jsonl"
expect "a test command quoted inside a patch body is not a test run" block "$(send "$tmp/cx" "$tmp/cx/sneaky.jsonl" Stop)"

# THE CANARY section 10.3 of docs/architecture/tiered-multi-harness-support.md requires, and the
# evidence behind the codex transcript_turn_tool_calls row in lib/harness/capabilities. The capture
# ran one shell command and edited nothing, so a clean turn is the right answer; what it proves is
# that the real shape still parses. When Codex changes its rollout format this goes red, rather
# than the guard going quiet on every Codex turn.
real_cx="$ROOT_DIR/tests/fixtures/transcripts/codex.jsonl"
expect "a rollout captured from a real Codex turn still parses" quiet "$(send "$tmp/cx" "$real_cx" Stop)"

# ...and the same capture with its one exec call rewritten as an edit must block. Without this the
# case above passes just as well against a reader that returns nothing at all for a rollout, which
# is exactly the fail-open this section was added to close.
python3 - "$real_cx" "$tmp/cx/real-edit.jsonl" <<'EOF'
import json, sys
out = []
for line in open(sys.argv[1], encoding="utf-8"):
    r = json.loads(line)
    p = r.get("payload") or {}
    if p.get("type") == "custom_tool_call":
        p["input"] = ('const r = await tools.exec_command({"cmd":"apply_patch <<EOF\\n'
                      '*** Begin Patch\\n*** Update File: src/real.py\\n*** End Patch\\nEOF"});')
    out.append(r)
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    for r in out:
        fh.write(json.dumps(r) + "\n")
EOF
expect "an edit in a real rollout is seen" block "$(send "$tmp/cx" "$tmp/cx/real-edit.jsonl" Stop)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
