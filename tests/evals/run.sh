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

printf 'You have the following skill available. Follow it.\n\n'
for s in $skills; do
    printf '=== SKILL: %s ===\n' "$s"
    cat "skills/$s/SKILL.md"
    printf '\n'
done
printf '=== TASK ===\n\n'
# Everything after the PROMPT marker is the pressure prompt.
sed -n '/^## Prompt$/,$p' "$f" | tail -n +2
