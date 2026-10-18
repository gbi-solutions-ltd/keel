---
name: write-plan
description: Use when a design or stories exist and implementation is about to start, or the user asks for an implementation plan or a task breakdown, or asks to implement a small change.
allowed-tools: [Read, Write, Grep, Glob, Bash, Agent, AskUserQuestion]
---

# Write Plan

## Overview

Write the plan for an engineer who is capable but has no context for this codebase, no
knowledge of the problem domain, and an aversion to testing.

**Core principle:** every step is executable as written. If a step requires the reader to
decide something, you have not finished planning.

Why each step is as it is: [references/rationale.md](references/rationale.md). Read it before
changing a step.

## Step 1: Read the inputs

Check `profile.artifacts` for mapped paths first. Otherwise stories at
`<docs_root>/stories/<slug>.md`, architecture at `<docs_root>/architecture/<slug>.md`
if it exists, and `.keel/profile.json` for the verify commands. Read the ADRs the stories point at.

If no stories exist, stop and name `keel:write-user-stories` as next; it routes to `write-prd` where
no PRD exists. Small work with no stories follows `references/short-path.md` instead.

On a greenfield project every verify command is `null`. Task 1 creates the toolchain and writes them
into the profile; the template says how.

**Unanswered open questions block the tasks that depend on them.** Put them to the user as choices
with `AskUserQuestion`, per
[../keel/references/asking-questions.md](../keel/references/asking-questions.md), rather than
planning around them or picking silently.

Check story kinds. A `verify` story plans differently from a `build` one: its first task writes
a test for behaviour believed correct, and it only becomes implementation work if that test
fails.

## Step 2: Map the files before writing tasks

List every file to create or modify and what each is responsible for.

**Where the area to map is larger than you can hold, delegate the reading**: subagents in one
message, delegation profile `keel-fanout`, with each dispatch's description starting
`keel-fanout: `, each citing `path:line`. The predicate is the tree: more directories than you can
list from memory. Under that, read it yourself.

Their findings are leads; the decomposition stays yours.

Prefer small focused files. Files that change together belong together. In an existing codebase,
follow the established pattern even where you would do it differently.

## Step 3: Write the tasks

Follow [references/plan-template.md](references/plan-template.md). Write to
`profile.artifacts.plans` if that is set, otherwise `<docs_root>/plans/`, as `YYYY-MM-DD-<slug>.md`.

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's
gate. Fold setup and configuration into the task whose deliverable needs them. Split only where
a reviewer could reject one task while approving its neighbour.

**Every task carries a `Done when:` line**: a `profile.verify` command and its passing result, or,
where a task genuinely has none, a statement that there is no command.

Every task carries a `**Behaviours:**` list: each behaviour, with at least one example of an input
and the result it must give, such as "a net payout of 1000 at 3% is 970". The only verbatim code a
plan carries is a form another task consumes, in `**Interfaces:**`.

**Every task carries a `Depends on:` line** naming the tasks that must land first, or `none`.
Once the tasks are written, run `keel plan batches` and declare every batch it prints in the
header. The template says how.

## Step 4: No placeholders

Never write these placeholders:

- "TBD", "implement later", "fill in details"
- A behaviour with no example
- "Handle edge cases", "add validation" or "add error handling" without each edge or rule as a
  behaviour with its example
- "Similar to Task 3" instead of restating the behaviours. Tasks are read out of order
- A type, function, or method that no task defines

## Step 5: Self-review, then have it reviewed

**Run the self-review in [references/plan-template.md](references/plan-template.md) yourself.**

**Then dispatch a reviewer.** Brief in [references/plan-review.md](references/plan-review.md), model
`inherit`, with the dispatch's description starting `inherit: `. Fix what it returns, or record why
not.

## Step 6: Hand off

Report task count, story coverage, any concurrent batches and anything the plan could not settle.
Then ask one question carrying the routing and the delivery choice, for example "Approve, implement
on keel-implementer, deliver to a pull request", and write the answer into `**Implementer
routing:**` and `**Delivery:**`. Commit the plan alone, `docs(plans): <slug>`. On the default
branch, leave it uncommitted, start nothing and say so. Otherwise, on `pull-request`, start
`execute-plan`; on `hand-off`, name it and do not start it.
