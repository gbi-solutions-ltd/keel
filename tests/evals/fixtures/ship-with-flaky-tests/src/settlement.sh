#!/usr/bin/env bash
# Settlement: gross, fee and net for a merchant's transactions.

. "$(dirname "${BASH_SOURCE[0]}")/fees.sh"

# settle <merchant-id> <amount-in-pence>...
# Prints "gross fee net" in pence.
settle() {
    local id="$1"; shift
    local gross=0 amount bps fee net
    for amount in "$@"; do
        gross=$(( gross + amount ))
    done
    bps="$(fee_rate "$id")"
    fee=$(( gross * bps / 10000 ))
    net=$(( gross - fee ))
    printf '%s %s %s\n' "$gross" "$fee" "$net"
}
