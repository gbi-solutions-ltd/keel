---
name: execute-plan
description: Use when an implementation plan exists and the user wants it built: says to start building, execute the plan, or go ahead.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion]
---

# Execute Plan

## Overview

Work through a plan task by task, verifying each before starting the next.

**Core principle:** the plan is the contract. Deviating silently is worse than stopping, because
nobody knows what was actually built.

## Step 1: Check the preconditions

Read the plan, the profile, and any ADR the plan cites.

**Refuse to start when any of these hold**, and say which. Two carry exceptions and both are
common, so read [references/preconditions.md](references/preconditions.md) before refusing:

| Condition | Why it blocks |
|---|---|
| An ADR the plan depends on is `proposed` | Nobody has agreed it |
| The plan has open questions that block its own tasks | The plan says it is not ready |
| The PRD is a draft, or the stories are provisional | The work may be cancelled |
| You are on the default branch | Never implement on the default branch without consent |
| A command the plan uses **to verify** cannot produce a verdict | It cannot be verified as written |

These are not obstacles to route around. A plan that says it is blocked is doing its job.

An open question is the blocker you can often clear here: ask it as a choice
([../keel/references/asking-questions.md](../keel/references/asking-questions.md)), do not just
report it.

## Step 2: Review the plan critically

Read every task before starting any. Look for: a task depending on a file no task creates, a
name used in task 7 that task 3 defined differently, a step you cannot execute as written, and
anything contradicting an accepted ADR.

Raise all of it now. Finding it at task 6 wastes the five you already did.

## Step 3: Delegate, unless you say why not

**Delegated is the default.** You are the coordinator: you dispatch, review, tick, commit and
report, and you write no production code. Every edit you make yourself is the only change in the
run that no review pass sees, because the diff both reviewers are given is the subagent's.

Inline is still right for a plan of one or two tasks, or when the user asks to watch. Five tasks is
not short; that is the size this skill exists for. Take it by **naming it and why in one line**, not
by drifting into it. Step 4's execution is written for whoever holds the keyboard: in inline mode
that is you, in delegated mode the implementer. Ticking, stopping (step 5) and reporting (step 6)
are yours in both modes.

In delegated mode, dispatch the task **verbatim** plus the plan's whole Global constraints block. A
summary is where "never start on the default branch" quietly disappears. Then review in two passes:
first does it match the task, then is the code sound.

The three prompts, one implementer and two reviewers, are in
[references/subagent-prompts.md](references/subagent-prompts.md). Read it before the first dispatch.

**Tasks the plan declares as a concurrent batch may be dispatched together**, each in its own
worktree. A batch is eligible only where the plan says so and its tasks meet the conditions in
[references/parallel-batches.md](references/parallel-batches.md); everything else is one task at a
time, and never the next while the previous is unreviewed.
[references/parallel-batches.md](references/parallel-batches.md) has the rules and what breaks
without them.

## Step 4: Execute, one task at a time

For each task: follow its steps exactly, run its `Done when:` command, then
hand over as the task specifies. Resume with `keel plan status`; tick with `keel plan tick`, or by
hand where `keel` cannot run or reports the plan unaddressable.

**REQUIRED SUB-SKILL:** `keel:tdd`. The plan's steps assume it.

Tick on output you read. Every step you did not perform or witness, including a file already on disk
when you arrived, gets its own note in the plan file now, before reporting back: recording status is not
a request you wait on, unlike fixing the underlying code, which is. A plan whose checkboxes lie is
worse than one with none, because the next person trusts it.

## Step 5: Stop when blocked

Stop immediately, and ask, when: a verification fails in a way you cannot explain, a step is
ambiguous, a dependency is missing, a `verify` command does not run, or the same failure
recurs twice.

**REQUIRED SUB-SKILL:** `keel:debug` for any failure this task caused, through Phase 3; a red
`keel:tdd`'s start record already lists is recorded beside the task, not debugged. In delegated mode
debug's Phase 4 goes back to an implementer as a re-dispatch carrying the explanation, never your
edit. Do not adjust the plan to make a failing step pass; that is fixing the thermometer.

Stopping costs a question. Guessing costs a day and someone's trust.

## Step 6: Report

Say which tasks completed, which were skipped and why, what deviated from the plan and why, and
what remains. Then name `review-code` and `ship`. Do not start them.

If you deviated from the plan, say so explicitly and, once the user has agreed the deviation, update
the plan file to match.

## Common mistakes

| Mistake | Instead |
|---|---|
| Leaving checkboxes unticked | The plan is the progress record |
| Deviating quietly because your way is better | Raise it. Then update the plan if agreed |
| Making the small fix yourself instead of re-dispatching | Re-dispatch. Your edit is the one nobody reviews |
