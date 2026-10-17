#!/usr/bin/env bash
# Makes the staged copy a git repository with `main` checked out and a clean tree, and puts a keel
# install beside it.
#
# Run by tests/evals/stage.sh with the staged project/ as its working directory, and not staged
# itself. A fixture cannot carry a .git directory, because a nested repository cannot be committed
# inside keel's own tree.
#
# Why it is a repository on `main`. The short path asks for a new branch when the work starts on the
# default branch, and that is one of the things the scenario scores. With no repository there is no
# branch to be on, and the git state that shows whether the arm wrote code or committed is gone.
#
# Why keel is installed beside it. The short path runs `keel plan risk` over the files it names and
# `keel plan status` over the plan it writes, and with no `keel` it reads the change as sensitive
# and refuses, which is right and is not this scenario. The install is bin/, lib/ and VERSION copied
# from this tree to <staged>/keel/, beside project/ for the reason the staged references are: it is
# not a file the arm finds in the repository it is working on. Both arms are dispatched with
# <staged>/keel/bin first on PATH, so the baseline has the same tools. A keel that cannot run here
# fails the stage, rather than staging an arm that is scored on a refusal nobody asked for.
#
# The message describes the code and not the exercise, for the reason in fixtures/README.md: the arm
# reads this history. The identity and the signing setting are local to this repository so the
# commit does not depend on whoever ran the stage having a usable global git config.

set -euo pipefail

git init -q -b main
git config user.name "Payouts CI"
git config user.email "ci@payouts.invalid"
git config commit.gpgsign false
git add .
git commit -q -m "feat: payout receipts with formatted amounts and signed links"

repo="$(cd "$(dirname "$0")/../../../.." && pwd)"
mkdir -p ../keel
cp -R "$repo/bin" "$repo/lib" "$repo/VERSION" ../keel/
rm -rf ../keel/lib/__pycache__
# One data line of the install names this repository's eval results file. A staged file that
# names it tells the arm it is inside an eval, which tests/test-eval-harness.sh case 4 forbids, so
# the copy's wording is neutral. keel reads that field as prose and nothing here depends on it.
sed 's#tests/evals/results.md#the eval results#' ../keel/lib/harness/capabilities > ../keel/cap.tmp
mv ../keel/cap.tmp ../keel/lib/harness/capabilities
if grep -rq 'tests/evals' ../keel; then exit 1; fi
../keel/bin/keel plan risk src/format.sh tests/test-format.sh | grep -qx 'loop: light'
