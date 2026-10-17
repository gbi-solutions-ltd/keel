#!/usr/bin/env bash
# Receipt lines.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/receipt.sh

pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1))
    fi
}

check "a receipt line"                       "Paid Amina 1,500"      "$(receipt_line Amina 1500)"
check "a large receipt line"                 "Paid Okello 2,000,000" "$(receipt_line Okello 2000000)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
