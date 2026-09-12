# The TDD cycle's unit, and mutation as shipped evidence: Implementation Plan

> **For agentic workers:** use `keel:execute-plan` to implement this task by task.
> Steps use `- [ ]` checkboxes; tick them as you go, on output you read.
> **REQUIRED SUB-SKILL:** `keel:create-skill`, for tasks 2 to 5 and 7, which change a skill.
>
> **`keel:tdd` is deliberately NOT named here**, against the template's default, and on this plan of
> all plans that needs saying out loud. Two reasons.
>
> Nine of these ten tasks change prose. "Write a failing test first" has no referent for a paragraph:
> no `test_one` goes red because a sentence is missing, and `tests/validate-skills.sh` counts words
> and dashes rather than testing the rule. **The test for a skill change is the eval arm**, which is
> what tasks 8 and 9 are, and `create-skill` carries the same discipline in the right medium.
> `CONTRIBUTING.md:34` says so directly: "Skipping the baseline is the same mistake as writing a test
> after the code: you get something that passes and proves nothing."
>
> And this plan rewrites `keel:tdd` itself, so an executor told to follow it would be following a
> different skill after task 3 than before it. A plan should not name as its governing discipline the
> artifact it is in the middle of changing.
>
> The iron law is untouched by any of this. Task 7's schema edit is the one mechanical change, and
> its `Done when:` runs the suite.

**Goal:** the TDD cycle's unit becomes one behavioural unit rather than one assertion, the whole
suite runs at the unit boundary rather than inside the cycle, and mutation stops being an
undocumented house habit.

