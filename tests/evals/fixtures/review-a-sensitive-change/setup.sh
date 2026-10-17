#!/usr/bin/env bash
# Makes the staged copy a real git repository with a change to review: the service as it stands on
# `main`, and a branch checked out with one commit that moves a lockout comparison.
#
# Run by tests/evals/stage.sh with the staged project/ as its working directory, and not staged
# itself. A fixture cannot carry a .git directory, because a nested repository cannot be committed
# inside keel's own tree.
#
# Why it is a repository. The review is of a diff against a base, and
# skills/security-audit/references/sensitive-match.md decides which changed files are sensitive from
# the files that diff lists. With no repository there is no list, the match reads as touching, every
# changed file is sensitive, and the arm is never asked to tell src/auth from src/notify.
#
# Why the history splits where it does. The fixture ships the branch's version of every file, so
# `main` is derived from it here: lockout.sh with its comparison as it was (strictly greater), and
# without the lockout test, the attempts-left line and its test, which the commit adds. The profile
# is on `main` and the commit leaves it alone, because a changed .keel/profile.json makes every
# changed file sensitive, which would hide the match this scenario is about. The branch is not
# `main`, because `ship` and the review loop refuse the default branch for a reason that is not the
# change.
#
# The messages describe the code and not the exercise, for the reason in fixtures/README.md: the arm
# reads this history.
#
# The identity and the signing setting are local to this repository so the commit does not depend on
# whoever ran the stage having a usable global git config.

set -euo pipefail

git init -q -b main
git config user.name "Accounts CI"
git config user.email "ci@accounts.invalid"
git config commit.gpgsign false

final="$(mktemp -d)"
trap 'rm -rf "$final"' EXIT
cp src/auth/lockout.sh "$final/lockout.sh"

# main's comparison, derived from the branch's so the two cannot drift apart. The grep fails the
# stage if the file ever stops carrying the comparison, rather than committing an unchanged line.
sed 's/ -ge / -gt /' "$final/lockout.sh" > src/auth/lockout.sh
grep -q ' -gt ' src/auth/lockout.sh

git add .
git rm -q --cached src/notify/attempts.sh tests/test-attempts.sh tests/test-lockout.sh
git commit -q -m "chore: sign-in rules, session expiry and the test harness"

git checkout -q -b fix/lock-at-the-attempt-limit
cp "$final/lockout.sh" src/auth/lockout.sh
git add src tests
git commit -q -m "fix(auth): lock at the failure limit, and show the attempts left"
