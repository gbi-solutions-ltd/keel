---
name: repo-snapshot
description: Use when onboarding onto an unfamiliar codebase, asked what a repository is or does, before a PRD or architecture doc for an existing system, or auditing one for debt and documentation gaps.
allowed-tools: [Read, Write, Grep, Glob, Bash, Agent, AskUserQuestion]
---

# Repo Snapshot

## Overview

Produce one document that lets an engineer who has never seen this repository work in it.

**Core principle:** every claim cites a `path:line`, or is marked `Unknown`. A confident snapshot
that is wrong is worse than none: the next three decisions inherit the error.

## When to use

Onboarding, before `write-prd` or `design-architecture` on an existing system, after inheriting
a service, or quarterly.

**Skip when** a snapshot exists, is under a quarter old, and nothing changed structurally.

## Step 1: Scope and set exclusions

Run `git log -1 --format=%H`, `git log --oneline -20`, `git ls-files | wc -l`,
`git branch -a -v`. Read the root listing and any README.

**Compare the default branch against HEAD.** If they differ, record both and establish which
deploys. A default branch that is not the code you read is itself a finding.

Then find what agents must not read; one 500KB generated file eats a budget:

```bash
git ls-files -z | xargs -0 du -k 2>/dev/null | sort -rn | head -15
```

Add anything generated: lock files, specs, coverage, build output, vendored dependencies.

One snapshot per deployable unit. For a monorepo, ask which unit.

Where `profile.artifacts` maps an existing architecture or decisions document, read it rather than
re-deriving what someone already wrote.

## Step 2: Delegate the reading

**This is why the skill exists.** Files read inline sit in context all session; a subagent's are
discarded.

Dispatch these `Explore` agents concurrently **in one message**, model `sonnet`:

| Agent | Brief |
|---|---|
| A. Boot | Entry points, process start, config and env loading and whether validated, flags, cron, workers |
| B. Data | Models, schemas, migrations, datastores, caches, queues, which component owns each table |
| C. Surface | Routes, events in and out, third-party integrations, auth, authorisation, webhook signature checks |
| D. Quality | Verbatim commands for test, one test, lint, typecheck, build. Test vs source count, untested areas, strictness |
| E. Delivery | Dockerfile, pipeline shape, what gates a deploy, environments, secret handling, IaC, deploy target |
| F. Docs | README and doc accuracy, ADRs, commits by theme, contributors, untouched areas |

Under roughly 100 tracked files, collapse to three agents (A+B, C+D, E+F).

Append to every brief verbatim, filling in the Step 1 exclusions:

> Do not read: `<exclusions>`. Return findings only, never file contents. Cite `path:line` for
> every claim. Cap your answer at 400 words. If something is absent, say `absent`; never infer
> it from naming. Flag anything that contradicts the README.

## Step 3: Verify what will drive action

**Subagent findings are leads, not facts.** Before writing, verify anything reaching section 10 or
carrying a number. Cap at six: where being wrong changes what somebody does.

| Claim | How to verify |
|---|---|
| Any number | Run the command. Never report a figure from a committed report or an agent's count |
| Security or delivery | Read the cited lines yourself |
| Setup steps | Execute them |

**Check each command actually ran.** An errored tool and one that found nothing both exit
non-zero. Read the output, not the code.

**A claim you could not verify does not reach section 10.** It goes in section 8, marked
`unverified`.

## Step 4: Write the document

Read [references/section-templates.md](references/section-templates.md) now and follow it. Write
`<docs_root>/snapshot.md`, or `snapshot-<unit>.md` per unit in a monorepo, stating the unit's
place in the platform.

## Step 5: Propose the profile

Fill section 11 from agents D and E. Never invent a verify command: propose `null` if none was found.
No profile? Say to run `keel init`.

## Step 6: Hand off

Name section 10's highest-value actions with their skills, and what you did not check. Do not start them.

## Common mistakes

| Mistake | Instead |
|---|---|
| Reporting a number an agent read off a committed report | Run it. Stale reports are confidently wrong by an order of magnitude |
| Snapshotting HEAD without checking the default branch | Compare them in Step 1. They diverge often |
| Fixing what you find | This skill reports. Fixes belong to the skill for that problem |
