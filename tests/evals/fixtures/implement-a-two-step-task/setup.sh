#!/usr/bin/env bash
# Builds the payouts repository from implement-a-small-change's fixture: one commit holding
# everything that fixture ships, on a branch off main, with a clean tree. No plan is committed
# and no keel is installed.
#
# Run by tests/evals/stage.sh with the staged project/ as its working directory, and not staged
# itself. A fixture cannot carry a .git directory, because a nested repository cannot be committed
# inside keel's own tree, and this scenario is scored on git state.
#
# Why it reuses the other fixture. The scenario and its twin, implement-a-five-step-task, run on one
# project, so a change to implement-a-small-change cannot leave the task in the prompt describing
# code that is not there, and the two cannot drift onto different projects.
#
# Why there is no plan. The task is pasted into the prompt. A plan on disk would be a second copy an
# arm could read instead of the one it was given.
#
# Why there is no keel. The arm is dispatched with the prompt and nothing else, and a keel beside
# the project is a tool the prompt does not mention.
#
# Why the branch is not `main`. The profile says `main` is the default branch and standards.md says
# never to commit to it, so on `main` the arm has a reason to stop that has nothing to do with the
# work. The branch is the one run-a-short-path-plan uses.
#
# The message describes the code and not the exercise, for the reason in fixtures/README.md: the arm
# reads this history. The identity and the signing setting are local to this repository so the
# commit does not depend on whoever ran the stage having a usable global git config.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../implement-a-small-change"

cp -R "$src/." .
rm -f setup.sh

git init -q -b main
git config user.name "Payouts CI"
git config user.email "ci@payouts.invalid"
git config commit.gpgsign false
git add .
git commit -q -m "feat: payout receipts with formatted amounts and signed links"
git switch -q -c feat/currency-code
