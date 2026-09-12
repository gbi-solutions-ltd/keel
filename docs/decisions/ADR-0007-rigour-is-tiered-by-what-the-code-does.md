# ADR-0007: Rigour is tiered by what the code does

| | |
|---|---|
| Status | rejected |
| Date | 2026-09-07 |
| Deciders | Bernard Tebandeke |
| Requirements | none; this governs keel's own TDD discipline |
| Supersedes | none |

## Context

The claim, stated plainly, is that **uniform ceremony is the tax**. `skills/tdd/SKILL.md` asks the
same cycle of a DTO mapper and of a payment path, and the proposal in
[the idea record](../ideas/tdd-cycle-cost-and-case-coverage.md) was to tier it: money movement takes
the strict cycle, glue takes coverage at the integration seam.

[ADR-0006](ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md) shipped the other two changes from
that record. The unit is now one behavioural unit, and `verify.test` runs at the unit boundary rather
than inside every GREEN. Those reduce **the cost of one cycle**. Neither answers **whether a DTO
mapper should carry a cycle at all**, which is tiering's actual question, and ADR-0006 says so in as
many words: tiering "answers a different question". So the question survived ADR-0006 rather than
being settled by it, and it was carried forward to this ADR, planned as `proposed`, with the skill
change in task 7 of [the plan](../plans/2026-09-06-tdd-cycle-unit-and-mutation.md) and a laundering
arm in task 8.

That is the decision now being taken, and it is taken against tiering.

## Decision

**Tiering rigour by the kind of code is rejected.** The cycle stays uniform: every behavioural unit
takes the same RED, the same watched failure and the same boundary run, whatever the code does. Five
reasons.

**1. The cost argument that motivated it is largely answered, and now measured.** The record's case
was that a fifteen assertion change is fifteen round trips and fifteen full suite runs at 313 seconds
each. ADR-0006 shipped both halves, and the two arms of 2026-09-07 at 869 words ran the new shape:
one wrote three cases together and one wrote four, each implemented once and each ran the suite at
the unit boundary rather than per GREEN. The cost of a cycle has already fallen, so tiering's premise
is weaker than when it was written.

**2. What tiering would still answer is narrower, and the body cannot carry it.** `skills/tdd/SKILL.md`
is **869 words** against ADR-0001's hard ceiling of 900, so there are **31 words of headroom** against
the 60 to 80 the plan's task 7 step 1 budgets for the body. Buying the difference means moving rules
the new cycle depends on. The sections with any slack are the RED block, which carries the unit
definition and the start record ADR-0006 rests on, and the Rationalisations table, already down to
four rows with the other six behind a link.

**3. The risk can only be measured by shipping it first, which is the wrong order for a discipline
skill.** Task 8 would dispatch `tdd-under-deadline` against the **tiered** body to hunt tier
laundering, and task 8 gated task 7. So the only way to learn whether tiering hands the model an
escape is to put the escape in the skill first. The idea record's surviving objection is that tiering
"hands the model a new escape on the one scenario guarding this skill", whose prompt already reads
"Just add the guard, it is a two-line change", and its open question 1 concedes that nothing has
produced the behaviour yet.

**4. keel already has this mechanism and it has held.** "Exceptions, stated out loud" says "Taking
the exception is fine; taking it silently is not." That is the shape tiering wanted, a classification
stated with its reason, and it is already shipped and already exercised under exactly the pressure
that would break it: an arm under the 40 minute deadline, in the money movement scenario,
"Checked the exception list explicitly and said none applied."

**5. Nothing was measured either way, and this ADR says so plainly.** No arm has ever produced tier
laundering, because no tiering ever shipped for an arm to launder. **The laundering risk is unmeasured,
not cleared.** This rejection rests on cost and on the word budget, not on evidence that tiering is
unsafe. Nothing here says tiering was tested and failed.

## Alternatives considered

These are the shapes that were evaluated and are declined with the decision. They are recorded
rather than dropped because this is the kind of idea that returns.

### A: The strict tier bound to `hard_block_paths`

