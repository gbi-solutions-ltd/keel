# Plan execution speed, second sweep Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for tasks 1, 2, 3 and 9. Tasks 4 to 8 and 10 change skill
> text and records and say under their behaviours why they carry no failing test.

**Goal:** a plan run stops paying for what does not check anything: the suite runs longest-first
on more workers, reviewers stop re-running the suite, a subagent is not stopped for its
coordinator's context, citations stop taxing every task, older plans can take checkpoints, and the
one approval a run cannot grant itself is asked while the person is there.
**Stories:** none. `docs/ideas/plan-execution-speed-2.md`, items 1 to 9, agreed by Bernard on
2026-11-12, with the four decisions recorded at its end.
**ADRs:** ADR-0017 (suite checkpoints), which tasks 5 and 6 amend; ADR-0011 (skill bodies hold
instructions, references hold the rest); ADR-0001 (skill body word ceiling); ADR-0012 (a task
carries two steps).
**Architecture:** three code changes and seven text changes. `tests/run-tests.sh` orders files by
their last recorded durations and runs more jobs; `lib/context_watch.py` says nothing to a
subagent; `tests/validate-citations.sh` adds two hot files; `bin/keel plan tick` takes several ids.
The rest is `execute-plan`'s prompts and suite checkpoints reference, `review-code`, the plan
template and review brief, `tdd`, and ADR-0017.
**Implementer routing:** inherit
**Delivery:** pull-request (onto PR #12's branch, `feat/faster-plan-execution`)
**Concurrent batches:** none. Every task adds a line to `CHANGELOG.md`; tasks 4, 5, 6 and 10 share
`skills/execute-plan/references/subagent-prompts.md`; tasks 5 and 6 share ADR-0017.
**Suite checkpoints:** every 3 tasks.
**Commits that ask:** tasks 2 and 3 stage `hard_block_paths` (`lib/context_watch.py`,
`lib/harness/capabilities`), so sensitive-guard asks at their commits. They run early, while the
person who approved the plan is likely still present.
**Decided:** by Bernard, 2026-11-12: all nine items; item 3 as design first, with no code the
model could use to satisfy sensitive-guard; item 5 as a hot-file list and no record repairs, the
validator's line check unchanged; item 6 as `review-code` quoting the plan-end checkpoint on the
same HEAD while `ship` still runs its own; item 7 as the checkpoint offer also rewriting each open
task's boundary step, a repair the person approves; delivery onto PR #12. Decided in this plan and
put to Bernard at approval:
- Durations persist in `.keel/test-durations`, git-ignored beside the handoff, so each checkout
  learns its own; a file with no recorded duration runs first, since unknown is treated as slow.
- The job count is `KEEL_TEST_JOBS` when it is a positive integer, else the online CPU count from
  `getconf _NPROCESSORS_ONLN` capped at 8, else 4.
- A subagent is told by a non-empty `agent_type` and a non-empty `agent_id`, as `review-guard`
  tells one, and context-watch is silent for it: its context is its own and is discarded when it
  returns, and no field on its PreToolUse event is known to name its own transcript.
- The checkpoint offer (item 7) is made when a plan with no `**Suite checkpoints:**` line has 3 or
  more open tasks. It did not exist before this plan; task 6 creates it.
- The checkpoint note records the tree it ran on (`suite: pass at tree <tree sha>`, from
  `git write-tree` with the task staged, before the tick), not a commit: the suite runs before the
  task and plan are committed together, so no commit the note could name is HEAD. `review-code`
  reuses it when `git diff --name-only <tree> HEAD` names nothing outside `docs/plans/` and the
  working tree is clean.
- This plan starts after `docs/plans/2026-11-12-plan-execution-follow-ups.md` task 3 is committed,
  since tasks 2 and 3 edit and cite files that task changes. Before the first dispatch the
  coordinator repairs any citation `tests/validate-citations.sh` flags under `docs/plans/`, so the
  validator starts green.
**Reviewed:** by a dispatched plan reviewer on 2026-11-12: two blocking (a checkpoint note naming
a commit can never be HEAD; task 1's red run would recurse through the runner), and should-fix
items on wrapped greps, the records the validator flags, task 1's test isolation and its timing
case, a usage line in `docs/03-install-and-distribution.md`, and ship's quoting. All folded in.
**Approved:** by Bernard, 2026-11-12: routing `inherit`, onto PR #12's branch, with the decisions
above as written.
**Shape:** behaviours with examples.

## Global constraints

Every task inherits these.

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test
  `tests/{name}`, lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh
  tests/evals/run.sh tests/evals/stage.sh tests/evals/gate.sh tests/evals/isolation-check.sh
  hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
  hooks/review-guard`. No typecheck, format or build command exists.
- Shellcheck at default severity after each file edit, not at the end.
- Never start on `main`. This plan runs on `feat/faster-plan-execution` (PR #12).
- `hooks`, `lib/harness`, `settings.json`, `.github/workflows`, `templates/ci-review.yml` and
  `lib/context_watch.py` are `hard_block_paths`. Tasks 2 and 3 touch them. Leave
  `.github/workflows` alone in every task.
- Hooks parse under `/bin/bash` 3.2 (`docs/standards.md`, "Scripts parse under bash 3.2"): python
  stays in the heredoc read into a variable, never inside `$( )`.
- **No `SKILL.md` body gains words.** `tdd` is at 698 and `write-plan` at 684 of the validator's
  700-word ceiling, `execute-plan` at 673. New rules go in a reference (ADR-0011); a body line may
  be reworded to point at it, and its body word count, as `tests/validate-skills.sh` counts it,
  after the task is at most its count before.
- A change lands with the live documents it makes wrong, each stating what is true now. A
  citation the citation validator flags is repaired; do not look for shifted citations in records
  (`docs/plans`, `docs/ideas`, `docs/prd`, `docs/decisions` and the other dated records). A
  citation under `docs/plans/` is reported to the coordinator, not edited.
- `tests/test-harness-claims.sh` fails any line in `README.md` or `docs/NN-*.md` that names
  `review-guard` or `hard_block_paths`, or uses gate or ceiling vocabulary, without a `keel:claim`
  tag within three lines: tag what you write the way the surrounding text does.
- The implementer prompt's `=== RULES ===` block onward is carried verbatim by four eval scenarios
  (`tests/evals/scenarios/commit-outside-a-worktree.md`, `implement-a-two-step-task.md`,
  `implement-a-five-step-task.md`, `implement-a-batched-task.md`), which
  `tests/test-eval-harness.sh` checks: a change there is mirrored in all four.
- Add one line for the task under `## Unreleased` in `CHANGELOG.md`.
- No em or en dashes anywhere, conventional commit messages, no attribution footers.
- Never `git stash`, in any form: the stash is shared by every worktree of this repository.
- Suite checkpoints: run no `tests/run-tests.sh`. The coordinator runs it before the first
  dispatch, after tasks 3, 6 and 9, and after the last, and hands you the last record as your start
  record.

---

### Task 1: the suite runs longest-first on more workers

**Story:** idea record item 2, and item 8's slow-suite warning
**Files:**
- Modify: `tests/run-tests.sh`
- Modify: `.gitignore`
- Modify: `docs/snapshot.md`
- Modify: `CHANGELOG.md`
- Create: `tests/test-run-tests.sh`

**Depends on:** none

**Behaviours:**

1. Files run longest-first by their last recorded duration, and a file with none recorded runs
   before every recorded one. Durations are read from and written to `.keel/test-durations` (one
   `<seconds> <file>` line per file, the file as the runner's list names it, plus a
   `total <seconds>` line for the last wall time), under the repository root;
   `KEEL_TEST_DURATIONS` names another path. Each file's log is still replayed when it ends, so the
   output is in run order. Example: with
   `KEEL_TEST_FILES` naming stubs `a.sh`, `b.sh` and `c.sh` (each sleeps briefly and exits 0),
   `KEEL_TEST_JOBS=1` and a durations file saying `1 a.sh` and `5 b.sh`, the run starts `c.sh`,
   then `b.sh`, then `a.sh`, and afterwards the file holds a line for each of the three.
2. `KEEL_TEST_FILES`, when set, is the space-separated list of test files to run in place of the
   built-in list, and the lint job is then skipped; this is the seam the new test uses. Example:
   the run in behaviour 1 prints no `== lint` line.
3. The job count is `KEEL_TEST_JOBS` when it is a positive integer, else `getconf
   _NPROCESSORS_ONLN` capped at 8, else 4. Example: with `KEEL_TEST_JOBS=2` and four stubs that
   each create an entry in a shared directory, record how many entries it holds, sleep 1 s and
   remove their entry, the largest count any stub records is exactly 2; with `KEEL_TEST_JOBS=1` it
   is 1; `KEEL_TEST_JOBS=abc` falls back to the CPU rule without error. No case asserts wall time,
   since the suite runs this file beside others.
4. A run whose wall time is over twice the recorded `total` says so in one line before the result.
   Example: with `total 1` recorded and stubs that take about 3 s, the output contains
   `over twice the last run`; with no `total` recorded, it does not.
5. `.keel/test-durations` is git-ignored, and the header comment that says no test file writes
   into the repository's tree names the durations file as the runner's one write. Example:
   `git check-ignore .keel/test-durations` exits 0. Every case in `tests/test-run-tests.sh` sets
   `KEEL_TEST_DURATIONS` to a temporary path, so running it never touches the real file.
6. `docs/snapshot.md:116` states the order, the job count and the durations file in place of
   "about 6 minutes". Example: that line no longer says `about 6 minutes`.
7. The runner is timed for real three times on this machine after the change, with the default job
   count. Example: the report quotes three wall times and names any file that failed in one run and
   passed in another (the guards' 10 s hook timeouts are the likely flake). If any did, the default
   cap drops to the highest count with three clean runs, and the report says so.

**Done when:** `tests/test-run-tests.sh` passes, and `git check-ignore .keel/test-durations`
exits 0.

- [x] **Step 1.1: Build it test first** Note: rounds: 1; routing: inherit; loop: light; red 6/9 quoted; three timed suite runs 243/169/165 s at 8 jobs, no flake; reds only two plan phrase citations, repointed by the coordinator; extra staged: test-harness-claims.sh:42 comment (coordinator's request), one docs/ideas citation repair

Follow `keel:tdd`. Add the `KEEL_TEST_FILES` and `KEEL_TEST_DURATIONS` seam first (behaviour 2),
since without it the new test would run the whole suite. Then write `tests/test-run-tests.sh` for
behaviours 1, 3 and 4, and add it to the runner's list only once it passes.
Run: `tests/test-run-tests.sh`
Expected before the rest of the implementation: FAIL, behaviour 1's order case (file order, not
longest-first, and no durations written), behaviour 3's cases (4 jobs whatever `KEEL_TEST_JOBS`
says) and behaviour 4's case (no warning). Expected after: PASS. Quote the failing output.

Run: the lint command. With the `Done when:` run above, that is the unit boundary. Then run
`tests/run-tests.sh` three times for behaviour 7 (this task alone runs the suite, because what it
changes is the suite).
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [x] **Step 1.2: Hand over** Note: staged by the implementer

```bash
git add tests/run-tests.sh tests/test-run-tests.sh .gitignore docs/snapshot.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "perf(tests): run the suite longest-first on more workers"`.

---

### Task 2: context-watch leaves a subagent alone

**Story:** idea record item 9
**Files:**
- Modify: `lib/context_watch.py`
- Modify: `docs/05-token-and-memory-design.md`
- Modify: `CHANGELOG.md`
- Test: `tests/test-context-watch.sh`

**Depends on:** none

**Behaviours:**

1. An event with a non-empty string `agent_type` and a non-empty string `agent_id` gets no output
   and exit 0, whatever the main transcript measures. Example: a transcript measuring past the
   stop threshold, a `Bash` PreToolUse with `agent_type` `general-purpose` and `agent_id` `a1`
   exits 0 with no output; the same event without the two fields is denied, as today.
2. Either field alone is not a subagent, as `hooks/review-guard`'s header records (a main session
   run with `--agent` carries `agent_type` and no `agent_id`). Example: past the threshold, a `Bash`
   PreToolUse with `agent_type` `helper` and no `agent_id` is denied; with `agent_id` `a1` and no
   `agent_type`, it is denied.
3. A subagent's event changes no state: no stop marker and no `.measure` file is written for it.
   Example: after behaviour 1's event, under a nested `TMPDIR`, the state directory holds no file
   for the event's session that was not there before.
4. `docs/05-token-and-memory-design.md`, where it describes the watchdog's events, says a subagent
   is left alone and why. Example: it contains `agent_id`.

**Done when:** `tests/test-context-watch.sh`, `tests/test-validate-citations.sh` and
`tests/test-harness-claims.sh` pass.

- [ ] **Step 2.1: Build it test first**

Follow `keel:tdd`. Write cases for behaviours 1 to 3 after the existing cases; `fire()` takes no
agent fields, so these events are built by hand, as the existing hand-written events are.
Run: `tests/test-context-watch.sh`
Expected before the implementation: FAIL, behaviour 1's case (the subagent is denied) and
behaviour 3's case (state is written). Expected after: PASS. Quote the failing output.

Run: the lint command. With the `Done when:` run above, that is the unit boundary. Run no
`tests/run-tests.sh`: the plan header names suite checkpoints.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 2.2: Hand over**

```bash
git add lib/context_watch.py tests/test-context-watch.sh docs/05-token-and-memory-design.md \
        CHANGELOG.md
git status --porcelain
```

Stage exactly those paths, and any flagged citation repairs by name, and stop. **Do not commit.**
The coordinator commits after both review passes, with
`git commit -m "fix(context-watch): leave a subagent alone"`.

---

### Task 3: the two files every task shifts are hot

**Story:** idea record item 5
**Files:**
- Modify: `tests/validate-citations.sh`
- Modify: `tests/test-validate-citations.sh`
- Modify: `templates/profile.schema.json`
- Modify: `docs/profile-keys.md`
- Modify: `docs/snapshot.md`
- Modify: `lib/harness/capabilities`
- Modify: `tests/validate-skills.sh`
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `CHANGELOG.md`

**Depends on:** none

**Behaviours:**

1. `hooks/done-guard` and `lib/context_watch.py` join the hot-file list in
   `tests/validate-citations.sh` (the `case` beside `bin/keel`), so a non-record file citing either
   by line fails and a record citing either by line does not. Example: in
   `tests/test-validate-citations.sh`, a fixture live document citing `hooks/done-guard:5` fails
   naming the hot-file rule, and the same line in a fixture under `docs/ideas/` passes.
2. Every live line citation into the two files becomes a phrase citation (`path#phrase`), so the
   repository validates. Example: `grep -rnE '(hooks/done-guard|lib/context_watch\.py):[0-9]'`
   over `docs/snapshot.md`, `docs/profile-keys.md`, `templates/profile.schema.json`,
   `lib/harness/capabilities` and `tests/validate-skills.sh` prints nothing, and
   `tests/validate-citations.sh` passes. `docs/profile-keys.md` is regenerated
   (`tests/generate-profile-keys.sh`), not edited by hand.
3. The plan template's guidance on global constraints says a plan tells implementers to repair the
   citations the validator flags and not to look for shifted citations in records, and why: on the
   2026-11-11 run that instruction caused most repairs outside a task's Files (11 of 13 tasks).
   Example: `plan-template.md` contains `do not look for shifted citations in records`.

Each phrase citation in `templates/profile.schema.json` sits within three lines below a line naming
the key's leaf, as the existing `code:bin/keel#...` entries do (`tests/validate-skills.sh` checks
it).

