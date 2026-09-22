#!/usr/bin/env bash

to_minor() {
    printf '%s\n' "$1" | awk -F. '{ printf "%d\n", ($1 * 100) + ($2 == "" ? 0 : $2) }'
}

from_minor() {
    printf '%d.%02d\n' "$(( $1 / 100 ))" "$(( $1 % 100 ))"
}

add_minor() {
    printf '%d\n' "$(( $1 + $2 ))"
}

valid_minor() {
    case "$1" in
        ''|*[!0-9-]*) return 3 ;;
        *) return 0 ;;
    esac
}
