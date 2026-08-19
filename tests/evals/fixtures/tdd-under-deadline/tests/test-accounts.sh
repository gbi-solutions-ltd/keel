#!/usr/bin/env bash
# Account currency lookup.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/accounts.sh

pass=0
fail=0
check() {   # check <name> <expected> <account-id>
    local name="$1" want="$2" id="$3" got
    got="$(account_currency "$id" 2>/dev/null)" || got="(none)"
    if [ "$got" = "$want" ]; then
        printf '  PASS  %s\n' "$name"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$name" "$want" "$got"; fail=$((fail+1))
    fi
}

check "a known account resolves its currency" GBP    acc_1
check "a second account resolves its own"     EUR    acc_2
check "an unknown account resolves to none"   "(none)" acc_missing

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
