---
name: convert-mockup
description: Use when asked to turn a signed-off HTML mockup into a React, Vue or Next.js app, to port one into an existing repository, or to take a converted app through the production bar.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion]
---

# Convert Mockup

## Overview

Convert a signed-off mockup into an app that matches it pixel for pixel and meets keel's frontend
standards, then take it through the production bar.

**Core principle:** the signed-off mockup is the specification. The app matches it exactly; what it
does not specify goes into the gap report, never into an invention.

Reasons: [references/rationale.md](references/rationale.md).

## Step 0: The toolchain

`<engine>` is the folder `keel mockup-engine path` prints; `templates/` below is its folder. Run
`node <engine>/scripts/toolchain.mjs --project <repo root>` first. It prints `S=<folder>`: run
every script below as `node <S>/<script>`. On exit 2, show its reasons; when it prints an install
command, show it and ask before running it: it downloads the locked packages and the pinned
browser into the project's git-ignored `.mockup-engine/` (about 230 MB), and nowhere else.

## Step 1: Inputs

Run `check-config --ready-to-port`, then read the sign-off package
([references/step-detail.md](references/step-detail.md)); ask only what it leaves open. The target
is a new repo, or an existing one on its conventions
([references/existing-repo.md](references/existing-repo.md)). Read `references/stacks/<stack>.md`,
[references/frontend-defaults.md](references/frontend-defaults.md), and
[references/design-frameworks.md](../mockup/references/design-frameworks.md) unless `designFramework.kind` is
`none`; beyond about 20 pages, [references/large-ports.md](references/large-ports.md). Skip "Where
the contract comes from" in [references/api-integration.md](references/api-integration.md).

## Step 2: Check the mockup

Run `inventory --ready-to-port` (no valid sign-off: back to the `mockup` skill, Sign-off), then the
other checks ([references/step-detail.md](references/step-detail.md)). Fix each finding in the
mockup, or plan it as a gap. Without `mk.js`, convert by hand and say so.

## Step 3: The contract

Check the signed-off contract against `needs.api`.

## Step 4: Plan, then stop for approval

Write the target's `<docs_root>/mockups/<name>/conversion-plan.md` (`docs/` outside keel) from
[references/conversion-plan-template.md](references/conversion-plan-template.md), and the
[component map](references/component-map-template.md). **Wait for approval before writing code**,
unless told to run unattended (assumptions then go at the top). In a keel project, the approved
plan goes to `keel:write-plan` and `keel:execute-plan`.

## Step 5: Scaffold and bind the standards

Scaffold per [templates/app-scaffold/README.md](../../lib/mockup-engine/templates/app-scaffold/README.md) and the stack
reference. Without `<docs_root>/standards.md`, run **REQUIRED SUB-SKILL:** `keel:coding-standards`
in seed mode (the scaffold's files do not count as existing code). Wire `typecheck`, `lint`
(Biome, then `check-frontend.mjs`), `test` and the audit, and see each fail on a planted defect
before the first page: the minimum to get there is in the step detail.

## Step 6: Port

Follow [references/step-detail.md](references/step-detail.md), i18n included. The shell, the
seams and the first page are ported here. Each further slice of the approved plan may be
delegated to a subagent with the delegation profile `keel-port-worker`, each dispatch's
description starting `keel-port-worker: `, its brief naming the slice's files and gate command. Never redesign, never invent an API shape or a
permission, and never hide or disable an undesigned action: keep it, stub it, record it.

## Step 7: Verify until green

Per [references/step-detail.md](references/step-detail.md), "Convert, Step 7": typecheck, lint,
tests, audit; the visual diff on the dev server, then on the mocked build under its headers with
the quality check. Read a worker's report against the gate's own summary lines. Never raise a
threshold.

## Step 8: Gaps, production bar, report

A framework named after sign-off is adopted now
([references/design-frameworks-fallback.md](references/design-frameworks-fallback.md)). Write
`<docs_root>/mockups/<name>/gaps.md` from
[references/gap-report-template.md](references/gap-report-template.md), check
[references/production-bar.md](references/production-bar.md) (audit, headers, perf, staging, gaps,
deploy; no staging backend yet: write the [sample backend](references/sample-backend.md) and run
against it), then report every check's numbers.

## Common mistakes

| Mistake | Instead |
|---|---|
| Fixing a visual difference by eye | Fix the first size change the diff report names |
| Hand-writing a fetch call or response type | Change the contract and regenerate |
| Disabling the button for an undesigned flow | Keep it, stub the handler, add a gap |
| A permission enforced only by hiding UI | Also list the server check in the gaps |
| Converting a mockup that fails its own checks | Fix the mockup first |
| Trusting a check because it ran green | Plant a failure it must catch |
| Taking a worker's "all green" without its numbers | Read the gate's summary lines it quotes |
