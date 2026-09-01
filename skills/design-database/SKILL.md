---
name: design-database
description: Use when designing a database schema, reviewing or remediating an existing one, normalising tables, choosing column types, or planning indexes and partitioning for a database.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# Design Database

## Overview

Schema design, and review of a database that already exists.

**Core principle:** the findings are not the hard part. A capable reader already finds the urgent
defect; what gets skipped is the sweep, so every review fills in the same required sections whether
or not anything interesting turned up in them.

## What this skill does not own

Hand these off rather than repeating them. Each already has an owner that does it better.

| Concern | Goes to |
|---|---|
| Which engine, and whether a database is the right store at all | `design-architecture` |
| Query latency, N+1, a missing index on a slow query, reading a plan | `optimize-performance` |
| Producing the document itself | `write-docs` |
| Drawing the ERD | `design-architecture/references/mermaid-patterns.md`, section ER |

Partitioning stays here, because it is a schema decision with a retention consequence rather than a
query fix.

Engine specifics live in [references/postgres.md](references/postgres.md) and
[references/oracle.md](references/oracle.md). The steps below are engine-agnostic.

## Step 1: Establish what you are looking at

Read the schema from the database where you can, and say plainly where you could not. A
hand-regenerated schema file may not describe production, and a review of the wrong artifact is
worse than no review because it reads as authoritative.

Then answer, or record as unverified: what enforces integrity outside the schema. Application
validators are invisible here and they change every finding about a missing constraint.

Get the row counts. Half the findings that matter are a schema fact plus a row count, and neither
half is a finding on its own.

## Step 2: Review, or design

Both produce the same document, and its sections are not optional. See
[references/review-template.md](references/review-template.md).

Design starts from the entities and their real identifiers. Review starts from the schema as it is.
They converge on the same sections because the questions are the same ones.

## Step 3: Fill every required section

A section with nothing in it says `None found`, and that is itself a finding: it says somebody
looked. A section left out says nothing at all, and is not permitted.

`None found` is honest only after the sweep. Writing it because a section looked unpromising is the
failure this whole shape exists to prevent.

## Step 4: Order what you found

Lead with what breaks soonest, not what is worst in principle. A column type that is merely wrong
outranks nothing; a key three months from exhausting its range outranks everything.

For each, give the smallest correct change. A rewrite proposed where a constraint would do is a
recommendation nobody can act on this quarter.

## Common mistakes

| Mistake | Instead |
|---|---|
| Reviewing the headline defect and stopping | The sections are a sweep. Fill them all |
| An ERD left undrawn because the model seemed obvious | You reconstructed it in order to review it. Draw it |
| `None found` written without looking | It claims a sweep happened. Do the sweep |
| Recommending a rewrite where a constraint would do | Say what the smallest correct change is |
| Reviewing a schema file as though it were the database | Say which one you read, and what that costs |
