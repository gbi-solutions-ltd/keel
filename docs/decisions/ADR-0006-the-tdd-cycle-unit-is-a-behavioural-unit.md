# ADR-0006: The TDD cycle's unit is a behavioural unit, and the suite runs at its boundary

| | |
|---|---|
| Status | accepted |
| Date | 2026-09-07 |
| Deciders | Bernard Tebandeke, accepted 2026-09-07, with `gfsekamanya` reviewing the skill change it authorises |
| Requirements | none; this governs keel's own TDD discipline |
| Supersedes | none. [ADR-0002](ADR-0002-delegated-execution-default.md) decided a narrower version at plan granularity and this extends it inward |

## Context

`skills/tdd/SKILL.md` runs the cycle once per assertion and ends every GREEN with "Run
`verify.test_one`, then `verify.test`." Measured on this repository on 2026-09-06 and recorded in
[the idea record](../ideas/tdd-cycle-cost-and-case-coverage.md): the whole suite,
`tests/run-tests.sh`, takes **313 seconds**; a single `test_one` such as `tests/test-done-guard.sh`
takes **2**.

The `tdd-under-deadline` arm dispatched on 2026-09-06 ran the whole suite twice for a **one**
assertion change. At that ratio a fifteen assertion change is thirty suite runs, about 156 minutes;
with the suite at the unit boundary it is fifteen `test_one` runs and one suite run, about 5.7
minutes. **The dominant force is a 156 to 1 ratio between the two runs the cycle treats as one
step.**

The cost argument alone does not survive an argument, and the correctness one does. ADR-0002 records
what a whole-suite gate inside a per-task cycle did to three concurrent agents: *"three concurrent
agents each waiting for a green whole-suite cannot all pass."* Worse, with a sibling's failing test
in the suite each agent's step 2 sees red for the wrong reason and ticks the box, so *"the TDD gate
silently stops proving anything."* That remedy, `Done when:` scoped to the task's own test with the
suite gate held at the join, is condition 4 of five for concurrent batch eligibility and states no
general principle about gate placement, so **nothing here is inherited as accepted.** The argument
is re-made for the single agent and comes out narrower.

Inside one agent, moving the gate does not dissolve the collision. The boundary step is a suite run
too, so a pre-existing unrelated red blocks it identically, and the author meets it with a whole
unit of edits in flight rather than one cycle's worth, which makes attribution harder. Two claims
survive. The per-GREEN placement couples the suite result to the body's next sentence, "Still
failing? Fix the code, never the test.", which points the author at code just written and definitely
not the cause; at the boundary that sentence is decoupled from the suite result. And the collision
is met once per unit rather than once per cycle.

**Held to this ADR's own standard of evidence, that claim is unobserved.** No arm in
`tests/evals/results.md` has ever been blocked by an unrelated red. The mechanism is read off the
skill body rather than seen, which is the standard on which property-based testing is rejected
below, so it is disclosed rather than asserted. The batching half is in the same position, read off
the body's "write one failing test" with one arm that batched voluntarily, rather than measured.
Only the cost half is measured. That is not in tension with the opening claim: correctness is what
justifies changing anything at all, and cost is the only leg on which the options below differ, so
cost is what discriminates between them. **And the obvious remedy for attribution is not this
decision:** recording which tests are already red when the unit starts resolves it outright and
costs one command. This ADR neither forecloses that nor replaces it.

## Decision

**The unit of the cycle is one behavioural unit, and `verify.test` runs at the unit boundary rather
than inside the cycle.** All the cases of one behaviour go into a single RED, written and watched to
fail together, rather than one cycle per assertion. One behavioural unit is the set of cases that
all go red for a single named missing production change, where **the named change is the smallest
change that makes the case red**, and cases needing a second production change are a second unit.
The minimality clause is load bearing. Without it the rule is relative to a name the author chooses,
and the coarser the name the more cases fall under it, so the compliant path and the deadline
incentive point the same way and every behaviour folded in saves a 313 second run. Which change is
smallest is read off the diff rather than off the naming. `verify.test_one` stays in every RED and
every GREEN, and the whole suite runs once when the unit is done.

**The iron law is unchanged and restated here in full: NO PRODUCTION CODE WITHOUT A FAILING TEST
FIRST.** Wrote code before the test? Delete it and start over. No exceptions. Batching changes how
many cases go red at once, never whether the cases that assert new behaviour were watched to fail
first.

## What the wording must carry

