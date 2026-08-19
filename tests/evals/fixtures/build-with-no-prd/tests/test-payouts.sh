#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/payouts.sh

pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1)); fi
}

check "a payout resolves its merchant"     mer_1 "$(payout_field po_1001 2)"
check "failed payouts can be listed"       3     "$(payouts_by_status failed | wc -l | tr -d ' ')"
check "payouts filter by merchant"         4     "$(payouts_by_merchant mer_1 | wc -l | tr -d ' ')"
check "paid GBP volume covers two days"    2     "$(daily_volume GBP | wc -l | tr -d ' ')"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
