# Lean task steps Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** a task in a keel plan carries two steps instead of five. Step N.1 builds the task test
first by following `keel:tdd`, and Step N.2 hands over. The plan stops restating the TDD cycle once
per task, and the implementer's report must still quote the failing run from before the
implementation, so the red is witnessed and checkable. A paired eval on Sonnet decides whether the
change stays.
**Stories:** none. The input is the discussion of 2026-10-21 on whether keel should keep a plan
template of its own now that harnesses have plan modes, and its conclusion that the five fixed
steps are the clearest duplication.
**ADRs:** ADR-0011, ADR-0008, ADR-0006
**Architecture:** no parser changes. `keel plan status`, `tick`, `report` and `ship`'s gate find a
task from its steps' ids (`<task>.<step>`), so a task with two steps is read as it is today. What
changes is text: the plan template's task shape and step granularity, the short path's plan, the
implementer prompt and the spec reviewer's questions, one catalog paragraph. A new ADR records the
decision and the condition on which it is reverted. Two new eval scenarios, identical but for the
shape of the task they paste, give the measurement. Plans already written keep their five steps
and keep working (no migration, as in the addressable-steps PRD).
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Concurrent batches:** none. Tasks run one at a time in plan order, each handing over for the
coordinator to commit. Task 7 is the coordinator's own (a measurement and a decision), so
`execute-plan` runs it inline and dispatches nothing for it.

## What this plan does not do

Two further changes from the same discussion are left out on purpose and wait for the result of
task 6, because they are only worth doing if the two-step shape holds:

- Move the concurrent-batch rules out of `plan-template.md` into a reference read only when a plan
  declares a batch (a move of text, about 2,000 of its 4,200 words).
- Say in `write-plan` that when the harness offers a plan mode, its plan is the draft that
  `write-plan` hardens (adds the missing examples and `Done when:` lines) and commits.

This plan was written in the shape it proposes. It is the first live use of the shape, and the
coordinator notes in the hand-off whether it worked.

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test `tests/{name}`,
  lint `shellcheck -x` on the files the profile names. On a small machine lint the changed files
  only. The full suite takes about 170 seconds; run it in slices of the same test list if a
  detached process is killed.
- Work on `sandbox`, never on `main`.
- `docs/standards.md`: no em or en dashes; prose lines at most 100 columns; no `@` links; relative
  links resolve. A skill's frontmatter is not edited. A skill body stays at or under 700 words
  (ADR-0011); no task here may add words to a body, and `tests/validate-skills.sh` must pass.
- Citations: a living document that cites `path:line` must still resolve after an edit. A dated
  record is pinned as "line N at `<commit>`". `tests/validate-citations.sh` only checks that the
  file exists, the line is in range and the first cited line is not blank, so it will not report a
  shifted line. After editing any file under `skills/`, also run
  `grep -rn '<file name>:[0-9]' docs README.md skills tests` for each edited file, outside
  `docs/plans/` and the dated `docs/audits/` records, and repoint any living citation whose line
  moved, by the rule in `docs/standards.md`. Say so in the report.
- The harness pins counts and text: `tests/test-eval-harness.sh` case 23 holds a scenario's copy of
  the implementer prompt byte for byte against `subagent-prompts.md`, and the scenario count is
  stated in several documents (task 6 lists them). Run `tests/test-eval-harness.sh` and
  `tests/test-doc-claims.sh` after any task that touches a scenario, a prompt or a count.
- Exact text given in a task is used exactly, rewrapped to 100 columns where it replaces wrapped
  prose. If an old text is not found exactly once, stop and report.
- Name paths when staging. Never `git add -A`, `git add .` or `git commit -a`. Do not commit; the
  coordinator does.

---

### Task 1: record the decision, proposed

**Files:**
- Create: `docs/decisions/ADR-0012-a-task-carries-two-steps.md`

**Depends on:** none

**Behaviours:**

