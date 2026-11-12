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
# tests/no-internal-leaks.sh, tests/supply-chain-scan.sh and tests/validate-citations.sh, run
# "against this repo" below, only read the tree and are safe alongside everything else. That
# makes all of the jobs below independent, so they run in parallel rather than one after another.
# The runner's one write into the tree is its own: .keel/test-durations, git-ignored, which records
# each file's last duration so the next run can start the longest first. A KEEL_TEST_FILES run
# writes it only when KEEL_TEST_DURATIONS names it.

names=(); cmds=()
add() { names+=("$1"); cmds+=("$2"); }

# KEEL_TEST_FILES replaces the list below, and the lint job with it, so tests/test-run-tests.sh can
# drive this runner over stub files without running the whole suite inside itself.
# KEEL_TEST_DURATIONS moves the durations file for the same reason. Without it a KEEL_TEST_FILES run
# reads the default file and leaves it as it was: a partial run's durations would replace the
# whole suite's.
DURATIONS="${KEEL_TEST_DURATIONS:-.keel/test-durations}"
RECORD=1
if [ -n "${KEEL_TEST_FILES:-}" ]; then
    [ -n "${KEEL_TEST_DURATIONS:-}" ] || RECORD=0
    for f in $KEEL_TEST_FILES; do add "$f" "$f"; done
else

# The validator checks the repo; its own tests check the validator.
add "tests/test-validate-skills.sh" "tests/test-validate-skills.sh"
add "tests/test-keel.sh"            "tests/test-keel.sh"
add "tests/test-keel-2.sh"          "tests/test-keel-2.sh"
add "tests/test-keel-3.sh"          "tests/test-keel-3.sh"
add "tests/test-keel-4.sh"          "tests/test-keel-4.sh"
add "tests/test-keel-5.sh"          "tests/test-keel-5.sh"
add "tests/test-no-leaks.sh"        "tests/test-no-leaks.sh"
add "tests/test-apex-export.sh"     "tests/test-apex-export.sh"
add "tests/test-supply-chain.sh"    "tests/test-supply-chain.sh"
add "tests/test-context-watch.sh"   "tests/test-context-watch.sh"
add "tests/test-profile-keys.sh"    "tests/test-profile-keys.sh"
add "tests/test-sensitive-guard.sh" "tests/test-sensitive-guard.sh"
add "tests/test-review-guard.sh"    "tests/test-review-guard.sh"
add "tests/test-done-guard.sh"      "tests/test-done-guard.sh"
add "tests/test-session-start.sh"   "tests/test-session-start.sh"
add "tests/test-cache-install.sh"   "tests/test-cache-install.sh"
add "tests/test-doc-claims.sh"      "tests/test-doc-claims.sh"
add "tests/test-eval-harness.sh"    "tests/test-eval-harness.sh"
add "tests/test-harness-resolve.sh"  "tests/test-harness-resolve.sh"
add "tests/test-harness-claims.sh"   "tests/test-harness-claims.sh"
add "tests/test-validate-citations.sh" "tests/test-validate-citations.sh"
add "tests/test-keel-fleet.sh" "tests/test-keel-fleet.sh"
add "tests/test-plan.sh"        "tests/test-plan.sh"
add "tests/test-agents.sh" "tests/test-agents.sh"
add "tests/test-ci-review.sh" "tests/test-ci-review.sh"
add "tests/test-subagent-statusline.sh" "tests/test-subagent-statusline.sh"
add "tests/test-run-tests.sh" "tests/test-run-tests.sh"
add "tests/test-grep-quiet.sh" "tests/test-grep-quiet.sh"; add "tests/test-withheld.sh" "tests/test-withheld.sh"; add "tests/test-leak-guard.sh" "tests/test-leak-guard.sh"; add "tests/test-check-dco.sh" "tests/test-check-dco.sh"
add "tests/validate-skills.sh (against this repo)"   "tests/validate-skills.sh"
add "tests/no-internal-leaks.sh (against this repo)" "tests/no-internal-leaks.sh"
add "tests/supply-chain-scan.sh (against this repo)" "tests/supply-chain-scan.sh"
add "tests/validate-citations.sh (against this repo)" "tests/validate-citations.sh"

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
fi

# Launched in the background, longest first by the durations the last run recorded, so the slowest
# file is not the last one started and the wall time is close to that file's own. A file with no
# recorded duration runs before every recorded one, because unknown is treated as slow. Each job's
# log is replayed below in the order the jobs started, so the transcript reads the same as a serial
# run. Each job's exit code and elapsed seconds go to their own file rather than a shared one,
# because two backgrounded jobs writing "$rc" into the same variable would just race.
LOG_DIR="$(mktemp -d)"; [ -d "$LOG_DIR" ] || { echo "$0: mktemp -d failed" >&2; kill $$; exit 1; }
trap 'rm -rf "$LOG_DIR"' EXIT

