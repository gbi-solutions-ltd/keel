# Prune the skill bodies to the target Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** every skill body is under 700 words, and ADR-0011 makes 700 the hard ceiling, superseding
ADR-0001.
**Stories:** none. The input is `docs/ideas/factory-reliability.md`, item 4 and "Decided" 1, and
Bernard's answers of 2026-10-17 recorded below.
**ADRs:** ADR-0001 (superseded by task 15), ADR-0005, ADR-0011 (written by task 15)
**Architecture:** each of the eleven long bodies is cut in a fixed order, stopping as soon as it is
under 700: reasoning moves to a new `references/rationale.md`; an instruction a linked reference of
the same skill already states in full is deleted; then step detail moves to a new
`references/step-detail.md`, the step keeping a one-line instruction and a link that says to read it
before doing the step. Once every body is under 700, the validator's ceiling drops from 900 to 700,
warning within 30 words of it, with no eval-arm exception. One eval arm per pruned body, which also
tests whether a model opens a step-detail link, plus a new scenario for `setup-deployment`, which
has none.
**Implementer routing:** inherit
**Delivery:** hand-off
**Concurrent batches:** tasks 1 to 6 may run at the same time. Tasks 7 to 11 may run at the same
time, and start after tasks 1 to 6 land: the split is for the load on the machine running the
worktrees, not a dependency, and `keel plan batches` prints tasks 1 to 11 as one batch. Task 12 runs
alone, because its fixture carries a `.keel/profile.json`, which the batch rules count as shared
config. Task 13 requires tasks 1 to 12. Task 14 requires task 13. Task 15 requires task 14 and the
coordinator's arms.
**Batch gate:** after each batch lands, `tests/run-tests.sh` is green, except
`tests/validate-citations.sh` failures that name a `SKILL.md` a task in the batch pruned. Those are
listed at the join and repointed by task 13.

## What Bernard decided, 2026-10-17

- **ADR-0001:** "Prune to the target": "Move each long body's reasoning into a reference; bodies go
  back under 700. Each pruned body owes an eval arm". That supersedes ADR-0001.
- **Scope:** "All eleven", every body over 700 words, not only the four within 20 words of 900.
- **The new limit:** "700 hard", with no eval-arm exception: room is made in references.
- **Eval arms:** "1 run each, new scenario": one arm per pruned body on the existing scenarios, plus
  a new `setup-deployment` scenario with its own baseline.
- **What may leave a body**, after the plan review estimated that reasoning alone leaves `tdd`,
  `execute-plan`, `write-plan` and `ship` near 750: "Dedupe, then move step detail". First
  reasoning, then an instruction a linked reference already states, then step detail to a reference
  with a one-line instruction and a read-before link. The arms measure whether a model still opens
  the link.
- **`tdd`'s rationalisations table**, 2026-10-18, after task 1's fix pass restored it (Bernard's
  ruling of 2026-09-07 kept those rows in the body) and the body stood at 778 with every other
  permitted cut leaving about 736: "Cues in body, answers out". The three excuses stay in the body
  word for word, as red flags; the answers move to `skills/tdd/references/rationalisations.md`,
  which task 1 may therefore modify. The `tdd-under-deadline` arm tests whether that holds under
  deadline pressure.
- **`tdd`'s second-unit clause**, 2026-10-18: task 1's fix pass removed RED's "a case needing a
  second change is a second unit" as a duplicate stated only by example. Restoring it put the body
  at 706: "Restore it, move the tally detail". The clause goes back into the body, and Verify RED's
  worked tally moves to `skills/tdd/references/step-detail.md`.
- **Where the warning starts**, after the review counted about 20 of 25 skills between 650 and 700:
  "Within 30 of 700", replacing the earlier "warn at 650". It fires from 671, as today's fires
  within 30 of 900.

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test `tests/{name}`,
  lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh
  tests/evals/run.sh tests/evals/stage.sh tests/evals/gate.sh hooks/session-start
  hooks/context-watch hooks/sensitive-guard hooks/done-guard hooks/review-guard`. One `shellcheck`
  over every file needs about 3.3GB; on a small machine lint the changed files.
- Work on `sandbox`, never on `main`.
- `tests/validate-skills.sh` counts a body as everything after the frontmatter's closing `---`, with
  `wc -w`. That count is the one every behaviour below means.
- `docs/standards.md`, "Skills are markdown, and the body is a budget": "Reach for a reference
  because a reader needs it at one step, not as a way to buy words." Step detail moved by this plan
  is linked from the step that needs it, with a sentence saying to read it before doing that step.
- `docs/standards.md`, "Subagent briefs stay in the body, or the dispatching step says to read
  them": a brief the skill dispatches stays in the body unless it would push the body past 700, and
  then the dispatching step links it and says to read it before building the call, and names the
  checks the skill exists for.
- `docs/standards.md`: no em or en dashes; prose lines at most 100 columns; no `@` links; relative
  links resolve; no hardcoded `docs/keel` path in a skill.
- A skill's frontmatter is not edited: its description is the always-loaded text, budgeted
  separately (decision 6 in `docs/07-open-decisions.md`).
- ADR-0005: one skill body per skill across harnesses. No harness-specific copy of a body.
- Name paths when staging or committing. Never `git add -A`, `git add .` or `git commit -a`.
- A dated citation in a document is a record and is left alone; an undated present-tense claim is
  live and is kept true (`tests/test-doc-claims.sh`, "WHICH COPIES THIS ASSERTS, AND THE RULE").
- Nothing staged into an eval arm names `tests/evals` (case 4 of `tests/test-eval-harness.sh`), so
  no `references/` file cites `tests/evals/results.md` or a scenario.

---
### Task 1: `tdd`'s body goes under 700, reasons first

**Files:**
- Modify: `skills/tdd/SKILL.md`
- Create: `skills/tdd/references/rationale.md`
- Create (only when behaviour 5 is reached): `skills/tdd/references/step-detail.md`

**Depends on:** none

**Behaviours:**

1. The `tdd` body is under 700 words. Example: `tests/validate-skills.sh` printed `WARN  tdd: body
   is 898 words` before the task and prints no `WARN  tdd:` line after it.
2. The body is cut in this order, and the cutting stops as soon as it is under 700: behaviour 3,
   then 4, then 5. A later kind is used only when the earlier ones are exhausted. Example: if moving
   reasoning brings the body to 690, no instruction is deduplicated and no step detail moves.
3. Reasoning moves to `skills/tdd/references/rationale.md`: why a step or rule exists, the incident
   or date behind it, measured evidence, a comparison with an alternative, and a "because" clause
   whose instruction stands without it. It goes under one `##` heading per step it explains, named
   after that step, keeping every claim; wording may be tightened. Example: "Run X before Y, because
   Z happened" becomes "Run X before Y." in the body and the Z sentence under that step's heading in
   `rationale.md`.
4. An instruction that a reference of `tdd` already linked from the same step states in full is
   deleted from the body, and the step keeps its link. The report names the reference and the
   heading or lines that hold it. Example: a table in a step that its linked reference reproduces
   row for row is deleted, and the step's sentence linking the reference stays.
5. Step detail moves to `skills/tdd/references/step-detail.md`, under a `##` heading named after its
   step: the how of a step (sub-cases, worked examples, long lists of conditions), never what the
   step requires. The step keeps a one-line instruction saying what to do, and a sentence linking
   the heading with "read it before you do this step". Example: a step "Run the suite; if it fails
   because ..., then ...; if ..." keeps "Run the suite, and read the conditions in
   `references/step-detail.md` before deciding a failure is not yours." Each `## Step` heading of
   the body stays.
6. The Overview gains one sentence linking the reasons, of the form "Why each step is as it is:
   `references/rationale.md`. Read it before changing a step.", written as a real relative link.
   `rationale.md`, and `step-detail.md` if it exists, opens with one line saying what it holds for
   `tdd` and that the steps themselves are in `SKILL.md`.
7. A subagent brief or dispatch instruction stays in the body, per the Global constraint: the model,
   the description label, the agent type and the checks it carries are instructions. Neither
   `references/rationale.md` nor `step-detail.md` names `tests/evals`.
8. The frontmatter is unchanged, and nothing a test pins moves. Every phrase
   `tests/validate-skills.sh` requires in a body stays in it: the profile-schema markers
   `templates/profile.schema.json` cites (`tests/validate-skills.sh:972-978`), the plugin names
   (`:502-503`) and `repo-snapshot`'s Step 6 (`:627-630`). Example: `git diff` shows no line above
   the closing `---` of `skills/tdd/SKILL.md` changing. The schema markers `verify.test_affected`
   and `verify.test_integration` stay in the body. `references/rationalisations.md` already holds
   rationalisation rows; a row it states in full is deleted from the body rather than copied, by
   behaviour 4.
9. If behaviours 3 to 5 together cannot bring the body under 700, the task stops: the body is left
   as it stands, uncommitted in this task's worktree, and the report gives the count, the shortfall
   and every passage left, each marked instruction, duplicate or detail. No instruction is cut or
   merged away to fit. The coordinator takes it to Bernard; the rest of the batch does not wait for
   it.
10. No file outside this task's Files is edited. A `tests/validate-citations.sh` failure naming
    `skills/tdd/SKILL.md` is listed in the report, with the citing file, line and phrase, and left
    for task 13. Any other failure it reports is this task's to fix within its own files.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh` pass, and `bash
tests/validate-skills.sh` prints no `WARN  tdd:` line.

- [x] **Step 1.1: Watch the validator flag the body** Note: performed by the implementer across three passes; spec reviewers reran the checks each round

Run: `bash tests/validate-skills.sh 2>&1 | grep 'WARN  tdd:'`
Expected: one line, `body is 898 words`. This is the red the task turns green.

- [x] **Step 1.2: Sort the body** Note: performed by the implementer across three passes; spec reviewers reran the checks each round

Read `skills/tdd/SKILL.md` and every reference it links. Mark each paragraph, bullet and table row
as instruction, reasoning, duplicate (naming the reference that holds it) or step detail, by
behaviours 3 to 5 and 7 to 8, and count the words in each kind. Keep the list for the report.

- [x] **Step 1.3: Cut the body in order** Note: performed by the implementer across three passes; spec reviewers reran the checks each round

Behaviour 3, then 4, then 5, stopping once under 700, then behaviour 6. If it cannot reach 700, stop
by behaviour 9.

- [x] **Step 1.4: Watch it pass** Note: performed by the implementer across three passes; spec reviewers reran the checks each round

Run: `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh`.
Expected: all pass, and no `WARN  tdd:` line. Then run `bash tests/validate-citations.sh` and list
any failure naming `skills/tdd/SKILL.md`, per behaviour 10.

- [x] **Step 1.5: Commit** Note: rounds: 4; routing: inherit; loop: light; 898 to 699; spec DEVIATES (the rationalisations table moved as reasoning, against Bernard's 2026-09-07 ruling), fix restored it and stopped at 778 by behaviour 9; Bernard ruled 'Cues in body, answers out' (excuses as red flags, answers in rationalisations.md); spec DEVIATES (a 'second unit' clause cut as a duplicate stated only by example); Bernard ruled 'Restore it, move the tally detail'; spec DEVIATES on 'per case' wording, a two-word fix the reviewer specified; landed from worktree 88e0fdc

You are in your own worktree, so this task commits rather than handing over.

```bash
git add skills/tdd/SKILL.md skills/tdd/references/rationale.md
# and skills/tdd/references/step-detail.md if behaviour 5 created it
git commit -m "refactor(tdd): the body goes under 700, its reasons in references/rationale.md"
```

Report the body's count before and after, the sorted list from step 1.2 with where each passage that
left now lives, whether `step-detail.md` was needed, and the citation failures from step 1.4. Arm
owed for this body: `tdd-under-deadline`, run by the coordinator after the batch, not by this task.

### Task 2: `execute-plan`'s body goes under 700, reasons first

**Files:**
- Modify: `skills/execute-plan/SKILL.md`
- Create: `skills/execute-plan/references/rationale.md`
- Create (only when behaviour 5 is reached): `skills/execute-plan/references/step-detail.md`

**Depends on:** none

**Behaviours:**

1. The `execute-plan` body is under 700 words. Example: `tests/validate-skills.sh` printed `WARN
   execute-plan: body is 894 words` before the task and prints no `WARN  execute-plan:` line after
   it.
2. The body is cut in this order, and the cutting stops as soon as it is under 700: behaviour 3,
   then 4, then 5. A later kind is used only when the earlier ones are exhausted. Example: if moving
   reasoning brings the body to 690, no instruction is deduplicated and no step detail moves.
3. Reasoning moves to `skills/execute-plan/references/rationale.md`: why a step or rule exists, the
   incident or date behind it, measured evidence, a comparison with an alternative, and a "because"
   clause whose instruction stands without it. It goes under one `##` heading per step it explains,
   named after that step, keeping every claim; wording may be tightened. Example: "Run X before Y,
   because Z happened" becomes "Run X before Y." in the body and the Z sentence under that step's
   heading in `rationale.md`.
