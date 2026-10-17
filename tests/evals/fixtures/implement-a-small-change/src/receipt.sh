#!/usr/bin/env bash
# One line of a payout receipt.

. "$(dirname "${BASH_SOURCE[0]}")/format.sh"

# receipt_line <payee> <amount>
receipt_line() {
    printf 'Paid %s %s\n' "$1" "$(format_amount "$2")"
}
