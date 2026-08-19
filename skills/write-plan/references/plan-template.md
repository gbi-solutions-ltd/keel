# Plan template

The structure of `<docs_root>/plans/YYYY-MM-DD-<slug>.md`. Adapted closely from superpowers'
`writing-plans`, with the verify commands read from `.keel/profile.json` and tasks traced to
story IDs.

## Header

Every plan starts with this. The banner is not decoration: a plan is often opened by an agent
that has loaded nothing else.

```markdown
# <Feature> Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness, or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** one sentence.
**Stories:** S-08, S-14
**ADRs:** ADR-0003
**Architecture:** two or three sentences on the approach.

## Global constraints

Copied verbatim from the stories, ADRs, and profile. Every task inherits these.

- Verify commands: test `npm test`, one test `npm test -- {path}`, lint `npm run lint`
- Never start on `main`
- ADR-0003 requires that a missing or empty credential fails startup

---
```

Copy the constraints in full rather than linking. A task executed by a fresh agent that reads
only its own section must still obey them.

## Task shape

````markdown
### Task 3: Reject an empty credential at startup

**Story:** S-08
**Files:**
- Modify: `src/main/java/com/example/config/SecurityProperties.java`
- Test: `src/test/java/com/example/config/SecurityPropertiesTest.java`

**Interfaces:**
- Consumes: `SecurityProperties.apiKeys` (List<String>), defined in task 2
- Produces: nothing new; adds validation to an existing type

**Depends on:** task 2

**Done when:** `./gradlew test --tests '*SecurityPropertiesTest'` passes and the full suite is green.

- [ ] **Step 1: Write the failing test**

```java
@Test
void emptyApiKeysFailsStartup() {
    assertThatThrownBy(() -> context.getBean(SecurityProperties.class))
        .hasMessageContaining("apiKeys");
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./gradlew test --tests '*SecurityPropertiesTest'`
Expected: FAIL, "expected an exception but none was thrown"

- [ ] **Step 3: Write the minimal implementation**

```java
@NotEmpty(message = "apiKeys must not be empty")
private List<String> apiKeys;
```

- [ ] **Step 4: Run it and watch it pass**

Run: `./gradlew test --tests '*SecurityPropertiesTest'`
Expected: PASS. Then run the full suite; nothing else may break.

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/example/config/SecurityProperties.java \
        src/test/java/com/example/config/SecurityPropertiesTest.java