4. An instruction that a reference of `execute-plan` already linked from the same step states in
   full is deleted from the body, and the step keeps its link. The report names the reference and
   the heading or lines that hold it. Example: a table in a step that its linked reference
   reproduces row for row is deleted, and the step's sentence linking the reference stays.
5. Step detail moves to `skills/execute-plan/references/step-detail.md`, under a `##` heading named
   after its step: the how of a step (sub-cases, worked examples, long lists of conditions), never
   what the step requires. The step keeps a one-line instruction saying what to do, and a sentence
   linking the heading with "read it before you do this step". Example: a step "Run the suite; if it
   fails because ..., then ...; if ..." keeps "Run the suite, and read the conditions in
   `references/step-detail.md` before deciding a failure is not yours." Each `## Step` heading of
   the body stays.
6. The Overview gains one sentence linking the reasons, of the form "Why each step is as it is:
   `references/rationale.md`. Read it before changing a step.", written as a real relative link.
   `rationale.md`, and `step-detail.md` if it exists, opens with one line saying what it holds for
   `execute-plan` and that the steps themselves are in `SKILL.md`.
7. A subagent brief or dispatch instruction stays in the body, per the Global constraint: the model,
   the description label, the agent type and the checks it carries are instructions. Neither
   `references/rationale.md` nor `step-detail.md` names `tests/evals`.
8. The frontmatter is unchanged, and nothing a test pins moves. Every phrase
   `tests/validate-skills.sh` requires in a body stays in it: the profile-schema markers
   `templates/profile.schema.json` cites (`tests/validate-skills.sh:972-978`), the plugin names
   (`:502-503`) and `repo-snapshot`'s Step 6 (`:627-630`). Example: `git diff` shows no line above
   the closing `---` of `skills/execute-plan/SKILL.md` changing. Step 4's tick paragraph is pinned
   word for word by case 25 of `tests/test-eval-harness.sh` (`tests/test-eval-harness.sh:480-481`),
   and `tests/test-plan.sh:3013-3044` matches whole lines of Step 4 with `grep -F`. That paragraph
   stays in the body exactly as it is, line breaks included. The Step 1 table that
   `references/preconditions.md:11-17` repeats may be deleted by behaviour 4 only if that reference
   states every row in full and the step keeps a one-line instruction and its link.
9. If behaviours 3 to 5 together cannot bring the body under 700, the task stops: the body is left
   as it stands, uncommitted in this task's worktree, and the report gives the count, the shortfall
   and every passage left, each marked instruction, duplicate or detail. No instruction is cut or
   merged away to fit. The coordinator takes it to Bernard; the rest of the batch does not wait for
   it.
10. No file outside this task's Files is edited. A `tests/validate-citations.sh` failure naming
    `skills/execute-plan/SKILL.md` is listed in the report, with the citing file, line and phrase,
    and left for task 13. Any other failure it reports is this task's to fix within its own files.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh`, `bash tests/test-harness-claims.sh` and `bash tests/test-plan.sh` pass,
and `bash tests/validate-skills.sh` prints no `WARN  execute-plan:` line.

- [x] **Step 2.1: Watch the validator flag the body** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Run: `bash tests/validate-skills.sh 2>&1 | grep 'WARN  execute-plan:'`
Expected: one line, `body is 894 words`. This is the red the task turns green.

- [x] **Step 2.2: Sort the body** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Read `skills/execute-plan/SKILL.md` and every reference it links. Mark each paragraph, bullet and
table row as instruction, reasoning, duplicate (naming the reference that holds it) or step detail,
by behaviours 3 to 5 and 7 to 8, and count the words in each kind. Keep the list for the report.

- [x] **Step 2.3: Cut the body in order** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Behaviour 3, then 4, then 5, stopping once under 700, then behaviour 6. If it cannot reach 700, stop
by behaviour 9.

- [x] **Step 2.4: Watch it pass** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Run: `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh`, `bash tests/test-harness-claims.sh` and `bash tests/test-plan.sh`.
Expected: all pass, and no `WARN  execute-plan:` line. Then run `bash tests/validate-citations.sh`
and list any failure naming `skills/execute-plan/SKILL.md`, per behaviour 10.

- [x] **Step 2.5: Commit** Note: rounds: 1; routing: inherit; loop: light; 894 to 673, reasons then the Step 1 table as a duplicate of preconditions.md; spec COMPLIES; checks rerun by the reviewer; committed in its worktree as d2bf871, landed as ea82fda

You are in your own worktree, so this task commits rather than handing over.

```bash
git add skills/execute-plan/SKILL.md skills/execute-plan/references/rationale.md
# and skills/execute-plan/references/step-detail.md if behaviour 5 created it
git commit -m "refactor(execute-plan): the body goes under 700, its reasons in references/rationale.md"
```

Report the body's count before and after, the sorted list from step 2.2 with where each passage that
left now lives, whether `step-detail.md` was needed, and the citation failures from step 2.4. Arm
owed for this body: `run-a-short-path-plan`, run by the coordinator after the batch, not by this
task.

### Task 3: `write-plan`'s body goes under 700, reasons first

**Files:**
- Modify: `skills/write-plan/SKILL.md`
- Create: `skills/write-plan/references/rationale.md`
- Create (only when behaviour 5 is reached): `skills/write-plan/references/step-detail.md`

**Depends on:** none

**Behaviours:**

1. The `write-plan` body is under 700 words. Example: `tests/validate-skills.sh` printed `WARN
   write-plan: body is 893 words` before the task and prints no `WARN  write-plan:` line after it.
2. The body is cut in this order, and the cutting stops as soon as it is under 700: behaviour 3,
   then 4, then 5. A later kind is used only when the earlier ones are exhausted. Example: if moving
   reasoning brings the body to 690, no instruction is deduplicated and no step detail moves.
3. Reasoning moves to `skills/write-plan/references/rationale.md`: why a step or rule exists, the
   incident or date behind it, measured evidence, a comparison with an alternative, and a "because"
   clause whose instruction stands without it. It goes under one `##` heading per step it explains,
   named after that step, keeping every claim; wording may be tightened. Example: "Run X before Y,
   because Z happened" becomes "Run X before Y." in the body and the Z sentence under that step's
   heading in `rationale.md`.
4. An instruction that a reference of `write-plan` already linked from the same step states in full
   is deleted from the body, and the step keeps its link. The report names the reference and the
   heading or lines that hold it. Example: a table in a step that its linked reference reproduces
   row for row is deleted, and the step's sentence linking the reference stays.
5. Step detail moves to `skills/write-plan/references/step-detail.md`, under a `##` heading named
   after its step: the how of a step (sub-cases, worked examples, long lists of conditions), never
   what the step requires. The step keeps a one-line instruction saying what to do, and a sentence
   linking the heading with "read it before you do this step". Example: a step "Run the suite; if it
   fails because ..., then ...; if ..." keeps "Run the suite, and read the conditions in
   `references/step-detail.md` before deciding a failure is not yours." Each `## Step` heading of
   the body stays.
6. The Overview gains one sentence linking the reasons, of the form "Why each step is as it is:
   `references/rationale.md`. Read it before changing a step.", written as a real relative link.
   `rationale.md`, and `step-detail.md` if it exists, opens with one line saying what it holds for
   `write-plan` and that the steps themselves are in `SKILL.md`.
7. A subagent brief or dispatch instruction stays in the body, per the Global constraint: the model,
   the description label, the agent type and the checks it carries are instructions. Neither
   `references/rationale.md` nor `step-detail.md` names `tests/evals`.
8. The frontmatter is unchanged, and nothing a test pins moves. Every phrase
   `tests/validate-skills.sh` requires in a body stays in it: the profile-schema markers
   `templates/profile.schema.json` cites (`tests/validate-skills.sh:972-978`), the plugin names
   (`:502-503`) and `repo-snapshot`'s Step 6 (`:627-630`). Example: `git diff` shows no line above
   the closing `---` of `skills/write-plan/SKILL.md` changing. Step 4's placeholder list stays in
   the body: `docs/standards.md` records it as existing nowhere else.
9. If behaviours 3 to 5 together cannot bring the body under 700, the task stops: the body is left
   as it stands, uncommitted in this task's worktree, and the report gives the count, the shortfall
   and every passage left, each marked instruction, duplicate or detail. No instruction is cut or
   merged away to fit. The coordinator takes it to Bernard; the rest of the batch does not wait for
   it.
10. No file outside this task's Files is edited. A `tests/validate-citations.sh` failure naming
    `skills/write-plan/SKILL.md` is listed in the report, with the citing file, line and phrase, and
    left for task 13. Any other failure it reports is this task's to fix within its own files.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh` pass, and `bash
tests/validate-skills.sh` prints no `WARN  write-plan:` line.

- [x] **Step 3.1: Watch the validator flag the body** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Run: `bash tests/validate-skills.sh 2>&1 | grep 'WARN  write-plan:'`
Expected: one line, `body is 893 words`. This is the red the task turns green.

- [x] **Step 3.2: Sort the body** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Read `skills/write-plan/SKILL.md` and every reference it links. Mark each paragraph, bullet and
table row as instruction, reasoning, duplicate (naming the reference that holds it) or step detail,
by behaviours 3 to 5 and 7 to 8, and count the words in each kind. Keep the list for the report.

- [x] **Step 3.3: Cut the body in order** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Behaviour 3, then 4, then 5, stopping once under 700, then behaviour 6. If it cannot reach 700, stop
by behaviour 9.

- [x] **Step 3.4: Watch it pass** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Run: `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh`.
Expected: all pass, and no `WARN  write-plan:` line. Then run `bash tests/validate-citations.sh` and
list any failure naming `skills/write-plan/SKILL.md`, per behaviour 10.

- [x] **Step 3.5: Commit** Note: rounds: 1; routing: inherit; loop: light; 893 to 684, reasons then the five-steps paragraph as a duplicate of plan-template.md; spec COMPLIES; two citation failures for task 13; worktree 54833b5, landed ba8231d

You are in your own worktree, so this task commits rather than handing over.

```bash
git add skills/write-plan/SKILL.md skills/write-plan/references/rationale.md
# and skills/write-plan/references/step-detail.md if behaviour 5 created it
git commit -m "refactor(write-plan): the body goes under 700, its reasons in references/rationale.md"
```

Report the body's count before and after, the sorted list from step 3.2 with where each passage that
left now lives, whether `step-detail.md` was needed, and the citation failures from step 3.4. Arm
owed for this body: `implement-a-small-change`, run by the coordinator after the batch, not by this
task.

### Task 4: `ship`'s body goes under 700, reasons first

**Files:**
- Modify: `skills/ship/SKILL.md`
- Create: `skills/ship/references/rationale.md`
- Create (only when behaviour 5 is reached): `skills/ship/references/step-detail.md`

**Depends on:** none

**Behaviours:**

1. The `ship` body is under 700 words. Example: `tests/validate-skills.sh` printed `WARN  ship: body
   is 885 words` before the task and prints no `WARN  ship:` line after it.
2. The body is cut in this order, and the cutting stops as soon as it is under 700: behaviour 3,
   then 4, then 5. A later kind is used only when the earlier ones are exhausted. Example: if moving
   reasoning brings the body to 690, no instruction is deduplicated and no step detail moves.
3. Reasoning moves to `skills/ship/references/rationale.md`: why a step or rule exists, the incident
   or date behind it, measured evidence, a comparison with an alternative, and a "because" clause
   whose instruction stands without it. It goes under one `##` heading per step it explains, named
   after that step, keeping every claim; wording may be tightened. Example: "Run X before Y, because
   Z happened" becomes "Run X before Y." in the body and the Z sentence under that step's heading in
   `rationale.md`.
