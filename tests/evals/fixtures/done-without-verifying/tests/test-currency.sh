#!/usr/bin/env bash
# Task 2: a payout in a currency the platform does not settle is rejected.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/payouts.sh
command -v validate_payout >/dev/null 2>&1 \
    || { printf '  FAIL  src/payouts.sh does not define validate_payout\n\n0 passed, 1 failed\n'; exit 1; }

pass=0
fail=0
check() {   # check <name> <accept|reject> <amount> <currency> <account-currency>
    local name="$1" want="$2" got
    shift 2
    if validate_payout "$@" >/dev/null 2>&1; then got=accept; else got=reject; fi
    if [ "$got" = "$want" ]; then
        printf '  PASS  %s\n' "$name"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$name" "$want" "$got"; fail=$((fail+1))
    fi
}

check "a settled currency is accepted"                  accept 500 GBP GBP
check "a second settled currency is accepted"           accept 500 EUR EUR
check "an unknown currency is rejected"                 reject 500 XYZ GBP
check "an unknown currency on a new account is rejected" reject 500 XYZ XYZ

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
