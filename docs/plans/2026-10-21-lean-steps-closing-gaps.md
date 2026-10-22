# Lean steps: closing the gaps Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** leave nothing open after `docs/plans/2026-10-21-lean-task-steps.md`. Three text changes
that plan deferred or found (stale citations and a stale comment, the concurrent-batch rules moved
into their own reference, the harness plan mode named in the template) and five checks it could
not finish (the full suite, `shellcheck` and bash 3.2 on Linux, a Sonnet baseline for the one arm
that scored partial, a second reader for the pair, an independent review of the whole change). The
baseline and the second reader were run while this plan was being reviewed; task 4 records them.
**Stories:** none. The input is Bernard's instruction of 2026-10-21, "proceed. there should be no
leftovers/gaps", on the list of leftovers in the previous plan's hand-off.
**ADRs:** ADR-0011, ADR-0012
**Architecture:** no skill body changes, so ADR-0011 owes no arm for the text tasks; the move in
task 2 is the one change that could alter what a planner reads, so task 4 runs the write-plan arm
on it. Tasks 1 to 3 and 5 are implemented; task 4 is the coordinator's and implements
nothing. Task 5 was added after the independent review in step 4.4 returned findings.
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Concurrent batches:** none. Tasks run one at a time in plan order, each handing over for the
coordinator to commit. Task 4 runs inline.

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test `tests/{name}`,
  lint `shellcheck -x` on the files the profile names. On the Mac VM a call is cut off at 180
  seconds and `tests/test-keel.sh` takes longer, so it runs in the cloud workspace (task 4).
- Work on `sandbox`, never on `main`.
- `docs/standards.md`: no em or en dashes; prose lines at most 100 columns; no `@` links; relative
  links resolve. A skill's frontmatter is not edited. A skill body stays at or under 700 words
  (ADR-0011); no task here edits a skill body.
- Citations: `tests/validate-citations.sh` only checks the file exists, the line is in range and
  the first cited line is not blank. After editing a file, also run
  `grep -rn '<file name>:[0-9]' docs README.md skills tests` outside `docs/plans/` and the dated
  `docs/audits/` records, and repoint any living citation whose line moved.
- Exact text given in a task is used exactly, rewrapped to 100 columns where it replaces wrapped
  prose. If an old text is not found exactly once, stop and report.
- Name paths when staging. Never `git add -A`, `git add .` or `git commit -a`. Do not commit; the
  coordinator does.

---

### Task 1: stale citations and a stale comment

**Files:**
- Modify: `docs/ideas/independence-of-a-delegated-review.md`
- Modify: `tests/evals/stage.sh`
- Modify: `tests/validate-citations.sh`
- Modify: `tests/test-validate-citations.sh`

**Depends on:** none

**Behaviours:**

1. The three citations of `plan-review.md` in the ideas document point at the lines they mean.
   Lines 25 and 105 cite `skills/write-plan/references/plan-review.md:67` for the rule "If
   nothing blocks, say so in the first line", and line 29 cites `plan-review.md:76` for "Do not
   dispatch this to the same context that wrote the plan". Each becomes the line where that text
   now is in the file (74 and 83 at the time of writing; use `grep -n` and take what it prints).
   Example: after the edit, `sed -n "<cited line>p"` of the file prints the sentence the citation
   names.
2. Three comments name a count that is no longer true, and each is reworded so that it names no
   count that can go stale again. In `tests/evals/stage.sh`, "Six scenarios need it" (around line
   136) becomes "Every fixture that carries a `setup.sh` needs it", and "Six other fixtures are
   repositories too" (around line 166) becomes "The other fixtures that build a repository are
   scored on the reply or on tool calls". In `tests/validate-citations.sh` (around line 45) "those
   eleven stand-in projects" becomes "those stand-in projects", and in
   `tests/test-validate-citations.sh` (around line 359) "holds eleven stand-in projects" becomes
   "holds stand-in projects". Nothing else in those files changes. Example:
   `grep -rniE 'six (other )?(scenarios|fixtures)|eleven stand-in' tests` finds nothing afterwards
   and `bash -n` passes on the three scripts.
