#!/usr/bin/env bash
# Stage an eval dispatch in a directory OUTSIDE this repository. Prints that directory's path.
#
# Why this exists: an arm whose working directory is this repository can read
# tests/evals/scenarios/, which is the file describing how it will be scored. The 0.10.0 run caught
# one arm doing exactly that. The 0.11.0 run suppressed it by telling every arm not to run
# commands, and recorded that an instruction is not a fix, because the exposure was unchanged and
# the instruction is itself a difference in treatment between two runs. Staging outside the tree is
# the fix.
#
# Layout, and the reason for it:
#
#   <dir>/prompt.md   the assembled prompt, kept out of the working directory so it is not one of
#                     the files the arm finds lying around in the project it is working on
#   <dir>/project/    the arm's working directory: a scenario's fixture, or empty
#
# Usage: tests/evals/stage.sh <scenario-name>
#        dir=$(tests/evals/stage.sh done-without-verifying)
#        cd "$dir/project" && claude -p "$(cat ../prompt.md)"

set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
repo="$PWD"

name="${1:-}"
f="tests/evals/scenarios/$name.md"
[ -f "$f" ] || { printf 'no such scenario: %s\n\navailable:\n' "$name" >&2
                 find tests/evals/scenarios -name '*.md' -exec basename {} .md \; | sed 's/^/  /' >&2
                 exit 1; }

dir="$(mktemp -d "${TMPDIR:-/tmp}/keel-eval-XXXXXX")" || exit 1
case "$dir" in
    "$repo"/*) printf 'refusing to stage inside the repository: %s\nTMPDIR points into the tree, which is the exposure this script exists to close.\n' "$dir" >&2
               rm -rf "$dir"; exit 1 ;;
esac

mkdir -p "$dir/project" || exit 1
tests/evals/run.sh "$name" > "$dir/prompt.md" || { rm -rf "$dir"; exit 1; }

fixture="tests/evals/fixtures/$name"
if [ -d "$fixture" ]; then
    cp -R "$fixture/." "$dir/project/" || { rm -rf "$dir"; exit 1; }
fi

# A fixture that needs more than files carries a setup.sh, run here with the staged project/ as its
# working directory. One scenario needs it: a fixture cannot ship a .git directory, because a nested
# repository cannot be committed inside this one, so a scenario scored on git state has to build the
# repository at staging time. Its output goes to stderr, because stdout is the path this script
# returns.
#
# The script is not left in the working directory, for the reason prompt.md is not: it is not one of
# the files the arm should find lying around in the project it is working on, and a setup script that
# builds a repository would otherwise be in the first commit of it.
#
# A setup that fails takes the stage with it. Staging a half-built fixture and printing a path is the
# worse outcome: the arm runs, the result looks like a result, and nothing says the project it worked
# in was never finished.
if [ -f "$fixture/setup.sh" ]; then
    rm -f "$dir/project/setup.sh"
    ( cd "$dir/project" && bash "$repo/$fixture/setup.sh" ) >&2 \
        || { printf 'fixture setup failed (exit %d): %s\nstaged nothing; the scenario cannot be dispatched until it is fixed\n' \
                    "$?" "$fixture/setup.sh" >&2
             rm -rf "$dir"; exit 1; }
fi

printf '%s\n' "$dir"

# Guidance on stderr so `dir=$(stage.sh x)` still captures only the path.
cat >&2 <<GUIDE

Dispatch it from the staged working directory, never from this repository:

  cd $dir/project && claude -p "\$(cat ../prompt.md)"

A subagent spawned from a session whose working directory is this repository is NOT isolated: it
inherits that directory and can read the scenario's pass criteria. Stage once per arm, because two
arms sharing a directory race on the same files and the result looks fine either way.
GUIDE
