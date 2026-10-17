# ADR-0009: The unit boundary may run the affected tests, not the whole suite

| | |
|---|---|
| Status | accepted |
| Date | 2026-10-16 |
| Deciders | Bernard Tebandeke, accepted 2026-10-16 |
| Requirements | none; driver is gap 2 of `docs/ideas/delivery-flow-gaps.md`, "test speed is reported, not managed" |
| Supersedes | none; amends one rule of [ADR-0006](ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md), under "A red boundary the unit did not cause" |

## Context

[ADR-0006](ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md) moved the suite from every GREEN
to the unit boundary, and measured why: the suite took 313 seconds against 2 for one test. That
cut the suite to one run per unit, the right trade then, and leaves a cost per unit standing.
keel's own suite takes about 170 seconds now. A change of ten units pays that ten times at the
boundary, about 28 minutes, and again in `review-code` and `ship`. The boundary run is the one the
cycle can shrink without giving up anything the later runs cover.

Some stacks can select the tests a change affects, and `doctor` can already time the suite and say
what it costs. What the cycle cannot do is use a selection, because its boundary step names exactly
one command, `verify.test`.

## Decision

**The unit boundary runs `verify.test_affected`, with `{base}` replaced by the commit the unit's
start record names, when the profile sets it, and `verify.test` when it does not.** With no VCS
there is no `{base}`, so the boundary runs `verify.test`. When the affected run did not run the
unit's own cases (a new test file the runner's selection missed), the boundary runs `verify.test`
too, because a boundary that never ran the unit's tests proves nothing about them. The first start
record of a `tdd` session still costs one full `verify.test`, and the reds it holds carry forward
from unit to unit, each boundary dropping any red a later run sees passing.

**The command must select uncommitted and untracked changes since `{base}`.** Under `execute-plan`
an implementer stages and does not commit, so every unit of a task shares one `HEAD`, and a command
that selects only committed changes would select nothing. A command with no `{base}` in it is
accepted, for a runner that tracks changes itself.

**The key is set by hand and `keel init` writes it as null.** `keel init` does not detect a runner:
no project has used one yet, and a detector written before a user is a guess.

**What this amends in ADR-0006.** Its sentence "A boundary red the start record does not hold is one
this unit caused" no longer holds once any boundary has run the affected tests. The start record was
taken from a full run, and the boundary run is a selection, so a break made by an earlier unit
outside that earlier unit's own selection can first show at a later unit's boundary, where the later
unit did not cause it, and a later full run can be the first to see it. Such a red goes to
`keel:debug` all the same, naming every unit since the first start record as a possible cause. Where
every boundary since the first start record ran `verify.test`, the sentence stands as written.
ADR-0006 is otherwise unchanged, and so is its iron law: no production code without a failing test
first. This ADR moves where a test runs, never whether a new case was watched failing.

## Alternatives considered

### A: Warn about a slow suite and leave the boundary at the whole suite

`doctor` names the cost and the cycle keeps paying it. It is built too, as `doctor`'s warning, and
it is not enough alone: the warning tells a project it is slow and gives the cycle nothing to do
about it. It loses as a complete answer and stays as the half that makes the cost visible.

### B: Detect the runner in `keel init`

Write `verify.test_affected` for Jest, Vitest and the like. It loses for now because a detected
command that selects too little hides a break, which is the cost this decision accepts only for a
command a person chose. Left until a project has used one by hand and shown what the detector
should write.

## Consequences

**What becomes easier.** A ten-unit change on a 170 second suite pays one full run at the start and
a runner-sized one per unit, instead of about 28 minutes in the suite. The suite still runs in
`review-code`, `ship` and CI.

**What becomes harder.** A break outside what the runner selects surfaces at `review-code`, not at
the boundary that caused it, and the author meets it with more units behind it. The selection's
accuracy is the runner's, not keel's: a runner that misses a dependency hides a break until the full
suite runs. Both are accepted. The attribution rule above is what the second gets instead of a
mitigation.

**What this forecloses.** Little. Unsetting the key returns the boundary to the whole suite.

**What must be true for this to keep working.** That the command selects what a change touches
including uncommitted and untracked files, and that `review-code` and CI keep running the whole
suite, since they are the backstop for what a selection misses.

## Verification

Holding if a project that sets `verify.test_affected` stops paying the suite per unit and no break
reaches the default branch that the old boundary run would have caught and `review-code`'s run did
not. A break caught at `review-code` is the accepted consequence above, not a falsifier.

Not holding if a break reaches the default branch past `review-code` and `ship`, or if a red at a
later boundary was handed to `keel:debug` blaming only the current unit.

Not checked on the day of this decision: no project has set `verify.test_affected` yet.
