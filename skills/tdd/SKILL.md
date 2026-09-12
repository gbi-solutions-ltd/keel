---
name: tdd
description: Use when implementing any feature, bugfix, or behaviour change, before writing implementation code.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion]
---

# Test-Driven Development

## Overview

Write the test first. Watch it fail. Write the minimum that passes.

**Core principle:** if you did not watch it fail, you do not know it tests anything.

**Violating the letter violates the spirit.**

## The iron law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Wrote code before the test? Delete it and start over.

**No exceptions.** Not as reference, not adapted while writing the test, not looked at. Delete means
delete, then implement fresh from the test.

## Commands come from the profile

Read `.keel/profile.json` first: `verify.test_one` for one test, `verify.test` for the suite,
`verify.test_integration` for database-backed tests.

## The cycle

### RED: write the unit's failing tests

The unit is every case going red for one named missing production change, named as the **smallest**
change making that case red; a case needing a second change is a second unit. Before its first test,
write the **start record**: the starting commit, and the tests already red there, which the previous
unit's boundary run reports (the first unit's costs one `verify.test`). Name that commit in the
report. No VCS? Say so: the baseline is the working tree as found. Write the cases together, real
code rather than mocks, one behaviour per case, each name stating it. Cannot name the change? It
asserts nothing.

Can you write the whole spec before writing any of it? If not, this cycle is design work: one case
at a time. **The iron law is unchanged:** batching changes how many cases go red together, never
whether the cases asserting new behaviour were watched failing.

See [references/writing-good-tests.md](references/writing-good-tests.md) when writing or
changing any test.

### Verify RED: watch it fail

**Mandatory. Never skip.** Run `verify.test_one`. Confirm it fails rather than errors, the message is
the one you expected, and it fails because the behaviour is missing, not a typo.

Passed immediately? It tests existing behaviour. Errored? Fix and re-run.

Report a tally: how many written, how many failed, and for each first-run pass the behaviour it
pins. That pass is legitimate only where the case is green on the start record's commit, and it
never counts toward the unit's coverage.

### Prefer a real database over a mocked one

Where a behaviour touches persistence, test against a **running** database.

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

### Unit boundary: run the suite

The unit ends with one `verify.test` run. The suite is 313 seconds and one test is 2.

Red for tests this unit did not touch? Name them and match them against the start record. All
matched means the unit is done: record them and carry on. An unmatched red is this unit's: hand it
to `keel:debug`.

## Exceptions, stated out loud

Not required for a throwaway spike, generated code, or pure configuration. Taking the exception is
fine; taking it silently is not. Say which applies and why, then delete the spike before implementing
properly. "I will tidy it later" means the spike is production code with no tests.

### The project has no test tooling at all

Both commands `null` and not greenfield? You do not resolve that yourself. Ask, with the three
options and their costs in [references/no-test-tooling.md](references/no-test-tooling.md), and
record the answer.

## Rationalisations

| Excuse | Reality |
|---|---|
| "I will test after" | It passes immediately, proving nothing. You never saw it fail, so never proved it catches the bug |
| "I will backfill the tests" | They pass on the first run and prove nothing about whether the guard ever caught anything |
| "This code has no tests" | You are improving it. Add one for what you touch. This assumes a runner exists; where none does, see the exception below rather than installing one |
| "The suite is green, do not risk touching it" | It may be green *because* a test asserts the current wrong behaviour. Writing the test first tells you in two minutes, not mid-release |

The rest, unchanged, in [references/rationalisations.md](references/rationalisations.md).

## Red flags: stop and start over

Code before test. Test written after. Test passed first run, pinning nothing. Cannot explain why it
failed. "Just this once." "Spirit not ritual." "This case is different because."

All of these mean: delete the code, start with the test.

## Before claiming done

Every new function has a test. You watched each case asserting new behaviour fail first, for the
expected reason. Any case you could not watch fail, you broke the line it covers and watched it go
red. You wrote the minimum. The boundary suite ran, every red matched. Edge cases and error paths
are covered. Cannot claim all six? You skipped TDD.

## Bugs

Never fix a bug without a test reproducing it first. See `keel:debug` for finding the root cause
before you get here.
