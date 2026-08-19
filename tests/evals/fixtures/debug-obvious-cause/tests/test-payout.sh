#!/usr/bin/env bash
# The payout write path.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

export LEDGER
LEDGER="$(mktemp)"
trap 'rm -f "$LEDGER"' EXIT

. src/payout.sh

pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1))
    fi
}

ledger_append acc_1 10000
make_payout acc_1 2500 >/dev/null
check "a payout debits the ledger" 7500 "$(ledger_balance acc_1)"

if make_payout acc_1 -5 >/dev/null 2>&1; then r=accept; else r=reject; fi
check "a negative payout is rejected" reject "$r"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
