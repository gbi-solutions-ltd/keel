# The unit boundary when the profile names the affected tests

`SKILL.md` ends each unit with one `verify.test_affected` run when the profile sets it. This page
holds what that run needs and cannot say alone. The decision, its costs and the rule it amends in
ADR-0006 are in `docs/decisions/ADR-0009-the-unit-boundary-may-run-the-affected-tests.md`.

## When the boundary runs `verify.test` instead

Run the whole suite, as the boundary always did, in either case:

- **There is no VCS.** `{base}` is the start record's commit, and with no commit there is nothing to
  fill it with, so the selection would have no starting point.
- **The run's output does not show the unit's own cases ran.** A runner that selects by changed
  files can miss a new test file, and a boundary that never ran the unit's tests proves nothing
  about them. Look for the unit's test names or files in the output. If they are not there, run
  `verify.test`, and say in the report that the selection missed them, so the person who set the
  command can see it misses new files.

## The start record across units

The first unit's start record costs one full `verify.test`. It is the only run that sees every red,
because an affected run sees only what it selects. Every later unit's start record is the previous
one carried forward:

- **A red stays on the record until a run shows that test passing.** An affected run that does not
  select a test says nothing about it, so its absence from the output is not a fix.
- **A test seen passing at a later boundary drops off.** That run saw it pass, so it is no longer a
  known red, and if it fails again that is a new break, to be treated as one.

Two examples:

- A test was red before the work started, so the first start record holds it. At unit 3 it is in the
  affected set and fails. It is on the record, so it is **matched**: record it and carry on, and do
  not hand it to `keel:debug`. This unit did not cause a red that was there before any unit began.
- A test was red before the work started. Unit 2's boundary run selected it and saw it pass, so it
  dropped off the record. Unit 4 breaks it again. Unit 4's start record no longer holds it, so the
  red is **unmatched** and goes to `keel:debug`. Fixed means fixed: a break after the fix is new.

## Which units an unmatched red names

Only while every boundary so far ran the full `verify.test` is an unmatched red this unit's, as it
always was. Once any boundary ran the affected tests, hand it to `keel:debug` naming **every unit
since the first start record** as a possible cause, not only the current one, even when this unit's
own boundary ran `verify.test`: an earlier selection may have hidden the break, so the first run
that reaches it can be a later unit's. A unit can break a test outside its own selection, and the
break shows only at a later unit whose run includes it. That later unit did not cause it, and
naming it alone sends `debug` to the wrong diff.

Example: unit 2 breaks a test its own run did not select. Unit 3's run did not select it either.
Unit 4's run does, and shows it red. It is not on the record, so it is unmatched, and `debug` is
told units 1 to 4, every unit since the first start record, not unit 4 alone: the record cannot say
which unit broke it.

Example: unit 3's affected run misses its own new file, so unit 3 runs `verify.test`, and a test
unit 2 broke shows red. Unit 2's boundary was an affected run, so `debug` is told units 1 to 3, not
unit 3 alone.
