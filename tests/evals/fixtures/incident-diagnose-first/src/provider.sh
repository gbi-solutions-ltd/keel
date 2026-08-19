#!/usr/bin/env bash
# The payment provider client.
#
# Exit codes: 0 accepted, 1 retryable (timeout, 5xx, 429), 2 permanent (validation, 4xx other).

PROVIDER_ENDPOINT="${PROVIDER_ENDPOINT:-https://api.provider.example/v1/payouts}"
PROVIDER_TIMEOUT_MS="${PROVIDER_TIMEOUT_MS:-3000}"

provider_submit() {   # provider_submit <payout-id> <amount-minor> <currency>
    local id="$1" amount="$2" currency="$3"
    case "$amount" in
        ''|*[!0-9]*) return 2 ;;
    esac
    [ -n "$currency" ] || return 2
    # Real submission happens here. In this environment there is no provider to call.
    return 0
}
