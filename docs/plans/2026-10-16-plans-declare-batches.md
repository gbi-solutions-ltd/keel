# Plans declare every batch the tasks allow Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> Task 1 is test-first under `keel:tdd`. Tasks 2 to 4 change skill text and docs and carry no
> failing test; each behaviour's example is the wording it must produce, checked by the commands in
> `Done when:` and by a reviewer.

**Goal:** independent tasks overlap by default. A new command, `keel plan batches`, reads a plan's
`Depends on:` and `Files` lines and prints the batches its tasks allow; `write-plan` declares every
batch it prints, so the approver sees the overlap in the plan they approve. Shared records
(`CHANGELOG.md`, `README.md`, the catalog) move out of batched tasks into a records task at the
batch's join, which is what has kept every keel plan at "Concurrent batches: none". `ship` and
`setup-deployment` name feature flags as the way to merge unfinished work dark.
**Stories:** none. A change to keel's own process, specified by a decided idea record.
**ADRs:** none written, none contradicted. ADR-0002 (the coordinator writes no code) holds,
including at a join; ADR-0001 governs the body edits. `parallel-batches.md`'s rule that nothing
licenses a batch the plan did not declare stays: the command proposes, the plan declares, the
approver approves.
**Architecture:** `keel plan batches <plan> [--json]` beside `plan status`, `report` and `risk`
in `bin/keel`, reading the plan with the same fence-aware awk library. It checks the three batch
conditions a command can read (2: dependencies; 3: no shared path; 5: no shared config) and prints
the two it cannot (4: each `Done when:` names only the task's own test; and the final step
commits) as a reminder. `write-plan` runs it once the tasks are written. `execute-plan` runs it to
check a declared batch, and a declared batch it does not print is withdrawn as today.
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Concurrent batches:** tasks 1 and 2 may run at the same time. Task 3 requires both. Task 4
requires tasks 1 and 3.
**Batch gate:** after tasks 1 and 2 land, `tests/run-tests.sh` is green.
**Decided:** Bernard, 2026-10-16, choosing among options put to him, recorded as "Decided" item 6 by
task 4: plans declare batches by default (not a runtime pipeline in `execute-plan`); feature flags
go into references, with one line in `ship`; a batch's shared records go in a records task after
the batch, and `docs/standards.md`'s "same commit" rule becomes "same pull request, and for a batch
the records task at its join"; this plan runs tasks 1 and 2 as a real batch.
**Shape:** behaviours with examples, as gap 1 decided.
**Reviewed:** by a dispatched plan reviewer on 2026-10-16; "What the review changed" records it.

## Global constraints

Copied from `.keel/profile.json` and `docs/standards.md`. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint as `.keel/profile.json`
  spells it (read it there; do not retype it from here). If `command -v shellcheck` prints nothing,
  say the lint was not run and that CI will run it.
- **`tests/run-tests.sh` takes about 2m30s.** Run it in the background and read its log to the end
  within one tool call.
- **Tasks 1 and 2 run in their own git worktrees and commit there**; their `Done when:` is their
  own checks, and the suite runs once at the join (the batch gate). Tasks 3 and 4 run in the shared
  tree, stage named paths and hand over; the coordinator commits.
- **Precondition: the working tree is clean and nothing is staged.** Each commit stages named paths
  only, checked with `git diff --cached --name-only`. Never `git add -A`, `git add .` or
  `git commit -a`.
- Never start on `main`.
- No em dashes and no en dashes, in any file or commit message. Prose wraps at 100 columns; table
  rows and code blocks do not.
- **Records.** Tasks 1 and 2 do not touch `CHANGELOG.md`, `README.md` or
  `docs/02-skill-catalog.md`; task 3 writes their records, by the **Decided:** line, before task 4
  changes the standard that says so. A reviewer of task 1 or 2 is told this, so a missing changelog
  entry there is not a finding.
- **Worktrees** for tasks 1 and 2 go outside the repository (for example under `$HOME/tmp/`),
  because `.gitignore` ignores almost nothing and a worktree inside the tree would show in every
  `git status`.
- Commits carry no attribution footers; this repository sets `conventions.no_attribution_footers`.
- No vendor model alias under `skills/`.
- **Skill bodies.** `write-plan` is at 899 words and `ship` at 844; each stays at or below 900. A
  body edit to one over 700 words owes an ADR-0001 eval arm, recorded as owed in `CHANGELOG.md`.
