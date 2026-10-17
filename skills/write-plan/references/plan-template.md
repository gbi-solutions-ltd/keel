# Plan template

The structure of `<docs_root>/plans/YYYY-MM-DD-<slug>.md`. Drawn from superpowers'
`writing-plans`, with the verify commands read from `.keel/profile.json` and tasks traced to
story IDs. The task shape, behaviours with examples in place of test code, is keel's own.

## Header

Every plan starts with this. The banner is not decoration: a plan is often opened by an agent
that has loaded nothing else.

```markdown
# <Feature> Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** one sentence.
**Stories:** S-08, S-14
**ADRs:** ADR-0003
**Architecture:** two or three sentences on the approach.
**Implementer routing:** inherit
**Delivery:** hand-off

## Global constraints

Copied verbatim from the stories, ADRs, the standards document, and profile. Every task inherits
these.

- Verify commands: test `./gradlew test`, one test `./gradlew test --tests '{name}'`, lint
  `./gradlew check`
- Never start on `main`
- ADR-0003 requires that a missing or empty credential fails startup
- `<docs_root>/standards.md` requires a named exception type, never a bare catch

---
```

Copy the constraints in full rather than linking. A task executed by a fresh agent that reads
only its own section must still obey them.

**The routing line** takes `inherit` or `keel-implementer`, and the person approving the plan can
change it before `execute-plan` runs. `keel-implementer` fits where every task has a `Done when:`
command and concrete behaviours. A plan with any task touching `hard_block_paths` names `inherit`,
unless the person approving says otherwise.

**The delivery line** takes `hand-off` or `pull-request`. `hand-off` stops after each skill, as
before. `pull-request` runs through to an open pull request, stopping wherever
`skills/execute-plan/references/delivery.md` says. The person approving the plan chooses, and can
change the line before `execute-plan` runs: `execute-plan` reads the line from the plan and not from
the request, so the choice made at approval is the one a later session finds.

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

**Behaviours:**

1. An empty `apiKeys` list fails startup with a message naming `apiKeys`. Example: a context
   configured with `apiKeys: []` fails to start, and the message contains "apiKeys".

**Done when:** `./gradlew test --tests '*SecurityPropertiesTest'` passes.

- [ ] **Step 3.1: Write the failing test**

Write the test for behaviour 1 from its example, in `SecurityPropertiesTest`.

- [ ] **Step 3.2: Run it and watch it fail**

Run: `./gradlew test --tests '*SecurityPropertiesTest'`
Expected: FAIL, the case for behaviour 1 fails because startup succeeds

- [ ] **Step 3.3: Write the minimal implementation**

Make behaviour 1 pass: validate `apiKeys` in `SecurityProperties` so that an empty list fails
startup with a message naming `apiKeys`.

- [ ] **Step 3.4: Run it and watch it pass**

Run: `./gradlew test --tests '*SecurityPropertiesTest'`
Expected: PASS. The tests run at the unit boundary, not per step.

- [ ] **Step 3.5: Run the tests at the unit boundary, then hand over**

Run: `./gradlew test`. Where the profile sets `verify.test_affected`, run that instead, with
`{base}` filled with the start record's commit, or `verify.test` where `keel:tdd`'s affected-tests
reference says to. The task text overrides the skill, so a step naming only the suite would
schedule it for every task, and an affected run that never selected the unit's new test would pass
this step.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

