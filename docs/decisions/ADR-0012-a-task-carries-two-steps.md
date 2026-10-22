# ADR-0012: A task carries two steps

| | |
|---|---|
| Status | accepted |
| Date | 2026-10-21 |
| Deciders | Bernard Tebandeke, proposed 2026-10-21; accepted 2026-10-21 on the condition below |
| Requirements | none; driver is the discussion of 2026-10-21 on whether keel should keep a plan template of its own now that harnesses have plan modes |
| Supersedes | none; amends the plan template's five-step task shape |

## Context

`skills/write-plan/references/plan-template.md` is about 4,200 words. A task in a plan written from
it carries five steps, although `keel:tdd` already prescribes the cycle those steps restate: write
the failing test, watch it fail, write the code, watch it pass, hand over. The plan repeats the
cycle once per task, and the skill that owns the cycle says it once.

The cost shows in the plans themselves. The PRD for addressable steps,
[addressable-plan-steps](../prd/addressable-plan-steps.md), records this repository's plans at
10,000 to 35,000 words, with 30 checkboxes in the latest and each of its five labels appearing six
times. A six-task plan carries 30 checkboxes, 18 of them restating the cycle.

## Decision

**A task has two steps. Step N.1 builds the task test first, following `keel:tdd`, and ends at the
unit-boundary run. Step N.2 hands over: it stages the named paths and stops. The implementer's
report quotes the failing run that preceded the implementation, and the spec reviewer returns
DEVIATES for a report without it.**

The red is no longer a box to tick. It is evidence in the report, and a report without it does not
pass the spec review. Step ids, the four states and every `keel plan` command are unchanged: `keel
plan status`, `tick`, `report` and `ship`'s gate find a task from its steps' ids
(`<task>.<step>`), so a task with two steps is read as a task with five is today. Plans already
written keep their five steps and keep working.

## Alternatives considered

### A: Keep five steps

Each stage of the cycle keeps its own tick. It loses on the duplication: three of the five steps
say what `keel:tdd` says, in every task of every plan.

### B: Drop step ids

With no per-step checkbox there is nothing to address. It loses because `plan status`, `tick`,
`report` and `ship` read the ids, and the addressable-steps work exists because a reread of a plan
that size misses boxes.

### C: One step per task

The whole task is one box. It loses because the hand-over names task-specific paths and a commit
message and is ticked only after review, so it is a different kind of step from the build and
cannot share its box.

## Consequences

**What is lost.** A tick per cycle stage. `rounds`, `routing` and `loop` stay on the last step
ticked in a task, so nothing in `keel plan report` changes.

**What is gained.** Fewer checkboxes: 12 where a six-task plan had 30, and one place for the
cycle, `keel:tdd`, instead of a copy in every task.

**No claim that the template gets shorter.** The text that states the two-step shape, and the
report evidence the implementer prompt and the spec reviewer now ask for, offset what is removed.
The gain is in the plans, not in `plan-template.md`.

**What must be true for this to keep working.** That an implementer told only "follow `keel:tdd`"
still watches a test fail before it writes the code, and that its report shows it.

## Verification

Accepted only if the paired eval of task 7 of
[the plan](../plans/2026-10-21-lean-task-steps.md) (four runs per arm, Sonnet) shows the two-step
arm meeting every criterion the five-step arm meets in each run, and quoting the pre-implementation
failing run in every run. Otherwise this ADR is marked `rejected` and tasks 2 to 5 of that plan are
reverted. A two-step run whose report shows only passing output fails the condition even if its
code is right.

Four runs per arm is thin, so a pass is evidence and not proof. The longer check is `rounds` and
rework from `keel plan report` on the first real plans written this way.

**Result, 2026-10-21.** The eval ran: four runs per arm on Sonnet, the two-step arm at five criteria
out of five in all four, the control the same, and the red quoted in every run. The condition is
met and this ADR is accepted. The evidence is weak, for the reasons the results entry gives (one
easy task, no criterion separated the arms, both arms carry the report line), and the longer check
above stands. The entry is "2026-10-21, the step-shape pair for ADR-0012" in
`tests/evals/results.md`.
