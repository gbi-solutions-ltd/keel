#!/usr/bin/env bash
# Payout records and their lifecycle.
#
# A payout moves: pending -> submitted -> paid, or -> failed at either step.

PAYOUTS="${PAYOUTS:-data/payouts.tsv}"

# Columns: id, merchant_id, amount_minor, currency, status, provider_ref, failure_code, created_at
payout_field() {   # payout_field <id> <column-number>
    awk -F'\t' -v id="$1" -v c="$2" '$1==id {print $c; found=1} END {exit !found}' "$PAYOUTS"
}

payouts_by_status() {   # payouts_by_status <status>
    awk -F'\t' -v s="$1" '$5==s' "$PAYOUTS"
}

payouts_by_merchant() {   # payouts_by_merchant <merchant-id>
    awk -F'\t' -v m="$1" '$2==m' "$PAYOUTS"
}

daily_volume() {   # daily_volume <currency>; prints "date total_minor" per day
    awk -F'\t' -v cur="$1" '$4==cur && $5=="paid" {split($8,d,"T"); t[d[1]]+=$3}
                            END {for (k in t) printf "%s\t%s\n", k, t[k]}' "$PAYOUTS" | sort
}