```bash
git add src/main/java/com/example/config/SecurityProperties.java \
        src/test/java/com/example/config/SecurityPropertiesTest.java
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(config): reject an empty apiKeys at startup"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch, say
so and leave it unstaged.
````

### Why the implementer stages and the coordinator commits

**Nothing reaches shared history before both review passes.** That is the guarantee the whole
delegated design rests on, and a per-task commit run by the implementer breaks it: the commit lands
first and review can then only be acted on by rewriting history, which is not a gate.

Three things follow, and each closes a hole that was recorded before it was fixed:

- **The reviewer gets a diff that exists.** `git diff` in the working tree is exactly this task's
  change. [parallel-batches.md](../../execute-plan/references/parallel-batches.md) already records
  the other outcome, that a plain diff shows "nothing at all once each agent has committed, and an
  empty diff produces a confident COMPLIES over nothing".
- **A DEVIATES verdict costs nothing to act on.** The re-dispatch goes to a fresh subagent, and
  discarding an uncommitted working tree returns the tree to precisely the state the first subagent
  started from. With a commit already in, "fresh" is not true of the tree it arrives at.
- **Staging names the task's paths.** `git status --porcelain` in the report is how the coordinator
  sees a file the task never mentioned before it is committed rather than afterwards.

**The one exception is a declared concurrent batch**, whose tasks commit inside their own worktrees
(rule 2 under "Tasks that run concurrently"). Nothing enters the shared tree until the coordinator
merges each worktree back, after review, so the guarantee holds in both modes.

### Named paths only, in every task

**Never `git add -A`, `git add .` or `git commit -a`, in any task, batch or not.** The hand-over step
lists every path by name and stages those.

This used to be stated only for tasks in a concurrent batch, where, in one shared tree, the harm is
a sibling's half-written files being swept up. **Outside a batch the same rule is needed for a
different reason: a working tree that was already dirty when the run started.** Whatever was sitting
there uncommitted, someone's debugging edit, a half-finished experiment, gets swept into the first
task's commit and attributed to work that never touched it. A batch is not what makes `git add -A`
dangerous; a non-empty `git status` is, and that can be true on task 1 of a serial plan.

### Why the Interfaces block exists

A task's implementer may see only their own section. `Consumes` tells them the exact signatures
earlier tasks produced; `Produces` tells later tasks what to expect. Without it, task 7 invents
a name for something task 3 already built, and the two never meet.

**It is the one place a plan carries verbatim form.** Code, a signature or a data shape that
another task consumes goes here and nowhere else; the rest of a task says what it must do as
behaviours with examples.

Omit the block only when a task genuinely touches nothing shared.

### Why the Behaviours list exists

A plan that carried each task's test and implementation verbatim was a second copy of the code,
which the implementer then wrote again. Behaviours with examples say what must be true. The
implementer writes the tests from them, and the spec review checks that every example has its case.

**The risk taken is drift.** With no code to copy, an implementer can build something the plan did
not mean. Watch it as `rounds` and `rework` in `keel plan report`.

### Why the Depends on line exists

It is what lets `execute-plan` run tasks concurrently, and it is required on every task. Write
`none` where a task depends on nothing; an absent line is not the same as `none`: it is read as
unknown, and the task runs alone.

`keel plan batches` batches a task only when it can read this line exactly, so write it in one of
these forms and nothing else, bar an optional period at the end: `none`; `task 2`; `tasks 1 and 2`;
`tasks 1, 2 and 3` (any number of ids, with an optional comma before the `and`); or `tasks 1 to 3`
(every task from 1 to 3). For example:

```markdown
**Depends on:** tasks 1, 2 and 3
```

A task whose line is written another way, with a reason after it, a range as `1-3`, or a note in
parentheses, still runs, alone, because a guess at what it meant could put it beside a task it
depends on. Put the reason in the task's `Behaviours`, not on the line.

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

Write the plan in this order, because `keel plan batches` can only read tasks that are already
written, and a record that every task writes is what hides a batch from it:

1. Write the tasks with the shared records (`CHANGELOG.md`, `README.md`, the skill catalog) left out
   of any task that could run beside another, and a records task after them that depends on them.
   Every task writing the same record is what makes no two tasks disjoint: code tasks that each end
   in a `CHANGELOG.md` entry never batch, and one records task after them lets them. Write each
   task's `Depends on:` line and `Files` block in the strict form below, because a task written
   another way still runs, but alone.
2. Run `keel plan batches <plan>`. It reads each task's `Depends on:` and `Files` lines, prints the
   batches they allow, and gives a `why:` line for each task that could not join the step before it.
3. Declare in the header's `**Concurrent batches:**` line every batch it prints, unless a task in it
   cannot meet rules 1 and 2 below, in which case say which task; or write `none` followed by its
   `why:` lines. A batch it does not print is not declared, because it reads the same lines the
   batch rests on; a declared batch may be part of a printed one. The approver can only approve
   overlap they can see.
4. For each declared batch, scope each task's `Done when:` (rule 1), make its last step a commit
   (rule 2) and add the `**Batch gate:**` line, because the command cannot judge either and prints
   them only as a reminder.

The command batches a task only when both lines match their strict form exactly. For example:

```markdown
**Depends on:** tasks 1 and 2
**Files:**
- Create: `src/format.js` and `src/util.js`
- Modify (the export line only): `src/index.js`
- Test: `test/format.test.js`
```

`Depends on:` is `none`, `task 2`, `tasks 1 and 2`, `tasks 1, 2 and 3` or `tasks 1 to 3`. `Files` is
the label alone on its line, then one list item per action, `Create`, `Modify`, `Delete`, `Test` or
`Rename` (optionally with a note in parentheses before the colon, which must not name a file,
because the command cannot see a file named in prose), each followed by backticked paths separated
by commas with an optional final `and`. A long list may continue on an indented line when the line
before it ends in a comma or `and`. A path has letters, digits and `._-/@+` only: no space, `:`,
`#`, `*` or trailing `/`, and it does not start with `/` or `./` or hold `//`, since each of those
spells one file two ways. A rename names both paths, as
`` - Rename: `src/old.js` and `src/new.js` ``, and both count; written with ` to ` the task runs
alone, since only `and` is in the strict form. The block ends at the first blank line, and no list
item may follow that blank line before the next `**Label:**` line, nor an indented line, which would
continue the last item. A task written another way, with prose in the block, a note after a path, a
directory or a pattern, or a reason after the dependencies, still runs, alone, with a `why:` line
naming the label; to batch it, put the note in `Behaviours` and list the files. A list item
elsewhere in a task (a `Behaviours` or step item) whose first word is one of the five action words,
followed by ` (` or by a `:` later on the line, counts too and runs the task alone, so word those
another way; `Tests:` and `Created by:` are other words.

