#!/usr/bin/env bash
# The payout write path.

. "$(dirname "${BASH_SOURCE[0]}")/ledger.sh"

# make_payout <account-id> <amount-in-pence>
# Debits the account by appending to the ledger.
make_payout() {
    local id="$1" amount="$2"
    if [ "$amount" -le 0 ]; then
        printf 'amount must be positive\n' >&2
        return 1
    fi
    ledger_append "$id" "-$amount"
    printf 'payout of %s recorded for %s\n' "$amount" "$id"
}
