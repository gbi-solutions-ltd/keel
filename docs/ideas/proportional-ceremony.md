# Idea: make the ceremony around a change proportional to its risk, and keep the tests

| | |
|---|---|
| Raised by | Bernard, 2026-10-16, under client pressure: competitors deliver features faster, and colleagues report fast turnaround from Claude Code's own planning followed by a review where needed |
| Status | closed: part 2, the proportional review loop, is built by `docs/plans/2026-10-16-proportional-review-loop.md` (commits `997b2be`, `1e47780` and the commit titled `feat(skills): the final review stops after one fix pass`). Part 3 is gap 1 of [delivery-flow-gaps.md](delivery-flow-gaps.md), not yet planned; part 1's instrument is gap 7, built, and the measurement itself is not taken |
| Recommendation | Build something smaller than a TDD waiver: measure where a feature's time goes, then make the review loop and the plan proportional to what a change touches. Leave TDD as ADR-0007 decided unless the measurement meets ADR-0007's own reopening condition |
| Next | None here. Part 3 continues as gap 1 of [delivery-flow-gaps.md](delivery-flow-gaps.md). Whether the measured lead time reopens ADR-0007 is for `keel plan report` numbers to say, in a new record |

## The problem

keel is slower to a delivered feature than a plain Claude Code workflow, and clients notice. Bernard
built keel to make delivery sturdy, so the question is which parts of keel's process buy stability
and which only cost time.

**Evidence.** The pressure is asserted from client conversations and is not measured. keel records
no time to delivery for any feature. One observation from 2026-10-14 is measured, and it points away
from TDD: `keel ci-review`'s refusal (`4ee1a35`, plan
`docs/plans/2026-10-14-ci-review-refuses-other-ci.md`) was a one-task plan. Its tests were written
first in one pass, red at 57 passed and 12 failed. What took the time was one implementer, three fix
passes and nine review dispatches over four rounds, most of them about remote URL shapes and message
wording. The coordinator also chose delegated mode for a one-task plan, where
`skills/execute-plan/SKILL.md` step 3 already allows inline, and ran fix rounds on findings that
`skills/execute-plan/references/subagent-prompts.md` says do not block a tick. So part of that cost
was the process as written and part was the coordinator going beyond it.

## What was asked for

> does keel currently have a way to waive TDD? like write a plan without considering TDD but rather
> bank on code-review and security-audit for verifications

> Honestly, TDD is slowing me down and I have pressure from clients because my competitors are
> delivering features faster. I want to produce stable code and it's why I started building Keel to
> ensure a sturdy process. Help me reason about this and maybe suggest possible alternatives.
> Colleagues tell me they use the existing Claude code planning feature and execution depends on
> that, then execute a review process where necessary and their TAT for features is quite fast

## The case against

**Strongest argument for not building this at all.** Most of it has already been decided.
[ADR-0007](../decisions/ADR-0007-rigour-is-tiered-by-what-the-code-does.md) rejected tiering TDD by
what the code does on 2026-09-07, on five reasons, and names the only two things that reopen it: a
measured cost that ADR-0006 did not remove, or room in the `tdd` body. Client pressure is neither.
[ADR-0006](../decisions/ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md) already made one cycle
cheaper by batching cases into a behavioural unit and running the suite once at its boundary. A
waiver built now would be the same idea ADR-0007 declined, with less evidence than it had.

**Second.** `review-code` and `security-audit` read code and run the suite that exists. Neither
writes a test. A review catches a defect once; a test catches its return on every later change. The
planted defect in `tests/plugin-evals/` (a net payout that adds the fee) passed a green suite and
was found only by review, which is the case for a test that pins it, not against one.

**Third.** A fast lane is the lane people pick. Any proportional scheme needs a classification that
is expensive to launder, and ADR-0007's reason 3 says that risk cannot be measured without shipping
it.

## What the system says

- **TDD has one exception path.** `skills/tdd/SKILL.md`, "Exceptions, stated out loud": a throwaway
  spike, generated code or pure configuration, named with its reason. The iron law is "NO PRODUCTION
  CODE WITHOUT A FAILING TEST FIRST".
