# Follow-ups after PR #12 Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for tasks 1 to 4. Tasks 5 and 6 change records and skill text
> and say under their behaviours why they carry no failing test.

**Goal:** close the four follow-ups Bernard chose from PR #12's list: the context-watch state
directory cannot be used by another local user to overwrite a file (audit W-08), the
concurrent-ticks test leaves the evidence its next failure needs, ADR-0011 records the measured
evidence about its "read it before" sentence, and the small text items and three cheap code edges
are fixed.
**Stories:** none. PR #12's "Follow-ups" section; the audit
`docs/audits/2026-11-12-security-plan-execution-speed-2.md` (W-08). Bernard directed on 2026-11-12:
"do the four follow-ups next, starting with W-08".
**ADRs:** ADR-0011 (skill bodies and references; task 5 adds an observation to it); ADR-0017 (suite
checkpoints); ADR-0012 (a task carries two steps).
**Architecture:** `lib/context_watch.py` keeps its state in a per-user directory it has made private
and verified, and `hooks/context-watch`'s cached shortcut reads only from a directory that passes
the same check. `bin/keel`'s plan lock writes a trace when a test asks for one. The rest is small
edits in `hooks/done-guard`, `bin/keel`, `tests/run-tests.sh`, ADR-0011 and skill references.
**Implementer routing:** inherit
**Delivery:** pull-request
**Concurrent batches:** none. Every task adds a line to `CHANGELOG.md`; tasks 3 and 4 share
`bin/keel` and `tests/test-plan.sh`.
**Suite checkpoints:** every 3 tasks.
**Commits that ask:** tasks 1 (`lib/context_watch.py`, `hooks/context-watch`) and 2
(`hooks/done-guard`) stage `hard_block_paths`, so sensitive-guard asks at their commits. They run
first.
**Decided:** by Bernard, 2026-11-12: all four follow-ups, W-08 first; ADR-0011 as a recorded
observation with the convention kept; the fourth follow-up as the text items plus three cheap code
edges (an id holding a newline, `tests/run-tests.sh`'s untested `mkdir` guard, quotes in scoped
prefix words), with done-guard's `time {`, `!` and `timeout` forms and the context-watch timing
items deferred. Decided in this plan and put to Bernard at approval:
- The state directory is `$TMPDIR/keel-context-watch-<euid>` (`/tmp` when `TMPDIR` is unset or
  empty), mode 0700. It is used only when `lstat` shows a real directory (not a symlink) owned by
  this effective user; one that is ours with looser bits is tightened to 0700. When it fails that
  check, as when another local user created it first (the euid is predictable), the state goes to
  `${XDG_CACHE_HOME:-$HOME/.cache}/keel-context-watch`, checked the same way. Running without state
  is not an acceptable fallback: with no stop marker, PreCompact writes the mechanical render over
  the session's own handoff and a plan run loses its `next:` line. Only when both fail does the
  watchdog run without state files, as it does today when the directory cannot be made. The bash
  cached shortcut reads only the `$TMPDIR` location and falls through to python otherwise.
- The lock trace is opt-in through `KEEL_PLAN_LOCK_TRACE`, a file path; with it unset nothing is
  written, so ordinary ticks pay nothing.
**Reviewed:** by a dispatched plan reviewer on 2026-11-12: nothing blocking; should-fix items on
task 1's red expectations (two rounds; `Bash` events), task 1's fail-closed cost (now a fallback
directory), task 3's forced failure (now deterministic), task 2's fixture (`verify.test` pinned) and
task 6's two files, plus `$EUID`, an empty `TMPDIR`, portable mode checks and the trace's order and
failure line. All folded in.
**Approved:** by Bernard, 2026-11-12: routing `inherit`, delivered to a pull request, with the
decisions above as written.
**Shape:** behaviours with examples.

## Global constraints