3. A search for other stale counts finds none left that are not dated records. Search with
   `grep -rniE` for a number word from one to twenty, or digits, followed by `scenarios`,
   `fixtures` or `stand-in projects`, over `README.md`, `docs` and `tests` (`*.md` and `*.sh`
   files), and read every hit. A count in `docs/ideas`, `docs/prd`, `docs/snapshot.md`,
   `docs/audits` or `docs/plans` is a dated record and stays; any other count is either right
   (compare with `ls tests/evals/scenarios | wc -l` and `ls tests/evals/fixtures | wc -l`) or
   reworded as in behaviour 2. Example: the report lists every hit, says which are dated records,
   which are right, and which it changed.

**Done when:** `tests/validate-citations.sh`, `bash tests/test-validate-citations.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-eval-harness.sh` pass.

- [x] **Step 1.1: Build it test first** Note: agent ran edits and Done-when commands; coordinator re-ran harness and doc-claims

There is no failing test for a citation. Make the edits, then run the three commands of the
`Done when:` and the `sed -n` check of behaviour 1 for each of the three citations. Expected: all
pass and each `sed` prints the named sentence. Quote the outputs and the behaviour 3 hits.

- [x] **Step 1.2: Hand over**

```bash
git add docs/ideas/independence-of-a-delegated-review.md tests/evals/stage.sh \
        tests/validate-citations.sh tests/test-validate-citations.sh
git status --porcelain
```

Stage those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "docs: repoint three stale citations; comments no longer name a count"`. Paste the
`git status --porcelain` output into your report.

---

### Task 2: the concurrent-batch rules move to their own reference

**Files:**
- Create: `skills/write-plan/references/concurrent-batches.md`
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `skills/execute-plan/references/parallel-batches.md`
- Modify: `tests/test-plan.sh`

**Depends on:** task 1

**Interfaces:**
- Produces: `skills/write-plan/references/concurrent-batches.md`, linked from the template.

**Behaviours:**

1. The section `### Tasks that run concurrently` of `plan-template.md`, from that heading to the
   line before `### Why the Done when line exists`, moves into the new file, byte for byte except
   for (a) the heading becoming the file's `# Concurrent batches` title with a three-line
   introduction saying it is read from `plan-template.md` when a task may run beside another, (b)
   relative links re-based if they no longer resolve (the file sits beside the template, so
   `../../execute-plan/...` links stay), and (c) the words "above" and "below" and any mention of a
   neighbouring template section reworded to name the section and link `plan-template.md`.
   Example: `diff` of the moved lines against the same lines in `git show HEAD:<template>` shows
   only those changes.
2. In place of the section, the template has exactly this, under the same `###` heading:

   ````markdown
   ### Tasks that run concurrently

   A plan earns concurrency by declaring it, and the rules for a declared batch are in
   [concurrent-batches.md](concurrent-batches.md): the order to write the plan in, the strict
   `Files` form, the four rules every batched task meets, and what the header declares. Read it
   when you intend tasks to run at the same time, and whenever `keel plan batches` prints a batch.
   Run `keel plan batches <plan>` on every plan once its tasks are written. When it prints no batch,
   write `**Concurrent batches:** none` followed by its `why:` lines. A plan whose tasks would all
   write the same shared record (`CHANGELOG.md`, `README.md`) prints no batch for that reason, so
   leave such records to a task after the others whenever tasks could otherwise overlap; the
   reference says how.
   ````

3. Every sentence that points at the old section is reworded to link the new file: in the
   template, "(rule 2 under "Tasks that run concurrently")" in "The one exception is a declared
   concurrent batch" and "for the reason under "Tasks that run concurrently" above" in the Done
   when rules; in `skills/execute-plan/references/parallel-batches.md` (around lines 70 and 71),
   the link that names rule 2 under that heading. Example:
   `grep -rn 'under "Tasks that run concurrently"' skills` finds nothing.
4. The template and the new file together hold the same text as the old template, apart from the
   changes above and the stub. Example: the sum of `wc -w` of both is within 250 words of 4,228
   and the template alone is under 3,200 after this task.