- **Plans assume it.** `skills/write-plan/references/plan-template.md` heads every plan with
  "REQUIRED SUB-SKILL: `keel:tdd` for every task", and `skills/execute-plan/SKILL.md` step 4 says
  the same. A step can be ticked `--not-applicable <reason>`, which records a skip and is not a
  waiver anything else reads.
- **Review checks the order.** `skills/review-code/references/rubric-pass.md` questions 3 and 5 ask
  whether tests came first and whether any was shown able to fail, through a revert check.
- **The review loop is two passes per task.** `skills/execute-plan/references/subagent-prompts.md`:
  spec compliance, then code quality. A DEVIATES verdict or a blocking finding discards the attempt
  and re-dispatches a fresh subagent; should fix and consider findings do not stop the tick. No ADR
  fixes the number of passes: [ADR-0002](../decisions/ADR-0002-delegated-execution-default.md)
  decides that delegation is the default and that the coordinator writes no production code.
- **Inline is allowed for small plans.** `skills/execute-plan/SKILL.md` step 3: "Inline is still
  right for a plan of one or two tasks", named in one line.
- **A risk list already exists.** `hard_block_paths` in `.keel/profile.json`, "Intended for auth,
  money movement, and personal data", enforced by `hooks/sensitive-guard`. ADR-0007's alternative A
  chose it as the only acceptable strict list, so no second taxonomy is needed.
- **`ship` requires tests and a review**, not their order: `skills/ship/SKILL.md` steps 1, 2 and 5.

## The design

Three parts, independent, in the order they should be decided.

**1. Measure before changing TDD.** Time three to five real features on code outside
`hard_block_paths`, split into plan, test cycle, implementation, review rounds and fixes. If the
test cycle is the dominant cost after ADR-0006, that is ADR-0007's first reopening condition, and
the revival starts from its alternative A (`hard_block_paths` takes the strict cycle, everything
else at least one test at the seam, never none) and owes the laundering arm ADR-0007 describes. If
the review loop or the plan dominates, parts 2 and 3 are the fix and TDD stays.

**2. A proportional review loop.** For a task whose diff touches no `hard_block_paths` path:

- one review pass, spec and quality together, instead of two;
- a blocking finding still blocks; should fix and consider findings go to the report, never to
  another round, which `subagent-prompts.md` already says and the coordinator must follow;
- after two blocking rounds on one task, stop and ask the user rather than dispatch a third.

A task touching `hard_block_paths` keeps both passes and the discard rule unchanged, and
`security-audit` stays required there through `gates.security_audit`.

**3. Plans in proportion.** A change of one or two tasks needs no plan file: Claude Code's planning,
or the request itself, is the contract, executed inline as step 3 already allows. A plan file stays
for anything larger, anything touching `hard_block_paths`, and anything with an ADR behind it. TDD
applies in both cases; what changes is the paperwork around it.

What the colleague workflow maps to under this design: plan in Claude Code, implement under `tdd`
(one behavioural unit at a time, suite at the boundary), one `review-code` pass, `ship`. The
difference from theirs is a test per behaviour and a review every time rather than where needed.

## Open questions

1. Is a single combined review pass enough outside `hard_block_paths`, or does the code quality pass
   catch things the spec pass does not often enough to keep both? The 2026-10-14 run had both passes
   find different problems in every round, which argues for keeping two where the code is risky.
2. Who decides a task is outside `hard_block_paths`, the diff or the plan? The diff is checkable;
   the plan is known before work starts.
3. What does a project with an empty `hard_block_paths` get? Probably the full loop everywhere until
   it declares the list, so that not configuring is not a way to go faster.
4. Should the measurement in part 1 be a keel feature (time per phase recorded in the plan
   by `keel plan tick`), or a one-off spreadsheet?

## Recommendation

**Build something smaller.** Do not add a TDD waiver: ADR-0007 decided that, and nothing here meets
its conditions yet. Measure first (part 1). Then build the proportional review loop (part 2) and the
plan-free path for small changes (part 3), both keyed to `hard_block_paths`. The one measured case,
2026-10-14, spent its time in the review loop, not the test cycle.

## Not decided here

- Whether part 1's measurement reopens ADR-0007. That is a new ADR superseding it, if the numbers
  say so.
- The exact wording of the combined review prompt, and whether it reuses the five spec questions.
- Whether `ship` should report which loop a change went through.