**Done when:** `tests/test-validate-citations.sh`, `tests/test-profile-keys.sh` and
`tests/test-harness-claims.sh` pass, and `tests/validate-citations.sh` exits 0.

- [ ] **Step 3.1: Build it test first**

Follow `keel:tdd`. Write behaviour 1's cases in `tests/test-validate-citations.sh` first.
Run: `tests/test-validate-citations.sh`
Expected before the implementation: FAIL, the live-document case passes validation because the two
files are not hot. Expected after: PASS. Quote the failing output.
Then add the two files to the list, run `tests/validate-citations.sh`, and convert each live
citation it now names (behaviour 2).

Run: the lint command. With the `Done when:` run above, that is the unit boundary. Run no
`tests/run-tests.sh`: the plan header names suite checkpoints.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 3.2: Hand over**

```bash
git add tests/validate-citations.sh tests/test-validate-citations.sh templates/profile.schema.json \
        docs/profile-keys.md docs/snapshot.md lib/harness/capabilities tests/validate-skills.sh \
        skills/write-plan/references/plan-template.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(citations): done-guard and context_watch are hot files"`.

---

### Task 4: reviewers keep to the scoped re-run

**Story:** idea record item 1
**Files:**
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `CHANGELOG.md`

**Depends on:** task 3