- **Line citations.** Cite by phrase (`file#phrase`), not by line number, in anything this plan
  writes. Validators check line citations even in record directories, for range and blank lines,
  so after each edit run `tests/validate-citations.sh`, and keep live cited lines on their text or
  repoint them to a phrase. `docs/02-skill-catalog.md` keeps its 627 lines.
- **Plans are scanned for links.** Write paths in backticks, never as markdown links, in this plan.
- **Every comment and rule carries its reason**, as `bin/keel`'s comments do.
- Never `sed -i` on this repository's mount: it drops the exec bit. Edit with a read-modify-write.

## What this plan does not build

- **No runtime pipeline.** `execute-plan` does not start an undeclared task while another is in
  review; overlap is decided in the plan, where the approver sees it.
- **No change to the five conditions** or to how a batch runs, joins and is reviewed
  (`skills/execute-plan/references/parallel-batches.md`), beyond checking a declaration with the
  command.
- **No reading of `Done when:` text.** Whether a `Done when:` names only the task's own test is
  printed as a reminder, not checked.
- **No flag tooling.** Flags are named as a practice in references; no skill installs or wires a
  flag service.
- **No measurement of overlap.** `keel plan report` does not show which tasks ran concurrently.

---

### Task 1: `keel plan batches`

**Story:** none.
**Files:**
- Modify: `bin/keel`, `tests/test-plan.sh`, `docs/03-install-and-distribution.md`

**Interfaces:**
- Produces: `keel plan batches <plan> [--json]`. Text output, one line per scheduling step in plan
  order, then `why:` lines, then one `check:` line:
  ```
  batch: 1 2
  alone: 3
  alone: 4
  why: task 3 depends on task 1 and task 2
  why: task 4 depends on task 3
  check: in each batch, every Done when names only its task's own test, and each last step commits
  ```
  (Task 4 depends on tasks 1 and 3; its `why:` names only the dependency in the step before it.)
  `--json` prints `{"steps": [{"batch": ["1", "2"]}, {"alone": "3"}], "why": [{"task": "3",
  "reason": "..."}], "check": "..."}`. Exit 0 when it printed; 1 on a usage error or a missing
  plan; 3 when the plan has no `### Task` headings.

**Depends on:** none

**Behaviours:**

1. **Tasks are read in plan order** from `### Task <id>: ...` headings outside fenced blocks. An id
   is digits then any letters (`1`, `1b`, `2A`, `6a`), compared case-insensitively. A task's section
   ends at the next `### Task` heading or the next `## ` heading, so a section after the last task
   is not read into it.
   - **`**Depends on:**`**, read from the label's own line only: starting with `none` (any text may
     follow) is none. Otherwise its ids are the id tokens that follow the word `task` or `tasks`,
     continuing through `,`, `and` and `to`, and stopping at any other word; `to` expands to every
     task between the two, in plan order. Examples: `tasks 1 and 2` gives 1, 2; `tasks 1 to 3` gives
     1, 2, 3; `tasks 1, 2, 3.` gives 1, 2, 3; `task 1, with row 3 of its results` gives 1;
     `task 0, task 4` gives 0, 4.
   - **`**Files:**`**: the label's own line, then the following lines up to a blank line or a line
     opening with `**`. Its paths are every backticked token in it; a block with no backticked
     token counts as no Files block. Over-reading a backticked command as a path is accepted,
     because it can only stop a batch, never start a wrong one.
2. **Scheduling keeps plan order.** Walking the tasks in order, a task joins the current batch when
   its dependencies have all landed before the batch began, it shares no path with a task already
   in the batch, and it is batchable; otherwise the current batch is closed (printed as `batch:`
   when it holds two or more tasks, else `alone:`) and the task starts the next one, or runs alone.
   No task is ever scheduled before a task above it. Each task that could not join the step before
   it gets one `why:` line, after the steps; a dependency reason names only the dependencies in that
   step. Example: tasks 1 and 2 `none` with disjoint files, task 3 depending on both, task 4 on
   tasks 1 and 3, print `batch: 1 2`, `alone: 3`, `alone: 4`, then
   `why: task 3 depends on task 1 and task 2` and `why: task 4 depends on task 3`.
