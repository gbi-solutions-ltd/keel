#!/usr/bin/env bash
# Tests for the eval harness: tests/evals/stage.sh, and the fixture it stages.
#
# Two findings drive this file, both recorded in tests/evals/results.md.
#
# The first is the evaluation-awareness exposure. An arm dispatched with this repository as its
# working directory can read tests/evals/scenarios/, which is the file describing how it will be
# scored. The 0.11.0 run suppressed that by instruction and said plainly that an instruction is not
# a fix. Staging outside the repository is the fix, so cases 1 to 6 assert the isolation rather
# than trusting it.
#
# The second is that the done-without-verifying fixture was silently worthless: its narrow test was
# four echo lines that never loaded the module, so the scenario asked "will an agent notice a fake
# test suite" rather than the question it exists to ask. Cases 7 to 11 pin the fixture's two load
# bearing properties, that the narrow command really passes against real code and the full suite
# really fails, so it cannot rot back into a stub without a test going red.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"

pass=0
fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); return 0; }
bad() { printf '  FAIL  %s: %s\n' "$1" "$2"; fail=$((fail+1)); return 0; }

staged=()
cleanup() { [ "${#staged[@]}" -gt 0 ] && rm -rf "${staged[@]}"; return 0; }
trap cleanup EXIT

# 1. An unknown scenario is refused, and says what there is. Same contract as run.sh: a typo that
# stages an empty directory would dispatch an arm against nothing and look like a result.
out="$(tests/evals/stage.sh no-such-scenario 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'debug-obvious-cause'; then
    ok "unknown scenario is refused and lists the available ones"
else
    bad "unknown scenario is refused and lists the available ones" "rc=$rc out=${out:0:120}"
fi

# 2. The staging directory is outside this repository. This is the whole point of the script: a
# working directory inside the tree leaves the scenario file one `cat` away.
dir="$(tests/evals/stage.sh done-without-verifying 2>/dev/null)"
staged+=("$dir")
case "$dir" in
    "$REPO"/*) bad "staged outside the repository" "staged inside the tree at $dir" ;;
    /*)        if [ -d "$dir" ]; then ok "staged outside the repository"
               else bad "staged outside the repository" "not a directory: $dir"; fi ;;
    *)         bad "staged outside the repository" "not an absolute path: $dir" ;;
esac

# 3. The assembled prompt is there, skills and all.
if grep -q '=== SKILL: execute-plan ===' "$dir/prompt.md" 2>/dev/null \
   && grep -q 'tick all the boxes' "$dir/prompt.md" 2>/dev/null; then
    ok "prompt.md carries the injected skills and the pressure prompt"
else
    bad "prompt.md carries the injected skills and the pressure prompt" "missing or incomplete"
fi

# 4. The scoring criteria are not staged. An arm that can read "Passes if the reply" is being
# measured against a mark scheme it has seen, which is the confound this script exists to remove.
if grep -rq 'Passes if the reply' "$dir" 2>/dev/null; then
    bad "the pass criteria are not staged" "found the criteria under $dir"
else
    ok "the pass criteria are not staged"
fi

# 5. The agent's working directory is project/, and it holds the fixture rather than the prompt.
if [ -f "$dir/project/src/payouts.sh" ] && [ -f "$dir/project/PLAN.md" ] \
   && [ ! -e "$dir/project/prompt.md" ]; then
    ok "the fixture is staged into project/, with the prompt kept out of it"
else
    bad "the fixture is staged into project/, with the prompt kept out of it" \
        "$(find "$dir/project" -mindepth 1 -maxdepth 1 2>&1 | tr '\n' ' ')"
fi

# 6. Two stagings do not share a directory. Recorded 2026-08-16: the first dispatch pointed both
# arms at one fixture directory and they would have raced on the same plan file. A result from that
# setup would have been unusable and would have looked fine.
dir2="$(tests/evals/stage.sh done-without-verifying 2>/dev/null)"
staged+=("$dir2")
if [ "$dir2" != "$dir" ]; then ok "each staging gets its own directory"
else bad "each staging gets its own directory" "both runs returned $dir"; fi

# 7. A scenario with no fixture still gets an empty working directory outside the repository,
# so every dispatch is isolated the same way.
dir3="$(tests/evals/stage.sh tdd-under-deadline 2>/dev/null)"
staged+=("$dir3")
if [ -d "$dir3/project" ] \
   && [ -z "$(find "$dir3/project" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
    ok "a fixtureless scenario stages an empty working directory"
else
    bad "a fixtureless scenario stages an empty working directory" \
        "$(find "$dir3/project" -mindepth 1 -maxdepth 1 2>&1 | tr '\n' ' ')"
fi

# 8. The narrow command in the plan's task 1 genuinely passes. If this goes red the scenario is
# invalid again: the user's premise is that it passed.
if ( cd "$dir/project" && tests/run-tests.sh tests/test-payouts.sh >/dev/null 2>&1 ); then
    ok "the narrow command passes, which is the scenario's premise"
else
    bad "the narrow command passes, which is the scenario's premise" \
        "$( cd "$dir/project" && tests/run-tests.sh tests/test-payouts.sh 2>&1 | tail -3 | tr '\n' ' ')"
fi

# 9. And it passes because it ran the code, not because it printed PASS. This is the treatment
# arm's own falsification experiment from 2026-08-16, kept as a test: empty the module, and a real
# test must go red.
cp "$dir/project/src/payouts.sh" "$dir/payouts.sh.bak"
: > "$dir/project/src/payouts.sh"
if ( cd "$dir/project" && tests/run-tests.sh tests/test-payouts.sh >/dev/null 2>&1 ); then
    bad "the narrow test loads the real module" "it still passes against an empty src/payouts.sh"
else
    ok "the narrow test loads the real module"
fi
cp "$dir/payouts.sh.bak" "$dir/project/src/payouts.sh"

# 10. The full suite fails, on the seeded currency regression rather than on anything else. The
# scenario is about a broader command the user did not run, so there must be something in it to find.
full="$( cd "$dir/project" && tests/run-tests.sh 2>&1 )"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$full" | grep -qi 'currenc'; then
    ok "the full suite fails on the seeded currency regression"
else
    bad "the full suite fails on the seeded currency regression" "rc=$rc out=$(printf '%s' "$full" | tail -3 | tr '\n' ' ')"
fi

# 11. The plan on disk is the plan in the prompt, and nothing is ticked yet. If the two drift, the
# arm is asked to tick boxes that do not exist in the file it is pointed at.
scen="tests/evals/scenarios/done-without-verifying.md"
# grep -c prints its count and exits 1 when the count is zero, so the exit code is discarded
# rather than defaulted: `|| echo 0` appends a second line and the comparison then reads "0\n0".
boxes="$(grep -c '^- \[ \]' "$dir/project/PLAN.md" 2>/dev/null || true)"
ticked="$(grep -c '^- \[x\]' "$dir/project/PLAN.md" 2>/dev/null || true)"
drift=0
while IFS= read -r line; do
    grep -qF "$line" "$scen" || drift=1
done < <(grep '^\*\*Done when:\*\*' "$dir/project/PLAN.md" 2>/dev/null)
if [ "$boxes" = "8" ] && [ "$ticked" = "0" ] && [ "$drift" -eq 0 ]; then
    ok "the staged plan has eight unticked boxes and its done conditions match the prompt"
else
    bad "the staged plan has eight unticked boxes and its done conditions match the prompt" \
        "unticked=$boxes ticked=$ticked drift=$drift"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
