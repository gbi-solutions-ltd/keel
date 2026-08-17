# Idea: done is a command that passed, not a word

| | |
|---|---|
| Raised by | Bernard, 2026-08-16 |
| Status | agreed, 2026-08-16, both stages |
| Recommendation | Build something smaller, in two stages: a per-task done condition first, a structural Stop hook second |
| Next | `docs/plans/2026-08-16-done-conditions-model-pins-and-install-docs.md`, tasks 3, 4 and 5 |

**Agreed with one change to the recommendation.** Stage 2 was recommended for after stage 1 had run
on real work, and was agreed for the same pass instead. The ordering survives inside that pass:
tasks 3 and 4 make the condition legible before task 5's hook checks for it. Open question 1 below
is therefore still open at the point the hook is built, which is why the plan's task 5 keeps the
guard structural and adds an eval scenario rather than trusting the design.

## The problem

An engineer is told work is complete, finds it is not, and from then on re-checks every claim by
hand, which removes the saving the tool existed to produce.

**Evidence.** Asserted from use rather than cited from a transcript. No specific instance was named
when this was raised, and that gap is the first open question below. What is not asserted is the
structural gap: keel says "before claiming done" in three places and nothing anywhere checks it.

## What was asked for

> Now that there's TDD enforced/involved, when executing the plan or handling a coding task,
> declaration of done needs to be based on something. You should never claim that work is done when
> it isn't and there should be no excuse for not completing a task. Where possible, iterations can
> happen against test suites or defined checklists to concretize DONE. So even when agents are
> working in auto-mode, verification of what's done is a must.

## The case against

**Strongest argument for not building this at all.** keel already says this three times, in prose,
and prose is what failed. The always-loaded block says "run these before claiming anything is done",
`tdd` has a five-item "Before claiming done" list, and `ship` is a real gate. A fourth sentence in a
fourth file is the cheapest possible response and the one with the best track record of changing
nothing. Worse, the obvious enforcement (a `Stop` hook that reads the final message for the word
"done") is a string matcher over English: it will miss "that's the retry path covered" and fire on
"done reading the config", and a guard that cries wolf gets switched off. It would be switched off
alongside `sensitive-guard`, which is in the same `hooks.json` and is the one guard that must never
be disabled.

**Alternatives**

| Option | What it costs | Why not this |
|---|---|---|
| Do nothing | Nothing | The `ship` gate only fires when the user says ship. A task declared done and never shipped is never checked |
| Do it manually | The user asks "did you run the tests?" every time | That is the cost being complained about, moved rather than removed |
| Buy it | Nothing available | No tool sells "did the agent actually verify" |
| Build something smaller | One line per plan task | Makes DONE a command with an expected result, without parsing English |

**Variants of building it**

| Variant | Note |
|---|---|
| Per-task `Done when:` in the plan template, enforced by `execute-plan` | Structural, cheap, works in delegated mode because the brief carries it |
| `Stop` / `SubagentStop` hook keyed on *edits without verification* | Structural. Fires when the turn wrote code and never ran `profile.verify.test`. No English matching |
| `Stop` hook keyed on the words "done", "complete", "implemented" | Rejected above. English matching |

**Assumptions this rests on**

| Assumption | True if | How we would know | Checked? |
|---|---|---|---|
| A `Stop` hook can see the turn's tool calls | The event input carries `tool_calls` and `last_assistant_message` | Documented on the hooks page; not yet run against a real turn | Documented, not run |
| Blocking `Stop` does not loop | The model runs the verify command and the second `Stop` passes | Needs a test with a deliberately unverified turn | No |
| The profile's `verify.test` is recognisable in a `Bash` call | The command string appears in the tool input | True for `tests/run-tests.sh`; unproven for commands with wrappers or a changed cwd | No |
| A per-task done condition is writable for every task | Some tasks are documentation-only | Documentation tasks would need a non-test check, or an explicit "no command" marker | No |

## What the system says

| Finding | Evidence | What it means for the idea |
|---|---|---|
| The done checklist exists but is unenforced prose | `skills/tdd/SKILL.md`, "Before claiming done" | The rule is written. Writing it again is not the fix |
| The real gate only fires on request | `skills/ship/SKILL.md`, the eight-check gate | Everything short of shipping is ungated |
| The plan is the progress record, ticked by the same agent that did the work | `skills/execute-plan/SKILL.md`, step 4 | Nothing distinguishes a ticked box from an honest one |
| Delegated mode dispatches subagents with no completion check | `skills/execute-plan/SKILL.md`, step 3 | This is the auto-mode case the request names. `SubagentStop` is where it attaches |
| No `Stop` or `SubagentStop` hook exists | `hooks/hooks.json` | The enforcement point is unused. `sensitive-guard` shows the shape a guard takes here |
| Plan tasks carry `*Verify:*` lines already | `IMPLEMENTATION-PLAN.md`, task 7.6 | The convention exists informally. Stage 1 is mostly making it required and machine-checkable |

## Open questions

1. **What was the instance?** A real transcript where done was claimed falsely would say whether the
   failure is a skipped verify command or a passing command whose result was misread. Those need
   different fixes and only one of them is a hook.
2. **Does the block fire on a subagent that was told to stop early?** A user interrupt and an agent
   giving up look similar from `SubagentStop`.
3. **What happens on a project with `verify.test` set to `null`?** The hook cannot check anything and
   must not block. Silent pass, or a warning?

## Recommendation

**Build something smaller, in two stages.**

Stage 1: `write-plan` requires a `Done when:` line per task, a command plus its expected result, and
`execute-plan` may not tick a checkbox without that command's output in the transcript. This makes
DONE checkable, works in delegated mode because the brief carries the line, and needs no hook.

Stage 2, only after stage 1 has run on real work: a `Stop` and `SubagentStop` guard that fires on
the structural condition, *this turn edited code and never ran the profile's test command*, not on
the word "done".

Stage 1 first because it is the thing the hook would otherwise have to infer.

## Not decided here

Whether the guard blocks or warns; how a documentation-only task states its done condition; whether
`keel doctor` should check that plans have done conditions.