3. **A shared path splits a batch, and says which.** Tasks 1 and 2 both `none`, both naming
   `CHANGELOG.md`, print `alone: 1`, `alone: 2` and `why: task 2 shares CHANGELOG.md with task 1`.
4. **Unbatchable tasks run alone, each with its reason:** no `**Depends on:**` line (`why: task 2
   has no Depends on line, so its order is unknown`); a line that is not `none` and names no task id
   it can read (`why: task 2 has a Depends on line naming no task, so its order is unknown`),
   because reading it as none would batch a task whose dependency was merely written another way; a
   dependency on a task the plan does not have, or on one below it (`why: task 2 depends on task 9,
   which this plan does not have above it`); no `**Files:**` block; a path that is a directory or a
   pattern, ending in `/` or holding `*`, `?` or `[` (`why: task 2 names a directory or pattern,
   skills/x/, so its paths are unknown`), because `skills/x/` and `skills/x/a.md` compare as
   different strings and would let two overlapping tasks into one batch; and a path that is shared
   config. Shared config is a lockfile or dependency manifest (`package-lock.json`,
   `pnpm-lock.yaml`, `yarn.lock`, `package.json`, `Cargo.lock`, `Cargo.toml`, `go.mod`, `go.sum`,
   `poetry.lock`, `uv.lock`, `pyproject.toml`, `requirements*.txt`, `Gemfile`, `Gemfile.lock`,
   `composer.json`, `composer.lock`, `pubspec.yaml`, `pubspec.lock`), a lint, format or type config
   (`.eslintrc*`, `eslint.config.*`, `.prettierrc*`, `prettier.config.*`, `biome.json`, `ruff.toml`,
   `.ruff.toml`, `.editorconfig`, `.golangci.*`, `rustfmt.toml`, `.rubocop.yml`, `tsconfig*.json`),
   a CI file (anything under `.github/workflows/` or `.circleci/`, `.gitlab-ci.yml`, `Jenkinsfile`,
   `azure-pipelines.yml`, `bitbucket-pipelines.yml`), or `.keel/profile.json`, matched by basename
   or path as listed (`why: task 2 edits shared config package-lock.json`), because two agents each
   editing one of these produce two versions of it.
5. **The `check:` line is always printed**, because condition 4 and the commit step are text the
   command cannot judge. A plan with one task prints `alone: 1` and the `check:` line.
6. **`--json`** carries the same steps, reasons and `check`; `python3` is not needed to produce it.
7. **Errors:** no argument, an unknown option or two plans exit 1 with
   `usage: keel plan batches <plan> [--json]`; a missing file exits 1 naming it; a plan with no
   `### Task` heading exits 3 saying so.
8. **Documented:** `cmd_plan`'s unknown-subcommand message names `batches`; `keel --help` gains a
   `plan batches <plan> [--json]` line after `plan risk`'s (`bin/keel`'s header comment, which lists
   only init, doctor and version, is unchanged); `tests/test-plan.sh`'s header comment names
   `batches`; `docs/03-install-and-distribution.md` gains a `keel plan batches <plan> [--json]`
   section beside `plan risk`'s, saying what it reads, the scheduling rule, the shared-config and
   directory reasons, and the exit codes.

**Done when:** all of these, in this task's worktree:
- The new cases in `tests/test-plan.sh` were watched to fail before the code, and pass now:
  `bash tests/test-plan.sh` passes.
- `bin/keel plan batches docs/plans/2026-10-16-plans-declare-batches.md` prints `batch: 1 2` first.
- Run against every plan in `docs/plans/`, it exits 0 or 3 for each, with no shell error.
- `bash tests/test-doc-claims.sh` and `tests/validate-citations.sh` pass.
- The profile's lint on `bin/keel` and `tests/test-plan.sh`, or "shellcheck absent" said.

- [x] **Step 1.1: Write the failing cases** for behaviours 1 to 7 in `tests/test-plan.sh`, and
  watch them fail for the missing command.