**Behaviours:** this task changes prompt text and has no failing test; each example is checked by
a reader against the diff and by the greps in `Done when:`.

1. The spec prompt's question 4 tells the reviewer to re-run the task's `Done when:` commands
   itself, which take seconds and are the one independent check that the report is real, and not
   to run `verify.test` or the lint command, quoting the report's output for those instead.
   Example: the spec prompt contains `do not run \`verify.test\``.
2. The quality prompt says the same of `verify.test` and lint: scoped tests are fine. Example: the
   quality prompt contains `do not run \`verify.test\``.
3. The paragraph under the spec prompt says why, with the measurement: 24 of 62 spec reviewers
   across three sessions ran the full suite. Example: it contains `24 of 62`.

**Done when:** `tests/test-validate-skills.sh` and `tests/test-validate-citations.sh` pass, and
`tr '\n' ' ' < skills/execute-plan/references/subagent-prompts.md | grep -o 'do not run
\`verify.test\`' | wc -l` prints at least `2` (joined first, since a phrase may wrap).

- [ ] **Step 4.1: Make the change and check it**

Edit the prompts as the behaviours say, keeping each prompt a fenced block the coordinator pastes.
Run: the `Done when:` commands and the lint command. Run no `tests/run-tests.sh`: the plan header
names suite checkpoints.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 4.2: Hand over**

