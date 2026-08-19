---
name: write-plan
description: Use when a design or stories exist and implementation is about to start, or the user asks for an implementation plan, a task breakdown, or how to build something.
allowed-tools: [Read, Write, Grep, Glob, Bash, Agent, AskUserQuestion]
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

**Where the area to map is larger than you can hold, delegate the reading**: `Explore` agents in
one message, model `sonnet`, each citing `path:line`, said in one line. The predicate is the tree,
not the mood: more directories than you can list from memory. Under that, read it yourself.

Their findings are leads; the decomposition stays yours. Step 4 forbids naming a function no task
defines, and second-hand knowledge is how that creeps in.

Prefer small focused files. Files that change together belong together. In an existing codebase,
follow the established pattern even where you would do it differently.

## Step 3: Write the tasks

Follow [references/plan-template.md](references/plan-template.md). Write to
`<docs_root>/plans/YYYY-MM-DD-<slug>.md`.

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's
gate. Fold setup and configuration into the task whose deliverable needs them. Split only where
a reviewer could reject one task while approving its neighbour.

**Every task carries a `Done when:` line**: a `profile.verify` command and its passing result.

**Every task carries a `Depends on:` line** naming the tasks that must land first, or `none`;
absent is read as unknown and runs alone. Where tasks depend on nothing outstanding and no two name
the same file, declare a concurrent batch in the header. The template states the three further
conditions a batch must also meet.

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

## Step 5: Self-review, then have it reviewed

**These four are mechanical. Run them yourself; a dispatch is slower and no more reliable.**

1. **Story coverage:** every story in scope maps to at least one task. Name any that do not.
2. **Placeholder scan:** search for the phrases above. Fix each.
3. **Name consistency:** a function called `clearLayers()` in task 3 and `clearFullLayers()` in
   task 7 is a bug you are shipping into someone's afternoon.
4. **Command accuracy:** every command that *verifies* comes from `profile.verify`, never from
   your idea of what the stack uses. Investigative and read-only commands (`grep`, `git log`,
   `ls`) need no profile entry.

**Then dispatch a reviewer.** The four above compare the plan to itself; none opens the codebase, so
a plan can pass all four and still be unbuildable. Measured: a run doing exactly these four passed a
plan whose central story could not be delivered, catching it only by opening a file no item asked
for. Brief in [references/plan-review.md](references/plan-review.md), model `inherit`, said in one
line. Fix what it returns, or record why not.

## Step 6: Hand off

Report task count, story coverage, any concurrent batches, and anything the plan could not settle.
Name `execute-plan` as next. Do not start it.

## Common mistakes

| Mistake | Instead |
|---|---|
| Steps that describe rather than instruct | Show the code. "Add validation" is not a step |
| Guessing the test command | Read `profile.verify`. Guessing produces a plan that fails at step 2 |
| Planning `verify` stories as new work | Its first task is a test for existing behaviour |
| One giant task | If a reviewer could reject half of it, it is two tasks |
| Skipping the failing-test step | Watching it fail is what proves the test works |
| A done condition that describes rather than commands | Name the command and its expected result |
