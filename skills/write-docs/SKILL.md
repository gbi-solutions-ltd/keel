---
name: write-docs
description: Use when asked to write or update a README, document a feature or module, produce a runbook, draw a process flow or diagram, or create onboarding material.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, Agent]
---

# Write Docs

## Overview

Write the document someone will actually need, at the moment they need it.

**Core principle:** every instruction is executed before it is written down. An untested quickstart
is the most expensive documentation there is, because it fails at the moment a new joiner has least
context.

## Step 1: Pick the type

| Type | Output | Reader |
|---|---|---|
| README | `README.md` | Someone deciding whether this concerns them, then running it |
| Runbook | `<docs_root>/runbooks/<topic>.md` | Someone at 3am with a page open |
| Process flow | mermaid, inside the relevant doc | Someone tracing how a thing works |
| API reference | `<docs_root>/api/` | Someone integrating |
| Onboarding | `<docs_root>/onboarding.md` | Someone on day one |
| ADR | Not this skill | Use `keel:design-architecture` |

Each has a different reader in a different state. A README written for the 3am reader is
unreadable, and a runbook written for the browsing reader is useless.

Auditing what the docs already claim, rather than writing them, is
[references/claims-audit.md](references/claims-audit.md).

## Step 2: Generate what can be generated

Prose restating what the code already declares goes stale silently. Prefer the generator, and commit
its wiring rather than its output pasted in by hand.

| Document | Generated from |
|---|---|
| API reference | OpenAPI from the framework's decorators or schema |
| Code reference | JSDoc, docstrings, or the stack's documenter |
| Release notes | Conventional Commits |

Hand-write only what no generator can produce: why the thing exists, how the parts fit, what the
reader must do. Where a generator would fit and is not wired up, wiring it up is the work.

## Step 3: Gather, do not invent

Read what already exists: `<docs_root>/snapshot.md`, the PRD, the architecture doc, the profile.
Most of what a README needs has already been established, and re-deriving it produces a second,
subtly different account.

Where those do not exist and the code must be read instead, delegate that reading to concurrent
`Explore` agents in one message, model `sonnet`: theirs is discarded, yours sits in context all
session. Findings are leads, so verify anything you state as fact.

Where something is genuinely unknown, write `Unknown` rather than a plausible guess. A confidently
wrong setup step costs more than a gap.

## Step 4: Execute every instruction

**This is the step that makes the difference.** For a README or onboarding doc, run the commands on
a clean checkout, in order, as written.

Every failure is a finding: a missing prerequisite, an undocumented variable, a command that only
works with something already installed. Fix the document, not your local machine.

For a runbook, execute the recovery path once. See
[references/runbook-structure.md](references/runbook-structure.md).

## Step 5: Write it, in the present tense

Follow [references/readme-structure.md](references/readme-structure.md) for a README,
[references/runbook-structure.md](references/runbook-structure.md) for a runbook.

Diagrams are mermaid, always, because they render in the forge and diff as text. Shapes and
rendering traps are in
[../design-architecture/references/mermaid-patterns.md](../design-architecture/references/mermaid-patterns.md).

State what the reader must know to avoid harm, early. A destructive command, a shared environment,
a step that cannot be undone.

Write the current state. A document says what is true now, never the review history that produced
it. Durable tradeoffs go to an ADR. When a section is wrong, delete it and write it again from the
code. Reread against the tells in
[references/current-state-prose.md](references/current-state-prose.md).

## Step 6: Say when it was true

Every generated doc records the commit it describes. Undated documentation gets trusted long after
it should be, because nobody can judge its staleness.

## Common mistakes

| Mistake | Instead |
|---|---|
| A quickstart nobody ran | Execute it on a clean checkout |
| A README that is a feature list | Say what it is, who it is for, and how to run it |
| Restating the code in prose | Generate it, or document why and what the code cannot say |
| A runbook with an untested recovery | Execute the recovery once |
| An image of a diagram | Mermaid. It diffs and renders |
| No date and no commit | The reader cannot judge staleness |
| A doc the change outdated | Update it in the same commit. Stale reads as true |
| A wrong section patched in place | Delete it and write it again from the code |
