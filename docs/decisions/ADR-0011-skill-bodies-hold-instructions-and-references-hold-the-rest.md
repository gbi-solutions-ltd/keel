# ADR-0011: Skill bodies hold instructions, and references hold the rest

| | |
|---|---|
| Status | accepted |
| Date | 2026-10-18 |
| Deciders | Bernard Tebandeke, decided 2026-10-17, with two rulings on `tdd` on 2026-10-18 |
| Requirements | none; driver is item 4 and "Decided" 1 of `docs/ideas/factory-reliability.md` |
| Supersedes | [ADR-0001](ADR-0001-skill-body-word-ceiling.md) |

## Context

ADR-0001 raised the skill body ceiling from 700 to 900 words on 2026-08-16, kept 700 as a warned
target that a body could cross with a passing eval arm at its length, and named its own trigger:
"if the count within 20 words of 900 grows past two or three, the target-follows-ceiling effect has
reappeared and this ADR needs superseding rather than amending."

That trigger fired. On 2026-10-17, by `tests/validate-skills.sh`'s count, four bodies sat within 20
words of 900, `tdd` 898, `execute-plan` 894, `write-plan` 893 and `ship` 885, and a fifth,
`security-audit` 872, within 30. Eleven bodies were over 700: those five, `write-prd` 798,
`repo-snapshot` 748, `incident-response` 746, `setup-deployment` 744, `review-code` 728 and
`coding-standards` 726. It is the effect ADR-0001 diagnosed at 700, two months later at 900.

**The dominant force: whatever number is enforced, bodies settle against it.** 700 drew fifteen
bodies within 20 words of it by August; 900 drew four within 20 of it by October. A higher number
buys room once and then fills, so the remedy has to be a kind of text that leaves the body, not a
higher number.

ADR-0001 held that this remedy was exhausted: moving detail into `references/` stopped near 680, so
the bodies at the ceiling could not be relieved by it. That measured detail moved out, not reasons.
Much of what made a body long was the why beside each instruction, which persuades a reader once
and which a model does not need in order to follow the step.

Bernard decided on 2026-10-17, in his words:

- "Prune to the target": "Move each long body's reasoning into a reference; bodies go back under
  700. Each pruned body owes an eval arm". That supersedes ADR-0001.
- "All eleven": every body over 700 words, not only the four within 20 words of 900.
- "700 hard": no eval-arm exception; room is made in references.
- "1 run each, new scenario": one arm per pruned body, plus a new `setup-deployment` scenario.
- "Dedupe, then move step detail": reasoning first, then an instruction a linked reference already
  states, then step detail to a reference with a one-line instruction and a read-before link.
- "Within 30 of 700": the warning fires from 671, replacing an earlier "warn at 650".

And on 2026-10-18, on `tdd`, two rulings quoted under Consequences.

## Decision

A skill body holds instructions. Room under the ceiling is made by three moves, in this order,
stopping as soon as the body is under 700: the reasons for the instructions go to the skill's
`references/rationale.md`; an instruction that a linked reference of the same skill states in full
is deleted from the body; and step detail goes to the skill's `references/step-detail.md`, the step
keeping a one-line instruction and a link with a sentence saying to read it before doing that step.
700 words, counted by `tests/validate-skills.sh` as everything after the frontmatter, is the hard
ceiling, and the validator warns within 30 of it, from 671. There is no eval-arm exception: room is
made in references, never by crossing the number. A pruned body owes a re-run of its arm when the
body or its `step-detail.md` changes. A skill that still cannot get under 700 after all three moves
has to split.

**ADR-0001's floor, answered by measurement.** Each of the eleven bodies over 700 was cut in that
order, stopping once under 700:

