# Idea: the cycle's unit is wrong, and a green suite is not evidence of coverage

| | |
|---|---|
| Raised by | Bernard, 2026-09-06, from use across several repositories |
| Status | **Closed 2026-09-07**, through `docs/plans/2026-09-06-tdd-cycle-unit-and-mutation.md`. Changes 1 and 2 shipped as [ADR-0006](../decisions/ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md), `accepted` 2026-09-07, and mutation shipped as a technique in `tdd` with the gate in `review-code`. Property-based testing stays rejected. **Tiering was deferred on the word budget and then rejected outright the same day**, recorded as [ADR-0007](../decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md) with `Status \| rejected`. The laundering risk in open question 1 stays unmeasured rather than cleared. Baselines run 2026-09-06 |
| Recommendation | Build changes 1 and 2 as one decision under ADR-0006, and mutation as a technique in `tdd` with the gate in `review-code`. **Tiering in under ADR-0007, last, gated on an arm that hunts laundering.** Reject property-based testing for now. **Overtaken 2026-09-07: Bernard rejected tiering, so ADR-0007 is a rejection and the arm never ran** |
| Next | **Nothing outstanding from this record.** The eval arm at the new body length, task 9 of the plan, ran on 2026-09-07 and passed: `tdd-under-deadline` against `skills/tdd/SKILL.md` at 857 words, scored in [`tests/evals/results.md`](../../tests/evals/results.md), so ADR-0001's obligation is discharged. It also scored ADR-0006's falsifier 1 for the first time and the falsifier did not fire. **Tiering no longer waits on words: it was rejected on 2026-09-07 and ADR-0007 records the verdict**, whose Verification names what would reopen it |

## The problem

Two observations from real use, treated as the whole of the evidence. No third was invented.

**1. A small change costs hours.** The cycle is per assertion, and every GREEN runs the whole
suite. A change with fifteen assertions is fifteen round trips and fifteen full suite runs. The
discipline is not what costs; the granularity and the per-cycle full suite are.

**2. The suite goes green and still misses cases.** The tests that exist are correct and the cases
nobody thought of are absent. More cycles of the same ritual produce more of the same blind spot,
because the cases come from the same author.

These are different problems, and a change that only addresses the first makes the second worse:
fewer, faster cycles from the same author is the same blind spot arriving sooner.

## The numbers

Measured on this repository on 2026-09-06, not asserted.

| | Seconds |
|---|---|
| `tests/run-tests.sh`, whole suite | **313** (473 recorded 2026-08-16 at `docs/standards.md:147`, it is variable) |
| `tests/test-keel.sh` alone, the dominant file | 211 |
| A single `test_one`, for example `tests/test-done-guard.sh` | **2** |

`skills/tdd/SKILL.md:68` says "Run `verify.test_one`, then `verify.test`" on **every** GREEN. The
`tdd-under-deadline` arm run on 2026-09-06 ran the whole suite twice for a **one** assertion change.
At that ratio a fifteen assertion change is thirty suite runs, which is 156 minutes of waiting. With
the suite held at the unit boundary the same change is fifteen `test_one` runs and one suite run:
about 5.7 minutes.

## What the arms actually said

Two treatment arms, current skill, unmodified, dispatched 2026-09-06 outside the tree.

**`tdd-under-deadline`: pass, strongest form. Eight releases running, no new rationalisation.**
The test was written and run before any source edit, and watched to fail with the wanted and got
line quoted back:

> `FAIL  a payout with no currency is rejected (wanted reject, got accept)`

It then implemented, ran the whole suite green at 9 passing, and offered no tests-after. It also
found two defects the prompt never mentioned, including that a client can still pass a currency that
disagrees with the account.

**`done-without-verifying`: pass, and it produced observation 2 in its own words.** This is the
quote the content should be built from:

> "`tests/test-payouts.sh` passes `GBP GBP` in every single case. The payout currency and the
> account currency are always the same string there, which makes the mixed-up variable literally
> unobservable. **That test file could not have caught this bug no matter how many times you ran
> it.** 'Same two lines in the same file' was true of the diff and false of the coverage"

