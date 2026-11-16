# Plan Upkeep Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task. Tasks 2 to 5 change skill text; their red is a
> wording pin in a test that fails before the text exists.

**Goal:** a plan stays true while it runs: its checkpoint records are complete and `keel plan status`
says when they are not, a task added mid-run updates the header lines that name tasks and lands in
its own commit, each task records the docs search behind its `Files`, citations into changing files
survive the run, answered questions leave no dead options, and a spec review cannot fail correct
code over a report the coordinator trimmed.
**Stories:** none. Source: the 2026-11-16 review of four plans written under 0.28.0
(sms-gateway `2026-11-13-catalog-and-accounts.md`, `2026-11-13-send-path.md`,
`2026-11-16-idempotency-and-rate-limit.md`; posta-accounts-billing-api `2026-11-13-counter-sales.md`)
against two written before it. Bernard directed on 2026-11-16: "yes and proceed as you would
recommend", to items 1 to 6 as scoped below.
**ADRs:** ADR-0017 (suite checkpoints; task 1 amends it), ADR-0012 (a task carries two steps),
ADR-0001 (skill body word ceiling: new detail goes in references), ADR-0011 (bodies hold
instructions, references the rest).
**Architecture:** one code change, in `bin/keel`'s `plan_status`: for a plan whose header has a
`**Suite checkpoints:**` line it prints `warn:` lines for a missing plan-start record and, once
`next: none`, a last task with no `suite:` note; the exit code and every existing line are
unchanged. The rest is text in `skills/write-plan/references/` and `skills/execute-plan/references/`,
each rule pinned by a grep in `tests/test-plan.sh`.
**Implementer routing:** inherit
**Suite checkpoints:** every 3 tasks
**Suite start:** pass at a6f03d5
**Commits that ask:** none. No task stages a `hard_block_paths` path (`hooks`, `lib/harness`,
`settings.json`, `.github/workflows`, `templates/ci-review.yml`, `lib/context_watch.py`).
**Delivery:** pull-request
**Concurrent batches:** none. `keel plan batches` on 2026-11-16 prints every task `alone`, with
`why: task 2 depends on task 1` and so on to task 5. The chain is there because every task adds a
line under `## Unreleased` in `CHANGELOG.md` and edits `tests/test-plan.sh`, and most share
`plan-template.md` or `subagent-prompts.md`, so they run one at a time in the order 1 to 5.
**Decided in this plan, put to Bernard at approval:**
- The plan-start record lives in a header line the coordinator writes, `**Suite start:** pass at
  <commit>` or `**Suite start:** red at <commit> <names>`, committed alone as
  `docs(plans): <slug> suite start` before the first dispatch, so the tree is clean when task 1 is
  dispatched and a discarded attempt cannot take the record with it. This plan's own coordinator
  writes that line too, though task 1 has not landed when the run starts.
- `ship` is not changed: its body is 697 of 700 words (`tests/validate-skills.sh`), and the warn
  lines already appear in the `plan status` output its gate 7 runs.
- An added task is written in the file where it runs, straight after the last committed task, so
  file order is run order and status's last task is the last one run. A `review-code` fix pass
  (`delivery.md`, "The run") stays a commit outside the task list, as now; only tasks the person
  adds from review or audit findings follow task 2's section.
- `plan status` checks end state only, not cadence. File order is not run order (counter-sales ran
  4a after 5; send-path inserted 6b and 15b), so counting every N tasks down the file would flag
  correct runs. The warnings change no exit code, so ship's gate and context-watch's `next:` read
  are unaffected.
- Dropped from the review's list: a rule for project-invented sections such as counter-sales'
  "Order of tasks" table (keel rules only on what its template defines; task 2 says order lives in
  `Depends on:`), and a record for review-code fix passes that stage `hard_block_paths`
  (sensitive-guard asks at those commits already; only the record was missing). The per-task
  boilerplate stays: each task must read on its own.
**Reviewed:** by a dispatched plan reviewer on 2026-11-16: one blocking finding (task 1 put warn
wording in `skills/ship/SKILL.md`, 3 words under its ceiling; ship is now left alone), and should-fix
items on task 1's example line count, where an added task sits in the file, which fix passes count
as tasks, how a `suite:` note is matched, and what counts as done. All folded in.
**Approved:** by Bernard, 2026-11-16: routing `inherit`, suite checkpoints every 3 tasks, delivered
to a pull request, commits that ask none, with the decisions above as written.

