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
# A glob match rather than deleting the spaces and testing what is left: the same rule, and the
# substitution cost about a millisecond a field under bash 3.2, which is most of what doctor spent in
# this file, measured 2026-10-25.
_harness_present() {
    case "$1" in *[![:space:]]*) return 0 ;; esac
    return 1
}

# Resolved once, when this file is sourced. Every resolver call reads the manifest path, and working
# it out per call cost a subshell and a dirname each time: half of what one `keel doctor` spent here,
# measured 2026-10-25. Through symlinks the way bin/keel resolves itself, because the manifest sits
# beside the file a link names and not beside the link, and with CDPATH emptied for the cd, because
# one that finds its directory through CDPATH prints it and the capture would hold two lines.
_harness_src="${BASH_SOURCE[0]}"
while [ -L "$_harness_src" ]; do
    _harness_link="$(readlink "$_harness_src")"
    case "$_harness_link" in
        /*) _harness_src="$_harness_link" ;;
        *)  _harness_src="$(dirname "$_harness_src")/$_harness_link" ;;
    esac
done
_HARNESS_DIR="$(CDPATH='' cd "$(dirname "$_harness_src")" && pwd)"
unset _harness_src _harness_link

# _harness_cap: sets _HARNESS_CAP to the manifest path. The functions below use it rather than
# `$(harness_capabilities_path)`, because each command substitution is a fork, and a doctor run made
# about 35 of them.
_harness_cap() {
    # Set but empty is an error, not a fallback. A caller whose override path came out empty (an
    # unset lookup, a failed mktemp) must not silently resolve against the developer's own manifest
    # and be told every gate is active.
    if [ -n "${KEEL_CAPABILITIES+x}" ]; then
        [ -n "$KEEL_CAPABILITIES" ] || return 1
        _HARNESS_CAP="$KEEL_CAPABILITIES"; return 0
    fi
    _HARNESS_CAP="$_HARNESS_DIR/capabilities"
}

harness_capabilities_path() {
    _harness_cap || return 1
    printf '%s' "$_HARNESS_CAP"
}

harness_provides() {
    [ $# -eq 2 ] || return 1
    local harness="$1" primitive="$2" cap f1 f2 f3 f4 f5 f6 f7
    _harness_cap || return 1; cap="$_HARNESS_CAP"
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
    _harness_cap || return 1; cap="$_HARNESS_CAP"
    [ -r "$cap" ] || return 1
    while IFS='|' read -r f1 f2 rest || [ -n "$f1" ]; do
        [ "$f1" = "provides" ] && [ "$f2" = "$harness" ] && return 0
    done < "$cap"
    return 1
}

harness_gate_active() {
    [ $# -eq 2 ] || return 1
    local harness="$1" gate="$2" cap f1 f2 f3 found=1
    _harness_cap || return 1; cap="$_HARNESS_CAP"
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
    _harness_cap || return 1; cap="$_HARNESS_CAP"
    while IFS='|' read -r f1 f2 rest || [ -n "$f1" ]; do
        [ "$f1" = "requires" ] || continue
        case " $seen " in *" ${f2} "*) continue ;; esac
        seen="$seen $f2"
        harness_gate_active "$harness" "$f2" && printf '%s\n' "$f2"
    done < "$cap"
    return 0
}

# ---- keel's minimum Claude Code version ------------------------------------
#
# Derived here rather than written down anywhere: the highest version a gate's primitive was verified
# on. README carries the number and tests/test-harness-claims.sh compares the two, so a row that
# raises it is a red build until README says so. Pure bash like the rest of this file, and with no
# external command either, because keel doctor calls it on every run.

# harness_version_ge A B: 0 when version A is at or above B, comparing each dotted field as a
# number, so 2.1.302 is above 2.1.99 where a string comparison says the opposite. A field one
# version lacks counts as 0. 10# because a field with a leading zero is otherwise read as octal.
harness_version_ge() {
    [ $# -eq 2 ] || return 1
    local a="$1" b="$2" x y
    while [ -n "$a" ] || [ -n "$b" ]; do
        x="${a%%.*}"; y="${b%%.*}"
        case "$a" in *.*) a="${a#*.}" ;; *) a="" ;; esac
        case "$b" in *.*) b="${b#*.}" ;; *) b="" ;; esac
        [ "$((10#${x:-0}))" -gt "$((10#${y:-0}))" ] && return 0
        [ "$((10#${x:-0}))" -lt "$((10#${y:-0}))" ] && return 1
    done
    return 0
}

# _harness_gate_version GATE: sets _HARNESS_VERSION to the highest version among the evidenced
# provides|claude rows for the primitives GATE requires, or empty, returning 1. A variable rather
# than output, for the fork the comment on _harness_cap counts. Evidenced is harness_provides'
# test, field for field: a row with no version grants nothing, so it sets no minimum either.
_harness_gate_version() {
    local gate="$1" cap f1 f2 f3 f4 f5 f6 f7 needs=" "
    _HARNESS_VERSION=""
    _harness_cap || return 1; cap="$_HARNESS_CAP"
    [ -r "$cap" ] || return 1
    while IFS='|' read -r f1 f2 f3 || [ -n "$f1" ]; do
        [ "$f1" = "requires" ] && [ "$f2" = "$gate" ] && needs="$needs$f3 "
    done < "$cap"
    while IFS='|' read -r f1 f2 f3 f4 f5 f6 f7 || [ -n "$f1" ]; do
        [ "$f1" = "provides" ] || continue
        [ "$f2" = "claude" ] || continue
        case "$needs" in *" $f3 "*) ;; *) continue ;; esac
        [ -z "$f7" ] || continue
        _harness_present "$f4" || continue
        _harness_present "$f5" || continue
        _harness_present "$f6" || continue
        if [ -z "$_HARNESS_VERSION" ] || ! harness_version_ge "$_HARNESS_VERSION" "$f5"; then
            _HARNESS_VERSION="$f5"
        fi
    done < "$cap"
    [ -n "$_HARNESS_VERSION" ]
}

harness_gate_version() {
    [ $# -eq 1 ] || return 1
    _harness_gate_version "$1" || return 1
    printf '%s\n' "$_HARNESS_VERSION"
}

# harness_min_version: the highest harness_gate_version over every gate in a requires row, which
# is the oldest Claude Code on which every gate keel ships has its evidence.
harness_min_version() {
    local cap f1 f2 rest seen=" " best=""
    _harness_cap || return 1; cap="$_HARNESS_CAP"
    [ -r "$cap" ] || return 1
    while IFS='|' read -r f1 f2 rest || [ -n "$f1" ]; do
        [ "$f1" = "requires" ] || continue
        case "$seen" in *" $f2 "*) continue ;; esac
        seen="$seen$f2 "
        _harness_gate_version "$f2" || continue
        if [ -z "$best" ] || ! harness_version_ge "$best" "$_HARNESS_VERSION"; then
            best="$_HARNESS_VERSION"
        fi
    done < "$cap"
    [ -n "$best" ] || return 1
    printf '%s\n' "$best"
}
