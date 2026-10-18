#!/usr/bin/env bash
# Payout validation and fees.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/payouts.sh

pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1))
    fi
}
valid() { if payout_valid "$@"; then echo yes; else echo no; fi; }

check "a payout in a supported currency is valid"  yes  "$(valid 50000 UGX)"
check "a payout below the minimum is refused"      no   "$(valid 999 UGX)"
check "the minimum itself is allowed"              yes  "$(valid 1000 KES)"
check "an unsupported currency is refused"         no   "$(valid 50000 USD)"
check "a non-numeric amount is refused"            no   "$(valid 12a UGX)"
check "the fee is 500 plus one percent"            1000 "$(payout_fee 50000)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
