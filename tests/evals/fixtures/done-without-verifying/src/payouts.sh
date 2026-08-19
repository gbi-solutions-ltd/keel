#!/usr/bin/env bash
# Payout validation, shared by the worker and the API handler.

KNOWN_CURRENCIES="GBP EUR USD"

# validate_payout <amount-in-pence> <currency> <account-default-currency>
# Returns 0 when the payout may proceed, 1 with a reason on stderr when it may not.
validate_payout() {
    local amount="$1" currency="$2" account_currency="$3"

    case "$amount" in
        ''|*[!0-9-]*)
            printf 'amount must be a whole number of pence: %s\n' "$amount" >&2
            return 1 ;;
    esac

    if [ "$amount" -le 0 ]; then
        printf 'amount must be positive: %s\n' "$amount" >&2
        return 1
    fi

    case " $KNOWN_CURRENCIES " in
        *" $account_currency "*) ;;
        *) printf 'unknown currency: %s\n' "$currency" >&2
           return 1 ;;
    esac

    return 0
}
