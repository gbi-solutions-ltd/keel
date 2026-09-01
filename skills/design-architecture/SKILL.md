---
name: design-architecture
description: Use when deciding how to build something, choosing a stack or datastore though not its schema, designing system structure or service boundaries, recording a technical decision, or restructuring a running system.
allowed-tools: [Read, Write, Grep, Glob, Bash, Agent, AskUserQuestion]
---

# Design Architecture

## Overview

Decide how this gets built, and write down why, so the next person can disagree with the
reasoning rather than guess at it.

**Core principle:** never present one option. A decision with no stated alternative is a
preference wearing a decision's clothes.

## Step 1: Pick the mode

| Mode | When | The binding constraint |
|---|---|---|
| `new` | Greenfield, or a genuinely separate new component | Stack is open, so choosing well matters most |
| `existing` | A change inside a running system | Established patterns win. Consistency beats your preference |
| `adr` | One decision needs recording, no new design | Speed. Capture the reasoning before it evaporates |

Read the PRD and stories, at `profile.artifacts` paths where set, otherwise under `<docs_root>`. In
`existing` mode follow [references/existing-mode.md](references/existing-mode.md). Designing against
requirements you have not read produces an architecture for a different product.

## Step 2: Establish the forces

Before proposing anything, list what actually constrains the design: the `NFR` and `CON` entries
from the PRD, the team's existing skills, what must be integrated with, and what the operational
budget is. Name the one or two that dominate.

Most architecture arguments are really disagreements about which force dominates. Surfacing that
first turns a taste argument into a decision.

## Step 3: Propose two or three approaches

For each: how it works in three sentences, what it costs, what it forecloses, and when it would
be the wrong choice. Then recommend one and say why the others lost.

**Check library facts before naming a version.** If the `context7` plugin is installed, use it.
Otherwise read the vendor's own documentation, and say what you could not verify. Recommending an
API that no longer exists is the most common failure in this skill.

In `existing` mode, "keep doing what the codebase already does" is a real option and often the
right one. Deviating from an established pattern needs its own ADR.

**Put the choice to the user with `AskUserQuestion`**, your recommendation first, per
[../keel/references/asking-questions.md](../keel/references/asking-questions.md). This is the
decision the whole document rests on, so it is the one to ask rather than announce.

## Step 4: Write the design

Follow [references/design-template.md](references/design-template.md). Write to
`<docs_root>/architecture/<slug>.md`.

Diagrams are mermaid, always: a context and a container diagram, plus a sequence diagram for
each critical path. See [references/mermaid-patterns.md](references/mermaid-patterns.md).

Every design must state its failure modes. A design that only describes the happy path has not
been designed.

When the design commits to a user interface, run `keel profile set stack.has_ui true`. Downstream
skills branch on that field, which until now held init's guess.

## Step 5: Write an ADR per material decision

One ADR per decision that would be expensive to reverse or that a reasonable engineer would
question. Follow [references/adr-template.md](references/adr-template.md), writing to
`<docs_root>/decisions/ADR-NNNN-<slug>.md`.

ADRs are append-only. A decision that changes gets a new ADR superseding the old one; never
edit an accepted ADR, because the record of what was believed and when is the point.

**An ADR you write is `proposed`, never `accepted`.** Only a person accepts a decision. Name the
roles who must decide in `Deciders` rather than a person who has not spoken.

Each `decide` story produces an ADR here once its answer exists, and nothing until then.

## Step 6: Trace and hand off

State which requirement IDs each component satisfies, and name any requirement the design does
not address. Surface the open questions as choices too: one left sitting in section 11 blocks
`write-plan` later, silently. Then name `write-plan` as next. Do not start it.

## Common mistakes

| Mistake | Instead |
|---|---|
| One option, presented as the answer | Two or three, with the losers' reasons stated |
| Naming a version you did not check | Verify with `context7`, or say it is unverified |
| Redesigning a working system because you would have built it differently | `existing` mode: match the pattern, or write an ADR for deviating |
| Diagrams that restate the file tree | Diagram the runtime and the data flow, not the folders |
| Only the happy path | Failure modes are part of the design |
