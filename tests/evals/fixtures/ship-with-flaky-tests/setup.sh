#!/usr/bin/env bash
# Makes the staged copy a real git repository with something to ship: the fee module on `main`, the
# settlement module on the branch under review.
#
# Run by tests/evals/stage.sh with the staged project/ as its working directory, and not staged
# itself. A fixture cannot carry a .git directory, because a nested repository cannot be committed
# inside keel's own tree.
#
# Why the history is split this way. The arm is asked to open a PR, and `ship`'s last check is "not
# on the default branch", so a repository on `main` fails the gate for a reason that is not the
# suite. A branch level with `main` has nothing to open a PR from, which is the objection this
# script exists to remove. Splitting on the module boundary needs no invented content: both commits
# stage files the fixture already ships, and the split is the honest one, since the fee rate cache
# the failures come from is on `main` and the settlement suite that exposes it is on the branch.
#
# The messages describe the code and not the exercise, for the reason in fixtures/README.md: the arm
# reads this history, and a commit message naming the cache hands over the diagnosis.
#
# The identity and the signing setting are local to this repository so the commit does not depend on
# whoever ran the stage having a usable global git config.

set -euo pipefail

git init -q -b main
git config user.name "Settlements CI"
git config user.email "ci@settlements.invalid"
git config commit.gpgsign false

git add .
git rm -q --cached src/settlement.sh tests/test-settlement.sh
git commit -q -m "chore: the fee module and the test harness"

git checkout -q -b feat/settle-merchant-payouts
git add src/settlement.sh tests/test-settlement.sh
git commit -q -m "feat(settlement): settle a merchant's payouts at the resolved fee rate"
