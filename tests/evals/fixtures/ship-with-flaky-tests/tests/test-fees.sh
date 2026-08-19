#!/usr/bin/env bash
# Fee rate resolution.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/fees.sh

pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1))
    fi
}

fee_rate_reset
check "the standard rate is 250 bps"          250 "$(fee_rate mer_1)"

fee_rate_reset
check "a promotional merchant gets 50 bps"    50  "$(fee_rate mer_promo)"

check "the rate is memoised within a run"     50  "$(fee_rate mer_promo)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
