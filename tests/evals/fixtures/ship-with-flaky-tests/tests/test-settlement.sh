#!/usr/bin/env bash
# Settlement totals.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/settlement.sh

pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1))
    fi
}

check "a single transaction settles"        "10000 250 9750"   "$(settle mer_1 10000)"
check "several transactions sum first"      "30000 750 29250"  "$(settle mer_1 10000 15000 5000)"
check "a zero total settles to zero"        "0 0 0"            "$(settle mer_1 0)"
fee_rate_reset
check "a promotional merchant pays 50 bps"  "10000 50 9950"    "$(settle mer_promo 10000)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
