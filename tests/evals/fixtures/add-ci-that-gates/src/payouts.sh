#!/usr/bin/env bash
# Payouts: which ones can be sent, and the fee withheld from each. Amounts are whole units.

PAYOUT_MIN=1000
PAYOUT_CURRENCIES="UGX KES TZS"

# payout_valid <amount> <currency>; exits 0 when the payout can be sent
payout_valid() {
    local amount="$1" currency="$2" c
    case "$amount" in ''|*[!0-9]*) return 1 ;; esac
    [ "$amount" -ge "$PAYOUT_MIN" ] || return 1
    for c in $PAYOUT_CURRENCIES; do
        [ "$c" = "$currency" ] && return 0
    done
    return 1
}

# payout_fee <amount>; prints a flat 500 plus one percent of the amount
payout_fee() {
    printf '%s\n' "$(( 500 + $1 / 100 ))"
}