1. The ADR has the table header and the sections of ADR-0009: Context, Decision, Alternatives
   considered, Consequences, Verification (`ADR-0000-template.md` is only a pointer to the
   `design-architecture` skill). Example: Status is `proposed`,
   Date is `2026-10-21`, Deciders is `Bernard Tebandeke, proposed 2026-10-21`, Supersedes is
   `none; amends the plan template's five-step task shape`.
2. Context states the duplication in numbers: `skills/write-plan/references/plan-template.md` is
   about 4,200 words; a task carries five steps although `keel:tdd` already prescribes the cycle;
   the addressable-steps PRD records plans of 10,000 to 35,000 words with 30 checkboxes in the
   latest. Example: "a six-task plan carries 30 checkboxes, 18 of them restating the cycle."
3. Decision states, in these words: "A task has two steps. Step N.1 builds the task test first,
   following `keel:tdd`, and ends at the unit-boundary run. Step N.2 hands over: it stages the
   named paths and stops. The implementer's report quotes the failing run that preceded the
   implementation, and the spec reviewer returns DEVIATES for a report without it." It also says
   step ids, the four states and every `keel plan` command are unchanged.
4. Consequences lists what is lost (a tick per cycle stage; `rounds`, `routing` and `loop` stay on
   the last step ticked in a task, so nothing in `keel plan report` changes) and what is gained
   (fewer checkboxes: 12 where a six-task plan had 30, and one place for the cycle). It makes no
   claim that the template gets shorter, because the replacement text offsets what is removed.
5. The Verification section holds the revert condition: the decision is accepted only if the paired
   eval of task 6
   (four runs per arm, Sonnet) shows the two-step arm meeting every criterion the five-step arm
   meets in each run, and quoting the pre-implementation failing run in every run. Otherwise it is
   marked `rejected` and tasks 2 to 5 are reverted. Example: a two-step run whose report shows only
   passing output fails the condition even if its code is right. It adds that four runs per arm is
   thin, so a pass is evidence and not proof, and that `rounds` and rework from `keel plan report`
   on the first real plans written this way are the longer check.
6. Alternatives considered: keep five steps (rejected: the duplication); drop step ids (rejected:
   `plan status`, `tick`, `report` and `ship` read them); one step per task (rejected: the
   hand-over names task-specific paths and a commit message and is ticked only after review).

**Done when:** `tests/validate-skills.sh` passes and `tests/test-doc-claims.sh` passes; the ADR
exists with Status `proposed`.

- [x] **Step 1.1: Write the ADR** Note: implementer reported both checks passing; coordinator read the ADR against behaviours 1-6

There is no failing test for a decision record. Write the ADR from behaviours 1 to 6, then run
`tests/validate-skills.sh` and `tests/test-doc-claims.sh`. Expected: both pass. If either names
the new file, fix it. Quote both outputs in your report.

- [x] **Step 1.2: Hand over** Note: rounds: 1; routing: general agent on sonnet; loop: light; spec pass by coordinator read, no dispatched reviewer

```bash
git add docs/decisions/ADR-0012-a-task-carries-two-steps.md
git status --porcelain
```

Stage exactly that path and stop. **Do not commit.** The coordinator commits after both review
passes with `git commit -m "docs(decisions): ADR-0012 proposes two steps per task"`. Paste the
`git status --porcelain` output into your report; if it lists anything this task did not touch,
say so and leave it unstaged.

---

### Task 2: the plan template's task shape has two steps

**Files:**
- Modify: `skills/write-plan/references/plan-template.md`

**Depends on:** task 1

**Behaviours:**

