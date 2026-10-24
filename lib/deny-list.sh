#!/usr/bin/env bash
# The internal deny list, loaded the one way: for tests/no-internal-leaks.sh and for
# `keel scan --leaks` in bin/keel. Sourced and never run, so it is not executable.
#
# `deny_load` takes no arguments, returns 0, and sets four names:
#   DENY         the patterns: '/Users/[a-z]' '/home/[a-z]', then each pattern line of the file
#   DENY_WHERE   one entry per pattern: 'generic pattern 1', 'generic pattern 2', then
#                'deny list line <n>', <n> being the line's number in the file with comment and blank
#                lines counted, so the owner finds a pattern by opening the file at that line
#   DENY_FILE    ${KEEL_DENY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/keel/internal-deny-list.txt}
#   DENY_LOADED  how many patterns came from the file; 0 when it is absent
# Every name this file sets starts with DENY or deny_, because it is sourced into scripts that have
# names of their own.
#
# Generic patterns. These stay in the tree because they disclose nothing: a developer's absolute path
# helps nobody else and dates the moment they change laptop.
#
# Client and partner identifiers are loaded from a file outside the tree, because the list is itself
# the disclosure. It was the one file that enumerated who we work with, and it must contain the names
# in order to search for them, so the guard against disclosure had become the disclosure. Decision 2
# in docs/07-open-decisions.md required this before any public release, and 2026-08-17 is that release.
#
# One pattern per line, ERE, `#` comments and blank lines ignored. Absent is a legitimate state: a CI
# runner on a fork has no list, exactly as it has no marketplace registered. When it is absent the
# generic patterns still run, so a scan degrades rather than going quiet, and each caller prints which
# mode it ran in before any finding.
#
# What is not covered, and the format that would fix it. tests/test-no-leaks.sh proves the mechanism
# with invented names; it can no longer prove that every pattern in the real list still matches
# something, because it no longer has the real list. Giving the file a `pattern<TAB>sample` format
# would restore that check whenever it is present, and it is the better end state. It was not built
# because the mechanism came first.

# DENY_WHERE, DENY_FILE and DENY_LOADED are read by the scripts that source this file.
# shellcheck disable=SC2034
deny_load() {
    local deny_line deny_n=0
    DENY=( '/Users/[a-z]' '/home/[a-z]' )
    DENY_WHERE=( 'generic pattern 1' 'generic pattern 2' )
    DENY_FILE="${KEEL_DENY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/keel/internal-deny-list.txt}"
    DENY_LOADED=0
    if [ -f "$DENY_FILE" ]; then
        while IFS= read -r deny_line || [ -n "$deny_line" ]; do
            deny_n=$((deny_n+1))
            case "$deny_line" in ''|\#*) continue ;; esac
            DENY+=( "$deny_line" )
            DENY_WHERE+=( "deny list line $deny_n" )
            DENY_LOADED=$((DENY_LOADED+1))
        done < "$DENY_FILE"
    fi
    return 0
}