5. `tests/test-plan.sh` reads the template. Around line 2964 it sets the template path, and two
   checks read text out of the moved section: the check around line 2976 that looks for the
   `**Depends on:** tasks 1 and 2` example, and the check around lines 2990 and 2991 that cuts the
   text from `2. **Write the final step as a commit` to the line beginning `The named-paths rule
   above still applies`. Both are repointed at `concurrent-batches.md`, and if rewording in
   behaviour 1 changes the end marker, the check's marker is changed to the new text and the check
   still asserts the same thing. Example: `bash tests/test-plan.sh` passes, and deleting the moved
   example from `concurrent-batches.md` makes the first check fail.
6. `tests/validate-skills.sh` still passes (it checks the template's step ids and that every
   relative link in a reference resolves), and `grep -rn 'plan-template.md#'` finds no anchor to a
   heading that moved.

**Done when:** `tests/validate-skills.sh`, `tests/validate-citations.sh`, `bash
tests/test-doc-claims.sh` and `bash tests/test-plan.sh` pass.

- [x] **Step 2.1: Move the section** Note: implementer ran diff, counts, validators; coordinator re-ran validators and checked the diff

There is no test to write first; the check is the diff of behaviour 1 and the validators. Move the
section with a script that extracts the lines by their boundary headings (do not retype it), apply
behaviours 2 and 3, then run the diff, the word counts and the `Done when:` commands. Quote the
diff summary, the counts and the outputs. Read the new file once end to end for any sentence that
now points at the wrong place.

- [x] **Step 2.2: Hand over**

```bash
git add skills/write-plan/references/concurrent-batches.md \
        skills/write-plan/references/plan-template.md \
        skills/execute-plan/references/parallel-batches.md tests/test-plan.sh
git status --porcelain
```

Stage those paths, and any file you repointed a citation in, naming each. Stop. **Do not commit.**
The coordinator commits with
`git commit -m "docs(write-plan): the concurrent-batch rules get their own reference"`. Paste the
`git status --porcelain` output into your report.

---

### Task 3: the harness's plan mode, and the changelog

**Files:**
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `CHANGELOG.md`

**Depends on:** task 2

**Behaviours:**

1. Before `## Header` in the template, a new section is added, exactly:

   ````markdown
   ## Starting from the harness's plan mode

   Where the harness has a plan mode, use it for the read-only exploration and the approval it
   gives, and treat its plan as a draft and not as the plan. Harden the draft: give each task its
   `Files`, `Behaviours` with examples, `Depends on:` and `Done when:` from the profile, and size
   the tasks as "Task granularity" says. Plan mode blocks writes until it is left, so write the
   file where `write-plan` step 3 says only after leaving it. The harness's approval covers the
   draft; the question at step 6 still carries the routing and the delivery. A harness with no plan
   mode, and a headless or scheduled run, writes the plan directly, and nothing else here changes.
   ````

   Example: `grep -c 'Starting from the harness' plan-template.md` is 1, and the section precedes
   `## Header`.
2. `CHANGELOG.md` gains two bullets under `## Unreleased`, in the file's style: the concurrent-batch
   rules now live in `skills/write-plan/references/concurrent-batches.md`, read when a plan may
   batch; and the template names the harness's plan mode as the source of a draft. The second says
   plainly that no eval measures it, because `claude -p` runs no plan mode, and the first says the
   same of the move, because no scenario writes a plan with a batch. Example: both bullets name the
   file they changed.
3. No skill body changes. Example: `git diff --stat` against the commit of task 2 shows only the two
   files, and `wc -w` of `skills/write-plan/SKILL.md` is unchanged. The template is under 3,300
   words afterwards.

**Done when:** `tests/validate-skills.sh`, `tests/validate-citations.sh` and `bash
tests/test-doc-claims.sh` pass.

- [x] **Step 3.1: Add the section and the entries** Note: implementer ran Done-when; coordinator checked the diff against the plan text

There is no test to write first. Make the edits and run the `Done when:` commands and the two
checks of behaviours 1 and 3. Quote the outputs.

- [x] **Step 3.2: Hand over**

```bash
git add skills/write-plan/references/plan-template.md CHANGELOG.md
git status --porcelain
```