# KEEL_TEST_JOBS when it is a positive integer, else the online CPU count capped at 8 so a large
# machine does not start every file at once, else 4.
positive() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; [ "$1" -gt 0 ]; }
if positive "${KEEL_TEST_JOBS:-}"; then
    MAX_JOBS=$KEEL_TEST_JOBS
elif cpus=$(getconf _NPROCESSORS_ONLN 2>/dev/null) && positive "$cpus"; then
    MAX_JOBS=$cpus
    [ "$MAX_JOBS" -le 8 ] || MAX_JOBS=8
else
    MAX_JOBS=4
fi

# No ambient git identity, for every job below. The CI runner has none, and on 2026-09-07 three
# cases in tests/test-keel.sh failed there with `fatal: empty ident name (for <runner@...>) not
# allowed`: their setup's `git init && ... && git commit && keel init` chain aborted at the commit,
# no .keel/profile.json was ever written, and the assertion reported an empty value rather than a
# wrong one. All three passed on every laptop, because a laptop has a global user.name. Setting
# user.useConfigOnly turns git's identity auto-detection off, so a fixture that means to commit has
# to configure its own identity, and the next setup copied from one of these fails on the machine
# that wrote it instead of in CI. The file is real and writable, not /dev/null, because
# tests/test-keel-4.sh asserts `keel guard install` leaves the global config alone and that assertion
# has to be able to see a global write.
GIT_CONFIG_SYSTEM=/dev/null
GIT_CONFIG_GLOBAL="$LOG_DIR/gitconfig"
printf '[user]\n\tuseConfigOnly = true\n' > "$GIT_CONFIG_GLOBAL"
export GIT_CONFIG_SYSTEM GIT_CONFIG_GLOBAL

# The run order, as indices into names: each name's recorded seconds, or one more than any second a
# run could take when none is recorded, sorted longest first and by list position within a tie.
n=${#names[@]}
order=$(
    i=0
    while [ "$i" -lt "$n" ]; do printf '%s\t%s\n' "$i" "${names[$i]}"; i=$((i+1)); done |
        awk -F'\t' -v durs="$DURATIONS" '
            BEGIN { while ((getline l < durs) > 0) { s = l; sub(/ .*/, "", s); sub(/^[^ ]* /, "", l); d[l] = s } }
            { print (($2 in d) ? d[$2] : 999999), $1 }' |
        sort -k1,1nr -k2,2n | cut -d' ' -f2
)
total=$(sed -n 's/^total \([0-9][0-9]*\)$/\1/p' "$DURATIONS" 2>/dev/null | head -1)
run_start=$(date +%s)

for i in $order; do
    while [ "$(jobs -rp | wc -l)" -ge "$MAX_JOBS" ]; do
        sleep 0.2
    done
    (
        start=$(date +%s)
        "${cmds[$i]}" > "$LOG_DIR/$i.out" 2>&1
        rc=$?
        printf '%s %s\n' "$rc" "$(( $(date +%s) - start ))" > "$LOG_DIR/$i.meta"
    ) &
done
wait
wall=$(( $(date +%s) - run_start ))

# The durations are rewritten for the next run, gathered while the logs replay and written once at
# the end, so a run stopped during the jobs leaves the last record in place. This is the one file
# the runner writes into the repository's tree, and a partial run with no KEEL_TEST_DURATIONS skips
# the write. The file's directory is made on every run: a partial run that writes no file leaves at
# most an empty .keel/, which git never tracks.
failed=0
mkdir -p "$(dirname "$DURATIONS")"
: > "$LOG_DIR/durations"
for i in $order; do
    read -r rc elapsed < "$LOG_DIR/$i.meta"
    printf '\n== %s (%ss)\n' "${names[$i]}" "$elapsed"
    cat "$LOG_DIR/$i.out"
    [ "$rc" -eq 0 ] || failed=$((failed+1))
    printf '%s %s\n' "$elapsed" "${names[$i]}" >> "$LOG_DIR/durations"
done
printf 'total %s\n' "$wall" >> "$LOG_DIR/durations"
[ "$RECORD" -eq 0 ] || mv "$LOG_DIR/durations" "$DURATIONS"

printf '\n'
# A run over twice the last one usually means something new is slow, or the machine is busy.
if [ -n "$total" ] && [ "$wall" -gt $((total * 2)) ]; then
    printf 'This run took %ss, over twice the last run (%ss).\n' "$wall" "$total"
fi
if [ "$failed" -eq 0 ]; then printf 'All test files passed\n'; exit 0; fi
printf '%s test file(s) failed\n' "$failed"; exit 1