Every task inherits these.

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test `tests/{name}`,
  lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh
  tests/evals/run.sh tests/evals/stage.sh tests/evals/gate.sh tests/evals/isolation-check.sh
  hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
  hooks/review-guard`. No typecheck, format or build command exists.
- Shellcheck at default severity after each file edit, not at the end.
- Never start on `main`. This plan runs on `fix/follow-ups-after-pr-12`.
- `hooks`, `lib/harness`, `settings.json`, `.github/workflows`, `templates/ci-review.yml` and
  `lib/context_watch.py` are `hard_block_paths`. Tasks 1 and 2 touch them.
- Scripts parse under `/bin/bash` 3.2 (`docs/standards.md`, "Scripts parse under bash 3.2"): python
  in a hook stays in the heredoc read into a variable, never inside `$( )`.
- **No `SKILL.md` body gains words.** New rules go in a reference (ADR-0011).
- A change lands with the live documents it makes wrong, each stating what is true now. Repair the
  citations `tests/validate-citations.sh` flags; do not look for shifted citations in records
  (`docs/plans`, `docs/ideas`, `docs/prd`, `docs/stories`, `docs/architecture`, `docs/decisions`,
  `docs/audits`, `docs/07-open-decisions.md`, `docs/harness-support.md`, the eval fixtures,
  `CHANGELOG.md`). A citation under `docs/plans/` is reported to the coordinator, not edited.
  `hooks/done-guard`, `lib/context_watch.py` and `bin/keel` are hot files: live documents cite
  them by phrase.
- No staged skill or reference file may contain the text `tests/evals`
  (`tests/test-eval-harness.sh`).
- Every test file follows the grep-quiet rule and checks its `mktemp -d` result
  (`tests/test-grep-quiet.sh` enforces both). Never run a test or a mutant with this working tree as
  the place a failed `mktemp` would fall back to; mutate in a throwaway worktree or copy.
- `tests/test-harness-claims.sh` fails any line in `README.md` or `docs/NN-*.md` that names
  `review-guard` or `hard_block_paths`, or uses gate or ceiling vocabulary, without a `keel:claim`
  tag within three lines.
- Add one line for the task under `## Unreleased` in `CHANGELOG.md`.
- No em or en dashes anywhere. Prose wraps at 100 columns. Conventional commit messages, no
  attribution footers.
- Never `git stash`, in any form.
- Suite checkpoints: run no `tests/run-tests.sh`. The coordinator runs it before the first dispatch,
  after task 3 and after the last, and hands you the last record as your start record.

---

### Task 1: the context-watch state directory is private to its user

**Story:** audit W-08
**Files:**
- Modify: `lib/context_watch.py`
- Modify: `hooks/context-watch`
- Modify: `docs/05-token-and-memory-design.md`
- Modify: `CHANGELOG.md`
- Test: `tests/test-context-watch.sh`

**Plan note, 2026-11-12, coordinator:** task 1's quality review showed behaviour 3 unsafe as
written: tightening a loose directory keeps symlinks already planted in it, and the cache write
follows them (reproduced). Behaviour 3 now refuses a directory whose mode is not 0700 (it fails the
check and the fallback is used), the bash shortcut also requires the cache file to be a regular
file owned by this user, a fallback path that is not absolute (no `HOME`) is skipped, and docs/05
names the assumption that the parent directory is sticky or private. The Decided line's "tightened
to 0700" is superseded by this note; reported to Bernard.

**Depends on:** none

**Behaviours:**

1. The state directory is `$TMPDIR/keel-context-watch-<euid>` (`/tmp` when `TMPDIR` is unset or
   empty; python uses `os.geteuid()`, bash `$EUID`), created with mode 0700. Example: under a nested
   `TMPDIR`, after a `Bash` PreToolUse event past the warn threshold,
   `<TMPDIR>/keel-context-watch-<euid>` exists with mode `700` (read portably, with python
   `os.stat`) and holds the session's `.measure` file.
2. A state directory that is a symlink is not used, and nothing is written through it; the state
   goes to the fallback instead. Example: with `<TMPDIR>/keel-context-watch-<euid>` planted as a
   symlink to a scratch directory holding `<sid>.measure` with known content, and
   `XDG_CACHE_HOME` set to a nested temp directory, a `Bash` PreToolUse event (not `Edit`: tools in
   `ALWAYS_ALLOWED` return before any measurement) leaves the planted file unchanged, writes
   `<sid>.measure` under `<XDG_CACHE_HOME>/keel-context-watch` (mode 700), exits 0, and past the
   stop threshold is still denied.
3. A state directory this user owns whose mode is not 0700 is not used, and nothing is written in
   it; the fallback is used instead. Example: pre-created with mode 0777 and holding
   `<sid>.measure` as a symlink to a scratch file, a `Bash` event leaves the scratch file unchanged
   and writes `<sid>.measure` under `<XDG_CACHE_HOME>/keel-context-watch`.
4. `hooks/context-watch`'s cached shortcut reads its cache only from
   `${TMPDIR:-/tmp}/keel-context-watch-$EUID`, and only when it is a real directory owned by this
   user (`[ -d ] && [ ! -L ] && [ -O ]`; `-O` alone is true for a symlink to our directory);
   otherwise it falls through to python. Example: with the directory planted as a symlink to a
   scratch directory holding a fresh low reading for the session, a PreToolUse `Edit` with a
   `python3` shim first on `PATH` records a python call.
