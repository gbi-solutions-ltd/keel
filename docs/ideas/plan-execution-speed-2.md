# Plan execution speed, second sweep

**Raised:** 2026-11-12, by Bernard ("do another sweep to identify possible opportunities of
improving execution speed"), after PR #12.
**Agreed:** 2026-11-12, by Bernard: plan all of items 1 to 8 below; item 3 starts as this record's
design, not code. Item 9 was added after, from a stop that halted a subagent, and Bernard agreed
to plan it the same day. The four open decisions are settled (see the end).

## What was measured

Two read-only sweeps, 2026-11-12. The run measured is the 13-task execution of
`docs/plans/2026-11-11-faster-plan-execution.md`, which ran on the installed keel 0.27.0, so none of
PR #12's fixes were active: it is the baseline they target. The hooks in a session resolve to the
installed plugin cache, so no gain from this branch is measurable until it is installed.

Active time 378 minutes (a further 373 minutes waited on one approval prompt):

| Where | Minutes |
|---|---|
| Implementers blocked on the full suite (29 runs, median 317 s; 20 moved to the background by the harness at 180 s) | 159 |
| Implementer model time | 98 (66 without one 30-minute API stall) |
| Citation repairs outside a task's Files (11 of 13 tasks), red suites and a discarded round from them | about 50 |
| Rework rounds (tasks 1, 2, 10) | about 50 |
| Resumes because a task's Files missed a document the change made wrong (tasks 3, 8, 9, 12) | about 30 |
| Spec reviewers re-running tests (24 of 62 spec reviewers across three sessions ran the full suite) | 14 here; 2 to 8 per task elsewhere |
| Hooks per tool call | about 2 s per task in all: not worth optimising |

`tests/run-tests.sh` runs 4 jobs in file order: 307 s wall against 1058 s summed (measured while
another suite ran). Longest-first on 8 workers simulates to about 133 s; the machine has 10 cores.
The slowest files: `test-plan` 126 s, `test-keel-4` 120, `test-keel-2` 99, `test-keel` 98.

## The items, and the change each gets

1. **Reviewers stop re-running expensive tests.** The spec prompt's question 4 asks whether the
   verify commands ran and never says not to re-run them. Reviewers do not run `verify.test` or
   lint; they keep the scoped `Done when:` re-run, which takes seconds and is the only independent
   check that the report is real.
2. **The suite runs longest-first with a higher job cap.** `tests/run-tests.sh` orders files by
   their last recorded durations and runs `min(nproc, 8)` jobs, overridable by an environment
   variable; timed for real three to five times, watching the guards' 10 s timeouts for flakes.
   It also says so when a run takes over twice the last total (item 8's slow-suite stop). Put this
   task first so later boundary runs are faster. `.github/workflows` is a hard-block path: leave it.
3. **An unattended delivery stalls on sensitive-guard's commit ask.** The guard's own header says
   `ask` is the one decision the model cannot grant itself, so nothing the model can write (a
   token, a ledger, "plan approval covers these files") may satisfy it. The levers that keep it:
   the coordinator sends a `PushNotification` just before a commit it knows will ask (`keel plan
   risk --staged` printed `loop: full`); `write-plan` orders hard-block tasks early and states at
   approval how many commits will ask, so they run while the person is present.
4. **`write-plan` finds the documents a change makes wrong.** Search live documents only (README,
   `docs/NN-*.md`, skills, `templates/profile.schema.json` and the generated `docs/profile-keys.md`)
   for the behaviour being changed, and list each in the task's Files. Records do not change.
5. **The citation tax.** Two sources: the validator fails a record's line citation that lands on a
   blank line, and this branch's plans told implementers to repair citations in records too.
6. **The same suite runs three times on the final commit** (plan-end checkpoint, `review-code`,
   `ship`). Ship's "Not 'the last run was green'" stays unless Bernard rules otherwise.
7. **Older plans pay the per-task suite.** Their Step N.1 says "the one boundary run" and task text
   overrides the skill, so adding the header line alone leaves the two in conflict.
8. **Small items:** `keel plan tick` takes several ids; the GREEN run counts as the `Done when:`
   run when nothing changed after it; the slow-suite warning (item 2); and the tdd lines telling an
   implementer to read a reference none read (check `validate-skills` and `docs/standards.md`,
   "the dispatching step says to read them", before removing; the tdd body is at 745 of 746 words).

9. **context-watch stops a subagent for its coordinator's context.** Found 2026-11-12, when the
   stop halted a follow-ups implementer at the coordinator's 970k tokens (also seen in sms-gateway;
   live in installed 0.27.0 and on this branch). A subagent's hook input carries the parent's
   `transcript_path` and `session_id`, and `lib/context_watch.py` never reads `agent_id`, so it
   measures the main thread (sidechain entries excluded) and denies the subagent's tools. A
   subagent is told by a non-empty `agent_type` and `agent_id`, as `hooks/review-guard:12-17`
   records; the plan decides whether such a call is skipped or measured against its own context.

## Decisions, by Bernard on 2026-11-12

- Item 5: hot-file list plus no record repairs. The validator's line check stays as it is.
- Item 6: `review-code` quotes the plan-end checkpoint run on the same HEAD; `ship` still runs its
  own.
- Item 7: the offer to add checkpoints also rewrites each open task's boundary step, a repair the
  person approves.
- Item 9: planned with the rest.
- Branch: more commits on PR #12 (`feat/faster-plan-execution`), not a stacked branch.