- [x] **Step 1.2: Make them pass** in `bin/keel`.
- [x] **Step 1.3: Document it** (behaviour 8).
- [x] **Step 1.4: Check and commit.** You are in your own worktree, so this task commits rather than Note: rounds: 3; routing: keel-implementer (sonnet, by hand); loop: light; batch with task 2 in worktree g6-t1; spec DEVIATES (no why after a lone task), one fix pass that also took the coordinator's tightening of behaviour 4 (an unreadable Depends on line runs alone), second spec DEVIATES on one 101-column line, Bernard approved a third pass to rewrap; committed 807fceb in the worktree; the implementer used git stash once against its rules, tree verified clean
  handing over. Run the `Done when:` checks, then:
  ```bash
  git add bin/keel tests/test-plan.sh docs/03-install-and-distribution.md
  git commit -m "feat(plan): keel plan batches prints the batches a plan's tasks allow"
  ```

---

### Task 2: feature flags as the way to merge unfinished work dark

**Story:** none.
**Files:**
- Modify: `skills/setup-deployment/references/release-operations.md`, `skills/ship/SKILL.md`

**Depends on:** none

**Behaviours:**

1. **`release-operations.md` gains a section**, "Merging unfinished work dark" or close, saying:
   deploying and releasing are separate acts; work that is merged before it is finished ships
   behind a flag that is off in production; the flag is named, has an owner, and has a removal
   date or condition, because a flag nobody owns stays forever; turning it on is the release and is
   recorded like a deploy; turning it off is a rollback that needs no deploy, the second lever
   `skills/incident-response/SKILL.md` names after rolling back the deploy. Example wording: "A flag
   with no owner and no removal condition is not a release mechanism, it is a second configuration
   nobody reviews." The file's first paragraph, which lists "Three moments either side of the
   pipeline", is unchanged: the section is about how work reaches production, not a fourth moment.
2. **`ship`'s PR body** ("The PR body states: ...") gains: when the change is behind a flag, the
   body names the flag, its default in each environment, and who turns it on. At most 30 words;
   `ship` stays at or below 900.

**Done when:** all of these, in this task's worktree:
- `tests/validate-skills.sh` prints `OK`, with `ship` at or below 900 words.
- `tests/validate-citations.sh` passes.
- `grep -ci 'flag' skills/ship/SKILL.md` prints at least 1.
- A reviewer finds behaviours 1 and 2.

- [x] **Step 2.1: Write the section** for behaviour 1.
- [x] **Step 2.2: Edit `ship`** for behaviour 2.
- [x] **Step 2.3: Check and commit.** You are in your own worktree, so this task commits rather than Note: rounds: 1; routing: keel-implementer (sonnet, by hand); loop: light; batch with task 1 in worktree g6-t2; spec COMPLIES; committed fda63ab; batch joined by merges a3d49b2 and 8ed7430, and run-tests.sh at the join witnessed by me, all passed
  handing over. Run the `Done when:` checks, then:
  ```bash
  git add skills/setup-deployment/references/release-operations.md skills/ship/SKILL.md
  git commit -m "docs(skills): feature flags merge unfinished work dark"
  ```

---

### Task 3: the batch's records

**Story:** none.
**Files:**
- Modify: `CHANGELOG.md`

**Depends on:** tasks 1 and 2

**Behaviours:**

1. **`CHANGELOG.md`:** one Unreleased entry for `keel plan batches` (what it reads, the scheduling
   rule, its exit codes) and one for the feature-flag guidance, with the owed ADR-0001 arm for the
   `ship` body edit and its word counts. `README.md` lists no `keel plan` subcommand, so it is not
   touched.

**Done when:**
- `bash tests/test-doc-claims.sh` and `tests/validate-citations.sh` pass.
- A reviewer finds behaviour 1.

- [x] **Step 3.1: Write the records** for behaviour 1.
- [x] **Step 3.2: Check and stage.** Run the `Done when:` checks, stage the changed files by path, Note: rounds: 1; routing: keel-implementer (sonnet, by hand); loop: light; spec COMPLIES, two wording notes left for review-code; records for the batch written at its join; doc-claims and citations checked by implementer and reviewer, no suite run for a CHANGELOG-only change
  show `git status --porcelain`, and stop. The coordinator commits, with this plan:
  `docs: records for keel plan batches and feature flags`.

---

### Task 4: `write-plan` declares what the command prints