The strict tier is not a new list. It is the one the profile already declares: paths matching auth,
session, token or credential; anything computing, storing or transmitting an amount or a currency;
card, account or personal identifiers; migrations and webhook signature verification; CI and secret
configuration. One list, two enforcement points, the commit-time `hooks/sensitive-guard` that exists
and the cycle rigour this would add. It is the best available shape and it still loses on reasons 2
and 3: the reuse costs nothing in correctness and does not reduce the 60 to 80 body words, and the
list being load bearing at commit time is what makes a laundered classification expensive rather than
cheap.

### B: The lighter tier as coverage at the integration seam, never no tests

Glue and DTO mappers get one test at the seam they are used through, rather than a cycle per case,
and never zero tests. That sentence is the whole difference between tiering and permission to skip,
which is why it was to sit in the body rather than only in a reference. It loses with A: the sentence
that carries the difference is itself part of the 60 to 80 words there is no room for, and a lighter
tier shipped without it is the failure mode, not a smaller version of the feature.

### C: A second, TDD specific taxonomy of money movement and state machines

A list written for this rule, naming the domains that earn the strict cycle. Rejected on 2026-09-06
and still rejected: two lists of the same domains drift apart, and the hook-enforced one is already
load bearing, so the drift would be silent in the direction that matters. This is the reason A exists
in the shape it does.

**Why the rejection won:** reasons 1 and 2 are the discriminating ones. A cheaper cycle removes most
of what tiering was for, and what is left costs twice the words the body has, against a ceiling that
is a hard FAIL in `tests/validate-skills.sh` rather than a warning.

## Consequences

**What is lost, and it is real.** Uniform ceremony stays. A DTO mapper carries the same cycle as a
payment path: the same start record, the same watched red, the same boundary run. That cost is real
and this decision does not address it. It is smaller than it was before ADR-0006 and it has not gone
away.

**`gates.tdd` stays declared and unread.** Wiring it as the project-wide floor was task 7 step 4 and
it does not happen, so the key remains one of the seven declared profile keys read by nothing that
`CHANGELOG.md` records, and that count is unchanged. `templates/profile.schema.json` keeps its
sentence that changing the key changes nothing, and it stays true.

**2026-09-07, later the same day: `gates.tdd` is retired rather than left declared.** The paragraph
above stands as the record of what this rejection decided, which is that no wiring happens. Retiring
the key does not reverse it. The reason is that "declared so the intent has somewhere to live once
something enforces it" is the sentence that left 20 keys read by nothing, and this ADR is a better
home for the intent than a schema field: the two conditions that would reopen the question are
already written down above. See `docs/plans/2026-09-07-declared-profile-keys-take-effect.md`.

**The laundering risk stays unmeasured.** There is no arm and there will be none, so the
Rationalisations table gains no tier laundering row. Per `CONTRIBUTING.md` that row could only have
come from an arm that produced the excuse, and none has.

**What becomes easier.** The 31 words of headroom stay available to rules the shipped cycle depends
on, and the RED block and the four remaining Rationalisations rows stay in the body rather than being
traded for a feature.

**What this forecloses.** Little. The idea is recorded here in full, and a future ADR that supersedes
this one starts from alternative A rather than from scratch.

**What must be true for this to keep working.** That the cheaper cycle keeps the cost of uniform
ceremony tolerable on code that does not move money, and that "Exceptions, stated out loud" keeps
holding under deadline pressure.

## Verification

Two things would reopen this, and either is enough.

1. **A measured cost that ADR-0006's changes did not remove.** An arm or a real change on
   non-money-movement code where the ceremony, after batching and the boundary run, is still the
   dominant cost of the change, with the numbers in `tests/evals/results.md` the way the 313 second
   suite and the 2 second `test_one` were measured. Cost asserted rather than measured is what this
   ADR already declined once.
2. **Room in the body.** A relocation or a cut that puts `skills/tdd/SKILL.md` at or below 820, so
   that 60 to 80 tiering words fit under ADR-0001's 900 without touching the RED block, the start
   record or the four remaining Rationalisations rows. Words bought from those sections do not count,
   because they are the rules tiering would sit on top of.

Reason 5 governs both. Evidence that tiering is safe is not what would reopen this and never was;
tiering was never measured. Anyone reviving it inherits task 8's obligation to hunt laundering
against the tiered body, and inherits it unpaid.