```bash
git add skills/execute-plan/references/subagent-prompts.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(execute-plan): reviewers keep to the scoped re-run"`.

---

### Task 5: review-code reuses the plan-end checkpoint on the same commit

**Story:** idea record item 6
**Files:**
- Modify: `skills/review-code/SKILL.md`
- Modify: `skills/review-code/references/rationale.md`
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `docs/decisions/ADR-0017-a-plan-run-checks-the-suite-at-checkpoints.md`
- Modify: `CHANGELOG.md`

**Depends on:** task 4

**Behaviours:** this task changes skill text and an ADR and has no failing test; each example is
checked by a reader against the diff and by the greps in `Done when:`.

1. The checkpoint note records the tree the suite ran on: the coordinator runs `git write-tree`
   with the task staged, before the tick, and writes `; suite: pass at tree <tree sha>` or
   `; suite: red at tree <tree sha> <names>`. Example: the suite checkpoints section of
   `subagent-prompts.md` contains `git write-tree` and `suite: pass at tree`.
2. `review-code` step 3 runs `verify.test` itself unless the plan's last ticked step carries a
   `suite: pass at tree <sha>` note, `git diff --name-only <sha> HEAD` names nothing outside
   `docs/plans/`, and `git status --porcelain` is empty; then it quotes that note as the suite
   result. The rule sits in `references/rationale.md` or a new reference, and the body's word count
   does not grow. Example: step 3 contains `suite: pass at tree`.