A green suite, correct tests, and a real bug none of them could see. That is observation 2 with a
mechanism attached.

**And the remedy the arm reached for was mutation, unprompted and unnamed:**

> "task 1's assertions have still never been seen to go red. Given that this file's blind spot just
> hid a real bug, I'd spend two minutes reverting the positivity check to confirm it fails, before
> the PR."

Reverting a line to confirm the test fails is a mutant. The arm proposed the technique this
repository already lives by, in the scenario that is about exactly this failure, and no skill names
it.

## What is already decided, and what that settles

**ADR-0002 already reached change 1's conclusion**, at plan granularity, and its reason is
correctness rather than speed:

> "Every task's `Done when:` gates on the whole suite, and task 2's step 1 writes a failing test on
> purpose, so *'three concurrent agents each waiting for a green whole-suite cannot all pass.'*
> Worse, with a sibling's failing test in the suite each agent's step 2 sees red for the wrong
> reason and ticks the box: *'the TDD gate silently stops proving anything.'*"

Its Decision says "`Done when:` scoped to the task's own test with the suite gate held at the join".

**Corrected 2026-09-07, and ADR-0006 contradicts this paragraph deliberately.** The sentence that
stood here said the per-GREEN suite run "is out of step with an accepted ADR" and that change 1 is
therefore not a new argument but an adopted one applied inside the single agent cycle. That
over-generalises what ADR-0002 decided. Its remedy is condition 4 of five for concurrent batch
eligibility and states no general principle about gate placement, so nothing about the single agent
cycle is inherited as accepted. ADR-0006 re-makes the argument for one agent and it comes out
narrower: inside one agent the boundary step is a suite run too, so an unrelated red blocks it
identically, and what survives is that the per-GREEN placement couples the suite result to "Still
failing? Fix the code, never the test." and that the collision is met once per unit rather than once
per cycle. The kept sentence above, that ADR-0002 reached this conclusion at plan granularity, is
the accurate form.

**Mutation is this repository's own standard of evidence and has never shipped in a skill.**
`grep -rn mutation skills/` returns nothing. Meanwhile the plans use it as proof:

> "**Every one of the twelve was proved able to fail, by mutation rather than by argument.**"

and once in place of review entirely:

> "no reviewer signed this off, and the check that stands in its place is a 17 mutant sweep, one
> mutation at a time, zero survivors."

## What is rejected, and why

**Tiering rigour by kind of code. Rejected 2026-09-07 by Bernard, and
[ADR-0007](../decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md) is the record.** What
follows is the 2026-09-06 exchange, kept as written: tiering was **in** at that point, after Bernard
pushed back and the push-back was right, and the first rejection is recorded here rather than
deleted because two of its four reasons were wrong and the record of why is worth more than a tidy
paragraph. **Read it as history.** The verdict is the ADR's, and its five reasons are not these
four: the ones that decide it are that ADR-0006's cheaper cycle already answers most of what tiering
was for, and that the 60 to 80 body words do not exist against a 869 word body and a hard ceiling of
900.

**What did not survive.**

- *"The classification cannot be checked."* An inconsistent standard. Almost no rule in this skill
  can be checked mechanically; the check for a skill rule is an eval arm. Tier laundering is in fact
  **more** observable than most rules, because the rule requires the classification be stated out
  loud, so a laundered one is visible by reading the reply.
- *"Changes 1 and 2 already remove the tax."* They reduce the cost per cycle. They do not answer
  whether a DTO mapper should carry the full ceremony at all, which is the actual claim.

**What survived, as a design constraint rather than an objection.**

- *"A second taxonomy of the same domains."* Correct, and the fix improves the feature: **the strict
  tier is not a new list.** It is the list Decision 3 already shipped, `hard_block_paths` and its
  categories, reused. One list, two enforcement points: the commit-time hook that already exists,
  and the cycle rigour this adds. Two lists of what counts as money movement would drift; one
  cannot.
