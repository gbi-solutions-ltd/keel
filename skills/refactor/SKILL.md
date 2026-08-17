---
name: refactor
description: Use when asked to clean up or restructure code, when a file has grown hard to change or duplicated, or before adding a feature to code that is difficult to work in.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# Refactor

## Overview

Change the structure, never the behaviour. Prove it with tests that passed before and after.

**Core principle:** a refactor with no tests is a rewrite with optimism. If you cannot prove
behaviour is unchanged, you are not refactoring.

## Step 1: The precondition, which is not negotiable

Run `profile.verify.test`. The tests must exist and pass **before** you touch anything.

**No tests covering the target?** Then writing them is the whole task for now.
**REQUIRED SUB-SKILL:** `keel:tdd`. Stop there and report; do not write the tests and
continue in the same breath, because tests written to describe code you are about to change tend
to describe the change instead.

**Tests failing?** That is a bug, not a refactoring target. **REQUIRED SUB-SKILL:**
`keel:debug`.

## Step 2: Name the problem in one sentence

"This is messy" is not a problem statement. "Adding a payment provider requires edits in seven
files because the provider choice is a switch statement at `payout.service.ts:412`" is.

If you cannot name the cost concretely, you do not yet have a reason, and a refactor without a
reason is churn that consumes a review slot.

## Step 3: Stay inside the boundary

Refactor what the task named. Not its neighbours, not the file you noticed on the way, not the
formatting.

Notice something else worth doing? Write it down and mention it. Do not do it. A diff mixing
three refactors is unreviewable, and unreviewable is how a behaviour change slips in.

## Step 4: Sequence it, commit per step

Plan the smallest ordered steps that each leave the tests green. Then, per step: make the change,
run `profile.verify.test`, commit.

Committing per step is what makes the whole thing revertible. A single large commit means the
only rollback is all of it.

Green after every step. If a step needs the suite red for a while, it is too big; split it.

## Step 5: Prove behaviour is unchanged

Same tests, same results, no test modified. **A test you had to change is a behaviour change**,
and it needs saying out loud rather than absorbing into the refactor.

If the interface genuinely must change, that is a separate, stated piece of work with its own
review.

## Step 6: Report

What changed structurally, what the tests prove, what you deliberately left alone, and anything
you noticed but did not touch.

## Common mistakes

| Mistake | Instead |
|---|---|
| Refactoring untested code | Write tests first, and stop there |
| Editing a test to make the refactor pass | That is a behaviour change. Say so |
| Fixing the neighbours too | Stay in the boundary. Note the rest |
| Reformatting in the same diff | Separate commit, or let the formatter own it |
| One large commit | One per step, each green |
| "Cleaner" with no stated cost | Name the concrete cost, or leave it |
