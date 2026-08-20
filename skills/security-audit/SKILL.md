---
name: security-audit
description: Use when about to ship, asked whether something is secure or needs a vulnerability check, or when working on authentication, payments, personal data, secrets, or external input.
allowed-tools: [Read, Bash, Grep, Glob, Agent, WebSearch]
---

# Security Audit

## Overview

Find the doors that are actually unlocked, and prove each one is.

**Core principle:** every finding needs a concrete exploit and a `file:line`. A report of forty
maybes gets ignored; three real ones get fixed.

## Step 1: Pick the scope

| Scope | When | Phases |
|---|---|---|
| `--diff` | Before every ship. The default | 1, 2, 6, 7 on changed code only |
| `--full` | New engagement, monthly, or after an incident | All |

Read `.keel/profile.json` for `gates.security_audit` and any `hard_block_paths`.

## Step 2: Work the phases in this order

Ordered by where breaches actually come from, which is not where code review looks.

1. **Secrets.** In the working tree, in git history, in build artifacts, in CI logs, in committed
   `.env` files and keystores. **Build the artifact and look inside it.** A secret in an image or
   a jar is readable by anyone who can pull it, and this is the single most common serious finding.
2. **Supply chain.** Outdated majors, known advisories, unmaintained packages, an undeclared
   dependency resolving by hoisting, a lockfile that disagrees with the manifest.
3. **Pipeline.** What the CI can read, what it prints, who can trigger a deploy, whether tests
   actually gate, and whether a secret reaches a log or an artifact.
4. **Configuration.** Credentials with defaults, values that start the service when empty, and
   anything that fails open where it should fail closed.
5. **Threat model.** STRIDE over the architecture. See
   [references/stride.md](references/stride.md).
6. **Code.** OWASP Top 10 against the diff or the repo. See
   [references/owasp-checklist.md](references/owasp-checklist.md).
7. **Domain.** For anything touching money or cards, work
   [references/payments-checklist.md](references/payments-checklist.md). This is where the real
   risk is, and generic tooling does not cover it.

Delegate phases to parallel subagents on a `--full` run, one per phase, model `sonnet`, and say
which model in one line. The reading stays out of the main context, and step 3 verifies every
finding before it is written, so nothing ships on the cheaper model's judgement alone.

## Step 3: Verify every finding before writing it

A finding you have not confirmed is noise, and noise is what makes audits ignored.

For each: read the cited lines yourself, and state the exploit as a sequence someone could
follow. If you cannot say who does what and what they get, it does not go in the report. Drop it,
or move it to a clearly separated "worth checking" list.

## Step 4: Report

Write `<docs_root>/audits/YYYY-MM-DD-security.md`, following
[references/report-template.md](references/report-template.md).

Rank by exploitability multiplied by impact, not by scanner severity. Every finding: location,
exploit, blast radius, fix.

Say plainly what you did **not** cover. An audit that implies completeness it does not have is
worse than a narrow one.

## Step 5: Plugin and gate

`security-guidance` covers edits and the end of a turn with its own hooks, so it catches what runs
between audits. Recommend it if absent. The built-in `/security-review` is a useful cross-check on
a diff.

Then report to `ship`. A finding above the project's threshold blocks the ship gate; on a
`hard_block_paths` match it is not overridable in conversation.

## Common mistakes

| Mistake | Instead |
|---|---|
| Auditing only the code | Secrets, supply chain, and pipeline come first |
| Reading the Dockerfile instead of the image | Build it and look inside. That is where secrets hide |
| Forty findings, unranked | Verify each, drop the unproven, rank by exploitability |
| A severity with no exploit | Name who does what and what they get, or drop it |
| Implying full coverage | State what you did not cover |
| Trusting an empty scanner result | Scanners miss authorisation and business logic entirely |
