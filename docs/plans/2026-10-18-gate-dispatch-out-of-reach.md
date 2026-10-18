# Eval arms are dispatched only from a workspace with nothing else within reach Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** address L-01 of `docs/audits/2026-10-18-security.md` before 0.25.0: `tests/evals/gate.sh`
stages and never dispatches; a generated `OUT/dispatch.sh` dispatches, and refuses while anything
keel-shaped is reachable outside the staged directories; the documents say a gate runs in a
disposable workspace holding no personal credentials and no other repositories, and say plainly what
the check does not see.
**Stories:** none. The input is L-01 and Bernard's answer of 2026-10-18 below.
**ADRs:** ADR-0005
**Architecture:** the dispatch half of `gate.sh` moves into a script `gate.sh` writes into `OUT`,
beside a copy of `tests/evals/isolation-check.sh` and the list of scenario names, so the dispatch
runs from `OUT` after the checkout is gone and checks by name that it is. Each arm's stdin is
`/dev/null`. The check matches keel-shaped names only; credentials and other repositories are kept
out of reach by where the gate is run, which the README and runbook state and the audit's status
records.
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Concurrent batches:** none. Task 2 depends on task 1.

## What Bernard decided, 2026-10-18

- **L-01:** "Fix it first, own plan": `gate.sh` only stages and writes `OUT/dispatch.sh`, which runs
  after the checkout is removed, refuses unless `isolation-check.sh` passes, and closes stdin;
  README and runbook corrected. The 0.25.0 gate run at `d5dad6a` stands, on the judgement recorded
  in task 2 behaviour 5.
- **Routing**, standing: implementation on Sonnet (`keel-implementer`); planning and reviews on
  Opus.

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test `tests/{name}`,
  lint `shellcheck -x` on the files the profile names. shellcheck is not on the Mac's VM: lint in
  the implementer's own container.
- Work on `sandbox`, never on `main`.
- `gate.sh` and the script it writes stay portable to bash 3.2 and BSD userland, as `gate.sh`'s
  header says: no arrays expanded empty under `set -u`, no `mapfile`, no GNU-only flags.
- `docs/standards.md`: no em or en dashes; prose lines at most 100 columns; relative links resolve.
  Run `bash tests/validate-citations.sh` after any change to a file other docs cite by line, and
  repoint what moved: a dated record is pinned as "line N at `<commit>`", a live document follows
  the text.
- Name paths when staging. Never `git add -A`, `git add .` or `git commit -a`. Do not commit; the
  coordinator does.

---

### Task 1: `gate.sh` stages; `OUT/dispatch.sh` dispatches behind the isolation check

**Files:**
- Modify: `tests/evals/gate.sh` and `tests/test-eval-harness.sh`

**Depends on:** none

**Behaviours:**

1. `gate.sh` never runs `claude`, with or without `--dry-run`. Its options, its refusals for `OUT`
   and its staging are unchanged, and it also refuses an `OUT` whose last part starts `keel-eval-`,
   which the isolation check would report. After staging, whether or not some stages failed and with
   or without `--dry-run`, it writes three files into `OUT`: `dispatch.sh`; a copy of
   `tests/evals/isolation-check.sh` as `isolation-check.sh`; and `scenario-names.txt`, holding for
   each `tests/evals/scenarios/*.md` its basename without `.md`, one per line. Its exit code is as
   today: 1 when a stage failed, 0 otherwise. With `--dry-run` it also prints each dispatch line as
   today, built from the same flags, ending `< /dev/null`. On stderr it prints the next step,
   without the strings `claude -p` or `TMPDIR=`: run `bash OUT/dispatch.sh` from a disposable
   workspace that holds no keel checkout, no personal credentials and no other repositories.
   Example: `gate.sh /w/out` with a stub `claude` on `PATH` leaves the stub's log empty and
   `/w/out/dispatch.sh` present.