1. The "Task shape" example task (Task 3, "Reject an empty credential at startup") has two steps.
   Its steps 3.1 to 3.5 become the following, with step 3.1's second paragraph being the existing
   step 3.5 paragraph beginning "Run: `./gradlew test`. Where the profile sets
   `verify.test_affected`" moved in unchanged, and step 3.2 being the existing `git add` block and
   the paragraph beginning "Stage exactly those paths and stop." moved in unchanged:

   ````markdown
   - [ ] **Step 3.1: Build it test first**

   Follow `keel:tdd` for behaviour 1: write its test from the example, run it, and watch it fail
   for the reason the behaviour names, then write the minimal implementation and watch it pass.
   Run: `./gradlew test --tests '*SecurityPropertiesTest'`
   Expected before the implementation: FAIL, the case for behaviour 1 fails because startup
   succeeds. Expected after: PASS. Quote the failing output in your report.

   <the existing step 3.5 paragraph "Run: `./gradlew test`. Where the profile sets ...", then its
   "Expected:" line, unchanged>

   - [ ] **Step 3.2: Hand over**

   <the existing git add block and "Stage exactly those paths and stop." paragraph, unchanged>
   ````

   Example: after the edit, `grep -c 'Step 3\.[0-9]:' plan-template.md` inside the Task shape
   block is 2, and `Step 3.5` appears nowhere in the file.
2. The "Step granularity" section opens: "A task has two steps." It then says: Step N.1 builds the
   task test first by following `keel:tdd` and runs the unit-boundary tests; Step N.2 stages the
   named paths, names the commit the coordinator will make, and stops. The section's paragraph
   beginning "Steps 2 and 4 are not ceremony." is replaced by exactly: "The watch-it-fail is not
   dropped; it moved. `keel:tdd` owns the cycle, the plan's step names the failure to expect, and
   the report must quote the failing run from before the implementation. A test you did not watch
   fail may be asserting nothing, and a report with only passing output shows that nobody did."
3. Self-review item 7 gains: "Each task's steps are `<task>.1`, a build step, and `<task>.2`, the
   hand-over, except a task with no test, whose `<task>.1` is the human check." Example: a plan
   whose task 2 has a step `2.3` fails this item.
4. Rule 2 under "Tasks that run concurrently" shows the batched task's final step as
   `**Step 1.2: Commit**` where it shows `**Step 1.5: Commit**` now, and its prose says "the final
   step" without naming its number.
5. The "Tasks with no test" example stays as it is except that its step id is `Step 4.1` followed
   by a `**Step 4.2: Hand over**` line stating that the task hands over as above.
6. Every other place in the file that names a step by its old position is reworded, by exact
   phrase: "every agent's step 2 sees red for the wrong reason" becomes "every agent's failing-test
   run sees red for the wrong reason" (the "Tasks that run concurrently" paragraph, around line
   312); "unrunnable" in "every step 2 and step 4 unrunnable" is kept and "every step 2 and step 4"
   becomes "every task's failing and passing runs"; "Task 1's own step 2 watches the test command
   fail" becomes "Task 1's own failing run watches the test command fail"; the five-bullet list in
   "Step granularity" ("Write the failing test" to "Run the tests at the unit boundary ...") is
   deleted; and the id example "`**Step 3.2: Run it and watch it fail**` is task 3's second step"
   becomes "`**Step 3.2: Hand over**` is task 3's second step". Example: afterwards
   `grep -n 'step 2\|step 4\|watch it fail' plan-template.md` finds only the replacement paragraph
   of behaviour 2.
7. Nothing else changes: the header, the Interfaces, Behaviours, Depends on and Done when sections
   and the batch rules keep their text. The word count is reported in the hand-over and has no
   target.

**Done when:** `tests/validate-skills.sh` passes (it checks the template still has a step carrying
an id and no step in the old form).

- [x] **Step 2.1: Edit the template** Note: implementer ran validate-skills and citations; coordinator read the diff

Make the seven changes from the behaviours. There is no test to write first; the check is the
validator. Run `grep -nE 'Step (3\.[3-9]|1\.5)' skills/write-plan/references/plan-template.md` and
confirm it finds nothing, and the `grep` in behaviour 6. Run `tests/validate-skills.sh` and
`tests/validate-citations.sh`. Expected: pass,
or a citation shift you repoint. Quote the outputs.

