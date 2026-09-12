#!/usr/bin/env bash
# Tests for lib/harness/capabilities and lib/harness/resolve.sh.
#
# shellcheck disable=SC2015  # `a && ok || bad` is this suite's idiom; ok never fails, so the
# warning's scenario cannot arise. `tests/test-keel.sh#shellcheck disable=SC2015` and
# `test-context-watch.sh#shellcheck disable=SC2015` disable it for the same reason, and
# `.keel/profile.json#shellcheck at default severity` means an info finding is a red build.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

CAP="$ROOT/lib/harness/capabilities"

[ -f "$CAP" ] && ok "capabilities file exists" \
  || bad "capabilities file exists" "not found at lib/harness/capabilities"

grep -q '^provides|claude|pretooluse_ask|' "$CAP" 2>/dev/null \
  && ok "claude provides pretooluse_ask" \
  || bad "claude provides pretooluse_ask" "row absent"

grep -q '^provides|codex|pretooluse_ask|' "$CAP" 2>/dev/null \
  && bad "codex does not provide pretooluse_ask" "row present and must not be" \
  || ok "codex does not provide pretooluse_ask"

# Every requires row names a gate that exists as a file under hooks/. Both directions, because a
# requires row for a gate nobody ships is as wrong as a gate with no requires row.
while IFS='|' read -r k g _; do
    [ "$k" = requires ] || continue
    [ -f "$ROOT/hooks/$g" ] && ok "requires row $g has a hook file" \
      || bad "requires row $g has a hook file" "hooks/$g does not exist"
done < "$CAP"

# ADR-0003: absent evidence fails, never passes. A field holding only spaces is absent evidence
# that would pass a test for emptiness, so match blank rather than empty, and check the field count
# too: a seven-field row would otherwise sail through.
provenance_gaps() {   # provenance_gaps <file>
    awk -F'|' '$1=="provides" && (NF!=6 || $4 ~ /^[[:space:]]*$/ || $5 ~ /^[[:space:]]*$/ || $6 ~ /^[[:space:]]*$/) {print $2"/"$3}' "$1"
}
thin="$(provenance_gaps "$CAP")"
[ -z "$thin" ] && ok "every provides row carries source, version and date" \
  || bad "every provides row carries source, version and date" "$thin"

# A validator with no test proving it fires is worse than none: docs/standards.md, and ADR-0003's
# own verification section says a check that has never fired is a check nobody has tested. Run the
# predicate against a fixture built to break it, in every way the predicate claims to catch.
#
# One row per column and per blankness kind, because a row caught on two columns at once pins
# neither: weaken one of them and the other still prints the row, and the suite stays green.
# Row c holds a space in $4 and rows e, f and g hold a tab in $4, $5 and $6, so every column carries
# a blank that is not empty and at least one that /^ *$/ cannot match. Without them three mutations
# survive: deleting the $5 disjunct outright, weakening $6 to $6 == "", and weakening $4, $5 or $6
# to /^ *$/. ADR-0003 says absent evidence never passes, and a tab in a manifest column is invisible
# in a diff, so the tab cases are the ones that carry the claim.
fx="$(mktemp)"
printf 'provides|ghost|a|src|1|2026-01-01\nprovides|ghost|b|src|1|\nprovides|ghost|c| |1|2026-01-01\nprovides|ghost|d|src|1|2026-01-01|extra\nprovides|ghost|e|\t|1|2026-01-01\nprovides|ghost|f|src|\t|2026-01-01\nprovides|ghost|g|src|1|\t\n' > "$fx"
got="$(provenance_gaps "$fx" | sort | tr '\n' ' ')"
[ "$got" = "ghost/b ghost/c ghost/d ghost/e ghost/f ghost/g " ] \
  && ok "the provenance check fires on empty, blank and wrong-arity rows" \
  || bad "the provenance check fires on empty, blank and wrong-arity rows" "got: $got"
rm -f "$fx"

# Every source says which kind of evidence it is. A keel file is neither kind.
unkinded="$(awk -F'|' '$1=="provides" && $4 !~ /^(vendor|probe):/ {print $2"/"$3}' "$CAP")"
[ -z "$unkinded" ] && ok "every source is marked vendor: or probe:" \
  || bad "every source is marked vendor: or probe:" "$unkinded"

