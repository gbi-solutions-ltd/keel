---
name: write-user-stories
description: Use when a PRD or written requirements need breaking into deliverable work, or the user asks for user stories, epics, tickets, or a backlog.
allowed-tools: [Read, Write, Grep, Glob, AskUserQuestion]
---

# Write User Stories

## Overview

Turn requirements into work someone can pick up, finish, and prove finished.

**Core principle:** every story traces to a requirement ID, and every requirement is covered by
a story. Coverage is checkable, so check it rather than assuming it.

## Step 1: Read the PRD

Read the PRD at `profile.artifacts.prd` if that is set, otherwise `<docs_root>/prd/<slug>.md`. If
neither exists, **REQUIRED SUB-SKILL:** `keel:write-prd`.
Stories invented without requirements are a backlog nobody agreed to.

Note any requirement whose status is `inferred` or `disputed`. Those produce stories that may be
cancelled, so mark them rather than letting them look settled.

**If the PRD has open questions that block requirements, put them to the user as choices** with
`AskUserQuestion`, per [../keel/references/asking-questions.md](../keel/references/asking-questions.md),
before writing the stories they affect. Writing a story against an unanswered question produces
work that gets cancelled.

**Ask only what the user can settle now.** A question needing a measurement, a lawyer, or a
decision they already deferred becomes a `decide` story instead. Re-asking what the PRD knowingly
left open is theatre, and it teaches people the process wastes their time.

## Step 2: Decide each story's kind

For a PRD written `from-repo`, most requirements already have working code. Writing "build X"
for something that exists wastes a sprint. Classify first:

| Kind | When | Produces |
|---|---|---|
| `build` | Nothing implements this requirement | Normal implementation work |
| `verify` | Code exists but no test proves it | A test, and a fix only if the test fails |
| `fix` | Code exists and contradicts the requirement | A failing test, then the fix |
| `decide` | The requirement is `disputed`, or an open question blocks it | A decision, not code |

`decide` stories come first in the backlog. Building on an undecided requirement is rework.

## Step 3: Write epics, then stories

An epic groups stories that ship together and deliver something a user would notice. A story is
one testable behaviour change, small enough that one person finishes it without a handoff.

Split when the halves could ship separately and one is useful without the other, when a story
needs two people, or when its acceptance criteria exceed about six scenarios.

"and" in a title is a prompt to check, not a defect. Upload and download, rotate and purge, query
and list: each is one story, because shipping half delivers nothing.

Follow [references/story-template.md](references/story-template.md) for the exact shape. Write to
`<docs_root>/stories/<slug>.md`.

Every story carries: an ID, its kind, the requirement IDs it satisfies, `As a / I want / So
that`, Gherkin acceptance criteria, a size, and its dependencies.

## Step 4: Prove coverage both ways

This is the step that makes the document trustworthy, and it is mechanical.

**Forward:** every `FR` and `NFR` in the PRD appears in at least one story's `Satisfies` field.
List any that do not. A requirement with no story is either out of scope, and belongs in the
PRD's Out of scope section, or it is a gap.

**Backward:** every story's `Satisfies` names a requirement that exists in the PRD. A story
satisfying nothing is scope you invented; delete it or take it back to `write-prd`.

Put the resulting coverage table at the end of the document. Do not claim coverage you did not
tabulate.

## Step 5: Order and hand off

Order by dependency first, then by value. Mark the critical path.

Report: story count by kind, any uncovered requirements, and the `decide` stories that block
others. Then name `design-architecture` or `write-plan` as next. Do not start either.

## Common mistakes

| Mistake | Instead |
|---|---|
| "Build X" for code that already exists | Step 2. Most `from-repo` stories are `verify`, not `build` |
| Acceptance criteria restating the title | State observable outcomes, one scenario per behaviour |
| Stories with no requirement ID | Every story traces back, or it is invented scope |
| Claiming full coverage without tabulating it | Step 4 produces a table. No table, no claim |
| Estimating in hours | Size relatively. Hours invite a commitment nobody made |
