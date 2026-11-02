# Idea: hold an implementer's `git stash` the way a reviewer's is held

| | |
|---|---|
| Raised by | Bernard, 2026-11-02, as a follow-up: "implementers running git stash. It has recurred three times and no hook covers implementers" |
| Status | agreed 2026-11-02 by Bernard: any subagent, with open question 1 confirmed |
| Recommendation | Build something smaller than a second review-guard: refuse the stash-writing forms of `git stash` to every subagent call, and add the rule to the implementer brief. Open question 1 asks Bernard to confirm the reach |
| Next | `write-plan` (short path) |

## The problem

Implementers dispatched by `execute-plan` run `git stash` on a tree whose stash every worktree
shares. They have done it four times in six weeks. Each time the coordinator had to audit the
stash and the tree before trusting the task, and once the stash held a plan's entire staged diff.

**Evidence.** Four instances, not the three remembered, because the 2026-09-19 plan holds two:

| Date | Where | What happened | How it was dispatched |
|---|---|---|---|
| 2026-09-19 | `docs/plans/2026-09-19-make-keel-enforceable-outside-the-agent.md:580-586` | A subagent created a stash "apparently to isolate a test run" and never popped it. The stash held "the entire staged diff for this plan including the correct fix already made". The subagent was stopped with `TaskStop`, and one file was restored from the stash by hand | No keel agent type: `agents/keel-implementer.md` was added in `a60df6a` on 2026-10-17 |
| 2026-09-19 | same plan, `:1119-1123` | The fix's implementer "used `git stash` mid-task despite being explicitly told not to", and `git stash pop` conflicted. It resolved the conflict by hand | As above. The rule was in its dispatch prompt |
| 2026-10-16 | `docs/plans/2026-10-16-plans-declare-batches.md:190` | "the implementer used git stash once against its rules, tree verified clean", inside worktree `g6-t1` | Sonnet on `keel-implementer` routing, a day before the agent type existed |
| 2026-10-29 | `docs/plans/2026-10-29-claude-code-only.md:1714` | "implementer ran git stash and pop once on the shared tree, tree intact" | `inherit` routing, which dispatches by model and description, not by a keel agent type (`skills/execute-plan/references/subagent-prompts.md:309-312`) |

The reviewer's own instance, on 2026-10-12, is the one `hooks/review-guard` now holds, and it is
not counted here.

## What was asked for

> An idea record on implementers running git stash. It has recurred three times and no hook covers
> implementers.

The request names a hook. The problem is narrower than the hook it suggests: the harm is the
shared stash, not the implementer's git in general.

## The case against

**The strongest argument for not building this at all.** No instance lost work. Three of the four
ended "tree intact" or "verified clean", and the fourth was recovered byte for byte. A hook buys a
refusal for something that has cost audit time but no work. And it
reads a command string, so `sh -c "git stash"` or a script still gets through, as
`hooks/review-guard`'s header says of itself.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | An audit of the stash and tree after each instance, about one every ten days so far | The 2026-09-19 stash held a whole plan's staged work until someone looked. The next one may not be found before a `git stash drop` or a `git stash clear` |
| Do it manually | Add "never `git stash`" to the implementer brief (`subagent-prompts.md` section 1) and `agents/keel-implementer.md`, neither of which says it today | The 2026-09-19 second instance was told not to and stashed anyway. A prompt binds only as far as the model follows it, the reason `hooks/review-guard:8-10` gives for existing |
| Buy it | A Claude Code permission rule such as `deny: Bash(git stash:*)` | A permission rule cannot tell a subagent from the main session, so it would also refuse the person their own `git stash`. Matching is on the string, with the same `sh -c` gap as a hook |
| Build something smaller | Refuse only the stash-writing forms of `git stash` to every call that carries an `agent_type`, and add the rule to the brief | **The recommendation.** See the variants below |

**Variants of building it**, kept apart from the alternatives above:

| Variant | What it covers | Why not this |
|---|---|---|
| Key a hook on `keel:keel-implementer`, as review-guard keys on the reviewer | Implementers dispatched as that agent type | **It would have caught none of the four.** Three predate the agent type and the fourth ran on `inherit`, which never uses it |
| Route every implementer through a typed keel agent, then key on it | Every keel implementer | Changes `inherit` routing, which ADR-0008 lets a plan choose, to fix a git habit. The `inherit` row would need its own agent type per model |
| Refuse the stash to any subagent (chosen scope) | Every subagent in a keel project, keel's or the user's own | Reaches agents keel did not dispatch. That is open question 1 |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| Every subagent's Bash call carries an `agent_type`, and the main session's never does | The 2026-10-17 probe generalises | `docs/harness-support.md:34`: "no agent_type for the main session, general-purpose for a general-purpose subagent" | **Checked** on 2.1.302 for general-purpose and plugin agents. Not checked for agents a user defines in `.claude/agents/` |
| No subagent has a legitimate use for the stash-writing forms | Nothing keel dispatches is told to stash | `grep -rn stash skills agents` finds stash only as something forbidden or the user's call | **Checked** for keel's own prompts. A user's own agents are unknown |
| `git stash list` and `git stash show` are harmless to allow | They only read | git documentation | Believed, not checked against a case where the reading forms matter |
| The habit is a model reaching for a baseline, not an adversary | Each report gives a test-isolation or baseline reason | The four plan notes above | **Checked**: the 09-19 reason is test isolation; the others give none |

**This argument is weaker than it looks.** Nothing at a task boundary would find a stray stash. The
coordinator checks `git status --porcelain` before every dispatch
(`skills/execute-plan/references/subagent-prompts.md:230`), but a stash empties the tree, so status
reads clean while the stash holds the work. That is how the 2026-09-19 stash hid a whole plan's
staged diff. Nothing in `execute-plan` reads `git stash list`; only the eval staging records it
(`stash.txt`, `docs/plans/2026-10-18-prune-follow-ups.md:104`). Each instance was found in a
report or by an unexpected diff, not by a check.

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| review-guard's cheap filter passes only the reviewer's calls | The "cheap filter" in `hooks/review-guard` returns at once unless the input names `keel:keel-reviewer` | Widening the scope to every subagent means a check on every subagent Bash call, which is the cost to measure |
| review-guard already parses where a git command acts and refuses `stash` in any form for the reviewer | `hooks/review-guard:31-36`, and its word list at `:116-119` | The parsing exists. An implementer must keep `add` and `commit` in its own worktree, so the reviewer's list cannot be reused as it stands, only its `stash` entry |
| The implementer brief and agent carry no stash rule | `skills/execute-plan/references/subagent-prompts.md` section 1 (`:15-84`) and `agents/keel-implementer.md` name `git add` and commit rules only. Stash is forbidden only in the two review prompts (`:100-101`, `:152-153`) | The "do it manually" alternative has never been tried in the standing brief, only in one dispatch on 2026-09-19 |
| Implementers do commit, in a concurrent batch's private worktree | `skills/write-plan/references/plan-template.md`, "the one exception is a declared concurrent batch" | Any guard for implementers has to leave `commit` alone there. A stash-only guard does |
| `review-guard` denies, it does not ask | `hooks/review-guard:38-40`, decided by Bernard on 2026-10-17 | The same choice applies here, and a `deny` reaches the agent as a reason it can read |

## Open questions

1. **May keel refuse `git stash` to subagents it did not dispatch?** **Answer, Bernard 2026-11-02:
   yes, confirmed.** Bernard chose any subagent as
   the scope to weigh on 2026-11-02. Building it means a keel project's own agents, defined by the
   user, lose the stash-writing forms too. The default offered: yes, because the stash is shared by
   every worktree and the refusal reason names the hook, so a user who needs it can see why.
2. **Which forms are refused?** The default: every form except `list` and `show`, the same line
   `review-guard` draws.
3. **Does the brief change land first, on its own?** The default: yes, in the same plan, because it
   costs nothing and the hook is not a boundary.

## Recommendation

**Build something smaller:** refuse the stash-writing forms of `git stash`
to every call carrying an `agent_type`, and add the never-stash rule to the implementer brief and
`agents/keel-implementer.md`. A hook keyed on the implementer type would have caught none of the four
instances, a stated rule failed once already, and no boundary check would find a stash. Bernard chose
this scope knowing it reaches a user's own agents; question 1 asks him to confirm it before the
plan. Next: `write-plan`, short path.

## Not decided here

Whether this extends `hooks/review-guard` or is its own hook, whether it needs a new ledger
primitive or reuses `pretooluse_agent_type`, the deny wording, and the test cases. Those belong to
the plan.