| Skill | Before | After | What left the body |
|---|---|---|---|
| `tdd` | 898 | 699 | reasons, the rationalisations' answers, then step detail to `step-detail.md` |
| `execute-plan` | 894 | 673 | reasons, then the Step 1 table, a duplicate of `preconditions.md` |
| `write-plan` | 893 | 684 | reasons, then a paragraph duplicating `plan-template.md` |
| `ship` | 885 | 697 | reasons, one duplicate, then the PR-body sub-cases to `step-detail.md` |
| `security-audit` | 872 | 694 | reasons, then one duplicate of `report-template.md` |
| `write-prd` | 798 | 682 | reasons only |
| `repo-snapshot` | 748 | 695 | reasons, then one duplicate of `section-templates.md` |
| `incident-response` | 746 | 575 | reasons only |
| `setup-deployment` | 744 | 699 | reasons only; a first cut to 649 was revisited, see Consequences |
| `review-code` | 728 | 592 | reasons only |
| `coding-standards` | 726 | 645 | reasons only |

Nine of the eleven went under 700 without moving step detail, and four went below ADR-0001's floor
of roughly 680. `coding-standards`, the skill ADR-0001 cited at 683 as proof of that floor, was 645
on 2026-10-18, with 18 references carrying 22,916 words. The eleven bodies fell from 8,932 words to
7,335. A body's floor is set by its steps and the instruction each step needs, not by the reasons it
carries.

## Alternatives considered

### A: Keep 900 and the eval-arm rule

Leave ADR-0001 standing and let each body over 700 keep paying its arm. It lost because it is the
state whose trigger fired: four bodies within 20 words of 900 is the number turned target again,
and ADR-0001 says that when this happens "the answer is not another raise". Standing still is the
same answer one step later.

### B: 750 hard, with a warning at 700

A smaller raise from the old 700. It lost because it repeats the mechanism one size smaller. The
plan review estimated that moving reasons alone left `tdd`, `execute-plan`, `write-plan` and `ship`
near 750, so the new number would be full on its first day, and a warning at 700 is what ADR-0001's
warning at 700 already was.

### C: 700 hard, with an eval-arm exception

The ceiling ADR-0001 replaced, plus its exception. Its strongest point is behaviour: in the
controls, taken together, the six bodies before the prune, at 726 to 898 words, did no worse than
the pruned ones (5 of 12 against 4 of 12), though per body it went both ways: `incident-response`
rose from 1 of 2 to 2 of 2 and `setup-deployment` fell from 2 of 2 to 0 of 2 before its reasons went
back. Nothing measured shows a model following a 900-word body less well than a 700-word one.
ADR-0011's case against C rests on the settling force, not on behaviour: the exception is the route
by which bodies reached 900, a warned number that a body may cross with an arm, and an arm measures
one scenario at one length, not whether every step of the body is still read. Bernard's "700 hard"
closed it.

### D: Reasons only, accepting a shortfall

Move reasons out and stop, leaving any body that does not reach 700 over it. It lost because the
same estimate put four bodies near 750 after reasons alone, so the ceiling would need an exception
from its first day, which is C. In the event, duplicates carried `execute-plan`, `write-plan`,
`security-audit` and `repo-snapshot` under, and `tdd` and `ship` needed step detail.

**Why the chosen option won:** the dominant force is that the enforced number becomes the target.
The only remedy that does not feed that force is a kind of text leaving the body, and the prune
showed that it does leave: every body over 700 went under it, four of them under ADR-0001's floor,
with no number raised and no exception granted. Clustering just under the hard number is expected
and accepted. The prune itself stopped at 699, 699, 697, 695 and 694, and twelve bodies sat within
20 words of 700 on 2026-10-18. Under a hard ceiling with no exception, a body settled against the
number pays for its next line with a move into a reference; what this decision rules out is the
number moving.

## Consequences

**What becomes easier.** Eleven skills carry a `references/rationale.md`, and `tdd` and `ship` a
`references/step-detail.md`, so a body reads as the steps to take. The eleven bodies are 1,597 words
shorter together; an invocation saves its own body's cut, 45 to 221 words, less whatever it then
reads from references. A reason is still on disk for the reader who wants it, in the same skill.
ADR-0002's rule "The coordinator writes no production code, at any size, with the reason attached"
now has its reason in `skills/execute-plan/references/rationale.md`, and "attached" is met by the
body's link to it, so ADR-0011 leaves ADR-0002's decision unchanged.

