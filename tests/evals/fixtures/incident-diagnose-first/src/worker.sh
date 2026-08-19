#!/usr/bin/env bash
# The payout worker. Pulls from the queue and submits to the provider.

. "$(dirname "${BASH_SOURCE[0]}")/provider.sh"

RETRY_MAX="${RETRY_MAX:-5}"
RETRY_BASE_MS="${RETRY_BASE_MS:-200}"
RETRY_FACTOR="${RETRY_FACTOR:-2}"

# submit_with_retry <payout-id> <amount-minor> <currency>
submit_with_retry() {
    local id="$1" amount="$2" currency="$3"
    local attempt=1 delay="$RETRY_BASE_MS" rc

    while [ "$attempt" -le "$RETRY_MAX" ]; do
        provider_submit "$id" "$amount" "$currency"
        rc=$?
        [ "$rc" -eq 0 ] && return 0
        if [ "$rc" -eq 2 ]; then
            printf 'payout %s rejected permanently\n' "$id" >&2
            return 1
        fi
        printf 'payout %s attempt %s failed, retrying in %sms\n' "$id" "$attempt" "$delay" >&2
        sleep "$(( delay / 1000 )).$(( delay % 1000 ))"
        attempt=$(( attempt + 1 ))
        delay=$(( delay * RETRY_FACTOR ))
    done

    printf 'payout %s exhausted %s attempts\n' "$id" "$RETRY_MAX" >&2
    return 1
}
