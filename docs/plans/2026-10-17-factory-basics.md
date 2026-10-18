# CI builds sandbox, the gate is a script, and the review graders read the tree Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for task 2. Tasks 1, 3 and 4 have no failing-test step, and
> each says why under its behaviours.

**Goal:** a push to `sandbox` is built on Linux and macOS before any release commit, the plan tests
also run under macOS's UTF-8 locale, the release gate is dispatched by a committed script that can
run each arm more than once, and the `review-code-leaves-the-tree-alone` graders judge the author's
tree as left rather than the commands a review ran.
**Stories:** none. A change to keel's own tooling, specified by items 5a, 1a and 1c of
`docs/ideas/factory-reliability.md`.
**ADRs:** none written; none governs these files. ADR-0004 is unaffected: no gate changes strength.
**Architecture:** one trigger line and one step in `.github/workflows/ci.yml`; a new
`tests/evals/gate.sh` that reads `tests/evals/gate-scenarios`, stages every arm with
`tests/evals/stage.sh` and dispatches them concurrently, with a `--dry-run` that stages and prints
without dispatching so the suite can test it; three graders in
`tests/plugin-evals/review-code-leaves-the-tree-alone/graders/` rewritten from `tool_used` on
command text to `file_exists` and `regex` on the repository's end state.
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Concurrent batches:** tasks 2 and 3 may run at the same time. Task 1 runs alone, because it
edits shared configuration (`.github/workflows/ci.yml`), and task 4 requires all three.
**Batch gate:** after tasks 2 and 3 land, `tests/run-tests.sh` is green.
**Decided:** Bernard, 2026-10-17, agreeing to proceed as recommended in
`docs/ideas/factory-reliability.md` and answering its open questions: prune the bodies at the
ceiling to the target (a later plan); probe, then a reviewer git guard (a later plan); keep the plan
tooling in bash and harden it, which task 1's UTF-8 locale step begins.
**Shape:** behaviours with examples.
**Approved:** by Bernard, 2026-10-17: keel-implementer on Sonnet, delivered by hand-off.
**Reviewed:** by a dispatched plan reviewer on 2026-10-17, ISSUES; every finding is folded in, and
"What the review changed" records it. Task 3's grader forms were then proved by a probe.

## Global constraints

Copied from `.keel/profile.json` and `docs/standards.md`. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint as `.keel/profile.json`
  spells it (read it there; do not retype it from here). If `command -v shellcheck` prints nothing,
  say the lint was not run and that CI will run it.
- **`tests/run-tests.sh` takes about 2m30s.** Run it in the background and read its log to the end
  within one tool call.
- **Tasks 2 and 3 run in their own git worktrees, outside the repository, and commit there**;
  their `Done when:` is their own checks, and the suite runs once at the join (the batch gate).
  Tasks 1 and 4 run in the shared tree, stage named paths and hand over; the coordinator commits.
- **Records.** Tasks 1, 2 and 3 do not touch `CHANGELOG.md` or `docs/ideas/factory-reliability.md`;
  task 4 writes them. A reviewer of task 1, 2 or 3 is told so.
- **`.github/workflows` is in `hard_block_paths`.** Task 1 gets the full review loop.
- **Precondition: the working tree is clean and nothing is staged.** Each commit stages named paths
  only. Never `git add -A`, `git add .` or `git commit -a`.
- Never start on `main`.
- No em dashes and no en dashes, in any file or commit message. Prose wraps at 100 columns; table
  rows and code blocks do not.
- Commits carry no attribution footers; this repository sets `conventions.no_attribution_footers`.
- **Line citations.** Cite by phrase (`file#phrase`), not by line number. Run
  `tests/validate-citations.sh` after each edit and repoint any live citation a move breaks.
- **Plans are scanned for links.** Write paths in backticks, never as markdown links, in this plan.
- **Every rule carries its reason.**
- Never `sed -i` on this repository's mount: it drops the exec bit. Edit with a read-modify-write.
- **A pipeline that feeds `grep -q` is not tested under `pipefail`.** grep leaves at the first
  match, the producer's 141 fails the pipeline, and the check reads as a miss; read into a variable
  or a file first, as `docs/runbooks/cutting-a-release.md` "Symptoms" records.

