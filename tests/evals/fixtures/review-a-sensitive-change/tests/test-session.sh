#!/usr/bin/env bash
# Session expiry.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/auth/session.sh

pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1))
    fi
}

state() { if session_expired "$1"; then printf 'expired\n'; else printf 'live\n'; fi; }

check "a new session is live"                       live    "$(state 0)"
check "a session one second short of 30 minutes"    live    "$(state 1799)"
check "a session at exactly 30 minutes is expired"  expired "$(state 1800)"
check "a session past 30 minutes is expired"        expired "$(state 7200)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
