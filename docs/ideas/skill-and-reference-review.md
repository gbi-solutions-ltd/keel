# Idea: review every skill body and reference for clarity

| | |
|---|---|
| Raised by | The maintainer, in conversation, 2026-09-28 |
| Status | agreed 2026-09-28 |
| Recommendation | Build it: a findings pass over all of `skills/`, then defect fixes and clarity rewording in every skill, re-running an arm wherever one exists |
| Next | `write-prd`: drafted as `docs/prd/skill-and-reference-review.md`, approved |

## The problem

A model following a keel skill reads a body of about 730 words, and the references it opens, where
the same rule is stated several times, facts about keel's own repository sit beside rules meant for
every project, and a table can repeat the steps above it. Each of those is a place where the model
can pick the wrong one of two phrasings, or apply a number that was never about its project. This
happens on every skill invocation, in every project that installs keel.

**Evidence.** Two instances, one a defect and one a compliance failure whose cause is not known:

- `skills/tdd/SKILL.md:87` said "The suite is 313 seconds and one test is 2." until commit
  `268a950`. That was keel's own `tests/run-tests.sh`, measured for
  `docs/decisions/ADR-0006-the-tdd-cycle-unit-is-a-behavioural-unit.md:16`, shipped as a statement
  about every project's suite.
- Commit `a132794` (2026-08-19): the `build-with-no-prd` arm asked five questions in one table, which
  `write-prd` Step 2 forbids. The rule was stated. Whether a clearer body would have been followed
  is exactly what nobody has measured.

## What was asked for

"Review all skill files and identify possible improvements and possibly shorten the skill bodies."
Clarified the same day: the goal is clearer bodies the model follows better, not a word count, and
the review covers `references/` as well as the 25 bodies.

## The case against

**Strongest argument for not building this at all.** No measured failure has been traced to how a
body is worded. The one failed arm in the record ignored a rule stated plainly, and rewording for
clarity is a change made on judgement to text that passing arms have already observed working. Most
skills have no arm to show a rewrite did no harm, and more than two hundred citations point into
skill files by line or phrase, so every reworded sentence has a repair cost, and a rewrite made
for clarity can quietly remove the one sentence a scenario depended on. The repetition that looks
like clutter may be why the rules hold: `tdd` states "test first" four ways and its arms pass.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | The `tdd` leak stays, and any other leaks nobody has found | A known defect ships to every project |
| Do it manually, one skill at a time as each is next touched | Nothing up front | Leaks and contradictions across skills are only visible when reading them together |
| Buy it | Not applicable: no external tool reviews a skill against keel's own conventions | |
| Build something smaller | A read-only findings pass, defects fixed, rewording held to what an eval can check | This is the recommendation |

Variants of the idea:

| Variant | Difference |
|---|---|
| Rewrite every body toward a lower word target | Rejected by the maintainer's answer: the goal is clarity, not a number. `docs/05-token-and-memory-design.md` records that bodies drift to whatever number is checked |
| Bodies only, references untouched | Rejected by the maintainer's answer: references are in scope |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| Stating a rule once, clearly, is followed at least as well as stating it several times | An arm on a deduplicated body passes where the original passed | Re-run that skill's scenario after the change | No |
| Other skills and references carry keel-specific facts like `tdd`'s | The review finds more than the one known | The findings pass itself | One found, the rest unknown |
| A reviewer can tell a defect from a style preference reliably | Findings sort cleanly into "wrong" and "could be clearer" | The findings list, read by the maintainer | No |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| 25 bodies total 18,276 words, mean 731; 16 are over the 700 target, none over 900 | `wc -w skills/*/SKILL.md`, 2026-09-28 | There is room to cut, but the budget does not force it |
| 62 reference files, about 72,000 words | `find skills -path '*references*' -name '*.md'` | The larger half of the review by volume |
| Bodies drift to the enforced number, and moving text to `references/` did not lower the floor | `docs/05-token-and-memory-design.md`, "One band, per ADR-0001" | A word target would be met by rephrasing, not by being clearer |
| A body over 700 words needs a passing eval arm at its length | `docs/decisions/ADR-0001-skill-body-word-ceiling.md`, Decision | A body rewritten above 700 owes a new arm |
| 14 eval scenarios, whose `Inject:` lines name 10 of the 25 skills | `grep '^Inject:' tests/evals/scenarios/*.md` | Most skills cannot be re-measured after a rewrite |
| Over 200 citations into skill files by line or anchor | grep over `docs/`, `README.md`, `tests/*.sh` | Every reword carries a citation repair, as commit `870d07c` already recorded for another plan |
| Some skill sentences are pinned word for word by the test suite | `tests/test-eval-harness.sh:480` pins `execute-plan` Step 4 | A reword there fails the suite until the pin moves with it |
| `refactor`'s "Common mistakes" table restates steps 1, 3, 4 and 5 row by row | `skills/refactor/SKILL.md` | One example of the redundancy pattern the review looks for |

## Open questions

1. *Answered 2026-09-28, by the maintainer.* Skills with no scenario get clarity rewording as well as
   defect fixes. The case against above stands as the recorded risk; the answer accepts it. Now FR-05 in
   `docs/prd/skill-and-reference-review.md`.
2. *Answered 2026-09-28, by the maintainer.* A separate piece of work. The review writes no new
   scenarios; scenarios for the skills with none are
   [eval-scenarios-for-uncovered-skills.md](eval-scenarios-for-uncovered-skills.md). Now FR-10 in
   `docs/prd/skill-and-reference-review.md`.

## Recommendation

Build it: one read-only findings pass over all 25 bodies and 62 references, sorted into defects
(repo facts leaking into skills, contradictions, stale or broken references) and clarity changes,
then both kinds made in every skill, with an arm re-run wherever the skill has one. Next is `write-prd`.

*Revised 2026-09-28.* This read "build something smaller", holding clarity changes to skills with an
arm. The maintainer chose rewording for every skill; the smaller form is kept here as what was
weighed.

## Not decided here

The checklist the review uses, how it is split across reviewers, the order skills are changed in,
and whether any word target changes. Those belong to `write-prd` and `write-plan`.
