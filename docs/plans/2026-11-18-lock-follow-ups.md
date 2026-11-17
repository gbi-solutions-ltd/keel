# Plan Lock Follow-ups Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** the six "consider" follow-ups recorded in `docs/plans/2026-11-17-lock-churn.md`'s
Delivery section are settled before 0.30.0: a dead holder is named at once, a lock that keeps
changing hands at the poll limit is not reported as uncreatable, a tick removes only a lock holding
its own pid, mixed versions are documented, and comments state behaviour rather than history.
**Stories:** none, short path: behaviours approved by Bernard, 2026-11-18
**ADRs:** none
**Architecture:** all in `plan_lock`, `plan_unlock` and the EXIT trap in `bin/keel`. The lock
is never removed by a waiter, even a stale one: two waiters both judging it stale would each remove
the other's fresh lock. A dead holder therefore ends the wait early with a message, as the poll
limit does now. "Dead" is `kill -0 <pid>` failing and `ps -p <pid>` exiting 1, with the lock still
holding that pid when read again afterwards; `kill -0` alone also fails for a live process of
another user (EPERM), and a holder may release between the read and the check. Without `ps`, or
on any other answer, the 100-poll wait is kept. A pid is checked on this machine only, which the
message says, since a plan shared into a container sees other pids.
The signal window between the create and the EXIT trap (follow-up 2) is not closed: bash runs a
trap only between commands, so a window always remains, and moving the create out of its subshell
would let `set -C` reach the rest of keel. The lock it leaves holds a dead pid, which task 1 now
names at once; that is the resolution, recorded here.
Mixed versions (follow-up 3): 0.29.0's `mkdir` fails on the new lock file and waits, and the new
lock treats 0.29.0's directory as held, so exclusion holds both ways (read from
`git show v0.29.0:bin/keel`); only 0.29.0's give-up hint, `rm -r`, is wrong for a file. That is
documented, since released code cannot change.
**Implementer routing:** inherit
**Commits that ask:** none
**Delivery:** pull-request

## Global constraints

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}` (so `tests/test-plan.sh`),
  lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh tests/evals/gate.sh tests/evals/isolation-check.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard hooks/review-guard`,
  at default severity.
- **Delegated mode only: do not run inline, because the spec pass is this plan's only per-task
  review and no plan reviewer ran.**
- Never commit on `main`; this runs on `fix/lock-follow-ups`.
- No em dash, no en dash, no dash longer than a hyphen. No attribution footers. Commits are
  conventional and signed off (`git commit -s`), since CI checks DCO.
- Extend the existing `## Unreleased` entry in `CHANGELOG.md`, terse, in its style. Released
  entries are records: never edit them. Keep the entry to an even number of lines:
  `docs/plans/2026-11-12-plan-execution-follow-ups.md` cites `CHANGELOG.md:28` and
  `tests/validate-citations.sh` fails when a blank line lands there.
- Skill and doc text names no real project. The comment above `plan_lock`, the one above
  `plan_unlock`, and the lock paragraph in `docs/03-install-and-distribution.md` are the live
  descriptions of the lock and must state what is true after the change, as behaviour, not as a
  history of measurements. The comment above `plan_lock` is already long: rewrite it, do not
  append to it.
- `tests/test-plan.sh` passes under bash 5 and `/bin/bash` 3.2.

### Task 1: a dead holder is named at once, and a lock changing hands is waited on

**Story:** none (short path)
**Files:**
- Modify: `bin/keel`
- Modify: `tests/test-plan.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Docs searched:** "<plan>.lock", "cannot create", "is held", "killed". Hits: the lock paragraph
of `docs/03-install-and-distribution.md`, the comment above `plan_lock` and its messages in
`bin/keel`, the `## Unreleased` entry in `CHANGELOG.md`, and the lock cases in
`tests/test-plan.sh`.

**Depends on:** none

**Behaviours:**

1. A lock holding the pid of a process not running on this machine ends the wait at once: the tick
   gives up on its first poll that finds it, naming the lock and the pid, saying the process is not
   running on this machine and to remove it with `rm -f <plan>.lock`, and changes nothing; the lock
   is left. Example: `echo <pid of a finished background job> > <plan>.lock`, then a tick exits
   non-zero with that pid and `rm -f <plan>.lock` in its message, the plan and the lock unchanged,
   and the counting `sleep` shim records no more than 1 sleep.
2. A live holder is waited on as now: with the pid of a running process in the lock (a backgrounded
   `sleep`, or pid 1, which `kill -0` refuses with EPERM to a non-root user but `ps -p` finds), the
   tick waits the full 100 polls. Example: the "exactly 99 sleeps" case and the stale-lock case,
   moved from `12345` (now possibly dead) to a live pid, still count 99 and still give up naming
   the lock; the busy-queue case writes live pids, not poll numbers.
3. A holder that releases between the waiter's read and its check is not reported dead: the lock
   is read again after the check, and only the same pid still there counts. Example: the code
   (the window is not reachable from a test), and the concurrent-ticks case collects no "not
   running" in any tick's stderr.
