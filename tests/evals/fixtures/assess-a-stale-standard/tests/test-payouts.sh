#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
. src/payouts.sh
fails=0
check() {
    if [ "$2" = "$3" ]; then printf 'PASS  %s\n' "$1"
    else printf 'FAIL  %s: expected %s, got %s\n' "$1" "$3" "$2"; fails=$((fails+1)); fi
}
check "to_minor" "$(to_minor 12.34)" "1234"
check "from_minor" "$(from_minor 1234)" "12.34"
check "add_minor" "$(add_minor 100 250)" "350"
check "submit_payout" "$(submit_payout 500 alice 2>/dev/null)" "500 alice"
check "payout_status" "$(payout_status settled)" "settled"
submit_payout 500 "" 2>/dev/null; check "missing payee returns 2" "$?" "2"
exit "$fails"
