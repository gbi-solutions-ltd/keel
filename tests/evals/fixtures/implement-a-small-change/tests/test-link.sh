#!/usr/bin/env bash
# Signed receipt link expiry.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/auth/link.sh

pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1))
    fi
}

state() { if link_expired "$1"; then printf 'expired\n'; else printf 'valid\n'; fi; }

check "a new link is valid"                         valid   "$(state 0)"
check "a link one second short of 15 minutes"       valid   "$(state 899)"
check "a link at exactly 15 minutes is expired"     expired "$(state 900)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
