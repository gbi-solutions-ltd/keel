#!/usr/bin/env bash
# Runs every keel test. Free, no dependencies, about four and a half minutes.
# Usage: tests/run-tests.sh   (from the repository root)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

failed=0
run() {
    printf '\n== %s\n' "$1"
    if "$1"; then :; else failed=$((failed+1)); fi
}

# The validator checks the repo; its own tests check the validator.
run tests/test-validate-skills.sh
run tests/test-keel.sh
run tests/test-no-leaks.sh
run tests/test-apex-export.sh
run tests/test-supply-chain.sh
run tests/test-context-watch.sh
run tests/test-sensitive-guard.sh
run tests/test-done-guard.sh
run tests/test-session-start.sh
run tests/test-cache-install.sh
run tests/test-doc-claims.sh
printf '\n== tests/validate-skills.sh (against this repo)\n'
if tests/validate-skills.sh; then :; else failed=$((failed+1)); fi

printf '\n== tests/no-internal-leaks.sh (against this repo)\n'
if tests/no-internal-leaks.sh; then :; else failed=$((failed+1)); fi

printf '\n== tests/supply-chain-scan.sh (against this repo)\n'
if tests/supply-chain-scan.sh; then :; else failed=$((failed+1)); fi

# The same lint CI runs, read from the profile so the two cannot drift. Skipped when shellcheck is
# absent, with a warning, because it is a developer dependency and not a runtime one.
printf '\n== lint (verify.lint from .keel/profile.json)\n'
if command -v shellcheck >/dev/null 2>&1; then
    LINT=$(sed -n 's/.*"lint": "\(.*\)",*/\1/p' .keel/profile.json | head -1)
    if eval "$LINT"; then printf 'OK    shellcheck clean\n'; else failed=$((failed+1)); fi
else
    printf 'SKIP  shellcheck is absent locally. CI will run it: install it to see what CI sees.\n'
fi

printf '\n'
if [ "$failed" -eq 0 ]; then printf 'All test files passed\n'; exit 0; fi
printf '%s test file(s) failed\n' "$failed"; exit 1