git commit -m "fix(config): reject an empty apiKeys at startup"
```
````

### Why the Interfaces block exists

A task's implementer may see only their own section. `Consumes` tells them the exact signatures
earlier tasks produced; `Produces` tells later tasks what to expect. Without it, task 7 invents
a name for something task 3 already built, and the two never meet.

Omit the block only when a task genuinely touches nothing shared.

### Why the Depends on line exists

It is what lets `execute-plan` run tasks concurrently, and it is required on every task. Write
`none` where a task depends on nothing; an absent line is not the same as `none` and is read as
the second case below.

The line is not redundant with `Consumes`. A run asked to execute a five-task plan as fast as it
reasonably could worked out for itself that three leaf tasks had disjoint `Files` and no
`Consumes` entries, and still refused to overlap them, correctly:

> "Inferring parallelism from the absence of a `Consumes:` line is an inference; a plan that
> intends it should say it, because absence of a line is also what an incompletely-written task
> looks like."

So a plan earns concurrency by declaring it. `Depends on:` names task numbers, and it covers
ordering that `Consumes` cannot see: a migration that must land before a task that queries the
column, a config key written by one task and read by another, a task that must not start until a
credential exists.

### Tasks that run concurrently

Where a plan has a batch of tasks that all say `Depends on: none`, or whose dependencies are all
already complete, and no two of them name the same file anywhere in their `Files` blocks, say so
in the header:

```markdown
**Concurrent batches:** tasks 1, 2 and 3 may run at the same time. Task 4 requires all three.
Task 5 requires task 4.
```

**Disjoint files and declared dependencies are necessary and not sufficient.** Three more rules
apply to every task in a concurrent batch, and each exists because the same baseline run predicted
the failure in concrete terms:

1. **Scope the `Done when:` to the task's own test.** `**Done when:** node --test test/format.test.js
   passes.` and nothing about the full suite. The suite gate moves to the join, as its own line in
   the header: `**Batch gate:** after tasks 1 to 3 land, node --test test/ is green.` A whole-suite
   `Done when:` inside a batch cannot pass, because task 2's step 1 writes a failing test on
   purpose while task 1 is running: *"even with perfect isolation of source files, three concurrent
   agents each waiting for a green whole-suite cannot all pass."*
2. **Commit named paths only.** The commit step lists every path explicitly and never uses
   `git add -A` or `git commit -a`, which otherwise sweeps in a sibling's half-written files and
   produces *"a commit labelled 'format' containing a half-written SMS module"*.
3. **Touch no shared config.** A task in a batch that would create or edit a lockfile, a linter
   config, a CI file, or the profile is not eligible for the batch. Two agents each deciding the
   lint command needs a config file will each write one.

The failure these prevent is not a lost race. It is quieter: with a sibling's failing test in the
suite, every agent's step 2 sees red for the wrong reason and ticks the box, so *"the TDD gate
silently stops proving anything"*.

Where any of the three cannot hold, the tasks are sequential. Say so rather than declaring a batch
and hoping.

### Why the Done when line exists

`Done` is otherwise an adjective the implementer applies to their own work. The line names the
command a reviewer would run and the result they would see, which turns it into something a third
party can check without reading the diff.

Rules:

- It is a **command from `profile.verify` plus its expected result**, not a description. "The
  validation works" is not a done condition. "`npm test -- payouts` passes" is.
- Where a task genuinely has no command, the line says so in the same place, the way the no-test
  tasks below do: `**Done when:** there is no command. This is a human check against the staging
  environment.` An honest gap reads as a gap. An invented command reads as coverage.
- It appears once per task, above the steps, so a fresh agent dispatched only that section still
  receives it.

## Step granularity

Each step is one action, two to five minutes:

- Write the failing test
- Run it and watch it fail
- Write the minimal code
- Run it and watch it pass
- Commit

Steps 2 and 4 are not ceremony. A test you did not watch fail may be asserting nothing, and a
plan that omits the failure check produces suites that are green because they test nothing.

### A step somebody else already did

Most plans are resumed, so the common case is arriving at a task whose first steps are already
satisfied. The banner's rule covers it: tick with a note, or leave it and report. The distinction
that matters is *witnessed here* against *believed done*, not *done* against *not done*, because a
silent tick leaves the plan asserting that a failing test was watched failing in a session where
nobody watched anything.

## Task granularity

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's
gate.

**Fold in:** setup, config, scaffolding, and documentation belonging to that deliverable.
**Split when:** a reviewer could reject one half while approving the other.

Ten tasks of one step each is not a plan, it is a checklist with extra headings. One task with
forty steps cannot be reviewed.

## Planning by story kind

| Story kind | Task 1 is | Then |
|---|---|---|
| `build` | The failing test for new behaviour | Implement |
| `verify` | A test for behaviour believed correct | If it passes, done. If it fails, the story becomes `fix` and needs new tasks |
| `fix` | A test reproducing the defect | Fix at the root cause |
| `decide` | **Not a plan.** Route it to `design-architecture` for an ADR | No code |

The `verify` row matters most in an existing codebase. Planning a `verify` story as if it were
`build` rewrites working software.

## No placeholders

Every one of these moves a decision from the planner to someone with less context:

- "TBD", "implement later", "fill in details"
- "Add appropriate error handling", "handle edge cases", "add validation"
- "Write tests for the above", without the test
- "Similar to Task 3", instead of repeating the code. Tasks are read out of order
- Any type or function no task defines

If you cannot write the code for a step, the plan is not finished. Say what is blocking it and
put it in an open questions section rather than hiding it behind a phrase.

Then ask it. A blocker recorded in an open questions section stops `execute-plan` before it
starts, so a question you could have settled in one exchange costs a whole cycle instead. Put it
to the user as a choice, following
[../../keel/references/asking-questions.md](../../keel/references/asking-questions.md).

## Commands come from the profile

Every `Run:` line uses a command from `.keel/profile.json`. Do not guess, and do not use the
idiomatic command for the stack: a project's actual test command is frequently not the obvious
one. Where the profile has `null`, say so in the task rather than substituting a guess.

**On a greenfield project every verify command is `null`, and saying so is not enough.** There is no
test command because there is no project, and no task after the first can run anything until one
exists. Admitting the gap in each task would leave every step 2 and step 4 unrunnable, which is a
plan that cannot be executed.

So **task 1 creates the toolchain and writes the commands into the profile**, ending with
`keel profile set verify.test ...` for each and a `keel doctor` that must pass. State the commands
it will create in the plan's global constraints, so every later task inherits a real command rather
than a promise. Task 1's own step 2 watches the test command fail because the toolchain is absent,
which is a real failure and the honest one to watch.

That task satisfies no story and is infrastructure. Say so in it, rather than inventing a story for
it to trace to.

## Tasks with no test

Some tasks genuinely cannot be tested: a human check against deployed environments, a rotation
that touches a partner, a decision recorded as a runbook entry. A plan may contain one, and it
**must say so explicitly** rather than inventing a test to fill the shape.

```markdown
- [ ] **Step 1: There is no test for this**

This task is a human check. It cannot be automated because it requires reading configuration
from environments this repository cannot see.
```

The failure mode this prevents is a fabricated test that passes without checking anything, which
is worse than an honest gap because it reads as coverage.

## Self-review

1. Every story in scope maps to at least one task.
2. No placeholder phrases survive.
3. Names used in later tasks match what earlier tasks defined.
4. Every **verifying** command comes from `profile.verify`. Investigative commands (`grep`,
   `git log`, `ls`) need no entry, and demanding one makes the check reject correct plans.
5. Every task ends with a commit step.
6. No task depends on a file no task creates.

Fix inline. Then report coverage and hand off.