**What becomes harder.** A body may sit at 671 to 700 and warn. Fourteen did on 2026-10-18, counted
by `tests/validate-skills.sh`. A warned body has to make room in a reference before it grows, so a
one-line addition to one of those fourteen can cost a move first. A reason in a reference is read
only by someone who goes looking, so a model that follows a step without its reason can follow it
too literally, and a reviewer has to open two files to judge one step.

**The step-detail risk, and what the arms saw.** A model may skip a link and do the step without its
detail. Only `tdd`'s arm reached a step-detail link; it opened it at RED. `ship`'s arm never reached
its link. One arm is an observation, not a rate. The same `tdd` arm did not open
`rationalisations.md`, and argued for the test from `gates.tdd: required` and cost rather than from
the iron law: the one observation that bears on whether reasons are needed in the body.

**What the arms found.** Recorded in `tests/evals/results.md` under "2026-10-18, the
prune-to-the-target arms". At one run per body, plus two blinded runs each way on six bodies, the
arms found no regression except `setup-deployment`'s first cut; where old and new bodies both
failed, they could not show one. That cut, to 649, passed `add-ci-that-gates` on the letter 1 of 3
against the old body's 2 of 2; it was revisited, the four reasons beside the gating steps went back
(`d6ccba9`, 699 words), and four more runs passed 3 of 4 on the letter, the old body's rate over
four runs. On the strict reading, which counts a non-required quarantine job as discarding the exit
code, the revised body passed 1 of 4 and the old 2 of 4, and five of the last six runs, the old
body's among them, took that route. The arms also exposed gaps that predate the prune, seen on the
old bodies or in the harness, and recorded as follow-ups rather than built: `tdd-under-deadline`'s
criterion 2 fails every arm that does the act it names; `repo-snapshot` cites the seeded breaches to
its own reading rather than the audit; every `review-code` arm mutated a non-sensitive file, and
concurrent arms collide on a fixed worktree path; `setup-deployment`'s "Tests fail the build" does
not name a non-required quarantine job; and arms search the whole filesystem rather than the path
their prompt names.

**The isolation defect in round 1 was a coordinator error.** A repository snapshot and a stray keel
clone were left on the machine, and four arms read references from those copies. Every file read
that way was byte-identical to the staged copy and no arm read a scenario, so no verdict depends on
it. It was corrected for the later rounds, which deleted every copy first and listed what remained.

**Two of Bernard's 2026-10-18 rulings shaped `tdd`.** "Cues in body, answers out": the three
excuses of the rationalisations table stay in the body word for word as red flags, and their
answers live in `skills/tdd/references/rationalisations.md`. "Restore it, move the tally detail":
the clause making a case that needs a second change a second unit went back into the body, and the
tally the RED check reports moved to `step-detail.md`.

**What this forecloses.** Relief by raising the number. A skill that needs more than 700 words of
instruction, after its reasons and step detail have left, has to split, and splitting spends the
always-loaded description budget of decision 6 in `docs/07-open-decisions.md`.

**What must be true for this to keep working.** That a model opens a link whose sentence says to
read it before the step, and that the reasons in `rationale.md` are not needed to follow the steps.
Where an arm shows either failing, the passage goes back into the body, as `setup-deployment`'s
reasons did, and something else leaves instead.

## Verification

The arms are the check. A body near 700 is expected and is not the signal, since the warning band
is where this decision puts bodies. The signal is an arm failing on a step whose reason or detail
left the body, or an arm doing a linked step without opening its link: either names the passage to
restore. Re-run each pruned body's arm when its body or its `step-detail.md` changes, and record in
`tests/evals/results.md` whether a step-detail link was opened at its step.

If the next relief anyone proposes is a higher number, the dominant force has won again and this
ADR needs superseding with a different kind of remedy, not amending with a larger figure.