Stage those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "docs(write-plan): the template starts from the harness's plan mode"`. Paste the
`git status --porcelain` output into your report.

---

### Task 4: close the checks the previous plan could not finish (coordinator)

**Files:**
- Modify: `tests/evals/results.md`
- Modify: `CHANGELOG.md`

**Depends on:** task 3

**Behaviours:**

1. **Full suite, lint and bash 3.2 on Linux.** `tests/run-tests.sh` runs to the end in the cloud
   workspace on a copy of `HEAD`, including `tests/test-keel.sh`; `shellcheck -x` runs over the
   files in `verify.lint`; and the tests that run the scripts a Mac ships
   (`tests/test-eval-harness.sh`, `tests/test-plan.sh`, `tests/test-validate-skills.sh`, the review
   guard) run again with a real bash 3.2 first on `PATH` as `bash`, built from source if the
   workspace can fetch it. Example: the suite ends "All test files passed", `shellcheck` exits 0
   and the 3.2 run passes, or each failure is reported with the file and cause. If bash 3.2 cannot
   be built here, that is a gap that stays open and is named, with the CI step that would close it
   (a macOS step that prints `/bin/bash --version` and runs the suite with `/bin/bash`), left to
   the owner because `.github/workflows` is a hard-block path.
2. **Sonnet baseline for `commit-outside-a-worktree`.** Three runs on `claude-sonnet-5-5` of the
   scenario as it stood at `v0.25.0` and three at `HEAD`, scored on criterion 4 from the tool calls
   (a command establishing where the arm is runs before it declines) and on criteria 1 to 3 from
   the git state. Decision rule: equal rates are recorded as the model's behaviour and not a
   regression; a lower rate at `HEAD` by two or more runs is a regression to repair before this
   change is merged, with its own task added to this plan. Result, run 2026-10-21: 0 of 3 at
   `v0.25.0` and 0 of 3 at `HEAD` ran such a command; all six left one commit, staged the two
   paths and passed the suite. It is the model's behaviour.
3. **Second reader for the pair.** An independent reader, never shown the first scorer's work,
   scores the eight pair arms on the five criteria. Result, run 2026-10-21: all 40 verdicts agree,
   with the reader's doubts recorded (the quotes in some reports are excerpts of the failing run,
   not the whole output).
4. **Independent review of the whole change.** A reviewer on the strongest model reads
   `git diff d1dd6a3..HEAD` (both plans, the merge of 0.25.0 to now) with the repository, answers
   the plan-review questions against it, and reports blocking, should-fix and consider findings
   with `path:line`. This is also the review of the tasks that were checked by the coordinator's
   own reading. Example: no blocking finding, or each is fixed in a further task of this plan.
5. **A check that the move left the short path intact.** Two runs on `claude-opus-5-5` of
   `implement-a-small-change`, which injects `write-plan`. It writes a one-task plan, so it
   cannot see a batching regression and is recorded as a check of the short path only. Example:
   both pass its six criteria.
6. The results of 1 to 5 go into `tests/evals/results.md` under the entry of 2026-10-21, whose
   statements "Scored by one reader" and "went with it" are corrected to what is then true, and
   into `CHANGELOG.md`'s Unreleased entry in a sentence.

**Done when:** there is no command. This is a set of measurements and a review, and the evidence
is the results entry.

- [x] **Step 4.1: Full suite, lint and bash 3.2** Note: full suite and shellcheck pass on Linux at ce8de8b; bash 3.2 not buildable (mirrors blocked), named as a gap; found a pre-existing pipefail grep -q flake, recorded not fixed

There is no test for this. Run behaviour 1 and note each result.

- [x] **Step 4.2: Sonnet baseline** Note: run 2026-10-21 before approval: Sonnet 0/3 vs 0/3, model behaviour

Behaviour 2, run 2026-10-21 before this plan was approved to build; tick with the result.

- [x] **Step 4.3: Second reader** Note: run 2026-10-21 before approval: 40/40 verdicts agree

Behaviour 3, run 2026-10-21 before this plan was approved to build; tick with the result.

- [x] **Step 4.4: Independent review of the whole change** Note: Opus review: no blocking; findings fixed in task 5, residuals named in results.md

Behaviour 4. Fix each blocking finding through a further task of this plan before ticking.

- [x] **Step 4.5: The short-path check, then record** Note: short-path 2/2 Opus pass, recorded in results.md and CHANGELOG

Behaviour 5, then write behaviour 6. Tick with a note naming each result.

- [x] **Step 4.6: Hand over**

```bash
git add tests/evals/results.md CHANGELOG.md
git status --porcelain
```

Stage those paths and stop. The coordinator commits with
`git commit -m "docs: the gaps of the lean-steps change are closed or named"`.

---

### Task 5: fix what the independent review of the whole change found

**Files:**
- Modify: `tests/validate-skills.sh`
- Modify: `tests/test-validate-skills.sh`
- Modify: `tests/test-eval-harness.sh`
- Modify: `bin/keel`
- Modify: `docs/decisions/ADR-0012-a-task-carries-two-steps.md`
- Modify: `docs/prd/standards-assessment.md`
- Modify: `docs/02-skill-catalog.md`
- Modify: `tests/evals/fixtures/README.md`
- Modify: `skills/write-plan/references/plan-template.md`
- Modify: `skills/write-plan/references/concurrent-batches.md`
- Modify: `skills/write-plan/references/plan-review.md`
- Modify: `agents/keel-implementer.md`

**Depends on:** task 3

**Behaviours:**

1. `tests/validate-skills.sh` applies its two refusals about step ids (an old-form `**Step <n>:`
   and an id beyond `.2`) to `skills/write-plan/references/concurrent-batches.md` as well as to the
   template, when that file exists, because the nested example commit step moved there. The check
   that a template carries at least one id stays on the template alone. The comment above the
   checks gains one sentence saying the patterns match fenced and indented example steps too, which
   `keel plan` does not count, so an example follows the same numbering. Example:
   `tests/test-validate-skills.sh` has two new cases, `m_batches_step_beyond_two` (a fixture tree
   whose `concurrent-batches.md` holds `- [ ] **Step 1.5: Commit**`) and `m_batches_old_form` (one
   holding `- [ ] **Step 5: Commit**`), each run with the template valid, and each exits 1 naming
   `concurrent-batches.md`; a tree whose `concurrent-batches.md` holds `Step 1.2: Commit` exits 0.
   All existing cases still pass.
2. `docs/decisions/ADR-0012-a-task-carries-two-steps.md` says "the paired eval of task 7", not
   "task 6", because task 7 of the plan runs the pair. Example: `grep -n 'paired eval of task'` on
   the file prints task 7.
3. In `docs/prd/standards-assessment.md` the citation of `subagent-prompts.md` that follows
   "the `=== PROJECT STANDARDS ===` block is now in the implementer prompt" points at the line of
   the review prompt's `=== PROJECT STANDARDS ===` at this commit. Take it from
   `grep -n '=== PROJECT STANDARDS ===' skills/execute-plan/references/subagent-prompts.md`: the
   first hit is the implementer prompt's, the second the review prompt's; cite the line the
   sentence means by reading the sentence. Example: `sed -n "<cited line>p"` prints
   `=== PROJECT STANDARDS ===`.
4. In `tests/test-eval-harness.sh` the comment that begins "It existed in no file until
   2026-09-06" reads as one unbroken sentence again, ending where it ended before cases 38b and 38c
   were added, and those two cases (from the line `# 38b.` through the end of case 38c) sit
   together straight after the last case of that "release-gate scenario set" block, not in the
   middle of its comment. No line of either case changes. Example: `bash tests/test-eval-harness.sh`
   prints the same number of passes as before, and `sed -n` of the comment lines shows no `# 38b.`
   inside it.
