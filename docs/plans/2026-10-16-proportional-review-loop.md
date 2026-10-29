# A review loop in proportion to the code it guards Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for task 1. Tasks 2 and 3 change skill text, requirements and
> docs and carry no failing test; they are checked by `tests/validate-skills.sh`, the doc checks and
> a reviewer.

**Goal:** a task whose change touches none of the project's `hard_block_paths` gets one spec pass,
the feature gets one quality review at the end through `review-code`, and a rejected task or a
blocking final review gets one fix pass before the person is asked. A task touching one keeps the
loop as it is. Which loop applies is decided by a command that fails safe, not by judgement.
**Stories:** S-03 of `docs/stories/coding-standards-enforcement.md` is amended by task 2 (FR-11
applies in the full loop only), decided by Bernard 2026-10-16. No new stories.
**ADRs:** none written for this. ADR-0002 (delegated execution, the coordinator writes no code) is
unchanged: it fixes who reviews, not how many passes. ADR-0007 is untouched: this removes review
passes, not test-first. ADR-0001 governs the body edits in tasks 2 and 3.
**Architecture:** one read-only command, `keel plan risk`, says which loop a change gets. It matches
paths exactly as `hooks/sensitive-guard` does and prints `loop: light` only when it can show that
nothing sensitive is touched; every other outcome is the full loop. `execute-plan` and `review-code`
read it. `keel plan report` shows each task's loop.
**Implementer routing:** keel-implementer
**Decided:** Bernard, 2026-10-16. `docs/ideas/delivery-flow-gaps.md`, "Decided" item 4; and, put to
him after the plan review the same day: a repository with no `hard_block_paths` gets the light loop,
and keel declares its own list; the final `review-code` gets the same one-fix-then-ask cap, built
here; FR-11 applies in the full loop only, with `ship`'s standards gate covering the light loop.
**Shape:** behaviours with examples, no verbatim implementation, as gap 1 decided.
**Reviewed:** by a dispatched plan reviewer on 2026-10-16; "What the review changed" records it.

## Global constraints

Copied from `.keel/profile.json` and `docs/standards.md`. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint as `.keel/profile.json`
  spells it (read it there; do not retype it from here). CI runs that lint and **info findings fail
  it**. If `command -v shellcheck` prints nothing, say the lint was not run and that CI will run it.
- **`tests/run-tests.sh` takes about 2m30s.** Run it in the background and read its log to the end
  within one tool call. Say which ran.
- **Precondition: the working tree is clean and nothing is staged.** Each commit stages named paths
  only, checked with `git diff --cached --name-only`. Never `git add -A`.
- Never start on `main`.
- No em dashes and no en dashes, in any file or commit message. Prose wraps at 100 columns; table
  rows and code blocks do not.
- Every commit carries its own documentation, `CHANGELOG.md` included.
- Commits carry no attribution footers; this repository sets `conventions.no_attribution_footers`.
- No vendor model alias under `skills/`. Routing is named by delegation profile.
- **Skill bodies.** `execute-plan` is at 889 of 900 words: its one edit replaces a sentence with one
  no longer than it, and anything else goes in its references. `review-code` and `ship` edits stay
  inside 900. A body edit to a skill over 700 words owes an ADR-0001 eval arm; the task says how.
- **Line citations.** Some documents cite line ranges in others (`templates/profile.schema.json`
  cites `hooks/sensitive-guard#get("hard_block_paths") or []`). Do not change `hooks/sensitive-guard`; where an edit shifts a
  cited line elsewhere, `tests/validate-citations.sh` says so, and the fix is placement.
- Bash 3.2 compatible.

## What this plan does not build

- **No change to `write-plan`'s plan reviewer.** It caught two blocking problems on 2026-10-16, and
  the decision did not cover it.
- **No unattended run** from an approved plan to a pull request. That is gap 4. Until then the
  person starts `review-code` after `execute-plan`, which step 6 names as the feature's quality
  review in the light loop.
- **No change to `hooks/sensitive-guard`.** The plan review found it misses a rename out of a
  declared path (`git diff --cached --name-only` lists only the destination). `plan risk` does not
  copy that gap; the hook's is recorded as a known gap in `CHANGELOG.md` by task 1, for its own fix.
- **No change to the full loop.** Both passes, the discard rule and the re-dispatch stay exactly as
  written for a task that touches a declared path.

## The rule

A task's loop is decided after its implementer stages, from `keel plan risk --staged`, or for a
batched task from `keel plan risk --range <base>..<task-head>`:

- **Light loop** only when the command exits 0 and its last line is `loop: light`: a declared list
  that the change touches nowhere, or no list declared at all.