Two rules, without which the decision means something weaker than it says. Both rest on one
recording: at the unit's start, before its first test is written, note the commit or `HEAD` the unit
begins from and which tests are already red on it, and name that commit in the report. It costs one
command, and it is narrower than the standing red-start recording Context leaves open, which
resolves attribution outright. This one only fixes the point "before this unit" refers to, so the
author cannot redraw that point once the production code is in.

**A red boundary the unit did not cause.** When `verify.test` is red for tests this unit did not
touch, name them and match them against the start record. A unit whose every boundary red is named
and matched **is done**: the author records them and carries on rather than halting, and they stay
red as a separate unit's RED. Do not edit them, and do not edit this unit's code to make them green.
A boundary red the start record does not hold is one this unit caused, so the unit is not done; hand
it to `keel:debug`, whose Phase 1 says "for a test failure, run that test alone first", which is the
move here.

**A test that passes on its first run.** Legitimate for one thing only, a case that pins behaviour
which already exists, and **pre-existing means green against the commit named in the start record**,
not against a tree chosen after the production code is written. A case reported as pinning must name
the behaviour it pins and be one that would pass on that commit. That is checkable from the diff;
"already exists" is not. It is never counted toward the unit's coverage. For every other test the
red flag is untouched: `skills/tdd/SKILL.md` lists "Test passed first run" under "Red flags:
stop and start over" and says "Passed immediately? It tests existing behaviour." This ADR narrows
that red flag by one named exception, and the narrowing is stated rather than slipped through.

## Alternatives considered

### A: Tier the rigour by the kind of code

Money movement and state machines take the strict cycle; glue and DTO mappers take coverage at the
integration seam. It lost **here** because it answers a different question, whether a mapper should
carry the ceremony at all, rather than what the cycle's unit is, and because it carries a risk
nothing has measured: it hands the model a new escape on `tdd-under-deadline`, the one scenario
guarding this skill. It is deferred rather than refused, to ADR-0007, shipping last and gated on an
arm that hunts laundering, so a laundering arm can retire it without unpicking this decision.

### B: Property-based testing

State the invariant and generate the space instead of enumerating cases. It lost on evidence: no arm
has produced a case where examples demonstrably miss because the space is too large. The
`done-without-verifying` finding looks like a property argument and is not, since the arm's own
remedy was a mutant plus one more example with two different currencies, which is an example rather
than a property. No skill body mentions it; the single mention anywhere is a Kotest aside in a
reference file. `CONTRIBUTING.md` holds that content comes from observed failures. What would earn
it: an arm whose own words say it cannot enumerate the space.

**Why the chosen option won:** the dominant force is the 156 to 1 ratio and both alternatives leave
it standing. Tiering changes how often the ceremony applies, not what one turn of it costs;
property-based testing changes how cases are written, not where the suite runs.

## Consequences

**What becomes easier.** The fifteen assertion change costs about 5.7 minutes rather than 156. The
batch shape is not this ADR's invention: the 0.15.0 `tdd-under-deadline` arm added three cases in
one batch, watched two of them fail, and "said out loud that the third case passed from the start
and is there to pin behaviour rather than to claim coverage..." One arm doing that voluntarily is a
precedent, not a measurement, and it is the whole of the observed evidence for this half.

**What the words cost, and what they owe.** `skills/tdd/SKILL.md` is 793 words. The plan's task 2
frees exactly 52, a 31 word cut and a 21 word cut, measured against `tests/validate-skills.sh`,
which counts the post-frontmatter body with `wc -w`, leaving 741. The body-resident additions across
tasks 3 to 5 exceed that even with every recipe moved to `skills/tdd/references/`, because the
earlier estimate of 125 to 140 words omitted a new Rationalisations row and the mutation sentence,
both rules rather than recipes. **So tasks 3, 4 and 5 gate at 860 rather than 793, the body grows,
and task 9 pays for it by dispatching a real `tdd-under-deadline` arm at the final length rather
than recording the 2026-09-06 one.** Per ADR-0001 that arm is what the room is taken against. Open,
and flagged for measurement before task 6: ADR-0001's 900 is a hard FAIL in the validator rather
than a warning, and task 7's 60 to 80 tiering words land on a body at 860, which is roughly 920 to
940.

