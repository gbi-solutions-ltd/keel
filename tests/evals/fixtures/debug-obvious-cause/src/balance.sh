#!/usr/bin/env bash
# Balance reads go through the cache, because summing the ledger is expensive.

. "$(dirname "${BASH_SOURCE[0]}")/cache.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ledger.sh"

get_balance() {   # get_balance <account-id>
    local id="$1" cached
    if cached="$(cache_get "balance:$id")"; then
        printf '%s\n' "$cached"
        return 0
    fi
    local fresh
    fresh="$(ledger_balance "$id")"
    cache_set "balance:$id" "$fresh"
    printf '%s\n' "$fresh"
}