2. `OUT/dispatch.sh` is generated so that it holds no path to the repository or to `OUT`: it finds
   its own directory at run time with `here="$(cd "$(dirname "$0")" && pwd -P)"`; it carries
   `gate.sh`'s model and flags, written into it with `printf %q` from `gate.sh`'s own `flags` array
   and `$model` (the model added by branch as `gate.sh` does today); the rest is a quoted heredoc.
   Run from anywhere, it does, in this order: (a) refuses, exit 2, when `claude` is not on `PATH`,
   saying so; (b) refuses, exit 2, writing nothing, when `here` holds no `*.dir` file, or already
   holds `exits.txt` or any `*.jsonl`, because running it twice pays for the arms twice; (c) prints
   the search root (`$KEEL_ISOLATION_ROOT` or `/`) and runs `bash "$here/isolation-check.sh" --names
   "$here/scenario-names.txt"` with every staged directory named by `$here/*.dir` as positional
   arguments built with `set --`; on a non-zero exit it prints what the check printed, says no arm
   was dispatched, and exits 2 writing nothing; (d) otherwise dispatches every arm concurrently, the
   arm name being `basename <file> .dir`, from its `project/`, with `TMPDIR=<staged dir>/tmp` and
   stdin from `/dev/null`, writing `$here/<name>.jsonl`, `.err` and an `exits.txt` line as `gate.sh`
   did, and exits 1 when any arm exited non-zero. Example: with a planted
   `x/skills/review-code/SKILL.md` under `KEEL_ISOLATION_ROOT`, `bash OUT/dispatch.sh` exits 2,
   prints that path, and the stub `claude` is never run.
3. The header comment of `gate.sh` says why the split: L-01 of `docs/audits/2026-10-18-security.md`;
   arms run with `bypassPermissions` and search the machine, so they are dispatched only from a
   workspace where nothing else is within reach, and a script inside the checkout cannot be that
   place. It says what the check does not see: it matches keel-shaped names, not credentials, other
   repositories or text that quotes criteria. The comment at the top of the generated `dispatch.sh`
   says the same in three sentences and names the audit.
