---
name: shape-idea
description: Use when someone brings a rough idea, asks whether it is worth building, describes a solution without stating the problem, or wants a feature thought through before requirements exist.
allowed-tools: [Read, Write, Grep, Glob, Bash, Agent, AskUserQuestion]
---

# Shape Idea

## Overview

Turn a raw idea into a recorded decision `write-prd` can consume, or into a decision not to build it.

**Core principle:** the output is a file, and its most valuable section is the case against.

<HARD-GATE>
No design, no stack choice, no sprint slice, no tickets, no estimates. This skill ends at a written
idea record and one recommendation. If the idea is agreed, name `write-prd` and stop.
</HARD-GATE>

If overridden, write down what was skipped and carry on.

## Step 1: Find the problem under the solution

A request names a solution. "An ops dashboard refreshed every second" is a mechanism; the problem is
whatever makes today bad. Ask until you can write one sentence naming who has the problem, what it
costs them, and how often.

One question per message, your own answer offered as the default, per
[../keel/references/asking-questions.md](../keel/references/asking-questions.md). Never a closing
list of five.

**If nobody can name a specific recent instance, that is the finding.** Write the record with that as
its headline and stop there: no PRD, no next skill. "Stop" never means write nothing. An idea with no
evidence behind it is the cheapest thing you will ever decline to build.

## Step 2: Check it against the system before challenging it

Read the code, the snapshot, and the docs that bear on it. Delegate wide reading to subagents with
model `sonnet`, and say so.

A challenge carrying a `path:line` changes a decision. The same challenge from instinct starts an
argument and loses. Every objection in step 3 cites something.

## Step 3: Write the case against, and lead with it

**Required, and it comes before any recommendation.** Three parts:

- **The strongest single argument for not building this at all**, as its own sentence.
- **Alternatives**, always including doing nothing, doing it manually, and buying it.
- **What is actually being assumed**: each part of the idea that only works if something unproven is
  true.

| Rationalisation | Answer |
|---|---|
| "Opening by dismissing the premise ends the conversation instead of improving the idea" | Observed verbatim in a baseline that then buried its own strongest objection inside a delivery plan. The premise is what the user is deciding. Burying it is how a bad idea gets built politely |
| "The goal is obviously reasonable, so only the mechanism is worth questioning" | Say that explicitly then, in one line. An unexamined goal is not the same as an endorsed one |
| "I will put it later, after the constructive part" | Later is read less. Lead |
| "They have already decided, so I will make it work" | Then record that it was already decided, and by whom |

**Red flag, this skill's own failure mode.** A question whose every option leads to your conclusion
is not a question. A run wrote one: three options, all closing the idea. Challenge hard, then let an
answer beat you.

## Step 4: Write the record

Write `<docs_root>/ideas/<slug>.md`, following
[references/idea-template.md](references/idea-template.md). **Chat is not an output.** A shaped idea
that lives only in a transcript is re-litigated from scratch next month.

## Step 5: Recommend one thing, then stop

Exactly one of: build it, build something smaller (say what), do not build it, or undecided until a
named question is answered. State which, and why, in three lines.

Then name `write-prd` if it is going ahead, and stop. `write-prd` reads this file and will not
re-ask what it answers.

## Common mistakes

| Mistake | Instead |
|---|---|
| Producing a sprint plan | That is `write-plan`, three skills later, after a PRD nobody has written |
| The objection folded into a plan | Its own section, first. See the table above |
| Alternatives that are all versions of building it | Doing nothing is an alternative. So is a spreadsheet |
| Accepting the solution as the problem | Step 1. "Always sees the true number" is a means, not an end |
| A wall of questions at the end | One per message, throughout |
| Nothing written | The file is the deliverable |
