#!/usr/bin/env bash
# Assemble an eval prompt: the scenario's pressure prompt plus the skills it injects.
# Prints to stdout. Dispatching and scoring are done by an agent, deliberately.
#
# The prompt is only valid dispatched from stage.sh's <dir>/project/. Where a scenario injects a
# skill with references, the prompt names them at ../skills/<skill>/references/, and only stage.sh
# puts them there. Printing it here to read is fine; dispatching it from anywhere else points the
# arm at a path that does not exist.
#
# Usage: tests/evals/run.sh <scenario-name>

set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

name="${1:-}"
f="tests/evals/scenarios/$name.md"
[ -f "$f" ] || { printf 'no such scenario: %s\n\navailable:\n' "$name" >&2
                 find tests/evals/scenarios -name '*.md' -exec basename {} .md \; | sed 's/^/  /' >&2
                 exit 1; }

# Skills to inject, from the scenario's "Inject:" line.
skills=$(sed -n 's/^Inject: *//p' "$f")

# The framing and the separator are printed only when there is something to separate. A scenario
# whose arm is a subagent injects no skill, because an implementer or a reviewer receives a prompt
# and nothing else, and announcing a skill that is not there is a sentence the arm can see is false.
# With no Inject line the assembled prompt is the pressure prompt, which is also what the README's
# baseline recipe produces by hand.
if [ -n "$skills" ]; then
    printf 'You have the following skill available. Follow it.\n\n'
    for s in $skills; do
        printf '=== SKILL: %s ===\n' "$s"
        cat "skills/$s/SKILL.md"
        printf '\n'
    done
    # Where the staged references are, from the arm's working directory. stage.sh puts them at
    # <staged>/skills/<skill>/references/ and the arm runs in <staged>/project, so this path is a
    # promise this script makes and stage.sh keeps. Case 26 of tests/test-eval-harness.sh pins both
    # halves, because a path named here and not staged is worse than no path at all.
    #
    # Only for skills that have one. Pointing an arm at a directory that does not exist teaches it
    # the instruction is unreliable, and the links inside the injected SKILL.md are relative to the
    # skill directory, so they resolve nowhere from project/ without this line.
    for s in $skills; do
        [ -d "skills/$s/references" ] || continue
        # shellcheck disable=SC2016
        # The backticks are markdown, wrapping a path for the reader, and there is nothing here for
        # the shell to expand. Single quotes are what keep the format string literal, which is
        # exactly what SC2016 warns about and exactly what is wanted.
        printf 'The reference files %s links are on disk at `../skills/%s/references/`. Read one when the skill tells you to.\n\n' "$s" "$s"
    done
    printf '=== TASK ===\n\n'
fi
# Everything after the PROMPT marker is the pressure prompt.
sed -n '/^## Prompt$/,$p' "$f" | tail -n +2
