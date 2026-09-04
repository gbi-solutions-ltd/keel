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

# ---- the loaded plugin version -------------------------------------------------------------
#
# The hook prints the version of the plugin copy the session loaded, which is the one fact a session
# cannot learn any other way: CLAUDE_PLUGIN_ROOT reaches a plugin's own hooks and not `keel` on
# PATH, and on a developer machine those are routinely different copies a full release apart.
#
# Every case below asserts the hook still exits 0 and still carries the router pointer, because the
# failure being guarded against is a dead hook rather than a missing line. A hook that exits
# non-zero prints nothing at all, and a session that loses the router looks exactly like one where
# the plugin is not installed. That is the failure case 10 above records for the profile read.
version_line_of() {   # version_line_of <plugin-root-or-empty>
    local pr="$1" out
    if [ -n "$pr" ]; then out="$( cd "$tmp/d" && CLAUDE_PLUGIN_ROOT="$pr" "$HOOK" 2>/dev/null )"
    else out="$( cd "$tmp/d" && "$HOOK" 2>/dev/null )"; fi
    printf '%s' "$out" | python3 -c '
import json, sys
try:
    c = json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]
except Exception:
    print("INVALID-JSON"); sys.exit(0)
if "pick a skill" not in c:
    print("NO-ROUTER"); sys.exit(0)
hits = [l for l in c.split("\n") if l.startswith("keel ")]
print(hits[0] if hits else "NONE")'
}

check_version() {   # check_version <name> <plugin-root-or-empty> <expected line or NONE>
    local name="$1" got
    got="$(version_line_of "$2")"
    if [ "$got" = "$3" ]; then ok "$name"
    else bad "version" "$name: expected [$3], got [$got]"; fi
}

vroot="$tmp/plug"

# 11. The ordinary case. A plugin root carrying a VERSION puts one line in the context.
mkdir -p "$vroot/ok" && printf '9.9.9\n' > "$vroot/ok/VERSION"
check_version "a plugin root's VERSION reaches the session context" "$vroot/ok" "keel 9.9.9"

# 12. CLAUDE_PLUGIN_ROOT unset, which no real install produces and every test invocation does. The
# BASH_SOURCE fallback has to resolve to this repository, or the four size assertions below are
# measuring something other than what a session sees.
check_version "with CLAUDE_PLUGIN_ROOT unset the fallback finds this repository" "" "keel $(cat "$(dirname "$HOOK")/../VERSION")"

# 13. No VERSION at all, which is what a partial or hand-assembled install looks like.
mkdir -p "$vroot/none"
check_version "an absent VERSION drops the line and keeps the router" "$vroot/none" NONE

# 14. An unreadable VERSION. Same guard as case 10, and the one that regresses the moment somebody
# simplifies `[ -r ... ]` away: under `set -e` the read is the last command in an && chain, so a
# failure takes the whole hook down rather than the line.
#
# Skipped as root, which can read a 000 file, so the case would pass while testing nothing.
mkdir -p "$vroot/unreadable" && printf '1.2.3\n' > "$vroot/unreadable/VERSION"
if [ "$(id -u)" -eq 0 ]; then
    printf '  SKIP  an unreadable VERSION drops the line and keeps the router (running as root)\n'
else
    chmod 000 "$vroot/unreadable/VERSION"
    check_version "an unreadable VERSION drops the line and keeps the router" "$vroot/unreadable" NONE
    chmod 644 "$vroot/unreadable/VERSION"
fi

# 15. Whitespace, which is checked as its own rule in the hook rather than left to the character
# set. A newline breaks the one-line contract of the injected context and escape() would ship it
# rather than reject it. Three shapes, because a set widened later may stop excluding one of them
# as a side effect: that is exactly what happened to this guard on 2026-09-02.
mkdir -p "$vroot/multiline" && printf '0.1\nrm -rf /\n' > "$vroot/multiline/VERSION"
check_version "a multiline VERSION is dropped rather than escaped and shipped" "$vroot/multiline" NONE
mkdir -p "$vroot/space" && printf '0.17.0 rc1\n' > "$vroot/space/VERSION"
check_version "a VERSION containing a space is dropped" "$vroot/space" NONE
mkdir -p "$vroot/tab" && printf '0.17\t0\n' > "$vroot/tab/VERSION"
check_version "a VERSION containing a tab is dropped" "$vroot/tab" NONE

# 16. A pre-release version. Letters and hyphens are accepted since 2026-09-02: the digits-and-dots
# set that shipped that morning dropped the line silently for `0.17.0-rc.1`, which is the release
# where knowing which copy a session loaded matters most and the one nobody would have checked.
mkdir -p "$vroot/prerelease" && printf '0.17.0-rc.1\n' > "$vroot/prerelease/VERSION"
check_version "a pre-release VERSION is kept, letters and hyphens included" "$vroot/prerelease" "keel 0.17.0-rc.1"

