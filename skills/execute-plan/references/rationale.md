# Why execute-plan's steps are as they are

The reasons behind `execute-plan`'s steps. The steps themselves are in [SKILL.md](../SKILL.md).

## Overview

Deviating silently is worse than stopping, because nobody knows what was actually built.

## Step 1: Check the preconditions

Two of the conditions carry exceptions, and both exceptions are common.

Why each condition blocks:

| Condition | Why it blocks |
|---|---|
| An ADR the plan depends on is `proposed` | Nobody has agreed it |
| The plan has open questions that block its own tasks | The plan says it is not ready |
| The PRD is a draft, or the stories are provisional | The work may be cancelled |
| A command the plan uses to verify cannot produce a verdict | It cannot be verified as written |

The conditions are not obstacles to route around because a plan that says it is blocked is doing
its job.

An open question is the blocker you can often clear at this step, which is why it is asked as a
choice rather than reported.

## Step 2: Review the plan critically

Raise everything before starting: finding it at task 6 wastes the five you already did.

## Step 3: Delegate, unless you say why not

The coordinator writes no production code because every edit it makes itself is the only change
in the run that no review pass sees: the diff both reviewers are given is the subagent's.

Five tasks is not short because that is the size this skill exists for.

The task goes out verbatim, with the whole Global constraints block, because a summary is where
"never start on the default branch" quietly disappears.

Review follows the references because the passes depend on what the task touches.

[parallel-batches.md](parallel-batches.md) has the batch rules and what breaks without them.

## Step 4: Execute, one task at a time

`keel:tdd` is required because the plan's steps assume it.

## Step 5: Stop when blocked

Adjusting the plan to make a failing step pass is fixing the thermometer.

Stopping costs a question. Guessing costs a day and someone's trust.

## Common mistakes

Re-dispatch rather than make the small fix yourself: your edit is the one nobody reviews.