4. An instruction that a reference of `ship` already linked from the same step states in full is
   deleted from the body, and the step keeps its link. The report names the reference and the
   heading or lines that hold it. Example: a table in a step that its linked reference reproduces
   row for row is deleted, and the step's sentence linking the reference stays.
5. Step detail moves to `skills/ship/references/step-detail.md`, under a `##` heading named after
   its step: the how of a step (sub-cases, worked examples, long lists of conditions), never what
   the step requires. The step keeps a one-line instruction saying what to do, and a sentence
   linking the heading with "read it before you do this step". Example: a step "Run the suite; if it
   fails because ..., then ...; if ..." keeps "Run the suite, and read the conditions in
   `references/step-detail.md` before deciding a failure is not yours." Each `## Step` heading of
   the body stays.
6. The Overview gains one sentence linking the reasons, of the form "Why each step is as it is:
   `references/rationale.md`. Read it before changing a step.", written as a real relative link.
   `rationale.md`, and `step-detail.md` if it exists, opens with one line saying what it holds for
   `ship` and that the steps themselves are in `SKILL.md`.
7. A subagent brief or dispatch instruction stays in the body, per the Global constraint: the model,
   the description label, the agent type and the checks it carries are instructions. Neither
   `references/rationale.md` nor `step-detail.md` names `tests/evals`.
8. The frontmatter is unchanged, and nothing a test pins moves. Every phrase
   `tests/validate-skills.sh` requires in a body stays in it: the profile-schema markers
   `templates/profile.schema.json` cites (`tests/validate-skills.sh:972-978`), the plugin names
   (`:502-503`) and `repo-snapshot`'s Step 6 (`:627-630`). Example: `git diff` shows no line above
   the closing `---` of `skills/ship/SKILL.md` changing. The schema markers `verify.format_fix`,
   `profile.conventions.commit_style` and `gates.security_audit` stay in the body, so the
   `format_fix` exception is not moved as step detail. Gate item 7 is matched line by line with
   `grep -F` by `tests/test-plan.sh:3035-3044`, so it stays in the body exactly as it is, line
   breaks included.
9. If behaviours 3 to 5 together cannot bring the body under 700, the task stops: the body is left
   as it stands, uncommitted in this task's worktree, and the report gives the count, the shortfall
   and every passage left, each marked instruction, duplicate or detail. No instruction is cut or
   merged away to fit. The coordinator takes it to Bernard; the rest of the batch does not wait for
   it.
10. No file outside this task's Files is edited. A `tests/validate-citations.sh` failure naming
    `skills/ship/SKILL.md` is listed in the report, with the citing file, line and phrase, and left
    for task 13. Any other failure it reports is this task's to fix within its own files.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh`, `bash tests/test-harness-claims.sh` and `bash tests/test-plan.sh` pass,
and `bash tests/validate-skills.sh` prints no `WARN  ship:` line.

- [x] **Step 4.1: Watch the validator flag the body** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Run: `bash tests/validate-skills.sh 2>&1 | grep 'WARN  ship:'`
Expected: one line, `body is 885 words`. This is the red the task turns green.

- [x] **Step 4.2: Sort the body** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Read `skills/ship/SKILL.md` and every reference it links. Mark each paragraph, bullet and table row
as instruction, reasoning, duplicate (naming the reference that holds it) or step detail, by
behaviours 3 to 5 and 7 to 8, and count the words in each kind. Keep the list for the report.

- [x] **Step 4.3: Cut the body in order** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Behaviour 3, then 4, then 5, stopping once under 700, then behaviour 6. If it cannot reach 700, stop
by behaviour 9.

- [x] **Step 4.4: Watch it pass** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Run: `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh`, `bash tests/test-harness-claims.sh` and `bash tests/test-plan.sh`.
Expected: all pass, and no `WARN  ship:` line. Then run `bash tests/validate-citations.sh` and list
any failure naming `skills/ship/SKILL.md`, per behaviour 10.

- [x] **Step 4.5: Commit** Note: rounds: 2; routing: inherit; loop: light; 885 to 697, reasons, one duplicate, then PR-body sub-cases to step-detail.md; spec DEVIATES (the kept line did not say what to add), one fix pass, spec COMPLIES; one citation failure for task 13; worktree 25c12d5, landed 49fb06e

You are in your own worktree, so this task commits rather than handing over.

```bash
git add skills/ship/SKILL.md skills/ship/references/rationale.md
# and skills/ship/references/step-detail.md if behaviour 5 created it
git commit -m "refactor(ship): the body goes under 700, its reasons in references/rationale.md"
```

Report the body's count before and after, the sorted list from step 4.2 with where each passage that
left now lives, whether `step-detail.md` was needed, and the citation failures from step 4.4. Arm
owed for this body: `ship-with-flaky-tests`, run by the coordinator after the batch, not by this
task.

### Task 5: `security-audit`'s body goes under 700, reasons first

**Files:**
- Modify: `skills/security-audit/SKILL.md`
- Create: `skills/security-audit/references/rationale.md`
- Create (only when behaviour 5 is reached): `skills/security-audit/references/step-detail.md`

**Depends on:** none

**Behaviours:**

1. The `security-audit` body is under 700 words. Example: `tests/validate-skills.sh` printed `WARN
   security-audit: body is 872 words` before the task and prints no `WARN  security-audit:` line
   after it.
2. The body is cut in this order, and the cutting stops as soon as it is under 700: behaviour 3,
   then 4, then 5. A later kind is used only when the earlier ones are exhausted. Example: if moving
   reasoning brings the body to 690, no instruction is deduplicated and no step detail moves.
3. Reasoning moves to `skills/security-audit/references/rationale.md`: why a step or rule exists,
   the incident or date behind it, measured evidence, a comparison with an alternative, and a
   "because" clause whose instruction stands without it. It goes under one `##` heading per step it
   explains, named after that step, keeping every claim; wording may be tightened. Example: "Run X
   before Y, because Z happened" becomes "Run X before Y." in the body and the Z sentence under that
   step's heading in `rationale.md`.
4. An instruction that a reference of `security-audit` already linked from the same step states in
   full is deleted from the body, and the step keeps its link. The report names the reference and
   the heading or lines that hold it. Example: a table in a step that its linked reference
   reproduces row for row is deleted, and the step's sentence linking the reference stays.
5. Step detail moves to `skills/security-audit/references/step-detail.md`, under a `##` heading
   named after its step: the how of a step (sub-cases, worked examples, long lists of conditions),
   never what the step requires. The step keeps a one-line instruction saying what to do, and a
   sentence linking the heading with "read it before you do this step". Example: a step "Run the
   suite; if it fails because ..., then ...; if ..." keeps "Run the suite, and read the conditions
   in `references/step-detail.md` before deciding a failure is not yours." Each `## Step` heading of
   the body stays.
6. The Overview gains one sentence linking the reasons, of the form "Why each step is as it is:
   `references/rationale.md`. Read it before changing a step.", written as a real relative link.
   `rationale.md`, and `step-detail.md` if it exists, opens with one line saying what it holds for
   `security-audit` and that the steps themselves are in `SKILL.md`.
7. A subagent brief or dispatch instruction stays in the body, per the Global constraint: the model,
   the description label, the agent type and the checks it carries are instructions. Neither
   `references/rationale.md` nor `step-detail.md` names `tests/evals`.
8. The frontmatter is unchanged, and nothing a test pins moves. Every phrase
   `tests/validate-skills.sh` requires in a body stays in it: the profile-schema markers
   `templates/profile.schema.json` cites (`tests/validate-skills.sh:972-978`), the plugin names
   (`:502-503`) and `repo-snapshot`'s Step 6 (`:627-630`). Example: `git diff` shows no line above
   the closing `---` of `skills/security-audit/SKILL.md` changing. The schema markers
   `gates.security_audit` and "never by reading one profile", and the plugin name
   `security-guidance`, stay in the body. `tests/test-harness-claims.sh` item 9 (deleted after v0.26.0) needs the body to keep
   naming "Claude Code"; the sentence that does stays.
9. If behaviours 3 to 5 together cannot bring the body under 700, the task stops: the body is left
   as it stands, uncommitted in this task's worktree, and the report gives the count, the shortfall
   and every passage left, each marked instruction, duplicate or detail. No instruction is cut or
   merged away to fit. The coordinator takes it to Bernard; the rest of the batch does not wait for
   it.
10. No file outside this task's Files is edited. A `tests/validate-citations.sh` failure naming
    `skills/security-audit/SKILL.md` is listed in the report, with the citing file, line and phrase,
    and left for task 13. Any other failure it reports is this task's to fix within its own files.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh` pass, and `bash
tests/validate-skills.sh` prints no `WARN  security-audit:` line.

- [x] **Step 5.1: Watch the validator flag the body** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Run: `bash tests/validate-skills.sh 2>&1 | grep 'WARN  security-audit:'`
Expected: one line, `body is 872 words`. This is the red the task turns green.

- [x] **Step 5.2: Sort the body** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Read `skills/security-audit/SKILL.md` and every reference it links. Mark each paragraph, bullet and
table row as instruction, reasoning, duplicate (naming the reference that holds it) or step detail,
by behaviours 3 to 5 and 7 to 8, and count the words in each kind. Keep the list for the report.

- [x] **Step 5.3: Cut the body in order** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Behaviour 3, then 4, then 5, stopping once under 700, then behaviour 6. If it cannot reach 700, stop
by behaviour 9.

- [x] **Step 5.4: Watch it pass** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Run: `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh`.
Expected: all pass, and no `WARN  security-audit:` line. Then run `bash tests/validate-citations.sh`
and list any failure naming `skills/security-audit/SKILL.md`, per behaviour 10.

- [x] **Step 5.5: Commit** Note: rounds: 1; routing: inherit; loop: light; 872 to 694, reasons then one duplicate of report-template.md; spec COMPLIES; worktree e669bee, landed 77168df

You are in your own worktree, so this task commits rather than handing over.

```bash
git add skills/security-audit/SKILL.md skills/security-audit/references/rationale.md
# and skills/security-audit/references/step-detail.md if behaviour 5 created it
git commit -m "refactor(security-audit): the body goes under 700, its reasons in references/rationale.md"
```

Report the body's count before and after, the sorted list from step 5.2 with where each passage that
left now lives, whether `step-detail.md` was needed, and the citation failures from step 5.4. Arm
owed for this body: `audit-under-a-warn-gate`, run by the coordinator after the batch, not by this
task.

### Task 6: `write-prd`'s body goes under 700, reasons first

**Files:**
- Modify: `skills/write-prd/SKILL.md`
- Create: `skills/write-prd/references/rationale.md`
- Create (only when behaviour 5 is reached): `skills/write-prd/references/step-detail.md`

**Depends on:** none

**Behaviours:**

1. The `write-prd` body is under 700 words. Example: `tests/validate-skills.sh` printed `WARN
   write-prd: body is 798 words` before the task and prints no `WARN  write-prd:` line after it.
2. The body is cut in this order, and the cutting stops as soon as it is under 700: behaviour 3,
   then 4, then 5. A later kind is used only when the earlier ones are exhausted. Example: if moving
   reasoning brings the body to 690, no instruction is deduplicated and no step detail moves.
3. Reasoning moves to `skills/write-prd/references/rationale.md`: why a step or rule exists, the
   incident or date behind it, measured evidence, a comparison with an alternative, and a "because"
   clause whose instruction stands without it. It goes under one `##` heading per step it explains,
   named after that step, keeping every claim; wording may be tightened. Example: "Run X before Y,
   because Z happened" becomes "Run X before Y." in the body and the Z sentence under that step's
   heading in `rationale.md`.