- [x] **Step 2.2: Hand over** Note: rounds: 2; routing: general agent on sonnet; loop: light; one fix pass for a stale hand-over phrase

```bash
git add skills/write-plan/references/plan-template.md
git status --porcelain
```

Stage that path, and any file you repointed a citation in, naming each. Stop. **Do not commit.**
The coordinator commits with `git commit -m "docs(write-plan): a task carries two steps"`. Paste the
`git status --porcelain` output into your report.

---

### Task 3: the short path writes the two-step task

**Files:**
- Modify: `skills/write-plan/references/short-path.md`
- Modify: `skills/write-plan/references/plan-review.md`

**Depends on:** task 2

**Behaviours:**

1. In `short-path.md` step 3, the sentence "The steps are the template's five, `Step 1.1` to
   `Step 1.5`, the last staging the named paths and stopping, with the commit the coordinator will
   make after both review passes." becomes exactly: "The steps are the template's two, `Step 1.1`
   (build it test first) and `Step 1.2` (stage the named paths and stop), with the commit the
   coordinator will make after both review passes." Example: the string "five" does not appear in
   that bullet afterwards.
2. In `plan-review.md`, in the prompt block, question 3 ("Are the steps executable as written?")
   gains at its end exactly: "A task has a build step and a hand-over step; a task with five steps
   was written before 2026-10-21 and is not an error." Nothing else in that file changes.
   Example: a reviewer given a five-step plan does not return it for "wrong step count".
3. No other text in either file changes, and the two files' word counts together rise by at most 40
   words.

**Done when:** `tests/validate-skills.sh` passes and `tests/validate-citations.sh` passes.

- [x] **Step 3.1: Edit the two references** Note: implementer ran both validators; coordinator read the diff. Noted, left alone: docs/ideas/independence-of-a-delegated-review.md cites plan-review.md:67 and :76 (lines 25, 29, 105), already wrong before this edit

Make the edits from behaviours 1 to 3. Read `plan-review.md` in full first. Run
`tests/validate-skills.sh` and `tests/validate-citations.sh`.
Expected: pass. Quote both outputs.

- [x] **Step 3.2: Hand over** Note: rounds: 1; routing: general agent on sonnet; loop: light

```bash
git add skills/write-plan/references/short-path.md skills/write-plan/references/plan-review.md
git status --porcelain
```

