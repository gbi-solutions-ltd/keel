# Small work runs from an approved behaviour list to a pull request Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> Every task changes skill text and docs and carries no failing test; each behaviour's example is
> the wording or outcome it must produce, checked by the commands in `Done when:` and by a reviewer.

**Goal:** "implement X" for small work no longer waits at six hand-offs or needs a PRD. The person
approves a behaviour list once, in one question that also chooses delivery, and keel writes it as a
one-task plan and runs it through `execute-plan`'s existing delivery: build under `tdd`, the review
loop, `review-code` and `ship`, to an open pull request. The long chain stays for work that needs a
PRD, and for anything big or sensitive.
**Stories:** none. A change to keel's own process, specified by a decided idea record.
**ADRs:** none written, none contradicted. ADR-0002 holds (the coordinator writes no code, and the
short path's plan forbids inline mode); ADR-0001 governs the body edits; ADR-0006 holds (the `tdd`
cycle is unchanged); ADR-0007 stays rejected (small work keeps the full cycle).
**Architecture:** no new skill (CONTRIBUTING.md: "No new skill, improve the existing one"). The
router sends "implement X" to `write-plan`'s short path, a new reference
`skills/write-plan/references/short-path.md`, because `write-plan` already writes plans and asks
the approval question, and its body has one word left under ADR-0001's ceiling. The short path
writes the same plan shape the template defines, with one task, so `execute-plan`, its delivery
reference, `keel plan risk`, `keel plan status` and `keel plan report` all work on it unchanged.
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Concurrent batches:** none. Task 2 depends on task 1, and both write records.
**Decided:** Bernard, 2026-10-17, choosing among options put to him: the record is a one-task plan
written for the person, run by `execute-plan`'s delivery; the short path takes at most 5
behaviours and no `hard_block_paths` change, decided by `keel plan risk` on the files it names,
and offers `write-plan`'s full form otherwise, with the reason; approval asks each time, with
delivery to a pull request as the first option and hand-off as the other. After the plan review:
on the default branch the approval question names a new branch and the short path creates it,
that answer being the consent; and `write-plan`'s description claims small changes while `tdd`'s
defers them to the short path, so sessions that pick by description reach it.
**Shape:** behaviours with examples, as gap 1 decided.
**Reviewed:** by a dispatched plan reviewer on 2026-10-17; "What the review changed" records it.

## Global constraints

Copied from `.keel/profile.json` and `docs/standards.md`. Every task inherits these.

- Verify commands: test `tests/run-tests.sh`, one test `tests/{name}`, lint as `.keel/profile.json`
  spells it (read it there; do not retype it from here). shellcheck may be at
  `$HOME/.local/bin/shellcheck`; if `command -v shellcheck` prints nothing, say the lint was not
  run and that CI will run it.
- **`tests/run-tests.sh` takes about 2m30s without the lint.** Run it in the background and read
  its log to the end within one tool call.
- **Precondition: the working tree is clean and nothing is staged.** Each commit stages named paths
  only. Never `git add -A`, `git add .` or `git commit -a`.
- This work is on branch `short-path`, off `sandbox`, for its own pull request. Never start on
  `main`.
- No em dashes and no en dashes, in any file or commit message. Prose wraps at 100 columns; table
  rows and code blocks do not.
- Every task carries its own records (`CHANGELOG.md`, the catalog), since none runs in a batch.
- Commits carry no attribution footers; this repository sets `conventions.no_attribution_footers`.
- No vendor model alias under `skills/`.
- **Skill bodies.** `write-plan` is at 899 words and `keel` at 594; each stays at or below 900 as
  `tests/validate-skills.sh` counts it. A body edit to one over 700 words owes an ADR-0001 eval arm,
  recorded as owed in `CHANGELOG.md`.
- **Line citations.** Cite by phrase (`file#phrase`), not by line number. Validators check line
  citations even in record directories, so run `tests/validate-citations.sh` after each edit and
  keep cited lines on their text, or repoint live citations by phrase. `docs/02-skill-catalog.md`
  keeps its 627 lines.
- **Plans are scanned for links.** Write paths in backticks, never as markdown links, in this plan.
- **Every rule carries its reason.**
- Never `sed -i` on this repository's mount: it drops the exec bit. Edit with a read-modify-write.

## What this plan does not build

- **No change to the bodies of `tdd`, `execute-plan`, `review-code` or `ship`.** The short path
  produces a plan they already run; only `tdd`'s frontmatter description changes (task 2). If a
  task finds one of them refuses a one-task plan, it stops and reports.
- **No short path for bug fixes.** "fix bug Z" still routes to `debug`, which ends without a pull
  request; joining `debug` to delivery is a separate change.
- **No plan reviewer on the short path.** The person approves the behaviour list directly; the spec
  pass and the final `review-code` still run. A plan of more than 5 behaviours goes to the full
  form, which keeps its reviewer.
- **No change for sensitive work.** A change `keel plan risk` marks sensitive is offered the full
  form, where the full loop and the mutation step apply as today.
- **No measurement of the short path separately.** `keel plan report` reads its plan like any
  other.

---

### Task 1: `write-plan`'s short path

