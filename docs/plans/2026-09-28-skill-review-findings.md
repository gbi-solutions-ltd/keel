# Skill review findings Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps are checkboxes with ids, `**Step <task>.<step>: ...**`. Find your place with
> `keel plan status <this file>` and tick with `keel plan tick <this file> <id>`, on output you
> read; where `keel` cannot run, tick by hand.
> A box for a step you did not perform yourself is ticked only with a note naming what you did
> and did not witness (`--note <text>`), or left unticked and reported.
> **REQUIRED SUB-SKILL:** `keel:tdd` for every task that changes behaviour; tasks 1 and 2 change
> none and say so.

**Goal:** one findings file records every defect and clarity change across all 25 skills, their
descriptions and their 62 reference files; Bernard rules on every finding that would remove a rule
or a trigger; and the one defect known before the pass, `tdd`'s keel-only timing, is fixed.
**Stories:** S-01, S-02, and the `tdd` part of S-03, in `docs/stories/skill-and-reference-review.md`,
from `docs/prd/skill-and-reference-review.md` (approved 2026-09-28).
**ADRs:** ADR-0001 (a body over 700 words owes a passing arm at its length) and ADR-0005 (one body
per skill across harnesses). Neither is changed.
**Architecture:** no code. Task 1 fans the reading out to seven subagents, six by group of skills
and one comparing skills with each other, and assembles their verified findings into
`docs/audits/<date>-skill-review.md` in a fixed table shape. Task 2 puts every finding that removes a rule or a trigger to Bernard and records each
ruling in the file. Task 3 replaces the one sentence in `skills/tdd/SKILL.md` that states keel's own
suite timing, and re-runs the two eval arms that inject `tdd`.

**Decided 2026-09-28, Bernard:** the review is planned in two parts. This plan is the first. The
rest of S-03, and S-04 to S-07, are planned once the findings file exists, because their edits can
only be written as exact text from it; a plan written now would have to say "apply the findings",
which the plan template forbids.

**Order, decided 2026-09-28, Bernard:** this plan runs after
`docs/plans/2026-09-28-addressable-plan-steps.md`, which builds the `keel plan` commands this
plan's header uses. Both plans' eval arms are approved to run as written.

**The findings file's shape**, fixed here so task 2 and the second plan can read it:

- Path `docs/audits/<YYYY-MM-DD>-skill-review.md`, dated the day task 1 runs.
- A header table: date, the commit the pass read (`git rev-parse --short HEAD` before step 1.2), and
  the stories it serves.
- One `### <path>` section per file read, in `skills/` order: each `SKILL.md`, then that skill's
  reference files. Every file read gets a section; a file with nothing to change says
  `No findings.` A skill's `description` findings go in its `SKILL.md` section, and every
  `SKILL.md` section opens with a line `Description: no findings.` or `Description: F-NNN[, F-NNN]`
  naming its description findings, so a description nobody reviewed cannot pass as one with nothing
  to change.
- A final `### Between skills` section holds contradictions between two different skills, from
  reader G.
- Under each section with findings, one table:

  | # | Where | Kind | Finding | Proposed change | Removes | Ruling | Resolution |
  |---|---|---|---|---|---|---|---|

  - `#` is `F-NNN`, numbered across the whole file from `F-001`, never reused.
  - `Where` is `path:line`, with `(description)` after it for a description finding.
  - `Kind` is exactly one of `repository fact`, `contradiction`, `stale or broken reference`,
    `clarity change`.
  - `Proposed change` is the exact new text, or `delete`, never a description of an edit.
  - `Removes` names the rule or description trigger the change would remove, or `nothing`. A change
    that deletes one of two statements of a rule is not `nothing`: it records `the statement of
    <rule> at <path:line>, kept at <path:line>`, because a rule that holds by being repeated is
    exactly what S-02 exists to protect.
  - `Ruling` is `not needed` where `Removes` is `nothing`, otherwise `pending` until task 2 sets it
    to `approved YYYY-MM-DD` or `refused YYYY-MM-DD`.
  - A `|` inside a cell, as in a replacement for a table row, is written `\|`. Step 1.5 counts cells
    with those removed, so an unescaped one shows as a wrong cell count rather than a shifted row.
  - Text quoted from a skill is put in a code span, so a link inside it is not resolved against
    `docs/audits/` by `tests/validate-skills.sh`.
  - `Resolution` is `open` until a later task sets it to `fixed <commit>`, `made <commit>` or
    `declined: <reason>`.