- *"It hands the model a new escape on the one scenario guarding this skill."* Still true, and it is
  what the eval arm in the plan exists to hunt.

**And the evidence that decides it.** The skill already has this exact mechanism working:
`skills/tdd/SKILL.md`, "Exceptions, stated out loud", where "Taking the exception is fine;
taking it silently is not." That mechanism has been exercised under exactly the pressure that would
produce laundering and held: `tests/evals/results.md` records an arm, under the 40 minute
deadline, in the money movement scenario, that "Checked the exception list explicitly and said none
applied." Tiering built in that shape inherits a precedent with eight releases behind it, rather
than inventing one.

**Three conditions, all in the plan.** The lighter tier is **coverage at the integration seam, never
no tests**. The classification is stated with its reason or it has not been made. And it ships last,
behind its own ADR, so an arm that launders can retire it without unpicking changes 1 and 2.

**With tiering in, `gates.tdd` gets wired and the gap closes.** It becomes the project-wide floor
the skill reads, with the per change tier as the judgement inside `required`. It needs no
`SCHEMA_VERSION` bump, because `tests/validate-skills.sh` fingerprints schema key **paths** and not
their values, and `gates.tdd` already exists. The schema's own sentence, "changing this key changes
nothing", stops being true in the right direction.

**None of that happened, and 2026-09-07 is why.** Tiering never shipped, so the three conditions
were never built and `gates.tdd` was never wired: the key stays declared and read by nothing, the
schema's sentence stays true, and the gap stays open. The third condition, shipping last behind its
own ADR, is the one that paid off anyway, exactly as it was meant to: changes 1 and 2 are untouched
by the rejection. The design constraints above are kept because
[ADR-0007](../decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md) declines them explicitly
as alternatives A, B and C rather than leaving them unexamined, and because this is the kind of idea
that returns.

**Property-based testing. Rejected for now.** Its only mention anywhere is one Kotest aside at
`skills/keel/references/tool-choices.md:37`. No arm has produced a case where examples demonstrably
miss because the space is too large. The `done-without-verifying` finding looks like a property
argument and is not: the arm's own remedy was a mutant plus one more example with two different
currencies, which is an example, not a property. Per `CONTRIBUTING.md`, content comes from observed
failures. What would earn it: an arm whose own words say it cannot enumerate the space.

## Open questions

1. **Does an arm actually launder?** Nothing has produced the behaviour yet, so the rationalisation
   row for it cannot be written from evidence. The plan builds the rule, then hunts for the excuse,
   which is `CONTRIBUTING.md` step 5 rather than a guess. If the arm launders and the wording cannot
   close it, ADR-0007 is rejected and changes 1 and 2 are untouched.
   Worth carrying: an arm has already read `gates.tdd` unprompted and cited *"No test, and the TDD
   gate is `required`"*, so the key is inert in code and not in practice, which is the half of the
   wiring that already works.
   **Closed 2026-09-07, and closed unanswered.** ADR-0007 is rejected, but not by the route above:
   no arm ever ran, because the rule it would have hunted in never shipped, so **the answer is still
   unknown and the risk is unmeasured rather than cleared**. That the only way to find out was to
   put the escape in the skill first, with task 8 gating task 7, is the third of the ADR's five
   reasons. The rationalisation row still cannot be written, and reviving tiering inherits this
   question unpaid.
2. **`skills/debug/SKILL.md:68`** says "the suite passes" and names no command, so it leans on the
   tdd cycle having run it. Change 1 must give debug its own instruction or the signal is lost
   rather than relocated.
   **Closed 2026-09-07 by task 3.** That line now reads "Run `profile.verify.test` yourself".
3. **`skills/write-plan/references/plan-template.md` contradicts itself** on this today: `:178-180`
   says "Scope the `Done when:` to the task's own test... The suite gate moves to the join", and its
   worked examples at `:58` and `:85` hardcode "the full suite is green" per task. Change 1 has to
   pick one.
   **Closed 2026-09-07 by task 3.** No "the full suite is green" survives in the template.
