# Running a declared batch concurrently

Read this when a plan declares a concurrent batch, to decide whether the declaration is eligible and
how to run it. A plan that declares none needs nothing here, and nothing here licenses a batch the
plan did not declare.

## Eligibility, and why the obvious test is not enough

A batch is eligible only when **all five** hold:

1. The plan's header declares it a concurrent batch.
2. Every task in it has `Depends on: none`, or names only tasks already landed and reviewed.
3. No two tasks in it name the same path anywhere in their `Files` blocks.
4. Each task's `Done when:` is scoped to that task's own test, with the whole-suite gate held at
   the batch join.
5. No task in it creates or edits shared config: a lockfile, a linter or formatter config, a CI
   file, or `.keel/profile.json`.

**1 to 3 are the ones people check, and on their own they produce a green suite that proves
nothing.** A run asked to execute a five-task plan as fast as it reasonably could worked out
unaided that three leaf tasks had disjoint files and no shared symbols, then refused to overlap
them anyway, and its reason is condition 4:

> "even with perfect isolation of source files, three concurrent agents each waiting for a green
> whole-suite cannot all pass."

Task 2's step 1 writes a failing test on purpose. That is TDD working. It also turns task 1's
whole-suite gate red through no fault of task 1, and task 1's agent then either reports blocked or
follows `keel:debug` into someone else's task.

**The quiet failure is worse than the loud one.** With a sibling's failing test in the suite, every
agent's step 2 sees red for the wrong reason and ticks the box:

> "The TDD gate silently stops proving anything."

That is the whole value of the plan, gone, with every checkbox ticked.

## Dispatching

Dispatch the batch in one message, each agent with `isolation: worktree`, so each gets its own
checkout and the shared working tree stops being shared. Without it, three further failures follow,
all predicted in the same run and none of them a rare race:

| Without a worktree | What happens |
|---|---|
| Commit capture | A step 5 that runs `git add -A` sweeps in a sibling's half-written files, producing "a commit labelled 'format' containing a half-written SMS module" |
| Index lock | Two `git commit` calls race on `.git/index.lock`; a stale lock cleared by one agent while the other is mid-write corrupts the staging state |
| The reviewer sees the wrong diff | Pass one is fed `git diff` from a shared tree, sees both tasks, answers "is anything here that no step asked for" with YES, and returns a spurious DEVIATES that re-dispatches correct work |

Add to each implementer prompt, on top of the standard rules:

```
- You are running concurrently with other tasks. Commit only the paths this task lists, by name.
  Never `git add -A` and never `git commit -a`.
- Your `Done when:` is this task's own test. Do not run the full suite; another task is
  deliberately red while you work. Do not investigate a failure in a file this task does not list.
```

## Joining

Review each returned task in the usual two passes as it arrives; that part does not batch. Take the
diff both passes need from that worktree alone, as `git diff <the commit the batch started from>..HEAD`
run inside it. A plain `git diff` in the shared tree shows a mixture of all three, or nothing at all
once each agent has committed, and **an empty diff produces a confident COMPLIES over nothing.**

Then, in one place and by you:

1. Merge each worktree back, in task order, so a conflict surfaces against a known predecessor.
2. **Run the whole suite once.** This is the batch gate the tasks were excused from, and it is the
   first honest whole-suite result in the batch.
3. Tick the checkboxes for the whole batch, serially. Two near-simultaneous edits to the plan file
   will otherwise drop one task's ticks through a stale read.
4. Commit, or confirm each task's own commit landed with only its own paths in it.

A red suite at the join is a real finding about the combination, which is exactly what no task
could have discovered alone. Use `keel:debug`; do not re-run the tasks.

## When not to batch

If eligibility fails on any of the five, **run the tasks one at a time** and say which condition
failed. Three tasks run safely in sequence beat three run concurrently on a gate that cannot hold.

**Do not stop the plan for it.** A wrong declaration is a defect in one header line, not a reason to
halt work the tasks themselves can do safely, and stopping is step 5's job: it is for tasks that
cannot be executed as written, which is a different finding. Withdraw the declaration in the plan
file so the next run does not re-derive it. That is a tightening edit and it is yours.

Repairing the tasks so the batch becomes eligible is not yours. Rescoping a `Done when:` or moving a
config file into a predecessor task changes what was planned in order to buy speed, however
reasonable it looks. Propose it and let the user rule.