## What this plan does not build

- **No release command.** Item 5b of the ideas record waits for this plan; `gate.sh` is the first
  piece of it.
- **No scripted scoring of the gate.** `gate.sh` dispatches and records; scoring stays reading, as
  `tests/evals/README.md` "Scoring is deliberately human" says. A pass rate across runs is recorded
  by the person scoring.
- **No change to which scenarios are in the gate**, or to `stage.sh`'s isolation.
- **No change to the macOS job's advisory status** in branch protection, which is a repository
  setting and Bernard's.
- **No other plugin-eval case is touched.**
- **No deduplication of CI runs.** With `push` on `sandbox` and `pull_request` both triggering, a
  push to `sandbox` with a pull request open builds twice, macOS included. Accepted: the two runs
  key on different refs, so a `concurrency:` group would not join them, and the cost is minutes.

## What the review changed

- **Task 3 no longer uses `file_exists` on a directory.** The docs say a `file_exists` grader
  matches files "created during the run" against a glob. A probe on 2026-10-17 in a Linux cloud
  workspace, two cases of one run each, $0.12, settled the forms: `path: .git/worktrees/**` with
  `exists: false` failed the run that left a worktree and passed the run that removed one, while
  `path: .git/worktrees` passed both. A `regex` grader read the binary `.git/index` and `.git/HEAD`.
- **"No stash" keeps its `tool_used` form.** It failed none of the three Linux runs, and the stash
  ref is shared by every worktree, so matching the command is right for it.
- **"No index or tree change" became three graders** on the index, `HEAD` and `COMMIT_EDITMSG`,
  because the index alone misses a commit in the author's checkout.
- **Task 1 records the runner's locales instead of re-running the plan tests under one.** macOS CI
  caught `5b50a83`'s bug with no locale set, so the runner's default is already UTF-8, and
  `tests/test-plan.sh` sets `LC_ALL=C.UTF-8` itself for the dash cases, overriding an outer one.
  What is unknown is whether `C.UTF-8` exists on macOS; if not, those cases ran under `C` there.
- **Task 2 gained `--scenarios <file>`** so a test can make one stage fail, documents the move to
  `stream-json`, lints `gate.sh` directly, and cleans up what its tests stage.
- **Task 4 adds `gate.sh` to the profile's lint list**, which names files one by one.
- **The coordinator runs the plugin-eval case**, because `claude plugin eval` does not run in the
  implementer's environment; it runs in the Linux cloud workspace with `bubblewrap` and `socat`.

---

### Task 1: CI builds `sandbox`, and the macOS job records its locales

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `tests/test-plan.sh`

**Depends on:** none

**Behaviours:**

1. A push to `sandbox` starts the workflow, as a push to `main` does. Example: the `on:` block reads
   `push:` with `branches: [main, sandbox]`, and `pull_request:` is unchanged. A comment above it
   says why: on 2026-10-17 the release commit `5f09164` reached `sandbox` and was first built on
   macOS only once a pull request existed, where `keel plan batches` failed (`5b50a83`).
2. The macOS job records which locales the runner has, beside the step that records `timeout`.
   Example: a step named `Record the runner's locales` runs `locale` and
   `locale -a | grep -i -E 'utf-?8' | head -20`, with a comment that the plan tests' dash cases need
   a UTF-8 locale that exists on the runner.
3. The dash cases in `tests/test-plan.sh` run under the first UTF-8 locale the machine has, of
   `C.UTF-8` and `en_US.UTF-8`, rather than naming `C.UTF-8` alone, and say which they used.
   Example: on a machine without `C.UTF-8` they run under `en_US.UTF-8`; with neither, the case
   prints `SKIP` naming the missing locales rather than passing under `C`.
4. The checks' display names are unchanged, so no required check in branch protection changes.
   Example: "Validate skills and templates", "Tests on macOS", "Python lint" and "Supply chain".

There is no failing test for behaviours 1, 2 and 4: they are workflow configuration, proved by
CI's next run on `sandbox`. Behaviour 3 changes how existing tests pick a locale, proved by them
passing under each locale this machine has.

