# Idea record template

The structure of `<docs_root>/ideas/<slug>.md`. Written by `shape-idea`, read by `write-prd` in
`from-idea` mode.

Order matters here and is not cosmetic. The case against sits above the recommendation because a
baseline run, with no skill, deliberately buried its own strongest objection inside a delivery plan
and said so afterwards: "opening by dismissing the premise tends to end the conversation instead of
improving the idea." The template removes the choice.

```markdown
# Idea: <short name>

| | |
|---|---|
| Raised by | Who, and when |
| Status | shaping / agreed / declined / paused pending <question> |
| Recommendation | One line. Filled in at step 5 |
| Next | `write-prd`, or nothing |

## The problem

One sentence: who has it, what it costs them, how often.

**Evidence.** A specific recent instance, with a date or a reference. Not a category.
`Unknown, and nobody could name one` is a valid and important entry.

## What was asked for

The idea as it arrived, in the requester's own words. Kept separate from the problem on purpose:
these are usually different, and the gap is the most useful thing on this page.

## The case against

**Strongest argument for not building this at all.** One paragraph. Not hedged, not folded into a
recommendation. If there genuinely is not one, say so and say why.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | | |
| Do it manually | | |
| Buy it | | |
| Build something smaller | | |

Doing nothing is always listed, and those four rows come first. **Variants of the idea go in a
separate table below, not in this one.** A run added two rows that were both ways of building it, and
noted afterwards that it had diluted the table in exactly the direction this warning points at. Keep
the alternatives table answerable by somebody who does not want the thing built.

**Status and Recommendation must agree**, or the record says why they differ. `paused` beside "do not
build it" is defensible when the answer to a blocking question was assumed rather than given, but
that has to be stated rather than left for a reader to notice.

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|

Each part of the idea that only works if something unproven holds.

## What the system says

Findings from reading the code and docs, each citing `path:line` or a document. This is what makes
the case against land rather than read as reluctance.

| Finding | Evidence | What it means for the idea |
|---|---|---|

## Open questions

The ones that would change the answer, in descending order of how much. Surfaced as choices where
they block, per the shared question convention.

## Recommendation

One of: build it, build something smaller, do not build it, undecided pending a named question.

Three lines: what, why, and what happens next. No design, no stack, no estimate.

## Not decided here

Everything deliberately left to `write-prd` and `design-architecture`, so a reader does not mistake
silence for an answer.
```

## What this file is not

Not a PRD. No `FR-NN` ids, no acceptance criteria, no non-functional requirements. If you are
numbering requirements, `write-prd` should already have started.

Not a design. No components, no stack, no schema, no sequencing. Naming a technology here quietly
decides an architecture nobody reviewed.

## Where `write-prd` picks it up

`write-prd --from-idea` reads this file and skips every question it answers, the same way
`from-repo` reads `snapshot.md`. The sections it consumes directly are **The problem**, **What was
asked for**, **Open questions**, and the assumptions table. Filling those in properly is what stops
the user being asked the same things twice.
