# An approved plan runs through to an open pull request Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> Both tasks change skill text and docs and carry no failing test; each behaviour's example is the
> wording it must produce, checked by the commands in `Done when:` and by a reviewer.

**Goal:** when the person approving a plan chooses delivery to a pull request, approval starts
`execute-plan`, and `execute-plan`, the feature's `review-code` and `ship` run one after another
without waiting for the person, stopping wherever any of them says a person decides. The pull
request is the gate. Without that choice nothing changes.
**Stories:** none. A change to keel's own process, specified by a decided idea record.
**ADRs:** none written for this, and none contradicted. ADR-0002 (the coordinator writes no code)
holds throughout the run, review fixes included; ADR-0001 governs the body edits.
**Architecture:** no new skill (CONTRIBUTING.md: "No new skill, improve the existing one" is a
common and correct outcome). A plan header line, `**Delivery:**`, chosen at approval, tells
`write-plan` to start `execute-plan` and `execute-plan` to continue past its report. The rules for
continuing live in a new reference, `skills/execute-plan/references/delivery.md`, because the
`execute-plan` body has 8 words left under ADR-0001's ceiling. If the reference is not read, the run
stops at the old hand-off, which fails safe.
**Implementer routing:** keel-implementer
**Delivery:** hand-off
**Decided:** Bernard, 2026-10-16, `docs/ideas/delivery-flow-gaps.md`, "Decided" item 3: once the
behaviour list is approved, keel runs build, review and `ship` to an open pull request without
stopping, except on a blocker, a second blocking finding, or `sensitive-guard`'s ask. Gap 5's
decision that should fix and consider findings become a follow-up list applies to the run.
**Shape:** behaviours with examples, as gap 1 decided.
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
- **Skill bodies.** `execute-plan` is at 892 words, `write-plan` at 853 and `review-code` at 560;
  each stays at or below 900. A body edit to one over 700 words owes an ADR-0001 eval arm, recorded
  as owed in `CHANGELOG.md`.
- **Line citations.** Cite by phrase (`file#phrase`), not by line number, in anything this plan
  writes. After each edit, `grep -rn '<file>:[0-9]' docs` for each edited file and keep cited lines
  on their text, or repoint them to a phrase (`docs/ideas/leon-van-zyl-skill-collection.md` cites
  `review-code/SKILL.md:83`).
- **Plans are scanned for links.** `tests/validate-skills.sh` checks markdown links in
  `docs/plans/`; write paths in backticks, never as links, in this plan and its examples.

## What this plan does not build

- **No change to the gates.** `ship`'s eight checks, `security-audit`'s force, the review loops and
  their caps, and `hooks/sensitive-guard` are unchanged. Delivery only removes the waits between
  skills; every stop a gate or a skill makes still stops the run.
- **No merge.** The run ends at an open pull request, or, where `gh` is absent, at a pushed branch
  and the compare URL, reported as such. Merging stays a person's act.
- **No default change.** A plan with no `**Delivery:**` line, or `hand-off`, behaves exactly as
  today: each skill names the next and stops.
- **No short path without a plan.** Gap 4 also asked for joining `tdd`, `review-code` and `ship`
  for work without a PRD; this plan covers planned work only, and the record says so.
- **No router change.** Delivery is chosen at approval, in the plan; asking to "deliver" a plan
  whose line says `hand-off` changes nothing until the line is changed.
- **No measurement of delivery mode.** `keel plan report` does not print the `**Delivery:**` line,
  and a review fix committed after the last tick is not in `delivered`; recorded as known gaps.

---

### Task 1: `execute-plan` and `review-code` continue when the plan says so

**Story:** none.
**Files:**
- Create: `skills/execute-plan/references/delivery.md`
- Modify: `skills/execute-plan/SKILL.md`, `skills/review-code/SKILL.md`, `skills/ship/SKILL.md`,
  `CHANGELOG.md`

**Interfaces:**
- Produces: the header line `**Delivery:** hand-off` or `**Delivery:** pull-request`, read from the
  plan's header; absent means `hand-off`. And a `## Delivery` section that the coordinator appends
  to the plan during a run, one line per stage, for example `- review-code: nothing blocking
  (2026-10-16, base 57c1bc4)`.

**Depends on:** none

**Behaviours:**

