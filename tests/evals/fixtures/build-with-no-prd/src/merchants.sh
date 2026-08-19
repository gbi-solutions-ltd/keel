#!/usr/bin/env bash
# Merchant records.

MERCHANTS="${MERCHANTS:-data/merchants.tsv}"

# Columns: id, name, settlement_currency, tier
merchant_name() {   # merchant_name <id>
    awk -F'\t' -v id="$1" '$1==id {print $2; found=1} END {exit !found}' "$MERCHANTS"
}
