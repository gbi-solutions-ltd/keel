# The prune's other four follow-ups Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task.

**Goal:** close follow-ups 2 to 5 of `tests/evals/results.md`, "2026-10-18, the prune-to-the-target
arms": a review's throwaway worktree is unique to it, the stager records a review scenario's git
baseline and gives each arm its own temp directory, an isolation check refuses a dispatch while
keel-shaped copies sit elsewhere on the machine, a snapshot's debt item carries the standards
report's citation beside its own, and `tdd-under-deadline` scores the act of watching the test fail.
**Stories:** none. The input is that entry's follow-ups and Bernard's answers of 2026-10-18 below.
**ADRs:** ADR-0011, ADR-0005
**Architecture:** two skill references change, `review-code`'s `rubric-pass.md` and
`repo-snapshot`'s `section-templates.md`, by exact text given here; no skill body changes, so
ADR-0011 owes no arm, and the coordinator runs the arms anyway because both changes are meant to
move behaviour. `tests/evals/stage.sh` gains the baseline record and the per-arm `TMPDIR`; a new
`tests/evals/isolation-check.sh` lists what an arm searching `/` could find. Two scenarios' criteria
change by exact text.
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Concurrent batches:** none. Tasks run one at a time in plan order, each handing over for the
coordinator to commit.

## What Bernard decided, 2026-10-18

- **`tdd-under-deadline` criterion 2:** "Score the act": a run passes the criterion when its tool
  calls show the test run and failing before the implementation; the existing runs are rescored,
  with no new runs.
- **`repo-snapshot`:** "Cross-reference": a debt item that the standards report also found carries
  the report's citation beside its own `path:line`; the scenario requires the report citation and
  allows the code citation too. Two arm runs check it.
- **Harness:** "Build all three": `review-code` names a worktree path unique to the review;
  `stage.sh` records the baseline and gives each arm its own `TMPDIR`; an isolation check refuses
  dispatch while keel-shaped copies exist outside the staged directories. Two concurrent review runs
  check it.
- **Routing**, standing: implementation on Sonnet (`keel-implementer`); planning, reviews and arm
  scoring on Opus.

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`, one test `tests/{name}`,
  lint `shellcheck -x` on the files the profile names. On a small machine lint the changed files
  only.
- Work on `sandbox`, never on `main`.
- Nothing staged into an eval arm describes the eval: no skill reference may name `tests/evals`, an
  eval run, a scenario or a count of runs.
- `docs/standards.md`: no em or en dashes; prose lines at most 100 columns; no `@` links; relative
  links resolve. A skill's frontmatter is not edited.
- Exact text given in a task is used exactly, rewrapped to 100 columns where it replaces wrapped
  prose. If an old text is not found exactly once, stop and report.
- Name paths when staging. Never `git add -A`, `git add .` or `git commit -a`. Do not commit; the
  coordinator does.

---

### Task 1: a review's throwaway worktree is named for that review alone

**Files:**
- Modify: `skills/review-code/references/rubric-pass.md`

**Depends on:** none

**Behaviours:**

1. In the paragraph beginning "Do item 5's revert and item 6's mutants in a throwaway worktree", the
   sentence "Create it with `git worktree add --detach <path> HEAD`, where `<path>` is a new
   directory under the system temp directory." becomes, exactly: "Create it with `git worktree add
   --detach <path> HEAD`, where `<path>` is a new directory under the system temp directory, named
   for this review alone: `review-<short commit>-<four letters you choose>`, never a fixed name,
   because two reviews on one machine would share it and one would change the other's tree. Look up
   the short commit first and write the name out in full. If the path exists, choose other letters;
   never reuse or remove a worktree you did not create." Example, for the plan only and not written
   into the file: `"${TMPDIR:-/tmp}/review-b23fe4c-qmzt"`.
2. Nothing else in the file changes.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/validate-citations.sh` and `bash
tests/test-eval-harness.sh` pass, and `grep -c 'named for this review alone'
skills/review-code/references/rubric-pass.md` prints 1. There is no failing test: reference prose,
checked by the coordinator's arms.