1. **`execute-plan` step 6** keeps its report and replaces "Then name `review-code` and `ship`. Do
   not start them." with a sentence of at most 14 words that names the reference by path in
   backticks, for example "Then name `review-code` and `ship`; `references/delivery.md` says when to
   start them." The body stays at or below 900 words.
2. **`delivery.md`, the general rule first:** under `**Delivery:** pull-request`, any point in the
   chain where a skill or one of its references says stop, ask, or "the user decides" ends the run
   with a report of where it stopped, what it needs, and what was left as it was. The list that
   follows names cases of that rule, not all of it. Example: "Stopped at `ship` check 4:
   `security-audit` found 1 finding under `warn`, which the user decides. Nothing was pushed."
3. **`delivery.md`, the cases named:** an `execute-plan` step 5 stop; a deviation from the plan, a
   skipped task, or a step deferred or marked not applicable (each needs the user's agreement); the
   loop sending a task to the person (a second light-loop DEVIATES, or a full-loop DEVIATES or
   blocking finding with no fix allowed); `keel plan risk` exit 4; a dirty tree before a dispatch; a
   rejected attempt already committed; an unknown routing value; a plan repair; an empty join diff;
   `review-code`'s second blocking round; any red `ship` check (the `format_fix` exception aside);
   any `security-audit` finding, under `required` or `warn`; a `hooks/sensitive-guard` ask the
   person declines or does not answer; and a context-watch block.
4. **`delivery.md`, the run:** once every task is ticked and committed, the coordinator runs
   `review-code` over the whole change, base `git merge-base <default_branch> HEAD` (what `ship`
   opens the pull request against), then `ship`. A blocking finding, or a standards violation `ship`
   check 5 would refuse under `gates.coding_standards: required`, gets one fix pass: a fresh
   implementer on the plan's `**Implementer routing:**`, given the findings and told to change only
   what they name; `keel plan risk --staged` on the result; the coordinator commits it as
   `fix: <what> (review-code)`; then exactly one re-review. A second blocking round stops the run.
   The `security-audit` report file `ship` writes is committed on its own before the pull request.
5. **`delivery.md`, the record:** after each stage the coordinator appends a line to the plan's
   `## Delivery` section and commits it with the stage, so a resumed session (after a compaction or
   a context-watch block) reads the plan line, `keel plan status` and that section, and re-runs
   `review-code` if its verdict is not recorded. `ship` check 5 reads that line in a delivery run.
6. **`delivery.md`, what the run never does:** merge, push to the default branch, override a gate on
   the person's behalf, accept a finding the person has not named, or start `ship` from a
   `review-code` that `execute-plan` did not start in a delivery run.
7. **`review-code` step 5's hand-off** ("Then name `security-audit` and `ship` as next. Do not start
   them.") gains: unless `execute-plan` started this review in a delivery run, in which case `ship`
   follows as `execute-plan`'s delivery reference says.
8. **`ship`'s PR body** in a delivery run carries the follow-up list: every should fix and consider
   finding from the per-task reviews and `review-code`, and the step 6 report's remaining items. One
   sentence in "Committing and the PR".
9. **`CHANGELOG.md`:** an Unreleased entry; the owed arms for the `execute-plan` and `ship` body
   edits; and a known gap: no test or eval yet shows a session continuing from `execute-plan` into
   `review-code` and `ship`.

**Done when:** all of these:
- `tests/validate-skills.sh` prints `OK`, with `execute-plan` and `ship` at or below 900 words.
- `bash tests/test-doc-claims.sh`, `tests/validate-citations.sh` and
  `bash tests/test-harness-claims.sh` pass.
- `grep -c 'Do not start them' skills/execute-plan/SKILL.md` prints 0, and
  `grep -c 'delivery.md' skills/execute-plan/SKILL.md` prints 1.
- `grep -c 'pull-request' skills/execute-plan/references/delivery.md` prints at least 1, and
  `grep -c 'merge-base' skills/execute-plan/references/delivery.md` prints at least 1.
- `grep -c 'delivery run' skills/review-code/SKILL.md` prints at least 1.
- A reviewer finds behaviours 2 to 8 stated, with the example wording.

- [x] **Step 1.1: Write `delivery.md`** for behaviours 2 to 6. Note: delivery.md by a sonnet subagent; one fix pass made the record carry the standards state and the follow-up list
- [x] **Step 1.2: Edit `execute-plan` step 6, `review-code` step 5 and `ship`** for 1, 7 and 8. Note: execute-plan 894, review-code 594, ship 844 words; one citation repointed by phrase in leon-van-zyl-skill-collection.md
- [x] **Step 1.3: Check and commit.** The `Done when:` checks and the full `tests/run-tests.sh`. Note: rounds: 2; routing: keel-implementer (sonnet, by hand); loop: light; spec DEVIATES on a resume hole, one fix pass, second spec pass COMPLIES; full run-tests.sh witnessed by me, all passed
  Stage the five files and this plan. Commit: `feat(skills): an approved plan can run through to a
  pull request`.

---

### Task 2: approval chooses it, and starts the run

**Story:** none.
**Files:**
- Modify: `skills/write-plan/SKILL.md`, `skills/write-plan/references/plan-template.md`,
  `docs/02-skill-catalog.md`, `docs/ideas/delivery-flow-gaps.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: the `**Delivery:**` line and the `## Delivery` section task 1 defines.

**Depends on:** task 1

**Behaviours:**

1. **The template's header** gains `**Delivery:** hand-off` after `**Implementer routing:**`, with
   one paragraph: `hand-off` stops after each skill as before; `pull-request` runs through to an
   open pull request, stopping wherever `skills/execute-plan/references/delivery.md` says; the
   person approving chooses, and can change the line before `execute-plan` runs.
2. **`write-plan` step 6** asks the person to approve with one question carrying the routing and the
   delivery choice, for example "Approve, implement on keel-implementer, deliver to a pull request";
   writes the answer into the two header lines; commits the plan; and, on `pull-request`, starts
   `execute-plan` instead of naming it. On the default branch, where the plan is not committed, it
   does not start the run and says so. Within 900 words.
3. **`docs/02-skill-catalog.md`**, the `execute-plan` and `write-plan` entries, say a plan can run
   through to a pull request when approved that way, without changing the file's line count.
4. **Records.** `docs/ideas/delivery-flow-gaps.md`: Status names gap 4 built for planned work, with
   its commits, and the short path without a plan not built; Next names gap 2; the gap 4 section
   gets "**Built 2026-10-16 for planned work**, see Status." `CHANGELOG.md`: the entry and the owed
   arm for the `write-plan` body edit.

**Done when:** all of these:
- `tests/validate-skills.sh` prints `OK`, with `write-plan` at or below 900 words.
- `bash tests/test-doc-claims.sh`, `tests/validate-citations.sh` and
  `bash tests/test-harness-claims.sh` pass.
- `grep -c 'Delivery:' skills/write-plan/references/plan-template.md` prints at least 1, and
  `grep -c 'Delivery' skills/write-plan/SKILL.md` prints at least 1.
- `wc -l < docs/02-skill-catalog.md` prints 627.
- A reviewer finds behaviours 1 to 4 stated.

- [x] **Step 2.1: The template and `write-plan` step 6** for behaviours 1 and 2. Note: write-plan body 853 to 893 words; the default-branch case still writes both lines into the uncommitted plan
- [x] **Step 2.2: The catalog and the records** for behaviours 3 and 4. Note: catalog kept at 627 lines by joining the `Depends on:` paragraph to the one before it
- [x] **Step 2.3: Check and commit.** The `Done when:` checks and the full `tests/run-tests.sh`. Note: rounds: 1; routing: keel-implementer (sonnet, by hand); loop: light; spec COMPLIES first pass, three minor notes left for review-code; full run-tests.sh witnessed by me, all passed
  Stage the changed files and this plan. Commit: `feat(skills): delivery to a pull request is chosen
  when the plan is approved`.

---

## What the review changed

A plan reviewer read the first draft on 2026-10-16. Applied: the example link became backticked text
(plans are scanned for links); the review base is the merge base, so task 1 is never left out; the
fix for `review-code`'s first blocking finding is assigned (a fresh implementer, `plan risk`, the
coordinator's commit, one re-review); the stop list starts from a general rule (any stop, ask or
"the user decides" ends the run) and names the cases the draft missed, `warn` security findings and
plan deviations among them; the `review-code` exception applies only when `execute-plan` started it;
follow-up findings go in the PR body; approval under `pull-request` starts the run, so there are two
checkpoints; a `## Delivery` record in the plan lets a resumed session and `ship` check 5 find the
review verdict; the router is left alone; `Done when:` checks each behaviour; and the record calls
gap 4 built for planned work only.
