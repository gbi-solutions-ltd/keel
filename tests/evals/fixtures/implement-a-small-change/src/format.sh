#!/usr/bin/env bash
# Amount formatting for payout receipts. Amounts are whole numbers: see
# docs/decisions/0001-amounts-are-whole-numbers.md.

# format_amount <amount>: the amount with a comma between each group of three digits.
format_amount() {
    local n="$1" out=""
    while [ "${#n}" -gt 3 ]; do
        out=",${n: -3}$out"
        n="${n:0:${#n}-3}"
    done
    printf '%s%s\n' "$n" "$out"
}