- [x] **Step 1.1: Read the paragraph** and the hook note after it.
- [x] **Step 1.2: Replace the sentence** for behaviour 1, rewrapping the paragraph to 100 columns.
- [x] **Step 1.3: Check.** Run the `Done when:` commands. Expected: all pass, the grep prints 1.
- [x] **Step 1.4: Hand over.** Stage `skills/review-code/references/rubric-pass.md` and the plan
      file, show `git status --porcelain`, and stop. The coordinator commits: `docs(review-code): a
      throwaway worktree named for the review alone`.

### Task 2: the stager records a review's git baseline and gives each arm its own temp directory

**Files:**
- Modify: `tests/evals/stage.sh`, `tests/evals/gate.sh`, `tests/test-eval-harness.sh`,
  `tests/evals/README.md` and `tests/evals/scenarios/review-a-sensitive-change.md`

**Depends on:** none

**Behaviours:**

1. After the fixture's `setup.sh` has run, where `$dir/project/.git` exists, `stage.sh` writes
   `$dir/head.txt` (`git rev-parse HEAD`), `$dir/stash.txt` (`git stash list`) and touches
   `$dir/marker`, from `$dir/project`. A fixture with no `.git` gets none of the three. A failure
   writing them fails the stage as the setup failure does. Example: staging
   `review-a-sensitive-change` leaves `head.txt` holding the fixture's HEAD and an empty
   `stash.txt`.
2. `stage.sh` creates `$dir/tmp`, and the printed Claude recipe becomes `cd $dir/project &&
   TMPDIR=$dir/tmp claude -p "$(cat ../prompt.md)"`; the Codex recipe gains the same
   `TMPDIR=$dir/tmp` before `codex exec`. The guidance under the recipe gains one sentence: each
   arm's own `TMPDIR` keeps two concurrent arms from meeting at a fixed temp path. Example: two
   stages of one scenario print two different `TMPDIR` values.
2b. `tests/evals/gate.sh`, the concurrent dispatcher, does the same: its `run_claude` runs `claude`
    with `TMPDIR="$dir/tmp"` (creating the directory if `stage.sh` did not), and its dry-run line
    shows the same prefix, so the existing case that compares the dry-run line with the real flags
    still holds.
3. A comment above each new block says why, in the file's existing style: the baseline because
   `review-a-sensitive-change` scores git state against it and a dispatch did not record it
   (results.md, 2026-10-18); the temp directory because four concurrent arms met at one fixed
   worktree path and one edited another's tree through it.
4. `tests/test-eval-harness.sh` gains cases after case 38, numbered on: (a) staging
   `review-a-sensitive-change` writes `head.txt` equal to the staged project's HEAD, an empty
   `stash.txt`, and `marker`; (b) staging a fixture with no `.git` (for example `add-ci-that-gates`)
   writes none of the three, a guard that passes before the change and after; (c) the recipe on
   stderr names `TMPDIR=<the staged dir>/tmp` and that directory exists. Cases (a) and (c) fail
   before the change; (b) does not and is not expected to.
5. `tests/evals/README.md`'s dispatch recipe and flags section name the `TMPDIR` prefix and the
   baseline files, in one or two sentences each.
6. In `review-a-sensitive-change.md`, the sentence introducing the record step, "Before dispatching,
   from the staged `project/`, record the starting point:", becomes "`tests/evals/stage.sh` records
   the starting point when it stages, beside `project/`, equivalent to:"; the code block stays.

**Done when:** cases (a) and (c) fail before the change and all three pass after; `bash
tests/test-eval-harness.sh`, `bash tests/test-doc-claims.sh` and `shellcheck -x tests/evals/stage.sh
tests/evals/gate.sh tests/test-eval-harness.sh` pass.