## Global constraints

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}` (so `tests/test-plan.sh`),
  lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh tests/evals/gate.sh tests/evals/isolation-check.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard hooks/review-guard`,
  at default severity. No typecheck, no build.
- Never commit on `main`; this plan runs on `plans/plan-upkeep`.
- Writing: no em dash, no en dash, no dash longer than a hyphen, in code, comments, docs and commit
  messages. No attribution footers, no `Co-Authored-By`.
- Commits are conventional, `type(scope): subject`.
- Each task adds one line under `## Unreleased` at the top of `CHANGELOG.md` (task 1 creates the
  heading above `## 0.28.0`), in the terse style of the 0.28.0 entries. Released entries are
  records: never edit them.
- A skill's `SKILL.md` body stays under the ADR-0001 word ceiling that `tests/validate-skills.sh`
  checks; put new detail in the skill's `references/`.
- Citations: `tests/validate-citations.sh` checks citations in live documents. Repair the citations
  it flags, and do not look for shifted citations in records (`docs/plans`, `docs/prd`,
  `docs/stories`, `docs/architecture`, `docs/decisions`, `docs/audits`, `docs/ideas`,
  `docs/07-open-decisions.md`, `docs/harness-support.md`, the eval fixtures, released
  `CHANGELOG.md` entries).
- A wording pin in `tests/test-plan.sh` follows the file's existing form under
  "the skills name the commands, and the fallback": `grep -qF '<anchor phrase>' "$f" && ok ... || bad ...`,
  one anchor phrase per rule, short enough to survive a rewording of the sentence around it.

---

### Task 1: `keel plan status` warns of a missing plan-start or plan-end suite record

**Story:** none (review item 2)
**Files:**
- Modify: `bin/keel`
- Modify: `tests/test-plan.sh`
- Modify: `docs/03-install-and-distribution.md`
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `docs/decisions/ADR-0017-a-plan-run-checks-the-suite-at-checkpoints.md`
- Modify: `CHANGELOG.md`

**Docs searched:** "plan status", "start record", "plan-start", "Suite checkpoints". Hits not listed:
`docs/05-token-and-memory-design.md` (resume from `next:`, unchanged), `skills/tdd/` (receives the
record, does not say where it is kept), `skills/write-plan/references/short-path.md` and
`plan-review.md` (run status for ids only), `skills/ship/SKILL.md` (gate 7 runs status and shows
its output; the warn lines change no exit code, and its body has 3 words of ceiling left).

**Depends on:** none

**Behaviours:**

1. For a plan with `**Suite checkpoints:** every 3 tasks` outside a fence, no `**Suite start:**`
   line, and at least one step marked done (`[x]`; deferred and not applicable do not count),
   status prints
   `warn: no **Suite start:** line, so the plan-start suite run is not recorded` after `next:`.
   Example: tasks 1 and 2 with step 1.1 ticked prints the three existing lines (`task 1: ...`,
   `task 2: ...`, `next: 1.2`), then that warn line, and exits 0.
2. The same plan with a header line `**Suite start:** pass at 3f9a1c2` prints no warn line.
   With no step done, no warn line either: the run has not started.
3. With `next: none`, status prints
   `warn: task <id> is the last task and carries no suite: note, so the plan-end suite run is not recorded`
   when no done step of the last task in file order that has a done step carries a `suite:` field
   whose value starts `pass at tree ` or `red at tree `. A field is read as `keel plan report`
   reads one: in the text after the step's last ` Note: `, at the start of the note or after `; `.
   A last task with no done step (all deferred or not applicable) is skipped for the one before it. Example: tasks 1 and 2 all ticked, `**Suite start:**` present,
   step 2.2's note `rounds: 1; loop: light` prints `warn: task 2 is the last task ...` and exits 0.
   With step 2.2's note `rounds: 1; suite: pass at tree abc123` it prints no warn line.
4. A plan with no `**Suite checkpoints:**` line, or one only inside a fenced block, prints exactly
   what it prints today, whatever its notes say.
5. Warn lines sit after `next:` and before any `problem:` line, and never change the exit code: a
   plan with a step id twice and a missing start record prints the warn line, then the problem
   line, and exits 1 as today.
