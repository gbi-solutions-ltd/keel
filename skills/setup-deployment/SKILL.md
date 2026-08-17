---
name: setup-deployment
description: Use when a project has no pipeline, when asked to add CI, containerise a service, set up environments, or when an existing deployment needs fixing or documenting.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# Setup Deployment

## Overview

Build the whole path from commit to running, including the way back.

**Core principle:** a pipeline that cannot fail a build is documentation. A deploy with no tested
rollback is a one-way door.

## Step 1: Find out what exists, and whether it works

Read `.keel/profile.json`, then look for a Dockerfile, CI config, and IaC. Two questions the
files will not answer directly:

- **Does the pipeline gate?** A test step with `continue-on-error` gates nothing. Read the
  conditions, not the step names.
- **Does every environment have a deploy path?** A build job with no matching deploy job means
  that environment is not being deployed by this pipeline, whatever the file implies.

Both of those have been found in real repositories. Check them explicitly.

## Step 2: Establish the verify commands first

Every pipeline stage runs a command from `profile.verify`. If a command is `null`, the pipeline
cannot check that thing and you must say so rather than substituting a guess.

Run each one locally before putting it in a pipeline. A CI job whose command fails on the
developer's machine will fail in CI too, and the pipeline gets blamed.

## Step 3: Build the pipeline

Stages, in order, each failing the build: install, lint, typecheck, test, security scan, build the
artifact, push, deploy per environment, smoke test.

See [references/pipeline-patterns.md](references/pipeline-patterns.md) for the shape and the traps.

Non-negotiables:

- **Tests fail the build.** No `continue-on-error` on a test step.
- **The branch that people work on is gated**, not just the default branch.
- **No secret reaches a log or an artifact.** Inject at runtime; never copy an env file into an
  image.
- **The image is built once** and the same digest is promoted through environments.

## Step 4: Containerise properly

Multi-stage, a pinned base image, a non-root user, no build tooling in the final layer, a healthcheck,
and a `.dockerignore` that excludes env files and keys.

**Keep it thin.** Every megabyte is pull latency on every deploy and every package is attack surface.
Measure with `docker image ls` and `docker history`, and record the size in the runbook so growth is
visible. See the reference for the specifics.

Then **build it and look inside**: `docker create` and `docker cp`, or `unzip -l` for a jar. What a
Dockerfile appears to copy and what lands in the image are different questions.

## Step 5: Wire observability

A service with no telemetry is a service whose next incident is measured in hours. Wire the exporter,
gated on the endpoint variable so local development stays quiet.

Backend comes from `profile.observability.backend`, default `signoz`. Instrument with OpenTelemetry
whichever it is, so the vendor sits behind the exporter and switching is configuration rather than a
rewrite. See
[../coding-standards/references/observability.md](../coding-standards/references/observability.md).

## Step 6: Environments and secrets

Per environment: what differs, where secrets come from, who can deploy. Environments must not share a
host or credential unless recorded as a decision; sharing means one incident takes both.

Migrations need a stated position: when they run, what happens when a deploy is rolled back, and
whether a failed candidate has already migrated shared state.

## Step 7: Write the runbook, then test it

Write `<docs_root>/runbooks/deploy.md`: how to deploy, how to roll back, where the logs are, the
three most likely failures, and who to call.

**Then execute the rollback once**, by hand. An untested rollback is a hope. Record that you ran it.

## Step 8: Report

What now gates, what still does not, which environments can be deployed, and whether rollback has
actually been tested.

## Common mistakes

| Mistake | Instead |
|---|---|
| A test step with `continue-on-error` | Tests fail the build, or delete the step |
| Gating only the default branch | Gate the branch people actually work on |
| Reading the Dockerfile to check contents | Build it and look inside |
| An env file copied into the image | Inject at runtime |
| Rebuilding per environment | Build once, promote the digest |
| A runbook nobody has run | Execute the rollback once |