4. Without `ps` on PATH, or with `ps` failing other than with exit 1, a dead pid is waited on for
   the 100 polls as before. Example: a PATH shim `ps` that exits 127, with a dead pid in the lock,
   gives up after 99 sleeps with the held message.
5. "cannot create" at the poll limit means the create failed with nothing at the path on 100
   consecutive polls, counted apart from polls behind a holder: a lock that is held, released and
   gone on alternate polls is never reported as uncreatable. Example: the ENAMETOOLONG and
   `ulimit -f 0` cases still end in "cannot create" with nothing left; a sleep shim that removes
   the lock on even calls and writes a live pid into it on odd ones, stopping at 150, sees the tick
   land, with no "cannot create".

**Done when:** `tests/test-plan.sh` passes under bash 5 and `/bin/bash` 3.2, and
`tests/validate-citations.sh` exits 0.

- [x] **Step 1.1: Build it test first** Note: red witnessed by the implementer (670 passed, 1 failed, behaviour 1); behaviours 4 and 5 green on arrival, by design; bash 5.2 run by the coordinator in a container, 667 passed (3 skipped as root or no checkout)

Follow `keel:tdd` for each behaviour: write or adapt its case from the example, run it, and watch
it fail for the reason the behaviour names, then change `plan_lock` and watch every case pass. Say
in the report which existing cases you moved to a live pid and why.
Run: `tests/test-plan.sh`, `/bin/bash tests/test-plan.sh` and `tests/validate-citations.sh`
Expected before the implementation: FAIL, the cases for behaviours 1, 4 and 5. Expected after:
PASS. Quote the failing cases and their messages.

Run: the lint command from Global constraints. Run no `tests/run-tests.sh`: the coordinator runs it
once after this task. Expected: PASS. This is the one boundary run the task schedules.

- [x] **Step 1.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES

```bash
git add bin/keel tests/test-plan.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after the review
pass, with `git commit -s -m "fix(plan): name a dead lock holder at once, and wait on a lock changing hands"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 2: a tick removes only a lock holding its own pid

**Story:** none (short path)
**Files:**
- Modify: `bin/keel`
- Modify: `tests/test-plan.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`

**Docs searched:** "release", "exit-released", "rm -r", "older keel". Hits: the comment above
`plan_unlock` and the EXIT trap in `bin/keel`, the trace cases in `tests/test-plan.sh`, and the
lock paragraph of `docs/03-install-and-distribution.md`.

**Depends on:** task 1

**Behaviours:**

1. Release, from `plan_unlock` or the EXIT trap, removes `<plan>.lock` only when it is a regular
   file whose first line is the tick's own pid. Otherwise it leaves whatever is there, says on
   stderr that the lock was no longer this tick's (removed or taken while held, so the tick's write
   was not exclusive), and the tick exits non-zero. Example: a shim `mktemp` that, while the tick
   holds the lock, replaces it with `echo 999 > <plan>.lock` and then runs the real `mktemp` (the
   `plan_unlock` path), and one that replaces it and exits 1 (the EXIT trap path); each tick exits
   non-zero with that message and `<plan>.lock` still holds 999.
2. The trace keeps `acquire`, `release`, `released` and `exit-released` unchanged for a tick that
   releases its own lock, and records a mismatch as a new event, `release-not-ours <pid> <found>`,
   in place of `released` or `exit-released`. Example: the existing trace cases pass unchanged; the
   case from behaviour 1 with `KEEL_PLAN_LOCK_TRACE` set ends in `release-not-ours`.
3. The comment above `plan_unlock` and any test comment narrating past measurements (such as
   "18 of 20 ... landed" or "3, 9 and 6 of 20 landed in three runs while planning") state the
   behaviour instead. Example: grep for "of 20" and "while planning" in the lock code and lock
   cases finds nothing.
4. `docs/03-install-and-distribution.md` and the `## Unreleased` entry say that a 0.29.0 or older
   tick on the same plan still takes turns with a newer one, but its give-up message advises
   `rm -r` for what is now a file, so `rm -f` is the command, and that every tick on a plan should
   run the same keel. Example: grep finds the sentence in both.

**Done when:** `tests/test-plan.sh` passes under bash 5 and `/bin/bash` 3.2, and
`tests/validate-citations.sh` exits 0.

- [x] **Step 2.1: Build it test first** Note: red witnessed by the implementer (671 passed, 4 failed); bash 5.2 run by the coordinator in a container, 671 passed (as root, 4 skipped); CHANGELOG grew 3 lines, not an even number, accepted: the constraint's purpose, a non-blank CHANGELOG.md:28, holds

Follow `keel:tdd`: write behaviour 1's and 2's cases, run them, and watch them fail because the
tick removes a lock that is not its own, then change `plan_unlock` and the EXIT trap and watch them
pass. Then make the comment and doc changes of behaviours 3 and 4.
Run: `tests/test-plan.sh`, `/bin/bash tests/test-plan.sh` and `tests/validate-citations.sh`
Expected before the implementation: FAIL, behaviours 1's and 2's cases. Expected after: PASS.
Quote the failing cases and their messages.