The header then reads:

```markdown
**Concurrent batches:** tasks 1, 2 and 3 may run at the same time. Task 4 requires all three.
Task 5 requires task 4.
```

**Disjoint files and declared dependencies are necessary and not sufficient.** Three more rules
apply to every task in a concurrent batch, because the same baseline run predicted the failure in
concrete terms, and a fourth keeps the files disjoint:

1. **Scope the `Done when:` to the task's own test.**
   `**Done when:** node --test test/format.test.js passes.` and nothing about the full suite. The
   suite gate moves to the join, as its own line in the header:
   `**Batch gate:** after tasks 1 to 3 land, node --test test/ is green.` A whole-suite `Done when:`
   inside a batch proves nothing about the batch: each worktree holds only its own task's change, so
   the suite that means anything is the one at the join, where every sibling's change first meets
   the others.
2. **Write the final step as a commit, not a hand-over.** A batched task is the one case that
   commits for itself, because it runs in its own worktree and the join reads
   `git diff <the commit the batch started from>..HEAD` from it. **The difference has to be in the
   task text**, not added at dispatch time: a coordinator that pastes a hand-over step saying "do
   not commit" and then appends a rule saying "do commit" has given the implementer two orders, and
   [subagent-prompts.md](../../execute-plan/references/subagent-prompts.md) tells it the task wins.

   ````markdown
   - [ ] **Step 1.5: Commit**

   You are in your own worktree, so this task commits rather than handing over.

   ```bash
   git add src/format.js test/format.test.js
   git commit -m "feat(format): normalise whitespace"
   ```
   ````

   The named-paths rule above still applies: a worktree keeps a sibling's files out, but not
   whatever else is in this one.

   **A batched task left with a hand-over step commits nothing, so the join diff is empty**, and an
   empty diff produces a confident COMPLIES over nothing. Observed on 2026-08-20: a real implementer
   given a hand-over step plus a dispatch-time rule telling it to commit staged its paths, said "not
   committed, per instructions", named neither rule, and left `git diff <start>..HEAD` at zero bytes.
3. **Touch no shared config.** A task in a batch that would create or edit a lockfile, a linter
   config, a CI file, or the profile is not eligible for the batch. Two agents each deciding the
   lint command needs a config file will each write one.
4. **Leave the shared records to a records task after the batch.** `CHANGELOG.md`, `README.md` and
   the skill catalog are written once, by a task that depends on every task in the batch, because
   two tasks that each add to the same record name the same file and meet in a conflict in the one
   place both edit. The documentation still lands in the same pull request; only the commit that
   carries it moves to the join.

The failure the first three prevent is quieter than a lost race, and it is what a batch run in one
shared tree produces: with a sibling's failing test in the suite, every agent's step 2 sees red for
the wrong reason and ticks the box, so *"the TDD gate silently stops proving anything"*. A worktree
per task is what keeps each suite to its own task.

Where any of the four cannot hold, the tasks are sequential. Say so rather than declaring a batch
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
- It is **scoped to the task's own test, never the full suite**, in every plan and not only in a
  concurrent batch. The tests run once at the unit boundary, which for a sequential task is its
  hand-over step and for a batched one is the `Batch gate:` line at the join. A whole-suite `Done
  when:` puts the suite back inside the cycle it was moved out of, and in a batch it also proves
  nothing, for the reason under "Tasks that run concurrently" above.
