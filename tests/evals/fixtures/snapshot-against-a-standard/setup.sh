#!/usr/bin/env bash
# Makes the staged copy a real git repository whose history has a before and an after.
#
# Run by tests/evals/stage.sh with the staged project/ as its working directory, and removed from
# project/ before it runs, so the arm never sees this file or these comments.
#
# Commit 1 is the point the document was derived from: the money and payout modules as they stood.
# Commit 2 adds the document, pinned to commit 1's sha, and two functions written after it. Both new
# functions breach a rule the document states, which is what gives the assessment something true to
# find, and both land after the derivation commit, which is what makes the pre-derivation proportion
# a real number rather than a formality.
#
# The commit messages describe the code and not the exercise, per fixtures/README.md: the arm reads
# this history, and a message naming the breach hands over the finding.
#
# Identity and signing are set locally so the commit does not depend on whoever ran the stage.

set -euo pipefail

git init -q -b main
git config user.name "Payouts CI"
git config user.email "ci@payouts.invalid"
git config commit.gpgsign false

git add src tests .keel docs/decisions
git commit -q -m "feat: submit a payout and read its status"
derived=$(git rev-parse --short HEAD)

cat >> src/payouts.sh <<'FN'

settle_payout() {
    local amount_minor="$1" fee_rate="$2"
    log info "settling"
    awk -v a="$amount_minor" -v r="$fee_rate" 'BEGIN { printf "%.4f\n", (a * r) / 100 }'
    return 0
}

receipt_line() {
    local amount_minor="$1"
    printf '%s settled %s\n' "$(date '+%d/%m/%Y %H:%M')" "$(from_minor "$amount_minor")"
}
FN

sed -i.bak "s/DERIVED_SHA/$derived/" docs/standards.md
rm -f docs/standards.md.bak

git add docs src/payouts.sh
git commit -q -m "feat: settle a payout at a fee rate and print a receipt line"
