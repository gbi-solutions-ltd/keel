# Plans name behaviours, not code Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> Both tasks change skill text and docs and carry no failing test; each behaviour's example is the
> wording it must produce, checked by the commands in `Done when:` and by a reviewer.

**Goal:** a plan task lists its behaviours, each with an example, plus its files, its interfaces and
its `Done when:`, and carries verbatim code only for a form another task consumes. The implementer
writes the tests from the examples and the code under `keel:tdd`; the spec review, and `review-code`
for the feature, check that every behaviour's example has a case.
**Stories:** none. A change to keel's own planning, specified by a decided idea record.
**ADRs:** none written for this, and none contradicted: no decision record requires verbatim code in
plans. ADR-0001 governs the `write-plan` and `execute-plan` body edits; ADR-0007 is untouched, since
test-first stays.
**Architecture:** text only, in `write-plan` (steps 3 and 4, its template, its review brief),
`execute-plan` (step 2, the implementer prompt, the spec review) and `review-code`'s rubric pass. No
command changes.
**Implementer routing:** keel-implementer
**Decided:** Bernard, 2026-10-16, `docs/ideas/delivery-flow-gaps.md`, "Decided" item 2: behaviours
only, verbatim code only for an interface another task consumes, and the spec pass carries the
precision verbatim code used to.
**Shape:** this plan's tasks are in the shape it describes. The two plans written so before it are
its trial. Their plan reviews found no task unbuildable for want of code, but `keel plan report` on
them shows 6 of 7 tasks took 2 or 3 implementer rounds, one of them a fix pass for four fail-open
holes: rounds, not only rework, is the measure to watch.
**Reviewed:** by a dispatched plan reviewer on 2026-10-16; "What the review changed" records it.

## Global constraints

Copied from `.keel/profile.json` and `docs/standards.md`. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint as `.keel/profile.json`
  spells it (read it there; do not retype it from here). If `command -v shellcheck` prints nothing,
  say the lint was not run and that CI will run it.
- **`tests/run-tests.sh` takes about 2m30s.** Run it in the background and read its log to the end
  within one tool call.
- **Precondition: the working tree is clean and nothing is staged.** Each commit stages named paths
  only, checked with `git diff --cached --name-only`. Never `git add -A`.
- Never start on `main`.
- No em dashes and no en dashes, in any file or commit message. Prose wraps at 100 columns; table
  rows and code blocks do not.
- Every commit carries its own documentation, `CHANGELOG.md` included.
- Commits carry no attribution footers; this repository sets `conventions.no_attribution_footers`.
- No vendor model alias under `skills/`.
- **Skill bodies.** `write-plan` is at 798 words and `execute-plan` at 887, both over 700: each body
  edit owes an ADR-0001 eval arm, recorded as owed in `CHANGELOG.md`. Both stay at or below 900.
- **A verbatim copy.** `tests/evals/scenarios/commit-outside-a-worktree.md` carries the implementer
  prompt's `=== RULES ===` block verbatim and `tests/test-eval-harness.sh` checks it. This plan does
  not edit that block: the new instruction goes in its own block above it.
- **Line citations.** Other documents cite lines of `skills/write-plan/SKILL.md`,
  `skills/write-plan/references/plan-template.md`, `skills/write-plan/references/plan-review.md`,
  `skills/execute-plan/references/subagent-prompts.md` and `docs/02-skill-catalog.md`. The validator
  checks only that a cited line exists and is not blank, so after each edit read every cited line
  (`grep -rn '<file>:[0-9]' docs`) and keep it on the text it cites, fixing by placement.

## What this plan does not build

- **No change to the five TDD steps a task carries.** Write the failing test, watch it fail, write
  the code, watch it pass, run the suite at the boundary: the steps stay; what a step contains
  changes.
- **No change to `keel plan status`, `tick`, `report` or `risk`.**
- **No rewrite of plans already written.** A task in the old shape, with verbatim test code and no
  behaviours list, stays valid and is followed as written.

---

### Task 1: `write-plan` asks for behaviours

**Story:** none.
**Files:**
- Modify: `skills/write-plan/SKILL.md`, `skills/write-plan/references/plan-template.md`,
  `skills/write-plan/references/plan-review.md`, `docs/02-skill-catalog.md`, `CHANGELOG.md`