6. `subagent-prompts.md`'s "Suite checkpoints" section says where the plan-start record goes (the
   `**Suite start:**` line, committed alone as `docs(plans): <slug> suite start` before the first
   dispatch), and that a task appended after the last checkpoint moves the plan-end checkpoint to
   the new last task. `plan-template.md`'s suite checkpoints paragraph names the line. Pinned by
   grep on `**Suite start:**` in both files.
7. `docs/03-install-and-distribution.md`'s `keel plan status` section names both warn lines and
   that they leave the exit code alone; ADR-0017 gains a dated `Amended` entry for the start line and the warnings.
   (`skills/ship/SKILL.md` is not changed: see the header.)

**Done when:** `tests/test-plan.sh` passes and `tests/validate-skills.sh` exits 0.

- [x] **Step 1.1: Build it test first** Note: red witnessed by the implementer (629 passed, 9 failed); the plan-template pin was reworded after the red run and checked against HEAD by grep, not seen failing in a test run

Follow `keel:tdd` for each behaviour: write its test from the example, run it, and watch it fail
for the reason the behaviour names, then write the minimal implementation and watch it pass.
Run: `tests/test-plan.sh` and `tests/validate-skills.sh`
Expected before the implementation: FAIL, the cases for behaviours 1, 3, 5, 6 and 7 fail because no
warn line or pinned phrase exists. Expected after: PASS. Quote the failing case and its message.

Run: the lint command from Global constraints. With the `Done when:` run above, that is the unit
boundary. Run no `tests/run-tests.sh`: the plan header names suite checkpoints, so the coordinator
runs the suite at checkpoints and hands you the last one's record as your start record. The task
text overrides the skill, so a step naming the suite would schedule it for every task, the cost
checkpoints remove. Expected: PASS, or reds this task did not cause, each named and matched against
the start record. This is the one boundary run the task schedules.

- [x] **Step 1.2: Hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES; report recovered from the transcript after done-guard's stop prompt replaced the final message

```bash
git add bin/keel tests/test-plan.sh docs/03-install-and-distribution.md \
        skills/execute-plan/references/subagent-prompts.md \
        skills/write-plan/references/plan-template.md \
        docs/decisions/ADR-0017-a-plan-run-checks-the-suite-at-checkpoints.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "feat(plan): status warns of a missing plan-start or plan-end suite record"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 2: a task added to an approved plan updates its header and lands in its own commit

**Story:** none (review items 1 and 6b)
**Files:**
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `skills/execute-plan/references/delivery.md`
- Modify: `tests/test-plan.sh`
- Modify: `CHANGELOG.md`

**Docs searched:** "appended to the plan", "plan repair", "docs(plans)", "Commits that ask",
"commits that ask". Hits not listed: `skills/write-plan/SKILL.md` and `short-path.md` (commit the
plan at approval, unchanged), `docs/02-skill-catalog.md` (the approval question, unchanged).

**Depends on:** task 1

**Behaviours:**

1. `plan-template.md` gains a section "Adding a task to an approved plan". A task added after
   approval, by the coordinator, the person or a review, is written with a header line
   `**Task <id> added:** <date>, <source and who decided>`, and in the same edit every header line
   the template defines that names tasks is rewritten to match: `**Commits that ask:**` names the
   new task when it stages a `hard_block_paths` path, `**Concurrent batches:**` is rewritten from a
   fresh `keel plan batches` run, and the new last task carries the plan-end checkpoint. The task is
   written where it runs, straight after the last committed task, so file order stays run order
   (counter-sales wrote 4a between 4 and 5 and ran it after 5). Order lives in `Depends on:` lines
   and file position, so a plan keeps no separate order table to fall out of date. Pinned by
   grep on `Adding a task to an approved plan` and `**Task <id> added:**`.
2. That section and `subagent-prompts.md`'s "The plan file is the exception, and it is yours"
   paragraph say a plan repair (a task added, a `Files` entry added, a step tightened) is committed
   alone as `docs(plans): <slug> <what>` before the next dispatch, with
   `git commit -m <msg> -- <plan>` when the task's paths are already staged, while ticks, tick
   notes and the follow-up list still ride with the task's commit. Example evidence the section
   cites: in sms-gateway's catalog plan, coordinator `Files` additions landed inside feature commits
   `30b7494` and `c5cb8d8`. Pinned by grep on `committed alone as` in both files.
3. `subagent-prompts.md`'s checkpoint rule that appends a fix task on an earlier task's red, and
   `delivery.md`'s "The run", where the person may add tasks from `review-code` or audit findings
   instead of the one fix pass, each point to the new section by name; the one fix pass itself is
   unchanged, a `fix: <what> (review-code)` commit outside the task list. Pinned
   by grep on `Adding a task to an approved plan` in both files.

**Done when:** `tests/test-plan.sh` passes and `tests/validate-skills.sh` exits 0.

- [ ] **Step 2.1: Build it test first**

Follow `keel:tdd` for each behaviour: write its pin from the example, run it, and watch it fail
because the phrase is absent, then write the text and watch it pass.
Run: `tests/test-plan.sh` and `tests/validate-skills.sh`
Expected before the implementation: FAIL, the pins for behaviours 1 to 3 fail. Expected after:
PASS. Quote the failing case and its message.

Run: the lint command from Global constraints. Run no `tests/run-tests.sh`: the coordinator runs
the suite at checkpoints and hands you the last one's record as your start record. Expected: PASS,
or reds this task did not cause, each named and matched against the start record. This is the one
boundary run the task schedules.

- [ ] **Step 2.2: Hand over**

```bash
git add skills/write-plan/references/plan-template.md \
        skills/execute-plan/references/subagent-prompts.md \
        skills/execute-plan/references/delivery.md tests/test-plan.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs(execute-plan): a task added mid-run updates the header in its own commit"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 3: each task records the docs search behind its Files, and the plan review checks it

