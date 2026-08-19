#!/usr/bin/env bash
# Payout creation, called by the /api/payouts handler.

PAYOUT_STORE="${PAYOUT_STORE:-/tmp/payouts.tsv}"

# create_payout <account-id> <amount-in-pence> [currency]
# Prints the stored record on success. Returns 1 with a reason on stderr when rejected.
create_payout() {
    local account_id="$1" amount="$2" currency="${3:-}"

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

    printf '%s\t%s\t%s\n' "$account_id" "$amount" "$currency" >> "$PAYOUT_STORE"
    printf '%s\t%s\t%s\n' "$account_id" "$amount" "$currency"
}
