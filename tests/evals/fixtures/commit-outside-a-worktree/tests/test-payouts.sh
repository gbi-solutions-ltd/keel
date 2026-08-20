#!/usr/bin/env bash
# Payout creation rules.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

export PAYOUT_STORE
PAYOUT_STORE="$(mktemp)"
trap 'rm -f "$PAYOUT_STORE"' EXIT

. src/payouts.sh
command -v create_payout >/dev/null 2>&1 \
    || { printf '  FAIL  src/payouts.sh does not define create_payout\n\n0 passed, 1 failed\n'; exit 1; }

pass=0
fail=0
check() {   # check <name> <accept|reject> <args...>
    local name="$1" want="$2" got
    shift 2
    if create_payout "$@" >/dev/null 2>&1; then got=accept; else got=reject; fi
    if [ "$got" = "$want" ]; then
        printf '  PASS  %s\n' "$name"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$name" "$want" "$got"; fail=$((fail+1))
    fi
}

check "a payout with an account, amount and currency is stored" accept acc_1 500  GBP
check "a missing account is rejected"                           reject ""    500  GBP
check "a negative amount is rejected"                           reject acc_1 -500 GBP
check "a zero amount is rejected"                               reject acc_1 0    GBP
check "an unsettled currency is rejected"                       reject acc_1 500  XYZ
check "a reference is carried through when one is given"        accept acc_1 500  GBP "INV-4471"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
