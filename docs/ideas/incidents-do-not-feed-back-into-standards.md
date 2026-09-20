# Idea: a postmortem is where `incident-response` stops

| | |
|---|---|
| Raised by | Bernard, 2026-09-19, "plan the work that makes keel enforceable outside the agent" |
| Status | shaped |
| Recommendation | One done-when line in `incident-response`, requiring a rule, an eval arm, or a skill line, not a new mechanism |
| Next | `write-plan`, as one increment of the outside-the-agent plan |

## The problem

What makes a factory improve rather than repeat an incident is that a preventable one yields a rule,
an eval arm, and a line in a skill. If that is not in a skill's own done-when, it depends on someone
remembering to do it later, which is the same "claim with no reader" shape as every other gap in this
plan, just applied to the feedback loop itself rather than to a single gate.

**Evidence.** `skills/incident-response/SKILL.md`'s closing step ("Hand off, and close it") requires,
in order: update the status page, `keel:debug` for root cause, `keel:tdd` for the fix with a
reproducing test, `keel:design-architecture` for an ADR "if the design allowed it", and "add what
you learned to the runbook." There is no step that updates `docs/standards.md`, no step that adds or
adjusts an eval scenario, and no step that touches a skill body. The loop closes at "the runbook
gets a line," which is a narrower claim than "incidents feed back into standards, skills, and
evals."

## What it costs

`skills/incident-response/SKILL.md`'s body is 699 words against ADR-0001's 700-word target and
900-word ceiling. Any addition crosses the target, which under ADR-0001 buys a passing eval arm at
that length, recorded in `tests/evals/results.md`. That is expected friction by design, not a
blocker: the ceiling exists precisely so growth is priced against observed behaviour rather than
against an assertion.

## Recommendation

Add one short done-when line: a preventable incident's handoff must name at least one of a rule
added to a reference file, an eval arm added, or a line changed in a skill body, with a one-line
justification if none applied. This is the cheapest version, matching the parent brief's own
instruction: "a done-when addition, not new machinery." It does not mandate that every incident
produces all three; it mandates that the handoff states which, if any, applies, so the choice is
visible rather than silently skipped.

## Open questions

1. Should the new line point at a specific artifact path (e.g. `docs/standards.md`,
   `tests/evals/results.md`) the way `ship`'s items point at commands, or stay a named-choice
   sentence? The latter costs fewer words and fits the remaining margin better.
2. Who verifies the done-when line was honoured, given `hooks/done-guard` cannot see whether an edit
   "followed a rule" any more than it can for coding standards (`docs/ideas/standards-that-bind.md`,
   question 3, item 5)? Likely: nobody mechanically; this stays a review-time check, same as the rest
   of `incident-response`'s closing step.
