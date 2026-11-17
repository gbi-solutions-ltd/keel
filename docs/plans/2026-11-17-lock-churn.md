# Lock Churn Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** a `keel plan tick` waiting on a busy lock keeps waiting when the lock changes hands
between its checks, instead of dying with "cannot create ... lock" and losing its tick.
**Stories:** none, short path: behaviours approved by Bernard, 2026-11-17
**ADRs:** none
**Architecture:** `plan_lock` in `bin/keel` retries a failed `mkdir` once when the lock is absent,
then dies if the lock is still absent, reading that as a directory it cannot write. Under load
another tick can take and free the lock inside that window twice, so the waiter dies wrongly. The
fix decides "cannot be locked" from the plan's directory (not a writable directory), and otherwise
keeps polling as for a held lock.
**Implementer routing:** inherit
**Commits that ask:** none
**Delivery:** pull-request

## Global constraints

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}` (so `tests/test-plan.sh`),
  lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh tests/evals/gate.sh tests/evals/isolation-check.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard hooks/review-guard`,
  at default severity.
- **Delegated mode only: do not run inline, because the spec pass is this plan's only per-task
  review and no plan reviewer ran.**
- Never commit on `main`; this runs on `fix/lock-churn`.
- No em dash, no en dash, no dash longer than a hyphen. No attribution footers. Commits are
  conventional and signed off (`git commit -s`), since CI checks DCO.
- One line under a new `## Unreleased` heading above `## 0.29.0` in `CHANGELOG.md`, terse, in the
  style of the 0.29.0 entries. Released entries are records: never edit them.
- `bin/keel`'s comment above `plan_lock` is the live description of the lock: it states what is
  true after the change.

### Task 1: a waiter that sees the lock change hands keeps waiting

**Story:** none (short path)
**Files:**
- Modify: `bin/keel`
- Modify: `tests/test-plan.sh`
- Modify: `CHANGELOG.md`

**Docs searched:** "cannot create", "retried once", "plan_lock". Hits: only the comment above
`plan_lock` in `bin/keel` and the existing read-only-directory case in `tests/test-plan.sh`; no
live document describes the retry.

**Depends on:** none

**Behaviours:**

1. A tick whose lock `mkdir` fails while the lock is absent, in a directory it can write, keeps
   polling and lands. Example: a PATH shim `mkdir` that fails for the lock path on its first three
   calls (the lock never existing) and then runs the real `mkdir`; `keel plan tick <plan> 1.1`
   exits 0, step 1.1 is ticked, no `<plan>.lock` is left, and the output has no "cannot create".
2. A tick on a plan whose directory it cannot write still fails at once with "cannot create" and
   no "is held", in under 5 seconds, changing nothing: the existing case
   "tick that cannot create its lock fails at once, saying so" passes unchanged.
3. Twenty ticks started together all land: the existing concurrent-ticks case passes unchanged.

**Done when:** `tests/test-plan.sh` passes.

- [ ] **Step 1.1: Build it test first**

Follow `keel:tdd` for behaviour 1: write its case from the example, run it, and watch it fail
because the tick dies with "cannot create", then change `plan_lock` and watch it pass, with
behaviours 2 and 3 still passing.
Run: `tests/test-plan.sh`
Expected before the implementation: FAIL, behaviour 1's case fails with "cannot create" in the
output. Expected after: PASS. Quote the failing case and its message.

Run: the lint command from Global constraints. Run no `tests/run-tests.sh`: the coordinator runs it
once after this task. Expected: PASS. This is the one boundary run the task schedules.

- [ ] **Step 1.2: Hand over**

```bash
git add bin/keel tests/test-plan.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after the review
pass, with `git commit -s -m "fix(plan): a tick waiting on a lock that changes hands keeps waiting"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.
