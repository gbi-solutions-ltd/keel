---
name: write-plan
description: Use when a design or stories exist and implementation is about to start, or the user asks for an implementation plan, a task breakdown, or how to build something.
allowed-tools: [Read, Write, Grep, Glob, Bash]
---

# Write Plan

## Overview

Write the plan for an engineer who is capable but has no context for this codebase, no
knowledge of the problem domain, and an aversion to testing.

**Core principle:** every step is executable as written. If a step requires the reader to
decide something, you have not finished planning.

## Step 1: Read the inputs

Check `profile.artifacts` for mapped paths first. Otherwise stories at
`<docs_root>/stories/<slug>.md`, architecture at `<docs_root>/architecture/<slug>.md`
if it exists, and `.keel/profile.json` for the verify commands. Read the ADRs the stories point
at; a plan that contradicts an accepted decision is worse than no plan.

If no stories exist, **REQUIRED SUB-SKILL:** `keel:write-user-stories`.

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

List every file to create or modify and what each is responsible for. Decomposition decisions
get locked in here, and they are much cheaper to change now than inside task 7.

Prefer small focused files. Files that change together belong together. In an existing codebase,
follow the established pattern even where you would do it differently.

## Step 3: Write the tasks

Follow [references/plan-template.md](references/plan-template.md). Write to
`<docs_root>/plans/YYYY-MM-DD-<slug>.md`.

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's
gate. Fold setup and configuration into the task whose deliverable needs them. Split only where
a reviewer could reject one task while approving its neighbour.

**Every task carries a `Done when:` line**: a `profile.verify` command and its passing result.

Every task follows the same five steps: write the failing test, run it and watch it fail, write
minimal code, run it and watch it pass, commit. Use the exact commands from
`profile.verify`, never a guess at what the project uses.

## Step 4: No placeholders

These are plan failures, not shortcuts. Never write them:

- "TBD", "implement later", "fill in details"
- "Add appropriate error handling", "handle edge cases", "add validation"
- "Write tests for the above" without the test code
- "Similar to Task 3" instead of repeating the code
- A type, function, or method that no task defines

Each one moves a decision from you to someone with less context. That is the opposite of
planning.

## Step 5: Self-review

Run this yourself. It is a checklist, not a subagent dispatch.

1. **Story coverage:** every story in scope maps to at least one task. Name any that do not.
2. **Placeholder scan:** search for the phrases above. Fix each.
3. **Name consistency:** a function called `clearLayers()` in task 3 and `clearFullLayers()` in
   task 7 is a bug you are shipping into someone's afternoon.
4. **Command accuracy:** every command that *verifies* comes from `profile.verify`, never from
   your idea of what the stack uses. Investigative and read-only commands (`grep`, `git log`,
   `ls`) need no profile entry.

## Step 6: Hand off

Report task count, story coverage, and anything the plan could not settle. Offer two execution
routes: `execute-plan` inline with checkpoints, or delegated with a fresh subagent per task.
Do not start either.

## Common mistakes

| Mistake | Instead |
|---|---|
| Steps that describe rather than instruct | Show the code. "Add validation" is not a step |
| Guessing the test command | Read `profile.verify`. Guessing produces a plan that fails at step 2 |
| Planning `verify` stories as new work | Its first task is a test for existing behaviour |
| One giant task | If a reviewer could reject half of it, it is two tasks |
| Skipping the failing-test step | Watching it fail is what proves the test works |
| A done condition that describes rather than commands | Name the command and its expected result |
