#!/usr/bin/env bash
# The one list of paths this repository holds back from its public tree, and three functions that
# answer questions about it. Sourced by tests/validate-skills.sh and tests/validate-citations.sh,
# never run, so it is not executable. Every caller runs from the repository root.
#
# docs/audits is a clone of a private repository: ignored here (see .gitignore), absent on a
# contributor's machine, present on the owner's. A document in a withheld path is never one of the
# documents the public checks read, because its dated records go stale as this tree moves. A link
# or a citation INTO a withheld path is skipped only while that path is absent, and checked in full
# once it is present.
#
# Every name here starts with _wh_: shellcheck -x follows the source into both validators and does
# not scope a function's locals. The file holds no quiet grep pipeline. Written for bash 3.2.

_wh_paths=( docs/audits )

# withheld_list: each listed path, one per line.
withheld_list() {
    local _wh_p
    for _wh_p in "${_wh_paths[@]}"; do
        printf '%s\n' "$_wh_p"
    done
    return 0
}

# _wh_norm <path>: the path with "." and empty segments dropped and "seg/.." folded, in shell, so
# the path need not exist. A ".." with nothing to fold stays, which is how a path that climbs out
# of the repository keeps climbing. An absolute path keeps its leading slash.
_wh_norm() {
    local _wh_rest="$1/" _wh_seg _wh_out="" _wh_abs=""
    case "$1" in /*) _wh_abs="/" ;; esac
    while [ -n "$_wh_rest" ]; do
        _wh_seg="${_wh_rest%%/*}"
        _wh_rest="${_wh_rest#*/}"
        case "$_wh_seg" in
            "" | .) ;;
            ..)
                case "$_wh_out" in
                    "" | .. | */..) _wh_out="${_wh_out:+$_wh_out/}.." ;;
                    */*) _wh_out="${_wh_out%/*}" ;;
                    *) _wh_out="" ;;
                esac
                ;;
            *) _wh_out="${_wh_out:+$_wh_out/}$_wh_seg" ;;
        esac
    done
    printf '%s%s\n' "$_wh_abs" "$_wh_out"
}

# _wh_match <path>: prints the listed path that <path>, normalised, equals or lies under, and
# returns 0; prints nothing and returns 1 when there is none.
_wh_match() {
    local _wh_n _wh_p
    _wh_n="$(_wh_norm "$1")"
    for _wh_p in "${_wh_paths[@]}"; do
        case "$_wh_n" in
            "$_wh_p" | "$_wh_p"/*) printf '%s\n' "$_wh_p"; return 0 ;;
        esac
    done
    return 1
}

# withheld_under <path>: 0 when <path> is a listed path or lies under one, whether or not it
# exists; otherwise 1.
withheld_under() {
    _wh_match "$1" >/dev/null
}

# withheld_skip <path>: 0 when withheld_under does and that listed path does not exist relative to
# the current directory; otherwise 1.
withheld_skip() {
    local _wh_m
    _wh_m="$(_wh_match "$1")" || return 1
    [ ! -e "$_wh_m" ]
}