- It appears once per task, above the steps, so a fresh agent dispatched only that section still
  receives it.

## Step granularity

Each step is one action, two to five minutes:

- Write the failing test
- Run it and watch it fail
- Write the minimal code
- Run it and watch it pass
- Run the tests at the unit boundary, then hand over: stage the named paths, do not commit

Steps 2 and 4 are not ceremony. A test you did not watch fail may be asserting nothing, and a
plan that omits the failure check produces suites that are green because they test nothing.

### A step somebody else already did

Most plans are resumed, so the common case is arriving at a task whose first steps are already
satisfied. The banner's rule covers it: tick with a note, or leave it and report. The distinction
that matters is *witnessed here* against *believed done*, not *done* against *not done*, because a
silent tick leaves the plan asserting that a failing test was watched failing in a session where
nobody watched anything.

### Step ids and states

Every step carries an id, `<task>.<step>`, at the start of its bold title:
`**Step 3.2: Run it and watch it fail**` is task 3's second step, and task 1b's first is `1b.1`.
Ids are unique within the plan. `keel plan status <plan>` counts each task's steps and names the
next open one, and `keel plan tick <plan> <id>` changes one step, both by id; a plan without ids
is reported as unaddressable and is read and ticked by hand.

A step is in one of four states, shown by its box, with anything more on the same line after
the title:

| Box | State | After the title |
|---|---|---|
| `[ ]` | open | nothing |
| `[x]` | done | ` Note: <text>`, where the step was not witnessed (`--note <text>`) |
| `[-]` | deferred | ` Deferred: <reason>`, required (`--defer <reason>`) |
| `[~]` | not applicable | ` Not applicable: <reason>`, required (`--not-applicable <reason>`) |

A step inside a fenced code block is an example, like this template's own, and is never counted.

## Task granularity

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

Step 4 of the skill lists them. Every one moves a decision from the planner to someone with less
context.

If you cannot state a behaviour with an example, the plan is not finished. Say what is blocking it
and put it in an open questions section rather than hiding it behind a phrase.

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
`keel profile set verify.test ...` for each and a `keel doctor` that must pass. Full doctor also
runs `verify.security` where one was detected, which needs the network, so a task that must leave
doctor passing names that dependency. State the commands it will create in the plan's global
constraints, so every later task inherits a real command rather than a promise. Task 1's own step 2
watches the test command fail because the toolchain is absent, which is a real failure and the
honest one to watch.

That task satisfies no story and is infrastructure. Say so in it, rather than inventing a story for
it to trace to.

## Tasks with no test

Some tasks genuinely cannot be tested: a human check against deployed environments, a rotation
that touches a partner, a decision recorded as a runbook entry. A plan may contain one, and it
**must say so explicitly** rather than inventing a test to fill the shape. Its behaviours still
carry an example: the wording the task must produce, or the output of a check command.

```markdown
- [ ] **Step 4.1: There is no test for this**

This task is a human check. It cannot be automated because it requires reading configuration
from environments this repository cannot see.
```

The failure mode this prevents is a fabricated test that passes without checking anything, which
is worse than an honest gap because it reads as coverage.

## Self-review

1. Every story in scope maps to at least one task.
2. No placeholder phrases survive.
3. Names used in later tasks match what earlier tasks defined. A function called
   `clearLayers()` in task 3 and `clearFullLayers()` in task 7 is a bug you are shipping into
   someone's afternoon.
4. Every **verifying** command comes from `profile.verify`. Investigative commands (`grep`,
   `git log`, `ls`) need no entry, and demanding one makes the check reject correct plans.
5. Every task ends with a hand-over step that stages named paths and names the commit the
   coordinator will make after both review passes. Only a task in a declared concurrent batch commits
   for itself, and then only inside its own worktree.
6. No task depends on a file no task creates.
7. Every step's bold title opens with its id, `Step <task>.<step>:`, and no id repeats:
   `keel plan status <plan>` exits 0, and no step title is in the old form, `**Step <n>: `.
8. Every behaviour has an example a test, or for a no-test task a check command or a reader, can
   assert.

Fix inline. Then report coverage and hand off.

## Common mistakes

| Mistake | Instead |
|---|---|
| Guessing the test command | Read `profile.verify`. Guessing produces a plan that fails at step 2 |
| Skipping the failing-test step | Watching it fail is what proves the test works |
