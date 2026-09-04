---
name: context-budget
description: Use when a session is using too many tokens, when compaction keeps happening, when a session feels slow or forgetful, or when asked to audit context or token cost.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# Context Budget

## Overview

Measure what loads on every request, then move what does not need to be there.

**Core principle:** prompt caching holds only while the front of the request is byte-identical.
One volatile value at the front costs the whole cache, on every request, forever.

## Step 1: Measure the always-loaded layer

These load into every request in every session:

| Source | How to measure |
|---|---|
| `CLAUDE.md`, and any imported file | `wc -c`, divided by about 3.6 for tokens |
| `AGENTS.md`, if present | Same |
| `SessionStart` hook output | Run the hook, measure what it prints |
| Skill descriptions | Count skills, times about 44 tokens each. Sum ceiling 1,320 |

Report each with a number. "CLAUDE.md is large" is not a finding; "CLAUDE.md is 38,662 bytes,
roughly 10,000 tokens per request" is, because it can be compared to a budget.

## Step 2: Find the cache hazards

The expensive class of problem, and invisible without looking for it.

Anything volatile at the front of the request invalidates the cache from that byte onward. Look for:

- A date, timestamp, or "last updated" line in `CLAUDE.md`
- A branch name, git status, or commit hash injected at session start
- A hook that runs a command and injects its output
- A counter, a session id, or a "you have N skills" line

Each of these means every request pays full price for everything after it. A hook that injects live
values is the most costly pattern available, and it looks helpful.

**Order by stability.** Most stable content first, so an edit low down does not invalidate the top.

## Step 3: Move what does not belong

| Currently in the prefix | Belongs |
|---|---|
| Full coding standards | `<docs_root>/standards.md`, read by the skills that need it |
| Deployment procedures | `<docs_root>/runbooks/`, read when deploying |
| API or database reference | Read on demand |
| Session history, "last time you were" | On disk, read when relevant |
| Anything changing weekly | Out of the prefix entirely |

What stays: the behavioural rules, the verify commands, and where to find everything else. That is
roughly 450 tokens, not 10,000.

**Judging what is left.** If the `claude-md-management` plugin is installed, use its rubric on the
trimmed file. Otherwise judge it against the table above and say the rubric was not available.

## Step 4: Check the skills

Per skill: body word count against the 700 ceiling, description length, and any `@` link, which
force-loads at parse time.

Where a project has a validator, run it. In keel that is `tests/validate-skills.sh`.

## Step 5: Report

Write `<docs_root>/context-audit.md`: a table of sources with tokens against budget, the cache
hazards with the cost of each, and the recommended moves with the tokens each saves.

Quantify every recommendation. "Move the deployment section" is ignorable; "move the deployment
section, saving about 1,100 tokens per request" is not.

## Step 6: Session hygiene, which is the user's lever

Worth saying explicitly, because no skill can enforce it: `/clear` between unrelated tasks, point
at a file rather than pasting it, and start a task from its plan rather than re-explaining the
project. The artifact chain means nothing is lost by clearing.

## Step 7: Empty the handoff before it is discarded

`.keel/handoff.md` is session state and it is git-ignored, so it is thrown away rather than kept.
Before that happens, move anything durable in it to its real home: a decision to an ADR under
`<docs_root>/decisions/`, everything else to the artifact it belongs to.

Skipping this is how a decision recorded nowhere else is lost. Read the handoff and ask, per
paragraph, whether it is state or knowledge. State goes; knowledge moves first.

## Common mistakes

| Mistake | Instead |
|---|---|
| "The context is bloated" | Give the number, per source, against a budget |
| Injecting live git state at session start | Nothing volatile in the prefix, ever |
| Trimming prose to save tokens | Move whole sections out. Trimming saves tens, moving saves thousands |
| Ignoring skill descriptions | They load every session. 25 skills is about 1,130 tokens |
| A recommendation with no saving attached | Quantify it, or it will not be actioned |
