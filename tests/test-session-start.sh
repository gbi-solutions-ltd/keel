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

# A profile carrying the two keys. Either may be empty, meaning that key is absent.
fixture() {   # fixture <root> <response_style-or-empty> <explain_level-or-empty>
    local root="$1" style="$2" level="$3" body=""
    mkdir -p "$root/.keel"
    [ -n "$style" ] && body="\"response_style\": \"$style\""
    if [ -n "$level" ]; then
        [ -n "$body" ] && body="$body, "
        body="$body\"explain_level\": \"$level\""
    fi
    printf '{\n  "conventions": {%s}\n}\n' "$body" > "$root/.keel/profile.json"
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

# `want` names which of the four forms is expected: brief, plain-terse, plain-verbose, or none.
# Matching a named form rather than a substring is load bearing. "Replies stay brief" is a prefix of
# both the brevity paragraph and the terse-plus-plain one, so a substring check passes whichever of
# the two the hook picked, which is precisely the bug this file exists to catch.
check() {   # check <name> <root> <want: brief|plain-terse|plain-verbose|none>
    local name="$1" root="$2" want="$3" out got
    if ! out="$(context_of "$root")"; then
        bad "$name" "hook did not emit valid JSON"
        return 0
    fi
    case "$out" in
        *"pick a skill"*) ;;
        *) bad "$name" "the routing text is missing"; return 0 ;;
    esac
    case "$out" in
        *"Replies stay brief and plain"*)            got=plain-terse ;;
        *"Replies stay plain"*)                      got=plain-verbose ;;
        *"Replies stay brief; artifacts stay full"*) got=brief ;;
        *)                                           got=none ;;
    esac
    if [ "$got" = "$want" ]; then ok "$name"
    else bad "$name" "expected the $want form, got $got"; fi
}

# 1. Both keys absent. Existing projects get the documented defaults without re-running init.
fixture "$tmp/a" "" ""
check "no keys at all is terse and technical" "$tmp/a" brief

# 2. The written defaults.
fixture "$tmp/b" "terse" "technical"
check "terse and technical injects the brevity rule" "$tmp/b" brief

# 3. The length opt-out, unchanged by the explain_level work.
fixture "$tmp/c" "verbose" "technical"
check "verbose and technical injects nothing" "$tmp/c" none

# 4. The vocabulary opt-in, on the default length. This is the combination the feature is for.
fixture "$tmp/g" "terse" "plain"
check "terse and plain injects the plain rule with the brevity rule" "$tmp/g" plain-terse

# 5. Both dials moved. It must have a paragraph rather than falling through to silence, which is
# what a hook keyed on one variable at a time would do.
fixture "$tmp/h" "verbose" "plain"
check "verbose and plain injects the plain rule alone" "$tmp/h" plain-verbose

# 6. explain_level alone, with response_style absent and therefore terse.
fixture "$tmp/i" "" "plain"
check "explain_level alone is read, and response_style defaults to terse" "$tmp/i" plain-terse

# 7. An unrecognised value falls back to the documented default rather than to silence.
fixture "$tmp/j" "terse" "simple"
check "an unrecognised explain_level is treated as technical" "$tmp/j" brief

# 8. No profile at all. A session outside a keel project must still start.
mkdir -p "$tmp/d"
check "no profile still emits valid JSON and the router pointer" "$tmp/d" brief

# 9. The hook runs from a subdirectory as readily as the root, the way sensitive-guard does. A
# session started in src/ is ordinary and must not silently lose the rule.
fixture "$tmp/e" "verbose" "plain"
mkdir -p "$tmp/e/src/deep"
check "the profile is found from a subdirectory" "$tmp/e/src/deep" plain-verbose

# 10. An unreadable profile must degrade to the defaults, not take the whole injection down with
# it. Found by review before the first ship: `set -e` plus the read being the last command in an &&
# chain meant the hook exited 1 and printed nothing, so the session lost the router pointer entirely
# and the failure looked like the plugin was not installed.
#
# Skipped as root, which can read a 000 file, so the case would pass while testing nothing.
if [ "$(id -u)" -eq 0 ]; then
    printf '  SKIP  unreadable profile degrades to the defaults (running as root)\n'
