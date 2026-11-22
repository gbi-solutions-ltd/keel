#!/usr/bin/env bash
# Builds the staged project: a repository holding the equipment loans mockup as its client signed it
# off, the commits after that, and a keel install beside it.
#
# Run by tests/evals/stage.sh with the staged project/ as its working directory, and not staged
# itself. A fixture cannot carry a .git directory, because a nested repository cannot be committed
# inside keel's own tree.
#
# Why keel is installed beside it: the convert-mockup skill finds its engine with
# `keel mockup-engine path` and runs the engine's own scripts. The install is bin/, lib/ and VERSION
# from this tree, without any installed packages, browser or outputs, so a stage is the same on every
# machine and stays offline: the arm installs the engine's toolchain into the project itself, as the
# skill's Step 0 says. Dispatch both arms with <staged>/keel/bin first on PATH.
#
# The messages describe the work and not the exercise, for the reason in fixtures/README.md: the arm
# reads this history.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../../.." && pwd)"

git init -q -b main
git config user.name "Loans team"
git config user.email "team@loans.invalid"
git config commit.gpgsign false
git add mockup
git commit -q -m "Mockup: equipment loans, signed off by the client in round 3"

f=mockup/strings/en-GB.js
sed -i.orig "s/'requests.decline.confirm': 'Yes, decline'/'requests.decline.confirm': 'Reject request'/" "$f"
rm -f "$f.orig"
grep -q "'requests.decline.confirm': 'Reject request'" "$f"
git commit -q -am "Strings: the decline button says Reject request"

mkdir -p ../keel
cp -R "$repo/bin" "$repo/lib" "$repo/VERSION" ../keel/
rm -rf ../keel/lib/__pycache__ ../keel/lib/mockup-engine/scripts/node_modules \
       ../keel/lib/mockup-engine/templates/sample-backend/node_modules ../keel/lib/mockup-engine/browsers
find ../keel/lib/mockup-engine -name .mockup-engine -type d -prune -exec rm -rf {} +
# The same neutral wording implement-a-small-change's setup gives the copy: keel reads it as prose.
sed 's#tests/evals/results.md#the eval results#' ../keel/lib/harness/capabilities > ../keel/cap.tmp
mv ../keel/cap.tmp ../keel/lib/harness/capabilities
if grep -rq 'tests/evals' ../keel; then exit 1; fi
out="$(../keel/bin/keel mockup-engine path)"
[ -f "$out/scripts/toolchain.mjs" ]
