# Concurrent batches

This file is read from [plan-template.md](plan-template.md) when a task may run beside another,
and whenever `keel plan batches` prints a batch. It holds the order to write the plan in, the
strict `Files` form, the four rules every batched task meets, and what the header declares.

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
   - [ ] **Step 1.2: Commit**

   You are in your own worktree, so this task commits rather than handing over.

   ```bash
   git add src/format.js test/format.test.js
   git commit -m "feat(format): normalise whitespace"
   ```
   ````

   The rule under "Named paths only, in every task" in [plan-template.md](plan-template.md) still
   applies: a worktree keeps a sibling's files out, but not whatever else is in this one.

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
shared tree produces: with a sibling's failing test in the suite, every agent's failing-test run
sees red for the wrong reason and counts as its own proof, so *"the TDD gate silently stops proving
anything"*. A worktree per task is what keeps each suite to its own task.

Where any of the four cannot hold, the tasks are sequential. Say so rather than declaring a batch
and hoping.