- **Full loop** otherwise: `loop: full` (a path matched), any non-zero exit (usage error, a keel too
  old to have the command, git or python3 unavailable, an unreadable profile, nothing staged), or
  keel not installed. Failing to decide is never a reason to review less.

In the light loop: one spec pass. COMPLIES: tick and commit, the note carrying `loop: light`.
DEVIATES: one fix pass, then one spec pass again; a second DEVIATES stops and asks the person with
both verdicts. **Why the fix pass may build on the rejected attempt here**, against the discard
rule's reason: it is scoped to what the verdict names, capped at one round, and a second rejection
goes to a person rather than to another agent. After the fix pass, `plan risk` runs again; if the
fix touched a declared path, the task moves to the full loop and the attempt is discarded.

Should fix and consider findings, in either loop, go to the step 6 report and never start another
round. The tick note carries `rounds: <n>; routing: <profile>; loop: <light|full>`.

The final `review-code` follows the same cap in both loops: a blocking finding gets one fix pass and
one re-review; a second blocking finding goes to the person.

---

### Task 1: `keel plan risk`, and the loop in the report

**Story:** none.
**Files:**
- Modify: `bin/keel`, `tests/test-plan.sh`, `docs/03-install-and-distribution.md`, `CHANGELOG.md`

**Interfaces:**
- Produces: `keel plan risk [--staged | --range <a>..<b> | <path>...]`, default `--staged`. Prints
  each matching path, then a last line `loop: full` or `loop: light`, and exits 0 when it decided.
  Exits 1 on a usage error, 3 when the profile cannot be read or python3 is absent, 4 when nothing
  is staged (or the range is empty), 6 when git cannot be run. And `keel plan report` reads a
  `loop:` note field beside `rounds:` and `routing:`.
- Consumes: the matching rule of `hooks/sensitive-guard` (`matches`, near line 237: a pattern
  matches a path by `fnmatch`, or everything under it as a directory), mirrored, not shared.

**Depends on:** none

**Behaviours, with the examples the tests use.** In temporary repositories with their own
`.keel/profile.json`, run from the root and from a subdirectory.

1. List `["src/payments", "*/auth/*"]`: `keel plan risk src/payments/fee.sh` prints the path, then
   `loop: full`, exit 0. `keel plan risk lib/auth/token.go` likewise.
2. Same list: `keel plan risk docs/readme.md src/ui/form.ts` prints `loop: light`, exit 0.
3. Mixed paths print only the matching one, then `loop: full`.
4. `--staged` uses `git diff --cached --no-renames --name-only -z`, so a rename out of
   `src/payments` (`git mv src/payments/fee.sh docs/fee.sh`, staged) prints the old path and
   `loop: full`. Nothing staged: exit 4, no `loop:` line.
5. `--range a..b` reads the same from `git diff --no-renames --name-only -z a b`; an empty range
   exits 4.
6. No `hard_block_paths` key, or `[]`: prints `no hard_block_paths declared` and `loop: light`, exit
   0, as decided.
7. A profile that is not valid JSON exits 3 naming it; no profile at the repository root is the same
   as no list (behaviour 6). The profile and the paths are both resolved from
   `git rev-parse --show-toplevel`. Outside a git work tree, exit 6.
8. **Parity with the hook.** A test runs the hook's matching rule (extracted from
   `hooks/sensitive-guard` at test time, not copied into the test) and `plan risk` over the same
   patterns and paths, including a directory pattern, a glob and a path with a space, and requires
   the same verdict for each.
9. A usage error (`keel plan risk --stagd`) exits 1 and prints no `loop:` line.
10. `keel plan report` prints `, loop light` or `, loop full` after routing when a task's done-step
    note has `loop: <value>` (same anchoring as `rounds:`), and `--json` carries `loop` or `null`.

**Done when:** `bash tests/test-plan.sh` and `bash tests/test-sensitive-guard.sh` print no FAIL, and
`bin/keel --help | grep 'plan risk'` prints the help line this task adds.

- [x] **Step 1.1: Write the failing cases** for behaviours 1 to 10. Note: cases by a sonnet subagent; 192 after the fix pass
- [x] **Step 1.2: Run them and watch them fail** for the missing subcommand and field. Note: not witnessed by me; reported 97 passed, 53 failed for the missing subcommand and field
- [x] **Step 1.3: Implement** `plan risk` and the `loop:` field, with a help line, then run both Note: implemented by a sonnet subagent; one fix pass closed four fail-open holes the review found, the worst a change editing the profile to lower its own review
  test files until no FAIL and the profile's lint if a shellcheck is available.
