#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
if bash tests/test-payouts.sh; then echo "All tests passed"; exit 0; fi
echo "Tests failed"; exit 1
