# Why `security-audit`'s steps are as they are

The reasons behind `security-audit`'s steps; the steps themselves are in [../SKILL.md](../SKILL.md).

## Overview

A report of forty maybes gets ignored; three real ones get fixed. That is why every finding needs a
concrete exploit and a `file:line`.

## Step 1: Pick the scope

Whether the diff touches a `hard_block_paths` path is never decided by reading one profile, so a
change cannot relax its own audit.

## Step 2: Work the phases in this order

The phases are ordered by where breaches actually come from, which is not where code review looks.

**Secrets.** A secret in an image or a jar is readable by anyone who can pull it, and this is the
single most common serious finding. That is why the artifact is built and looked inside.

**Configuration.** A value that starts the service when empty is worse than one that is missing,
because it starts.

**Domain.** The payments checklist is where the real risk is, and generic tooling does not cover
it.

**Delegating on a `--full` run.** The reading stays out of the main context, and step 3 verifies
every finding before it is written, so nothing ships on the cheaper model's judgement alone.

**Each brief on its own phase.** An agent that can read another's findings starts agreeing with
them, and agreement between agents that see each other is an echo, not corroboration.

## Step 3: Verify every finding before writing it

A finding you have not confirmed is noise, and noise is what makes audits ignored.

## Step 4: Report

Saying plainly what was not covered matters because an audit that implies completeness it does not
have is worse than a narrow one.

## Step 5: Plugin and gate

`security-guidance` covers edits and the end of a turn with its own hooks, so it catches what runs
between audits. That is why it is recommended where it is absent.

## Common mistakes

Build the image and look inside rather than reading the Dockerfile, because the image is where
secrets hide.