3. `ship` is unchanged: it runs `verify.test` itself. Example: `skills/ship/SKILL.md` still
   contains `Not "the last run was green"`.
4. ADR-0017 records the amendment in its own `Amended` section, dated, naming the decision (Bernard,
   2026-11-12) and the cost it removes (one of the three suite runs on the final commit), without
   rewriting its original text. Example: it contains `Amended` and `2026-11-12`.

**Done when:** `tests/test-validate-skills.sh`, `tests/test-validate-citations.sh` and
`tests/test-doc-claims.sh` pass, and `grep -c 'suite: pass at tree' skills/review-code/SKILL.md`
prints at least `1`.

- [ ] **Step 5.1: Make the change and check it**

Edit as the behaviours say.
Run: the `Done when:` commands and the lint command. Run no `tests/run-tests.sh`: the plan header
names suite checkpoints.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 5.2: Hand over**

```bash
git add skills/review-code/SKILL.md skills/review-code/references/rationale.md \
        skills/execute-plan/references/subagent-prompts.md \
        docs/decisions/ADR-0017-a-plan-run-checks-the-suite-at-checkpoints.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(review-code): reuse the plan-end checkpoint on the same commit"`.

---

### Task 6: an older plan is offered checkpoints, and its boundary steps follow

**Story:** idea record item 7
**Files:**
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `docs/decisions/ADR-0017-a-plan-run-checks-the-suite-at-checkpoints.md`
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `CHANGELOG.md`

