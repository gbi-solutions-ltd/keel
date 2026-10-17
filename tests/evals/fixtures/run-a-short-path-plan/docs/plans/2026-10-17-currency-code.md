# Currency code on formatted amounts Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** `format_amount` takes an optional currency code and prints it before the amount.
**Stories:** none, short path: behaviours approved by Amina, 2026-10-17
**ADRs:** 0001 (amounts are whole numbers)
**Architecture:** one optional second argument to `format_amount` in `src/format.sh`; with it the
output is the code, a space and the amount as formatted today, and without it nothing changes.
**Implementer routing:** inherit
**Delivery:** hand-off

## Global constraints

- Verify commands: test `tests/run-tests.sh`, one test `tests/run-tests.sh tests/{name}`
- Never start on `main`
- `hard_block_paths`: `src/auth`
- ADR 0001 requires that amounts are whole numbers and formatting never adds decimals or rounds
- `docs/standards.md` requires `set -uo pipefail` in every test file, snake_case functions with a
  one-line usage comment, a case in `tests/test-<source file>.sh` for every behaviour written
  before the code, and never committing to `main`
- **Delegated mode only: do not run inline, because the spec pass is this plan's only per-task
  review and no plan reviewer ran.**

---

### Task 1: An optional currency code on `format_amount`

**Story:** none, short path
**Files:**
- Modify: `src/format.sh`
- Test: `tests/test-format.sh`

**Depends on:** none

**Behaviours:**

1. A currency code is printed before the amount. Example: `format_amount 1500 UGX` prints
   `UGX 1,500`.
2. With no code the output is unchanged. Example: `format_amount 1500` prints `1,500`.
3. A large amount keeps its separators with a code. Example: `format_amount 1234567 KES` prints
   `KES 1,234,567`.

**Done when:** `tests/run-tests.sh tests/test-format.sh` passes.

- [ ] **Step 1.1: Write the failing tests**

Write a case for each of behaviours 1 to 3 from its example, in `tests/test-format.sh`.

- [ ] **Step 1.2: Run them and watch them fail**

Run: `tests/run-tests.sh tests/test-format.sh`
Expected: FAIL, the cases for behaviours 1 and 3 fail because the code is not printed

- [ ] **Step 1.3: Write the minimal implementation**

Make behaviours 1 to 3 pass: give `format_amount` an optional second argument and, when it is set,
print it and a space before the formatted amount. Update the usage comment.

- [ ] **Step 1.4: Run them and watch them pass**

Run: `tests/run-tests.sh tests/test-format.sh`
Expected: PASS. The tests run at the unit boundary, not per step.

- [ ] **Step 1.5: Run the tests at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

```bash
git add src/format.sh tests/test-format.sh
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(format): an optional currency code on format_amount"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch, say
so and leave it unstaged.