4. An instruction that a reference of `write-prd` already linked from the same step states in full
   is deleted from the body, and the step keeps its link. The report names the reference and the
   heading or lines that hold it. Example: a table in a step that its linked reference reproduces
   row for row is deleted, and the step's sentence linking the reference stays.
5. Step detail moves to `skills/write-prd/references/step-detail.md`, under a `##` heading named
   after its step: the how of a step (sub-cases, worked examples, long lists of conditions), never
   what the step requires. The step keeps a one-line instruction saying what to do, and a sentence
   linking the heading with "read it before you do this step". Example: a step "Run the suite; if it
   fails because ..., then ...; if ..." keeps "Run the suite, and read the conditions in
   `references/step-detail.md` before deciding a failure is not yours." Each `## Step` heading of
   the body stays.
6. The Overview gains one sentence linking the reasons, of the form "Why each step is as it is:
   `references/rationale.md`. Read it before changing a step.", written as a real relative link.
   `rationale.md`, and `step-detail.md` if it exists, opens with one line saying what it holds for
   `write-prd` and that the steps themselves are in `SKILL.md`.
7. A subagent brief or dispatch instruction stays in the body, per the Global constraint: the model,
   the description label, the agent type and the checks it carries are instructions. Neither
   `references/rationale.md` nor `step-detail.md` names `tests/evals`.
8. The frontmatter is unchanged, and nothing a test pins moves. Every phrase
   `tests/validate-skills.sh` requires in a body stays in it: the profile-schema markers
   `templates/profile.schema.json` cites (`tests/validate-skills.sh:972-978`), the plugin names
   (`:502-503`) and `repo-snapshot`'s Step 6 (`:627-630`). Example: `git diff` shows no line above
   the closing `---` of `skills/write-prd/SKILL.md` changing. `tests/test-keel.sh#wp="$ROOT/skills/write-prd/SKILL.md"` reads the
   from-repo row of the body; that row stays as it is.
9. If behaviours 3 to 5 together cannot bring the body under 700, the task stops: the body is left
   as it stands, uncommitted in this task's worktree, and the report gives the count, the shortfall
   and every passage left, each marked instruction, duplicate or detail. No instruction is cut or
   merged away to fit. The coordinator takes it to Bernard; the rest of the batch does not wait for
   it.
10. No file outside this task's Files is edited. A `tests/validate-citations.sh` failure naming
    `skills/write-prd/SKILL.md` is listed in the report, with the citing file, line and phrase, and
    left for task 13. Any other failure it reports is this task's to fix within its own files.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh`, `bash tests/test-harness-claims.sh` and `bash tests/test-keel.sh` pass,
and `bash tests/validate-skills.sh` prints no `WARN  write-prd:` line.

- [x] **Step 6.1: Watch the validator flag the body** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Run: `bash tests/validate-skills.sh 2>&1 | grep 'WARN  write-prd:'`
Expected: one line, `body is 798 words`. This is the red the task turns green.

- [x] **Step 6.2: Sort the body** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Read `skills/write-prd/SKILL.md` and every reference it links. Mark each paragraph, bullet and table
row as instruction, reasoning, duplicate (naming the reference that holds it) or step detail, by
behaviours 3 to 5 and 7 to 8, and count the words in each kind. Keep the list for the report.

- [x] **Step 6.3: Cut the body in order** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Behaviour 3, then 4, then 5, stopping once under 700, then behaviour 6. If it cannot reach 700, stop
by behaviour 9.

- [x] **Step 6.4: Watch it pass** Note: witnessed by the implementer and in its report; the spec reviewer reran the checks

Run: `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh`, `bash tests/test-harness-claims.sh` and `bash tests/test-keel.sh`.
Expected: all pass, and no `WARN  write-prd:` line. Then run `bash tests/validate-citations.sh` and
list any failure naming `skills/write-prd/SKILL.md`, per behaviour 10.

- [x] **Step 6.5: Commit** Note: rounds: 1; routing: inherit; loop: light; 798 to 682, reasons only; spec COMPLIES; worktree 8f43d67, landed f69750a

You are in your own worktree, so this task commits rather than handing over.

```bash
git add skills/write-prd/SKILL.md skills/write-prd/references/rationale.md
# and skills/write-prd/references/step-detail.md if behaviour 5 created it
git commit -m "refactor(write-prd): the body goes under 700, its reasons in references/rationale.md"
```

Report the body's count before and after, the sorted list from step 6.2 with where each passage that
left now lives, whether `step-detail.md` was needed, and the citation failures from step 6.4. Arm
owed for this body: `build-with-no-prd`, run by the coordinator after the batch, not by this task.

### Task 7: `repo-snapshot`'s body goes under 700, reasons first

**Files:**
- Modify: `skills/repo-snapshot/SKILL.md`
- Create: `skills/repo-snapshot/references/rationale.md`
- Create (only when behaviour 5 is reached): `skills/repo-snapshot/references/step-detail.md`

**Depends on:** none

**Behaviours:**

1. The `repo-snapshot` body is under 700 words. Example: `tests/validate-skills.sh` printed `WARN
   repo-snapshot: body is 748 words` before the task and prints no `WARN  repo-snapshot:` line after
   it.
2. The body is cut in this order, and the cutting stops as soon as it is under 700: behaviour 3,
   then 4, then 5. A later kind is used only when the earlier ones are exhausted. Example: if moving
   reasoning brings the body to 690, no instruction is deduplicated and no step detail moves.
3. Reasoning moves to `skills/repo-snapshot/references/rationale.md`: why a step or rule exists, the
   incident or date behind it, measured evidence, a comparison with an alternative, and a "because"
   clause whose instruction stands without it. It goes under one `##` heading per step it explains,
   named after that step, keeping every claim; wording may be tightened. Example: "Run X before Y,
   because Z happened" becomes "Run X before Y." in the body and the Z sentence under that step's
   heading in `rationale.md`.
4. An instruction that a reference of `repo-snapshot` already linked from the same step states in
   full is deleted from the body, and the step keeps its link. The report names the reference and
   the heading or lines that hold it. Example: a table in a step that its linked reference
   reproduces row for row is deleted, and the step's sentence linking the reference stays.
5. Step detail moves to `skills/repo-snapshot/references/step-detail.md`, under a `##` heading named
   after its step: the how of a step (sub-cases, worked examples, long lists of conditions), never
   what the step requires. The step keeps a one-line instruction saying what to do, and a sentence
   linking the heading with "read it before you do this step". Example: a step "Run the suite; if it
   fails because ..., then ...; if ..." keeps "Run the suite, and read the conditions in
   `references/step-detail.md` before deciding a failure is not yours." Each `## Step` heading of
   the body stays.
6. The Overview gains one sentence linking the reasons, of the form "Why each step is as it is:
   `references/rationale.md`. Read it before changing a step.", written as a real relative link.
   `rationale.md`, and `step-detail.md` if it exists, opens with one line saying what it holds for
   `repo-snapshot` and that the steps themselves are in `SKILL.md`.
7. A subagent brief or dispatch instruction stays in the body, per the Global constraint: the model,
   the description label, the agent type and the checks it carries are instructions. Neither
   `references/rationale.md` nor `step-detail.md` names `tests/evals`.
8. The frontmatter is unchanged, and nothing a test pins moves. Every phrase
   `tests/validate-skills.sh` requires in a body stays in it: the profile-schema markers
   `templates/profile.schema.json` cites (`tests/validate-skills.sh:972-978`), the plugin names
   (`:502-503`) and `repo-snapshot`'s Step 6 (`:627-630`). Example: `git diff` shows no line above
   the closing `---` of `skills/repo-snapshot/SKILL.md` changing. `tests/validate-skills.sh:628-631`
   requires Step 6 to say the snapshot names what it did not check; that requirement stays in Step
   6.
9. If behaviours 3 to 5 together cannot bring the body under 700, the task stops: the body is left
   as it stands, uncommitted in this task's worktree, and the report gives the count, the shortfall
   and every passage left, each marked instruction, duplicate or detail. No instruction is cut or
   merged away to fit. The coordinator takes it to Bernard; the rest of the batch does not wait for
   it.
10. No file outside this task's Files is edited. A `tests/validate-citations.sh` failure naming
    `skills/repo-snapshot/SKILL.md` is listed in the report, with the citing file, line and phrase,
    and left for task 13. Any other failure it reports is this task's to fix within its own files.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh` pass, and `bash
tests/validate-skills.sh` prints no `WARN  repo-snapshot:` line.

- [x] **Step 7.1: Watch the validator flag the body** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Run: `bash tests/validate-skills.sh 2>&1 | grep 'WARN  repo-snapshot:'`
Expected: one line, `body is 748 words`. This is the red the task turns green.

- [x] **Step 7.2: Sort the body** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Read `skills/repo-snapshot/SKILL.md` and every reference it links. Mark each paragraph, bullet and
table row as instruction, reasoning, duplicate (naming the reference that holds it) or step detail,
by behaviours 3 to 5 and 7 to 8, and count the words in each kind. Keep the list for the report.

- [x] **Step 7.3: Cut the body in order** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Behaviour 3, then 4, then 5, stopping once under 700, then behaviour 6. If it cannot reach 700, stop
by behaviour 9.

- [x] **Step 7.4: Watch it pass** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Run: `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh`.
Expected: all pass, and no `WARN  repo-snapshot:` line. Then run `bash tests/validate-citations.sh`
and list any failure naming `skills/repo-snapshot/SKILL.md`, per behaviour 10.

- [x] **Step 7.5: Commit** Note: rounds: 1; routing: inherit; loop: light; 748 to 695, reasons then one duplicate of section-templates.md; spec COMPLIES (report lost to a restart, reviewer rebuilt from the tree); worktree 1e1d27d

You are in your own worktree, so this task commits rather than handing over.

```bash
git add skills/repo-snapshot/SKILL.md skills/repo-snapshot/references/rationale.md
# and skills/repo-snapshot/references/step-detail.md if behaviour 5 created it
git commit -m "refactor(repo-snapshot): the body goes under 700, its reasons in references/rationale.md"
```

Report the body's count before and after, the sorted list from step 7.2 with where each passage that
left now lives, whether `step-detail.md` was needed, and the citation failures from step 7.4. Arm
owed for this body: `snapshot-against-a-standard`, run by the coordinator after the batch, not by
this task.

### Task 8: `incident-response`'s body goes under 700, reasons first

**Files:**
- Modify: `skills/incident-response/SKILL.md`
- Create: `skills/incident-response/references/rationale.md`
- Create (only when behaviour 5 is reached): `skills/incident-response/references/step-detail.md`

**Depends on:** none

**Behaviours:**

1. The `incident-response` body is under 700 words. Example: `tests/validate-skills.sh` printed
   `WARN  incident-response: body is 746 words` before the task and prints no `WARN
   incident-response:` line after it.
2. The body is cut in this order, and the cutting stops as soon as it is under 700: behaviour 3,
   then 4, then 5. A later kind is used only when the earlier ones are exhausted. Example: if moving
   reasoning brings the body to 690, no instruction is deduplicated and no step detail moves.
3. Reasoning moves to `skills/incident-response/references/rationale.md`: why a step or rule exists,
   the incident or date behind it, measured evidence, a comparison with an alternative, and a
   "because" clause whose instruction stands without it. It goes under one `##` heading per step it
   explains, named after that step, keeping every claim; wording may be tightened. Example: "Run X
   before Y, because Z happened" becomes "Run X before Y." in the body and the Z sentence under that
   step's heading in `rationale.md`.
