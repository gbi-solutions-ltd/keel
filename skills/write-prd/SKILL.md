---
name: write-prd
description: Use when the user has a product idea, asks for requirements or a spec or a PRD, wants an existing PRD improved, or is about to build something that has no written requirements.
allowed-tools: [Read, Write, Grep, Glob, Bash, Agent, AskUserQuestion]
---

# Write PRD

## Overview

Requirements someone can build from and disagree with.

**Core principle:** a requirement states what must be true, not what the code happens to do. In an
existing system those differ, and the gap is this skill's most valuable output.

Why each step is as it is: [references/rationale.md](references/rationale.md). Read it before
changing a step.

<HARD-GATE>
No design, no plan, no code until the user has approved the PRD, however simple the product surface
looks. A single feature the short path accepts, or a bug routed to `debug`, does not enter this
gate: name `write-plan` or `debug` and stop. A short PRD is fine; skipping it is not.
</HARD-GATE>

If the user overrides the gate, write down what you assumed and carry on.

## Step 1: Pick the mode and gather inputs

| Mode | When | First read |
|---|---|---|
| `from-idea` | A rough idea, nothing written | `<docs_root>/ideas/<slug>.md` if one exists |
| `from-repo` | The system exists, requirements never were | `profile.artifacts.snapshot`, else `<docs_root>/snapshot.md` |
| `revise` | A PRD exists and is vague, contradictory, or overtaken | The existing PRD |

**Check `profile.artifacts.prd` first.** If it maps to an existing document, this is a `revise`, not
a `from-idea`.

In `from-repo` with no snapshot, **REQUIRED SUB-SKILL:** `keel:repo-snapshot`.

**Scope it.** One PRD per coherent product surface, not per repository. If the boundary is unclear,
ask.

## Step 2: Ask, one question per message

Read the index at the top of [references/questionnaire.md](references/questionnaire.md), then
read only the sections your mode needs.

One per message, your best answer offered as the default. Stop once you can write every section.

In `from-repo` ask only what code cannot answer: why this exists, who for, what success looks like,
what is out of scope.

**In `from-idea`, read the idea record if there is one and ask nothing it settles.** If there is
none and the idea is still rough, `shape-idea` comes first.

**In `from-repo`, step 3 runs in the middle of this step.** Ask the purpose questions, classify,
then one question per ambiguity.

## Step 3: Separate observed from required

**`from-repo` mode only.**

For each behaviour the code exhibits, decide which it is:

| It is | Then |
|---|---|
| Intended, and the user confirms | A requirement, `confirmed` |
| Intended, nobody has confirmed | A requirement, `inferred` |
| An accident, a bug, or a stopgap | **Not a requirement.** Goes under Observed but not required |
| Contradicted by docs or another behaviour | `disputed`, and ask |

Never promote an accident to a requirement.

## Step 4: Write it

Follow [references/prd-template.md](references/prd-template.md). Write to
`<docs_root>/prd/<slug>.md`; in `revise`, edit the existing PRD in place.

Every functional requirement gets `FR-NN`, non-functional `NFR-NN`, constraint `CON-NN`, plus a
status.

## Step 5: Self-review, then gate

Check your draft: any untestable requirement, any "should" hiding an undecided question, any two
requirements that conflict, any empty section. Fix them.

Where this PRD came from an idea record, strike through the questions it settles there first. Ask
the blocking open questions (below), then present the PRD for approval and **stop**. Say plainly
which requirements are `inferred`, `disputed` and `author-added`.

**Surface open questions as choices, not a list.** Use `AskUserQuestion` for the ones that block
work, following [../keel/references/asking-questions.md](../keel/references/asking-questions.md).

**Step 2's rule holds here: one question per message, the blocking one first.** "As choices" is
about the form of a question, never a licence to batch. Five questions with defaults is the wall
step 2 refuses however it is rendered, and where `AskUserQuestion` is unavailable it is still one
question in the reply rather than a list in it.

On approval, name `write-user-stories` as next. Do not start it.

## Common mistakes

| Mistake | Instead |
|---|---|
| Accepting a shape as requirements | "A list, filters, a chart" describes a shape and commits to nothing. Ask who acts on it |
| Inventing metrics because the template has a slot | `Unknown, needs a decision` is a valid entry |
| Inventing *requirements* because they seem sensible | Mark them `author-added` and count them |
