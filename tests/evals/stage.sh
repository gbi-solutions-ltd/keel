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
#   <dir>/skills/<skill>/references/
#                     the references of every skill the scenario injects, beside the working
#                     directory rather than inside it, so `../skills/<skill>/references/` resolves
#                     from project/ and the arm has to choose to read one
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

# The references of every skill this scenario injects, staged beside project/ rather than inside it.
#
# An arm's working directory is project/, and until 2026-09-02 the staged tree held nothing else, so
# a skill body pointing at references/ pointed at nothing an arm could open. tests/evals/results.md
# recorded that on 2026-09-01 as the single most useful thing that run surfaced about the eval setup.
#
# Staged rather than injected into the prompt on purpose: injected text measures whether a reference
# is obeyed when the model already has it, and the question worth asking is whether it goes and reads
# it. Only the second can fail, so only the second is a test.
#
# Beside project/ for the same reason prompt.md and setup.sh are kept out of it. A skills/ directory
# inside the project is a file the arm would find lying around in the repository it is working on,
# and it would end up in the first commit of any scenario scored on git state.
# Assigned first and then split, which is run.sh:18-26's idiom for the same line and avoids
# SC2013: the splitting is wanted, because `Inject: execute-plan tdd` names two skills.
inject_skills=$(sed -n 's/^Inject: *//p' "$f")
for s in $inject_skills; do
    [ -d "skills/$s/references" ] || continue
    mkdir -p "$dir/skills/$s" || { rm -rf "$dir"; exit 1; }
    cp -R "skills/$s/references" "$dir/skills/$s/" || { rm -rf "$dir"; exit 1; }
done

# A fixture that needs more than files carries a setup.sh, run here with the staged project/ as its
# working directory. Three scenarios need it: a fixture cannot ship a .git directory, because a
# nested repository cannot be committed inside this one, so a scenario scored on git state has to
# build the repository at staging time. Its output goes to stderr, because stdout is the path this
# script returns.
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