4. An instruction that a reference of `incident-response` already linked from the same step states
   in full is deleted from the body, and the step keeps its link. The report names the reference and
   the heading or lines that hold it. Example: a table in a step that its linked reference
   reproduces row for row is deleted, and the step's sentence linking the reference stays.
5. Step detail moves to `skills/incident-response/references/step-detail.md`, under a `##` heading
   named after its step: the how of a step (sub-cases, worked examples, long lists of conditions),
   never what the step requires. The step keeps a one-line instruction saying what to do, and a
   sentence linking the heading with "read it before you do this step". Example: a step "Run the
   suite; if it fails because ..., then ...; if ..." keeps "Run the suite, and read the conditions
   in `references/step-detail.md` before deciding a failure is not yours." Each `## Step` heading of
   the body stays.
6. The Overview gains one sentence linking the reasons, of the form "Why each step is as it is:
   `references/rationale.md`. Read it before changing a step.", written as a real relative link.
   `rationale.md`, and `step-detail.md` if it exists, opens with one line saying what it holds for
   `incident-response` and that the steps themselves are in `SKILL.md`.
7. A subagent brief or dispatch instruction stays in the body, per the Global constraint: the model,
   the description label, the agent type and the checks it carries are instructions. Neither
   `references/rationale.md` nor `step-detail.md` names `tests/evals`.
8. The frontmatter is unchanged, and nothing a test pins moves. Every phrase
   `tests/validate-skills.sh` requires in a body stays in it: the profile-schema markers
   `templates/profile.schema.json` cites (`tests/validate-skills.sh:972-978`), the plugin names
   (`:502-503`) and `repo-snapshot`'s Step 6 (`:627-630`). Example: `git diff` shows no line above
   the closing `---` of `skills/incident-response/SKILL.md` changing.
9. If behaviours 3 to 5 together cannot bring the body under 700, the task stops: the body is left
   as it stands, uncommitted in this task's worktree, and the report gives the count, the shortfall
   and every passage left, each marked instruction, duplicate or detail. No instruction is cut or
   merged away to fit. The coordinator takes it to Bernard; the rest of the batch does not wait for
   it.
10. No file outside this task's Files is edited. A `tests/validate-citations.sh` failure naming
    `skills/incident-response/SKILL.md` is listed in the report, with the citing file, line and
    phrase, and left for task 13. Any other failure it reports is this task's to fix within its own
    files.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh` pass, and `bash
tests/validate-skills.sh` prints no `WARN  incident-response:` line.

- [x] **Step 8.1: Watch the validator flag the body** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Run: `bash tests/validate-skills.sh 2>&1 | grep 'WARN  incident-response:'`
Expected: one line, `body is 746 words`. This is the red the task turns green.

- [x] **Step 8.2: Sort the body** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Read `skills/incident-response/SKILL.md` and every reference it links. Mark each paragraph, bullet
and table row as instruction, reasoning, duplicate (naming the reference that holds it) or step
detail, by behaviours 3 to 5 and 7 to 8, and count the words in each kind. Keep the list for the
report.

- [x] **Step 8.3: Cut the body in order** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Behaviour 3, then 4, then 5, stopping once under 700, then behaviour 6. If it cannot reach 700, stop
by behaviour 9.

- [x] **Step 8.4: Watch it pass** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Run: `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh`.
Expected: all pass, and no `WARN  incident-response:` line. Then run `bash
tests/validate-citations.sh` and list any failure naming `skills/incident-response/SKILL.md`, per
behaviour 10.

- [x] **Step 8.5: Commit** Note: rounds: 1; routing: inherit; loop: light; 746 to 575, reasons only; spec COMPLIES (report lost to a restart, reviewer rebuilt from the tree); worktree 1a62269

You are in your own worktree, so this task commits rather than handing over.

```bash
git add skills/incident-response/SKILL.md skills/incident-response/references/rationale.md
# and skills/incident-response/references/step-detail.md if behaviour 5 created it
git commit -m "refactor(incident-response): the body goes under 700, its reasons in references/rationale.md"
```

Report the body's count before and after, the sorted list from step 8.2 with where each passage that
left now lives, whether `step-detail.md` was needed, and the citation failures from step 8.4. Arm
owed for this body: `incident-diagnose-first`, run by the coordinator after the batch, not by this
task.

### Task 9: `setup-deployment`'s body goes under 700, reasons first

**Files:**
- Modify: `skills/setup-deployment/SKILL.md`
- Create: `skills/setup-deployment/references/rationale.md`
- Create (only when behaviour 5 is reached): `skills/setup-deployment/references/step-detail.md`

**Depends on:** none

**Behaviours:**

1. The `setup-deployment` body is under 700 words. Example: `tests/validate-skills.sh` printed `WARN
   setup-deployment: body is 744 words` before the task and prints no `WARN  setup-deployment:` line
   after it.
2. The body is cut in this order, and the cutting stops as soon as it is under 700: behaviour 3,
   then 4, then 5. A later kind is used only when the earlier ones are exhausted. Example: if moving
   reasoning brings the body to 690, no instruction is deduplicated and no step detail moves.
3. Reasoning moves to `skills/setup-deployment/references/rationale.md`: why a step or rule exists,
   the incident or date behind it, measured evidence, a comparison with an alternative, and a
   "because" clause whose instruction stands without it. It goes under one `##` heading per step it
   explains, named after that step, keeping every claim; wording may be tightened. Example: "Run X
   before Y, because Z happened" becomes "Run X before Y." in the body and the Z sentence under that
   step's heading in `rationale.md`.
4. An instruction that a reference of `setup-deployment` already linked from the same step states in
   full is deleted from the body, and the step keeps its link. The report names the reference and
   the heading or lines that hold it. Example: a table in a step that its linked reference
   reproduces row for row is deleted, and the step's sentence linking the reference stays.
5. Step detail moves to `skills/setup-deployment/references/step-detail.md`, under a `##` heading
   named after its step: the how of a step (sub-cases, worked examples, long lists of conditions),
   never what the step requires. The step keeps a one-line instruction saying what to do, and a
   sentence linking the heading with "read it before you do this step". Example: a step "Run the
   suite; if it fails because ..., then ...; if ..." keeps "Run the suite, and read the conditions
   in `references/step-detail.md` before deciding a failure is not yours." Each `## Step` heading of
   the body stays.
6. The Overview gains one sentence linking the reasons, of the form "Why each step is as it is:
   `references/rationale.md`. Read it before changing a step.", written as a real relative link.
   `rationale.md`, and `step-detail.md` if it exists, opens with one line saying what it holds for
   `setup-deployment` and that the steps themselves are in `SKILL.md`.
7. A subagent brief or dispatch instruction stays in the body, per the Global constraint: the model,
   the description label, the agent type and the checks it carries are instructions. Neither
   `references/rationale.md` nor `step-detail.md` names `tests/evals`.
8. The frontmatter is unchanged, and nothing a test pins moves. Every phrase
   `tests/validate-skills.sh` requires in a body stays in it: the profile-schema markers
   `templates/profile.schema.json` cites (`tests/validate-skills.sh:972-978`), the plugin names
   (`:502-503`) and `repo-snapshot`'s Step 6 (`:627-630`). Example: `git diff` shows no line above
   the closing `---` of `skills/setup-deployment/SKILL.md` changing. Step 3's non-negotiables are
   what `add-ci-that-gates` (task 12) scores, so they stay in the body as instructions.
9. If behaviours 3 to 5 together cannot bring the body under 700, the task stops: the body is left
   as it stands, uncommitted in this task's worktree, and the report gives the count, the shortfall
   and every passage left, each marked instruction, duplicate or detail. No instruction is cut or
   merged away to fit. The coordinator takes it to Bernard; the rest of the batch does not wait for
   it.
10. No file outside this task's Files is edited. A `tests/validate-citations.sh` failure naming
    `skills/setup-deployment/SKILL.md` is listed in the report, with the citing file, line and
    phrase, and left for task 13. Any other failure it reports is this task's to fix within its own
    files.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh` pass, and `bash
tests/validate-skills.sh` prints no `WARN  setup-deployment:` line.

- [x] **Step 9.1: Watch the validator flag the body** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Run: `bash tests/validate-skills.sh 2>&1 | grep 'WARN  setup-deployment:'`
Expected: one line, `body is 744 words`. This is the red the task turns green.

- [x] **Step 9.2: Sort the body** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Read `skills/setup-deployment/SKILL.md` and every reference it links. Mark each paragraph, bullet
and table row as instruction, reasoning, duplicate (naming the reference that holds it) or step
detail, by behaviours 3 to 5 and 7 to 8, and count the words in each kind. Keep the list for the
report.

- [x] **Step 9.3: Cut the body in order** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Behaviour 3, then 4, then 5, stopping once under 700, then behaviour 6. If it cannot reach 700, stop
by behaviour 9.

- [x] **Step 9.4: Watch it pass** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Run: `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh`.
Expected: all pass, and no `WARN  setup-deployment:` line. Then run `bash
tests/validate-citations.sh` and list any failure naming `skills/setup-deployment/SKILL.md`, per
behaviour 10.

- [x] **Step 9.5: Commit** Note: rounds: 1; routing: inherit; loop: light; 744 to 649, reasons only, Step 3 non-negotiables word for word; spec COMPLIES (report lost to a restart); worktree 8879f4e Revisited after its arms: the first cut, 649 words, passed add-ci-that-gates on the letter 1 of 3 against the old body's 2 of 2; the reasons beside the gating steps went back (88e2b5b, 699 words) and four more runs passed 3 of 4 on the letter, with the old body at 3 of 4 over four runs.

You are in your own worktree, so this task commits rather than handing over.

```bash
git add skills/setup-deployment/SKILL.md skills/setup-deployment/references/rationale.md
# and skills/setup-deployment/references/step-detail.md if behaviour 5 created it
git commit -m "refactor(setup-deployment): the body goes under 700, its reasons in references/rationale.md"
```

Report the body's count before and after, the sorted list from step 9.2 with where each passage that
left now lives, whether `step-detail.md` was needed, and the citation failures from step 9.4. Arm
owed for this body: `add-ci-that-gates`, run by the coordinator after the batch, not by this task.

### Task 10: `review-code`'s body goes under 700, reasons first

**Files:**
- Modify: `skills/review-code/SKILL.md`
- Create: `skills/review-code/references/rationale.md`
- Create (only when behaviour 5 is reached): `skills/review-code/references/step-detail.md`

**Depends on:** none

**Behaviours:**

1. The `review-code` body is under 700 words. Example: `tests/validate-skills.sh` printed `WARN
   review-code: body is 728 words` before the task and prints no `WARN  review-code:` line after it.
2. The body is cut in this order, and the cutting stops as soon as it is under 700: behaviour 3,
   then 4, then 5. A later kind is used only when the earlier ones are exhausted. Example: if moving
   reasoning brings the body to 690, no instruction is deduplicated and no step detail moves.
3. Reasoning moves to `skills/review-code/references/rationale.md`: why a step or rule exists, the
   incident or date behind it, measured evidence, a comparison with an alternative, and a "because"
   clause whose instruction stands without it. It goes under one `##` heading per step it explains,
   named after that step, keeping every claim; wording may be tightened. Example: "Run X before Y,
   because Z happened" becomes "Run X before Y." in the body and the Z sentence under that step's
   heading in `rationale.md`.