5. `docs/05-token-and-memory-design.md`, where it names the state directory, names the per-user
   directory, its check and the fallback. Example: it contains `keel-context-watch-`, `0700` and
   `XDG_CACHE_HOME`.
6. The existing cases that name the old `keel-context-watch` path move to the new one. Example:
   `grep -n 'keel-context-watch"' tests/test-context-watch.sh` finds no path without the suffix.

**Done when:** `tests/test-context-watch.sh`, `tests/test-validate-citations.sh` and
`tests/test-harness-claims.sh` pass.

- [x] **Step 1.1: Build it test first** Note: round 1 reds (107/16, then 123/3) and round 2 reds (125/4, the reviewer's loose-directory exploit among them) quoted; spec COMPLIES after the coordinator repaired one shifted plan citation; quality found loose-dir tightening unsafe (reproduced), fixed in round 2 per the coordinator plan note; quality re-check: nothing blocking, exploit closed, 0700 under umask 022/077/002/000; context-watch 129/0; follow-up: the hook's shortcut comment omits the 0700 mode test

Follow `keel:tdd`, in two rounds. Round one: write behaviour 1's and 3's cases and move the existing
cases to the new name (behaviour 6); they fail against today's shared name; make the rename with the
0700 mode and watch them pass. Round two: write behaviour 2's and 4's cases; against the renamed but
unchecked code they fail (the planted file is overwritten; the shortcut answers from it); add the
check and the fallback and watch them pass.
Run: `tests/test-context-watch.sh`
Expected: FAIL in each round for the reasons above, then PASS. Quote each failing output.

Run: the lint command. With the `Done when:` run above, that is the unit boundary. Run no
`tests/run-tests.sh`: the plan header names suite checkpoints.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [x] **Step 1.2: Hand over** Note: rounds: 2; routing: inherit; loop: full; extra staged: docs/ideas citation repair

```bash
git add lib/context_watch.py hooks/context-watch tests/test-context-watch.sh \
        docs/05-token-and-memory-design.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any flagged citation repairs by name, and stop. **Do not commit.**
The coordinator commits after both review passes, with
`git commit -m "fix(context-watch): keep state in a private per-user directory"`.

---

### Task 2: a scoped prefix with quotes matches the command it describes

**Story:** PR #12 follow-up (done-guard: quotes inside a scoped prefix word never match)
**Files:**
- Modify: `hooks/done-guard`
- Modify: `CHANGELOG.md`
- Test: `tests/test-done-guard.sh`

**Depends on:** task 1

**Behaviours:**

1. A scoped prefix's words lose their quote characters before matching, as the shell would remove
   them from the command. Example: with `verify.test` `tests/run-tests.sh` (as the existing
   fixtures pin it, so `verify.test` is not a substring of the command) and `verify.test_one`
   `./gradlew test --tests '*{name}'` (the form `lib/detect-stack.sh` writes for Gradle), an `Edit`
   of `<repo>/lib/foo.sh` followed by the Bash command `./gradlew test --tests '*FooTest'` counts as
   a run under `required` (exit 0, no output); before, the prefix's last word `'*` could never
   match.
   With the detected Gradle profile, whose `verify.test` is `./gradlew test`, the substring rule
   already counted it, so the bug bit only hand-edited profiles.
2. A command that does not begin with the prefix still does not count. Example: with the same
   profile, `./gradlew build` after the edit blocks.

**Done when:** `tests/test-done-guard.sh`, `tests/test-validate-citations.sh` and
`tests/test-harness-claims.sh` pass.

- [x] **Step 2.1: Build it test first** Note: round 1 red 87/1 quoted; round 2 updated four live docs (spec DEVIATES on them); round 3 fixed a blocking loosening (quotes-only prefix matched everything, reds 89/2); round 4 fixed wrapper-only prefixes and made a complete last word match exactly (reds 91/4); final comparison with HEAD over 25 prefixes and ~90 commands: no loosening, only real test commands newly count; done-guard 95/0; coordinator repaired two follow-ups-plan citations by phrase; follow-ups: the regex fallback still uses unstripped prefixes, bash -x {script} counts any bash -x as at HEAD

Follow `keel:tdd`. Write cases for behaviours 1 and 2 after the existing cases.
Run: `tests/test-done-guard.sh`
Expected before the implementation: FAIL, behaviour 1's case blocks. Expected after: PASS. Quote
the failing output.

Run: the lint command. With the `Done when:` run above, that is the unit boundary. Run no
`tests/run-tests.sh`: the plan header names suite checkpoints.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [x] **Step 2.2: Hand over** Note: rounds: 4; routing: inherit; loop: full

```bash
git add hooks/done-guard tests/test-done-guard.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any flagged citation repairs by name, and stop. **Do not commit.**
The coordinator commits after both review passes, with
`git commit -m "fix(done-guard): a quoted scoped prefix matches its command"`.

---

### Task 3: the plan lock leaves a trace when a test asks for one

**Story:** PR #12's accepted CI race ("concurrent ticks: 19 of 20 landed", twice on Linux CI, not
reproduced in 355 local runs); the follow-up is evidence for its next occurrence, not a guessed fix.
**Files:**
- Modify: `bin/keel`
- Modify: `CHANGELOG.md`
- Test: `tests/test-plan.sh`

**Depends on:** task 2

**Behaviours:**

1. With `KEEL_PLAN_LOCK_TRACE` set to a file path, `plan_lock` appends a line when it acquires the
   lock, `plan_unlock` one before it releases and one after, and the EXIT trap one when it releases
   for a tick that dies holding the lock; each names the event and the process id. Lines are
   appended in order, and the order in the file is the evidence, since a timestamp is too coarse to
   order a race. A failed `rmdir` in `plan_unlock` is written as `release-failed <pid> <error>` in
   place of `released`, and its error still reaches stderr as today (both callers ignore
   `plan_unlock`'s status). Example: one tick with the variable set leaves three lines,
   `acquire <pid>`, `release <pid>` and `released <pid>`, with the same process id.
2. With the variable unset, nothing is written. Example: a tick with it unset creates no trace file
   at a path a test watches.
3. The concurrent-ticks case sets the variable, and on failure prints the trace with its other
   evidence. Example: in a throwaway copy of `tests/test-plan.sh` with the case's expected count
   changed from 20 to 21, the case fails and its message includes the trace's `acquire` lines.

**Done when:** `tests/test-plan.sh` passes.

- [ ] **Step 3.1: Build it test first**

Follow `keel:tdd`. Write cases for behaviours 1 and 2, then change the concurrent-ticks case.
Run: `tests/test-plan.sh`
Expected before the implementation: FAIL, behaviour 1's case (no trace file). Expected after: PASS.
Quote the failing output. Show behaviour 3 by the forced failure in the throwaway copy, quoted.

Run: the lint command. With the `Done when:` run above, that is the unit boundary. Run no
`tests/run-tests.sh`: the coordinator runs the checkpoint after this task.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 3.2: Hand over**

```bash
git add bin/keel tests/test-plan.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any flagged citation repairs by name, and stop. **Do not commit.**
The coordinator commits after both review passes, with
`git commit -m "test(plan): trace the plan lock for the concurrent-ticks race"`.

---

### Task 4: two cheap code edges

**Story:** PR #12 follow-ups (`keel plan tick` splits an argument holding a newline;
`tests/run-tests.sh` has an untested `mkdir -p` guard)
**Files:**
- Modify: `bin/keel`
- Modify: `tests/run-tests.sh`
- Modify: `CHANGELOG.md`
- Test: `tests/test-plan.sh`

