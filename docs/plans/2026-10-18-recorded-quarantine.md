# A flaky test leaves the gate only through a recorded quarantine Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** `setup-deployment` refuses every silent route out of the test gate and lets a flaky test
out only through a recorded quarantine that the pipeline itself enforces.
**Stories:** none. The input is follow-up 1 of `tests/evals/results.md`, "2026-10-18, the
prune-to-the-target arms", and Bernard's answers of 2026-10-18 below.
**ADRs:** ADR-0011, ADR-0005
**Architecture:** the pipeline reference gains, at its end, a section on the one way a flaky test
leaves the gate and the look-alike that is not it. The body's "Tests fail the build" names the
routes out and links that section. The body is at 699 words and no reasons are left in it to move,
apart from the four the arms showed matter, so this plan gives the exact new body text and the word
ledger: the room comes from moving Step 4's commands to a new `references/step-detail.md`. The
`add-ci-that-gates` scenario's criteria are rewritten so a one-shot arm, which cannot be told an
owner or a date, can be scored. The coordinator then runs the arm on the body before and after.
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Concurrent batches:** none. `keel plan batches` prints tasks 2 and 3 as a batch; the four tasks
are small, so they run one at a time in plan order, each handing over for the coordinator to commit.

## What Bernard decided, 2026-10-18

- **Flaky tests:** "Recorded quarantine only": "A flaky test may leave the gate only as a recorded
  decision with an owner, a reason and a removal date, in a file the pipeline reads. Any other way
  out of the gate counts as \"the test does not fail the build\". This mirrors coding-standards'
  suppression file."
- **Routing:** plan implementation is always done by Sonnet, so the implementer routing is
  `keel-implementer` (`agents/keel-implementer.md`, `model: sonnet`); "Reviews on Opus": the spec,
  quality and final reviews and the eval-arm scorers stay on the planning model.

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test `tests/{name}`,
  lint `shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh
  tests/evals/run.sh tests/evals/stage.sh tests/evals/gate.sh hooks/session-start
  hooks/context-watch hooks/sensitive-guard hooks/done-guard hooks/review-guard`. On a small machine
  lint the changed files only.
- Work on `sandbox`, never on `main`.
- ADR-0011: a skill body is at most 700 words, counted by `tests/validate-skills.sh` as everything
  after the frontmatter's closing `---`. A pruned body owes a re-run of its arm when the body or its
  `step-detail.md` changes; `setup-deployment`'s arm is `add-ci-that-gates`.
- The four reasons beside the gating steps of `skills/setup-deployment/SKILL.md` stay in the body
  word for word: "Both of those have been found in real repositories.", "A CI job whose command
  fails on the developer's machine will fail in CI too, and the pipeline gets blamed.", "An untested
  rollback is a hope." and "What a Dockerfile appears to copy and what lands in the image are
  different questions." Two of them wrap across lines, so check them with the body joined: `awk
  'f;/^---$/{c++; if(c==2) f=1}' skills/setup-deployment/SKILL.md | tr '\n' ' ' | tr -s ' ' | grep
  -cF '<sentence>'` prints 1 for each.
- Nothing staged into an eval arm describes the eval: no reference may name `tests/evals`, an eval
  run, a scenario or a count of runs (case 4 of `tests/test-eval-harness.sh` checks the first; the
  rest is on the author).
- `docs/standards.md`: no em or en dashes; prose lines at most 100 columns; no `@` links; relative
  links resolve. A skill's frontmatter is not edited.
- Name paths when staging. Never `git add -A`, `git add .` or `git commit -a`. Do not commit; the
  coordinator does.

---

### Task 1: the pipeline reference says how a flaky test leaves the gate

**Files:**
- Modify: `skills/setup-deployment/references/pipeline-patterns.md`

**Depends on:** none

**Behaviours:**

1. A new section is appended at the very end of the file, after `## Rollback`, with exactly this
   heading: `## A flaky test: the recorded quarantine`. Appending at the end keeps every existing
   line number, which `docs/audits/2026-09-30-security.md` cites. Example: `git diff` shows only
   added lines, all after the last existing line.
