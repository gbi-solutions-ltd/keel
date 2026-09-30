# Idea: eval scenarios for the skills that have none

| | |
|---|---|
| Raised by | The maintainer, 2026-09-28, splitting it out of [skill-and-reference-review.md](skill-and-reference-review.md) open question 2 |
| Status | recorded, not shaped |
| Recommendation | Undecided until the skill review's findings say which rewrites carried the most risk |
| Next | `shape-idea`, once the skill review has landed |

## The problem

A change to a skill with no eval scenario ships with nothing to show it still changes behaviour,
and the skill review is about to reword all of them.

**Evidence.** The 14 scenarios' `Inject:` lines name 10 skills. The 15 with none: `apex-export`,
`apex-port-plan`, `context-budget`, `create-skill`, `design-architecture`, `keel`,
`optimize-performance`, `port-assess`, `refactor`, `review-code`, `setup-deployment`, `shape-idea`,
`write-docs`, `write-plan`, `write-user-stories`. Run `grep '^Inject:' tests/evals/scenarios/*.md`
on 2026-09-28. No failure of an uncovered skill has been traced yet: without a scenario, none could be.

## What was asked for

"A separate piece of work": the skill review writes no new scenarios, and scenarios for the skills
with none are shaped here.

## The case against

**Strongest argument for not building this at all.** Scenarios cost API tokens and minutes per
run (`tests/evals/README.md`) and each needs a fixture and graded criteria. Fifteen of them is a
large standing cost for skills whose failures nobody has reported, and several (`apex-export`,
`port-assess`) run rarely enough that a scenario may never pay for itself.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Rewrites to 15 skills stay unmeasured | The skill review accepted that risk on 2026-09-28 |
| Do it manually | Re-read each reworded skill against a hand-run prompt | No record, not repeatable |
| Buy it | Not applicable | |
| Build something smaller | Scenarios for the most-used uncovered skills only, such as `write-plan` and `review-code` | Likely the answer; which skills is the open question |

## Open questions

1. Which uncovered skills get a scenario first, and by what measure: use, or the risk the review's rewrites carried?

## Recommendation

Undecided until the skill review has landed and its findings show where rewording changed the most.

## Not decided here

Scenario content, fixtures, criteria, and whether any become release-gate arms.