**Depends on:** task 3

**Behaviours:**

1. `keel plan tick` refuses an id that holds a newline, naming it as not one id, and changes
   nothing. Example: `keel plan tick p.md "$(printf '1.1\n1.2')"` exits non-zero, the message says
   an id is one line, and both steps stay open.
2. `tests/run-tests.sh` makes the durations file's directory unconditionally: a partial run that
   writes no file leaves at most an empty `.keel/`, which git never tracks, and the guard no test
   could tell from its absence goes. The comment above it says so. Example: the line reads
   `mkdir -p "$(dirname "$DURATIONS")"` with no `RECORD` test, and `tests/test-run-tests.sh` passes.

**Done when:** `tests/test-plan.sh` and `tests/test-run-tests.sh` pass.

- [ ] **Step 4.1: Build it test first**

Follow `keel:tdd`. Write behaviour 1's case after the several-ids tick cases.
Run: `tests/test-plan.sh`
Expected before the implementation: FAIL, behaviour 1's case (both steps are ticked). Expected
after: PASS. Quote the failing output. Behaviour 2 removes code no test observes; its check is
`tests/test-run-tests.sh` passing after it.

Run: `tests/test-run-tests.sh` and the lint command. With the `Done when:` runs, that is the unit
boundary. Run no `tests/run-tests.sh` as the suite: the plan header names suite checkpoints.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 4.2: Hand over**

