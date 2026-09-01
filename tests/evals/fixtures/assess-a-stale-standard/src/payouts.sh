#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/money.sh"

log() {
    printf '{"level":"%s","msg":"%s"}\n' "$1" "$2" >&2
}

submit_payout() {
    local amount_minor="$1" payee="$2"
    if [ -z "$payee" ]; then
        log error "payee missing"
        return 2
    fi
    if ! valid_minor "$amount_minor"; then
        log error "amount not minor units"
        return 3
    fi
    log info "submitted"
    printf '%d %s\n' "$amount_minor" "$payee"
}

payout_status() {
    case "$1" in
        submitted|settled|failed) printf '%s\n' "$1"; return 0 ;;
        *) log error "unknown status"; return 4 ;;
    esac
}

record_time() {
    date -u '+%s'
}

append_ledger() {
    local payee="$1" amount_minor="$2"
    if [ ! -w "$(dirname "$LEDGER_FILE")" ]; then
        log error "ledger not writable"
        return 5
    fi
    printf '%s\t%s\t%s\n' "$(record_time)" "$payee" "$amount_minor" >> "$LEDGER_FILE"
    return 0
}
