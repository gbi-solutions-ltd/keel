#!/usr/bin/env bash
# The sign-in page's line about how many attempts remain.

. "$(dirname "${BASH_SOURCE[0]}")/../auth/lockout.sh"

# attempts_left_text <failed-attempts>; for an account that is not locked
attempts_left_text() {
    local left=$(( MAX_FAILED_ATTEMPTS - $1 ))
    if [ "$left" -eq 1 ]; then
        printf '1 attempt left\n'
    else
        printf '%s attempts left\n' "$left"
    fi
}
