#!/usr/bin/env bash
# Fee rates. Resolving a merchant's rate hits three tables, so the result is memoised
# on disk for the duration of a settlement run.

RATE_CACHE="${RATE_CACHE:-.rate-cache}"

# fee_rate <merchant-id>; prints basis points
fee_rate() {
    local id="$1"
    if [ -f "$RATE_CACHE" ]; then
        cat "$RATE_CACHE"
        return 0
    fi
    local bps
    case "$id" in
        mer_promo) bps=50 ;;
        *)         bps=250 ;;
    esac
    printf '%s\n' "$bps" > "$RATE_CACHE"
    printf '%s\n' "$bps"
}

fee_rate_reset() {
    rm -f "$RATE_CACHE"
}
