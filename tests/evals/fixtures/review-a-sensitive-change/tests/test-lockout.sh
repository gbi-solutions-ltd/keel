#!/usr/bin/env bash
# Account lockout.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/auth/lockout.sh

pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1))
    fi
}

state() { if is_locked_out "$1"; then printf 'locked\n'; else printf 'open\n'; fi; }

check "an account with no failures is open"         open   "$(state 0)"
check "an account with one failure is open"         open   "$(state 1)"
check "an account with many failures is locked"     locked "$(state 9)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