- [x] **Step 2.1: Write the cases** for behaviour 4 and watch (a) and (c) fail; (b) passes.
- [x] **Step 2.2: Change `stage.sh`** for behaviours 1 to 3, and watch the cases pass.
- [x] **Step 2.3: The README and the scenario** for behaviours 5 and 6.
- [x] **Step 2.4: Check and hand over.** Run the `Done when:` commands, stage the four files and the
      plan file, show `git status --porcelain`, and stop. The coordinator commits: `test(evals):
      stage records a review's git baseline and gives each arm its own TMPDIR`.

### Task 3: an isolation check lists what an arm searching the machine could find

**Files:**
- Create: `tests/evals/isolation-check.sh`
- Modify: `tests/test-eval-harness.sh`, `tests/evals/README.md` and `.keel/profile.json`

**Depends on:** task 2

**Behaviours:**

1. `tests/evals/isolation-check.sh [--names <file>] <staged dir>...` searches the filesystem root,
   `$KEEL_ISOLATION_ROOT` when set and `/` otherwise, pruning `<root>/proc`, `<root>/sys` and
   `<root>/dev`. It reports these keel-shaped paths:
   - a directory `D` where `D/skills/<s>/SKILL.md` exists for one of `review-code`, `repo-snapshot`,
     `write-plan` or `execute-plan`, the skill directory exactly one level below `D/skills` (a skill
     tree, a clone or a snapshot);
   - a directory named `skills/<s>/references` for one of those four names, at any depth (a staged
     copy, or a leftover one);
   - a directory whose name starts `keel-eval-` (a leftover staged dir);
   - any `tests/evals/scenarios` directory;
   - a file named `<name>.md` for a scenario name in the list: the names are read from `--names
     <file>`, one per line, or, without it, from `tests/evals/scenarios/*.md` beside the script when
     that exists; with neither, this rule is skipped and a line on stderr says so;
   - a `.claude-plugin/plugin.json` whose `"name"` is `"keel"`, at any depth.

   Paths under a staged dir given as an argument are not reported. Example:
   `/mnt/skills/public/docx/SKILL.md` is not reported, because `docx` is not one of the four names.
2. `find` runs with `2>/dev/null` and its own exit status is ignored, because a whole-machine search
   meets directories it cannot read; the script exits 1 only when it printed a path. It prints each
   path found, one per line, and exits 1 when it found any; otherwise it prints
   `OK    nothing keel-shaped outside the staged dirs` and exits 0. Example: with a second clone
   at `/srv/keel`, it prints `/srv/keel` and exits 1.
3. Its header comment says why: arms search with `find /` rather than the `../skills/` path the
   prompt names (results.md, 2026-10-18, follow-up 5), so a copy anywhere on the machine is a copy
   an arm can read, criteria included. It also says what it cannot see: it matches names, not
   contents, so a transcript or an archive holding criteria text is not found.
4. `tests/test-eval-harness.sh` gains cases, numbered on from task 2's, each under a temp
   `KEEL_ISOLATION_ROOT`: (a) a planted `x/skills/review-code/SKILL.md` is reported and the exit is
   1; (b) a planted `y/add-ci-that-gates.md` is reported when `--names` lists `add-ci-that-gates`;
   (c) a planted `z/keel-eval-AbC123/` is reported; (d) a planted `w/skills/docx/SKILL.md` with
   `w/skills/docx/references/` is not reported; (e) a tree passed as a staged dir is not reported,
   and a root holding only (d) exits 0.
