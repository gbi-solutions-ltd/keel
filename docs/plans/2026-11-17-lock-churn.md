# Plan Lock File Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** `keel plan tick` takes its lock with a primitive that is atomic whatever `mkdir` the
system ships, so concurrent ticks never both hold it, and a waiter whose lock changes hands keeps
waiting instead of dying with "cannot create".
**Stories:** none, short path: behaviours approved by Bernard, 2026-11-17
**ADRs:** none
**Architecture:** the cause, measured 2026-11-17: Ubuntu 26.04 (GitHub's `ubuntu-latest`) ships
uutils coreutils, whose `mkdir` 0.10.0 exits 0 for both of two processes racing to create one
path (965 of 2000 trials), so `plan_lock`'s `mkdir "$1.lock"` let two ticks hold the lock and one
tick was lost. A CI probe (draft PR #17) traced two `mkdir` successes back to back on a fresh path.
Bash's own exclusive create, `set -C` then `>`, which opens with `O_EXCL`, double-succeeded 0 of
2000 times on the same image. `<plan>.lock` becomes a file created that way, holding the tick's
pid; release removes it. The wait, stale-lock and trace behaviour stay as they are. Separately,
under load a waiter could see the lock absent twice and die as if its directory were unwritable;
"cannot be locked" is now decided from the directory itself.
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
- One entry under a new `## Unreleased` heading above `## 0.29.0` in `CHANGELOG.md`, terse, in the
  style of the 0.29.0 entries. Released entries are records: never edit them. Keep the entry to an
  even number of lines: `docs/plans/2026-11-12-plan-execution-follow-ups.md` cites `CHANGELOG.md:28`
  and `tests/validate-citations.sh` fails when a blank line lands there.
- Skill and doc text names no real project. The comment above `plan_lock` in `bin/keel` and the
  lock paragraph in `docs/03-install-and-distribution.md` are the live descriptions of the lock and
  must state what is true after the change.

### Task 1: the plan lock is a file created exclusively

**Story:** none (short path)
**Files:**
- Modify: `bin/keel`
- Modify: `tests/test-plan.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Docs searched:** "<plan>.lock", "plan.lock", "rm -r", "cannot create", "owner file". Hits:
`docs/03-install-and-distribution.md` (the lock paragraph in the `keel plan status` section), the
comment above `plan_lock` and its messages in `bin/keel`, and the lock cases in
`tests/test-plan.sh`. `skills/execute-plan/references/parallel-batches.md` names `.git/index.lock`,
which is git's and unchanged.

**Depends on:** none

**Behaviours:**

1. The lock does not depend on `mkdir`: with a PATH shim `mkdir` that always exits 0 without
   creating anything (as a racing uutils `mkdir` can), twenty ticks started together on one plan
   all land and no `<plan>.lock` is left. Example: the concurrent-ticks case run with that shim
   first on PATH gives 20 of 20.
2. `<plan>.lock` is a regular file holding the holding tick's pid while it is held, created with
   `set -C`, and removed on release; the EXIT trap still removes it when a tick dies holding it.
   Example: the existing trace cases still read `acquire <pid>`, `release <pid>`,
   `released <pid>` and `exit-released <pid>`, and a tick that dies after taking the lock leaves
   no `<plan>.lock`.
3. Waiting keeps its rules, on the file: a waiter counts polls only behind one holder (the pid in
   the file), restarting when it changes, an empty lock file counts as one holder, and after 100
   polls behind one holder the tick gives up naming the lock and changing nothing; the message
   says to remove it with `rm -f <plan>.lock`. Example: the busy-queue, no-owner and stale-lock
   cases pass with the lock faked as a file (`echo 12345 > <plan>.lock`, or an empty file).
4. A lock that keeps changing hands is waited on, not reported as uncreatable: "cannot create" is
   printed only when the plan's directory is missing or not writable, and a failed exclusive
   create with the lock already gone again in a writable directory polls again. The window is a
   few microseconds, so no shim reaches it; the example is the code and its absence from load:
   `plan_lock` has no branch that dies on the lock being absent while the directory is writable,
   and the concurrent-ticks case collects no "cannot create" in any tick's stderr.
5. A plan in a directory the tick cannot write still fails at once with "cannot create" and no
   "is held", in under 5 seconds, changing nothing (the existing case, unchanged). A directory
   left at `<plan>.lock` by an older keel is treated as a held lock, and the give-up message names
   it so it can be removed (`rm -r` for a directory). Example: `mkdir <plan>.lock` then a tick
   gives up after the poll limit with the path in its message.

**Done when:** `tests/test-plan.sh` passes.

- [x] **Step 1.1: Build it test first** Note: red witnessed by the implementer (655 passed, 6 failed); behaviour 4 cannot be shown red by design

Follow `keel:tdd` for each behaviour: write or adapt its case from the example, run it, and watch
it fail for the reason the behaviour names (behaviour 1 fails because the shim `mkdir` lets ticks
share the lock), then change `plan_lock`, `plan_unlock` and the EXIT trap, and watch every case
pass. The existing lock cases that fake a held lock with `mkdir` change to a file; say which you
changed and why in the report.
Run: `tests/test-plan.sh`
Expected before the implementation: FAIL, the cases for behaviours 1, 3 (faked as a file) and 4
fail. Expected after: PASS. Quote the failing cases and their messages.

Run: the lint command from Global constraints, and `tests/validate-citations.sh`. Run no
`tests/run-tests.sh`: the coordinator runs it once after this task. Expected: PASS. This is the
one boundary run the task schedules.

- [x] **Step 1.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES; Ubuntu 26.04 container: main lost a tick in 39 of 100 rounds, the fix in 0 of 100

```bash
git add bin/keel tests/test-plan.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after the review
pass, with `git commit -s -m "fix(plan): take the plan lock with an exclusive file create, not mkdir"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.