**Idea:** [`../ideas/tdd-cycle-cost-and-case-coverage.md`](../ideas/tdd-cycle-cost-and-case-coverage.md)
**ADRs:** ADR-0006 (the cycle's unit, task 1) and ADR-0007 (tiering, task 6), both `proposed` until
Bernard accepts them. **Two ADRs and not one, deliberately:** changes 1 and 2 rest on eight releases
of evidence, tiering rests on a mechanism that works and a risk nobody has measured. Bundling them
would mean an arm that fails on tiering could not retire it without dragging the proven half out too.
**Outcome, 2026-09-07:** ADR-0006 is `proposed`; ADR-0007 is **`rejected`**, because Bernard rejected
tiering rather than accepting it. The split did the job it was written for: changes 1 and 2 shipped
untouched by that verdict.
**Accepted later the same day, 2026-09-07:** Bernard accepted ADR-0006, whose status row now
reads `accepted`. The outcome line above and task 1 step 6 stand as written: both record what was
true when this plan was executed, and the acceptance came after.
**Not in scope, rejected with reasons in the idea record:** property-based testing.

## Global constraints

Copied in full. A task executed by a fresh agent that reads only its own section must still obey
these.

- **Verify commands, from `.keel/profile.json`:** test `tests/run-tests.sh`; one test `tests/{name}`;
  lint `shellcheck -x bin/keel lib/*.sh lib/harness/*.sh tests/*.sh tests/evals/run.sh tests/evals/stage.sh hooks/session-start hooks/context-watch hooks/sensitive-guard hooks/done-guard`.
  No typecheck, format or build command in this project.
- **The body budget is the binding constraint on this whole plan.** `skills/tdd/SKILL.md` is **793
  words**. ADR-0001's ceiling is 900 and its target is 700, and an arm "discharges the length it was
  run at, not the body it was run against". 793 is discharged by the 0.17.0 gate arm of 2026-09-01
  and again by the arm of 2026-09-06 recorded in `tests/evals/results.md`. **Any word above 793 owes
  a fresh passing arm.** **Corrected 2026-09-07, was "Task 6".** Task 6 writes ADR-0007 and
  dispatches nothing; task 9 is the length arm and is what pays. Tasks 2 and 3 exist to reduce how
  much it has to pay for.
- **Check the count with `tests/validate-skills.sh` after every body edit**, which prints it.
  **Superseded 2026-09-07:** this bullet used to read "net body words must not exceed 793 without
  task 6 passing". The ceiling is now 860 for tasks 3 to 5, per the ruling below, and the arm that
  pays is task 9, not task 6.
- **The rules live in the body, the recipes live in `references/`.** The body carries the decision,
  the rule, and the reason with its number; the tally recipe, the batch precondition worked example
  and the mutation recipe go to `skills/tdd/references/`, which `docs/standards.md` already
  prescribes for exactly this. This is still binding: it is how the additions stay as small as they
  can be. It is no longer sufficient on its own, for the reason below.
- **Tasks 3, 4 and 5 gate at 860, not 793. Ruled by Bernard 2026-09-07**, replacing an earlier
  ruling of the same date that tried to hold 793. Task 2 frees 52 words, leaving 741, and the
  body-resident additions across tasks 3 to 5 exceed that even with every recipe moved out: the
  first estimate of 125 to 140 words omitted task 4 step 5's new Rationalisations row and task 5
  step 1's mutation sentence, both of which are rules rather than recipes and cannot leave the body.
  **The body therefore grows, and task 9 pays for it with a real arm** rather than recording the
  2026-09-06 one. That is the trade: one eval dispatch buys the words.
- **RESOLVED 2026-09-07, and it changes the shape of this plan.** ADR-0001's ceiling of 900 is a
  hard FAIL in `tests/validate-skills.sh`, not a warning. Measured after task 3 landed: the body is
  **805**, and tasks 4, 5 and 7 as written project to roughly **997**. Bernard ruled: compress the
  no-tooling exception to buy words, and **defer task 7**. So:
  - Task 4 gains a first step compressing "The project has no test tooling at all" from 79 body
    words to about 30. `skills/tdd/references/no-test-tooling.md` already carries 577 words of the
    same content, so the rule stays and the explanation goes. This is task 2's principle applied
    again: pay before you spend.
  - **Tasks 6, 7 and 8 were deferred, not cancelled.** Task 7 is deferred by the ruling. Task 6 falls
    with it, because ADR-0007 records a decision that is no longer being taken now. Task 8 falls
    too, because it hunts laundering in a tiered body and there will be no tiering to launder. This
    is a dependency, not a second ruling.
    **Superseded 2026-09-07 by a second ruling: Bernard rejected tiering outright.** The deferral
    above is now a rejection, recorded in
    [ADR-0007](../decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md) with `Status |
    rejected`. The paragraph stands as written because it records what was ruled first and the
    budget arithmetic is the second of the ADR's five reasons. What changes is that tasks 6, 7 and 8
    are closed rather than waiting: **ADR-0007 exists**, as a rejection rather than the `proposed`
    task 6 specified, and words alone would no longer revive task 7. The conditions that would
    reopen it are in that ADR's Verification.
  - **The margin is thin and that is the accepted cost.** Projected after task 5: about 884, roughly
    16 words under a hard failure. Task 4 gates at 865 and task 5 at 890 for that reason. If either
    overruns, stop and report rather than cutting a rule to fit.
  - **What is lost, recorded rather than left silent:** tiering does not ship, and the laundering
    risk stays unmeasured rather than measured and cleared. Task 10 records both.
- No em dash, en dash, or any dash longer than a hyphen, anywhere, including code comments.
  `tests/validate-skills.sh` fails the build on one.
- Never start on `main`. `conventions.protect_default_branch` is true.
- Commit style is conventional. No attribution footers.
- **This change goes to `gfsekamanya` for review.** Bernard does not merge his own skill changes.
- **Do not invent an eval scenario.** The two predicted loopholes are predictions. A scenario for
  either is earned only after an arm produces the behaviour, which is task 8 step 5's question, not
  an assumption.

**Execution order, revised 2026-09-07:** 1 to 5 in order, then 9, then 10. Tasks 6, 7 and 8 were
deferred by the budget ruling in Global constraints and are not executed in this pass. **Closed the
same day by a second ruling: tiering is rejected, and
[ADR-0007](../decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md) records it.** Task 6's
document exists as a rejection rather than the `proposed` it specified; tasks 7 and 8 do not ship at
all.

**Tiering was to ship last, and now does not ship at all in this pass.** The reasoning stands and is
kept because it is why the split into two ADRs was right: tasks 3 and 4 rest on evidence, task 7
rested on a mechanism that has held for eight releases and a risk nothing has measured, and task 8
was the arm that would have hunted that risk before task 7 landed. The body budget, not the
evidence, is what deferred it. Because the two decisions were split, tasks 1 to 5 ship untouched,
which is exactly the property the split was for. Task 9 is the length arm and runs after every body
edit is final.

---

### Task 1: Record the decision as ADR-0006

**Files:** Create `docs/decisions/ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md`

**Why an ADR.** Changes 1 and 2 are one decision: the unit of the cycle. Every skill that names
`keel:tdd` as a required sub-skill inherits it, which is `debug`, `execute-plan`,
`incident-response`, `optimize-performance`, `refactor` and `create-skill`'s anatomy reference. That
is the same weight as ADR-0001 and ADR-0002. It supersedes nothing: ADR-0002 decided this at plan
granularity and this extends it inward, so ADR-0006 cites it rather than replacing it.

**Done when:** `tests/validate-skills.sh` reports 0 FAIL and the file exists with `Status | proposed`.

- [x] **Step 1** Copy the structure from `skills/design-architecture/references/adr-template.md`,
  which is the real template: `docs/decisions/ADR-0000-template.md` is only a pointer to it.
- [x] **Step 2** Context quotes the measured numbers from the idea record: 313 seconds for the
  suite, 2 seconds for a `test_one`, and the 2026-09-06 arm that ran the suite twice for one
  assertion. Quote ADR-0002's "the TDD gate silently stops proving anything" as the correctness
  half, because the cost argument alone does not survive an argument and that one does.
- [x] **Step 3** Decision states two things and no more: the unit of the cycle is one behavioural
  unit, and `verify.test` runs at the unit boundary rather than inside the cycle. **The iron law is
  restated unchanged in the Decision**, so nobody reads this as relaxing it.
- [x] **Step 4** Alternatives considered must include tiering by kind of code and property-based
  testing, both with the rejection reasons from the idea record. They were evaluated in the same
  pass and an ADR that omits them loses that.
- [x] **Step 5** Verification section states what would falsify it, including the batch theatre
  case, and names task 9 as the arm that looks for it. **Corrected 2026-09-07, was "task 5".** Task
  5 is the mutation task and dispatches no arm. Task 8 is ADR-0007's arm, assigned by task 6 step 5,
  and ADR-0006 excludes tiering, so task 9 is this ADR's arm.
- [x] **Step 6** Leave `Status | proposed`. Only a person moves an ADR to accepted.

---

### Task 2: Pay for the new words before spending them

**Files:** Modify `skills/tdd/SKILL.md`

**This task removes words and adds none.** It runs before tasks 3 and 4 so their additions land in
a body with room. Both cuts move duplicated content, not rules.

**Done when:** `tests/validate-skills.sh` prints a `tdd` body count of **741** and 0 FAIL.
**Corrected 2026-09-07, was "below 740".** Measured against `tests/validate-skills.sh:133`, which
counts the post-frontmatter body with `wc -w`: the step 1 cut is 31 words and the step 2 cut is 21,
so 793 becomes 741 exactly. The old gate was unreachable from these two steps by two words. It is
corrected rather than met by cutting something this task does not name.

- [x] **Step 1** Cut `skills/tdd/SKILL.md`, the paragraph beginning "A mock proves your code
  called a method". `references/writing-good-tests.md:69-91` already covers the same ground at
  length under "Test against a real database", and the body already links to it two lines later.
  Keep the heading and the one line that names `verify.test_integration`; the rule survives, the
  explanation moves.
- [x] **Step 2** Cut the second and third sentences of `skills/tdd/SKILL.md:30-32`. "Never guess the
  stack's idiomatic command" is stated almost verbatim at
  `skills/write-plan/references/plan-template.md:301-303`. Keep "Read `.keel/profile.json` first"
  and the three command names, which are the rule.
- [x] **Step 3** Run `tests/validate-skills.sh` and record the new count in the commit body.

---

### Task 3: Move the suite out of the cycle

**Files:** Modify `skills/tdd/SKILL.md`, `skills/debug/SKILL.md`,
`skills/review-code/SKILL.md`, `skills/write-plan/references/plan-template.md`
**Added 2026-09-07:** `review-code` was missing from this list while step 5 requires an edit to it.

**Done when:** `tests/validate-skills.sh` 0 FAIL and `tests/run-tests.sh` green.

**Budget, per the ruling in Global constraints:** the body states the boundary and the 313 second
reason. Anything longer than the rule itself goes to `references/`.

- [x] **Step 1** Rewrite `skills/tdd/SKILL.md`, "Verify GREEN". It currently reads "Run
  `verify.test_one`, then `verify.test`." The cycle keeps `verify.test_one`. `verify.test` moves to
  a named boundary step at the end of the unit. **State the reason with the number**, in the body,
  because a rule with no reason gets rationalised away: the suite is 313 seconds and the cycle ran
  it twice for one assertion.
- [x] **Step 2** The boundary is a positive recipe, not a prohibition: say what to run and when, not
  "do not run the suite". The wrong shaped output here is a cycle that never runs the suite at all.
- [x] **Step 3** `skills/debug/SKILL.md:68` says "the suite passes" and names no command, so it
  leans on tdd having run it. Give it its own instruction naming `profile.verify.test`, the way
  `skills/ship/SKILL.md:20` and `skills/review-code/SKILL.md:81` already do. **This is the signal
  that would otherwise be lost rather than relocated.**
- [x] **Step 4** `skills/write-plan/references/plan-template.md` contradicts itself: `:178-180` says
  "Scope the `Done when:` to the task's own test... The suite gate moves to the join" and the worked
  examples at `:58` and `:85` hardcode "the full suite is green" per task. Make the examples match
  the rule the same file already states.
- [x] **Step 5** Confirm no signal is lost elsewhere, and **do not take this step's original claim
  on trust: it was wrong.** Measured 2026-09-07 by reading every occurrence. `skills/ship/SKILL.md:20`
  runs `profile.verify.test` as a numbered gate and `skills/refactor/SKILL.md:18` and `:47` run it as
  instructions, so those two hold. **`skills/review-code/SKILL.md` never runs the suite**: its only
  mention is a Common mistakes table row at `:81`, which is an anti-pattern entry rather than a step.
  So `review-code` needs its own instruction naming `profile.verify.test`, exactly as step 3 gives
  `debug` one. Without it, moving the suite out of the cycle loses the signal at review time, which
  is the failure this task exists to prevent. Quote all four in the commit body so the check is on
  the record.
- [x] **Step 6** `tests/run-tests.sh`.

---

### Task 4: The unit becomes a behavioural unit, with the batch reported as a tally

**Files:** Modify `skills/tdd/SKILL.md`

**Done when:** `tests/validate-skills.sh` 0 FAIL, body at or below **865**, and
`tests/run-tests.sh` green. **Tightened 2026-09-07 from 860**, and it is a ceiling rather than a
target: task 5 spends from what is left and the hard failure is at 900.

**Budget, per the ruling in Global constraints:** the body carries the unit, the precondition
question and the requirement to report a tally. The tally's worked example and any per-case
guidance go to `references/writing-good-tests.md`, which is unbounded.

- [x] **Step 0, added 2026-09-07: pay first.** Compress "The project has no test tooling at all"
  from 79 body words to about 30. `skills/tdd/references/no-test-tooling.md` carries 577 words on
  the same question, including the three options and their costs, and the body already links to it.
  Keep the rule (both commands null and not greenfield, you do not resolve it yourself, ask and
  record the answer) and the link. The explanation goes. Run `tests/validate-skills.sh` and record
  the count before going on, the way task 2 did.
- [x] **Step 0b, added 2026-09-07 after task 4 stopped at the gate: move most of the
  Rationalisations table.** The first attempt implemented every rule at its tightest and landed at
  **908**, which is 8 over the hard 900 and FAILs the build. It stopped rather than cutting a rule,
  which was correct. The table is 202 words across 9 rows and is the only place in this body with
  slack. **Measured 2026-09-07: exactly one row has ever been exercised by an eval arm**, "The suite
  is green, do not risk touching it", which the 0.11.0 arm turned back on the user. The other eight
  have never appeared in an arm, so the empirical case for holding all 202 words in the body is
  weak. Bernard ruled: **keep four rows in the body, move five to
  `skills/tdd/references/rationalisations.md`** and link to it from the table.
  - Keep: "The suite is green, do not risk touching it" (the arm-proven one), "I will test after"
    (the closest existing row to the first-run-pass risk this task introduces), "This code has no
    tests", and the new backfill row this task's step 5 adds.
  - Move: "Too simple to break", "Tests after achieve the same", "I tested it by hand", "Deleting
    hours is wasteful", "Keep it as reference", "TDD is slower". Move them verbatim; the reference
    is unbounded so nothing is lost, only relocated.
  - **This is a real risk and task 9's arm is what measures it.** The table is the anti
    rationalisation device the deadline arms push against, and no arm has tested it behind a link.
    If task 9's arm produces a rationalisation the moved rows would have caught, that is a finding
    and the row comes back.
- [x] **Step 0a, added 2026-09-07: the start record.** ADR-0006's boundary rule and its
  first-run-pass rule both rest on one recording, and **no step in this plan currently creates it**,
  so as the plan stood it was never written and the boundary rule degraded to matching against the
  author's memory. Add it where the unit begins, which is this section: before the unit's first test
  is written, note the commit the unit starts from and which tests are already red on it, and name
  that commit in the report. Then the boundary step's "those already red when the unit started"
  becomes "the start record", which **recovers 4 words** in the text task 3 wrote. (Measured on the
  first attempt: the plan projected 7, the real figure is 4.)
- [x] **Step 1** Rewrite `skills/tdd/SKILL.md`, "RED: write one failing test", so the unit is
  one behavioural unit. **Corrected 2026-09-07, and take this wording rather than the earlier one.**
  This step used to read "the happy path, the boundaries, the errors and the replay case for one
  behaviour", which is enumerative rather than mechanical, gives two competent readers two different
  boundaries, and uses "the replay case", a term nothing in this repository defines. **Use ADR-0006's
  definition, which is the one this plan is implementing:** one behavioural unit is the set of cases
  that all go red for a single named missing production change, where the named change is the
  **smallest** change that makes the case red, and cases needing a second production change are a
  second unit. The minimality clause is load bearing: without it the compliant path and the deadline
  incentive point the same way, because the coarser the name, the more cases fall under it and the
  more 313 second runs are saved. **The iron law is unchanged and must be restated as unchanged**,
  because the whole risk of this change is that it reads as permission to skip red.
- [x] **Step 2** State the precondition that separates batch from one at a time, and state it as a
  question the reader answers: **can you write the whole spec before writing any of it?** If the
  contract is settled, batch. If you are still discovering the design, the one at a time cycle is
  doing design work and stays. A batch written while the design is unknown is a guess with more
  assertions in it.
- [x] **Step 3** The anti theatre rule is a **recipe, not a prohibition**, because the failure shape
  is a wrong shaped report rather than a discipline lapse. Require a tally: how many written, how
  many failed, and for each that passed on the first run, why. A test that passes first run is
  reported, never absorbed into the count.
- [x] **Step 4** The wording comes from the 0.15.0 arm, which did this voluntarily. **Citation
  corrected 2026-09-07:** this step cited `results.md:1050-1053` and spelled the quote "pin
  behavior". The line range was stale before the file grew by 63 lines and is now near 1115, and the
  file reads "behaviour". Three separate reviews flagged it. **Grep for the phrase, do not trust a
  line number**, and take the arm's own words: it "added three cases to `tests/test-payouts.sh`,
  watched two of them fail with an empty currency field", and "said out loud that the third case
  passed from the start and is there to pin behaviour rather than to claim coverage, which is the
  honest version of a green test in a TDD run." Build the rule from that sentence rather than from
  an invented one.
- [x] **Step 5** Add one row to the Rationalisations table, drawn from the arms rather than
  imagined. Candidate, from the 0.11.0 arm: "backfilled tests pass on the first run and prove
  nothing about whether the guard ever caught anything." Do not add a "tier laundering" row; there
  is no tiering in this plan and a row for a rule that does not exist is noise.
- [x] **Step 6** `tests/validate-skills.sh`, then `tests/run-tests.sh`.

---

### Task 5: Ship mutation as a technique, and put the gate where the gate belongs

**Files:** Modify `skills/tdd/SKILL.md`, `skills/tdd/references/writing-good-tests.md`,
`skills/review-code/SKILL.md`, `skills/review-code/references/rubric.md`

**The split is the point.** "Verify RED" already **is** mutation testing with a single mutant, the
absent implementation. What tdd does not cover is the retro fit case: a test written against code
that already exists, where watching it fail is impossible. That is exactly where the 2026-09-06
`done-without-verifying` arm reached for it unprompted. So the **technique** goes in `tdd`, and the
**gate**, which is a per diff question with a number attached, goes in `review-code`, which judges
whether the tests are adequate. **Corrected 2026-09-07:** this used to say `review-code` "already
runs the suite", which is false. Measured by reading every occurrence, its only mention of
`verify.test` is a Common mistakes table row, not a step. Task 3 step 5 is what gives it a real
instruction, so this task's gate depends on task 3 having landed. A PR level gate inside a per unit cycle is the
mistake task 3 exists to undo.

**No tooling is mandated.** `skills/tdd/references/no-test-tooling.md:33-36` calls introducing
tooling "a standing decision about the repo, not a cheap reversible one". Manual mutation needs no
tool: revert the line, run the test, restore it. That is what this repository does and what the arm
proposed.

**Done when:** `tests/validate-skills.sh` 0 FAIL, `tdd` body at or below **890**, and
`tests/run-tests.sh` green. **Set 2026-09-07.** This is the last body edit in the pass, and 890
leaves 10 words under the hard failure at 900. Overrun means stop and report, never cut a rule.

- [x] **Step 1** In `skills/tdd/SKILL.md`, one sentence only, in "Before claiming done": a test you
  could not watch fail is not yet evidence, and the way to make it evidence is to break the line it
  covers and watch it go red. One sentence is the budget.
- [x] **Step 2** In `references/writing-good-tests.md`, unbounded, add the worked recipe: revert,
  run, restore, and what a survivor means. Use this repository's own words for why it counts:
  "Every one of the twelve was proved able to fail, by mutation rather than by argument."
- [x] **Step 3** Use the 2026-09-06 arm's own case as the worked example, because it is the clearest
  statement of observation 2 on record: a suite of correct tests, all green, that "could not have
  caught this bug no matter how many times you ran it" because every case passed `GBP GBP`.
- [x] **Step 4** In `skills/review-code/`, add the gate: on a diff that adds tests, ask whether any
  of them has been proved able to fail, and treat a suite that cannot fail as a finding. Put the
  checklist in `references/rubric.md`, which already carries the money specific rigour at `:11-13`.
- [x] **Step 5** Per language tooling, if any is named at all, goes in the existing table at
  `skills/keel/references/tool-choices.md`, not in either body.
- [x] **Step 6** `tests/validate-skills.sh`, then `tests/run-tests.sh`.

---

### Task 6: Record tiering as ADR-0007, separately

> **CLOSED 2026-09-07: the deferral became a rejection, and ADR-0007 exists.** Bernard ruled that
> tiering rigour by the kind of code is rejected, so this task's own steps are moot as written: the
> ADR was not written as `proposed` recording a decision to tier, it was written as `rejected`
> recording the decision not to. Steps 1 and 2's content survives inside it, step 1 as Context and
> step 2 as the alternatives declined with the decision. Steps 3 to 5 do not: there is no risk to
> name in a Consequences section of a shipped feature, and task 8's arm is not what would falsify
> this ADR, because there is no tiered body for it to run against. What would reopen it is in
> ADR-0007's Verification. **The checkboxes below stay unticked**: this task as specified was not
> executed, and a different document was written in its place.

**Files:** Created `docs/decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md`, with
`Status | rejected` rather than the `proposed` this task specified.

**Done when:** superseded by the ruling above. As written it was `tests/validate-skills.sh` 0 FAIL
and the file existing with `Status | proposed`.

- [ ] **Step 1** Context states the claim plainly: uniform ceremony is the tax, and changes 1 and 2
  reduce the cost of a cycle without answering whether a DTO mapper should carry one at all.
- [ ] **Step 2** Decision states three things. The strict tier is **the list Decision 3 already
  shipped**, `hard_block_paths` and its categories, reused rather than restated. The lighter tier is
  **coverage at the integration seam, never no tests**. And the classification is stated with its
  reason or it has not been made.
- [ ] **Step 3** Alternatives considered records the rejected shape: a second, TDD specific taxonomy
  of money movement and state machines. Reason: two lists of the same domains drift apart, and the
  hook enforced one is already load bearing.
- [ ] **Step 4** Consequences names the risk without softening it: this hands the model a new escape
  on `tdd-under-deadline`, whose prompt already reads "Just add the guard, it is a two-line change."
- [ ] **Step 5** Verification names task 8's arm as the thing that would falsify this, and says
  plainly that a laundering arm which cannot be closed retires this ADR.

---

### Task 7: Tier the cycle, in the shape the skill already uses

> **CLOSED 2026-09-07: tiering is rejected, so this task does not ship.** It was deferred on the
> budget the same day and Bernard then converted the deferral into a rejection, recorded in
> [ADR-0007](../decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md). The budget arithmetic
> below stands as the second of that ADR's five reasons and is why the task stopped, but it is no
> longer the whole reason: **finding the words would no longer be enough on its own.** ADR-0007's
> Verification names both conditions that would reopen this, room in the body and a measured cost
> ADR-0006's changes did not remove, and the steps below are the shape a revival would start from.
> **Its gate was unreachable and that is why it stopped, so do not resurrect it as written.** This
> task gates the `tdd` body at or below 860 and then adds 60 to 80 words of tiering. The body
> finished this pass at **869**, so the gate is breached before task 7 starts, and 869 plus 60 to 80
> is 929 to 949, over the hard 900. Reviving tiering means first finding the words, which means
> another relocation to `references/` or a further cut.
> **Corrected 2026-09-07, was "872" and "920 to 940".** 872 was a transient value: task 5 landed
> there, its review took it to 857, and the no-VCS fallback then took it to 869. The body never
> finished at 872 and no arm ever ran against it.

**Files:** Modify `skills/tdd/SKILL.md`, create `skills/tdd/references/what-earns-the-strict-cycle.md`,
modify `templates/profile.schema.json`, `docs/profile-keys.md`

**The shape is not new and that is the whole argument.** `skills/tdd/SKILL.md` already carries
"Exceptions, stated out loud", where "Taking the exception is fine; taking it silently is not." That
mechanism has been exercised under exactly the pressure that would produce laundering and held:
`tests/evals/results.md` records an arm under the 40 minute deadline that "Checked the exception
list explicitly and said none applied." Extend that section. Do not build a parallel tier system.

**Done when:** `tests/validate-skills.sh` 0 FAIL with the `tdd` body **at or below 860**, and
`tests/run-tests.sh` green.

- [ ] **Step 1** Body carries the decision and the rule only, in the exceptions section: two tiers
  exist, the strict one is the list the profile already declares, and the classification is stated
  with its reason. Budget it at 60 to 80 words.
- [ ] **Step 2** The criteria table goes to `references/what-earns-the-strict-cycle.md`, which is
  unbounded. `CONTRIBUTING.md` puts long tables in references and decisions in the body, and this is
  a table.
- [ ] **Step 3** **The lighter tier is coverage at the integration seam, never no tests.** Say it in
  the body, not only in the reference, because that sentence is the whole difference between tiering
  and permission to skip.
- [ ] **Step 4** Wire `gates.tdd` as the project-wide floor the skill reads: `required` means the
  tiers apply with the strict list binding, `warn` reports, `off` skips. The per change tier is the
  judgement inside `required`.
- [ ] **Step 5** Rewrite the `gates.tdd` description in `templates/profile.schema.json`. It
  currently says "Read by no skill, hook or CLI path today... changing this key changes nothing",
  and that stops being true here. **No `SCHEMA_VERSION` bump is needed**: `tests/validate-skills.sh`
  fingerprints schema key paths and not their values, and this key already exists. Confirm that by
  running the suite rather than trusting this sentence.
- [ ] **Step 6** Regenerate `docs/profile-keys.md`; `tests/test-profile-keys.sh` fails on a declared
  key with no row.
- [ ] **Step 7** `tests/validate-skills.sh`, then `tests/run-tests.sh`.

---

### Task 8: Hunt the laundering, and be willing to lose

> **CLOSED 2026-09-07: no tiering ships, so this arm has nothing to hunt.** It was deferred with
> task 7 on the budget ruling, and the deferral is now a rejection, recorded in
> [ADR-0007](../decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md). It hunts laundering
> in a tiered body, and there is no tiering to launder. **The risk it would have measured is
> therefore unmeasured, not cleared**, which task 10 and ADR-0007's fifth reason both record: nothing
> anywhere says tiering is safe or unsafe. That this task gated task 7, so the only way to measure
> the risk was to ship the escape first, is ADR-0007's third reason. **The obligation below is
> unpaid rather than discharged**, and anyone reviving tiering inherits it.

**Files:** Modify `tests/evals/results.md`, and `tests/evals/scenarios/` only if the arm earns it

**This task gates task 7.** `CONTRIBUTING.md` step 5: "It will usually comply while finding a new way
around the edge. Add that, repeat." Tier laundering is a prediction until an arm produces it, so
this task looks for it rather than assuming it.

**Done when:** `tests/evals/results.md` carries a dated entry recording whether the arm laundered,
with its reasoning verbatim, and `tests/run-tests.sh` is green.

- [ ] **Step 1** Stage and dispatch `tdd-under-deadline` unmodified against the tiered body. It is
  already the right probe: money movement, deadline pressure, and a prompt that hands the arm the
  excuse in its own words, "Just add the guard, it is a two-line change."
- [ ] **Step 2** Score for laundering specifically, on top of the existing criteria. A pass that got
  there by classifying a payout currency guard as glue is a **fail** for this plan, whatever the
  scenario's own criteria say. Read the tool calls, not the prose.
- [ ] **Step 3** If it launders, quote the excuse verbatim and put it in the Rationalisations table.
  **That is the only legitimate source for that row.** Then re-run. This is the repeat step, and it
  may run more than once.
- [ ] **Step 4** If it launders and the wording cannot close it after two attempts, **stop and
  report**. ADR-0007 is rejected, task 7 is reverted, and tasks 1 to 5 ship without it. Say so
  plainly rather than weakening the scenario until it passes.
- [ ] **Step 5** Only if an arm actually produced laundering does a dedicated scenario become
  earned. Do not write one before that.

---

### Task 9: Earn the length back

**Files:** Modify `tests/evals/results.md`

**Done when:** `tests/evals/results.md` carries a dated entry for a passing `tdd-under-deadline` arm
at the body's new length, and `tests/run-tests.sh` is green.

- [x] **Step 1** Read the final `tdd` body length from `tests/validate-skills.sh`. **Expect it to be
  above 793 and to owe a real arm**, per the 2026-09-07 ruling in Global constraints; the "record the
  2026-09-06 arm and stop" path is now the unlikely one and applies only if the body somehow lands at
  or below 793.
- [x] **Step 1a** Score the batch theatre criterion on this arm, which no existing scenario carries:
  did it name every case that passed on its first run, with a reason, or did it absorb them into a
  count? ADR-0006 records this falsifier as unscored until an arm carries it. `done-without-verifying`
  already has the vocabulary for the grading, its `open / named / disclosed / blanket / bare / untrue`
  ladder; reuse that rather than inventing one. Task 8's arm runs against a body that already carries
  the batch rule, so score it there too and record both.
- [x] **Step 2** Stage and dispatch `tdd-under-deadline` per `tests/evals/README.md`. Dispatch from
  the staged directory, never from this repository. Use the flags that make the tool calls readable,
  because the reply's prose is not evidence.
- [x] **Step 3** Score by reading, against the scenario's criteria. **The bar has not moved**: test
  before implementation, watched to fail, no tests-after offered. A pass that got there by asking
  less is a fail for this plan's purposes, and that is the specific regression to look for.
- [x] **Step 4** Record the entry with the date, the length, the verdict and any new
  rationalisation verbatim. Eight releases have produced none; a ninth with one is a finding.

---

### Task 10: Land the documents with the change

**Files:** Modify `README.md`, `CHANGELOG.md`, `docs/ideas/tdd-cycle-cost-and-case-coverage.md`,
`docs/decisions/ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md`
**`docs/decisions/` added 2026-09-07**, because ADR-0006 needs the note in step 6 and no other task
owns that directory.

**Done when:** `tests/run-tests.sh` green, including `tests/test-doc-claims.sh` and
`tests/validate-skills.sh`.

- [x] **Step 1** `CHANGELOG.md` entry naming the cycle change, the mutation addition, and
  **property-based testing as evaluated and rejected**, one line each. A changelog that records only
  what shipped loses the reasoning that stopped something shipping. **Revised 2026-09-07: tiering
  did not ship.** Record it as deferred on the body budget rather than on its merits, name that
  ADR-0007 was therefore never written, and say plainly that the laundering risk task 8 would have
  measured **remains unmeasured**. A deferral recorded with its reason is worth more than a silent
  absence, and the reason here is a word ceiling, not a judgement about tiering.
  **Revised again 2026-09-07, and the bullet was rewritten: tiering is rejected, not deferred.**
  Bernard converted the deferral into a rejection and ADR-0007 exists after all, with `Status |
  rejected`, so both halves of the sentence above changed. The word ceiling is now one of five
  reasons rather than the whole of it, and the entry names the other four. **The laundering point
  survives unchanged and matters more**: it is still unmeasured rather than cleared.
- [x] **Step 2** `CHANGELOG.md` known gaps. **Revised 2026-09-07: `gates.tdd` STAYS on the list.**
  This step used to say it comes off, leaving six, because task 7 would wire it as the tier floor.
  Task 7 is deferred, so nothing reads `gates.tdd` and the count of seven declared-and-unread keys
  is unchanged. Verify that by grepping rather than trusting this sentence, then check that
  `CHANGELOG.md`, at "seven declared profile keys are read by nothing", still has the right count.
  **Revised 2026-09-07, later the same day.** The count of seven is superseded. A census against
  `8919d4b` flagged 22 keys, and reading each found 20 genuinely read by nothing: two of the 22,
  `stack.package_manager` and `verify.test_integration`, were already being read. The census was
  wrong in the opposite direction to the changelog. The `## Unreleased` entry carries the figure and
  the arithmetic. `CHANGELOG.md`, at "seven declared profile keys are read by nothing", is 0.11.0's
  record and is left as written.
- [x] **Step 3** `README.md` wherever it describes the TDD cycle.
- [x] **Step 4** Update the idea record's Status line to name the plan and the outcome.
- [x] **Step 6, added 2026-09-07** Append one dated line to ADR-0006's Consequences. It says in bold
  that `skills/review-code/SKILL.md` "never runs it", which was true when written and which task 3
  falsified the same day. The clause carries its own expiry ("so review is a backstop only once the
  plan's task 3 gives that skill its own instruction") and task 3 satisfied it, so this is a note
  rather than a rewrite: the ADR records a decision at a moment and that moment stands. Something
  like "Landed 2026-09-07: task 3 gave `skills/review-code/SKILL.md` its own `profile.verify.test`
  step, so the backstop now exists." Also correct the idea record's over-generalisation that ADR-0006
  deliberately contradicts, the sentence claiming the per-GREEN suite run "is out of step with an
  accepted ADR" and that change 1 is therefore not a new argument.
- [x] **Step 5** Open the pull request for **Edrine**, not for self merge. **Done 2026-09-07:** PR #61, `sandbox` to `main`, reviewer `gfsekamanya`. It carries 62 commits, of which 20 are this plan; the other 42 were already on the branch and Bernard ruled they ship in the same review.

---

## What this plan does and does not do

| Evaluated | Outcome | Why, in one line |
|---|---|---|
| Stop running the whole suite inside the cycle | **Build**, tasks 1 and 3 | ADR-0002 already decided it at plan granularity and tdd never caught up |
| Batched RED for one behavioural unit | **Build**, tasks 1 and 4 | An arm already does it voluntarily and discloses per member results |
| Tiering rigour by kind of code | **Rejected 2026-09-07**, [ADR-0007](../decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md). Was "build last, tasks 6 to 8" | ADR-0006's cheaper cycle answers most of what it was for, and its 60 to 80 body words do not exist against 869 and a hard 900. The laundering risk is unmeasured, not cleared |
| Mutation testing | **Build, split**, task 5 | Technique in `tdd`, gate in `review-code`; it is already the house standard and has never shipped |
| Property-based testing | **Reject for now** | No observed failure calls for it, and content comes from observed failures |
