#!/usr/bin/env bash
# tests/run-tests.sh itself: the order it runs files in, how many it runs at once, the durations
# file it learns that order from, and the warning when a run takes over twice the last one.
# Plan: docs/plans/2026-11-12-plan-execution-speed-2.md, task 1.
#
# Every case drives the runner over stub files through KEEL_TEST_FILES, so the real suite never runs
# inside itself, and either sets KEEL_TEST_DURATIONS to a temporary path or runs a temp copy of the
# runner, so the repository's own .keel/test-durations is never read or written here. No case asserts wall time: the suite runs this
# file beside others, so only counts and order are stable.
set -uo pipefail; . "$(dirname "${BASH_SOURCE[0]}")/grep-quiet.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }
expect() {
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "got: $2 / want: $3"; fi
  return 0
}

TMP="$(mktemp -d)"; [ -d "$TMP" ] || { echo "$0: mktemp -d failed" >&2; kill $$; exit 1; }
trap 'rm -rf "$TMP"' EXIT

# stub <path> <body>: a test file that runs <body> and exits 0. It is run once with an argument, which
# exits before the body, because macOS takes about half a second over the first exec of a new file:
# unwarmed, four stubs started that far apart and never ran four at once even with four jobs free.
stub() {
  printf '#!/usr/bin/env bash\n[ $# -gt 0 ] && exit 0\n%s\nexit 0\n' "$2" > "$1"
  chmod +x "$1"
  "$1" warm
}

# 1. Longest-first by recorded duration, an unrecorded file before every recorded one, and the
#    durations written back for each file run.
d="$TMP/order"; mkdir "$d"
for s in a b c; do stub "$d/$s.sh" "echo $s >> '$d/started'; sleep 0.2"; done
printf '1 %s\n5 %s\n' "$d/a.sh" "$d/b.sh" > "$d/durations"
out=$(KEEL_TEST_FILES="$d/a.sh $d/b.sh $d/c.sh" KEEL_TEST_JOBS=1 KEEL_TEST_DURATIONS="$d/durations" \
  tests/run-tests.sh 2>&1)
rc=$?
expect "longest-first: the run passes" "$rc" "0"
expect "longest-first: an unrecorded file starts first, then the longest recorded" \
  "$(tr '\n' ' ' < "$d/started")" "c b a "
expect "longest-first: each log is replayed in run order" \
  "$(printf '%s\n' "$out" | sed -n 's/^== \([^ ]*\) .*/\1/p' | tr '\n' ' ')" "$d/c.sh $d/b.sh $d/a.sh "
for s in a b c; do
  if grep -qE "^[0-9]+ $d/$s\.sh\$" "$d/durations"; then
    ok "longest-first: the durations file holds a line for $s.sh"
  else
    bad "longest-first: the durations file holds a line for $s.sh" "$(cat "$d/durations")"
  fi
done
if grep -qE '^total [0-9]+$' "$d/durations"; then ok "longest-first: the durations file holds a total line"
else bad "longest-first: the durations file holds a total line" "$(cat "$d/durations")"; fi

# 2. KEEL_TEST_FILES skips the lint job.
if printf '%s\n' "$out" | grep -q '^== lint'; then bad "KEEL_TEST_FILES: no lint job runs" "$out"
else ok "KEEL_TEST_FILES: no lint job runs"; fi

# 3. The job count. Each stub adds an entry to a shared directory, records how many it sees, holds
#    for a second and removes its entry, so the largest count recorded is the most that ran at once.
# peak <jobs>: the largest count any of four such stubs records under KEEL_TEST_JOBS=<jobs>, then
# the runner's exit code and anything it said about an integer.
peak() {
  local w="$TMP/jobs-$1" s files=""
  mkdir -p "$w/live"
  for s in 1 2 3 4; do
    stub "$w/s$s.sh" "touch '$w/live/$s'; ls '$w/live' | wc -l | tr -d ' ' >> '$w/counts'; sleep 1; rm -f '$w/live/$s'"
    files="$files $w/s$s.sh"
  done
  local rc=0
  KEEL_TEST_FILES="$files" KEEL_TEST_JOBS="$1" KEEL_TEST_DURATIONS="$w/durations" \
    tests/run-tests.sh > "$w/out" 2>&1 || rc=$?
  printf '%s rc=%s %s\n' "$(sort -n "$w/counts" | tail -1)" "$rc" "$(grep -c 'integer' "$w/out")"
}
expect "job count: KEEL_TEST_JOBS=2 runs exactly 2 at once" "$(peak 2)" "2 rc=0 0"
expect "job count: KEEL_TEST_JOBS=1 runs 1 at once" "$(peak 1)" "1 rc=0 0"
got=$(peak abc)
expect "job count: KEEL_TEST_JOBS=abc falls back to the CPU rule without error" "${got#* }" "rc=0 0"

# 4. The slow-run warning: over twice the recorded total says so, no recorded total says nothing.
d="$TMP/slow"; mkdir "$d"
stub "$d/slow.sh" "sleep 3"
printf 'total 1\n' > "$d/with-total"
out=$(KEEL_TEST_FILES="$d/slow.sh" KEEL_TEST_DURATIONS="$d/with-total" tests/run-tests.sh 2>&1)
if printf '%s\n' "$out" | grep -q 'over twice the last run'; then
  ok "slow run: over twice the recorded total is said"
else
  bad "slow run: over twice the recorded total is said" "$out"
fi
out=$(KEEL_TEST_FILES="$d/slow.sh" KEEL_TEST_DURATIONS="$d/no-total" tests/run-tests.sh 2>&1)
if printf '%s\n' "$out" | grep -q 'over twice the last run'; then
  bad "slow run: no recorded total says nothing" "$out"
else
  ok "slow run: no recorded total says nothing"
fi

# 5. The durations file is git-ignored.
if git check-ignore -q .keel/test-durations; then ok "durations file: git-ignored"
else bad "durations file: git-ignored" "git check-ignore .keel/test-durations exited non-zero"; fi

# 5b. A KEEL_TEST_FILES run with no KEEL_TEST_DURATIONS leaves the default durations file as it
#     was: a partial run's durations would replace the whole suite's. The runner runs from a temp
#     copy of its root, so the default path it writes to is that copy's, never this repository's.
r="$TMP/root"; mkdir -p "$r/tests" "$r/.keel"
cp tests/run-tests.sh "$r/tests/"
printf '7 tests/test-a.sh\ntotal 7\n' > "$r/.keel/test-durations"
cp "$r/.keel/test-durations" "$TMP/durations-before"
stub "$r/one.sh" ":"
env -u KEEL_TEST_DURATIONS KEEL_TEST_FILES="$r/one.sh" "$r/tests/run-tests.sh" > "$TMP/partial-out" 2>&1
expect "partial run: the runner passes" "$?" "0"
if cmp -s "$TMP/durations-before" "$r/.keel/test-durations"; then
  ok "partial run: KEEL_TEST_FILES without KEEL_TEST_DURATIONS leaves the durations file unchanged"
else
  bad "partial run: KEEL_TEST_FILES without KEEL_TEST_DURATIONS leaves the durations file unchanged" \
    "$(cat "$r/.keel/test-durations")"
fi

# 6. The snapshot's development setup states the order and job count, not a fixed duration.
if grep -q 'about 6 minutes' docs/snapshot.md; then
  bad "snapshot: no longer says about 6 minutes" "$(grep -n 'about 6 minutes' docs/snapshot.md)"
else
  ok "snapshot: no longer says about 6 minutes"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