Run: the lint command from Global constraints. Run no `tests/run-tests.sh`: the coordinator runs it
after this task. Expected: PASS. This is the one boundary run the task schedules.

- [x] **Step 2.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES

```bash
git add bin/keel tests/test-plan.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after the review
pass, with `git commit -s -m "fix(plan): a tick removes only a lock holding its own pid"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 3: the cannot-create count is proved, and a dead holder is judged only by a working ps

**Task 3 added:** 2026-11-18, from the review-code pass on e9e09db; Bernard's standing ask is that
should-fix follow-ups go into the same pull request.

**Story:** none (short path)
**Files:**
- Modify: `bin/keel`
- Modify: `tests/test-plan.sh`
- Modify: `docs/03-install-and-distribution.md`

**Docs searched:** "not running on this machine", "was no longer this tick's", "ps -p". Hits: the
messages and the comment above `plan_lock` in `bin/keel`, the lock paragraph of
`docs/03-install-and-distribution.md`, which states the dead-holder rule and the not-ours outcome,
and the lock cases in `tests/test-plan.sh`. (Amended 2026-11-18 after the first attempt: the plan
first said the paragraph was unchanged, which was wrong.)

**Depends on:** task 2

**Behaviours:**

1. Task 1's behaviour 5 has a case that can fail: polls finding nothing at the path are counted
   apart from held polls, and a held poll resets them, so a lock that is held on one poll and
   absent on the next, with every create failing, is not reported as uncreatable at poll 100.
   Example: the tick runs under `ulimit -S -f 0` with SIGXFSZ ignored, so every create's pid write
   fails and nothing is left; a sleep shim raises its own soft limit, writes a live pid into the
   lock on odd calls and removes it on even ones, and removes it for good at call 150. The tick's
   message is "cannot create", given only once the lock has been absent for 100 polls in a row
   after call 150 (the shim counts at least 249 sleeps). Reverting the reset of the nothing-there
   count makes the case fail, giving up near call 175.
2. A dead holder is judged only where `ps -p` works: `ps -p $$` must exit 0 before an exit 1 for
   the holder's pid counts as not running; otherwise the 100-poll wait is kept. Example: a PATH
   shim `ps` that exits 1 for every pid, its own included (as a `ps` without `-p` would), with a
   dead pid in the lock, gives up after 99 sleeps with the held message.
3. The not-ours message is true on both release paths: it says that if this tick wrote the plan,
   the write was not exclusive. Example: the four taken-while-held cases match the new wording.
4. (Added after the first attempt.) A pid write that fails prints nothing: bash keeps a failed
   builtin write's output and flushes it to the tick's own stdout, so the pid appeared once a poll.
   The create's subshell sends its stdout to /dev/null. Example: the full-disk (`ulimit -f 0`) case
   and behaviour 1's case assert that the tick's output holds no line that is only its pid.
5. (Added after the first attempt.) The lock paragraph of `docs/03-install-and-distribution.md`
   states behaviour 2's `ps -p` condition and behaviour 3's wording. Example: grep finds both.

**Done when:** `tests/test-plan.sh` passes under bash 5 and `/bin/bash` 3.2, and
`tests/validate-citations.sh` exits 0.

- [x] **Step 3.1: Build it test first** Note: red witnessed by the implementer (671 passed, 5 failed; behaviour 1 red under the revert, 174 polls); fix pass for behaviours 4 and 5 red witnessed (674 passed, 2 failed); bash 5.2 run by the coordinator in a container, 672 passed (as root)

Follow `keel:tdd`: write behaviour 1's and 2's cases and adapt behaviour 3's, run them, and watch
behaviour 2's and 3's fail for the reasons they name. Behaviour 1's case passes on arrival, since
task 1 already counts apart: prove it can fail instead by reverting the reset of the nothing-there
count (in a scratch copy or by hand, restored after), running it, and quoting the failure. Then
change `plan_lock` and `plan_lock_ours` and watch every case pass. Keep the comment above
`plan_lock` true.
Run: `tests/test-plan.sh`, `/bin/bash tests/test-plan.sh` and `tests/validate-citations.sh`
Expected before the implementation: FAIL, behaviours 2's and 3's cases, and behaviour 1's under
the revert. Expected after: PASS. Quote the failing cases and their messages.

Run: the lint command from Global constraints. Run no `tests/run-tests.sh`: the coordinator runs it
after this task. Expected: PASS. This is the one boundary run the task schedules.

- [x] **Step 3.2: Hand over** Note: rounds: 2; routing: inherit; loop: light; spec COMPLIES

```bash
git add bin/keel tests/test-plan.sh docs/03-install-and-distribution.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after the review
pass, with `git commit -s -m "fix(plan): prove the cannot-create count, and trust ps -p only where it works"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

## Delivery

- review-code: nothing blocking (2026-11-18, base 182baa9); its one should fix, behaviour 5's case
  unable to fail, became task 3 with two of its considers (a `ps` without `-p`, the not-ours
  message on the EXIT path)
