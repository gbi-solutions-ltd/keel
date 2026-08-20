#!/usr/bin/env bash
# Makes the staged copy a real git repository: one commit holding everything the fixture ships, on a
# feature branch off main.
#
# Run by tests/evals/stage.sh with the staged project/ as its working directory, and not staged
# itself. A fixture cannot carry a .git directory, because a nested repository cannot be committed
# inside keel's own tree, and this scenario is scored on git state.
#
# The identity and the signing setting are local to this repository so the commit does not depend on
# whoever ran the stage having a usable global git config.

set -euo pipefail

git init -q -b main
git config user.name "Payouts CI"
git config user.email "ci@payouts.invalid"
git config commit.gpgsign false
git add .
git commit -q -m "chore: the payout service as it stands"
git checkout -q -b feat/payout-reference
