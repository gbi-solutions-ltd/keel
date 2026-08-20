#!/usr/bin/env bash
# Runs the payout service's tests. With no argument, runs every tests/test-*.sh.
# Usage: tests/run-tests.sh [test-file ...]

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

failed=0
run() {
    printf '\n== %s\n' "$1"
    if bash "$1"; then :; else failed=$((failed+1)); fi
}

if [ "$#" -gt 0 ]; then
    for t in "$@"; do run "$t"; done
else
    for t in tests/test-*.sh; do run "$t"; done
fi

printf '\n'
if [ "$failed" -eq 0 ]; then printf 'All test files passed\n'; exit 0; fi
printf '%s test file(s) failed\n' "$failed"; exit 1
