#!/usr/bin/env bash
# Tests for hooks/session-start, which injects the router pointer and, unless the project opts out,
# the brevity rule.
#
# Every case parses the emitted JSON. A hook that prints malformed JSON fails the session start
# itself, which is a worse failure than injecting the wrong text and is invisible in a grep.
#
# Case 3 is the one that matters. A hook that ignores conventions.response_style looks identical to
# a working one until somebody opts out, and the person opting out is by definition the person least
# inclined to file a bug about it.

set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/session-start"
pass=0
fail=0

ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL  %s (%s)\n' "$1" "$2"; fail=$((fail+1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# A profile carrying just the one key. `style` empty means no conventions block at all.
fixture() {   # fixture <root> <style-or-empty>
    local root="$1" style="$2"
    mkdir -p "$root/.keel"
    if [ -n "$style" ]; then
        printf '{\n  "conventions": {"response_style": "%s"}\n}\n' "$style" > "$root/.keel/profile.json"
    else
        printf '{\n  "conventions": {}\n}\n' > "$root/.keel/profile.json"
    fi
}

# Returns the injected context, or exits non-zero if the hook did not emit valid JSON.
context_of() {   # context_of <cwd>
    ( cd "$1" && "$HOOK" ) 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception as e:
    print("INVALID JSON: %s" % e); sys.exit(1)
print(d["hookSpecificOutput"]["additionalContext"])'
}

check() {   # check <name> <root> <want-brevity: yes|no>
    local name="$1" root="$2" want="$3" out
    if ! out="$(context_of "$root")"; then
        bad "$name" "hook did not emit valid JSON"
        return 0
    fi
    case "$out" in
        *"pick a skill"*) ;;
        *) bad "$name" "the routing text is missing"; return 0 ;;
    esac
    case "$out" in
        *"Replies stay brief"*)
            if [ "$want" = yes ]; then ok "$name"
            else bad "$name" "brevity rule present and should not be"; fi ;;
        *)
            if [ "$want" = no ]; then ok "$name"
            else bad "$name" "brevity rule absent and should be present"; fi ;;
    esac
}

# 1. Absent means terse. Existing projects get the behaviour without re-running init.
fixture "$tmp/a" ""
check "no response_style key is treated as terse" "$tmp/a" yes

# 2. The written default.
fixture "$tmp/b" "terse"
check "response_style terse injects the rule" "$tmp/b" yes

# 3. The opt-out. The user decides they want verbose.
fixture "$tmp/c" "verbose"
check "response_style verbose suppresses the rule" "$tmp/c" no

# 4. No profile at all. A session outside a keel project must still start.
mkdir -p "$tmp/d"
check "no profile still emits valid JSON and the router pointer" "$tmp/d" yes

# 5. The hook runs from a subdirectory as readily as the root, the way sensitive-guard does. A
# session started in src/ is ordinary and must not silently lose the rule.
fixture "$tmp/e" "verbose"
mkdir -p "$tmp/e/src/deep"
check "the profile is found from a subdirectory" "$tmp/e/src/deep" no

# 6. An unreadable profile must degrade to terse, not take the whole injection down with it. Found
# by review before the first ship: `set -e` plus the read being the last command in an && chain
# meant the hook exited 1 and printed nothing, so the session lost the router pointer entirely and
# the failure looked like the plugin was not installed.
#
# Skipped as root, which can read a 000 file, so the case would pass while testing nothing.
if [ "$(id -u)" -eq 0 ]; then
    printf '  SKIP  unreadable profile degrades to terse (running as root)\n'
else
    fixture "$tmp/f" "verbose"
    chmod 000 "$tmp/f/.keel/profile.json"
    check "an unreadable profile degrades to terse" "$tmp/f" yes
    chmod 644 "$tmp/f/.keel/profile.json"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