**Story:** none.
**Files:**
- Create: `skills/write-plan/references/short-path.md`
- Modify: `skills/write-plan/SKILL.md`, `docs/02-skill-catalog.md`, `CHANGELOG.md`

**Depends on:** none

**Behaviours:**

1. **When it applies.** `short-path.md` says the short path is for small work with no stories:
   work the person can describe as at most 5 behaviours with examples, on a project whose profile
   has its verify commands. No PRD or stories are needed, because the behaviour list is the
   requirement and the person approves it.
2. **The steps, in order.**
   - Read the code the request touches, `.keel/profile.json` and `<docs_root>/standards.md`, then
     write the behaviour list with example values and the files each would touch, as root-relative
     file paths, never directories.
   - **Check scope against all four limits** and name the one hit: more than 5 behaviours; a
     verify command missing from the profile; `keel plan risk <the named files>` printing
     `loop: full`, exiting other than 0, or no `keel` (read as sensitive, because failing to decide
     is never a reason to review less); and, on the default branch, the person declining a new
     branch. On any of the first three, offer `write-plan`'s full form, or `write-prd` where the
     requirement is unclear, because big or sensitive work earns the plan reviewer and the full
     loop. Say that the check is a forecast: `keel plan risk --staged` at execution still decides
     the review loop, so a build that touches a sensitive file nobody named gets the full loop.
   - Write a one-task plan where `write-plan` step 3 says plans go (honouring
     `profile.artifacts.plans`), in the template's shape
     (`skills/write-plan/references/plan-template.md`): header with
     `**Stories:** none, short path: behaviours approved by <person>, <date>`,
     `**Implementer routing:**`, `**Delivery:**`; Global constraints from the profile and
     `<docs_root>/standards.md`, including **"Delegated mode only: do not run inline, because the
     spec pass is this plan's only per-task review and no plan reviewer ran"**; one task with its
     `**Files:**`, `**Depends on:** none`, `**Behaviours:**` and `**Done when:**`, and its steps.
     Example behaviour line: "a refund larger than the payment is refused with
     `refund_exceeds_payment`".
   - Run the template's mechanical self-review items: no placeholders, commands from the profile,
     `keel plan status <plan>` exits 0, every behaviour has an example; they cost nothing and catch
     what a reviewer would.
   - Ask one question carrying the behaviours, the routing and the delivery choice, with "deliver
     to a pull request" first and "hand off" second, for example "Approve these 3 behaviours,
     implement on keel-implementer, deliver to a pull request". **On the default branch** the
     question also names a new branch, for example "... on new branch `feat/<slug>`", and on
     approval the short path creates it (`git switch -c feat/<slug>`) before committing, because
     that answer is the consent `execute-plan`'s precondition asks for. Write the answer into the
     plan's two header lines.
   - Commit the plan alone, `docs(plans): <slug>`, then on `pull-request` start `execute-plan`, and
     on hand-off name it, as `write-plan` step 6 does, for the same reasons.
3. **What it skips, and why.** No stories, no plan reviewer and no file map beyond the one task's
   `**Files:**`, because a one-task plan whose behaviours the person approved has little a reviewer
   can add that the spec pass and `review-code` will not catch.
4. **`write-plan` step 1** keeps "If no stories exist, stop" and adds, in 9 words, "Small work
   with no stories follows `references/short-path.md` instead." To stay at or below 900 words it
   drops step 3's "Use the exact commands from `profile.verify`, never a guess at what the project
   uses.", which duplicates the template's "Commands come from the profile" section and self-review
   item 4, so no rule is lost.
5. **`write-plan`'s description** gains "or asks to implement a small change" (or close), so a
   session that picks skills by description reaches the short path; it stays under the
   description length cap and `tests/validate-skills.sh`'s description budget.
6. **Records:** the catalog's `write-plan` entry says it also runs a short path for small work, and
   keeps 627 lines; `CHANGELOG.md` gains an entry, with the owed eval arm for the `write-plan` body
   edit recorded against a scenario to be written, `implement-a-small-change` (inject `write-plan`;
   passes if the reply writes 5 or fewer behaviours with examples, runs `keel plan risk`, asks one
   question with the pull request first, and writes no code).

**Done when:** all of these:
- `tests/validate-skills.sh` prints `OK`, with `write-plan` at or below 900 words.
- `bash tests/test-doc-claims.sh` and `tests/validate-citations.sh` pass.
- `grep -c 'short-path.md' skills/write-plan/SKILL.md` prints at least 1.
- `wc -l < docs/02-skill-catalog.md` prints 627.
- A reviewer finds behaviours 1 to 6, with the examples.

- [x] **Step 1.1: Write `short-path.md`** for behaviours 1 to 3.
- [x] **Step 1.2: Edit `write-plan` step 1 and its description** for behaviours 4 and 5. Note: write-plan 893 words, description 174 characters; one citation repointed by phrase in profile-schema-drift.md
- [x] **Step 1.3: The records** for behaviour 6.
- [x] **Step 1.4: Check and stage.** The `Done when:` checks and the full `tests/run-tests.sh`. Note: rounds: 2; routing: keel-implementer (sonnet, by hand); loop: light; spec DEVIATES on a false reason for root-relative paths, one fix pass, second spec pass COMPLIES; full run-tests.sh witnessed by me, all passed
  Stage every file named under **Files:** that changed, by path, show `git status --porcelain`, and
  stop. The coordinator ticks and commits, with this plan:
  `feat(skills): write-plan runs a short path for small work`.

