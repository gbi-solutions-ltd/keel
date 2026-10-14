# Reporting findings

Read this once before reporting a review. It carries the reason behind the reporting rules that
`review-code`, `write-plan`'s plan reviewer and the two passes `execute-plan` dispatches state at
their own point of use, each stating the ones its step needs.

The rules stay stated at the point of use, because a reviewer under time pressure reads the step in
front of it, and a subagent reads only the prompt it is pasted. **This file carries the reasons**,
which is what stops the rules being rationalised away, and it carries them once rather than in each
place that states a rule. A reviewer subagent does not read this file; the dispatcher does.

## Rank, and put blocking first

A reviewer who buries approval under nine nitpicks trains people to skim reviews, and a skimmed
review is worth less than none: it costs the author's time and buys no confidence.

## Say plainly when nothing blocks, in the first line

A reviewer who cannot approve invents problems. The instruction is not to be kind, it is to keep the
verdict informative: if every review returns findings, the presence of findings stops meaning
anything. Name what you checked, including what was fine, so a reader can tell a clean review from
an incurious one.

## Cap at around ten

More than about ten findings is itself the finding: the change is too large to review in one pass.
A fixed cap with nothing said drops whichever finding came eleventh and gives no signal that
anything was dropped, which is worse than reporting the size problem.

## Never a finding without a location, and never a location without a reason

A finding without a `path:line` is a guess, and the reader cannot check it without re-reading the
tree. `shape-idea` makes the same point about a challenge: one carrying a `path:line` changes a
decision, and the same challenge from instinct starts an argument and loses.

## Do not rewrite it in the review

Say what is wrong and let the author fix it. A reviewer that repairs what it found has removed the
decision somebody else was going to make, and in a delegated run an edit by the reviewer is a change
that neither review pass has read. `execute-plan` holds its coordinator to the same reasoning,
under "What you keep, and what you do not touch" in
`../../execute-plan/references/subagent-prompts.md`.

## "Looks good" is not a review

Name what you checked. A verdict with no evidence of reading is indistinguishable from not having
read it, and it is the one outcome that makes every later review from the same reviewer worth less.
The `review-code` rubric works this through with an example, under "Saying it is fine" in
`../../review-code/references/rubric.md`.