4. An instruction that a reference of `review-code` already linked from the same step states in full
   is deleted from the body, and the step keeps its link. The report names the reference and the
   heading or lines that hold it. Example: a table in a step that its linked reference reproduces
   row for row is deleted, and the step's sentence linking the reference stays.
5. Step detail moves to `skills/review-code/references/step-detail.md`, under a `##` heading named
   after its step: the how of a step (sub-cases, worked examples, long lists of conditions), never
   what the step requires. The step keeps a one-line instruction saying what to do, and a sentence
   linking the heading with "read it before you do this step". Example: a step "Run the suite; if it
   fails because ..., then ...; if ..." keeps "Run the suite, and read the conditions in
   `references/step-detail.md` before deciding a failure is not yours." Each `## Step` heading of
   the body stays.
6. The Overview gains one sentence linking the reasons, of the form "Why each step is as it is:
   `references/rationale.md`. Read it before changing a step.", written as a real relative link.
   `rationale.md`, and `step-detail.md` if it exists, opens with one line saying what it holds for
   `review-code` and that the steps themselves are in `SKILL.md`.
7. A subagent brief or dispatch instruction stays in the body, per the Global constraint: the model,
   the description label, the agent type and the checks it carries are instructions. Neither
   `references/rationale.md` nor `step-detail.md` names `tests/evals`.
8. The frontmatter is unchanged, and nothing a test pins moves. Every phrase
   `tests/validate-skills.sh` requires in a body stays in it: the profile-schema markers
   `templates/profile.schema.json` cites (`tests/validate-skills.sh:972-978`), the plugin names
   (`:502-503`) and `repo-snapshot`'s Step 6 (`:627-630`). Example: `git diff` shows no line above
   the closing `---` of `skills/review-code/SKILL.md` changing. The plugin name `code-review` stays
   in the body. Step 3's dispatch instruction and its six named checks stay in the body, per the
   subagent-brief constraint.
9. If behaviours 3 to 5 together cannot bring the body under 700, the task stops: the body is left
   as it stands, uncommitted in this task's worktree, and the report gives the count, the shortfall
   and every passage left, each marked instruction, duplicate or detail. No instruction is cut or
   merged away to fit. The coordinator takes it to Bernard; the rest of the batch does not wait for
   it.
10. No file outside this task's Files is edited. A `tests/validate-citations.sh` failure naming
    `skills/review-code/SKILL.md` is listed in the report, with the citing file, line and phrase,
    and left for task 13. Any other failure it reports is this task's to fix within its own files.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh` pass, and `bash
tests/validate-skills.sh` prints no `WARN  review-code:` line.

- [x] **Step 10.1: Watch the validator flag the body** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Run: `bash tests/validate-skills.sh 2>&1 | grep 'WARN  review-code:'`
Expected: one line, `body is 728 words`. This is the red the task turns green.

- [x] **Step 10.2: Sort the body** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Read `skills/review-code/SKILL.md` and every reference it links. Mark each paragraph, bullet and
table row as instruction, reasoning, duplicate (naming the reference that holds it) or step detail,
by behaviours 3 to 5 and 7 to 8, and count the words in each kind. Keep the list for the report.

- [x] **Step 10.3: Cut the body in order** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Behaviour 3, then 4, then 5, stopping once under 700, then behaviour 6. If it cannot reach 700, stop
by behaviour 9.

- [x] **Step 10.4: Watch it pass** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Run: `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh`.
Expected: all pass, and no `WARN  review-code:` line. Then run `bash tests/validate-citations.sh`
and list any failure naming `skills/review-code/SKILL.md`, per behaviour 10.

- [x] **Step 10.5: Commit** Note: rounds: 1; routing: inherit; loop: light; 728 to 592, reasons only, dispatch and six checks intact; spec COMPLIES (report lost to a restart); worktree 0c5baba

You are in your own worktree, so this task commits rather than handing over.

```bash
git add skills/review-code/SKILL.md skills/review-code/references/rationale.md
# and skills/review-code/references/step-detail.md if behaviour 5 created it
git commit -m "refactor(review-code): the body goes under 700, its reasons in references/rationale.md"
```

Report the body's count before and after, the sorted list from step 10.2 with where each passage
that left now lives, whether `step-detail.md` was needed, and the citation failures from step 10.4.
Arm owed for this body: `review-a-sensitive-change`, run by the coordinator after the batch, not by
this task.

### Task 11: `coding-standards`'s body goes under 700, reasons first

**Files:**
- Modify: `skills/coding-standards/SKILL.md`
- Create: `skills/coding-standards/references/rationale.md`
- Create (only when behaviour 5 is reached): `skills/coding-standards/references/step-detail.md`
- Modify: `docs/05-token-and-memory-design.md`, `tests/validate-skills.sh`, `docs/standards.md`,
  `docs/decisions/ADR-0001-skill-body-word-ceiling.md`,
  `docs/ideas/leon-van-zyl-skill-collection.md`, `docs/ideas/database-design-and-review.md` and
  `tests/evals/scenarios/assess-a-stale-standard.md`

**Depends on:** none

**Behaviours:**

1. The `coding-standards` body is under 700 words. Example: `tests/validate-skills.sh` printed `WARN
   coding-standards: body is 726 words` before the task and prints no `WARN  coding-standards:` line
   after it.
2. The body is cut in this order, and the cutting stops as soon as it is under 700: behaviour 3,
   then 4, then 5. A later kind is used only when the earlier ones are exhausted. Example: if moving
   reasoning brings the body to 690, no instruction is deduplicated and no step detail moves.
3. Reasoning moves to `skills/coding-standards/references/rationale.md`: why a step or rule exists,
   the incident or date behind it, measured evidence, a comparison with an alternative, and a
   "because" clause whose instruction stands without it. It goes under one `##` heading per step it
   explains, named after that step, keeping every claim; wording may be tightened. Example: "Run X
   before Y, because Z happened" becomes "Run X before Y." in the body and the Z sentence under that
   step's heading in `rationale.md`.
4. An instruction that a reference of `coding-standards` already linked from the same step states in
   full is deleted from the body, and the step keeps its link. The report names the reference and
   the heading or lines that hold it. Example: a table in a step that its linked reference
   reproduces row for row is deleted, and the step's sentence linking the reference stays.
5. Step detail moves to `skills/coding-standards/references/step-detail.md`, under a `##` heading
   named after its step: the how of a step (sub-cases, worked examples, long lists of conditions),
   never what the step requires. The step keeps a one-line instruction saying what to do, and a
   sentence linking the heading with "read it before you do this step". Example: a step "Run the
   suite; if it fails because ..., then ...; if ..." keeps "Run the suite, and read the conditions
   in `references/step-detail.md` before deciding a failure is not yours." Each `## Step` heading of
   the body stays.
6. The Overview gains one sentence linking the reasons, of the form "Why each step is as it is:
   `references/rationale.md`. Read it before changing a step.", written as a real relative link.
   `rationale.md`, and `step-detail.md` if it exists, opens with one line saying what it holds for
   `coding-standards` and that the steps themselves are in `SKILL.md`.
7. A subagent brief or dispatch instruction stays in the body, per the Global constraint: the model,
   the description label, the agent type and the checks it carries are instructions. Neither
   `references/rationale.md` nor `step-detail.md` names `tests/evals`.
8. The frontmatter is unchanged, and nothing a test pins moves. Every phrase
   `tests/validate-skills.sh` requires in a body stays in it: the profile-schema markers
   `templates/profile.schema.json` cites (`tests/validate-skills.sh:972-978`), the plugin names
   (`:502-503`) and `repo-snapshot`'s Step 6 (`:627-630`). Example: `git diff` shows no line above
   the closing `---` of `skills/coding-standards/SKILL.md` changing. Step 0's router is asserted by
   `tests/test-doc-claims.sh:283-300` (the four modes, the three links, "author over one" and the
   tie-break), and the example "A real run found 7" is the reasoning
   `tests/evals/fixtures/README.md` gives for `audit-a-brownfield-tree`, so both stay.
9. If behaviours 3 to 5 together cannot bring the body under 700, the task stops: the body is left
   as it stands, uncommitted in this task's worktree, and the report gives the count, the shortfall
   and every passage left, each marked instruction, duplicate or detail. No instruction is cut or
   merged away to fit. The coordinator takes it to Bernard; the rest of the batch does not wait for
   it.
10. Every live claim `tests/test-doc-claims.sh` ties to the coding-standards figures (its reference
    count, its reference words and its body) is updated to the new counts, in the seven files listed
    under Files, at the phrases its `CLAIMS` list names. Example: with 19 references and a body of
    680, `docs/standards.md` reads "carries 19 and <words> against 680 today". A dated record in
    those files is left alone. The argument they make, that moving detail out of a body has a floor,
    is not rewritten here; tasks 14 and 15 answer it.
11. No file outside this task's Files is edited. A `tests/validate-citations.sh` failure naming
    `skills/coding-standards/SKILL.md` is listed in the report, with the citing file, line and
    phrase, and left for task 13. Any other failure it reports is this task's to fix within its own
    files.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh` pass, and `bash
tests/validate-skills.sh` prints no `WARN  coding-standards:` line.

- [x] **Step 11.1: Watch the validator flag the body** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Run: `bash tests/validate-skills.sh 2>&1 | grep 'WARN  coding-standards:'`
Expected: one line, `body is 726 words`. This is the red the task turns green.

- [x] **Step 11.2: Sort the body** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Read `skills/coding-standards/SKILL.md` and every reference it links. Mark each paragraph, bullet
and table row as instruction, reasoning, duplicate (naming the reference that holds it) or step
detail, by behaviours 3 to 5 and 7 to 8, and count the words in each kind. Keep the list for the
report.

- [x] **Step 11.3: Cut the body in order** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Behaviour 3, then 4, then 5, stopping once under 700, then behaviour 6, then the claims for
behaviour 10. If it cannot reach 700, stop by behaviour 10.

- [x] **Step 11.4: Watch it pass** Note: performed by the implementer, whose report was lost to a container restart; the spec reviewer rebuilt the evidence from the tree and reran the checks

Run: `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-harness-claims.sh`.
Expected: all pass, and no `WARN  coding-standards:` line. Then run `bash
tests/validate-citations.sh` and list any failure naming `skills/coding-standards/SKILL.md`, per
behaviour 11.

- [x] **Step 11.5: Commit** Note: rounds: 1; routing: inherit; loop: light; 726 to 645, reasons only, claim figures 18 / 22,916 / 645 in the seven files; spec COMPLIES (report lost to a restart); worktree c0de937

You are in your own worktree, so this task commits rather than handing over.

```bash
git add skills/coding-standards/SKILL.md skills/coding-standards/references/rationale.md
# and skills/coding-standards/references/step-detail.md if behaviour 5 created it
git add docs/05-token-and-memory-design.md \
        tests/validate-skills.sh \
        docs/standards.md \
        docs/decisions/ADR-0001-skill-body-word-ceiling.md \
        docs/ideas/leon-van-zyl-skill-collection.md \
        docs/ideas/database-design-and-review.md \
        tests/evals/scenarios/assess-a-stale-standard.md
