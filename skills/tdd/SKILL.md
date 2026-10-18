---
name: tdd
description: Use when writing implementation code for any feature, bugfix or behaviour change, including each task a plan dispatches; a small change the user asks for directly, outside a plan, starts at write-plan's short path.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion]
---

# Test-Driven Development

## Overview

Write the test first. Watch it fail. Write the minimum that passes.

Why each step is as it is: [references/rationale.md](references/rationale.md). Read it before
changing a step.

## The iron law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Wrote code before the test? Delete it and start over.

**No exceptions.** Not as reference, not adapted while writing the test, not looked at. Delete means
delete, then implement fresh from the test.

## Commands come from the profile

Read `.keel/profile.json` first: `verify.test_one` for one test, `verify.test` for the suite,
`verify.test_affected` for the tests a change since `{base}` affects, `verify.test_integration` for
database-backed tests.

## The cycle

### RED: write the unit's failing tests

The unit is every case going red for one named missing production change, named as the **smallest**
change making that case red; a case needing a second change is a second unit. Before its first
test, write the **start record**: the starting commit, and the tests still red after the last
boundary (the first unit's costs one `verify.test`). Name that commit in the report. Write the cases
together.

No VCS, and when to write one case at a time:
[references/step-detail.md](references/step-detail.md#red-write-the-units-failing-tests). Read it
before you do this step.

See [references/writing-good-tests.md](references/writing-good-tests.md) when writing or
changing any test.

### Verify RED: watch it fail

**Mandatory. Never skip.** Run `verify.test_one`. Confirm it fails rather than errors, the message is
the one you expected, and it fails because the behaviour is missing, not a typo.

Passed immediately? It tests existing behaviour. Errored? Fix and re-run.

Report a tally:
[references/step-detail.md](references/step-detail.md#verify-red-watch-it-fail). Read it before you
do this step. A first-run pass is legitimate only if the case is green on the start record's commit,
and never counts toward the unit's coverage.

### Prefer a real database over a mocked one

Use `verify.test_integration` from the profile.
[references/writing-good-tests.md](references/writing-good-tests.md) covers how, and when a mock is
right.

### GREEN: minimum code

The simplest thing that passes. No extra parameters, no options object, no error handling for
states that cannot occur.

### Verify GREEN: watch it pass

Run `verify.test_one`. The new test passes, output clean. Still failing? Fix the code, never the
test.

### REFACTOR

Only once green. Remove duplication, improve names, extract helpers. No new behaviour. Stay green.

### Unit boundary: run the tests

The unit ends with one `verify.test_affected` run when the profile sets it, `{base}` the start
record's commit, else one `verify.test`. Fallbacks to `verify.test`, carried reds, and which
units an unmatched red names: [references/affected-tests.md](references/affected-tests.md).

Red for tests this unit did not touch? Name them and match them against the start record. All
matched means the unit is done: record them and carry on. An unmatched red goes to `keel:debug`.

## Exceptions, stated out loud

Not required for a throwaway spike, generated code, or pure configuration. Taking the exception is
fine; taking it silently is not. Say which applies and why, then delete the spike before implementing
properly.

### The project has no test tooling at all

`verify.test` and `verify.test_one` both `null`, and not greenfield? You do not resolve that
yourself. Ask, with the three options and their costs in
[references/no-test-tooling.md](references/no-test-tooling.md).

Code with no tests gets one for what you touch. Where no runner exists, this exception applies
rather than installing one.

## Red flags: stop and start over

Code before test. Test written after. Test passed first run, pinning nothing. Cannot explain why it
failed. "Just this once." "Spirit not ritual." "This case is different because." "I will test
after." "This code has no tests." "The suite is green, do not risk touching it."

All of these mean: delete the code, start with the test. Each excuse's answer:
[references/rationalisations.md](references/rationalisations.md).

## Before claiming done

Every new function has a test. You watched each case asserting new behaviour fail first, for the
expected reason. Any case you could not watch fail, you broke the line it covers and watched it go
red. You wrote the minimum. The boundary run showed only matched reds. Edge cases and error paths
are covered. Cannot claim all six? You skipped TDD.

## Bugs

Never fix a bug without a test reproducing it first. See `keel:debug` for finding the root cause
before you get here.