5. In `bin/keel` the comment above `plan status` that quotes `**Step 3.2: Run it and watch it
   fail**` quotes `**Step 3.2: Hand over**` instead, rewrapped to 100 columns, and nothing else in
   the file changes. Example: `git diff bin/keel` shows only comment lines, and
   `bash tests/test-plan.sh` passes.
6. `tests/evals/fixtures/README.md`, in the row for the short-path plan fixture, says the plan has
   "five steps, the shape the template wrote before 2026-10-21, which plans already written keep"
   where it now says "the template's five steps". Example: `grep -n "template's five steps"` on the
   file finds nothing.
7. In `skills/write-plan/references/plan-template.md`: (a) the "Skipping the failing-test step"
   row of the common-mistakes table becomes "Skipping the quote of the failing run", its reason
   unchanged; (b) the story-kind table becomes exactly:

   ````markdown
   | Story kind | Task 1 is | Then |
   |---|---|---|
   | `build` | One task whose build step starts from the failing test for new behaviour | Hand over |
   | `verify` | One task whose build step writes a test for behaviour believed correct | If it passes on arrival, the report says so and why, quotes that run and writes no code, and the story is done. If it fails, the story becomes `fix` and needs new tasks |
   | `fix` | One task whose build step starts from a test reproducing the defect | Fix at the root cause, in the same build step |
   | `decide` | **Not a plan.** Route it to `design-architecture` for an ADR | No code |
   ````

   Example: `grep -c "Skipping the failing-test step"` on the file is 0, and `wc -w` of the template
   is under 3,400.