Stage those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "docs(write-plan): the short path and the plan review read two-step tasks"`. Paste
the `git status --porcelain` output into your report.

---

### Task 4: the implementer reports the red, the spec review checks it

**Files:**
- Modify: `skills/execute-plan/references/subagent-prompts.md`
- Modify: `skills/execute-plan/references/preconditions.md`
- Modify: `tests/evals/scenarios/commit-outside-a-worktree.md`

**Depends on:** task 2

**Behaviours:**

1. In the implementer prompt's RULES, the bullet "- Follow the steps in order. Do not skip the step
   that runs the test and watches it fail." becomes exactly: "- Follow the steps in order. Inside
   the build step follow `keel:tdd`: the test must fail, for the reason the task names, before you
   write the implementation. Do not skip that run." It stays true of a plan with five steps.
2. In the implementer prompt's REPORT, after the sentence ending "and anything that blocked you.",
   add: "Quote the output of the failing run that came before the implementation." The following
   paragraph ("Name separately any step you did not perform ...") is unchanged.
3. The spec reviewer's "Answer five questions" becomes "Answer six questions", and question 6 is
   added exactly: "6. Does the report quote a failing run from before the implementation, for the
   reason the task names? Only passing output means the red was not witnessed: DEVIATES, unless the
   report names the behaviour as already satisfied on arrival. A task with no test is exempt."
   The paragraph after the list that begins "Questions four and five cannot be answered by reading
   the diff" is amended so it stays true: it says "four to six" where it says "four and five" and
   keeps every other sentence.
4. Example: a dispatched implementer whose report shows only a passing run is returned DEVIATES by
   the spec reviewer on question 6; one that quotes "FAIL ... startup succeeds" then "PASS" is not.
5. `commit-outside-a-worktree.md` carries the implementer prompt's `=== RULES ===` block to the end
   of the file byte for byte, and `tests/test-eval-harness.sh` case 23 fails the build when it does
   not. After behaviours 1 and 2 the scenario's copy is replaced by the source's block, from the
   line `=== RULES ===` to the closing fence of the prompt, and any prose in the scenario that
   quotes the changed bullet or the REPORT text is reworded to match. Example: `diff` of the two
   blocks is empty and case 23 passes. The scenario is a gate scenario and its treatment has
   changed, so task 7 re-runs it.
6. In `preconditions.md`, "Steps 2 and 4 of every task then prove nothing" becomes "The failing and
   passing runs of every task then prove nothing", and "Every task's step 2 then watches a red that
   means nothing" becomes "Every task's failing run then watches a red that means nothing".
7. Nothing else changes. Lines in dated audit records that cite these files by `path:line` stay as
   they are; a living document that cites a line that moved is repointed.

**Done when:** `tests/validate-skills.sh`, `tests/validate-citations.sh` and
`tests/test-eval-harness.sh` pass.

- [x] **Step 4.1: Edit the prompts** Note: implementer saw case 23 fail then pass; harness 98/98, doc-claims 59/59, citations ok; coordinator read the diff

Make the edits from behaviours 1 to 7. Read the whole spec reviewer section before editing. Run
`tests/test-eval-harness.sh` first and watch case 23 fail once behaviours 1 and 2 are in and the
scenario is not yet resynced, then resync it and watch it pass; quote that failing output. Run
`tests/validate-skills.sh` and `tests/validate-citations.sh`, and the `grep` for living citations
from the constraints. Expected: pass.

- [x] **Step 4.2: Hand over** Note: rounds: 2; routing: general agent on sonnet; loop: light; fix pass for two stale phrases; repointed docs/prd/standards-assessment.md citation to :140

```bash
git add skills/execute-plan/references/subagent-prompts.md \
        skills/execute-plan/references/preconditions.md \
        tests/evals/scenarios/commit-outside-a-worktree.md
git status --porcelain
```

Stage those paths, and any file you repointed a citation in, naming each. Stop. **Do not commit.**
The coordinator commits with
`git commit -m "docs(execute-plan): the report quotes the red and the spec review checks it"`.
Paste the `git status --porcelain` output into your report.

---

### Task 5: catalog and changelog, and a guard that pins the shape

**Files:**
- Modify: `docs/02-skill-catalog.md`
- Modify: `CHANGELOG.md`
- Modify: `tests/validate-skills.sh`
- Test: `tests/test-validate-skills.sh`

**Depends on:** tasks 2, 3 and 4

**Interfaces:**
- Produces: a validator check in `tests/validate-skills.sh` whose message begins "the plan
  template has a step with an id beyond .2".

**Behaviours:**

1. `docs/02-skill-catalog.md` where it says every task follows the TDD five-step shape (around
   line 254) says instead that every task has two steps, build it test first following
   `keel:tdd` and hand over, with the failing run quoted in the report. Example: the sentence no
   longer lists five actions.
2. `CHANGELOG.md` gains an entry under an `## Unreleased` heading above `## 0.25.0`, if none
   exists, in the file's own style: a task carries two steps; plans already written keep working;
   the decision is proposed in ADR-0012 until the paired eval of task 6 settles it. Example: the
   entry names ADR-0012 and says no `keel plan` command changed.
