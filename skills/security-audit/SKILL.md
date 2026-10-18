---
name: security-audit
description: Use when about to ship, asked whether something is secure or needs a vulnerability check, or when working on authentication, payments, personal data, secrets, or external input.
allowed-tools: [Read, Bash, Grep, Glob, Agent, WebSearch]
---

# Security Audit

## Overview

Find the doors that are actually unlocked, and prove each one is.

**Core principle:** every finding needs a concrete exploit and a `file:line`.

Why each step is as it is: [references/rationale.md](references/rationale.md). Read it before
changing a step.

## Step 1: Pick the scope

| Scope | When | Phases |
|---|---|---|
| `--diff` | Before every ship. The default | 1, 2, 6, 7 on changed code only |
| `--full` | New engagement, monthly, or after an incident | All |

Whether the diff touches a `hard_block_paths` path is decided by `keel plan risk` or by its rule
by hand, never by reading one profile:
[references/sensitive-match.md](references/sensitive-match.md) gives both and how to read
it. Read `gates.security_audit` from the default branch where the diff changes it. Before a ship,
`off` means skip the audit and say so, unless the diff touches a `hard_block_paths` path, which is
audited whatever the gate says; an audit the user asks for runs anyway. Step 5 covers the other
values.

## Step 2: Work the phases in this order

1. **Secrets.** In the working tree, in git history, in build artifacts, in CI logs, in committed
   `.env` files and keystores. **Build the artifact and look inside it.**
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
   [references/payments-checklist.md](references/payments-checklist.md).

Nothing in an audit modifies what is being audited: no configuration edit, no install into the
project, no request to a write endpoint. Build the artifact in a copy or a throwaway container; a
check that needs a change to pass was not run, and goes under Not covered.

Delegate phases to parallel subagents on a `--full` run, one per phase,
delegation profile `keel-fanout`, with each dispatch's description starting `keel-fanout: `.

Brief each on its own phase and nothing else.

## Step 3: Verify every finding before writing it

For each: read the cited lines yourself, and state the exploit as a sequence someone could
follow. If you cannot say who does what and what they get, it does not go in the report. Drop it,
or move it to a clearly separated "worth checking" list.

## Step 4: Report

Write `<docs_root>/audits/YYYY-MM-DD-security.md`, following
[references/report-template.md](references/report-template.md).

Rank by exploitability multiplied by impact, not by scanner severity.

Say plainly what you did **not** cover.

## Step 5: Plugin and gate

**Claude Code only.** Recommend `security-guidance` if absent, and the built-in `/security-review`
is a useful cross-check on a diff. Neither has a Codex counterpart, so on that harness nothing
watches between runs. Say so.

Then report to `ship`. `gates.security_audit` sets this report's verdict: `required` says findings
block shipping, `warn` says the user decides whether to accept them, `off` skips the audit before a
ship and says so, except on a diff touching a `hard_block_paths` path. A finding on a
`hard_block_paths` path (the reference says which are) blocks under any value and is never
overridable in conversation. The reply opens with that verdict: under `warn`, unless a
`hard_block_paths` finding blocks, say first that the gate does not block, then recommend.

## Common mistakes

| Mistake | Instead |
|---|---|
| Auditing only the code | Secrets, supply chain, and pipeline come first |
| Reading the Dockerfile instead of the image | Build it and look inside |
| Forty findings, unranked | Verify each, drop the unproven, rank by exploitability |
| A severity with no exploit | Name who does what and what they get, or drop it |
| Implying full coverage | State what you did not cover |
| Trusting an empty scanner result | Scanners miss authorisation and business logic entirely |