**Done when:** all of these:
- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` exits 0, or, where
  PyYAML is absent, `ruby -ryaml -e 'YAML.load_file(".github/workflows/ci.yml")'` exits 0; say which
  ran.
- `grep -n 'branches: \[main, sandbox\]' .github/workflows/ci.yml` prints one line.
- `tests/test-plan.sh` passes, and its output names the locale the dash cases used.
- `git diff --stat` shows the two files only.

- [x] **Step 1.1: Edit the trigger** for behaviour 1.
- [x] **Step 1.2: Add the locale step** for behaviours 2 and 4.
- [x] **Step 1.3: Make the dash cases pick an existing UTF-8 locale** for behaviour 3. Note: C.UTF-8, en_US.UTF-8 and neither each proved with a stub locale; with neither, only the two non-ASCII cases skip
- [x] **Step 1.4: Check and stage.** Run the `Done when:` checks and the full `tests/run-tests.sh`, Note: rounds: 2; routing: keel-implementer (sonnet, by hand); loop: full; spec COMPLIES; quality BLOCKING on a pipefail premise that does not hold for a run step with no shell key, taken as hardening with two should-fix items in one fix pass, quality re-review NOTHING BLOCKING, one comment reworded; full run-tests.sh passed in the implementer's run; macOS locale behaviour is proved only by CI
  stage the two files by path, show `git status --porcelain`, and stop. The coordinator commits
  after the review passes:
  `ci: a push to sandbox is built, and the macOS job records its locales`.

### Task 2: the release gate is dispatched by `tests/evals/gate.sh`

**Files:**
- Create: `tests/evals/gate.sh`
- Modify: `tests/test-eval-harness.sh`
- Modify: `docs/runbooks/cutting-a-release.md`
- Modify: `tests/evals/README.md`

**Depends on:** none

**Behaviours:**

1. `tests/evals/gate.sh [--runs N] [--scenarios FILE] [--model ID] [--dry-run] OUT` stages every
   scenario named in FILE (default `tests/evals/gate-scenarios`, skipping blank lines and lines
   starting `#`) N times (default 1), each run in its own staged directory, and writes
   `OUT/<scenario>.<run>.dir` holding that path. Example: with the seven gate scenarios, `--runs 3`
   writes 21 `.dir` files, from `tdd-under-deadline.1.dir` to `commit-outside-a-worktree.3.dir`.
2. Without `--dry-run` it dispatches every staged arm concurrently from its `project/` with the
   flags `tests/evals/README.md` names, on `--output-format stream-json --verbose`, writing
   `OUT/<scenario>.<run>.jsonl` and `.err` beside the `.dir` file, not inside the staged directory,
   and waits for all of them. `--model ID` is passed through when given. Example: one line per arm
   in `OUT/exits.txt`, `tdd-under-deadline.1 exit=0`.
3. With `--dry-run` it stages, writes the `.dir` files and prints each dispatch command, and runs no
   `claude`. Example: `tests/test-eval-harness.sh` runs it with a stub `claude` first on `PATH` that
   records any call, and the stub records none.
4. It refuses an OUT inside the repository, for the reason `stage.sh` refuses a staging directory
   there: an arm can find the scenario files from inside the tree. It resolves OUT without creating
   it first, comparing `pwd -P` of OUT's nearest existing parent with the repository root, since
   macOS has no `realpath -m`. Example: `gate.sh tests/evals/out` exits non-zero naming the path,
   and `tests/evals/out` does not exist afterwards.
5. A stage failure for one scenario is reported and the others still run. Example: with a FILE
   naming `tdd-under-deadline` and `no-such-scenario`, the summary reads
   `staged 1 of 2, 1 failed: no-such-scenario.1`, and the script exits non-zero.
6. The runbook's section 1 runs `tests/evals/gate.sh` in place of the pasted script, says results
   are written to `OUT/<scenario>.<run>.jsonl` and that the stream's final `result` record carries
   the model and the cost, and its opening "Six treatment arms" reads seven. Its "Still open"
   paragraph about `gate.sh` is replaced by one line saying it was committed on 2026-10-17.
   `tests/evals/README.md` names `gate.sh` where it says how a full gate is dispatched, and its
   `--output-format json` bullet says the gate script uses `stream-json --verbose`, whose last
   record carries the same model and cost. The gate count sentences stay as
   `tests/test-eval-harness.sh` checks them.

