# Idea: two scenarios now fail on how the reply presents its verdict

| | |
|---|---|
| Raised by | The coordinator, 2026-09-30, from task 13 of `docs/plans/2026-09-29-skill-review-changes.md` |
| Status | **closed 2026-09-30.** The harness was ruled out and both skills' reply guidance fixed; see [Closed](#closed-2026-09-30) |
| Recommendation | done: one sentence each in `security-audit` Step 5 and `coding-standards`' `references/assess.md` |
| Next | nothing |

## What failed

Two scenarios failed on 2026-09-30, and each fails the same way with the plan's change to its skill
undone. The evidence is in `tests/evals/results.md`, the first 2026-09-30 entry.

- **`assess-a-stale-standard`**, `coding-standards`. The written audit report is correct and in the
  fixed check order. The chat reply leads with the rule table (check 3), labels no check, and never
  states check 1's coverage number. The scenario scores the reply, so it fails. 3 of 3 at 726
  words, and 2 of 2 at the body as it stood before the skill review (795). It last passed on
  2026-09-02, at 876.
- **`audit-under-a-warn-gate`**, `security-audit`. Under `warn` the reply leads with its own "don't
  ship" and only then says the call is the user's, the shape the old body failed with on
  2026-09-08. 4 of 4 at the current 800 words; 3 of 3 each with F-200's `warn` clause reverted, with
  the 2026-09-08 wording "`warn` reports the finding and lets the ship proceed", and at the body
  before the skill review (695).

## What is shared

Both are in the reply rather than the work, and both scenarios last passed weeks before this run.
The arms now run with the `Artifact` tool: one published a claude.ai page instead of writing a file,
and several offered to. Whether that, the model, or something else moved them is untested. A
baseline arm with the `Artifact` tool removed from the dispatch would separate the harness from the
skill text.

## What it left owed

`security-audit` was at 800 words with its only scenario failing, so it had no passing arm at its
length, which ADR-0001 requires over 700. The fix below closed that.

## Closed, 2026-09-30

**The harness was not the cause.** Five dispatches with `--disallowedTools Artifact`, three `warn`
and two `assess`, $2.43, failed exactly as before, and none offered a page.

**The skills under-specified the reply.** Each body said what the verdict or the order is, and
nothing said the reply leads with it. Two sentences, at Bernard's direction:

- `security-audit` Step 5: "The reply opens with that verdict: under `warn`, unless a
  `hard_block_paths` finding blocks, say first that the gate does not block, then recommend." The
  body went from 800 words to 823. The `hard_block_paths` clause came from review, after the
  first three pairs had passed at 818 without it, and a fourth pair passed at 823.
- `coding-standards`' `references/assess.md`, after the checks: "**The reply keeps that order.**
  Name each check as the report does, check 1's number first, then 1b, 2, 3 and 4, however short
  the summary."

Four `warn` and `required` pairs and two `assess` arms, $4.37, all pass. `security-audit` at 823
has its arm. The evidence is the second 2026-09-30 entry in `tests/evals/results.md`.