**Depends on:** task 5

**Behaviours:** this task changes skill text and an ADR and has no failing test; each example is
checked by a reader against the diff and by the greps in `Done when:`.

1. Before the first dispatch, a plan with no `**Suite checkpoints:**` line and 3 or more open
   tasks is offered checkpoints, in one question to the person (every 3 tasks, the default). On a
   yes, the coordinator writes the header line and rewrites each open task's boundary step to the
   template's checkpoint form (`Done when:` and lint, `verify.test_affected` where set, and no
   `verify.test`), and commits the plan alone as a repair (`docs(plans): <slug> suite checkpoints`)
   before dispatching. On a no, or with fewer than 3 open tasks, the plan runs as written. Example:
   the suite checkpoints section says `3 or more open tasks` and names the commit message.
2. The rewrite changes only the boundary step's run lines; every other line of the task is kept,
   and a ticked step is not touched. Example: the section says `a ticked step is not touched`.
3. ADR-0017's `Amended` section (from task 5) gains this second amendment, replacing "a plan with
   no such line is run as written" as the whole rule. Example: ADR-0017 contains `3 or more open
   tasks`.
4. The plan template's checkpoints paragraph ("A plan with no such line runs its steps as written")
   names the offer. Example: it contains `offered`.

**Done when:** `tests/test-validate-skills.sh`, `tests/test-validate-citations.sh` and
`tests/test-doc-claims.sh` pass, and `grep -c '3 or more open tasks'
skills/execute-plan/references/subagent-prompts.md` prints at least `1`.

- [ ] **Step 6.1: Make the change and check it**

Edit as the behaviours say.
Run: the `Done when:` commands and the lint command. Run no `tests/run-tests.sh`: the plan header
names suite checkpoints.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 6.2: Hand over**

```bash
git add skills/execute-plan/references/subagent-prompts.md \
        docs/decisions/ADR-0017-a-plan-run-checks-the-suite-at-checkpoints.md \
        skills/write-plan/references/plan-template.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(execute-plan): offer an older plan suite checkpoints"`.

---

### Task 7: the commits that will ask are planned for and announced

**Story:** idea record item 3
**Files:**
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `skills/execute-plan/references/delivery.md`
- Modify: `CHANGELOG.md`

**Depends on:** task 6