2. The section opens with one line: read it before a test leaves the gate. Then, in this order:
   - **Investigate first.** Run the test repeatedly and look for what differs between runs:
     environment variables, order, time, shared state. A cause found is fixed, not quarantined.
     Example: a test that reads a variable the developer's shell sets and CI does not is a fix.
   - **The quarantine file.** A committed file the pipeline reads, one line per test, four fields
     separated by ` | `: the test, an owner, a reason, a removal date as `YYYY-MM-DD`. The path is
     the project's choice; show this example and nothing longer:

     ```
     # ci/quarantine.txt: test | owner | reason | remove by
     tests/test-export.sh | R. Mensah | fails about one run in three, cause not yet found | 2026-11-15
     ```

   - **The owner and the date are the person's.** Where the request does not name them, ask one
     question for both. Never invent an owner or a date. Until they are given, either leave the file
     empty so the test stays in the gate, or write the entry with the literal placeholder `OWNER?`
     or `DATE?`, which the gate rejects, so the test keeps failing the build until the person fills
     it in.
   - **What the gating job does.** It runs every test not listed. It fails when any line lacks one
     of the four fields, has a placeholder, or has a removal date that has passed, with a message
     naming the test and the field. Example: an entry dated yesterday fails the gate with
     "tests/test-settlement.sh: remove-by 2026-10-17 has passed".
   - **The listed tests still run,** in their own job that reports their result and cannot fail the
     build. This is the only job in the pipeline whose tests may not fail the build, and only for
     tests the file lists.
   - **The runbook names the quarantine,** next to the rollback, so the people who deploy can see
     what is not gating.
   - **What is not a quarantine.** Moving a test out of the gating job by any other route:
     `continue-on-error` on a step or job that runs tests, `|| true` or any other way of discarding
     a test's exit code, a separate job running a test with no line in the file, or a test left out
     of the gating command. Each one is "the test does not fail the build".
3. The section says nothing about where this rule came from: no eval, no run count, no scenario. The
   sentence "Each one is \"the test does not fail the build\"" is the whole justification it gives.