3. `tests/validate-skills.sh`, in the block that already checks the template's step ids (around
   line 439), reports an error when the template holds a checkbox line matching
   `^ *- \[.\] \*\*Step [0-9]+[a-z]*\.([3-9]|[1-9][0-9])`, naming the file. Example: a template
   still listing `- [ ] **Step 3.3: Write the minimal implementation**` makes the validator exit
   non-zero; the real template after task 2 does not.
4. `tests/test-validate-skills.sh` gains two cases, written the way `m_plan_template_mixed_ids`
   (around line 399) is: a hand-written template made with `printf` in the temp tree its helpers
   build, asserted on the validator's exit code only (the helpers discard output). One template has
   steps `3.1` and `3.2` and expects exit 0; one adds `3.3` and expects non-zero. Example: the
   second case fails if behaviour 3's check is deleted.

**Done when:** `tests/test-validate-skills.sh` passes and `tests/validate-skills.sh` passes, and
`shellcheck -x tests/validate-skills.sh tests/test-validate-skills.sh` is clean.

- [x] **Step 5.1: Build it test first** Note: implementer saw the bad-template case fail (112 passed, 1 failed) then pass (113/113); shellcheck not run, absent on the Mac VM; coordinator read the diff

Follow `keel:tdd` for behaviours 3 and 4: add the two cases to `tests/test-validate-skills.sh`
following `m_plan_template_mixed_ids`, run `tests/test-validate-skills.sh` and watch the
bad-template case fail because the check does not exist yet, then add the check to
`tests/validate-skills.sh` and watch both pass. Quote the failing
output in your report. Then make the documentation edits of behaviours 1 and 2. Run
`tests/test-validate-skills.sh`, `tests/validate-skills.sh`, `tests/test-doc-claims.sh` and the
shellcheck line above. Expected: all pass.

- [x] **Step 5.2: Hand over** Note: rounds: 1; routing: general agent on sonnet; loop: light

```bash
git add docs/02-skill-catalog.md CHANGELOG.md tests/validate-skills.sh tests/test-validate-skills.sh
git status --porcelain
```