# A one-character typo in a requires row would disable a gate on every harness, including the one
# where it works. Fail closed is right; a typo indistinguishable from a deliberate absence is not.
# Keyed on gate AND primitive. Keyed on the gate alone, a second requires row overwrites the first
# and only the last is ever checked, which is precisely the shape done-guard now has.
orphan="$(awk -F'|' '$1=="provides"{p[$3]=1} $1=="requires"{r[$2 SUBSEP $3]=1} END{for(k in r){split(k,a,SUBSEP); if(!(a[2] in p)) print a[1]"->"a[2]}}' "$CAP")"
[ -z "$orphan" ] && ok "every required primitive is provided by some harness" \
  || bad "every required primitive is provided by some harness" "$orphan"

# The gate list comes from the tree, not from this file. A fifth gate added under hooks/ with no
# requires row would otherwise pass unnoticed, and resolve.sh would report it active everywhere.
for h in "$ROOT"/hooks/*; do
    [ -f "$h" ] || continue
    g="$(basename "$h")"
    case "$g" in hooks.json|*.json) continue ;; esac
    grep -q "^requires|$g|" "$CAP" 2>/dev/null \
      && ok "gate $g has a requires row" || bad "gate $g has a requires row" "no requires row"
done

# Every line is a comment, a blank, or a well-formed record of the right arity. Without this, an
# indented or misspelled requires row is invisible to resolve.sh AND to every other check in this
# file, because all of them key on $1=="requires" or $1=="provides". One leading space turns a
# requirement into a no-op and its gate resolves ACTIVE on a harness that does not meet it: adding
# a single space to the done-guard row makes done-guard active on Codex, which provides neither
# transcript schema row. That is this design's dominant failure reachable by one keystroke, and the
# direction is the dangerous one, because a malformed provides row fails closed and gets noticed
# while a malformed requires row fails open and does not. Leading whitespace is never legal here,
# comments included, which is why an indented comment and a whitespace-only line are both flagged.
# Arity is checked here too: resolve.sh reads seven fields to detect a seventh, but a trailing pipe
# leaves that seventh empty and indistinguishable from a well-formed row, so it is caught here.
# The harness and primitive columns must be non-blank as well, in both record kinds. Nothing else
# looks at them: provenance_gaps inspects only $4 to $6, and the orphan check is satisfied whenever
# the same blank value appears on both sides. A blank primitive on a provides row and a blank
# primitive on a requires row therefore matched each other and granted the gate on no evidence.
malformed_rows() {   # malformed_rows <file>
    awk -F'|' '
        /^$/ { next }
        /^#/ { next }
        $2 ~ /^[[:space:]]*$/ || $3 ~ /^[[:space:]]*$/ { print NR; next }
        $1=="provides" && NF==6 { next }
        $1=="requires" && NF==3 { next }
        { print NR }
    ' "$1"
}
bad_rows="$(malformed_rows "$CAP" | tr '\n' ' ')"
[ -z "$bad_rows" ] && ok "every line is a comment, a blank, or a well-formed record" \
  || bad "every line is a comment, a blank, or a well-formed record" "lines: $bad_rows"

# A validator with no test proving it fires is worse than none. Seventeen malformed lines, 5 to 21,
# and four legal ones: a comment, a blank, and one record of each kind.
#
# Lines 14 to 18 and line 20 are the blank-but-not-empty cases and they are the point
# rather than padding. ADR-0003's whole claim is that blank is not empty, so a fixture holding only
# empty fields lets `$2 ~ /^[[:space:]]*$/` be weakened to `$2 == ""` with the suite still green,
# and a space in a manifest column is invisible in a diff. Lines 18 and 20 use tabs so `/^ *$/` is
# not enough either, and between them they cover both columns: 18 the harness, 20 the primitive.
# One per column is the whole of it. A second tab row in the same column pins nothing extra, because
# the blank rule runs before any `$1` test and so cannot tell the record kinds apart.
#
# New cases are appended rather than inserted. The assertion pins an exact list of line numbers, so
# inserting one renumbers every case after it and the diff stops showing which case was added.
fx2="$(mktemp)"
printf '# c\n\nprovides|a|b|src|1|2026-01-01\nrequires|g|b\n  # indented comment\n requires|g|b\nrequire|g|b\nprovides|a|c|src|1|2026-01-01|\nprovides|a|d|src|1\n   \nprovides|a||src|1|2026-01-01\nprovides||b|src|1|2026-01-01\nrequires|g|\nprovides|a| |src|1|2026-01-01\nprovides| |b|src|1|2026-01-01\nrequires|g| \nrequires| |b\nprovides|\t|b|src|1|2026-01-01\nrequires|g|b|extra\nprovides|a|\t|src|1|2026-01-01\nrequires|g|b|src|1|2026-01-01\n' > "$fx2"
got="$(malformed_rows "$fx2" | tr '\n' ' ')"
[ "$got" = "5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 " ] \
  && ok "the well-formedness check fires on every malformed shape and no legal one" \
  || bad "the well-formedness check fires on every malformed shape and no legal one" "got: $got"

# The pinned line list catches an insertion or a deletion, because either renumbers every case after
# it. It does not catch degradation in place. Turn line 18's tab into a space and the suite stays
# green while the $2 tab mutation silently stops being caught, and the comment above goes on
# claiming line 18 uses a tab. One invisible character deletes real coverage, so assert the fixture
# still holds what the prose says it holds.
tabbed="$(awk -F'|' 'NR==18 && $2=="\t"{n++} NR==20 && $3=="\t"{n++} END{print n+0}' "$fx2")"
[ "$tabbed" = 2 ] \
  && ok "the fixture's tab columns are still tabs, on line 18 and line 20" \
  || bad "the fixture's tab columns are still tabs, on line 18 and line 20" "found $tabbed of 2"
rm -f "$fx2"


# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/harness/resolve.sh
. "$ROOT/lib/harness/resolve.sh" 2>/dev/null || true

if command -v harness_active_gates >/dev/null 2>&1; then
    got="$(harness_active_gates claude | sort | tr '\n' ' ')"
    [ "$got" = "context-watch done-guard sensitive-guard session-start " ] \
      && ok "claude resolves four gates" || bad "claude resolves four gates" "got: $got"

    # Three gates, and this is where a human sees Tier B change size. It was session-start alone
    # until 2026-09-06: task 1's manifest had split the transcript primitives along Claude Code's
    # own schema, so no evidence could ever have earned the other two. Task 2A renamed them and
    # task 14 earned them, with parsers that read a captured rollout and probe rows citing it.
    # sensitive-guard stays inactive, because pretooluse_ask is genuinely absent rather than
    # unnameable. ADR-0003: absent evidence fails, never passes.
    got="$(harness_active_gates codex | sort | tr '\n' ' ')"
    [ "$got" = "context-watch done-guard session-start " ] \
      && ok "codex resolves three gates" \
      || bad "codex resolves three gates" "got: $got"

    harness_gate_active codex sensitive-guard \
      && bad "sensitive-guard inactive on codex" "reported active" \
      || ok "sensitive-guard inactive on codex"

    harness_active_gates cursor >/dev/null 2>&1 \
      && bad "an unknown harness is refused" "exit status was zero" \
      || ok "an unknown harness is refused"

    # A known harness must resolve with status 0. Command substitution and a pipeline each discard
    # the status, so every assertion above this one passes against a harness_active_gates that
    # always returns 1. That mutation was run against an earlier version of this suite and every
    # assertion still passed, which is why this one exists.
    if harness_active_gates claude >/dev/null; then
        ok "a known harness resolves with status zero"
    else
        bad "a known harness resolves with status zero" "non-zero status"
    fi

    # Set but empty is an error, not a fallback. A caller whose override path came out empty would
    # otherwise resolve against the developer's own manifest and be told every gate is active.
    # Assert the path function's own status. Going through harness_gate_active proves nothing:
    # with the guard deleted the path is still the empty string, [ -r "" ] still fails, and the
    # gate is still refused, so that assertion stays green against the very code it claims to pin.
    KEEL_CAPABILITIES="" harness_capabilities_path >/dev/null \
      && bad "an empty KEEL_CAPABILITIES is refused" "returned zero" \
      || ok "an empty KEEL_CAPABILITIES is refused"

    # One fixture per way a provides row can be absent evidence while looking populated. Each of
    # these granted its primitive in the first version of resolve.sh, and none is visible in a diff.
    # The positive control is first on purpose: without it every negative below also passes against
    # a resolver that refuses everything.
    gate_on() {   # gate_on <printf-escaped manifest>; echoes active or inactive
        local f rc
        f="$(mktemp)"
        printf '%b' "$1" > "$f"
        KEEL_CAPABILITIES="$f" harness_gate_active ghost done-guard; rc=$?
        rm -f "$f"
        [ "$rc" -eq 0 ] && printf 'active' || printf 'inactive'
    }

    [ "$(gate_on 'provides|ghost|p|src|1|2026-01-01\nrequires|done-guard|p\n')" = "active" ] \
      && ok "a complete row grants its primitive" \
      || bad "a complete row grants its primitive" "the negative cases below would prove nothing"

    [ "$(gate_on 'provides|ghost|p|src|1|\nrequires|done-guard|p\n')" = "inactive" ] \
      && ok "an empty date grants nothing" || bad "an empty date grants nothing" "reported active"

    [ "$(gate_on 'provides|ghost|p|src|1| \nrequires|done-guard|p\n')" = "inactive" ] \
      && ok "a blank date grants nothing" || bad "a blank date grants nothing" "reported active"

    [ "$(gate_on 'provides|ghost|p| |1|2026-01-01\nrequires|done-guard|p\n')" = "inactive" ] \
      && ok "a blank source grants nothing" || bad "a blank source grants nothing" "reported active"

    [ "$(gate_on 'provides|ghost|p|src|1|2026-01-01|extra\nrequires|done-guard|p\n')" = "inactive" ] \
      && ok "a seven-field row grants nothing" \
      || bad "a seven-field row grants nothing" "reported active"

    # No trailing newline, and the asymmetry that makes it dangerous: a dropped trailing provides
    # row fails closed and gets noticed, a dropped trailing requires row fails open and does not.
    # This fixture drops a requires row naming a primitive nobody provides, so a resolver that
    # cannot see it reports the gate ACTIVE with an unmet requirement.
    [ "$(gate_on 'provides|ghost|p|src|1|2026-01-01\nrequires|done-guard|p\nrequires|done-guard|absent')" = "inactive" ] \
      && ok "a final row with no trailing newline is still read" \
      || bad "a final row with no trailing newline is still read" "reported active"

    # A gate with no requires row at all must be inactive. `found=1` is the only thing making that
    # true, and flipping it to 0 resolves every unknown gate ACTIVE on every harness, which is
    # the failure the hooks-directory loop above warns about. Nothing pinned it until now.
    harness_gate_active claude no-such-gate \
      && bad "a gate with no requires row is inactive" "reported active" \
      || ok "a gate with no requires row is inactive"

    [ "$(gate_on 'provides|ghost|p|src| |2026-01-01\nrequires|done-guard|p\n')" = "inactive" ] \
      && ok "a blank version grants nothing" || bad "a blank version grants nothing" "reported active"

    # A tab, not a space. Every fixture above uses a space, which lets `${1//[[:space:]]/}` in
    # _harness_present be weakened to `${1// /}` with the suite green. resolve.sh states that the
    # resolver and the validator must agree on what absent evidence means, and the validator learned
    # about tabs first, so without this the two drift apart in the direction that grants.
    [ "$(gate_on 'provides|ghost|p|src|\t|2026-01-01\nrequires|done-guard|p\n')" = "inactive" ] \
      && ok "a tab-only version grants nothing" || bad "a tab-only version grants nothing" "reported active"

    # The no-trailing-newline guard is on four separate loops and the gate_on fixture above pins
    # only harness_gate_active's. These two reach the other three: A ends on an unterminated
    # provides row, which only harness_provides and harness_known read, and B ends on an
    # unterminated requires row, which reaches harness_active_gates' own loop. B also crosses
    # harness_gate_active's loop, so it is A that isolates the two provides-side guards.
    nl_case() {   # nl_case <printf-escaped manifest>; echoes the resolved gate list
        local f
        f="$(mktemp)"
        printf '%b' "$1" > "$f"
        KEEL_CAPABILITIES="$f" harness_active_gates ghost | tr '\n' ' '
        rm -f "$f"
    }

    [ "$(nl_case 'requires|session-start|p\nprovides|ghost|p|src|1|2026-01-01')" = "session-start " ] \
      && ok "a final provides row with no trailing newline is still read" \
      || bad "a final provides row with no trailing newline is still read" "got: $(nl_case 'requires|session-start|p\nprovides|ghost|p|src|1|2026-01-01')"

    [ "$(nl_case 'provides|ghost|p|src|1|2026-01-01\nrequires|session-start|p')" = "session-start " ] \
      && ok "a final requires row with no trailing newline is still read" \
      || bad "a final requires row with no trailing newline is still read" "got: $(nl_case 'provides|ghost|p|src|1|2026-01-01\nrequires|session-start|p')"

    # The record-kind guards. There are four, not three: `[ "$f1" = "provides" ]` appears in both
    # harness_provides and harness_known, and `[ "$f1" = "requires" ]` in harness_gate_active and
    # harness_active_gates. They are what make keying on the first field mean anything, and all four
    # survived deletion with this suite green. Without the provides guard, any line whose pipe
    # fields happen to align grants a primitive, and this manifest's own format comment is exactly
    # such a line: it reads as harness <harness> providing <primitive>. Without the requires guard
    # in harness_gate_active, a comment doubles as a requirement. Without it in
    # harness_active_gates, a provides row is offered as a candidate gate, which changes the ORDER
    # gates come out in rather than the set of them. The assertion that pins that one says so where
    # it sits, because a comment here that counted its position would go stale the moment anything
    # was inserted between the two, which is exactly how this sentence was wrong before.
    # Line 1 is a six-field comment, so dropping the provides guard reads it as harness <harness>
    # providing <primitive>. Line 2 is a THREE-field comment, and it has to be three: with only
    # `read -r f1 f2 f3`, a six-field provides row puts `p|src|1|2026-01-01` in f3, the primitive
    # lookup fails, and the gate is refused whether the requires guard is there or not. Only a
    # three-field line reaches the fail-open. Note what that means in the real manifest:
    # prose in a comment that happens to mention a requires row would grant that gate, and comments
    # are exempt from malformed_rows, so nothing else would see it.
    kind="$(mktemp)"
    printf '%b' '# provides|<harness>|<primitive>|<source>|<version>|<date>\n# see requires|newgate|p\nprovides|aaa|p|src|1|2026-01-01\nrequires|bbb|p\n' > "$kind"

    KEEL_CAPABILITIES="$kind" harness_provides '<harness>' '<primitive>' \
      && bad "a comment is not a provides row" "granted a primitive from the format comment" \
      || ok "a comment is not a provides row"

    KEEL_CAPABILITIES="$kind" harness_gate_active aaa newgate \
      && bad "a comment is not a requires row" "resolved a gate named only inside a comment" \
      || ok "a comment is not a requires row"

    # The fourth guard, in harness_known, which the other three fixtures do not reach. Without it
    # any string in the second field of any row is a known harness, including <harness> from the
    # format comment. Task 3 gates the CLI on harness_known, so this is what stops
    # `keel harness done-guard` being accepted and then resolving to an empty gate list with status
    # zero, which reads as "this harness has no gates" rather than "there is no such harness".
    KEEL_CAPABILITIES="$kind" harness_active_gates '<harness>' >/dev/null 2>&1 \
      && bad "a comment does not make a harness known" "accepted a harness named only in a comment" \
      || ok "a comment does not make a harness known"
    rm -f "$kind"

    # Here gate aaa IS required, and later in the file than bbb. Drop the requires guard in
    # harness_active_gates and the provides row offers aaa as a candidate first, so aaa comes out
    # ahead of bbb. Only the ORDER changes, the set is the same, which is why this assertion does
    # not sort where every other one here does. That is also what distinguishes this guard from its
    # counterpart in harness_gate_active above: dropping that one suppresses aaa entirely.
    kind2="$(mktemp)"
    printf '%b' 'provides|aaa|p|src|1|2026-01-01\nrequires|bbb|p\nrequires|aaa|p\n' > "$kind2"
    kind_out="$(KEEL_CAPABILITIES="$kind2" harness_active_gates aaa | tr '\n' ' ')"
    [ "$kind_out" = "bbb aaa " ] \
      && ok "gates come from requires rows, in manifest order" \
      || bad "gates come from requires rows, in manifest order" "got: $kind_out"
    rm -f "$kind2"

    # The gate path must not need python3. Assert that against a PATH built to lack one: /usr/bin
    # carries /usr/bin/python3, so the obvious version of this test would prove nothing.
    stub="$(mktemp -d)"
    ln -s "$(command -v dirname)" "$stub/dirname"
    # `command -v` consults bash's hash table before PATH, so a python3 invoked earlier in this
    # shell would be found here and fail this control spuriously. Forget it and test PATH alone.
    hash -r
    PATH="$stub" command -v python3 >/dev/null 2>&1 \
      && bad "the stub PATH has no python3" "found one, so the next assertion proves nothing" \
      || ok "the stub PATH has no python3"
    # Resolve claude here, not codex. Nothing about this assertion is related to Codex, and pinning
    # it to Codex's gate list means task 14, which adds Codex probe rows, turns it red for a reason
    # that reads as unrelated to the change. Claude's list is the R-01 no-regression set and does
    # not move when a second harness gains a primitive.
    out="$(PATH="$stub" /bin/bash -c ". '$ROOT/lib/harness/resolve.sh'; harness_active_gates claude" 2>&1 | sort | tr '\n' ' ')"
    [ "$out" = "context-watch done-guard sensitive-guard session-start " ] \
      && ok "resolves with no python3 on PATH" \
      || bad "resolves with no python3 on PATH" "got: $out"
    rm -rf "$stub"
else
    bad "resolve.sh defines harness_active_gates" "function not found after sourcing"
fi

# A primitive names a capability, never one harness's wire format. A name carrying a schema word
# cannot be satisfied by a second harness however much evidence that harness has, so it does not
# fail closed, it fails permanently. Tier B lost two gates by construction this way on 2026-09-05
# before the rename, which is the scar this assertion exists to keep.
schemaish="$(awk -F'|' '($1=="provides"||$1=="requires") && $3 ~ /jsonl|_json|message|content/ {print $3}' "$CAP" | sort -u | tr '\n' ' ')"
[ -z "$schemaish" ] && ok "no primitive name encodes a harness wire format" \
  || bad "no primitive name encodes a harness wire format" "$schemaish"

# Two repeat assertions, made earlier in this file on purpose: they are the regression guard, and a
# rename that changes either of them is a rename that dropped a requires row. Task 2A's rename moved
# neither, which was the point of it. What moved codex from one gate to three afterwards was task
# 14's evidence, not a rename, and that is the distinction these two keep visible: the claude line
# has never moved at all, and the codex line moves only when a probe row is added or removed.
[ "$(harness_active_gates claude | sort | tr '\n' ' ')" = "context-watch done-guard sensitive-guard session-start " ] \
  && ok "the rename left claude at four gates" \
  || bad "the rename left claude at four gates" "$(harness_active_gates claude | sort | tr '\n' ' ')"
[ "$(harness_active_gates codex | sort | tr '\n' ' ')" = "context-watch done-guard session-start " ] \
  && ok "the rename left codex holding every primitive it has evidence for" \
  || bad "the rename left codex holding every primitive it has evidence for" "$(harness_active_gates codex | sort | tr '\n' ' ')"

# ---- the generated per-harness hook manifests -------------------------------
#
# Four things have to agree about which gates a harness gets: this manifest, hooks/hooks.json,
# hooks/hooks.codex.json and the support page. A hand-maintained copy is the one that goes stale,
# so the hook manifests are generated and a stale file is a failing build. Same bargain
# tests/generate-profile-keys.sh makes for docs/profile-keys.md.

GEN="$ROOT/tests/generate-harness-artifacts.sh"

if [ -x "$GEN" ]; then
    # R-01: the Claude Code manifest must come out of the generator byte for byte as committed.
    # This case is the specification for the emitters. A generator that produces valid JSON which
    # is not this file changes what Claude Code installs, which is the one thing this work may not
    # do, and a diff is the only check that sees it.
    if diff -q <("$GEN" claude) "$ROOT/hooks/hooks.json" >/dev/null 2>&1; then
        ok "generated claude manifest is byte-identical to hooks/hooks.json"
    else
        bad "generated claude manifest is byte-identical to hooks/hooks.json" \
          "$( "$GEN" claude | diff - "$ROOT/hooks/hooks.json" | head -5 | tr '\n' ' ' )"
    fi

    diff -q <("$GEN" codex) "$ROOT/hooks/hooks.codex.json" >/dev/null 2>&1 \
      && ok "hooks/hooks.codex.json is not stale" \
      || bad "hooks/hooks.codex.json is not stale" "regenerate it"

    grep -q 'sensitive-guard' "$ROOT/hooks/hooks.codex.json" 2>/dev/null \
      && bad "codex manifest omits sensitive-guard" "an entry is present" \
      || ok "codex manifest omits sensitive-guard"

    for g in session-start done-guard context-watch; do
        grep -q "$g" "$ROOT/hooks/hooks.codex.json" 2>/dev/null \
          && ok "codex manifest registers $g" \
          || bad "codex manifest registers $g" "no entry"
    done

    # The exit-2 control path and the Stop decision path both need a synchronous hook.
    # codex-rs/hooks/src/engine/mod.rs:141-156. A silent flip here makes every gate advisory.
    for f in "$ROOT/hooks/hooks.json" "$ROOT/hooks/hooks.codex.json"; do
        n_hooks="$(grep -c '"type": "command"' "$f")"
        n_sync="$(grep -c '"async": false' "$f")"
        [ "$n_hooks" = "$n_sync" ] \
          && ok "$(basename "$f") pins async false on all $n_hooks entries" \
          || bad "$(basename "$f") pins async false on all entries" "$n_hooks commands, $n_sync synchronous"
    done

    # The generator reads the manifest, so a gate the manifest withholds must not reach the file.
    # Without this the emitters could ignore is_active entirely and every case above still passes,
    # because Codex happens to hold every gate but one today.
    withheld="$(KEEL_CAPABILITIES="$ROOT/lib/harness/capabilities" "$GEN" codex | grep -c 'done-guard' || true)"
    [ "$withheld" -gt 0 ] || bad "the codex manifest carries done-guard" "absent"
    cut_cap="$(mktemp)"
    grep -v '^provides|codex|transcript_turn_tool_calls|' "$ROOT/lib/harness/capabilities" > "$cut_cap"
    n="$(KEEL_CAPABILITIES="$cut_cap" "$GEN" codex | grep -c 'done-guard' || true)"
    [ "$n" = 0 ] \
      && ok "a gate the manifest withholds is not registered" \
      || bad "a gate the manifest withholds is not registered" "done-guard still emitted $n time(s)"

    # ...and the file it produces then is still a well-formed document, not one with a dangling
    # comma or an empty event array. An emitter that drops a group has to drop its event too.
    KEEL_CAPABILITIES="$cut_cap" "$GEN" codex | python3 -c '
import json,sys
d=json.load(sys.stdin)
sys.exit(1) if any(not v for v in d["hooks"].values()) else sys.exit(0)' 2>/dev/null \
      && ok "dropping a gate leaves valid JSON with no empty event" \
      || bad "dropping a gate leaves valid JSON with no empty event" "malformed or an empty array"
    rm -f "$cut_cap"

    # The message, not only the exit code. set -e plus harness_active_gates already makes an unknown
    # harness exit non-zero on its own, so a check on the status alone passes with the explicit
    # guard deleted and the operator gets silence instead of a name they can act on.
    err="$("$GEN" nosuchharness 2>&1 >/dev/null)"; rc=$?
    [ "$rc" != 0 ] && printf '%s' "$err" | grep -q 'unknown harness: nosuchharness' \
      && ok "an unknown harness is refused, by name" \
      || bad "an unknown harness is refused, by name" "rc=$rc err=${err:-<empty>}"
else
    bad "tests/generate-harness-artifacts.sh is executable" "not found or not executable"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
