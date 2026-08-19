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
`verify.test_integration` for database-backed tests. Never guess the stack's idiomatic command; a
project's real one is frequently not the obvious one. Absent? Ask rather than invent.

## The cycle

### RED: write one failing test

One behaviour, a name that states it, real code rather than mocks. Before writing it, name the
production change that would make it fail. If you cannot, it asserts nothing.

See [references/writing-good-tests.md](references/writing-good-tests.md) when writing or
changing any test.

### Verify RED: watch it fail

**Mandatory. Never skip.** Run `verify.test_one`. Confirm it fails rather than errors, the message is
the one you expected, and it fails because the behaviour is missing, not a typo.

Passed immediately? It tests existing behaviour. Errored? Fix and re-run.

### Prefer a real database over a mocked one

Where a behaviour touches persistence, test against a **running** database. A mock proves your code
called a method; a real database proves the stored data is what you meant. They differ on exactly
what matters: constraints, transactions, types, precision, concurrent writes.

Use `verify.test_integration` from the profile.
[references/writing-good-tests.md](references/writing-good-tests.md) covers how, and when a mock is
right.

### GREEN: minimum code

The simplest thing that passes. No extra parameters, no options object, no error handling for
states that cannot occur.

### Verify GREEN: watch it pass

Run `verify.test_one`, then `verify.test`. The new test passes, nothing else broke, output clean.
Still failing? Fix the code, never the test.

### REFACTOR

Only once green. Remove duplication, improve names, extract helpers. No new behaviour. Stay green.

## Exceptions, stated out loud

Not required for a throwaway spike, generated code, or pure configuration. Taking the exception is
fine; taking it silently is not. Say which applies and why, then delete the spike before implementing
properly. "I will tidy it later" means the spike is production code with no tests.

### The project has no test tooling at all

`verify.test` and `test_one` are both `null` and this is **not** greenfield: an established codebase
that never had a runner. None of the three exceptions covers it, and you resolve it in neither
direction yourself. Adding a runner to a years-old service is a standing decision about the
repository, not a step in someone's feature.

Ask, with the three options and their costs set out in
[references/no-test-tooling.md](references/no-test-tooling.md), and record the answer.

## Rationalisations

| Excuse | Reality |
|---|---|
| "Too simple to break" | Simple code breaks. The test costs 30 seconds |
| "I will test after" | It passes immediately, proving nothing. You never saw it fail, so never proved it catches the bug |
| "Tests after achieve the same" | After answers "what does this do?" First answers "what should it do?" |
| "I tested it by hand" | No record of what you covered, no way to re-run it |
| "Deleting hours is wasteful" | Sunk cost. Rewrite with confidence, or keep code you cannot trust |
| "Keep it as reference" | You will adapt it, which is testing after |
| "TDD is slower" | Slower to the first commit, faster to the working one |
| "This code has no tests" | You are improving it. Add one for what you touch. This assumes a runner exists; where none does, see the exception below rather than installing one |
| "The suite is green, do not risk touching it" | It may be green *because* a test asserts the current wrong behaviour. Writing the test first tells you in two minutes, not mid-release |

## Red flags: stop and start over

Code before test. Test written after. Test passed first run. Cannot explain why it failed. "Just this
once." "Spirit not ritual." "This case is different because."

All of these mean: delete the code, start with the test.

## Before claiming done

Every new function has a test. You watched each fail first, for the expected reason. You wrote the
minimum. The suite passes cleanly. Edge cases and error paths are covered. Cannot claim all five? You
skipped TDD.

## Bugs

Never fix a bug without a test reproducing it first. See `keel:debug` for finding the root cause
before you get here.
