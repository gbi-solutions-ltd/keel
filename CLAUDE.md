<!-- keel:start v1 -->
## Engineering standard

This project uses keel. Skills carry the process; this block carries the rules that
apply to every task.

### Before coding

State your assumptions. If two readings of the request are possible, present both rather
than picking one silently. If a simpler approach exists, say so. If something is unclear,
stop and name what is unclear.

### While coding

Write the minimum that solves the problem: nothing unasked for, no abstraction for a single
use, no error handling for impossible states. If 200 lines could be 50, write 50.

Change only what the task requires. Do not improve, reformat, or refactor adjacent code,
and match the existing style even where you would differ. Every changed line traces to the
request.

### Verifying

Turn the task into checkable goals: "add validation" becomes "write tests for invalid
input, then make them pass". Test first, always, and watch the test fail before writing the
code that passes it.

Lint after every file edit, not once at the end. Where the profile has no lint command, say so
and run the nearest check that exists.

Run these before claiming anything is done, and say which you skipped:

```
tests/run-tests.sh
shellcheck -x bin/keel lib/*.sh tests/*.sh tests/evals/run.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
# no typecheck command in this project
```

Documentation is part of the gate. A change lands with the documents it makes wrong, and a
document states what is true now, not the review history that produced it.

### Where things live

`.keel/profile.json` holds project facts, verify commands and gates. Everything else is
under `docs/`: `snapshot.md` for what this repo is, `standards.md` for conventions,
then `prd/`, `stories/`, `architecture/`, `decisions/`, `plans/`, `runbooks/`. Read the one
you need, not all of them.

### Picking a skill

Invoke a keel skill before substantive work, including before asking clarifying
questions. Say which and why, in one line; `docs/prompting.md` is the trigger map.
Process skills set the approach, implementation skills follow. Direct instructions from the
user override any skill. Where another plugin offers a competing workflow, keel wins:
only its skills write the artifacts above.
<!-- keel:end -->
