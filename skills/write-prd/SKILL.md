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

<HARD-GATE>
No design, no plan, no code until the user has approved the PRD, however simple the request looks.
A short PRD is fine; skipping it is not.
</HARD-GATE>

If overridden, write down what you assumed and carry on.

## Step 1: Pick the mode and gather inputs

| Mode | When | First read |
|---|---|---|
| `from-idea` | A rough idea, nothing written | `<docs_root>/ideas/<slug>.md` if one exists |
| `from-repo` | The system exists, requirements never were | `profile.artifacts.snapshot`, else `<docs_root>/snapshot.md` |
| `revise` | A PRD exists and is vague, contradictory, or overtaken | The existing PRD |

**Check `profile.artifacts.prd` first.** If it maps to an existing document, this is a `revise`, not
a `from-idea`: a second PRD beside a mature one makes the repo worse.

In `from-repo` with no snapshot, **REQUIRED SUB-SKILL:** `keel:repo-snapshot`.
Reverse-engineering requirements from an unread codebase produces confident fiction.

**Scope it.** One PRD per coherent product surface, not per repository. A document spanning several
surfaces is approved by nobody. If the boundary is unclear, ask.

## Step 2: Ask, one question per message

Read the index at the top of [references/questionnaire.md](references/questionnaire.md), then
read only the sections your mode needs.

One per message, your best answer offered as the default. Stop once you can write every section.

In `from-repo` ask only what code cannot answer: why this exists, who for, what success looks like,
what is out of scope. The snapshot has the rest.

**In `from-idea`, read the idea record if there is one and ask nothing it settles.** If there is
none and the idea is still rough, `shape-idea` comes first.

**In `from-repo`, do step 3 first, then return here.** The questions worth asking are the ambiguities
classification turns up. Ask the purpose questions, classify, then one question per ambiguity.

## Step 3: Separate observed from required

**`from-repo` mode only, and it is the point of the mode.**

For each behaviour the code exhibits, decide which it is:

| It is | Then |
|---|---|
| Intended, and the user confirms | A requirement, `confirmed` |
| Intended, nobody has confirmed | A requirement, `inferred` |
| An accident, a bug, or a stopgap | **Not a requirement.** Goes under Observed but not required |
| Contradicted by docs or another behaviour | `disputed`, and ask |

Never promote an accident to a requirement. A PRD asserting the system must do what it currently does
by mistake is worse than no PRD: the next engineer will defend it.

## Step 4: Write it

Follow [references/prd-template.md](references/prd-template.md). Write to
`<docs_root>/prd/<slug>.md`.

Every functional requirement gets `FR-NN`, non-functional `NFR-NN`, constraint `CON-NN`, plus a
status. `write-user-stories` traces to these and `write-plan` proves coverage against them, so they
are structural, not decoration.

## Step 5: Self-review, then gate

Check your draft: any untestable requirement, any "should" hiding an undecided question, any two
requirements that conflict, any empty section. Fix them.

Update the idea record's open questions first. Then present the PRD for approval and **stop**. Say plainly which requirements are `inferred` and
which are `disputed`, because those are what the user is really being asked to rule on.

**Surface open questions as choices, not a list.** Use `AskUserQuestion` for the ones that block
work, following [../keel/references/asking-questions.md](../keel/references/asking-questions.md).
A question buried in section 13 goes unanswered; the same question as a choice gets settled in
seconds.

**Step 2's rule holds here: one question per message, the blocking one first.** "As choices" is
about the form of a question, never a licence to batch. Five questions with defaults is the wall
step 2 refuses however it is rendered, and where `AskUserQuestion` is unavailable it is still one
question in the reply rather than a list in it.

On approval, name `write-user-stories` as next. Do not start it.

## Common mistakes

| Mistake | Instead |
|---|---|
| Describing the code and calling it requirements | Step 3. Observed is not required |
| Requirements nobody can test | State the observable outcome, not the intent |
| Accepting a shape as requirements | "A list, filters, a chart" describes a shape and commits to nothing. Ask who acts on it |
| Inventing metrics because the template has a slot | `Unknown, needs a decision` is a valid entry |
| Inventing *requirements* because they seem sensible | Mark them `author-added` and count them. The no-invention rules cover numbers, not features |
| Writing the plan because the PRD went well | The gate is the whole point. Stop |