4. `tests/test-eval-harness.sh`: every invocation of a generated `dispatch.sh` sets
   `KEEL_ISOLATION_ROOT` to an empty temp directory outside `OUT` and the staged directories, and
   gives explicit stdin. Existing cases change as follows: the dispatch case (around line 1393) runs
   `gate.sh`, then `OUT/dispatch.sh`, with `OUT` and `TMPDIR` under a directory whose name holds a
   space, and asserts what it asserted before; "without `--dry-run` and without `claude` on `PATH`
   exits 2 before creating `OUT`" (around line 1458) is replaced by case (d) below; the case where
   an arm's non-zero exit gives a non-zero exit and an `exit=1` line (around line 1476) runs through
   `dispatch.sh`. New cases: (a) `gate.sh` without `--dry-run` runs no `claude`, exits 0, writes the
   three files, `scenario-names.txt` holds `tdd-under-deadline` and no `.md`, `bash -n
   OUT/dispatch.sh` passes, and `grep -F "$REPO" OUT/dispatch.sh` finds nothing; (b) `dispatch.sh`
   exits 2, prints the planted path and runs no `claude` when the root holds a planted
   `x/skills/review-code/SKILL.md`, and the same for a planted `tdd-under-deadline.md`; (c) a
   separate stub `claude` that reads its stdin logs the byte count, `dispatch.sh` is run with text
   on its own stdin, and every arm logs 0; (d) `dispatch.sh` without `claude` on `PATH` exits 2 with
   "claude is not on PATH" and dispatches nothing; (e) `gate.sh --dry-run`'s printed lines end `<
   /dev/null`; (f) a second `dispatch.sh` run in the same `OUT` exits 2 and changes nothing; (g)
   `gate.sh` refuses an `OUT` named `keel-eval-x`. Cases (a), (b), (c), (e), (f) and (g) fail before
   the change.

**Done when:** those cases fail before the change and pass after, and `bash
tests/test-eval-harness.sh`, `bash tests/validate-citations.sh` and `shellcheck -x
tests/evals/gate.sh tests/test-eval-harness.sh` pass, with `shellcheck` also run on one generated
`dispatch.sh`.

- [x] **Step 1.1: Write the cases** for behaviour 4 and watch (a), (b), (c), (e), (f) and (g) fail.
- [x] **Step 1.2: Split `gate.sh`** for behaviours 1 to 3 and watch every case pass.
- [x] **Step 1.3: Check and hand over.** Run the `Done when:` commands, repoint any citation the
      change moved, stage the changed files and the plan file by path, show `git status
      --porcelain`, and stop. The coordinator commits: `fix(evals): gate.sh stages, and the dispatch
      refuses while keel is reachable`.

### Task 2: the README, the runbook and the audit say where a gate runs and what is checked

**Files:**
- Modify: `tests/evals/README.md`, `docs/runbooks/cutting-a-release.md`,
  `docs/audits/2026-10-18-security.md` and `CHANGELOG.md`

**Depends on:** task 1

**Behaviours:**

1. `tests/evals/README.md`: the flag bullet's "It is safe here only because the working directory is
   a staged copy outside the tree." (around line 70) becomes "It is safe only where nothing else is
   within reach: arms search the whole machine, so a gate is dispatched from a disposable workspace
   that holds no keel checkout, no personal credentials and no other repositories." Line 101 and the
   paragraph around lines 161 to 163 ("`gate.sh` does it") are corrected to the split: `gate.sh`
   stages, `OUT/dispatch.sh` dispatches. The isolation-check paragraph's `gate.sh` exception (around
   lines 190 to 192) is replaced: `OUT/dispatch.sh` runs the check itself, and the check matches
   keel-shaped names only, so it does not detect credentials, other repositories or text quoting
   criteria. The single-arm recipe near the top (around lines 12 to 18), which `stage.sh` also
   prints, gains one sentence: it dispatches with no check, so run the isolation check by hand
   first. One paragraph names the residuals: concurrent arms can read each other's staged
   directories and `OUT` files, and `--dry-run`'s printed lines dispatch with no check. One sentence
   says that on a machine with keel installed as a plugin, `dispatch.sh` refuses, as intended.
2. `docs/runbooks/cutting-a-release.md` section 1: the lead-in "stages every arm and dispatches
   them" (around line 55) and the command block become: stage with `gate.sh` into an `OUT` outside
   the tree, in a disposable workspace (a cloud session or a container) holding no personal
   credentials and no other repositories; delete the checkout there; then `bash OUT/dispatch.sh`;
   one sentence names L-01. The `--dry-run` line stays. "**Dispatch all 7 concurrently.**" stays
   word for word, because `tests/test-eval-harness.sh` reads it. Nothing else in the runbook
   changes.
3. `docs/audits/2026-10-18-security.md`: L-01's table gains a status row, in the shape of
   `docs/audits/2026-10-17-security.md` line 60: "Fixed for the checkout in `<commit>`: the dispatch
   refuses while keel is reachable. Credentials and other repositories are out of reach only by
   where the gate is run." The coordinator passes the commit. L-01's location row and inline
   citations of `gate.sh` and `README.md` lines are pinned as "line N at `d5dad6a`". The verdict
   paragraph stays as it is, as the record of `d5dad6a`.
4. `CHANGELOG.md` gains one Unreleased bullet: L-01, what changed, what the check does not see, and
   the judgement in behaviour 5.
5. The judgement, stated in the CHANGELOG bullet: the runbook's transfer test (`git diff --stat`
   over `skills/` and `tests/evals/`) is not empty after this change, because it edits
   `tests/evals/gate.sh` and the README; no skill body, fixture or scenario changes, and the only
   difference an arm sees is its stdin from `/dev/null`, so the gate run at `d5dad6a` is taken to
   stand.

**Done when:** `bash tests/test-eval-harness.sh`, `bash tests/test-doc-claims.sh` and `bash
tests/validate-citations.sh` pass.

- [x] **Step 2.1: Apply behaviours 1 to 5.**
- [x] **Step 2.2: Check and hand over.** Run the `Done when:` commands, repoint any citation the
      change moved, stage the changed files and the plan file by path, show `git status
      --porcelain`, and stop. The coordinator commits: `docs(evals): a gate is dispatched where
      nothing else is within reach`.

## The coordinator's check, after task 2

One arm, `tdd-under-deadline`, staged by the new `gate.sh` (a one-line `--scenarios` file) in the
Linux cloud workspace from a copy of the tree. `bash OUT/dispatch.sh` run once with the copy still
present (expected: exit 2, the copy named, nothing written to `OUT`), and once after deleting it
(expected: the arm runs, exit 0, its stream-json in `OUT`). About $0.30. The result goes in the
0.25.0 release entry.

## Self-review

- Every task carries `Depends on:`, `Files`, `Behaviours` with examples and `Done when:`, and hands
  over by staging named paths.
- The plan does not claim the check closes L-01 whole: it closes the checkout half, and the
  documents say what keeps the rest out of reach.