**Concurrent batches:** none. Task 2 reads task 1's file, and task 3 sets a row in it.

## Global constraints

- Verify commands, from `.keel/profile.json`: test `tests/run-tests.sh`; one test file
  `tests/{name}`; typecheck and build are `null`, since there is nothing to compile; lint is:

  ```bash
  shellcheck -x bin/keel bin/keel-fleet lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh \
    tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard
  ```

- `tests/run-tests.sh` takes about seven minutes and prints nothing until each file finishes. Slow
  is not hung.
- Never start on `main`. Work on `sandbox`, which is where this repository's pull requests come
  from.
- No em dash and no en dash anywhere: docs, findings, commit messages.
- Prose in markdown wraps at 100 columns; tables do not (docs/standards.md, "Prose wraps at 100
  columns; tables do not").
- Shipped prose states the current state; history lives in `CHANGELOG.md` (docs/standards.md,
  "Shipped prose states the current state, and history lives in the changelog").
- Documentation lands in the same commit as the change: a line under `## Unreleased` at the top of
  `CHANGELOG.md`, plus any document the change makes wrong.
- A skill body stays at or under 900 words, and one over 700 owes a passing eval arm at its new
  length, recorded in `tests/evals/results.md` (ADR-0001). One skill body serves every harness
  (ADR-0005).
- From the PRD: no rule a skill states is removed unless its finding records the removal and
  Bernard approves it (FR-07); no sentence stating a rule's reason is removed as a clarity change
  (FR-08); no description trigger is removed without the same approval (FR-12); no new eval scenario
  is written (FR-10). A description stays within 216 characters and all of them within 1,320 tokens
  (CON-04).
- After an edit that inserts or deletes lines in any tracked file, run `tests/validate-citations.sh`
  and repair what it reports.
- Stage named paths only. Never `git add -A`, `git add .` or `git commit -a`.
- Commit messages are conventional, title and body only: no `Co-Authored-By`, no robot emoji, no
  generated-with line.
- Do not delete a file you did not create, except where a task names it. If `git status` shows
  something unexpected, report it and leave it alone.

---

### Task 1: A findings pass over every body, description and reference

**Story:** S-01
**Files:**
- Create: `docs/audits/<YYYY-MM-DD>-skill-review.md`

**Interfaces:**
- Consumes: nothing
- Produces: the findings file in the shape above, read by task 2, task 3 and the second plan

**Depends on:** none

**Done when:** there is no command from `profile.verify` for this; the checks in step 1.5 each
print nothing, and `tests/validate-skills.sh` and `tests/validate-citations.sh` pass. Both read
every file under `docs/`, the findings file included.

- [x] **Step 1.1: There is no test for this**

This task writes a review record and changes no skill, so it has no behaviour to test. Step 1.5's
checks are the mechanical part: every file has a section, every kind is one of the four, and the
known defect is recorded.

- [x] **Step 1.2: Record the starting commit and the file list** Note: bda1acc, 87 files (25 bodies, 62 references)

```bash
git rev-parse --short HEAD
ls skills/*/SKILL.md skills/*/references/*.md | wc -l
```

Expected: a short sha, and 87 (25 bodies and 62 references). A different count means a skill or a
reference was added or removed since planning: use the count printed, and say so in the report.

- [x] **Step 1.3: Dispatch seven readers**

**Tasks 1 and 2 run in the coordinator, not a delegated implementer.** Task 1 dispatches readers
and verifies their findings, which a subagent cannot do for other subagents, and task 2 asks
Bernard, which needs `AskUserQuestion`, a tool subagents do not have. Say so in one line when
starting each, per `execute-plan` Step 3.

Dispatch all seven readers in one message, as general-purpose subagents with model `inherit`, not
the `keel-fanout` profile: that profile pins a cheaper model for mechanical reading, and judging
whether a sentence is clear is judgement. Readers A to F each get the first brief below with its
group pasted in; reader G gets the second.

| Group | Skills |
|---|---|
| A | `coding-standards` |
| B | `write-prd`, `write-user-stories`, `write-plan`, `execute-plan`, `tdd` |
| C | `debug`, `review-code`, `security-audit`, `refactor`, `optimize-performance` |
| D | `design-architecture`, `design-database`, `repo-snapshot`, `write-docs`, `shape-idea` |
| E | `ship`, `setup-deployment`, `incident-response`, `context-budget`, `create-skill` |
| F | `keel`, `apex-export`, `apex-port-plan`, `port-assess` |
| G | every `SKILL.md` body, for contradictions between two different skills only |

The brief, verbatim:

```text
You are reviewing keel skills for defects and for clarity. keel is a set of skills that a model
follows while working in someone else's project. Read, for each skill in your group, its
skills/<name>/SKILL.md (frontmatter description and body) and every file in
skills/<name>/references/. Your group: <GROUP>.

Report findings of exactly these four kinds:

- repository fact: a fact about keel's own repository stated as if it were true of the project the
  skill is used in. Example: skills/tdd/SKILL.md "The suite is 313 seconds and one test is 2.", which
  is keel's own tests/run-tests.sh. History quoted as evidence for a rule ("observed on 2026-08-20")
  is not this kind.
- contradiction: two statements that cannot both be followed, within a file or between a body and
  its reference. Quote both, each with path:line. Contradictions between two different skills are
  another reader's; do not report them.
- stale or broken reference: a link or path that does not resolve, a step or section named that
  does not exist, or a skill, command or flag named that does not exist. Check each one.
- clarity change: a rule stated more than once where once would do, a table row that restates a
  step above it, a sentence that can be read two ways, or a description that names a trigger the
  body does not handle or misses one it does.

For every finding give: path:line; the kind; one sentence quoting the text concerned; the exact
replacement text, or "delete"; and what the change removes, naming the rule or description trigger,
or "nothing". Never propose removing a sentence that states the reason for a rule. Where a rule is
stated twice, propose keeping the statement at the step where the model needs it, and record the
removal as "the statement of <rule> at <path:line>, kept at <path:line>", never as "nothing".

For every file you read with nothing to change, say "No findings." for it by path, so the reader
knows it was read. For every skill, say separately whether its description has findings, even when
its body has some.

These are leads for someone who will verify each one, not conclusions. Do not edit any file.
Write no dashes longer than a hyphen.
```

The brief for reader G, verbatim:

```text
You are checking keel skills for contradictions between skills. keel is a set of skills that a
model follows while working in someone else's project, and one task often passes through several of
them: tdd and debug, write-plan and execute-plan and ship, review-code and security-audit. Read
every skills/*/SKILL.md body. Report only pairs of statements, in two different skills, that cannot
both be followed: for example one skill saying to run the full suite after every test and another
saying to run it once per unit. For each, quote both with path:line, say which situation brings a
model to both, and propose the exact replacement text for one of them, and what that removes.
Report nothing within a single skill; other readers cover that.

These are leads for someone who will verify each one, not conclusions. Do not edit any file.
Write no dashes longer than a hyphen.
```

- [x] **Step 1.4: Verify and assemble**

Open every reported `path:line` and confirm the finding. Correct a wrong line number; drop a
finding that does not hold, and count the drops. For a `repository fact` or `stale or broken
reference` finding, run the check that proves it (a `ls` for a path, a `grep` for a named section).

Put reader G's verified findings under `### Between skills`, with `Where` naming the first of the
pair and `Finding` quoting both.

Write `docs/audits/<YYYY-MM-DD>-skill-review.md` in the shape under "The findings file's shape"
above, with the date the pass ran and the sha from step 1.2 in its header. Below the header, before
the first section, write one paragraph giving: files read, findings by kind, findings whose
`Removes` is not `nothing`, and findings dropped in verification.

The `tdd` finding must be present:

| # | Where | Kind | Finding | Proposed change | Removes | Ruling | Resolution |
|---|---|---|---|---|---|---|---|
| F-NNN | skills/tdd/SKILL.md:<its line> | repository fact | "The suite is 313 seconds and one test is 2." states keel's own suite timing as the reader's | `A suite run costs far more than one test's.` | nothing | not needed | open |

- [x] **Step 1.5: Check the file mechanically**

Each block in this plan sets `F` itself, since each step may run in its own shell.

```bash
F=$(ls docs/audits/*-skill-review.md)
for f in skills/*/SKILL.md skills/*/references/*.md; do
    grep -qxF "### $f" "$F" || echo "no section: $f"
done
for f in skills/*/SKILL.md; do
    awk -v h="### $f" '$0 == h { f = 1; next } f && /^### / { exit } f && /^Description: / { found = 1 }
        END { exit !found }' "$F" || echo "no Description line: $f"
done
awk '/^\| F-[0-9][0-9][0-9] / {
    l = $0; gsub(/\\\|/, "", l)
    n = split(l, c, "|")
    if (n != 10) { print "wrong cell count (" n - 2 "), an unescaped | ?: " c[2]; next }
    for (i = 2; i <= 9; i++) gsub(/^ +| +$/, "", c[i])
    if (c[4] != "repository fact" && c[4] != "contradiction" && c[4] != "stale or broken reference" && c[4] != "clarity change")
        print "bad kind: " c[2]
    if ((c[7] == "nothing") != (c[8] == "not needed")) print "ruling does not match removes: " c[2]
}' "$F"
grep -qxF '### Between skills' "$F" || echo "no Between skills section"
grep -q '313 seconds' "$F" || echo "the tdd timing finding is missing"
```

Expected: no output. Then `tests/validate-skills.sh` and `tests/validate-citations.sh` pass.

- [x] **Step 1.6: Hand over**

```bash
F=$(ls docs/audits/*-skill-review.md)
git add "$F"
git status --porcelain
git diff --cached --name-only | grep '^skills/'
```

Expected: the last command prints nothing, since this task changes no skill. Stage exactly the
findings file and stop. **Do not commit.** The coordinator commits after both review passes, with
`git commit -m "docs(audits): findings from the skill and reference review"`.

**Review record, 2026-09-29.** Run in the coordinator, as the task says. The seven readers
reported; each lead was verified against its cited lines, with an anchor quote checked to lie in
the cited range and the contested ones run or read by hand (the `debug` credential idiom was run
and does print the value). Spec review first returned DEVIATES: four proposed changes described an
edit, one substitution duplicated a sentence, two between-skills rewrites dropped text with
`nothing` recorded, three findings did not hold, and seven leads were unaccounted for. All were
fixed and re-reviewed to COMPLIES. The quality review raised two blocking and five should-fix
items: the between-skills `ship` rewrite removed the refuse-whatever-the-key rule unruled, and
`execute-plan` passes 900 words from its `not needed` findings unless its four pending row
deletions are approved; the rest were rewrites dropping text or changing a rule with `nothing`
recorded, two findings on one line undoing each other, and split code spans. All were fixed and
re-reviewed to RESOLVED. The file holds 343 findings, 143 pending, with twelve drops. Considered
and not acted on: `ADR-0001` arms owed where `security-audit` and `write-plan` cross 700 words;
the story-template move and the edits inside it need an order in the second plan; the dropped half
on `write-plan`'s batch reasons is recorded only in the summary; the `ship` finding's
cross-references run one way; the `REQUIRED SUB-SKILL` marker is dropped from
`optimize-performance`'s rewrite.

### Task 2: Bernard rules on every finding that removes a rule or a trigger

**Story:** S-02
**Files:**
- Modify: `docs/audits/<YYYY-MM-DD>-skill-review.md`

**Interfaces:**
- Consumes: the findings file from task 1
- Produces: every `Ruling` cell set to `not needed`, `approved YYYY-MM-DD` or `refused YYYY-MM-DD`

**Depends on:** task 1

**Done when:** there is no command from `profile.verify` for this; the check in step 2.3 prints `0`.

- [x] **Step 2.1: There is no test for this**

This is a decision, not code. The plan template routes a `decide` story to an ADR; the stories
record why this one is not: these are rulings on text, and they land beside each finding.

- [x] **Step 2.2: Put each pending finding to Bernard** Note: asked by class, then 15 singly (13, and F-084 and F-130 after review), as Bernard chose on 2026-09-29; see the review record

List them:

```bash
F=$(ls docs/audits/*-skill-review.md)
grep -n '| pending |' "$F"
```

Put them to Bernard with `AskUserQuestion`, following `skills/keel/references/asking-questions.md`:
one finding per question, at most four questions per call, taken in file order. Each question
shows the finding's current text, its proposed change and what it removes; its two options are
approve and refuse. Write
each answer into its row's `Ruling` cell as `approved YYYY-MM-DD` or `refused YYYY-MM-DD`, with the
date it was given.

- [x] **Step 2.3: Check none is left pending**

```bash
F=$(ls docs/audits/*-skill-review.md)
grep -c '| pending |' "$F"
```

Expected: `0`.

- [x] **Step 2.4: Hand over**

```bash
F=$(ls docs/audits/*-skill-review.md)
git add "$F"
git status --porcelain
```

Stage exactly the findings file and stop. **Do not commit.** The coordinator commits after both
review passes, with `git commit -m "docs(audits): rulings on the review's removals"`.

**Review record, 2026-09-29.** Run in the coordinator. Asked how to rule on the 143 pending
findings, Bernard chose to rule by class and then the rest singly, departing from step 2.2's one
question per finding: the Common mistakes rows restating a step are approved except the twelve
that would empty `incident-response`'s and `setup-deployment`'s tables; second statements of a
rule are approved where they remove a reference file's copy and refused where they remove the
body's; the other fifteen were asked one at a time, all approved (F-200 and F-339 as a pair).
Result: 119 approved, 24 refused. Review found two findings, F-084 and F-130, ruled under the
table-row class they do not belong to; both were put to Bernard singly and approved. For the
second plan: `docs/profile-keys.md:55` changes with F-200 and F-339; F-302's kept-at lines are
removed by F-301, and the rule stays at `skills/write-plan/SKILL.md:81-85`; F-059 already carries
F-060's fix to the same line; `execute-plan` lands at 889 words and owes its arm. Considered and
not acted on: four refused body copies (F-140, F-164, F-241, F-243) are kept elsewhere in the same
body, so refusing them keeps a duplicate inside it.

### Task 3: `tdd` no longer states keel's own suite timing

**Story:** S-03, the finding known before the pass
**Files:**
- Modify: `skills/tdd/SKILL.md`
- Modify: `docs/audits/<YYYY-MM-DD>-skill-review.md`
- Modify: `tests/evals/results.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: the `tdd` finding's row from task 1
- Produces: that row's `Resolution` set to `fixed <commit>`

**Depends on:** task 1

**Done when:** `tests/validate-skills.sh` passes, and both eval arms in steps 3.5 and 3.6 are
recorded as **Pass** in `tests/evals/results.md`.

- [x] **Step 3.1: Take the start record**

Run: `tests/run-tests.sh`
Record the commit (`git rev-parse --short HEAD`) and every test already red there, per `keel:tdd`'s
start record. Step 3.8 matches its reds against this list, so without it a red this task caused
could pass as one it found.

- [x] **Step 3.2: Write the failing check**

The sentence is text a model reads, so the behavioural test is the eval arms in steps 3.5 and 3.6,
which FR-06 requires. The textual check comes first:

```bash
grep -n '313 seconds' skills/tdd/SKILL.md
```

- [x] **Step 3.3: Run it and watch it find the sentence**

Expected: one line, `The unit ends with one \`verify.test\` run. The suite is 313 seconds and one
test is 2.`, with its line number.

- [x] **Step 3.4: Replace the sentence**

In `skills/tdd/SKILL.md`, under "### Unit boundary: run the suite", replace:

```markdown
The unit ends with one `verify.test` run. The suite is 313 seconds and one test is 2.
```

with:

```markdown
The unit ends with one `verify.test` run. A suite run costs far more than one test's.
```

The replacement keeps the reason the suite runs once per unit and is one word shorter, so the body
cannot cross a threshold it has not already crossed.

Add at the top of `## Unreleased` in `CHANGELOG.md`:

```markdown
- `tdd` no longer tells every project its suite takes 313 seconds, which was keel's own.
```

Then:

```bash
grep -n '313 seconds' skills/tdd/SKILL.md
tests/validate-skills.sh
```

Expected: the grep prints nothing, and the validator passes, reporting `tdd`'s body one word
shorter than before.

- [x] **Step 3.5: Run the `tdd-under-deadline` arm** Note: run by the coordinator at Bernard's request after the classifier denied the implementer's dispatch

```bash
dir=$(tests/evals/stage.sh tdd-under-deadline)
( cd "$dir/project" && claude -p "$(cat ../prompt.md)" \
    --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$dir/result.json" )
```

Grade `$dir/result.json` against `tests/evals/scenarios/tdd-under-deadline.md`. A fail stops this
task: report it with the arm's own words and use `keel:debug`, rather than rewording until it passes.

- [x] **Step 3.6: Run the `done-without-verifying` arm**

It injects `execute-plan tdd`, so FR-06 requires it too.

```bash
dir=$(tests/evals/stage.sh done-without-verifying)
( cd "$dir/project" && claude -p "$(cat ../prompt.md)" \
    --setting-sources "" --disable-slash-commands \
    --permission-mode bypassPermissions --output-format json > "$dir/result.json" )
```

Grade `$dir/project/PLAN.md`, not the reply, against `tests/evals/scenarios/done-without-verifying.md`,
whose Scoring section says so, in its form `pass (open xN, named xM)`; read the reply only for the
rationalisation it used. A fail stops this task as above, and so does a Partial, which this
scenario defines: only a Pass is a passing arm.

- [x] **Step 3.7: Record the arms and the resolution** Note: results entry written by the coordinator at Bernard's request

Append to `tests/evals/results.md`, in the shape of its 2026-09-21 "ship gate reads
gates.coding_standards" entry: a `## <date>, tdd re-run without keel's suite timing` heading, one
paragraph naming this plan's task 3 and the change, a **Method.** line with each arm's turns, time
and cost from its `result.json`, and a table with one row per arm, its verdict, and what the arm did
against the scenario's criteria.

In the findings file, leave the `tdd` row's `Resolution` as `open` for now; the coordinator sets it
to `fixed <commit>` in the same commit once the sha is known (step 3.8).

- [x] **Step 3.8: Run the suite at the unit boundary, then hand over**

Run: `tests/run-tests.sh`
Expected: PASS, or reds this task did not cause, each named and matched against the start record.
Then `tests/validate-citations.sh`, repairing anything citing `skills/tdd/SKILL.md` by a line this
task moved.

```bash
git add skills/tdd/SKILL.md tests/evals/results.md CHANGELOG.md
git status --porcelain
```

Stage exactly those paths and stop. **Do not commit.** The coordinator commits after both review
passes, with `git commit -m "fix(tdd): stop stating keel's own suite timing as the reader's"`, then
sets the `tdd` row's `Resolution` to `fixed <that commit's short sha>` in the findings file and
commits it with `git commit -m "docs(audits): the tdd timing finding is fixed"`.

**Review record, 2026-09-29.** The implementer made the change test first (the grep found the
sentence at `:87`, then nothing; the body went from 869 words to 868) and ran the
`done-without-verifying` arm, a pass (open x4). The auto-mode classifier denied its dispatch of the
`tdd-under-deadline` arm; at Bernard's choice the coordinator ran that arm once and graded it from
its transcript, a pass, and wrote the results entry. Spec review found one wrong figure in the entry
(the arm's baseline was 8 passed, not 3), fixed and confirmed. The quality review raised two
should-fix items in the entry, fixed and re-reviewed: it overstated what reaching the boundary
shows, and it named no ADR-0001 requirement. Considered and not acted on: the entry's second row
gives no word count; a failed compound command in the arm's transcript goes unmentioned; the PRD
and idea record still describe the timing in the present tense; `writing-good-tests.md` cites
keel's own arms at `:45`, `:93` and `:108`, which the audit has no finding for; the claude.ai
connector notice reaches arms despite `--setting-sources ""`.

## Coverage

| Story | Tasks |
|---|---|
| S-01 | 1 |
| S-02 | 2 |
| S-03 | 3, for the `tdd` finding; the rest of S-03 is in the second plan |
| S-04 to S-07 | the second plan, written from task 1's findings file |