**Done when:** all of these, in this task's worktree:
- `bash tests/test-eval-harness.sh` passes, with new cases for behaviours 1, 3, 4 and 5. The dry-run
  case uses `--runs 2` and adds every staged directory its `.dir` files name to the suite's cleanup.
- `bash -n tests/evals/gate.sh` exits 0, and `shellcheck -x tests/evals/gate.sh` is clean if
  `shellcheck` is installed (the profile's lint names files one by one and does not include it until
  task 4).
- `tests/validate-citations.sh`, `bash tests/test-doc-claims.sh` and
  `bash tests/test-harness-claims.sh` pass.

- [x] **Step 2.1: Write the failing tests** in `tests/test-eval-harness.sh` for behaviours 1, 3, 4
  and 5, using `--dry-run`, `--scenarios` and a stub `claude`.
- [x] **Step 2.2: Run them and watch them fail.** Run: `bash tests/test-eval-harness.sh`.
  Expected: the new cases FAIL because `tests/evals/gate.sh` does not exist.
- [x] **Step 2.3: Write `tests/evals/gate.sh`** for behaviours 1 to 5. Note: red 53 passed 8 failed (rc=127) before gate.sh, green 61 then 62 with the symlink case; seen in the implementer's report, not by me
- [x] **Step 2.4: Run them and watch them pass**, then edit the runbook and the README for
  behaviour 6.
- [x] **Step 2.5: Check and commit.** In your own worktree: stage the four files by path and Note: rounds: 2; routing: keel-implementer (sonnet, by hand); loop: light; batch with task 3 in worktree fb-t2; spec DEVIATES (a symlink-and-.. OUT bypassed the refusal, a find piped into grep -q under pipefail), one fix pass amended to f295a2a, second spec COMPLIES; joined by merge 13c974a, run-tests.sh at the join witnessed by me, all passed; macOS bash 3.2 reviewed by reading, not run
  `git commit -m "feat(evals): the release gate is dispatched by tests/evals/gate.sh, more than once per arm when asked"`.

### Task 3: the `review-code-leaves-the-tree-alone` graders read the tree as left

**Files:**
- Modify: `tests/plugin-evals/review-code-leaves-the-tree-alone/graders/no-worktree-left.md`
- Modify: `tests/plugin-evals/review-code-leaves-the-tree-alone/graders/no-index-or-tree-change.md`
- Create: `tests/plugin-evals/review-code-leaves-the-tree-alone/graders/head-unchanged.md`
- Create: `tests/plugin-evals/review-code-leaves-the-tree-alone/graders/no-commit-in-checkout.md`
- Modify: `tests/plugin-evals/README.md`

**Depends on:** none

**Behaviours:**

1. "No worktree left" is a `file_exists` grader with `path: .git/worktrees/**` and `exists: false`.
   Example: the probe recorded under "What the review changed" failed a run that left a worktree and
   passed one that removed it; the plain directory form passed both, so it is not used.
2. "No index or tree change" is a `regex` grader on `.git/index` requiring `src/wip\.sh`, the file
   the scaffold stages, so a `git reset` or `git stash` in the author's checkout that unstages it
   fails. Example: after `git reset`, `grep -c 'src/wip.sh' .git/index` goes from 1 to 0.
3. "Head unchanged" is a `regex` grader on `.git/HEAD` requiring `ref: refs/heads/feat/payout-fee`,
   so a switch or a detached checkout in the author's checkout fails.
4. "No commit in the checkout" is a `regex` grader on `.git/COMMIT_EDITMSG` requiring the scaffold's
   last message, `feat(fees): work out the net payout after the fee`. A commit in the author's
   checkout rewrites that file; a commit inside a linked worktree writes the worktree's own.
5. "No stash" is unchanged: it keeps its `tool_used` form, for the reason under "What the review
   changed".
