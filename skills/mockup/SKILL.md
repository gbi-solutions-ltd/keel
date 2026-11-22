---
name: mockup
description: Use when asked to mock up or prototype a web app, a screen or a state for a client, or to change a mockup a client is reviewing or has signed off.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion]
---

# Mockup

## Overview

Build client mockups in plain HTML that are framework shaped, check them, and freeze the signed-off
one as the specification `convert-mockup` builds the app from.

**Core principle:** the signed-off mockup is the specification. Everything the app will need is
decided here, with the client, or written down as deferred with an owner.

Reasons: [references/rationale.mock.md](references/rationale.md).

## Step 1: Intake, before the first screen

Follow [references/intake.md](references/intake.md): read existing records, then ask each
unanswered tier 1 question, one per message, recommended answer first. Tier 2: ask, or defer with
an owner and a date. Write the `project` block and the brief.

## Before the first command: the toolchain

`<engine>` is the folder `keel mockup-engine path` prints; `templates/` below is its folder. Run
`node <engine>/scripts/toolchain.mjs --project <repo root>` before Step 2; the intake needs none of it. It prints `S=<folder>`: run
every script below as `node <S>/<script>`. On exit 2, show its reasons; when it prints an install
command, show it and ask before running it: it downloads the locked packages and the pinned
browser into the project's git-ignored `.mockup-engine/` (about 230 MB), and nowhere else.

## Step 2: Build

Read [references/mockup-conventions.md](references/mockup-conventions.md) in full,
[references/design-frameworks.md](references/design-frameworks.md) with a framework (at intake
too), and [references/dashboard-patterns.md](references/dashboard-patterns.md) for dashboards,
reports or roles. Copy `templates/mockup-starter/`, replace its sample screens, keep
`assets/mk.js`, and copy opted-in modules ([references/modules.md](references/modules.md)). Build
to the intake's answers: tokens, fixtures shaped like the API, components by layer, then pages
with all four states and their `needs`.

## Step 3: The screen list

Update `index.html` and `mockup.config.json`
([references/mockup-config.md](references/mockup-config.md)): a screen per role and per
interactive state.

## Step 4: Check before the client sees it

Write `docs/behaviours.json` ([references/mockup-behaviours.md](references/mockup-behaviours.md)),
pin a baseline (`--write-baseline` once, then `--baseline`), and run every check in
[references/step-detail.mock.md](references/step-detail.md), fixing each finding at its
cause. Plant a failure each check must catch before trusting it.

## Step 5: Sign-off

Per [references/signoff.md](references/signoff.md): draft the contract, then `<S>/signoff.mjs`
freezes the mockup by hash. Later changes are new rounds. The signed-off package is what
`convert-mockup` reads.

## Common mistakes

| Mistake | Instead |
|---|---|
| Starting screens before the intake's tier 1 answers | Ask them first, one per message |
| A role or a state left out of the screen list | A screen per role and per interactive state |
| Fixtures shaped for the page, not the API | Shape them like the responses, so the contract drafts from them |
| A module copied in that the client did not opt into | Only opted-in modules; the checklist records the rest |
| Fixing a spill by shrinking one number | Let children shrink; stack rows that cannot share a line |
| Trusting a check because it ran green | Plant a failure it must catch |
| Editing a signed-off mockup in place | A new round, recorded |
