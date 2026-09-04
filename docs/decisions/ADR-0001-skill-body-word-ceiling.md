# ADR-0001: Raise the skill body ceiling to 900 words and enforce 700 as a warning

| | |
|---|---|
| Status | accepted |
| Date | 2026-08-16 |
| Deciders | Bernard Tebandeke |
| Requirements | none; this governs the repository's own authoring standard |
| Supersedes | none |

## Context

`docs/standards.md` sets a skill body target of 400 words for a single linear path and 600 for one
that fans out to subagents, with 700 as a hard ceiling enforced by `tests/validate-skills.sh`.

Measured across all 24 skills on 2026-08-16:

- **Zero skills meet the 400 target. Four are under 600.**
- **Fifteen are within 20 words of the ceiling, and the top eight within six**: `write-prd` 699,
  `repo-snapshot` 699, `tdd` 698, `port-assess` 697, `incident-response` 696, `write-docs` 695,
  `ship` 695, `design-architecture` 694.
- The shortest body is `refactor` at 489. Nothing sits between 540 and 664.

**The dominant force is that the ceiling is the only number enforced, so it became the target.**
The tiered targets are documented and unchecked, which makes them advisory in name and dead in
fact. Bodies migrate to whatever the validator permits.

The lever the standard offers for relief is moving substance into `references/`. That lever is
exhausted, and `coding-standards` proves it: **12 reference files carrying 17,816 words, and a body
still at 683**, as measured on 2026-08-16. That skill now routes four modes and stands at
17 references, 22,752 reference words, and a body of 795. The conclusion below is unchanged by that:
moving substance out still did not pull the body under 680, and the growth came from new modes
rather than from failing to offload. A body's floor is set by its number of steps and by the link-plus-when-to-read
sentence each reference costs, not by how much detail it holds. Moving more out does not pull a body
below roughly 680, so the fifteen skills at the ceiling cannot be relieved by the remedy the
standard names.

This now blocks work rather than merely being untidy. The fresh-clone documentation rule from the
2026-08-16 `create-skill` baseline belongs in `write-docs` and `repo-snapshot`, at the moment a
document is linked. Neither can take a line.

**The ceiling is also the one enforced rule in this repository with no observed failure behind it.**
`docs/standards.md:22` states that every rule in the validator "exists because it was broken during
development". The 700 figure does not: "past roughly 700 the model starts skimming" is asserted from
a prior. The five behavioural evals re-run on 2026-08-16 all passed against bodies of 692 to 698,
which is evidence against the threshold sitting at 700 but says nothing about where it does sit.

## Decision

The hard ceiling moves to 900 words. 700 becomes an enforced warning, replacing the 400 and 600
targets, so a body crossing it is visible in every validator run rather than silently normal. A
skill body over 700 words requires a passing eval arm at that length, recorded in
`tests/evals/results.md`, so the room is taken against observed behaviour rather than against an
assertion.

*Clarified 2026-09-04, by Bernard.* "A passing eval arm at that length" means any arm recorded in
`tests/evals/results.md` that passed against the body unmodified, whether it was dispatched as a
release-gate arm or as a dedicated length arm. The narrower reading, that only an arm scored on
length counts, is set out as Reading B in
[bodies-over-the-target-with-no-arm.md](../ideas/bodies-over-the-target-with-no-arm.md), and it
lost: what this sentence buys is room taken against observed behaviour, and an arm that followed
the body at that length observed it whatever it was dispatched to measure. Unchanged by this, an
arm still discharges the length it ran at and not the body it ran against, so a body that has since
grown past that length owes a new one.

## Alternatives considered

### A: Measure first, then set the number

Run eval arms against deliberately padded bodies at 900, 1100 and 1300 words to find where
compliance actually degrades, and set the ceiling from the result.

The most rigorous option and the most consistent with this repository's own standard that numbers
come from commands. It lost on sequencing rather than on merit: it leaves all fifteen skills frozen
while it runs, and it front-loads a measurement whose main output, "the threshold is not 700", is
already established by five passing arms at 692 to 698. The chosen option does the same measurement
incrementally, one skill at a time, against real content rather than padding, and each result is
worth more because a padded body is not a body a model is asked to follow.

### B: Keep 700 and enforce the 400/600 targets as warnings

Makes the drift visible without moving the ceiling.

It lost because it changes nothing about the blockage. Fifteen skills stay frozen, and new content
lands only by cutting existing content. It also asks the validator to warn against two targets that
zero and four skills respectively meet, which trains readers to ignore the warning: a check that
fires on 24 of 24 skills carries no information.

### C: Split the skills that sit at the ceiling

Treats the clustering as evidence that skills are doing too much.

Genuine where a skill has two jobs, and it is the right answer in those cases individually. It lost
as a general policy on a cost that decision 6 in `docs/07-open-decisions.md` already recorded: skill
descriptions load in **every** request, 1,066 tokens across 24 skills, while a body
loads only when its skill fires. Splitting converts a per-invocation cost into an always-loaded one.
Splitting even half of the fifteen puts the count past 30, and decision 6 says explicitly to revisit
granularity **before** 30, not after.

*Corrected on acceptance, 2026-08-16:* this paragraph read "about 1,120 tokens", a figure carried
rather than measured. The measured total is 1,066, and plan task 7.5 has since capped it at 1,320,
which is the 30-skill line this paragraph relies on. The argument is unchanged and its number is now
enforced rather than quoted.

**Why the chosen option won:** the dominant force is that the only enforced number becomes the
target, and the relief valve the standard names is measurably exhausted. Raising the ceiling while
making 700 an enforced warning keeps a number that bodies must justify crossing, rather than one
they silently settle against, and it is the only option that unblocks the fifteen skills now.

## Consequences

**What becomes easier.** The fifteen skills at the ceiling can take content again, starting with the
fresh-clone rule in `write-docs` and `repo-snapshot`. Authoring stops being a word-golf exercise
where a genuine improvement must be paid for by deleting a different one.

**What becomes harder.** Every skill that uses the new room costs roughly 30 percent more per
invocation, paid each time the skill fires. Reviewers lose the crude protection of a hard 700: a
body at 850 is now legal and must be argued about on its merits. The eval requirement makes crossing
700 slower on purpose, and that cost is real for a skill that needs one extra line.

**What this forecloses.** Nothing structurally. Lowering the ceiling later is expensive, because it
means cutting content from every skill that took the room, so this is not cheaply reversible in the
direction that matters.

**What must be true for this to keep working.** That the skim threshold is above 900, and that the
700 warning is treated as a question rather than as noise. If bodies migrate to 900 the way they
migrated to 700, this ADR has failed in exactly the way it diagnosed, and the answer is not another
raise.

## Verification

The distribution is the measure, not the maximum. Re-measure every skill body at each release: if
the count within 20 words of 900 grows past two or three, the target-follows-ceiling effect has
reappeared and this ADR needs superseding rather than amending.

The eval arms are the second check. A skill that crossed 700 and whose arm later fails is the direct
signal that its body outgrew what the model will follow, and its length is the first thing to
suspect.