- [x] **Step 1.4: Mutation checks.** Each alone must fail a named case: drop the directory rule; Note: not witnessed by me; implementer and reviewer each ran mutations, every one failing a named case
  treat an empty list as `loop: full`; read the working tree instead of the index; drop
  `--no-renames`; print `loop: light` when nothing is staged.
- [x] **Step 1.5: Docs.** `docs/03-install-and-distribution.md`: a `keel plan risk` block after Note: docs and the hook's rename gap as a known gap, by the subagent; the reviewer verified the gap is real
  `keel plan report`, stating that only `loop: light` with exit 0 means the light loop; the report
  block gains `loop:`. `CHANGELOG.md`, Unreleased: one entry, plus a known gap: the hook misses a
  rename out of a declared path.
- [x] **Step 1.6: Check and commit.** `bash tests/test-doc-claims.sh`, Note: rounds: 2; routing: keel-implementer (sonnet, by hand); loop: light; one combined review, COMPLIES; test-plan 192/0 witnessed by me, full suite per the implementer
  `tests/validate-citations.sh`, the full `tests/run-tests.sh`. Stage the four files and this plan.
  Commit: `feat(cli): keel plan risk, which review loop a change gets`.

---

### Task 2: `execute-plan` chooses its loop; FR-11 amended; keel declares its list

**Story:** S-03, amended.
**Files:**
- Modify: `skills/execute-plan/SKILL.md`, `skills/execute-plan/references/subagent-prompts.md`,
  `skills/execute-plan/references/parallel-batches.md`, `docs/prd/coding-standards-enforcement.md`,
  `docs/stories/coding-standards-enforcement.md`, `.keel/profile.json`,
  `templates/profile.schema.json`, `docs/profile-keys.md`, `docs/02-skill-catalog.md`,
  `CHANGELOG.md`

**Interfaces:**
- Consumes: `keel plan risk` and the `loop:` field (task 1).

**Depends on:** task 1

**Behaviours.**

1. **The body sentence.** `SKILL.md` step 3's "Then review in two passes: first does it match the
   task, then is the code sound." becomes one sentence of no more words, saying the passes depend on
   what the task touches and pointing to the references. The body stays at or below 889 words; its
   "two reviewers" mentions stay, true of the full loop.
2. **`subagent-prompts.md` states "The rule"** above in its own section after "Why two review passes
   and not one": the deciding command, that only exit 0 with `loop: light` selects the light loop,
   the light loop's steps and its fix pass with the reason it may build on the attempt, the re-check
   after a fix pass, and the stop-and-ask on a second DEVIATES. "Never re-dispatch on top of the
   rejected attempt" is headed as the full loop's rule, its reason unchanged. The tick-note rule
   gains `loop: <light|full>`. Step 6's report, in this reference, names `review-code` as the light
   loop's quality review, not an optional next step.