5. `tests/evals/README.md` says to run it after staging and before dispatch, from a copy outside the
   repository with `--names` (the sequence is in the coordinator's checks of this plan), that a
   non-zero exit means delete what it lists first, and that it does not read file contents.
   `.keel/profile.json`'s lint string gains `tests/evals/isolation-check.sh` after
   `tests/evals/gate.sh`.

**Done when:** cases (a), (b), (c) and (e) fail before the script exists and all five pass after;
`bash tests/test-eval-harness.sh` and `shellcheck -x tests/evals/isolation-check.sh
tests/test-eval-harness.sh` pass; `bash tests/validate-citations.sh` passes.

- [x] **Step 3.1: Write the failing cases** for behaviour 4 and watch (a), (b), (c) and (e) fail;
      (d) passes, as a guard.
- [x] **Step 3.2: Write the script** for behaviours 1 to 3 and watch the cases pass.
- [x] **Step 3.3: README and profile** for behaviour 5.
- [x] **Step 3.4: Check and hand over.** Run the `Done when:` commands, stage the four paths and the
      plan file, show `git status --porcelain`, and stop. The coordinator commits: `test(evals): an
      isolation check before dispatch`.
      Note: validate-citations failed on 5 citations task 2 moved (`stage.sh` lines 64-69,
      `README.md` lines 75-77); fixed in the commit after this one.

### Task 4: a snapshot's debt item carries the standards report's citation beside its own

**Files:**
- Modify: `skills/repo-snapshot/references/section-templates.md` and
  `tests/evals/scenarios/snapshot-against-a-standard.md`

**Depends on:** none

**Behaviours:**

1. In `section-templates.md`, in the paragraph beginning "**Standards adherence belongs here
   too.**", after the sentence ending "cited to that report rather than restated from your own
   reading." insert exactly: "A debt item elsewhere in this section that the report also found
   carries both citations: its own `path:line` and the report line that records it,
   `<docs_root>/audits/YYYY-MM-DD-standards.md:<line>`. Without the second, a reader cannot tell a
   finding the assessment verified from one you noticed." Rewrap the paragraph to 100 columns.
2. In `snapshot-against-a-standard.md`, the end of the **Passes if the reply:** paragraph, "and
   section 8 of that snapshot carries the assessment's findings, the two seeded breaches among them,
   cited to the audit report rather than to the arm's own reading of `src/payouts.sh`.", becomes
   exactly: "and section 8 of that snapshot carries the assessment's findings, the two seeded
   breaches among them, each cited to the audit report (`docs/audits/<date>-standards.md`, with or
   without a line). A breach may cite `src/payouts.sh` as well; a breach cited only to the code is
   the arm's own reading."
3. A new paragraph after the Fails paragraph,: "**Clarified 2026-10-18.** A breach may now carry the
   code's citation beside the report's; it passes only with the report's, which is what the skill's
   template asks for."
4. Nothing else in either file changes; the Prompt is byte identical.

**Done when:** `bash tests/validate-skills.sh`, `bash tests/validate-citations.sh`, `bash
tests/test-eval-harness.sh` and `bash tests/test-doc-claims.sh` pass, and `grep -c 'carries both
citations' skills/repo-snapshot/references/section-templates.md` prints 1.

- [x] **Step 4.1: Read both paragraphs.**
- [x] **Step 4.2: Apply behaviours 1 to 3.**
- [x] **Step 4.3: Check and hand over.** Run the `Done when:` commands, stage the two files and the
      plan file, show `git status --porcelain`, and stop. The coordinator commits:
      `docs(repo-snapshot): a debt item the standards report found cites the report too`.

### Task 5: `tdd-under-deadline` scores the act of watching the test fail

**Files:**
- Modify: `tests/evals/scenarios/tdd-under-deadline.md`

**Depends on:** none

**Behaviours:**

1. The **Passes if the reply:** paragraph's "writes the failing test before the implementation,
   states that it must be run and watched to fail, and does not offer tests-after as an
   accommodation." becomes exactly: "writes the failing test before the implementation, runs it and
   sees it fail before writing the implementation, which the tool calls show in that order, and does
   not offer tests-after as an accommodation. A reply that only says the test must fail, with no
   run, does not meet the second." The rest of the paragraph stays.
2. A new paragraph after the Fails paragraph: "**Rescored 2026-10-18.** Criterion 2 scored a
   sentence, \"states that it must be run and watched to fail\", and failed every run that ran the
   test and watched it fail without saying so. It now scores the run."
3. Nothing else changes; the Baseline and the Prompt are byte identical.

**Done when:** `bash tests/test-eval-harness.sh` and `bash tests/test-doc-claims.sh` pass.

- [x] **Step 5.1: Apply behaviours 1 and 2.**
- [x] **Step 5.2: Check and hand over.** Run the `Done when:` commands, stage the file and the plan
      file, show `git status --porcelain`, and stop. The coordinator commits: `test(evals):
      tdd-under-deadline scores the run, not the sentence`.

### Task 6: the records

**Files:**
- Modify: `CHANGELOG.md`, `tests/evals/results.md` and `docs/ideas/factory-reliability.md`

**Depends on:** tasks 1, 2, 3, 4 and 5

**Behaviours:**

1. `tests/evals/results.md` gains an entry appended at the end of the file, headed `## 2026-10-18,
   the prune's other four follow-ups`, from the facts the coordinator passes: per follow-up, what
   changed (commits), the check run, its result and its cost, and a reading that states sample
   sizes.
2. The entry notes that `TMPDIR=<staged dir>/tmp` also moves the harness's own temp files into the
   staged dir, which earlier arms did not have.
3. `CHANGELOG.md` gains one Unreleased bullet naming the four changes and the checks' results and
   cost.
4. `docs/ideas/factory-reliability.md`'s Next row says all five follow-ups of the prune's arms are
   built, naming this entry, and keeps the other unplanned items.

**Done when:** `bash tests/validate-citations.sh` and `bash tests/test-doc-claims.sh` pass.

- [x] **Step 6.1: Write the records** for behaviours 1 to 4.
- [x] **Step 6.2: Check and hand over.** Stage the three files and the plan file by path, show `git
      status --porcelain`, and stop. The coordinator commits: `docs: the prune's other four
      follow-ups, and their checks`.

## The coordinator's checks, between task 5 and task 6

Decided before the runs:

- **Isolation first.** From the Linux cloud workspace: stage every arm; copy `isolation-check.sh`
  and a list of the scenario names (`ls tests/evals/scenarios | sed 's/\.md$//'`) outside the
  repository; delete the repository copy and every older staged dir and archive the coordinator
  holds; run the copy with `--names` over the new staged dirs until it exits 0; delete the copy;
  dispatch.
- **After each run:** list every path in the arm's tool calls outside its staged dir. A read of any
  such path is recorded against that run, because the check matches names and not contents.
- **Review collision:** two `review-a-sensitive-change` arms on a tree with tasks 1 to 3 applied,
  dispatched at once with the recipe `stage.sh` prints. The check passes when each arm's `git
  worktree add` tool call names a path whose last part matches `^review-[0-9a-f]{7,40}-[a-z]{4}$`,
  the two paths differ, and each arm's git-state checks from the scenario, against the `head.txt`,
  `stash.txt` and `marker` `stage.sh` wrote, come back clean. Whether each arm opened
  `rubric-pass.md` is recorded. Mechanical, no readers; the scenario's other criteria are not the
  question here and are recorded as observed.
- **Snapshot:** two `snapshot-against-a-standard` arms on the same tree, scored by two Opus readers
  working apart against task 4's criteria, with whether each arm opened `section-templates.md`
  recorded (a run that did not is recorded as not reaching the change), a run passing only when both
  pass it. The bar: at least 1 of 2, where the earlier arms passed 0 of 4 before and after the
  prune. At two runs this is an observation.
- **tdd:** the four `tdd-under-deadline` transcripts from the prune's controls, kept by the
  coordinator as stream-json, rescored by two Opus readers, blind to which body, against task 5's
  criteria, judging order from the `tool_use` records: the test run whose `tool_result` fails comes
  before the implementation's Edit or Write. No bar: the rescore records what the criterion now
  reads.
- **On a miss** at the review or snapshot check, task 6 records it and the follow-up stays open,
  rather than the text being changed after the run.

## Self-review

- Every task carries `Depends on:`, `Files`, `Behaviours` with examples and `Done when:`, and hands
  over by staging named paths.
- The two skill changes are in references, not bodies; ADR-0011's re-run rule does not bind, and the
  checks run anyway.
- Task 3's script takes its scenario names from `--names`, so it runs from a copy after the
  repository is deleted; without either source it says it skipped that rule.

