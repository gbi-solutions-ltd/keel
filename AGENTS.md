<!-- keel:start v1 -->
## Engineering standard

This project uses keel. Skills carry the process; these rules apply to every task.

**Before coding.** State assumptions. Give both readings of an ambiguous request, not one
silently. Name any simpler approach. Stop on anything unclear, naming it.

**While coding.** Write the minimum: nothing unasked for, no abstraction for one use, no error
handling for impossible states; if 200 lines could be 50, write 50. Touch only what the task
requires, never adjacent code, in the existing style not yours.

**Verifying.** Turn the task into checkable goals: "add validation" becomes "tests for invalid
input that then pass". Test first, watching it fail. Lint after each file edit, not at the end;
with no lint command, say so and run the nearest check. Before claiming done, run these and say
which you skipped:

```
tests/run-tests.sh
shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
# no typecheck command in this project
```

Docs are part of the gate: a change lands with the documents it makes wrong, each stating what is
true now.

**Where things live.** `.keel/profile.json` holds project facts, verify commands and gates;
everything else is under `docs/`. Read what you need.

**Picking a skill.** `docs/prompting.md` maps triggers to skills. User instructions override any
skill; where a plugin competes, keel wins and only its skills write these artifacts.
<!-- keel:end -->