3. **Batches.** `parallel-batches.md`: at the join, each task's loop comes from `keel plan risk
   --range` over that task's commits; a light-loop fix pass inside a worktree amends the task's
   commit rather than adding one, so no rejected commit reaches shared history.
4. **FR-11 and S-03.** The requirement and the story say the per-task quality gate applies in the
   full loop; in the light loop the same standards are enforced once per feature by `ship` step 5's
   standards gate through `review-code`. Amended in place with the date and Bernard's decision, the
   ids unchanged.
5. **keel's own list.** `.keel/profile.json` gains `hard_block_paths`: `hooks`, `lib/harness`,
   `settings.json`, `.github/workflows` and `templates/ci-review.yml`, the code that runs on users'
   machines or in CI with their credentials. A commit touching them now asks a person, through
   `hooks/sensitive-guard`; say so in the CHANGELOG entry. `templates/profile.schema.json`'s
   description and `x-keel-read-by` for the key name `keel plan risk` as its second reader, and
   `docs/profile-keys.md` is regenerated as its test requires.
6. **Docs.** `docs/02-skill-catalog.md`'s "two-stage review" sentence names both loops;
   `CHANGELOG.md` carries the entry and the owed eval arm for the `execute-plan` body edit: the arm
   it last ran is `done-without-verifying`, and no scenario exercises the review loop, so the arm is
   owed, not claimed.

**Done when:** `tests/validate-skills.sh` 0 FAIL with `execute-plan` at or below 889 words;
`bash tests/test-doc-claims.sh`, `tests/validate-citations.sh` and the profile-keys test pass; a
reviewer finds behaviours 1 to 6 stated, and that a coordinator following the text would pick the
loop from `keel plan risk` alone.

- [x] **Step 2.1: Edit the body sentence and the two references** for behaviours 1 to 3. Note: by a sonnet subagent; the rule section sits just before Running the loop, not right after Why two passes, to keep cited lines in place
- [x] **Step 2.2: Run `tests/validate-skills.sh`** and read the `execute-plan` count. Note: execute-plan 887 words, per validate-skills witnessed by me
- [x] **Step 2.3: FR-11, S-03, the profile list, the schema and the generated keys** for behaviours Note: FR-11, S-03, E-02 amended; keel's list plus lib/context_watch.py after the quality review; profile-keys regenerated
  4 and 5.
- [x] **Step 2.4: Docs and the owed arm** for behaviour 6. Note: docs and the owed execute-plan arm in CHANGELOG
- [x] **Step 2.5: Check and commit.** The `Done when:` checks and the full `tests/run-tests.sh`. Note: rounds: 3; routing: keel-implementer (sonnet, by hand); loop: full; spec DEVIATES on two sentences, fixed on top by Bernard's named acceptance instead of a discard; quality pass nothing blocking, its should-fix items in one more text pass; one inline-mode sentence I had briefed wrongly corrected by me; full run-tests.sh witnessed by me, all passed
  Stage the ten files and this plan. Commit: `feat(skills): execute-plan reviews in proportion to
  what a task touches`. The commit touches `.keel/profile.json` but no declared path, so the guard
  does not ask; if it does, a person answers.

---

### Task 3: the final review's cap, and the record

**Story:** none.
**Files:**
- Modify: `skills/review-code/SKILL.md`, `skills/ship/SKILL.md`, `docs/ideas/delivery-flow-gaps.md`,
  `docs/ideas/proportional-ceremony.md`, `CHANGELOG.md`

**Depends on:** task 2

**Behaviours.**

1. **`review-code` step 5** gains the cap: when the author's fix for a blocking finding comes back,
   re-review once; a second blocking finding on the same feature goes to the person, with both
   reports, rather than to another round. One or two sentences, inside the body's budget.
2. **`ship` step 5** reads "nothing blocking remains" as including that cap: a blocking finding the
   person has accepted by name passes, as an accepted override already does. One sentence or none,
   if the existing override wording already covers it; say which.
3. **The records.** `docs/ideas/delivery-flow-gaps.md`: Status names gap 5 built with its commits,
   Next names gap 1. `docs/ideas/proportional-ceremony.md`: Status closed, its part 2 built by this
   plan. `CHANGELOG.md`: the entry and any owed arm for `review-code` and `ship`.

**Done when:** `tests/validate-skills.sh` 0 FAIL, `bash tests/test-doc-claims.sh` and
`tests/validate-citations.sh` pass, and a reviewer finds behaviours 1 to 3 stated.

- [x] **Step 3.1: Edit `review-code` and `ship`** for behaviours 1 and 2. Note: review-code step 5 gains the cap; ship unchanged, its Overrides already cover a blocking finding accepted by name, which the reviewer confirmed
- [x] **Step 3.2: Run `tests/validate-skills.sh`** and read both counts. Note: review-code 530 to 562 words, under 700, so no arm is owed; ship unchanged at 790
- [x] **Step 3.3: The records and the CHANGELOG** for behaviour 3. Note: records updated; one wording fix by me in proportional-ceremony.md from the reviewer's optional note
- [x] **Step 3.4: Check and commit.** The `Done when:` checks and the full `tests/run-tests.sh`. Note: rounds: 1; routing: keel-implementer (sonnet, by hand); loop: light; one spec pass, COMPLIES; quality review is the feature's review-code; full run-tests.sh witnessed by me, all passed
  Stage the five files and this plan. Commit: `feat(skills): the final review stops after one fix
  pass`.

---

## What the review changed

A plan reviewer read the first draft on 2026-10-16 against the codebase. Applied:

- **Blocking: exit 1 selected the light loop and is also what every keel failure returns.** The
  light loop now needs exit 0 with `loop: light`; everything else, a missing or old keel included,
  is the full loop.
- **Blocking: a repository with no list got the full loop, which was not decided.** Put to Bernard:
  no list means the light loop, and keel declares its own list (task 2).
- The light loop's fix pass now says why it may build on the attempt, and re-checks the loop after.
- The final `review-code` cap, half of decision 4, is built (task 3), as Bernard chose.
- FR-11 and S-03 are amended, not silently bypassed, as Bernard chose.
- The hook is mirrored with a parity test, not shared; `plan risk` reads renames both ways; batches
  use `--range`; a worktree fix pass amends; `keel plan report` shows the loop; the schema, the
  generated keys and `proportional-ceremony.md` are in the file lists; the profile is found from the
  repository root; the owed arm names the scenario that actually loaded `execute-plan`.
