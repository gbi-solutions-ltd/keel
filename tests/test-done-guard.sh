#!/usr/bin/env bash
# Tests for hooks/done-guard, registered on Stop and SubagentStop.
#
# The guard asserts on emitted JSON rather than exit code, for the same reason sensitive-guard's
# tests do: a hook that exits 0 emitting nothing is indistinguishable from one that is not
# installed. The difference from sensitive-guard is case 8. That guard asks a human whenever it
# cannot answer. This one has no human to ask, because a denied Stop just runs again, so it warns
# and allows. A guard that hangs a session is a guard that gets deleted.

set -uo pipefail

GUARD="$(cd "$(dirname "$0")/.." && pwd)/hooks/done-guard"
pass=0
fail=0

fixture() {   # fixture <root> <gate-json-or-empty> <verify-test-json>
    local root="$1" gate="$2" test_cmd="$3"
    mkdir -p "$root/.keel" "$root/lib" "$root/docs"
    printf '{\n  "verify": {"test": %s},\n  "gates": {%s},\n  "docs_root": "docs"\n}\n' \
        "$test_cmd" "$gate" > "$root/.keel/profile.json"
}

# A Stop event. edits is a space separated list of paths; cmds is a pipe separated list of Bash
# commands. Built through python3 so a command containing quotes cannot produce invalid JSON,
# which is the bug that made a sensitive-guard case pass while testing nothing.
event() {   # event <cwd> <stop_hook_active> <edits> <cmds> [hook_event_name]
    CWD="$1" ACTIVE="$2" EDITS="$3" CMDS="$4" EVNAME="${5:-Stop}" python3 -c '
import json, os
calls = []
for p in os.environ["EDITS"].split():
    calls.append({"tool_name": "Edit", "tool_use_id": "x", "tool_input": {"file_path": p}})
for c in os.environ["CMDS"].split("|"):
    if c:
        calls.append({"tool_name": "Bash", "tool_use_id": "y", "tool_input": {"command": c}})
print(json.dumps({"hook_event_name": os.environ["EVNAME"], "cwd": os.environ["CWD"],
                  "stop_hook_active": os.environ["ACTIVE"] == "1",
                  "last_assistant_message": "All set.", "tool_calls": calls}))'
}

check() {   # check <name> <want: deny|warn|none> <root> <active> <edits> <cmds>
    local name="$1" want="$2" root="$3" active="$4" edits="$5" cmds="$6" out
    out="$(event "$root" "$active" "$edits" "$cmds" | ( cd "$root" && "$GUARD" ) 2>/dev/null)"
    case "$want" in
        deny)
            if printf '%s' "$out" | grep -q '"decision": *"deny"'; then
                printf '  PASS  %s\n' "$name"; pass=$((pass+1))
            else
                printf '  FAIL  %s (expected deny, got: %s)\n' "$name" "${out:0:90}"; fail=$((fail+1))
            fi ;;
        warn)
            if printf '%s' "$out" | grep -q '"systemMessage"' \
               && ! printf '%s' "$out" | grep -q '"decision": *"deny"'; then
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
if printf '%s' "$out" | grep -q '"decision": *"deny"' \
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

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