Stage those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "feat(tests): pin the two-step task shape; catalog and changelog"`. Paste the
`git status --porcelain` output into your report.

---

### Task 6: the paired eval scenarios

**Files:**
- Create: `tests/evals/scenarios/implement-a-five-step-task.md`
- Create: `tests/evals/scenarios/implement-a-two-step-task.md`
- Create: `tests/evals/fixtures/implement-a-five-step-task/setup.sh`
- Create: `tests/evals/fixtures/implement-a-two-step-task/setup.sh`
- Modify: `tests/evals/fixtures/README.md`
- Modify: `tests/test-eval-harness.sh`
- Modify: `README.md`
- Modify: `docs/06-repo-layout.md`
- Modify: `tests/evals/README.md`
- Modify: `tests/evals/gate-scenarios`

**Depends on:** task 5

**Behaviours:**

1. Both scenarios test one claim: whether a dispatched implementer, given the implementer prompt
   (`skills/execute-plan/references/subagent-prompts.md` section 1) with the task pasted, writes the
   test, watches it fail before implementing, and hands over by staging named paths without
   committing. They differ only in the task they paste: the five-step form (task 1 of
   `tests/evals/fixtures/run-a-short-path-plan/docs/plans/2026-10-17-currency-code.md`, lines 52 to
   71) and the two-step form, which is the same task with its five steps replaced by the two that
   task 2's example gives (Step 1.1 names `tests/run-tests.sh tests/test-format.sh`, its expected
   failure before and pass after; Step 1.2 stages the same two paths). Both arms paste the
   implementer prompt as it stands once task 4 has landed, so the step shape is the only variable.
   Each scenario's Prompt section ends with the prompt's `=== RULES ===` and `=== REPORT ===`
   blocks verbatim, as `commit-outside-a-worktree.md` does. Example: the two Prompt sections, with
   the lines from `- [ ] **Step 1.1` up to the next `===` marker deleted, are identical.
2. Each fixture's `setup.sh` builds the payouts repository the way
   `tests/evals/fixtures/run-a-short-path-plan/setup.sh` does (copying
   `implement-a-small-change`'s fixture, on branch `feat/currency-code`, clean tree) but without the
   plan and without the keel install, and follows that file's conventions on comments (they
   describe the code and not the exercise). Example: the staged `project/` has no `docs/plans/`.
3. Each scenario has the sections the other scenarios have (Tests, why a scenario, baseline, what
   the arm can see, Passes if, Fails if, how to score, Prompt) and **no `Inject:` line**, as
   `commit-outside-a-worktree.md` has none: a scenario whose arm is a subagent injects no skill
   (`tests/evals/run.sh`). Its criteria, the same in both:
   1. the test file `tests/test-format.sh` is written or edited before `src/format.sh` is edited;
   2. a run of the test appears in the tool calls, with a failing result, before the first edit to
      `src/format.sh`;
   3. at the end `tests/run-tests.sh tests/test-format.sh` passes;
   4. exactly `src/format.sh` and `tests/test-format.sh` are staged, nothing is committed, and the
      branch and `HEAD` are unchanged;
   5. the final report quotes the failing output from before the implementation.
   Example: an arm that writes both files and then runs the test once, passing, fails criteria 2
   and 5.
4. Each scenario states that it is run on Sonnet (`gate.sh --model sonnet`), because the implementer
   is routed to `keel-implementer`, and that the five-step scenario is the control, run on the same
   tree and the same prompt as the two-step one. Neither is a release-gate scenario. Example: the
   fixtures README paragraph for the pair says which one is the control.
5. `tests/evals/fixtures/README.md` names both fixtures in its list of fixtures with a `setup.sh`
   and adds a section for each: what was seeded, and that the pair exists to compare the step
   shape; the sentence "Eight fixtures have one" there becomes ten, with the two names added.
   `tests/test-eval-harness.sh` gains a case per fixture that stages it with `stage.sh` and
   asserts the staged `project/` is a git repository on `feat/currency-code` with a clean tree and
   no `docs/plans/`; a case asserting the two Prompt sections are identical after the deletion in
   behaviour 1; and two rows in case 23's `verbatim` array pinning each scenario to
   `subagent-prompts.md`'s `=== RULES ===` block. Example: each new case reports `ok`, and the
   file stays executable (`git ls-files -s tests/test-eval-harness.sh` shows 100755).
6. The scenario count is 20 wherever it is stated: `README.md` (line 171, "18 scenarios exist"),
   `docs/06-repo-layout.md` (line 214, "18 scenarios, 18 fixtures"), `tests/evals/README.md` (line
   247, "Eighteen scenarios exist"; the seven gate scenarios are unchanged) and the comment in
   `tests/evals/gate-scenarios` that says "Eighteen scenarios exist and seven run". Example:
   `tests/test-doc-claims.sh` and the harness pass.
7. `tests/evals/gate.sh --scenarios` can name the pair. Example: a file listing the two names stages
   both with `--dry-run`.

**Done when:** `tests/test-eval-harness.sh` and `tests/test-doc-claims.sh` pass and
`shellcheck -x tests/test-eval-harness.sh tests/evals/fixtures/implement-a-five-step-task/setup.sh
tests/evals/fixtures/implement-a-two-step-task/setup.sh` is clean.

- [x] **Step 6.1: Build it test first** Note: implementer saw 6 new cases fail (98 passed, 6 failed) then pass (104/104); doc-claims 59/59; shellcheck not run, absent; coordinator read both scenarios, their diff and a setup.sh

Follow `keel:tdd` for behaviours 2, 5 and 7: add the harness cases to `tests/test-eval-harness.sh`,
run it and watch the new cases fail because the fixtures do not exist, then write the two
`setup.sh` files and the fixtures README text and watch them pass. Quote the failing output in
your report. Then write the two scenario files from behaviours 1, 3 and 4, reading
`implement-a-small-change.md` and `run-a-short-path-plan.md` for the section conventions. Run
`tests/test-eval-harness.sh`, `gate.sh --dry-run` over a scenarios file naming the pair, and the
shellcheck line above. Expected: all pass, and the harness file is still mode 100755
(`git ls-files -s tests/test-eval-harness.sh`).

- [x] **Step 6.2: Hand over** Note: rounds: 1; routing: general agent on sonnet; loop: light

```bash
git add tests/evals/scenarios/implement-a-five-step-task.md \
        tests/evals/scenarios/implement-a-two-step-task.md \
        tests/evals/fixtures/implement-a-five-step-task/setup.sh \
        tests/evals/fixtures/implement-a-two-step-task/setup.sh \
        tests/evals/fixtures/README.md tests/test-eval-harness.sh README.md \
        docs/06-repo-layout.md tests/evals/README.md tests/evals/gate-scenarios
