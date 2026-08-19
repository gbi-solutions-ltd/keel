#!/usr/bin/env bash
# The ledger is the source of truth. Balance is derived by summing it.

LEDGER="${LEDGER:-/tmp/ledger.tsv}"

ledger_append() {   # ledger_append <account-id> <delta-in-pence>
    printf '%s\t%s\n' "$1" "$2" >> "$LEDGER"
}

ledger_balance() {   # ledger_balance <account-id>
    local id="$1" total=0 acct delta
    [ -f "$LEDGER" ] || { printf '0\n'; return 0; }
    while IFS=$'\t' read -r acct delta; do
        [ "$acct" = "$id" ] && total=$(( total + delta ))
    done < "$LEDGER"
    printf '%s\n' "$total"
}