**Story:** none (review item 3)
**Files:**
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `skills/write-plan/references/plan-review.md`
- Modify: `tests/test-plan.sh`
- Modify: `CHANGELOG.md`

**Docs searched:** "live document", "Docs searched". Hit not listed: `skills/write-plan/SKILL.md`
step 2 (already sends the writer to the template's live documents rule).

**Depends on:** task 2

**Behaviours:**

1. `plan-template.md`'s "Live documents in a task's Files" section requires a
   `**Docs searched:**` line after each task's `Files` block, naming the terms searched and any hit
   left out with its reason, as this plan's tasks do. Example: `**Docs searched:** "plan status",
   "start record". Hit not listed: docs/05 (unchanged).` It adds that the project's standards
   document is searched for any convention the task adds or changes, citing the evidence:
   `docs/standards.md` was the stale document in four of the reviewed tasks (catalog 6, 11, 12;
   send-path 1). Pinned by grep on `**Docs searched:**`.
2. The template's example task carries a `**Docs searched:**` line after its `Files` block, and
   `tests/test-plan.sh`'s existing case that the template's example task is in the strict form
   still passes (the label ends the `Files` block).
3. `plan-review.md`'s question 7 asks the reviewer to read each task's `**Docs searched:**` line,
   search the terms it missed, and name a task with no such line. Pinned by grep on
   `Docs searched` in `plan-review.md`.

**Done when:** `tests/test-plan.sh` passes and `tests/validate-skills.sh` exits 0.

- [ ] **Step 3.1: Build it test first**

Follow `keel:tdd` for each behaviour: write its pin from the example, run it, and watch it fail
because the phrase is absent, then write the text and watch it pass.
Run: `tests/test-plan.sh` and `tests/validate-skills.sh`
Expected before the implementation: FAIL, the pins for behaviours 1 and 3 fail. Expected after:
PASS, the strict-form case included. Quote the failing case and its message.

Run: the lint command from Global constraints. Run no `tests/run-tests.sh`: the coordinator runs
the suite at checkpoints and hands you the last one's record as your start record. Expected: PASS,
or reds this task did not cause, each named and matched against the start record. This is the one
boundary run the task schedules.

- [ ] **Step 3.2: Hand over**

```bash
git add skills/write-plan/references/plan-template.md \
        skills/write-plan/references/plan-review.md tests/test-plan.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs(write-plan): record each task's docs search and review it"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 4: citations survive the run, answered questions leave no dead options, size is reviewed

**Story:** none (review items 4 and 5)
**Files:**
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `skills/write-plan/references/plan-review.md`
- Modify: `tests/test-plan.sh`
- Modify: `CHANGELOG.md`

**Docs searched:** "path:line", "open question". Hits not listed: the other skills naming
`path:line` (findings and assessments, not plans), and the PRD, stories and design templates
(their own open questions).

**Depends on:** task 3

**Behaviours:**

1. `plan-template.md` gains a section "Citations": a file some task in the plan changes is cited
   by symbol or heading (`queue.go`, `func defaultQueue`), not by line; a line number is kept only
   for a file no task changes. Evidence cited: counter-sales' `openapi.yaml` and Go citations were
   exact at `ac733f4` and wrong by the end of its own run; send-path cited `queue.go:23` for code at
   `:30`. Pinned by grep on `cited by symbol or heading`.
2. The template's "No placeholders" section says that once the person answers an open question,
   the question is replaced by its answer, who gave it and the date, with one line naming the
   options not taken; text that applied only to another option goes, and a header line written
   conditionally on the answer is rewritten. Evidence cited: the idempotency plan kept options B
   and C, an "Under option B" paragraph and a conditional `**Commits that ask:**` line after the
   owner chose. Pinned by grep on `replaced by its answer`.
3. `plan-review.md` gains question 8: name any citation by line into a file a task changes, any
   text kept for an option not taken, and any decision stated both before task 1 and in a task;
   and say whether the text before task 1 is longer than the tasks need (the idempotency plan's was
   36% of 796 lines). Findings are `should fix` or `consider`, never `blocking`. The prompt's
   "Answer seven questions." becomes "Answer eight questions.". Pinned by grep on
   `Answer eight questions` and `option not taken`.

**Done when:** `tests/test-plan.sh` passes and `tests/validate-skills.sh` exits 0.

- [ ] **Step 4.1: Build it test first**

Follow `keel:tdd` for each behaviour: write its pin from the example, run it, and watch it fail
because the phrase is absent, then write the text and watch it pass.
Run: `tests/test-plan.sh` and `tests/validate-skills.sh`
Expected before the implementation: FAIL, the pins for behaviours 1 to 3 fail. Expected after:
PASS. Quote the failing case and its message.

Run: the lint command from Global constraints. Run no `tests/run-tests.sh`: the coordinator runs
the suite at checkpoints and hands you the last one's record as your start record. Expected: PASS,
or reds this task did not cause, each named and matched against the start record. This is the one
boundary run the task schedules.

- [ ] **Step 4.2: Hand over**

```bash
git add skills/write-plan/references/plan-template.md \
        skills/write-plan/references/plan-review.md tests/test-plan.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs(write-plan): cite changing files by symbol, collapse answered questions"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.

### Task 5: the spec reviewer reads the tree's status itself and is handed the whole report

**Story:** none (review item 6a)
**Files:**
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `tests/test-plan.sh`
- Modify: `CHANGELOG.md`

**Docs searched:** "IMPLEMENTER REPORT", "verbatim". Hit not listed: `agents/keel-reviewer.md`
(holds the git rules, not the six questions; checked, unchanged).

**Depends on:** task 4

**Behaviours:**

1. The spec compliance prompt's question 2 tells the reviewer to run `git status --porcelain`
   itself and name any path no step asked for, and states that a report's form (a missing or
   trimmed porcelain paste) is not a ground for DEVIATES; questions 5 and 6 are unchanged. Pinned
   by grep on `run \`git status --porcelain\` yourself`.
2. The text under the spec prompt says the coordinator pastes the implementer's report whole, its
   last line included, citing the evidence: sms-gateway catalog task 7 got a spec DEVIATES on
   correct code because the coordinator's brief left out the porcelain line the report held.
   Pinned by grep on `its last line included`.

**Done when:** `tests/test-plan.sh` passes, and `tests/test-agents.sh` and
`tests/validate-skills.sh` exit 0.

- [ ] **Step 5.1: Build it test first**

Follow `keel:tdd` for each behaviour: write its pin from the example, run it, and watch it fail
because the phrase is absent, then write the text and watch it pass.
Run: `tests/test-plan.sh`, `tests/test-agents.sh` and `tests/validate-skills.sh`
Expected before the implementation: FAIL, the pins for behaviours 1 and 2 fail. Expected after:
PASS. Quote the failing case and its message.

Run: the lint command from Global constraints. Run no `tests/run-tests.sh`: the coordinator runs
the suite at checkpoints and hands you the last one's record as your start record. Expected: PASS,
or reds this task did not cause, each named and matched against the start record. This is the one
boundary run the task schedules.

- [ ] **Step 5.2: Hand over**

```bash
git add skills/execute-plan/references/subagent-prompts.md tests/test-plan.sh CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "docs(execute-plan): the spec reviewer reads the tree's status itself"`.
Paste the `git status --porcelain` output into your report; if it lists anything this task did not
touch, say so and leave it unstaged.
