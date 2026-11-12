# ADR-0017: A plan run checks the whole suite at checkpoints, not in every implementer

| | |
|---|---|
| Status | accepted |
| Date | 2026-11-11 |
| Deciders | Bernard Tebandeke, accepted 2026-11-11 |
| Requirements | none; driver is item 1 of [`docs/ideas/plan-execution-speed.md`](../ideas/plan-execution-speed.md), "the suite runs twice per task" |
| Supersedes | none; amends [ADR-0006](ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md) and [ADR-0009](ADR-0009-the-unit-boundary-may-run-the-affected-tests.md), for a unit run under `execute-plan` with a checkpoint line only |
| Amended by | its own [Amended](#amended) section, 2026-11-12 |

## Context

[ADR-0006](ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md) put the suite at the unit
boundary, and [ADR-0009](ADR-0009-the-unit-boundary-may-run-the-affected-tests.md) let that
boundary run the affected tests instead, keeping one full `verify.test` for the first start record
of a `tdd` session. Under `execute-plan` every implementer is a fresh `keel:tdd` session, so every
task pays that first run, and its boundary pays a second one when the profile sets no
`verify.test_affected`.

Measured on 2026-11-11 and recorded in [the idea record](../ideas/plan-execution-speed.md): a
sample project's suite takes about 300 seconds, of which one test package takes 244, and that
package holds nearly every task's tests. On its cleanest plan run, 10 tasks over 294 minutes, the
full suite ran 14 times over 11 implementer dispatches and took 22% of the wall clock. A selection
by changed package would still pick the 244 second package every time, so ADR-0009's remedy does
not reach this cost.

## Decision

**Under `execute-plan`, the coordinator runs `verify.test` once before the first dispatch, after
every N tasks are committed and after the last task.** The first run is the plan-start record. N
comes from the plan header line `**Suite checkpoints:** every N tasks`; `write-plan` writes 3 unless
the person approving says otherwise. A 10-task plan with N 3 runs the suite at start and after
tasks 3, 6, 9 and 10. The reason is the measurement above: one run every few tasks costs a fraction
of two per task and still bounds how far back a break can hide.

**Each implementer is handed the last checkpoint's record, its commit and the reds still on it, as
its first start record, so it runs no `verify.test` for one.** Its unit boundary is the task's
`Done when:` and the lint command, plus `verify.test_affected` where the profile sets it. On the
sample project above a task stops paying two runs of about 300 seconds and pays its `Done when:`
only. The record is the coordinator's because the coordinator is the one agent that sees every
task, and a record any implementer could take on its own would be the per-task cost again.

**At a checkpoint task the order is fixed.** Its review passes; the coordinator runs `verify.test`
on the tree with that task staged; it ticks the task's last step with the note
`rounds: <n>; routing: <profile>; loop: <light|full>; suite: pass`, or `suite: red <names>` matched
against the record; then it commits task and plan together as it does today. So the suite result is
in the one tick, no re-tick replaces the note, and the tree is clean before the next dispatch.
Task 3 of a 10-task plan with N 3 is ticked with `...; suite: pass`. Running the suite before the
tick, not after the commit, keeps a red out of a commit whose note says nothing of it.

**A checkpoint red not on the previous record stops the run before that tick.** The coordinator
runs `keel:debug` through Phase 3, naming as candidates the staged task and the tasks committed
since the previous checkpoint: a red at the task-6 checkpoint names tasks 4, 5 and 6. If the staged
task caused it, it is a rejection of that task, handled as the loop handles one. If an earlier task
did, the staged task is still ticked and committed with `suite: red <names>`, and Phase 4 goes to a
fresh implementer as a task appended to the plan, in the full loop, before any further dispatch.
The earlier task is already committed, so the fix can only be a new commit, and dispatching past a
known red would let later tasks build on it.

**A plan with no `**Suite checkpoints:**` line runs its steps as written.** Older plans name the
suite in their steps, and the task text overrides the skill, so a plan written before this decision
behaves as it did.

**`review-code`, `ship`, CI and a declared batch's join gate are unchanged.** They run the whole
suite as before and remain the backstop for what a checkpoint has not yet seen.

**What this amends.** ADR-0006's per-unit boundary, where the suite or ADR-0009's affected run ends
every unit, and ADR-0009's sentence "The first start record of a `tdd` session still costs one full
`verify.test`". Both change only for a unit run under `execute-plan` in a plan with a checkpoint
line. Standalone `tdd` is unchanged, and so is ADR-0006's iron law: no production code without a
failing test first. This ADR moves when the suite runs, never whether a new case was watched
failing.

## Alternatives considered

### A: A Go `verify.test_affected` recipe

Select by changed package and let ADR-0009 do the rest. It loses as the whole answer because the
sample project's 244 second package is in nearly every selection, so the selection still costs most
of a suite per task. It stays open as a project's own setting, and a profile that sets it still
runs it at each unit boundary.

### B: Run the suite at the plan's end only

One run per plan, the cheapest schedule. It loses because a break found after ten tasks has ten
candidates and ten commits on top of it, and `keel:debug` narrows a range of three far faster than
a range of ten.

## Consequences

**What becomes easier.** On the measured run, 14 suite runs become five with N 3 (start and after
tasks 3, 6, 9 and 10): at about 300 seconds each, about 70 minutes become 25, saving about 45 of
the run's 294 minutes. This is a forecast from the idea record's numbers, not yet a measurement of
a run under this decision.

**What becomes harder.** A break is found up to N tasks late and narrowed to a range, not pinned to
one task, and the commits it spans are already on the branch, so the fix lands as a new commit
rather than a rejected attempt. And `done-guard` now counts a scoped test run as a test run (task 1
of `docs/plans/2026-11-11-faster-plan-execution.md`), so a satisfied `gates.done_verified` no longer
proves the suite ran; under a plan run the checkpoint note is what says it did. Both are accepted.

**What this forecloses.** Little. Leaving the checkpoint line out of a plan returns its tasks to
the per-unit suite.

**What must be true for this to keep working.** That the coordinator runs every checkpoint and
writes its result in the tick, that an implementer starts from the record it is handed rather than
assuming a green tree, and that `review-code`, `ship` and CI keep running the whole suite.

## Verification

Holding if a plan run with a checkpoint line shows no `verify.test` inside its implementers, a
`suite:` field on each checkpoint tick, and no break reaching the default branch that a per-task
suite run would have caught and `review-code` did not.

Not holding if a checkpoint red is handed to `keel:debug` naming only the staged task, if a task is
dispatched past an unexplained checkpoint red, or if the wall clock per task does not fall on a
project whose suite dominated it.

Not checked on the day of this decision: no plan has run with a checkpoint line yet.

## Amended

**2026-11-12, decided by Bernard Tebandeke: the checkpoint note names the tree it ran on, and
`review-code` quotes the plan-end checkpoint in place of its own run on the same tree.** Item 6 of
[`docs/ideas/plan-execution-speed-2.md`](../ideas/plan-execution-speed-2.md). The coordinator runs
`git write-tree` with the task staged, before the tick, and the note ends
`suite: pass at tree <tree sha>` or `suite: red at tree <tree sha> <names>`. It names a tree, not a
commit, because the suite runs before task and plan are committed together, so no commit the note
could name is HEAD.

`review-code` runs no suite of its own when the plan's last ticked step carries
`suite: pass at tree <sha>`, `git diff --name-only <sha> HEAD` names nothing outside
`docs/plans/`, and `git status --porcelain` prints nothing; it quotes that note as the suite result
instead. HEAD then differs from the checked tree only under `docs/plans/`, where the tick lands,
so a second run would check nothing new. This removes one of the three suite runs on the final
commit (the plan-end checkpoint, `review-code` and `ship`). `ship` is unchanged and still runs its
own, so the final commit keeps an independent run besides the checkpoint, and CI and a declared
batch's join gate are unchanged.

This changes two sentences above, which stand as written for the day they were decided:
"`review-code`, `ship`, CI and a declared batch's join gate are unchanged" under Decision, and
"`review-code`, `ship` and CI keep running the whole suite" under Consequences. Under a plan run,
`review-code` now keeps running it except on the plan-end checkpoint's tree. The note formats under
"At a checkpoint task the order is fixed" gain `at tree <tree sha>` the same way.