```bash
git add bin/keel tests/test-plan.sh tests/run-tests.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any flagged citation repairs by name, and stop. **Do not commit.**
The coordinator commits after the review pass, with
`git commit -m "fix(plan): an id is one line; run-tests makes its state directory plainly"`.

---

### Task 5: ADR-0011 records the evidence on its "read it before" sentence

**Story:** PR #12 follow-up (the speed-2 sweep's measurement); Bernard decided on 2026-11-12 to
record it and keep the convention.
**Files:**
- Modify: `docs/decisions/ADR-0011-skill-bodies-hold-instructions-and-references-hold-the-rest.md`
- Modify: `CHANGELOG.md`

**Depends on:** task 4

**Behaviours:** this task changes a decision record and has no failing test; each example is
checked by a reader against the diff and by the commands in `Done when:`.

1. ADR-0011 gains a dated `Observed` entry (in its own section after Consequences or Verification,
   whichever the ADR's form suits, the earlier text untouched) stating: the 2026-11-12 speed sweep
   (`docs/ideas/plan-execution-speed-2.md`, item 8) found implementers did not read `tdd`'s
   step-detail reference even with the "read it before" sentence; Bernard decided the same day to
   keep the convention; and what would reopen it (an eval arm showing the sentence makes no
   difference to whether the reference is read). Example: ADR-0011 contains `Observed`,
   `2026-11-12` and `plan-execution-speed-2`.
2. The ADR's status stays `accepted`. Example: its Status row is unchanged.

**Done when:** `tests/test-doc-claims.sh` and `tests/test-validate-citations.sh` pass, and
`grep -c 'plan-execution-speed-2' docs/decisions/ADR-0011*.md` prints at least `1`.

- [ ] **Step 5.1: Make the change and check it**

Edit as the behaviours say.
Run: the `Done when:` commands and the lint command. Run no `tests/run-tests.sh`.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 5.2: Hand over**

```bash
git add docs/decisions/ADR-0011-skill-bodies-hold-instructions-and-references-hold-the-rest.md \
        CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after the review
pass, with `git commit -m "docs(adr): ADR-0011 records the read-it-before evidence"`.

---

### Task 6: the small text items

**Story:** PR #12 follow-ups (wording)
**Files:**
- Modify: `skills/tdd/references/rationale.md`
- Modify: `skills/review-code/references/step-detail.md`
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `tests/test-run-tests.sh`
- Modify: `CHANGELOG.md`

**Depends on:** task 5

**Behaviours:** this task changes text and has no failing test; each example is checked by a reader
against the diff and by the commands in `Done when:`.

1. `skills/tdd/references/rationale.md:19` stops saying `review-code` always runs the suite: it
   runs it, or quotes a qualifying plan-end checkpoint, and `ship` always runs it. Example: the line
   no longer reads `` `review-code` and `ship` still run the suite``.
2. `review-code`'s reuse condition names the plans directory the profile sets: `artifacts.plans`
   from `.keel/profile.json`, else `<docs_root>/plans/`. Example: `step-detail.md` contains
   `artifacts.plans`.
3. The checkpoint offer says what an open task is: a task with any step not done, deferred or not
   applicable, as `keel plan status` counts it. Both places that state the offer say so
   (`subagent-prompts.md`'s suite checkpoints section and `plan-template.md`'s checkpoints
   paragraph). Example: each contains `keel plan status` within two lines of `3 or more open tasks`.
4. The plan template names `CHANGELOG.md` one way in both places: records are its released entries,
   and each task's line goes under `## Unreleased`. Example: the paragraph near the records list
   that names `CHANGELOG.md` says `released`.
5. `tests/test-run-tests.sh`'s lines are at most 100 columns. Example:
   `awk 'length > 100' tests/test-run-tests.sh` prints nothing, and the file passes.

**Done when:** `tests/test-validate-skills.sh`, `tests/test-validate-citations.sh`,
`tests/test-eval-harness.sh`, `tests/test-run-tests.sh` and `tests/test-grep-quiet.sh` pass, and
`awk 'length > 100' tests/test-run-tests.sh` prints nothing.

- [ ] **Step 6.1: Make the change and check it**

Edit as the behaviours say.
Run: the `Done when:` commands and the lint command. Run no `tests/run-tests.sh` as the suite.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 6.2: Hand over**

```bash
git add skills/tdd/references/rationale.md skills/review-code/references/step-detail.md \
        skills/execute-plan/references/subagent-prompts.md \
        skills/write-plan/references/plan-template.md tests/test-run-tests.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after the review
pass, with `git commit -m "docs(skills): small follow-up wording"`.