**Behaviours:** this task changes skill text and has no failing test; each example is checked by a
reader against the diff and by the greps in `Done when:`. It adds no code, no token, no ledger and
no wording that could answer sensitive-guard's `ask`: that decision stays the person's
(`hooks/sensitive-guard`, "WHY `ask` AND NOT `deny`").

1. The plan template orders a task that touches `hard_block_paths` as early as its `Depends on:`
   allows, and its header carries a `**Commits that ask:**` line naming those tasks, which the
   approval question states, so the person knows when they are needed. Example: the template's
   header block contains `**Commits that ask:**`.
2. Before committing a task whose `keel plan risk --staged` printed `loop: full`, the coordinator
   sends a `PushNotification` naming the task and that a commit approval is waiting, where that
   tool exists, and goes on to the commit; where it does not exist, nothing changes. Example:
   "Running the loop" in `subagent-prompts.md` contains `PushNotification`.
3. `delivery.md`, where it says a declined or unanswered ask stops a delivery run, names the
   notification as what precedes it. Example: it contains `PushNotification`.

**Done when:** `tests/test-validate-skills.sh` and `tests/test-validate-citations.sh` pass, and
`grep -c 'PushNotification' skills/execute-plan/references/subagent-prompts.md
skills/execute-plan/references/delivery.md` prints at least `1` for each file.

- [ ] **Step 7.1: Make the change and check it**

Edit as the behaviours say.
Run: the `Done when:` commands and the lint command. Run no `tests/run-tests.sh`: the plan header
names suite checkpoints.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 7.2: Hand over**

```bash
git add skills/write-plan/references/plan-template.md \
        skills/execute-plan/references/subagent-prompts.md \
        skills/execute-plan/references/delivery.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(plans): plan for and announce the commits that ask"`.

---

### Task 8: write-plan finds the live documents a change makes wrong

**Story:** idea record item 4
**Files:**
- Modify: `skills/write-plan/SKILL.md`
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `skills/write-plan/references/plan-review.md`
- Modify: `CHANGELOG.md`

**Depends on:** task 7

**Behaviours:** this task changes skill text and has no failing test; each example is checked by a
reader against the diff and by the greps in `Done when:`.

1. Mapping the files includes searching the live documents for the behaviour each task changes,
   and listing every hit in that task's `Files`: `README.md`, `docs/NN-*.md`, `docs/runbooks/`,
   `skills/`, `templates/profile.schema.json` and the generated `docs/profile-keys.md`. Records
   (`docs/plans`, `docs/ideas`, `docs/prd`, `docs/stories`, `docs/architecture`, `docs/decisions`,
   `docs/audits`, `CHANGELOG.md` entries already released) are not searched. It costs the measured
   resumes: 4 of 13 tasks on 2026-11-11, about 30 minutes. Example: `plan-template.md` contains
   `docs/runbooks/` and `4 of 13`.
2. `write-plan`'s step 2 points at that rule in place of words it already has; its body word count
   does not grow. Example: step 2 names `live documents`.
3. The plan review brief asks whether each task's `Files` names every live document the change
   makes wrong. Example: `plan-review.md` contains `live document`.

**Done when:** `tests/test-validate-skills.sh` and `tests/test-validate-citations.sh` pass, and
`grep -c 'live document' skills/write-plan/SKILL.md skills/write-plan/references/plan-review.md`
prints at least `1` for each file.

- [ ] **Step 8.1: Make the change and check it**

Edit as the behaviours say.
Run: the `Done when:` commands and the lint command. Run no `tests/run-tests.sh`: the plan header
names suite checkpoints.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 8.2: Hand over**

```bash
git add skills/write-plan/SKILL.md skills/write-plan/references/plan-template.md \
        skills/write-plan/references/plan-review.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(write-plan): find the live documents a change makes wrong"`.

---

### Task 9: `keel plan tick` takes several ids

**Story:** idea record item 8, first part
**Files:**
- Modify: `bin/keel`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `CHANGELOG.md`
- Test: `tests/test-plan.sh`

**Depends on:** none

**Behaviours:**