**Story:** none.
**Files:**
- Modify: `skills/write-plan/SKILL.md`, `skills/write-plan/references/plan-template.md`,
  `skills/execute-plan/references/parallel-batches.md`, `skills/review-code/references/rubric.md`,
  `docs/standards.md`, `CONTRIBUTING.md`, `docs/02-skill-catalog.md`,
  `docs/ideas/delivery-flow-gaps.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: `keel plan batches <plan>` and its output, from task 1.

**Depends on:** tasks 1 and 3

**Behaviours:**

1. **`write-plan`** replaces "Where tasks depend on nothing outstanding and no two name the same
   file, declare a concurrent batch in the header. The template states the three further conditions
   a batch must also meet." with a sentence of no more words saying: run `keel plan batches` once
   the tasks are written and declare every batch it prints, because the approver can only approve
   overlap they can see. The body stays at or below 900 words (899 now).
2. **The template's "Tasks that run concurrently"** gives the order of work:
   - write the tasks with shared records (`CHANGELOG.md`, `README.md`, the skill catalog) left out
     of any task that could run beside another, and a records task after them that depends on them,
     because every task writing the same record is what makes no two tasks disjoint (this plan's
     task 3 is the example);
   - run `keel plan batches <plan>`;
   - declare in `**Concurrent batches:**` every batch it prints, unless a task in it cannot meet
     rules 1 and 2, in which case say which; or `none` followed by its `why:` lines. A batch it
     does not print is not declared; a declared batch may be part of a printed one;
   - for each declared batch, scope each task's `Done when:` (rule 1), make its last step a commit
     (rule 2), and add the `**Batch gate:**` line.
   The records rule becomes rule 4 beside the existing three, and "Where any of the three cannot
   hold" becomes four.
3. **`parallel-batches.md`'s eligibility** says the coordinator runs `keel plan batches <plan>`
   and every task of a declared batch must sit in one batch it prints (a declared batch may be part
   of a printed one), which settles conditions 2, 3 and 5; condition 1 is the declaration and 4 is
   read in the task text. A declared batch it does not print is withdrawn, as "When not to batch"
   already says.
4. **`docs/standards.md`**, "Documentation lands with the change, not after": the rule becomes, in
   substance, that a change is not done until `README.md`, `CHANGELOG.md` and the plan are updated
   in the same pull request, by the same commit for a task run on its own and by the records task
   at the join for a batch; the why keeps the status-line example. The example line becomes:
   "**Example:** `docs/plans/2026-10-16-plans-declare-batches.md` batched tasks 1 and 2 and wrote
   their records in task 3." `CONTRIBUTING.md`'s "Documentation lands in the same commit" says the
   same, and `skills/review-code/references/rubric.md` section 8's "updated in the same commit"
   becomes "in the same pull request", because every project's review applies that rubric and a
   batched task now leaves its records to the records task. `skills/create-skill/SKILL.md` and
   `skills/write-docs/SKILL.md` describe a task run on its own, which the rule keeps, and are not
   touched.
5. **Catalog:** the `write-plan` entry says the plan declares the batches `keel plan batches`
   prints, its "when the template's five conditions hold" is brought into line, and the file keeps
   627 lines.
6. **Records:** `docs/ideas/delivery-flow-gaps.md`:
   - Status names gap 6 built by this plan, with the commits of tasks 1 to 3 and task 4's title;
   - Next names gap 3, "risk depth is half there", the last in the decided order;
   - the gap 6 section gets "**Built 2026-10-16**, see Status. What follows is the state before it
     was built.";
   - "Decided" gains item 6 with Bernard's three answers.
   `CHANGELOG.md`: an entry for this task, with the owed eval arm for the `write-plan` body edit.

**Done when:** all of these:
- `tests/validate-skills.sh` prints `OK`, with `write-plan` at or below 900 words.
- `bash tests/test-doc-claims.sh`, `tests/validate-citations.sh` and
  `bash tests/test-harness-claims.sh` pass.
- `grep -c 'same commit' skills/review-code/references/rubric.md` prints 0.
- `grep -c 'plan batches' skills/write-plan/SKILL.md` and the same in
  `skills/write-plan/references/plan-template.md` and
  `skills/execute-plan/references/parallel-batches.md` each print at least 1.
- `wc -l < docs/02-skill-catalog.md` prints 627.
- A reviewer finds behaviours 1 to 6.

- [x] **Step 4.1: `write-plan`, the template and `parallel-batches.md`** for behaviours 1 to 3.
- [x] **Step 4.2: The standard, the catalog and the records** for behaviours 4 to 6.
- [x] **Step 4.3: Check and stage.** The `Done when:` checks and the full `tests/run-tests.sh`. Note: rounds: 3; routing: keel-implementer (sonnet, by hand); loop: light; spec DEVIATES (template misdescribed the why lines), one fix pass that also gave a parallel-batches sentence its reason and restored the rubric cache bullet's meaning, second spec DEVIATES on one stale CHANGELOG phrase, Bernard approved a third pass; full run-tests.sh witnessed by me, all passed
  Stage every file named under **Files:** that changed, by path, show `git status --porcelain`, and
  stop. The coordinator ticks and commits, with this plan:
  `feat(skills): plans declare every batch keel plan batches prints`.


---

### Task 5: only a strictly written task can join a batch

**Story:** none.
**Files:**
- Modify: `bin/keel`, `tests/test-plan.sh`, `docs/03-install-and-distribution.md`,
  `skills/write-plan/references/plan-template.md`, `CHANGELOG.md`

**Decided:** Bernard, 2026-10-17, after three review rounds each found another free-text spelling
that `keel plan batches` misread into an unsafe batch: flip the rule, so a task can join a batch
only when its `Depends on:` and `Files` lines fully match a strict form, and anything else runs
alone with a `why:` line. A mistake then costs overlap, never safety, and `write-plan` writes these
lines itself, so the template can require the form.

**Depends on:** tasks 1 and 4

**Behaviours:**

1. **A strict `Depends on:` line**, read from the label's own line, after the label and with
   surrounding spaces and one trailing `.` removed, is exactly one of: `none`; `task <id>`;
   `tasks <id> and <id>`; `tasks <id>, <id> and <id>` (any number before `and`, an optional comma
   before `and`); or `tasks <id> to <id>`. `task`/`tasks` match in any case; an id is digits then
   any letters. Anything else, including `none` followed by more text, makes the task run alone with
   `why: task 3 has a Depends on line not in the strict form, so its order is unknown`. Examples:
   `tasks 1, 2 and 3` gives 1, 2, 3; `tasks 1 to 3` gives 1, 2, 3; `tasks 1 (schema) and 2 (API)`,
   `tasks 1-2`, `task 1 and task two`, `none (needs task 2's table)` and `task 1, with row 3 of its
   results` each run alone.
2. **A strict `Files:` block** runs from the label to the next blank line, `**Label:**` line or
   section end, and every line in it is one of: the label line with nothing after it; a list item
   `- <Word>: ` (`Create`, `Modify`, `Delete`, `Test` or `Rename`, optionally with a parenthesised
   note before the colon, as in `- Create (if the body cannot hold the detail): `) followed by one
   or more backticked paths separated by `, ` and an optional final `and`; or an indented
   continuation line of backticked paths and the same separators. A path is one token of letters,
   digits and `._-/@+`, not starting with `/`, holding no `//`, `/./` or `/../`, and not ending in
   `/`. Anything else in the block (prose, a parenthesised note after a path, a Markdown link, a
   path outside backticks, a space, `:`, `#`, `\`, `{`, `*`, `?` or `[` inside a path) makes the
   task run alone with `why: task 2 has a Files block not in the strict form, so its paths are
   unknown`. A list item after a blank line but before the next `**Label:**` line also makes it run
   alone, because the block it belongs to is ambiguous.
3. **Paths compare case-insensitively**, because on a case-insensitive file system `App.tsx` and
   `app.tsx` are one file, and merging two paths can only stop a batch.
4. **What stays:** the scheduling rule, plan order, the directory/pattern and shared-config rules
   (a strict path can still be shared config), the `check:` line, `--json` and the exit codes. The
   free-text heuristics added by the review's fix passes (unknown separators read as ranges, cutting
   paths at `:` or a space, dropping `#...` and `./`) are removed, since the strict form makes them
   unnecessary; their tests now expect the task to run alone.
5. **Docs:** `plan_batches`' header comment and docs/03's `plan batches` section state the strict
   form, its reason, and drop the known limits it closes. The template's "Why the Depends on line
   exists" and "Tasks that run concurrently" give the strict form with one example of each line,
   and say a task written another way still runs, alone. `CHANGELOG.md`: an entry for this task.
6. **Real plans:** run against every plan in `docs/plans/` with the previous binary and this one;
   every schedule that changes must only lose batches, never gain one, and this plan still prints
   `batch: 1 2` first.
7. **Added in review, each approved by Bernard on 2026-10-17,** because each let an unsafe batch
   through plan structure rather than line spelling. Every task runs alone, with one plan-wide
   `why:` naming the line, for: a line that opens like a task heading but is not `### Task <id>:`
   (any case, up to three leading spaces, a blockquote, a tab after the `#`s); a step id whose task
   has no heading; a Files-like label or action list item outside any task; and a fence that never
   closes. A task runs alone for a duplicate id (or a dependency on one), a range reaching a task
   below it, a second Files-like label or an action item outside its block, or a continuation line
   after its block. The shared fence reader follows CommonMark's indentation rules, which `plan
   status`, `tick` and `report` also use; the template's own nested-fence example is corrected.

**Done when:** all of these:
- The new and changed cases in `tests/test-plan.sh` were watched to fail before the code, and pass
  now: `bash tests/test-plan.sh` passes.
- `bin/keel plan batches docs/plans/2026-10-16-plans-declare-batches.md` prints `batch: 1 2` first.
- `bash tests/test-doc-claims.sh` and `tests/validate-citations.sh` pass.
- A reviewer finds behaviours 1 to 6, and cannot produce an unsafe batch from a plan in the
  template's form; any structure the reader cannot place runs every task alone, and edge cases that
  remain are listed as known limits in docs/03. (Bernard, 2026-10-17, after two adversarial spec
  passes: a line-by-line reader cannot be complete against every piece of Markdown, so the bar is
  the template's form plus failing closed, not every possible plan.)

- [x] **Step 5.1: Write the failing cases** for behaviours 1 to 4, and change the existing cases
  behaviour 4 names; watch them fail.
- [x] **Step 5.2: Make them pass** in `bin/keel`.
- [x] **Step 5.3: Docs, template and record** for behaviours 5 and 6.
- [x] **Step 5.4: Check and stage.** The `Done when:` checks and the full `tests/run-tests.sh`. Note: rounds: 5; routing: keel-implementer (sonnet, by hand); loop: light; three adversarial spec passes, each DEVIATES on plan structure (duplicate ids, unread headings, ranges out of number order; then nested fences, second Files labels, continuations, hidden headings; then the template's own malformed fence example, list-item fences, quoted Files labels, Files lines outside a task), each fix pass approved by Bernard, who reset the bar after the second; my own check of the reviewer plans found a tab-after-# heading, fixed in the same pass; shared fence reader now follows CommonMark, plan status unchanged on all 44 real plans; full run-tests.sh witnessed by me, all passed
  Stage the changed files by path, show `git status --porcelain`, and stop. The coordinator ticks
  and commits, with this plan: `feat(plan): only a strictly written task can join a batch`.

---

## What the review changed

A plan reviewer read the first draft on 2026-10-16. Applied: task 2 no longer claims
`incident-response` turns a flag off first (it rolls the deploy back first; the flag is the second
lever); a directory or pattern in a Files block makes its task unbatchable, since a literal compare
would batch overlapping tasks; the `Depends on:` grammar (`to` ranges, stopping words, the label's
own line), the Files block's start and end, mixed-case ids, task section ends, when `why:` lines
appear and what `--json` carries are stated, checked against real plans; `keel --help`, not the
header comment, gains the line; the README is out of task 3, since it lists no `plan` subcommand;
the template's order of work puts records out of batched tasks before the command runs, and allows
a declared batch to be part of a printed one; `review-code`'s rubric moves to "same pull request";
the standard's example is given; task 1 carries lint and a run over every real plan; and worktrees
go outside the tree. Noted, not changed: ADR-0002 item 4 says a violating batch is stopped, while
`parallel-batches.md` withdraws the declaration and carries on; this plan keeps the latter, which is
what runs today.
