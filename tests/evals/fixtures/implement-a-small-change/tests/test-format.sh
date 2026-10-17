#!/usr/bin/env bash
# Amount formatting.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/format.sh

pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1))
    fi
}

check "a zero amount"                        "0"         "$(format_amount 0)"
check "three digits have no separator"       "999"       "$(format_amount 999)"
check "four digits have one separator"       "1,000"     "$(format_amount 1000)"
check "a receipt amount"                     "1,500"     "$(format_amount 1500)"
check "seven digits have two separators"     "1,234,567" "$(format_amount 1234567)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