1. `keel plan tick <plan> <id> [<id> ...] [--note <text> | --defer <reason> | --not-applicable
   <reason>]` changes each id under one lock, with the same option for each. Example:
   `keel plan tick p.md 1.1 1.2 --note x` ticks both, each with ` Note: x`.
2. An unknown id among several changes nothing and exits non-zero naming it. Example: `keel plan
   tick p.md 1.1 9.9` leaves 1.1 open and prints `9.9`.
3. One id behaves as today, and the help line and the usage line printed in
   `docs/03-install-and-distribution.md` show the new form. Example: every existing tick case
   passes, `tests/test-plan.sh`'s help-line assertion matches `plan tick <plan> <id> [<id> ...]`,
   and the document contains `<id> [<id> ...]`.

**Done when:** `tests/test-plan.sh` passes.

- [ ] **Step 9.1: Build it test first**

Follow `keel:tdd`. Write cases for behaviours 1 and 2 after the existing tick cases.
Run: `tests/test-plan.sh`
Expected before the implementation: FAIL, behaviour 1's case (the usage guard rejects a fifth
argument or 1.2 stays open) and behaviour 2's case. Expected after: PASS. Quote the failing output.

Run: the lint command. With the `Done when:` run above, that is the unit boundary. Run no
`tests/run-tests.sh`: the plan header names suite checkpoints.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 9.2: Hand over**

```bash
git add bin/keel tests/test-plan.sh docs/03-install-and-distribution.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(plan): tick several ids at once"`.

---

### Task 10: the green run counts, and tdd stops sending readers to references

**Story:** idea record item 8, second and fourth parts
**Files:**
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `tests/evals/scenarios/commit-outside-a-worktree.md`
- Modify: `tests/evals/scenarios/implement-a-two-step-task.md`
- Modify: `tests/evals/scenarios/implement-a-five-step-task.md`
- Modify: `tests/evals/scenarios/implement-a-batched-task.md`
- Modify: `skills/tdd/SKILL.md`
- Modify: `CHANGELOG.md`

**Depends on:** task 8

**Behaviours:** this task changes skill and prompt text and has no failing test; each example is
checked by a reader against the diff and by the greps in `Done when:`.

1. The implementer prompt's REPORT says a GREEN run of exactly the `Done when:` commands, with no
   change after it, is the `Done when:` run, so it is not run a second time. The sentence goes in
   the paragraph that begins "Run the task's `Done when:` command", not in the "Name separately"
   paragraph, which `tests/test-eval-harness.sh` pins word for word. The four eval scenarios carry
   the same text. Example: the REPORT contains `no change after it`, and
   `tests/test-eval-harness.sh` passes.
2. `tdd`'s two "Read it before you do this step" sentences go; their links stay. `docs/standards.md`
   requires that sentence only for a brief a skill dispatches, which `tdd`'s references are not.
   Example: `tr '\n' ' ' < skills/tdd/SKILL.md | grep -c 'Read it before you do this step'` prints
   `0` (joined first: both sentences wrap today), the two `step-detail.md` links remain, and the
   body word count is lower than before.

**Done when:** `tests/test-validate-skills.sh`, `tests/test-validate-citations.sh` and
`tests/test-eval-harness.sh` pass, and the grep in behaviour 2 prints `0`.

- [ ] **Step 10.1: Make the change and check it**

Edit as the behaviours say.
Run: the `Done when:` commands and the lint command. Run no `tests/run-tests.sh`: the plan header
names suite checkpoints.
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
This is the one boundary run the task schedules.

- [ ] **Step 10.2: Hand over**

```bash
git add skills/execute-plan/references/subagent-prompts.md skills/tdd/SKILL.md CHANGELOG.md \
        tests/evals/scenarios/commit-outside-a-worktree.md \
        tests/evals/scenarios/implement-a-two-step-task.md \
        tests/evals/scenarios/implement-a-five-step-task.md \
        tests/evals/scenarios/implement-a-batched-task.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(skills): the green run counts, tdd links without orders"`.
