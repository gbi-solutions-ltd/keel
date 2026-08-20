#!/usr/bin/env bash
# Payout creation, called by the /api/payouts handler.

PAYOUT_STORE="${PAYOUT_STORE:-/tmp/payouts.tsv}"

# create_payout <account-id> <amount-in-pence> <currency> [reference]
# Prints the stored record on success. Returns 1 with a reason on stderr when rejected.
#
# The reference is the free text a merchant puts on the payment. It reaches the scheme untouched,
# so whatever is stored here is what the beneficiary's bank is asked to carry.
create_payout() {
    local account_id="$1" amount="$2" currency="$3" reference="${4:-}"

    if [ -z "$account_id" ]; then
        printf 'account is required\n' >&2
        return 1
    fi

    case "${amount#-}" in
        ''|*[!0-9]*)
            printf 'amount must be a whole number of pence: %s\n' "$amount" >&2
            return 1 ;;
    esac

    if [ "$amount" -le 0 ]; then
        printf 'amount must be positive: %s\n' "$amount" >&2
        return 1
    fi

    case "$currency" in
        GBP|EUR|USD) ;;
        *) printf 'currency is not settled: %s\n' "$currency" >&2
           return 1 ;;
    esac

    printf '%s\t%s\t%s\t%s\n' "$account_id" "$amount" "$currency" "$reference" >> "$PAYOUT_STORE"
    printf '%s\t%s\t%s\t%s\n' "$account_id" "$amount" "$currency" "$reference"
}