**Interfaces:**
- Produces: the task shape, verbatim. After `**Depends on:**` and before `**Done when:**`, a task
  carries the line `**Behaviours:**` followed by a numbered list; each item is one behaviour with at
  least one example. Verbatim code, a signature or a data shape another task consumes, goes in the
  `**Interfaces:**` block and nowhere else.

**Depends on:** none

**Behaviours:**

1. **Step 3** gains, after its `Done when:` paragraph, a paragraph whose first sentence is: "Every
   task carries a `**Behaviours:**` list: each behaviour, with at least one example of an input and
   the result it must give, such as \"a net payout of 1000 at 3% is 970\"." It then says the only
   verbatim code a plan carries is a form another task consumes, in `**Interfaces:**`. The
   five-steps sentence stays.
2. **Step 4's list** keeps "TBD", "implement later", "fill in details" and "A type, function, or
   method that no task defines", and replaces the rest with exactly: "A behaviour with no example";
   "\"Handle edge cases\" or \"add validation\" without each edge or rule as a behaviour with its
   example"; "\"Similar to Task 3\" instead of restating the behaviours. Tasks are read out of
   order".
3. **The template's example task** (Task 3, "Reject an empty credential at startup") becomes the new
   shape: a `**Behaviours:**` list (for example "1. An empty `apiKeys` list fails startup with a
   message naming `apiKeys`."), the same five steps with their `Run:` lines and the hand-over `git
   add` block but no test or implementation code, and step 3.2's expected result in the form
   "Expected: FAIL, the case for behaviour 1 fails because startup succeeds".
4. **The template's other sections agree:** "Why the Interfaces block exists" says it is the one
   place for verbatim form; "No placeholders" reads "If you cannot state a behaviour with an
   example, the plan is not finished"; "Tasks with no test" says a no-test task's example is the
   wording it must produce or the output of a check command; the self-review gains the item "8.
   Every behaviour has an example a test, or for a no-test task a check command or a reader, can
   assert."; the opening provenance sentence no longer says "Adapted closely" and says the task
   shape is keel's own.
5. **`plan-review.md`:** question 3's example "A step saying write the failing test with no test in
   it" becomes "A behaviour with no example, or an example no test could assert"; the list of checks
   already run gains "every behaviour has an example".
6. **`docs/02-skill-catalog.md`**, the `write-plan` entry: "Real code in the plan, never \"add error
   handling here\"" becomes "Behaviours with examples in the plan, never \"add error handling
   here\"", and "near-verbatim" no longer describes it, without changing the file's line count.
7. **`CHANGELOG.md`:** an Unreleased entry, with the owed ADR-0001 arm for `write-plan`.

**Done when:** all of these:
- `bin/keel plan status` on this plan exits 0.
- `tests/validate-skills.sh` prints `OK`, with `write-plan` at or below 900 words.
- `bash tests/test-doc-claims.sh` and `tests/validate-citations.sh` pass.
- `grep -c 'without the test code' skills/write-plan/SKILL.md` prints 0.
- `grep -c 'instead of repeating the code' skills/write-plan/SKILL.md` prints 0.
- `grep -c '^```java' skills/write-plan/references/plan-template.md` prints 0.
- `grep -c 'Behaviours:' skills/write-plan/references/plan-template.md` prints at least 1.

- [x] **Step 1.1: Edit step 3 and step 4** for behaviours 1 and 2. Note: by a sonnet subagent; quoted wording used exactly, per the spec reviewer
- [x] **Step 1.2: Rewrite the template's example task and the sections around it** for 3 and 4. Note: template example rewritten with no java blocks; surrounding sections agree, per the reviewer
- [x] **Step 1.3: The review brief, the catalog and the CHANGELOG** for 5 to 7. Note: review brief, catalog and CHANGELOG by the subagent; write-plan 850 words, arm owed
- [x] **Step 1.4: Check and commit.** The `Done when:` checks, the cited-line read, and the full Note: rounds: 1; routing: keel-implementer (sonnet, by hand); loop: light; spec pass DEVIATES only on two shifted citations outside the task's files, which I repointed by heading anchor in independence-of-a-delegated-review.md and skill-review-findings.md; full run-tests.sh witnessed by me, all passed
  `tests/run-tests.sh`. Stage the five files and this plan. Commit: `feat(skills): write-plan asks
  for behaviours with examples, not code`.

---

### Task 2: execution and review build on behaviours

**Story:** none.
**Files:**
- Modify: `skills/execute-plan/SKILL.md`, `skills/execute-plan/references/subagent-prompts.md`,
  `skills/review-code/references/rubric-pass.md`,
  `tests/evals/scenarios/commit-outside-a-worktree.md`, `docs/ideas/delivery-flow-gaps.md`,
  `CHANGELOG.md`

**Interfaces:**
- Consumes: the `**Behaviours:**` line and list task 1 defines.

**Depends on:** task 1

**Behaviours:**

1. **The implementer prompt's task line** reads "<paste the task, including its Files, Interfaces,
   Behaviours, Done when, and every numbered step>".
2. **A new block above `=== RULES ===`**, outside it, headed `=== BEHAVIOURS ===`, says: "Where the
   task lists `**Behaviours:**`, write the tests from them: at least one case per example, each case
   named for the behaviour it asserts. Take verbatim only what `**Interfaces:**` gives. A listed
   behaviour with no example makes the task not executable as written: stop and report. A task with
   no behaviours list, in the older shape, is followed as written." The `=== RULES ===` block is
   unchanged, and `bash tests/test-eval-harness.sh` passes.
3. **The spec review's question 3** reads: "Does each listed behaviour have a test asserting its
   example, and does no test assert something adjacent instead? For a task with no test, quote the
   line of the diff that produces each behaviour's example."
4. **`execute-plan` step 2's list** gains "a behaviour with no example" (a few words; the body stays
   at or below 900), so inline mode, which has no spec pass, still refuses it before starting.
5. **`review-code`'s rubric pass question 1** gains: "Where the plan lists behaviours, does every
   behaviour's example have a case named for it?"
6. **The scenario's stale prose.** `commit-outside-a-worktree.md`'s sentence "nothing checks it" is
   no longer true (`tests/test-eval-harness.sh` checks the block); it says so.
7. **Records.** `docs/ideas/delivery-flow-gaps.md`: Status names gap 1 built with its commits, Next
   names gap 4. `CHANGELOG.md`: the entry, the owed ADR-0001 arm for the `execute-plan` body edit,
   and the risk taken, to be watched as `rounds` and `rework` in `keel plan report`.

**Done when:** `bash tests/test-eval-harness.sh`, `tests/validate-skills.sh` (`OK`, `execute-plan`
at or below 900), `bash tests/test-doc-claims.sh` and `tests/validate-citations.sh` pass;
`grep -c '=== BEHAVIOURS ===' skills/execute-plan/references/subagent-prompts.md` prints 1; and a
reviewer finds behaviours 1 to 7 stated as quoted.

- [x] **Step 2.1: The implementer prompt, the spec review and step 2** for behaviours 1 to 4. Note: by a sonnet subagent; RULES block untouched, eval-harness 48/0
- [x] **Step 2.2: The rubric pass and the scenario prose** for behaviours 5 and 6. Note: rubric pass and scenario prose by the subagent
- [x] **Step 2.3: The records** for behaviour 7. Note: records by the subagent; execute-plan 892 words, arm owed
- [x] **Step 2.4: Check and commit.** The `Done when:` checks, the cited-line read, and the full Note: rounds: 1; routing: keel-implementer (sonnet, by hand); loop: light; one spec pass, COMPLIES; four shifted citations repointed by me in dated audits, a plan and an idea record; full run-tests.sh witnessed by me, all passed
  `tests/run-tests.sh`. Stage the changed files and this plan. Commit: `feat(skills): execution and
  review build on a task's behaviours`.

---

## What the review changed

A plan reviewer read the first draft on 2026-10-16. Applied: the stop-on-no-example rule is scoped
to tasks that list behaviours, so old plans and the eval scenario stay valid; the instruction goes
in a new block above `=== RULES ===`, decided here, so the verbatim copy is untouched; a no-test
task's examples are its wording or a check's output, and the spec question says how to check them;
task 1's `Done when:` now fails on the unedited tree; the catalog and CHANGELOG moved into task 1;
the `**Behaviours:**` label is fixed by task 1's `Produces:`; the five steps keep their commands and
hand-over block; inline mode is covered through `execute-plan` step 2; the task line names
Behaviours; the trial's rounds are stated; `review-code`'s rubric gains the coverage check; pinned
wording is quoted; and the citation constraint names every file whose lines are cited.
