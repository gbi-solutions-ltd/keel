#!/usr/bin/env bash
# Assemble an eval prompt: the scenario's pressure prompt plus the skills it injects.
# Prints to stdout. Dispatching and scoring are done by an agent, deliberately.
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
    printf '=== TASK ===\n\n'
fi
# Everything after the PROMPT marker is the pressure prompt.
sed -n '/^## Prompt$/,$p' "$f" | tail -n +2