# A character outside the widened set is still dropped, so widening did not become anything-goes.
mkdir -p "$vroot/slash" && printf '0.17/0\n' > "$vroot/slash/VERSION"
check_version "a VERSION containing a slash is still dropped" "$vroot/slash" NONE

# 17. A VERSION of 300 digits. This is the case that is only found by running the guard: it passes
# any plausible character set and would blow NFR-01 on its own, which is why the length bound is a
# separate test rather than folded into the class.
mkdir -p "$vroot/long" && python3 -c "print('9' * 300)" > "$vroot/long/VERSION"
check_version "a 300 character VERSION is dropped by the length bound" "$vroot/long" NONE

# 18. The cap, from both sides and on both shapes, because twelve has to be what is under test
# rather than the character set. A twelve character pre-release is accepted and a thirteen character
# one is not, and the same pair for a plain numeric version. Four cases, one number.
mkdir -p "$vroot/twelve-pre" && printf '0.17.0-rc.12\n' > "$vroot/twelve-pre/VERSION"
check_version "a twelve character pre-release VERSION is kept" "$vroot/twelve-pre" "keel 0.17.0-rc.12"
mkdir -p "$vroot/thirteen-pre" && printf '0.17.0-rc.123\n' > "$vroot/thirteen-pre/VERSION"
check_version "a thirteen character pre-release VERSION is dropped" "$vroot/thirteen-pre" NONE
mkdir -p "$vroot/thirteen" && printf '1.2.3.4.5.6.7\n' > "$vroot/thirteen/VERSION"
check_version "a thirteen character numeric VERSION is dropped" "$vroot/thirteen" NONE
mkdir -p "$vroot/eleven" && printf '100.100.100\n' > "$vroot/eleven/VERSION"
check_version "an eleven character numeric VERSION is kept" "$vroot/eleven" "keel 100.100.100"

# 19. And the longest version the cap accepts must still fit NFR-01, which is the whole reason the
# cap is twelve rather than a round number. Measured on the worst of the four forms rather than on
# the one this repository selects, and on a twelve character version rather than the eleven above,
# because twelve is the boundary and eleven would leave the assertion a character of slack.
long_chars="$( cd "$tmp/b" && CLAUDE_PLUGIN_ROOT="$vroot/twelve-pre" "$HOOK" 2>/dev/null | wc -c | tr -d ' ' )"
if [ "$long_chars" -le 1285 ]; then
    ok "the longest version the cap accepts still fits NFR-01 at $long_chars characters"
else
    bad "version" "a twelve character version puts the worst form at $long_chars characters, over the 1285 of NFR-01. The cap in hooks/session-start and this ceiling have to move together"
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
# No skill name was dropped. The four forms fell by 18 characters each and the worst was then 1266,
# 351 tokens, which is 5 tokens inside NFR-01 rather than the 0 the first costing would have left.
#
# Re-measured 2026-09-02 when the hook began printing the loaded plugin version. Every form grew by
# 13: two characters for the newline escape() renders as `\n`, five for `keel `, and six for the
# version string itself. The worst is now 1279, 355 tokens, one inside NFR-01.
#
# THESE FOUR NUMBERS DEPEND ON THE LENGTH OF ./VERSION, and that is deliberate. CLAUDE_PLUGIN_ROOT
# is unset here, so the hook falls back to this repository and prints its real version, six
# characters today. A bump to a seven character version moves all four by one and fails this block,
# which is correct: it genuinely spends one of the six characters NFR-01 has left, and the point of
# asserting exact sizes rather than an upper bound is that spending them is a deliberate act with a
# re-measurement. Update the numbers, do not pin the version.
for spec in "b:1279:terse and technical" "g:1278:terse and plain" \
            "c:1077:verbose and technical" "h:1268:verbose and plain"; do
    dir="${spec%%:*}"; rest="${spec#*:}"; want="${rest%%:*}"; label="${rest#*:}"
    got="$(size_of "$tmp/$dir")"
    if [ "$got" = "$want" ]; then
        ok "$label injects exactly $want characters"
    else
        # Self-explaining on purpose. The likeliest cause of this failing is a VERSION whose length
        # changed, which is a legitimate release and not a defect, and somebody meeting four red
        # constants with no explanation deletes the tripwire rather than reading it.
        bad "size" "$label injects $got characters, expected $want, a difference of $(( got - want )).
        These four numbers are deliberately coupled to the length of ./VERSION, which this hook
        prints. A release that changes the version's length by one moves all four by one, and that
        is not a defect: it spends the headroom NFR-01 has left, which was 6 characters at 1279
        against the 1285 ceiling. Re-measure all four, update these constants and the four-form
        table under 'The rule is on by default and it is not free' in
        docs/05-token-and-memory-design.md, which NFR-05 requires to agree with them. Do not pin the
        version to keep this green: the coupling is what makes spending those characters deliberate."
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
