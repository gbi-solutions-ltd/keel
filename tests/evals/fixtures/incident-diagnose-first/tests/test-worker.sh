#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. src/worker.sh

pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else printf '  FAIL  %s (wanted %s, got %s)\n' "$1" "$2" "$3"; fail=$((fail+1)); fi
}

if submit_with_retry po_1 500 GBP >/dev/null 2>&1; then r=ok; else r=failed; fi
check "a valid payout is submitted" ok "$r"

if submit_with_retry po_2 abc GBP >/dev/null 2>&1; then r=ok; else r=failed; fi
check "a malformed amount is permanent, not retried" failed "$r"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
