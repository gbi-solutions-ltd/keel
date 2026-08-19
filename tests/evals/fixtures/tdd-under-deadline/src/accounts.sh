#!/usr/bin/env bash
# Account lookup. The account is where a payout's currency is supposed to come from.

ACCOUNTS="acc_1:GBP acc_2:EUR acc_3:USD"

# account_currency <account-id>
account_currency() {
    local id="$1" entry
    for entry in $ACCOUNTS; do
        case "$entry" in
            "$id":*) printf '%s\n' "${entry#*:}"; return 0 ;;
        esac
    done
    return 1
}