else
    fixture "$tmp/f" "verbose" "plain"
    chmod 000 "$tmp/f/.keel/profile.json"
    check "an unreadable profile degrades to terse and technical" "$tmp/f" brief
    chmod 644 "$tmp/f/.keel/profile.json"
fi

# The four forms are asserted at their exact measured sizes, not as an upper bound. NFR-01 of
# docs/prd/plain-language-chat.md caps every combination at 1285 characters and the wordings were
# chosen against that, so a wording edit has to be a deliberate act with a re-measurement rather
# than a drift that stays green until it does not.
size_of() {   # size_of <cwd>
    ( cd "$1" && "$HOOK" ) 2>/dev/null | wc -c | tr -d ' '
}
# Re-measured 2026-08-30 when design-database was added to the router. Adding a skill name costs 17
# characters against the 1 the worst form had spare, so four phrases were trimmed in the same edit:
# "Unsure which fits:" to "Unsure:", "for Oracle APEX" dropped from a line whose two skill names
# already carry the word, "is down now:" to "is down:", and "when no skill fits" to "when none fits".
# No skill name was dropped. The four forms fell by 18 characters each and the worst is now 1266,
# 351 tokens, which is 5 tokens inside NFR-01 rather than the 0 the first costing would have left.
for spec in "b:1266:terse and technical" "g:1265:terse and plain" \
            "c:1064:verbose and technical" "h:1255:verbose and plain"; do
    dir="${spec%%:*}"; rest="${spec#*:}"; want="${rest%%:*}"; label="${rest#*:}"
    got="$(size_of "$tmp/$dir")"
    if [ "$got" = "$want" ]; then
        ok "$label injects exactly $want characters"
    else
        bad "size" "$label injects $got characters, expected $want. NFR-01 caps every form at 1285"
    fi
done


# Every request of every session carries this prefix, so a byte added here is paid forever. It
# measured about 356 estimated tokens on 2026-08-18 against a 400 ceiling, and the remaining
# headroom is already spoken for by two other ideas. Nothing in the context window work touches
# this file; this is what says so a year from now.
#
# Measured the same way tests/validate-skills.sh does, at chars over 3.6, so the two can never
# disagree about the number.
#
# Two things here are load bearing, and the first version of this check had neither. It ran the
# hook by a relative path, so from any other working directory the command failed, chars came out
# 0, and `0 -le 356` passed: the hook could have been deleted and this stayed green. And a bound
# with no floor cannot tell "unchanged" from "produced nothing". $HOOK is absolute, and the lower
# bound is what makes a silent failure a failure.
chars=$("$HOOK" 2>/dev/null | wc -c | tr -d ' ')
est=$(( chars * 10 / 36 ))
if [ "$est" -ge 300 ] && [ "$est" -le 356 ]; then
    ok "the injected session prefix is still about $est tokens, between 300 and 356"
elif [ "$est" -lt 300 ]; then
    bad "prefix" "the prefix measured about $est tokens, below the 300 floor. Either it shrank sharply or the hook did not run at all, and this check cannot tell those apart by design"
else
    bad "prefix" "the prefix grew to about $est tokens; the 400 ceiling has 44 tokens of headroom and it is spoken for"
fi

# Both plain forms must keep artifacts exempt from the brevity rule, not merely from the vocabulary
# rule. "artifacts stay full" is the only thing in the injected context that says a PRD or a plan is
# not shortened, and the first version of the plain paragraphs replaced it with "artifacts stay
# technical", which answers a different question. A terse-plus-plain session then carried
# "Replies stay brief and plain" with nothing exempting artifacts at all. Caught in review, and this
# is what stops it coming back.
for spec in "g:terse and plain" "h:verbose and plain"; do
    dir="${spec%%:*}"; label="${spec#*:}"
    out="$(context_of "$tmp/$dir")"
    case "$out" in
        *"artifacts full and technical"*)
            ok "$label keeps artifacts exempt from brevity, not just from jargon" ;;
        *)
            bad "artifacts" "$label does not say artifacts stay full: brevity can bleed into a PRD" ;;
    esac
done

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
