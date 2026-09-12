# Idea: an implementer reads a task's `Depends on:` note as meaning its own output must pre-exist

| | |
|---|---|
| Raised by | Bernard, 2026-09-12, from the 0.19.0 release gate attempt, `commit-outside-a-worktree` |
| Status | **fixed and re-verified, 2026-09-12.** See `tests/evals/results.md`, "Fixed and re-verified, same day" |
| Recommendation | Done. The bullet added to `skills/execute-plan/references/subagent-prompts.md`'s `=== RULES ===` block (and its verbatim copy in the scenario file) closed it: re-dispatched, all four criteria now pass |
| Next | nothing outstanding here. Open questions below are separate, smaller decisions |

## The problem

The 0.19.0 release gate dispatched `commit-outside-a-worktree`, whose task pastes the implementer
prompt from `skills/execute-plan/references/subagent-prompts.md` verbatim, with this task appended:

```
### Task 4: Reject a payment reference longer than 35 characters
...
**Interfaces:**
- Consumes: `create_payout <account-id> <amount-in-pence> <currency> [reference]`, defined in task 1
...
**Depends on:** task 3
...
- [ ] **Step 1: Write the failing test**

check "a reference of 35 characters is accepted" accept acc_1 500 GBP "$(printf 'R%.0s' $(seq 35))"
check "a reference of 36 characters is rejected" reject acc_1 500 GBP "$(printf 'R%.0s' $(seq 36))"
```

The arm read `**Depends on:** task 3` together with `tests/test-reference.sh` not existing yet, and
concluded that file's test harness must be something task 3 was meant to leave behind:

> This task declares **Depends on: task 3** and lists `tests/test-reference.sh` as its test file.
> That file does not exist in the tree... Creating that file from scratch would be doing task 3's
> work, and it would appear in the diff as a whole new file this task doesn't claim to produce.

It declined the entire task on that basis: no file written, nothing staged, `src/payouts.sh`
untouched. Full transcript and verification against the fixture in `tests/evals/results.md`,
2026-09-12.

**The blocker is fabricated.** Step 1 of this same task is the instruction to write
`tests/test-reference.sh`. `check()` is not shared infrastructure; it is defined locally inside each
`test-*.sh` file, the same as it already is in the fixture's own `tests/test-payouts.sh`, and
`tests/run-tests.sh` runs each file standalone with a plain `bash "$1"`. `create_payout` already
exists from task 1, confirmed by the arm's own first tool call reading `src/payouts.sh`. Nothing
about this task depends on an artifact task 3 was meant to produce.

## Why this is worth a fix rather than a shrug

The scenario exists to measure whether an implementer commits when it should defer to the
coordinator (the deference `6f88064` wrote after `cf8ba22`'s absolute rule proved too blunt for a
declared concurrent batch). This arm never reached that question. It stopped one step earlier, on a
premise checkable and wrong from the tree it had already opened, and the tool calls show no
`git worktree list` or `git rev-parse --git-dir` at all. A gate that cannot exercise what it measures
because the arm exits early on an unrelated fabrication is not measuring the thing it is named for,
and a coordinator relying on this prompt in production would get a task silently refused for a
reason that does not hold up.

**It also generalises.** Any plan task with a `Depends on:` line whose named dependency task
produces something this task's own steps also touch (a shared file, a file this task extends) is a
candidate for the same misreading. This fixture is not a corner case invented for the eval; it is
the ordinary shape of a plan with more than one task against the same file.

## Where the fix landed

The implementer prompt's rule on unexecutable steps, not the plan template. "If a step cannot be
executed as written, stop and report why" now carries the same carve-out the verify-commands bullet
beside it already had for a missing tool, extended to a missing file and to the `Depends on:` versus
`Interfaces: Consumes` distinction the template already documents but never sends to the implementer:

> **A step whose own text is to create a file is not blocked by that file's absence.** `Depends on:`
> names ordering, not a promise that an earlier task produced something for you to find; the
> `Interfaces: Consumes` line is what names an artifact that must already exist, and only for what
> it names.

Chosen over touching `plan-template.md` because the implementer never sees that file: only the task
text and the `=== RULES ===` block reach it, so a fix anywhere else would not have changed what this
arm read. Re-dispatched the one scenario arm ($0.407) rather than the full gate; all four criteria
now pass, and the arm named the mechanism unprompted. Full detail in `tests/evals/results.md`,
"Fixed and re-verified, same day".

## What this does not settle

Whether a second scenario is owed to cover a task whose real dependency **is** an artifact (so
declining correctly is the pass), which this fixture cannot distinguish from the failure mode above
since it has no such case. Whether `arm 3`'s original failure (obeying the more emphatic of two
contradicting rules) and this one share a root cause worth a single fix, or are two separate gaps in
the same prompt. Both are smaller and separate; neither blocked this fix.