8. `docs/02-skill-catalog.md`, in the `write-plan` entry, replaces "Bite-sized steps of 2 to 5
   minutes." with "Two steps per task: a build step that follows `keel:tdd`, and a hand-over
   step.", rewrapped to 100 columns. Example: `grep -n "Bite-sized" docs/02-skill-catalog.md`
   finds nothing.
9. In `skills/write-plan/references/concurrent-batches.md` the sentence that says every agent's
   failing-test run "ticks the box" says it "counts as its own proof" instead, the quoted phrase
   after it unchanged. Example: `grep -n "ticks the box"` on the file finds nothing.
10. In `skills/write-plan/references/plan-review.md` question 3: "run it and watch it fail" naming
    no command and no expected output becomes "a build step naming no command and no expected
    output for the failing run", and the last sentence becomes "A task has a build step and a
    hand-over step; a plan written now with five-step tasks is a defect, and one written before
    2026-10-21 that is being resumed is not." Example: `grep -n "watch it fail"` on the file finds
    nothing, and the sentence about five-step tasks is present once.
11. `agents/keel-implementer.md`, in the "Report what you saw" rule, adds that for a task with a
    build step the report quotes the failing run from before the implementation, in a sentence
    added after "Paste the output of each verify command," and rewrapped to 100 columns. Example:
    `grep -n "failing run" agents/keel-implementer.md` prints the rule, and `bash
    tests/test-agents.sh` passes.

**Done when:** `bash tests/test-validate-skills.sh`, `tests/validate-skills.sh`,
`tests/validate-citations.sh`, `bash tests/test-doc-claims.sh`, `bash tests/test-plan.sh`,
`bash tests/test-agents.sh` and `bash tests/test-eval-harness.sh` pass.

- [x] **Step 5.1: Build it test first** Note: implementer quoted the red before the validator change; coordinator checked the diff and reran

Behaviour 1 is the only one with a test. Write the two new cases in
`tests/test-validate-skills.sh` first, run `bash tests/test-validate-skills.sh`, and quote the two
cases failing because `tests/validate-skills.sh` does not yet look at `concurrent-batches.md`.
Then make the validator change, and then behaviours 2 to 11, which are text and are checked by the
examples given. Run the seven `Done when:` commands and quote the outputs.

- [x] **Step 5.2: Hand over**

```bash
git add tests/validate-skills.sh tests/test-validate-skills.sh tests/test-eval-harness.sh bin/keel \
        docs/decisions/ADR-0012-a-task-carries-two-steps.md docs/prd/standards-assessment.md \
        docs/02-skill-catalog.md tests/evals/fixtures/README.md \
        skills/write-plan/references/plan-template.md \
        skills/write-plan/references/concurrent-batches.md \
        skills/write-plan/references/plan-review.md agents/keel-implementer.md
git status --porcelain
```

Stage those paths and stop. **Do not commit.** The coordinator commits with
`git commit -m "fix: what the review of the lean-steps change found"`. Paste the
`git status --porcelain` output into your report.

---

## Self-review notes

Every item in the previous hand-off's leftovers list maps to a task: the three citations and the
stale comments to task 1, the batch-rules move and the plan-mode wording to tasks 2 and 3, and the
suite, bash 3.2, the Sonnet lead, the single reader, the unreviewed diff and the move's effect to
task 4. What task 4 cannot close from here is the macOS CI run, which needs the owner's push. The
only verbatim text another task consumes is the stub and the new section, each in the task that
adds it. Commands come from the profile or from named test files.
