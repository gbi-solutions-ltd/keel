#!/usr/bin/env bash
# Resolve which gates are active on a harness, from lib/harness/capabilities.
#
# Pure bash on purpose. hooks/sensitive-guard sources this to decide whether it can do its job, and
# a gate that needs python3 to know whether it is a gate has the dependency in the wrong place.
#
# ADR-0003: a provides row grants its primitive only when source, version and date are all present.
# Absent evidence fails, never passes. Three ways a row can be absent evidence while looking
# populated, all of which resolved a gate ACTIVE in the first version of this file:
#   - a field holding only spaces is blank, not empty, and [ -n ] accepts it
#   - a row with more than six fields is malformed, and the sixth read variable swallows the rest
#   - a final row with no trailing newline is never seen at all, because read returns non-zero
# The last is the dangerous one: dropping a trailing `provides` row fails closed and gets noticed,
# dropping a trailing `requires` row fails OPEN and does not. `|| [ -n "$f1" ]` is what sees it.
# tests/test-harness-resolve.sh holds one fixture per case and a mutation test per check.

# A field is present only if it holds a non-space character. Same rule as provenance_gaps in
# tests/test-harness-resolve.sh, deliberately: the validator and the resolver disagreeing about
# what "absent evidence" means is how a row passes one and is granted by the other.
_harness_present() {
    [ -n "${1//[[:space:]]/}" ]
}

harness_capabilities_path() {
    # Set but empty is an error, not a fallback. A caller whose override path came out empty (an
    # unset lookup, a failed mktemp) must not silently resolve against the developer's own manifest
    # and be told every gate is active.
    if [ -n "${KEEL_CAPABILITIES+x}" ]; then
        [ -n "$KEEL_CAPABILITIES" ] || return 1
        printf '%s' "$KEEL_CAPABILITIES"; return 0
    fi
    printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/capabilities"
}

harness_provides() {
    [ $# -eq 2 ] || return 1
    local harness="$1" primitive="$2" cap f1 f2 f3 f4 f5 f6 f7
    cap="$(harness_capabilities_path)" || return 1
    [ -r "$cap" ] || return 1
    while IFS='|' read -r f1 f2 f3 f4 f5 f6 f7 || [ -n "$f1" ]; do
        [ "$f1" = "provides" ] || continue
        [ "$f2" = "$harness" ] || continue
        [ "$f3" = "$primitive" ] || continue
        [ -z "$f7" ] || continue
        _harness_present "$f4" || continue
        _harness_present "$f5" || continue
        _harness_present "$f6" || continue
        return 0
    done < "$cap"
    return 1
}

harness_known() {
    [ $# -eq 1 ] || return 1
    local harness="$1" cap f1 f2 rest
    cap="$(harness_capabilities_path)" || return 1
    [ -r "$cap" ] || return 1
    while IFS='|' read -r f1 f2 rest || [ -n "$f1" ]; do
        [ "$f1" = "provides" ] && [ "$f2" = "$harness" ] && return 0
    done < "$cap"
    return 1
}

harness_gate_active() {
    [ $# -eq 2 ] || return 1
    local harness="$1" gate="$2" cap f1 f2 f3 found=1
    cap="$(harness_capabilities_path)" || return 1
    [ -r "$cap" ] || return 1
    while IFS='|' read -r f1 f2 f3 || [ -n "$f1" ]; do
        [ "$f1" = "requires" ] || continue
        [ "$f2" = "$gate" ] || continue
        found=0
        harness_provides "$harness" "$f3" || return 1
    done < "$cap"
    return "$found"
}

harness_active_gates() {
    [ $# -eq 1 ] || return 1
    local harness="$1" cap f1 f2 rest seen=""
    harness_known "$harness" || return 1
    cap="$(harness_capabilities_path)" || return 1
    while IFS='|' read -r f1 f2 rest || [ -n "$f1" ]; do
        [ "$f1" = "requires" ] || continue
        case " $seen " in *" ${f2} "*) continue ;; esac
        seen="$seen $f2"
        harness_gate_active "$harness" "$f2" && printf '%s\n' "$f2"
    done < "$cap"
    return 0
}
