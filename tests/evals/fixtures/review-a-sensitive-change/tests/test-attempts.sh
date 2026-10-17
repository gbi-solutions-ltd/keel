#!/usr/bin/env bash
# The attempts-left line.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/notify/attempts.sh

pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1))
    fi
}

check "no failures leaves three"            "3 attempts left"  "$(attempts_left_text 0)"
check "one failure leaves two"              "2 attempts left"  "$(attempts_left_text 1)"
check "two failures leaves one, singular"   "1 attempt left"   "$(attempts_left_text 2)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