---

### Task 2: the router sends small work down the short path

**Story:** none.
**Files:**
- Modify: `skills/keel/SKILL.md`, `skills/tdd/SKILL.md`, `templates/prompting-cheatsheet.md`,
  `docs/prompting.md`, `docs/02-skill-catalog.md`, `docs/ideas/delivery-flow-gaps.md`,
  `CHANGELOG.md`

**Depends on:** task 1

**Behaviours:**

1. **The routing rows.** `skills/keel/SKILL.md`'s "implement X, add feature Y" row becomes exactly
   ``| implement X, add feature Y, a small change | `write-plan` (short path) |``, and a new row
   follows it: ``| just write the code for X, no PR | `tdd` |``, because `tdd` alone stops at the
   code and the short path carries it to a pull request with the review in between. A fix for a
   reported bug still routes to `debug`.
2. **`tdd`'s description** keeps implementation and says small changes asked for by name go through
   `write-plan`'s short path first, in substance: "Use when writing implementation code for any
   feature, bugfix or behaviour change, including each task a plan dispatches; a small change asked
   for by name starts at write-plan's short path." Only the frontmatter changes; the body is
   untouched. It stays under the description cap and the validator's description budget.
3. **The cheatsheets.** `templates/prompting-cheatsheet.md` and this repository's installed copy
   `docs/prompting.md` say the same as the router, in their own column shape, because the template
   ships to every project as `<docs_root>/prompting.md` and must match the router.
4. **Catalog:** the `keel` (router) entry, if it lists routes, matches, and the `tdd` entry's
   Trigger matches its new description; the file keeps 627 lines.
5. **Records:** `docs/ideas/delivery-flow-gaps.md`:
   - Status: gap 4's short path built by this plan, with task 1's commit and task 2's title; the
     short path writes a one-task plan; gap 4 is built in full;
   - the gap 4 section's "**Built 2026-10-16 for planned work**" line names the short path built
     2026-10-17 too, and its "goes straight to `tdd`" reads as the state before;
   - Next: drops the short path from what remains;
   - "Decided" gains item 8 with Bernard's answers (the three, and the branch and description
     decisions after the review).
   `CHANGELOG.md`: an entry for this task, with the owed eval arm for the `tdd` description change
   if the validator counts it (the body is unchanged, so likely none).

**Done when:** all of these:
- `tests/validate-skills.sh` prints `OK`, with `keel` at or below 900 words.
- `bash tests/test-doc-claims.sh`, `tests/validate-citations.sh` and
  `bash tests/test-harness-claims.sh` pass.
- `grep -c 'short path' skills/keel/SKILL.md`, and the same in `templates/prompting-cheatsheet.md`
  and `docs/prompting.md`, each print at least 1.
- `wc -l < docs/02-skill-catalog.md` prints 627.
- A reviewer finds behaviours 1 to 5.

- [x] **Step 2.1: The router, `tdd`'s description and the cheatsheets** for behaviours 1 to 3. Note: keel 594 to 611 words; tdd description 188 characters, body unchanged
- [x] **Step 2.2: The catalog and the records** for behaviours 4 and 5. Note: router citations repointed by phrase in standards-that-bind.md and the standards-assessment PRD
- [x] **Step 2.3: Check and stage.** The `Done when:` checks and the full `tests/run-tests.sh`. Note: rounds: 2; routing: keel-implementer (sonnet, by hand); loop: light; spec DEVIATES on stale line citations into the router, a 133-column line and a word count, one fix pass, second spec pass COMPLIES; full run-tests.sh witnessed by me, all passed; the final review-code found nothing blocking, its five should-fix and four consider were fixed in 3d1cbac, and the re-review's one should-fix and one consider in a154f90; the three owed eval arms passed (f90d938)
  Stage every file named under **Files:** that changed, by path, show `git status --porcelain`, and
  stop. The coordinator ticks and commits, with this plan:
  `feat(skills): the router sends small work down the short path`.

---

## What the review changed

A plan reviewer read the first draft on 2026-10-17. Applied: the short path's plan forbids inline
mode, since the spec pass is its only per-task review; on the default branch the approval names a
new branch and the short path creates it (Bernard's choice); `write-plan`'s description claims
small changes and `tdd`'s defers them, so sessions that pick by description reach the short path
(Bernard's choice); the step 1 exception works however `write-plan` was reached, and the trim is
named; the scope check lists all four limits, takes files not directories, and says it is a
forecast; the plan goes where step 3 says; the cheap self-review items run; constraints include
the standards file; the ADR line is corrected; `docs/prompting.md` and the gap 4 section are
updated; the owed `write-plan` arm names its scenario; the stories line says who approved; the
router rows are exact; and bug fixes are named as not covered.
