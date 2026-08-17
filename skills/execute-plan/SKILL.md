---
name: execute-plan
description: Use when an implementation plan exists and the user wants it built, or says to start building, execute the plan, or go ahead.
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
| The PRD is a draft and the stories are provisional | The work may be cancelled |
| You are on the default branch | Never implement on `main` without consent |
| A command the plan uses **to verify** is absent from the profile | It cannot be verified as written |

These are not obstacles to route around. A plan that says it is blocked is doing its job.

An open question is the blocker you can often clear here: ask it as a choice
([../keel/references/asking-questions.md](../keel/references/asking-questions.md)), do not just
report it.

## Step 2: Review the plan critically

Read every task before starting any. Look for: a task depending on a file no task creates, a
name used in task 7 that task 3 defined differently, a step you cannot execute as written, and
anything contradicting an accepted ADR.

Raise all of it now. Finding it at task 6 wastes the five you already did.

## Step 3: Choose a mode

| Mode | When | Cost |
|---|---|---|
| Inline | Short plans, or the user wants to watch | Implementation noise fills the main context |
| Delegated | Long plans, independent tasks | One subagent per task keeps the main context clean |

In delegated mode, dispatch the task **verbatim** plus the plan's whole Global constraints block. A
summary is where "never start on the default branch" quietly disappears. Then review in two passes:
first does it match the task, then is the code sound. One task at a time, and never dispatch the next
while the previous is unreviewed.

Prompts for all three are in
[references/subagent-prompts.md](references/subagent-prompts.md). Read it before the first dispatch.

## Step 4: Execute, one task at a time

For each task: mark it in progress, follow its steps exactly, run its `Done when:` command, tick
the checkboxes only on output you have read, then commit as the task specifies.

**REQUIRED SUB-SKILL:** `keel:tdd`. The plan's steps assume it.

Tick on output you read; note any step you did not witness. A plan whose checkboxes lie is worse
than one with none, because the next person trusts it.

## Step 5: Stop when blocked

Stop immediately, and ask, when: a verification fails in a way you cannot explain, a step is
ambiguous, a dependency is missing, a `verify` command does not exist, or the same failure
recurs twice.

**REQUIRED SUB-SKILL:** `keel:debug` for any failure. Do not adjust the plan to make a
failing step pass; that is fixing the thermometer.

Stopping costs a question. Guessing costs a day and someone's trust.

## Step 6: Report

Say which tasks completed, which were skipped and why, what deviated from the plan and why, and
what remains. Then name `review-code` and `ship`. Do not start them.

If you deviated from the plan, say so explicitly and update the plan file to match reality.

## Common mistakes

| Mistake | Instead |
|---|---|
| Starting on a plan blocked by a `proposed` ADR | Step 1. Say what blocks it and stop |
| Reading task 1 and starting | Read all of them first |
| Editing the plan so a failing step passes | Fix the code, or stop and ask |
| Leaving checkboxes unticked | The plan is the progress record |
| Deviating quietly because your way is better | Raise it. Then update the plan if agreed |
| Continuing past an unexplained failure | Stop. Use `debug` |
