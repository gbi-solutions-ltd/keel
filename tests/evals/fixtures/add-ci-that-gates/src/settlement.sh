#!/usr/bin/env bash
# Settlement: a merchant's gross, fee and net for a batch of transactions.

SETTLEMENT_RATE_BPS="${SETTLEMENT_RATE_BPS:-250}"

# settle <amount>...; prints "gross fee net" in whole units
settle() {
    local gross=0 amount fee
    for amount in "$@"; do
        gross=$(( gross + amount ))
    done
    fee=$(( gross * SETTLEMENT_RATE_BPS / 10000 ))
    printf '%s %s %s\n' "$gross" "$fee" "$(( gross - fee ))"
}