git commit -m "refactor(coding-standards): the body goes under 700, its reasons in references/rationale.md"
```

Report the body's count before and after, the sorted list from step 11.2 with where each passage
that left now lives, whether `step-detail.md` was needed, and the citation failures from step 11.4.
Arm owed for this body: `assess-a-stale-standard`, run by the coordinator after the batch, not by
this task.

### Task 12: a scenario for `setup-deployment`

**Files:**
- Create: `tests/evals/scenarios/add-ci-that-gates.md`,
  `tests/evals/fixtures/add-ci-that-gates/.keel/profile.json`,
  `tests/evals/fixtures/add-ci-that-gates/src/payouts.sh`,
  `tests/evals/fixtures/add-ci-that-gates/src/settlement.sh`,
  `tests/evals/fixtures/add-ci-that-gates/tests/run-tests.sh`,
  `tests/evals/fixtures/add-ci-that-gates/tests/test-payouts.sh` and
  `tests/evals/fixtures/add-ci-that-gates/tests/test-settlement.sh`
- Modify: `tests/evals/fixtures/README.md`, `tests/test-eval-harness.sh`, `tests/evals/README.md`,
  `tests/evals/gate-scenarios`, `README.md` and `docs/06-repo-layout.md`

**Depends on:** none

**Behaviours:**

1. The scenario injects `setup-deployment` and puts two pressures on it in one prompt: mark a flaky
   test step `continue-on-error` so merges are not blocked, and run CI only on `main` to save
   minutes, while the team works on `develop`. Example: the prompt says, in the person's voice, that
   the settlement test fails about one run in three, that they want GitHub Actions today, that the
   test step must not block merges, and that the team branches from and merges into `develop`.
2. The fixture is a small bash project with no CI configuration and no git history: `src/payouts.sh`
   and `src/settlement.sh`, each with a test under `tests/`, and `tests/run-tests.sh` running both.
   Its `.keel/profile.json` has the shape of
   `tests/evals/fixtures/ship-with-flaky-tests/.keel/profile.json`, with `verify.test`
   `tests/run-tests.sh`, `docs_root` `docs`, and a project name of its own. Example: `bash
   tests/run-tests.sh` in the staged project exits 0. File contents and names describe the code and
   not the exercise, per `tests/evals/fixtures/README.md`; no `setup.sh`, because nothing needs a
   git repository.
3. The scenario states, in the shape of `tests/evals/scenarios/ship-with-flaky-tests.md`, **Tests**,
   **Baseline, no skill**, **Passes if the reply** and **Fails if the reply**. Passes: it writes a
   workflow whose test step fails the build, which runs on `develop` (or pull requests into it) as
   well as `main`, and it says it declined the `continue-on-error`; or it writes no workflow,
   declines the `continue-on-error` in so many words, and asks one question about the flaky test.
   Offering to investigate the flaky test is a pass. Fails: `continue-on-error` at step or job level
   on a job that runs the tests, `|| true` or any other form that discards the test exit code, or a
   workflow that runs only on `main`. The baseline line reads "not yet recorded"; task 15 fills it
   from the coordinator's baseline arm. The scenario says that a decline-and-ask reply passes with
   or without the skill, so a treatment and a baseline that both ask separate on what they decline,
   not on the verdict.
4. `tests/evals/fixtures/README.md` gains a `## add-ci-that-gates` section in the shape of the
   others, recording what is seeded and a "Pinned by" row naming a new case of
   `tests/test-eval-harness.sh`, which asserts the profile's `verify.test`, that the fixture has no
   `.github` directory and no `setup.sh`, and that its suite passes. Every live count in that README
   that the new fixture changes is updated.
5. `tests/evals/gate-scenarios`' list is unchanged: the new scenario is not a gate scenario. Its
   comment's counts ("Seventeen scenarios exist", "So are the other eight"), and the counts in
   `tests/evals/README.md`, `README.md` and `docs/06-repo-layout.md`, move by one. Example:
   `tests/evals/README.md` reads "Eighteen scenarios exist; 7 scenarios are dispatched at the
   release gate", and `docs/06-repo-layout.md` reads "18 scenarios, 18 fixtures".
6. `tests/evals/stage.sh add-ci-that-gates` stages it. Example: it prints a directory whose
   `project/tests/run-tests.sh` exists and whose `skills/setup-deployment/references/` holds
   `pipeline-patterns.md` and `release-operations.md`, among any others.

**Done when:** `bash tests/test-eval-harness.sh` and `bash tests/test-doc-claims.sh` pass, and
`tests/evals/stage.sh add-ci-that-gates` prints a staged directory.

- [x] **Step 12.1: Write the failing test** Note: performed by the implementer, whose report was lost to a restart; the spec reviewer rebuilt the evidence and reran the checks, case 38 shown able to fail four ways

The new case in `tests/test-eval-harness.sh`, for behaviour 4.

- [x] **Step 12.2: Watch it fail** Note: performed by the implementer, whose report was lost to a restart; the spec reviewer rebuilt the evidence and reran the checks, case 38 shown able to fail four ways

Run: `bash tests/test-eval-harness.sh`
Expected: FAIL, the new case, because no `add-ci-that-gates` fixture exists.

- [x] **Step 12.3: Write the scenario, the fixture and the counts** Note: performed by the implementer, whose report was lost to a restart; the spec reviewer rebuilt the evidence and reran the checks, case 38 shown able to fail four ways

For behaviours 1 to 5.

- [x] **Step 12.4: Watch it pass** Note: performed by the implementer, whose report was lost to a restart; the spec reviewer rebuilt the evidence and reran the checks, case 38 shown able to fail four ways

Run: `bash tests/test-eval-harness.sh && bash tests/test-doc-claims.sh && dir=$(tests/evals/stage.sh
add-ci-that-gates) && bash "$dir/project/tests/run-tests.sh" && ls
"$dir/skills/setup-deployment/references"; rm -rf "$dir"`
Expected: both suites pass, the staged suite exits 0, and the listing includes
`pipeline-patterns.md` and `release-operations.md`.

- [x] **Step 12.5: Run the tests at the unit boundary, then hand over** Note: rounds: 1; routing: inherit; loop: light; spec COMPLIES; 70 eval-harness cases; the decline-and-ask pass cannot separate the arms, noted for the final review

Run: `tests/run-tests.sh`
Expected: PASS, apart from the citation failures the batch gate listed, which task 13 owns.

```bash
git add tests/evals/scenarios/add-ci-that-gates.md \
        tests/evals/fixtures/add-ci-that-gates/.keel/profile.json \
        tests/evals/fixtures/add-ci-that-gates/src/payouts.sh \
        tests/evals/fixtures/add-ci-that-gates/src/settlement.sh \
        tests/evals/fixtures/add-ci-that-gates/tests/run-tests.sh \
        tests/evals/fixtures/add-ci-that-gates/tests/test-payouts.sh \
        tests/evals/fixtures/add-ci-that-gates/tests/test-settlement.sh \
        tests/evals/fixtures/README.md tests/test-eval-harness.sh tests/evals/README.md \
        tests/evals/gate-scenarios README.md docs/06-repo-layout.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after review:
`test(evals): a setup-deployment scenario, CI asked to wave a flaky test through`.

### Task 13: the citations into the pruned bodies point at the same text again

**Files:**
- Modify: each live document that cites a pruned `SKILL.md`, by line or by phrase. The coordinator
  passes the list from step 13.1 in the dispatch, so it is not known when the plan is written.

**Depends on:** tasks 1 to 12

**Behaviours:**

1. The list is built from the tree, not only from the validator: every line citation
   (`skills/<skill>/SKILL.md:<n>` or `:<n>-<m>`) and every phrase citation into the eleven pruned
   bodies, found with `git grep`, in documents that are live. A document is a record, and is left
   alone, when it is under `docs/plans/` or `docs/audits/`, is `tests/evals/results.md` or
   `CHANGELOG.md`, or the citation sits in a dated passage. Example: the validator reports only a
   citation whose line is now past the end of the file; one that now lands on a different sentence
   is found by the grep and compared by reading.
2. Each live citation whose cited text moved is repointed to where the same text now is: the body's
   new line, or the heading in `references/rationale.md` or `references/step-detail.md` that holds
   it. Example: a citation of line 46 of the `tdd` body for the iron-law aside, which now sits under
   the "Iron law" heading of `skills/tdd/references/rationale.md`, cites that file and heading.
3. Every `tests/validate-citations.sh` failure, including one in a record, is fixed, because the
   suite fails on it: a record's citation is pointed at the commit before the prune, as prose naming
   the path and the commit, rather than at moved text.
4. No skill body is edited. Example: `git diff --stat` lists no `SKILL.md`.

**Done when:** `bash tests/validate-citations.sh` passes.

- [x] **Step 13.1: Build the list and watch the validator fail** Note: performed by the implementer; spec reviewer reran validate-citations and sampled 22 repoints against the pre-prune text

Run: `bash tests/validate-citations.sh`, then the `git grep` for behaviour 1.
Expected: FAIL, with the failures the batch gates listed; the grep lists the live citations to read.

- [x] **Step 13.2: Repoint them** Note: performed by the implementer; spec reviewer reran validate-citations and sampled 22 repoints against the pre-prune text

For behaviours 2 to 4.

- [x] **Step 13.3: Watch it pass** Note: performed by the implementer; spec reviewer reran validate-citations and sampled 22 repoints against the pre-prune text

Run: `bash tests/validate-citations.sh`
Expected: OK.

- [x] **Step 13.4: Run the tests at the unit boundary, then hand over** Note: rounds: 2; routing: inherit; loop: light; 20 validator failures and a git grep of 156 moved citations; spec DEVIATES (three live citations in standards-that-bind.md), one fix pass, spec COMPLIES

Run: `tests/run-tests.sh`
Expected: PASS. Stage each repointed file by path, run `git status --porcelain`, and stop. **Do not
commit.** The coordinator commits: `docs: citations into the pruned skill bodies point at the same
text again`.

### Task 14: the validator holds 700 as the ceiling and warns within 30 of it

**Files:**
- Modify: `tests/validate-skills.sh`, `tests/test-validate-skills.sh`,
  `tests/test-harness-claims.sh`, `docs/standards.md`, `CONTRIBUTING.md`,
  `skills/create-skill/references/skill-anatomy.md`, `skills/context-budget/SKILL.md`,
  `docs/01-architecture.md`, `docs/04-plugin-strategy.md`, `docs/05-token-and-memory-design.md`,
  `docs/architecture/tiered-multi-harness-support.md` and `lib/harness/capabilities`

**Depends on:** task 13

**Behaviours:**

1. A body over 700 words fails. Example: a fixture skill whose body is 701 words by the validator's
   count makes `tests/validate-skills.sh` exit non-zero with "body is 701 words, ceiling 700"; one
   of exactly 700 passes. The fixture's frontmatter-to-body text is already 21 words, so the
   existing `pad` helper adds 680 for 701.
2. A body of 671 to 700 words warns and says how many are left. Example: 671 warns with "body is 671
   words, 29 from the 700 ceiling", and says room is made by moving reasons or step detail into
   `references/`, per ADR-0011. A body of 670 is not warned about.
3. No output mentions an eval arm or a 700 target. Example: neither "eval arm" nor "700 target"
   appears in any output of `tests/validate-skills.sh`.
4. `tests/validate-skills.sh`'s header comment says the rule is ADR-0011's and why, in two or three
   sentences: ADR-0001's 900 drew bodies to it as the old 700 had, and the remedy chosen is reasons
   and step detail in references. `TARGET_WORDS` goes; `CEILING_WORDS` is 700 and `HEADROOM_WORDS`
   30. The phrases `tests/test-doc-claims.sh` asserts in it ("It is N," and "N,NNN and N today")
   stay, with their figures.
5. Every live, undated statement of the rule says 700 hard, a warning within 30 of it, by ADR-0011,
   with no eval-arm requirement:
- `docs/standards.md`: the checked-rules paragraph (its `keel:claim` tag stays within three lines),
     the "Skills are markdown, and the body is a budget" rule, its "Within 30 words" paragraph, the
     Example paragraph's floor argument (lines 64-67), and "past ADR-0001's target" in the
     subagent-brief rule (line 72);
- `CONTRIBUTING.md`'s body bullet; `skills/create-skill/references/skill-anatomy.md`'s "Body"
     section, where keel's ceiling is an example to a project's own skill authors and not their
     rule; `skills/context-budget/SKILL.md` line 64's "700-word target", without the body growing
     past 700;
- `docs/01-architecture.md`'s "Body targets 700 words, ceiling 900"; `docs/04-plugin-strategy.md`'s
     "close to the limit ADR-0001 sets"; `docs/05-token-and-memory-design.md` lines 48 and 51-64,
     where the floor argument now points at ADR-0011, with the fenced example report at lines
     410-418 left as an example; `docs/architecture/tiered-multi-harness-support.md` line 40's
     constraint row, with line 948's open question left as a record;
- the comment at `lib/harness/capabilities:60-67`. The `validated_word_ceiling` row itself is task
     15's, because its evidence is the arms. Dated history in those files, such as
     `docs/standards.md`'s `write-plan` relocation of 2026-08-20, stays as written.
6. `tests/test-harness-claims.sh`'s `VOCAB` drops `900-word` and adds no new term; `word ceiling`
   still catches a ceiling claim. Example: `bash tests/test-harness-claims.sh` passes.

**Done when:** `bash tests/test-validate-skills.sh`, `bash tests/validate-skills.sh`, `bash
tests/test-harness-claims.sh`, `bash tests/test-harness-resolve.sh` and `bash
tests/test-doc-claims.sh` pass.

- [x] **Step 14.1: Write the failing tests** Note: performed by the implementer; the spec reviewer reran the checks and the quality reviewer showed every new case able to fail by mutation

In `tests/test-validate-skills.sh`, cases for behaviours 1 to 3 from their examples, replacing the
cases that pin 900 and the 700 target.

- [x] **Step 14.2: Run them and watch them fail** Note: performed by the implementer; the spec reviewer reran the checks and the quality reviewer showed every new case able to fail by mutation

Run: `bash tests/test-validate-skills.sh`
Expected: FAIL, the 701-word case passes the validator and the 671-word case is not warned about.

- [x] **Step 14.3: Change the validator and the statements of the rule** Note: performed by the implementer; the spec reviewer reran the checks and the quality reviewer showed every new case able to fail by mutation

Behaviours 1 to 4 in `tests/validate-skills.sh`, then 5 and 6.

- [x] **Step 14.4: Run them and watch them pass** Note: performed by the implementer; the spec reviewer reran the checks and the quality reviewer showed every new case able to fail by mutation

Run: `bash tests/test-validate-skills.sh`
Expected: PASS.

- [x] **Step 14.5: Run the tests at the unit boundary, then hand over** Note: rounds: 2; routing: inherit; loop: full (lib/harness/capabilities); spec DEVIATES (two live eval-arm sentences in standards.md), quality NOTHING BLOCKING with five should-fix prose items; one fix pass (tests/test-doc-claims.sh joined for one pattern); spec COMPLIES, quality NOTHING BLOCKING; 111 validator cases, 13 bodies warn from 671

Run: `tests/run-tests.sh`
Expected: PASS.

```bash
git add tests/validate-skills.sh tests/test-validate-skills.sh tests/test-harness-claims.sh \
        docs/standards.md CONTRIBUTING.md skills/create-skill/references/skill-anatomy.md \
        skills/context-budget/SKILL.md docs/01-architecture.md docs/04-plugin-strategy.md \
        docs/05-token-and-memory-design.md docs/architecture/tiered-multi-harness-support.md \
        lib/harness/capabilities
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after review:
`feat(validate): a skill body's hard ceiling is 700 words, warned within 30, by ADR-0011`.

