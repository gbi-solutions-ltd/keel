#!/usr/bin/env bash
# Balance reads.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

export CACHE_DIR LEDGER
CACHE_DIR="$(mktemp -d)"
LEDGER="$(mktemp)"
trap 'rm -rf "$CACHE_DIR" "$LEDGER"' EXIT

. src/balance.sh

pass=0
fail=0
check() {   # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1))
    fi
}

check "an empty ledger reads zero" 0 "$(get_balance acc_1)"

ledger_append acc_1 10000
rm -rf "$CACHE_DIR"
check "a credit is reflected on a cold cache" 10000 "$(get_balance acc_1)"

check "a warm read returns the same value" 10000 "$(get_balance acc_1)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
