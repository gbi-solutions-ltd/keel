---
name: setup-deployment
description: Use when a project has no pipeline, when asked to add CI, containerise a service, set up environments or provision infrastructure, or when an existing deployment or release needs fixing, verifying, or documenting.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# Setup Deployment

## Overview

Build the whole path from commit to running, including the way back.

**Core principle:** a pipeline that cannot fail a build is documentation. A deploy with no tested
rollback is a one-way door.

Why each step is as it is: [references/rationale.md](references/rationale.md). Read it before
changing a step.

## Step 1: Find out what exists, and whether it works

Read `.keel/profile.json`, then look for a Dockerfile, CI config, and IaC. Two questions the
files will not answer directly:

- **Does the pipeline gate?** A test that cannot fail the gating job gates nothing. Read the
  conditions, not the step names.
- **Does every environment have a deploy path?** A build job with no matching deploy job means
  that environment is not being deployed by this pipeline, whatever the file implies.

Both of those have been found in real repositories. Check them explicitly. Read
[references/release-operations.md](references/release-operations.md) before provisioning anything,
and again before calling a release done.

## Step 2: Establish the verify commands first

Every checking stage (lint, typecheck, test, security scan, build) runs a command from
`profile.verify`. If a command is `null`, the pipeline cannot check that thing and you must say so
rather than substituting a guess.

Run each one locally before putting it in a pipeline. A CI job whose command fails on the
developer's machine will fail in CI too, and the pipeline gets blamed.

## Step 3: Build the pipeline

Stages, in order, each failing the build: install, lint, typecheck, test, security scan, build the
artifact, push, deploy per environment, smoke test.

See [references/pipeline-patterns.md](references/pipeline-patterns.md) for the shape and the traps.

Non-negotiables:

- **Tests fail the build.** No `continue-on-error`, `|| true`, or test moved out of the gating
  job. A flaky test leaves only by
  [the recorded quarantine](references/pipeline-patterns.md#a-flaky-test-the-recorded-quarantine).
- **The branch that people work on is gated**, not just the default branch.
- **No secret reaches a log or an artifact.** Inject at runtime; never copy an env file into an
  image.
- **The image is built once** and the same digest is promoted through environments.

## Step 4: Containerise properly

Multi-stage, a pinned base image, a non-root user, no build tooling in the final layer, a healthcheck,
and a `.dockerignore` that excludes env files and keys.

**Keep it thin**, recording its size in the runbook, and **build it and look inside**: read
[the commands](references/step-detail.md#step-4-containerise-properly) before you do. What a
Dockerfile appears to copy and what lands in the image are different questions.

## Step 5: Wire observability

Wire the exporter, gated on the endpoint variable.

Backend comes from `profile.observability.backend`, default `signoz`. Instrument with OpenTelemetry
whichever it is. See
[../coding-standards/references/observability.md](../coding-standards/references/observability.md).

## Step 6: Environments and secrets

Per environment: what differs, where secrets come from, who can deploy. Environments must not share a
host or credential unless recorded as a decision.

Migrations need a stated position: when they run, what happens when a deploy is rolled back, and
whether a failed candidate has already migrated shared state.

## Step 7: Test the rollback when there is one, then write the runbook

**Execute the rollback once**, by hand. An untested rollback is a hope. Then write
`<docs_root>/runbooks/deploy.md`: how to deploy, how to roll back, where the logs are, the three
most likely failures, and who to call. Note in the runbook when you ran the rollback. If there is
nothing yet to roll back to, write the runbook anyway, mark the rollback not yet executed, and name
running it as the next step in Step 8.

## Step 8: Report

What now gates, what still does not, which environments can be deployed, and whether rollback has
actually been tested.

## Common mistakes

| Mistake | Instead |
|---|---|
| A flaky test moved out of the gate | Fix it, or record its quarantine |
| Gating only the default branch | Gate the branch people actually work on |
| Reading the Dockerfile to check contents | Build it and look inside |
| An env file copied into the image | Inject at runtime |
| Rebuilding per environment | Build once, promote the digest |
| A runbook nobody has run | Execute the rollback once, or mark it pending |