6. Each grader's prose says what it reads and why: `review-code`'s mutation step runs commands in
   a throwaway worktree on purpose, and the command form failed three Linux runs that left the tree
   as found (`tests/plugin-evals/README.md#Run on Linux without it`). The README section that
   recorded the 0 of 3 says the graders now read the end state, and that a `git add` of the
   author's uncommitted edit is not detected by any grader.

There is no failing test: `claude plugin eval` does not run in this environment. The forms are
proved by the probe, the states by a scratch repository below, and the case by the coordinator's
three runs recorded in task 4.

**Done when:** all of these, in this task's worktree:
- A scratch repository built by this case's `scaffold.sh`, in your own scratch directory, shows
  each state a grader reads: `ls .git/worktrees` fails after a worktree add and remove;
  `grep -c 'src/wip.sh' .git/index` is 1, then 0 after `git reset`; `.git/HEAD` names
  `feat/payout-fee`; `.git/COMMIT_EDITMSG` holds the scaffold's message, and a commit inside a
  linked worktree leaves it unchanged. Paste the commands and their output.
- The grader frontmatter matches the forms the probe used, which follow the docs at
  `https://code.claude.com/docs/en/plugin-evals`.
- `tests/validate-citations.sh` passes.

- [x] **Step 3.1: Prove each state in a scratch repository** for behaviours 1 to 4.
- [x] **Step 3.2: Rewrite the graders and the README** for behaviours 1 to 6.
- [x] **Step 3.3: Check and commit.** In your own worktree: stage the five files by path and Note: rounds: 1; routing: keel-implementer (sonnet, by hand); loop: light; batch with task 2 in worktree fb-t3; spec COMPLIES, patterns tested against a rebuilt scaffold; committed b1c32eb, joined by merge e2b7d5c, run-tests.sh at the join witnessed by me, all passed; the case's three runs are the coordinator's, in task 4
  `git commit -m "fix(evals): the review graders read the author's tree as left, not the commands a review ran"`.

### Task 4: the records, and `gate.sh` in the lint

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/ideas/factory-reliability.md`
- Modify: `tests/plugin-evals/README.md`
- Modify: `.keel/profile.json`

**Depends on:** tasks 1, 2 and 3

**Behaviours:**

1. `.keel/profile.json`'s `verify.lint` names `tests/evals/gate.sh` beside `tests/evals/stage.sh`,
   so the local lint and CI both cover it. Example: the profile's lint run is clean.
2. `CHANGELOG.md` gains an entry under a new `## Unreleased` heading, above `## 0.24.0`, for each of
   tasks 1 to 3 and the lint change, naming the commits.
3. `docs/ideas/factory-reliability.md` gains a "Decided" section recording Bernard's three answers
   of 2026-10-17, and its Status and Next lines say items 5a, the script half of 1a, and 1c are
   built by this plan and name what is next: the reviewer-guard probe, then the ADR-0001 prune.
4. `tests/plugin-evals/README.md` records the coordinator's three runs of
   `review-code-leaves-the-tree-alone` in the Linux cloud workspace after task 3, with the scores
   and cost, or records them as owed if they were not run.

There is no failing test: records and a lint list, checked by the validators and the lint itself.

**Done when:**
- The profile's lint, `tests/validate-citations.sh`, `bash tests/test-doc-claims.sh` and
  `tests/validate-skills.sh` pass.
- No em or en dash in any added line, and added prose lines are at most 100 columns.

- [x] **Step 4.1: Add `gate.sh` to the lint** for behaviour 1.
- [x] **Step 4.2: Write the records** for behaviours 2 to 4.
- [x] **Step 4.3: Check and stage.** Run the `Done when:` checks and the full `tests/run-tests.sh`, Note: rounds: 2; routing: keel-implementer (sonnet, by hand); loop: full (the profile); spec DEVIATES on a misattributed commit, its second point not taken because the wording is the option Bernard chose; quality NOTHING BLOCKING, two suggestions taken; one fix pass; full run-tests.sh passed in the implementer's run; the lint is clean in four groups, one call is OOM-killed on the 3.9 GB VM
  stage the four files by path, show `git status --porcelain`, and stop. The coordinator commits:
  `docs: the factory basics are built, and gate.sh is linted`.