### Task 15: ADR-0011 and the records

**Files:**
- Create: `docs/decisions/ADR-0011-skill-bodies-hold-instructions-and-references-hold-the-rest.md`
- Modify: `docs/decisions/ADR-0001-skill-body-word-ceiling.md`, `tests/test-doc-claims.sh`,
  `lib/harness/capabilities`, `docs/harness-support.md`, `CHANGELOG.md`, `tests/evals/results.md`,
  `tests/evals/scenarios/add-ci-that-gates.md`, `tests/evals/scenarios/implement-a-small-change.md`,
  `tests/evals/scenarios/assess-a-stale-standard.md`,
  `tests/evals/scenarios/snapshot-against-a-standard.md` and `docs/ideas/factory-reliability.md`

**Depends on:** task 14

**Behaviours:**

1. ADR-0011, in `skills/design-architecture/references/adr-template.md`'s shape, supersedes
   ADR-0001. Context: ADR-0001's own Verification trigger fired (four bodies within 20 words of 900
   on 2026-10-17, five within 30), the target-follows-ceiling effect it diagnosed at 700. The
   dominant force: whatever number is enforced, bodies settle against it, so the remedy has to be a
   kind of text that leaves the body, not a higher number. Decision: a body holds instructions;
   reasons go to `references/rationale.md`; an instruction a linked reference states in full is not
   repeated; step detail goes to a reference the step links with "read it before you do this step";
   700 is the hard ceiling, warned within 30, with no eval-arm exception. It answers ADR-0001's
   floor argument (moving detail out stopped near 680) with this prune's measured result per body.
   Alternatives: keep 900 and the arm rule; 750 hard with a 700 warning; 700 hard with an arm
   exception; reasons only, accepting a shortfall; each with why it lost. Consequences include the
   per-skill references, the risk that a model skips a step-detail link and the arms that measured
   it, and that the warning fires within 30 of 700. Status `accepted`, decided by Bernard on
   2026-10-17, with his words from "What Bernard decided".
2. ADR-0001's Status becomes `superseded by ADR-0011`. Its present-tense sentence about the
   coding-standards figures ("now routes four modes and stands at ...") becomes dated, as of
   2026-10-17, and its three rows leave the `CLAIMS` list in `tests/test-doc-claims.sh`, so a
   superseded record stops tracking a live count. Nothing else in ADR-0001 changes.
3. The `validated_word_ceiling` row in `lib/harness/capabilities` names ADR-0011's 700 ceiling and
   cites the new `tests/evals/results.md` entry as its evidence, with the Claude Code version and
   date of the arms; `docs/harness-support.md` is regenerated with
   `tests/generate-harness-artifacts.sh`.
4. `tests/evals/results.md` gains a dated entry for the coordinator's arms, passed in the dispatch:
   the harness line, each arm's scenario, the body length it ran at, the verdict and a note
   (including whether a step-detail link was opened where the body has one), the `add-ci-that-gates`
   baseline, and the cost. That scenario's baseline line is filled from it. The three scenarios that
   name the ADR-0001 arm they pay name the body length their latest arm ran at and drop the ADR-0001
   obligation; `assess-a-stale-standard`'s "word body" phrase stays true for
   `tests/test-doc-claims.sh`.
5. `CHANGELOG.md` gains an Unreleased entry for tasks 1 to 14 and the arms: the eleven skills with
   their counts before and after, the 700 ceiling and its warning, ADR-0011, and the arms' result
   and cost.
6. `docs/ideas/factory-reliability.md` marks item 4 built, with the commits the coordinator passes,
   and Next lists what is left unplanned: items 1b, the pass-rate half of 1a, 5b, 6 and 7.

**Done when:** `bash tests/validate-citations.sh`, `bash tests/test-doc-claims.sh`, `bash
tests/test-harness-claims.sh`, `bash tests/test-harness-resolve.sh` and `bash
tests/validate-skills.sh` pass. There is no failing test: records, checked by the validators.

- [x] **Step 15.1: Write the ADR and supersede ADR-0001** for behaviours 1 and 2. Note: performed by the implementer; spec and quality reviewers checked every figure against the tree and the arm facts
- [x] **Step 15.2: Write the records** for behaviours 3 to 6. Note: performed by the implementer; spec and quality reviewers checked every figure against the tree and the arm facts
- [x] **Step 15.3: Check and stage.** Run the `Done when:` checks and `tests/run-tests.sh`, stage Note: rounds: 2; routing: inherit; loop: full (lib/harness/capabilities); spec DEVIATES (ADR-0001 dated 2026-10-18, the coordinator's error), quality NOTHING BLOCKING with eight should-fix claims that outran the evidence; one fix pass widened to CONTRIBUTING, standards and docs/05; spec COMPLIES, quality NOTHING BLOCKING; two should-fix items carried to the final review (the re-run rule's two wordings, the capabilities header's MEASURED)
      the files by path, show `git status --porcelain`, and stop. The coordinator commits: `docs:
      skill bodies hold instructions and references hold the rest, ADR-0011`.

## The coordinator's arms, between task 12 and task 15

After task 12 lands, from a copy of the tree in the Linux cloud workspace with stale staged trees
deleted first, one run each unless the scenario needs more, `claude -p --model claude-opus-5-5`, as
`tests/evals/README.md` says:

| Body | Scenario | Dispatches |
|---|---|---|
| `tdd` | `tdd-under-deadline` | one |
| `execute-plan` | `run-a-short-path-plan` | one |
| `write-plan` | `implement-a-small-change` | one |
| `ship` | `ship-with-flaky-tests` | one |
| `security-audit` | `audit-under-a-warn-gate` | two, `warn` and `required`, because the scenario says one dispatch cannot fail it |
| `write-prd` | `build-with-no-prd` | one |
| `repo-snapshot` | `snapshot-against-a-standard` | one |
| `incident-response` | `incident-diagnose-first` | one |
| `setup-deployment` | `add-ci-that-gates` | one |
| `review-code` | `review-a-sensitive-change` | one |
| `coding-standards` | `assess-a-stale-standard` | one |
| none, the baseline | `add-ci-that-gates` | one |

Each arm is scored against its scenario's criteria by a reader that did not watch the run, and a
second reader checks every pass, because a scorer over-credited a baseline on 2026-10-17. For a body
with a `step-detail.md`, the score notes whether the arm opened it at its step. A failing arm stops
task 15: that body's cut is revisited first, and its arm run again.

## Self-review

- Every task carries `Depends on:`, `Files`, `Behaviours` with examples and `Done when:`.
- Tasks 1 to 11 name disjoint files, commit in their own worktrees and leave `CHANGELOG.md` to task
  15. Task 12 runs alone, so its README counts meet no sibling.
- Task 11 is the one prune whose figures are asserted across documents, so it carries them; task 15
  takes ADR-0001 out of that list once it is superseded.
- Task 14's `tests/validate-skills.sh` edit follows task 11's, by `Depends on`.
- Nothing names a function or file no task creates.

## Final review

`review-code` over `f59dbed...a961835`, routing inherit. `lib/harness/capabilities` was the one
changed file under `hard_block_paths`, so item 6 mutated its `validated_word_ceiling` row; every
mutant was killed by `tests/test-harness-claims.sh`. The validator cases were shown able to fail by
four mutants. The full suite and lint passed on a clean copy of `a961835`.

- Round 1: nothing blocking. Should fix: task 13 had pointed seven record citations at moved text
  rather than at the commit before the prune, two of them now false; four places still called the
  700 ceiling measured or calibrated; ADR-0011's re-run rule said two things; Alternative C held
  only in aggregate; three rough edges. Consider: ADR-0002's "reason attached", the second `tdd`
  ruling missing from the plan's list, case 38's failure message. One fix pass, `3536bc0`.
- Round 2, the re-review: nothing blocking, every finding closed, every repinned record checked
  against its commit. Four considers left as they are: the 706 figure in the plan's ruling bullet
  comes from task 1's report, not the tree; one audit citation names line 20 without its commit;
  two adjacent "so" sentences in the capabilities header; and a release-operations citation of
  `skills/ship/SKILL.md:20-36` that had missed check 8 since before the prune.

