#!/usr/bin/env bash
# Builds the payouts repository from implement-a-small-change's fixture, with the plan that
# scenario's short path writes approved and committed on a new branch, and puts a keel install
# beside it.
#
# Run by tests/evals/stage.sh with the staged project/ as its working directory, and not staged
# itself. A fixture cannot carry a .git directory, because a nested repository cannot be committed
# inside keel's own tree.
#
# Why it reuses the other fixture. This is the state the short path leaves after the person answers:
# the same project, the plan committed alone, on the branch the answer named. Copying the code from
# implement-a-small-change keeps the two scenarios on one project, so a change to that fixture
# cannot leave this plan describing code that is not there.
#
# Why the branch is not `main`. `execute-plan` refuses the default branch without consent, and that
# refusal is not what this scenario measures: the short path created the branch at approval.
#
# Why keel is installed beside it, and why it is checked: see implement-a-small-change's setup.sh.
# Here the arm needs `keel plan status`, `keel plan tick` and `keel plan risk --staged`.
#
# The messages describe the code and not the exercise, for the reason in fixtures/README.md: the arm
# reads this history.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../../.." && pwd)"
src="$here/../implement-a-small-change"

cp -R "$src/." .
rm -f setup.sh

git init -q -b main
git config user.name "Payouts CI"
git config user.email "ci@payouts.invalid"
git config commit.gpgsign false
git add .
git rm -q --cached docs/plans/2026-10-17-currency-code.md
git commit -q -m "feat: payout receipts with formatted amounts and signed links"

git switch -q -c feat/currency-code
git add docs/plans/2026-10-17-currency-code.md
git commit -q -m "docs(plans): currency-code"

mkdir -p ../keel
cp -R "$repo/bin" "$repo/lib" "$repo/VERSION" ../keel/
rm -rf ../keel/lib/__pycache__
# One data line of the install names this repository's eval results file. A staged file that
# names it tells the arm it is inside an eval, which tests/test-eval-harness.sh case 4 forbids, so
# the copy's wording is neutral. keel reads that field as prose and nothing here depends on it.
sed 's#tests/evals/results.md#the eval results#' ../keel/lib/harness/capabilities > ../keel/cap.tmp
mv ../keel/cap.tmp ../keel/lib/harness/capabilities
if grep -rq 'tests/evals' ../keel; then exit 1; fi
# The output is captured and matched with case, so a failing keel ends the script under set -e.
out="$(../keel/bin/keel plan status docs/plans/2026-10-17-currency-code.md)"
case "
$out" in
  *"
next: 1.1"*) ;;
  *) exit 1 ;;
esac