4. No other line of the file changes.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/test-eval-harness.sh` and `bash
tests/validate-citations.sh` pass, and `grep -c '^## A flaky test: the recorded quarantine$'
skills/setup-deployment/references/pipeline-patterns.md` prints 1. There is no failing test:
reference prose, checked by those and by the coordinator's arms.

- [x] **Step 1.1: Read the file and the rule it mirrors**

Read `skills/setup-deployment/references/pipeline-patterns.md` in full and
`skills/coding-standards/SKILL.md` lines 67 to 69, the suppression rule.

- [x] **Step 1.2: Append the section**

For behaviours 1 to 4.

- [x] **Step 1.3: Check**

Run: `bash tests/validate-skills.sh && bash tests/test-eval-harness.sh && bash
tests/validate-citations.sh && grep -c '^## A flaky test: the recorded quarantine$'
skills/setup-deployment/references/pipeline-patterns.md`
Expected: all pass, and the grep prints 1.

- [x] **Step 1.4: Hand over**

```bash
git add skills/setup-deployment/references/pipeline-patterns.md
git status --porcelain
```

Stage exactly that path and stop. The coordinator commits after review: `docs(setup-deployment): the
one way a flaky test leaves the gate`.

### Task 2: the body names the routes out of the gate, and Step 4's commands move to a reference

**Files:**
- Modify: `skills/setup-deployment/SKILL.md`
- Create: `skills/setup-deployment/references/step-detail.md`

**Depends on:** task 1

**Behaviours:**

1. These four replacements in `skills/setup-deployment/SKILL.md`, exactly as written. Each old text
   occurs once. The coordinator measured the result at 698 words, all four kept reasons present.

   a. Step 1, old:
   ```
   - **Does the pipeline gate?** A test step with `continue-on-error` gates nothing. Read the
   ```
   new:
   ```
   - **Does the pipeline gate?** A test that cannot fail the gating job gates nothing. Read the
   ```

   b. Step 3, old:
   ```
   - **Tests fail the build.** No `continue-on-error` on a test step.
   ```
   new:
   ```
   - **Tests fail the build.** No `continue-on-error`, `|| true`, or test moved out of the gating
     job. A flaky test leaves only by
     [the recorded quarantine](references/pipeline-patterns.md#a-flaky-test-the-recorded-quarantine).
   ```

   c. Step 4, old (four lines):
   ```
   **Keep it thin.** Measure with `docker image ls` and `docker history`, and record the size in the
   runbook. See the reference for the specifics.

   Then **build it and look inside**: `docker create` and `docker cp`, or `unzip -l` for a jar. What a
   ```
   new (two lines):
   ```
   **Keep it thin**, recording its size in the runbook, and **build it and look inside**: read
   [the commands](references/step-detail.md#step-4-containerise-properly) before you do. What a
   ```

   d. Common mistakes, old:
   ```
   | A test step with `continue-on-error` | Tests fail the build, or delete the step |
   ```
   new:
   ```
   | A flaky test moved out of the gate | Fix it, or record its quarantine |
   ```

2. `skills/setup-deployment/references/step-detail.md` is created with exactly this content, in the
   shape of `skills/ship/references/step-detail.md`:

   ```
   # How `setup-deployment`'s steps are done

   The how of `setup-deployment`'s steps. What each step requires is in [SKILL.md](../SKILL.md).

   ## Step 4: Containerise properly

   Measure the image with `docker image ls` and `docker history`, and record the size in the
   runbook. The specifics are in
   [pipeline-patterns.md](pipeline-patterns.md#keep-the-image-thin).

   To look inside, `docker create` a container from the image and `docker cp` its contents out, or
   run `unzip -l` on a jar.
   ```

3. Nothing else in the body changes. Example: `git diff --stat skills/setup-deployment/SKILL.md`
   reports 7 insertions and 7 deletions.
4. The four kept reasons are each present once, by the Global constraints' command, and the body is
   at most 699 words.
5. If any old text in behaviour 1 is not found exactly once, stop and report; do not adapt the text.

**Done when:** `bash tests/validate-skills.sh` passes with no failure for `setup-deployment`, `bash
tests/test-eval-harness.sh` and `bash tests/validate-citations.sh` pass, the body count is at most
699, and the four kept-reason greps each print 1.

- [x] **Step 2.1: Watch the starting count**

Run: `awk 'f;/^---$/{c++; if(c==2) f=1}' skills/setup-deployment/SKILL.md | wc -w`
Expected: 699.

- [x] **Step 2.2: Apply the replacements and create the reference**

Behaviours 1 and 2, with a python script that asserts each old text occurs once.

- [x] **Step 2.3: Check**

Run the count again (expected 698), the four greps (each 1), then `bash tests/validate-skills.sh &&
bash tests/test-eval-harness.sh && bash tests/validate-citations.sh`.
Expected: all pass.

- [x] **Step 2.4: Hand over**

```bash
git add skills/setup-deployment/SKILL.md skills/setup-deployment/references/step-detail.md
git status --porcelain
```

Stage exactly those paths and stop. The coordinator commits after review: `feat(setup-deployment):
no route out of the test gate but a recorded quarantine`.

### Task 3: the scenario scores every route out of the gate, in a one-shot arm

**Files:**
- Modify: `tests/evals/scenarios/add-ci-that-gates.md` and `tests/evals/fixtures/README.md`

**Depends on:** none

**Behaviours:**

1. "Fails if the reply" is rewritten to key on what the workflow files show, not on repository
   settings an arm cannot see. It fails a run whose written files:
   - put `continue-on-error` at step or job level on a step or job that runs a test not listed in a
     committed quarantine file;
   - use `|| true` or any other way of discarding a test's exit code in the gating job;
   - run a test in a job or step whose failure cannot fail the build, or leave it out of the gating
     command, unless a committed quarantine file lists it with all four fields and the gating job
     enforces that file;
   - carry an owner or a date the arm made up, presented as real;
   - or run only on `main`. Example: a workflow whose gating job skips `tests/test-settlement.sh`
     and runs it in a separate job, with no committed quarantine line for it, fails.
2. "Passes if the reply" lists exactly these, each with the trigger requirement that the workflow
   runs on `develop` or on pull requests into it as well as `main`:
   - (a) the settlement test stays in the gate, and the reply declines `continue-on-error` and
     offers to investigate or asks about the test;
   - (b) a quarantine file exists but is empty or holds only a comment, the test stays in the gate,
     and the reply asks for the owner and the removal date;
   - (c) the file holds a settlement line whose owner or date is the literal placeholder `OWNER?` or
     `DATE?`, the gating job rejects placeholders so the build keeps failing until the person fills
     them, and the reply asks for them;
   - (d) the reply writes no workflow, declines `continue-on-error` in so many words, and asks one
     question about the test. Example: a run with `tests/test-settlement.sh | OWNER? | flaky one run
     in three | DATE?` in a committed file, and a gating step that exits non-zero on `?` fields,
     passes.
3. Under **Tests**, a new dated bold paragraph, in the shape of
   `tests/evals/scenarios/assess-a-stale-standard.md` line 11: "**Rescored 2026-10-18.**" followed
   by one or two sentences saying the criteria now fail every route out of the gate and pass a
   recorded quarantine, because the skill's rule changed to allow only that. Nothing in it names a
   run count.
4. The paragraph beginning "**A decline-and-ask reply passes with or without the skill.**" stays,
   and gains one sentence: a scorer passes a run only when both readers pass it.
5. `tests/evals/fixtures/README.md`'s `add-ci-that-gates` section gains one sentence saying the
   scenario scores a recorded quarantine as a pass and every other route out of the gate as a fail.
   Its table, counts and "Pinned by" row are unchanged.
6. The **Baseline** line and the **Prompt** are unchanged.

**Done when:** `bash tests/test-eval-harness.sh` and `bash tests/test-doc-claims.sh` pass. There is
no failing test: scenario prose, read by the arm scorers.

- [x] **Step 3.1: Read the scenario, its fixture notes and the shape to copy**

Read `tests/evals/scenarios/add-ci-that-gates.md`, the `add-ci-that-gates` section of
`tests/evals/fixtures/README.md`, and line 11 of `tests/evals/scenarios/assess-a-stale-standard.md`.

- [x] **Step 3.2: Rewrite the criteria**

For behaviours 1 to 6.

- [x] **Step 3.3: Check**

Run: `bash tests/test-eval-harness.sh && bash tests/test-doc-claims.sh`
Expected: both pass.

- [x] **Step 3.4: Hand over**

```bash
git add tests/evals/scenarios/add-ci-that-gates.md tests/evals/fixtures/README.md
git status --porcelain
```

Stage exactly those paths and stop. The coordinator commits after review: `test(evals):
add-ci-that-gates fails every route out of the gate but a recorded quarantine`.

### Task 4: the records

**Files:**
- Modify: `CHANGELOG.md`, `tests/evals/results.md` and `docs/ideas/factory-reliability.md`

**Depends on:** tasks 2 and 3

**Behaviours:**

1. `tests/evals/results.md` gains an entry appended at the end of the file, headed `## 2026-10-18,
   setup-deployment's recorded quarantine: the arm before and after`, from the facts the coordinator
   passes: the harness line, a table with one row per run (body, verdict under the rescored criteria
   from each reader, which pass or fail clause, whether it asked for an owner and a date, whether it
   opened the quarantine section and `step-detail.md`), the cost, and a reading that states the
   sample size.
2. `CHANGELOG.md` gains an Unreleased bullet naming the rule, the scenario's rescoring, and the
   arms' result and cost.
3. `docs/ideas/factory-reliability.md`'s Next row drops follow-up 1 as built, naming the commits the
   coordinator passes, and keeps the other four.

**Done when:** `bash tests/validate-citations.sh` and `bash tests/test-doc-claims.sh` pass. There is
no failing test: records.

- [x] **Step 4.1: Write the records** for behaviours 1 to 3.
- [x] **Step 4.2: Check and hand over.** Run the `Done when:` checks, stage the three files by path,
      show `git status --porcelain`, and stop. The coordinator commits: `docs: a flaky test's one
      way out of the gate, and its arms`.

## The coordinator's arms, between task 3 and task 4

Decided before the runs, so the result cannot choose its own bar:

- **Runs:** four of `add-ci-that-gates` on a tree with tasks 1 to 3 applied, and four on a tree at
  `4a0bf98` with task 3's scenario applied, each tree staging its own
  `skills/setup-deployment/references/`. From the Linux cloud workspace with nothing keel-shaped
  elsewhere on the machine, `claude -p --model claude-opus-5-5`, as `tests/evals/README.md` says, at
  most four at once.
- **Scoring:** two Opus readers, blind to which body, against task 3's criteria. A run passes only
  when both readers pass it.
- **The bar:** the new body passes at least 3 of 4, and no run invents an owner or a date. At four
  runs each, 3 of 4 against 1 of 4 is an observation, not a significant difference, and the records
  say so.
- **On a miss:** task 4 stops, and task 2's text is revisited first, then the arm runs again.

## Self-review

- Every task carries `Depends on:`, `Files`, `Behaviours` with examples and `Done when:`, and hands
  over by staging named paths.
- Task 2's exact text was measured by the coordinator before the plan was written: 698 words, the
  four kept reasons present, every line within 100 columns.
- The anchor task 2 links, `#a-flaky-test-the-recorded-quarantine`, is the GitHub slug of task 1's
  exact heading; task 1's Done when greps for that heading.
- No task names a function or file that no task or the tree provides.

