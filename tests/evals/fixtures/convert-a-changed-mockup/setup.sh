#!/usr/bin/env bash
# Builds the staged project: a repository holding the equipment loans mockup, with one string changed
# since the client's last sign-off round, and a keel install beside it.
#
# --as-signed leaves the string as the client signed it off, which is the control
# (convert-with-the-check-disabled): the same project and engine, with nothing changed since sign-off.
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
# One commit, with a message that describes the work and not the exercise, for the reason in
# fixtures/README.md: the arm reads this history, and a sign-off commit with a change on top of it
# gives the change away without the readiness check.
#
# The changed string is a hint no screen step or behaviour clicks or reads, so the sign-off
# comparison is the only thing either readiness check reports.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../../.." && pwd)"
as_signed=0
[ "${1:-}" = --as-signed ] && as_signed=1

f=mockup/strings/en-GB.js
key="'requests.decline.reason.hint'"
grep -q "^  $key: 'Shown to the person who asked. Up to {max} characters.',\$" "$f"
if [ "$as_signed" = 0 ]; then
  sed -i.orig "s/^  $key: 'Shown to the person who asked\. /  $key: 'The person who asked sees this. /" "$f"
  rm -f "$f.orig"
  grep -q "^  $key: 'The person who asked sees this. Up to {max} characters.',\$" "$f"
fi

git init -q -b main
git config user.name "Loans team"
git config user.email "team@loans.invalid"
git config commit.gpgsign false
git add mockup
git commit -q -m "Mockup: equipment loans"

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