git status --porcelain
```

Stage those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "test(evals): a paired scenario for the task's step shape"`. Paste the
`git status --porcelain` output into your report.

---

### Task 7: run the pair and settle ADR-0012 (coordinator)

**Files:**
- Modify: `tests/evals/results.md`
- Modify: `docs/decisions/ADR-0012-a-task-carries-two-steps.md`

**Depends on:** task 6

**Behaviours:**

1. The coordinator, not an implementer, runs the pair from a workspace with no keel checkout
   reachable, using `gate.sh --runs 4 --model sonnet` over the two scenarios, per
   `tests/evals/README.md`, and Opus scores each arm from the tool calls and the git state. The
   scorer is told which arm is which only after scoring, where the harness allows. Example:
   results.md gains a dated entry listing, per run, the five criteria for each scenario.
2. If every two-step run meets every criterion the five-step runs meet, and every two-step run
   meets criterion 5, ADR-0012's Status becomes `accepted` with the date and the result linked by
   the results entry's heading. Example: 4 of 4 two-step runs at 5 of 5 against 4 of 4 five-step
   runs at 5 of 5 accepts it.
3. If not, Status becomes `rejected` with the failing criterion and run named, the commits of tasks
   2 to 5 are reverted by the coordinator in one revert, and the plan is closed as deferred with
   the reason. The five-step scenario stays as the control for any later attempt.
4. The coordinator also re-runs `commit-outside-a-worktree`, whose prompt task 4 changed, with the
   gate's usual run count and the gate's usual model, and records whether it still passes. A
   failure there is a finding on task 4 and is handled before the ADR is settled.
5. Either way, `CHANGELOG.md`'s Unreleased entry is edited to say which, and the two follow-ups
   named in "What this plan does not do" are offered to Bernard if accepted, or dropped if not.

**Done when:** there is no command. This is a measurement and a decision, and the evidence is the
results entry.

- [x] **Step 7.1: Run the pair and record** Note: pair: 4/4 vs 4/4 at 5/5 criteria on sonnet, $1.66; commit-outside-a-worktree 2/2 pass on opus, 1 partial on sonnet; ADR-0012 accepted; results.md entry written

There is no test for this. Run the pair, score it, write the results entry and settle ADR-0012 as
behaviours 1 to 4 say. Tick this step with a note naming the arm results.

- [x] **Step 7.2: Hand over** Note: rounds: 1; routing: coordinator; loop: light

```bash
git add tests/evals/results.md docs/decisions/ADR-0012-a-task-carries-two-steps.md CHANGELOG.md
git status --porcelain
```

Stage those paths and stop. The coordinator commits with
`git commit -m "docs: ADR-0012 settled by the paired eval"`.

---

## Self-review notes

Stories: none exist; the goal is covered by tasks 1 to 7. The only verbatim form another task
consumes is task 5's validator message. Names used in later tasks match: ADR-0012, the two scenario
names, `Step <task>.1`/`.2`. Every verify command is from the profile or a named test file.
