#!/usr/bin/env bash
# Runs every keel test.
# Usage: tests/run-tests.sh   (from the repository root)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Every file below builds its own mktemp fixtures, cds into its own subshells, and scopes any
# HOME / CLAUDE_CONFIG_DIR / KEEL_DENY_FILE override to a single command rather than exporting it;
# none writes into this repository's tree or any other fixed shared path. Checked before
# parallelising by grepping every test file for hardcoded /tmp paths and shared env: the only
# "shared" looking strings found are literal "$HOME" and "/tmp/..." text some supply-chain-scan
# fixtures write INTO a scanned file, never executed. tests/validate-skills.sh,
# tests/no-internal-leaks.sh and tests/supply-chain-scan.sh, run "against this repo" below, only
# read the tree (git ls-files) and are safe alongside everything else for the same reason. That
# makes all of the jobs below independent, so they run in parallel rather than one after another.

names=(); cmds=()
add() { names+=("$1"); cmds+=("$2"); }

# The validator checks the repo; its own tests check the validator.
add "tests/test-validate-skills.sh" "tests/test-validate-skills.sh"
add "tests/test-keel.sh"            "tests/test-keel.sh"
add "tests/test-no-leaks.sh"        "tests/test-no-leaks.sh"
add "tests/test-apex-export.sh"     "tests/test-apex-export.sh"
add "tests/test-supply-chain.sh"    "tests/test-supply-chain.sh"
add "tests/test-context-watch.sh"   "tests/test-context-watch.sh"
add "tests/test-profile-keys.sh"    "tests/test-profile-keys.sh"
add "tests/test-sensitive-guard.sh" "tests/test-sensitive-guard.sh"
add "tests/test-done-guard.sh"      "tests/test-done-guard.sh"
add "tests/test-session-start.sh"   "tests/test-session-start.sh"
add "tests/test-cache-install.sh"   "tests/test-cache-install.sh"
add "tests/test-doc-claims.sh"      "tests/test-doc-claims.sh"
add "tests/test-eval-harness.sh"    "tests/test-eval-harness.sh"
add "tests/validate-skills.sh (against this repo)"   "tests/validate-skills.sh"
add "tests/no-internal-leaks.sh (against this repo)" "tests/no-internal-leaks.sh"
add "tests/supply-chain-scan.sh (against this repo)" "tests/supply-chain-scan.sh"

# The same lint CI runs, read from the profile so the two cannot drift. Skipped when shellcheck is
# absent, with a warning, because it is a developer dependency and not a runtime one. Wrapped as a
# function, rather than run after everything else the way it used to be, so it starts alongside the
# rest instead of waiting for them: it does not touch any fixture, so nothing about it needs to run
# last.
# shellcheck disable=SC2329,SC2317
# Invoked indirectly, by name, through "${cmds[$i]}" below. SC2329 is the code newer shellcheck
# gives a never-invoked function; older releases, including the one CI installs, report the same
# situation as SC2317 on every line of the body, so both are disabled.
run_lint() {
    if command -v shellcheck >/dev/null 2>&1; then
        local lint
        lint=$(sed -n 's/.*"lint": "\(.*\)",*/\1/p' .keel/profile.json | head -1)
        eval "$lint" && printf 'OK    shellcheck clean\n'
    else
        printf 'SKIP  shellcheck is absent locally. CI will run it: install it to see what CI sees.\n'
    fi
}
add "lint (verify.lint from .keel/profile.json)" "run_lint"

# Launched in the background, capped at 4 concurrent so a laptop is not swamped, and replayed below
# in the order added above so the transcript reads the same as a serial run. Each job's exit code
# and elapsed seconds go to their own file rather than a shared one, because two backgrounded jobs
# writing "$rc" into the same variable would just race.
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT
MAX_JOBS=4

n=${#names[@]}
i=0
while [ "$i" -lt "$n" ]; do
    while [ "$(jobs -rp | wc -l)" -ge "$MAX_JOBS" ]; do
        sleep 0.2
    done
    (
        start=$(date +%s)
        "${cmds[$i]}" > "$LOG_DIR/$i.out" 2>&1
        rc=$?
        printf '%s %s\n' "$rc" "$(( $(date +%s) - start ))" > "$LOG_DIR/$i.meta"
    ) &
    i=$((i+1))
done
wait

failed=0
i=0
while [ "$i" -lt "$n" ]; do
    read -r rc elapsed < "$LOG_DIR/$i.meta"
    printf '\n== %s (%ss)\n' "${names[$i]}" "$elapsed"
    cat "$LOG_DIR/$i.out"
    [ "$rc" -eq 0 ] || failed=$((failed+1))
    i=$((i+1))
done

printf '\n'
if [ "$failed" -eq 0 ]; then printf 'All test files passed\n'; exit 0; fi
printf '%s test file(s) failed\n' "$failed"; exit 1