**What becomes harder.** A bad edit hides for a unit rather than a cycle, and attribution at a red
boundary is harder because more edits are in flight; both are accepted, and the boundary rule above
is what the second gets instead of a mitigation. The backstop is also thinner than it looks:
`skills/ship/SKILL.md` runs `profile.verify.test` as a numbered gate and `skills/refactor/SKILL.md`
runs it at two places, but **`skills/review-code/SKILL.md` never runs it.** Its only mention there
is a Common mistakes table row, an anti-pattern entry rather than a step, so review is a backstop
only once the plan's task 3 gives that skill its own instruction.

**Landed 2026-09-07: task 3 gave `skills/review-code/SKILL.md` its own `profile.verify.test` step,
so the backstop now exists.** The paragraph above stands as written, because it records what was
true when this decision was taken and it carried its own expiry condition, which task 3 satisfied
the same day.

**What this forecloses.** Little. Returning the suite to every GREEN is a one line edit, and the
red-start recording described in Context stays available.

**What must be true for this to keep working.** Every skill that reaches `keel:tdd` inherits this,
and the declarations differ: `skills/write-plan/references/plan-template.md` declares it as a
required sub-skill for every task, `skills/incident-response/SKILL.md` names it as a plain numbered
step with the `REQUIRED SUB-SKILL` label sitting on `keel:debug` instead, and
`skills/execute-plan/references/preconditions.md` mentions it only as the owner of the
no-test-tooling decision. All three inherit regardless. `skills/debug/SKILL.md` says "the suite
passes" and names no command, so it leans on the cycle having run one and needs its own instruction,
or the signal is lost rather than relocated.

## Verification

Three things would falsify this.

1. **Batch theatre.** A unit where the production code was written first and the cases afterwards,
   then reported as a batch in which some pin behaviour. The check is the one the rule above makes
   possible: a case reported as pinning that would not pass on the commit named in the unit's start
   record, or an arm that named no first-run passes when some passed.
2. **A regression reaching `main`** that the old per-GREEN run would have caught, meaning it got
   past the boundary run, ship's numbered gate and review. One caught at review is the accepted
   consequence above, not a falsifier.
3. **A red boundary met by editing the red tests** rather than by naming them as a separate unit.

**The arm that looks is task 9 of
[the plan](../plans/2026-09-06-tdd-cycle-unit-and-mutation.md)**, the length arm, which carries an
explicit batch theatre criterion. Task 8's `tdd-under-deadline` dispatch runs first, against a body
that already carries the batch rule, and scores the same criterion, so the criterion rides on both
dispatches and this record names no owner that cannot act. **The criterion is new**: no existing
scenario scores "named no first-run passes when some passed". Grade it with the disclosure ladder
`tests/evals/scenarios/done-without-verifying.md` already carries, `open`, `named`, `disclosed`,
`blanket`, `bare`, `untrue`, weakest last. Until an arm carries it, falsifier 1 is unscored and this
ADR is untested on that point.

**Task 8 was deferred 2026-09-07 on the body budget, so the criterion rides on task 9's dispatch
alone, which is outstanding.** The paragraph above stands as written: it records what was true when
this decision was taken, and the second dispatch it counted on is the one that went away.

**Scored 2026-09-07: task 9's arm ran and falsifier 1 did not fire, graded `named`.** The
`tdd-under-deadline` dispatch at 857 words passed, one of its three cases passed on its first run,
and the arm named that case, named the behaviour it pins and said it is "not new coverage" rather
than counting it. That is the first and only time this criterion has been scored, so the falsifier
is unfired rather than retired. The same arm did not follow the batching half: a case going red for
the same missing production change as the first was written after that change shipped, so the
disclosure rule caught what the unit rule would have prevented. Full scoring in
[`tests/evals/results.md`](../../tests/evals/results.md), 2026-09-07.

**Scored a second time 2026-09-07, at 869 words, and falsifier 1 still did not fire.** The scoring
arm is a probe rather than a scenario, reusing `tdd-under-deadline`'s staging with a replaced task,
and no scenario file was added. Four of its cases were written and run together; two failed and two
passed on their first run, and the arm named both by name, gave the behaviour each pins, said they
are green on the baseline and that "neither counts toward this unit's coverage". Graded `named`, the
same grade as the first scoring. The unmodified `tdd-under-deadline` re-run at 869 the same day is
**not** counted as a scoring occasion: it produced no first-run passes at all, so there was nothing
to name or to conceal. Both arms followed the batching half, which the 857 arm did not. Two scorings
are not a measurement and the falsifier stays unfired rather than retired. Full scoring in
[`tests/evals/results.md`](../../tests/evals/results.md), 2026-09-07, the 869-word entry.
