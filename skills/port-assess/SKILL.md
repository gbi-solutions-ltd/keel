---
name: port-assess
description: Use when deciding whether or how to move an existing codebase to a different stack, or when asked to scope, size, or assess the risks of a rewrite or migration.
allowed-tools: [Read, Write, Grep, Glob, Bash, Agent, AskUserQuestion]
---

# Port Assess

## Overview

Read an existing service and produce one assessment: what porting it costs, what will break, what
should not be ported. For Oracle APEX use `apex-port-plan`, which reads an export instead.

**Core principle:** every claim is marked verified, inferred, or estimated, and the reader can tell
which without asking.

## Step 1: Prove the snapshot describes this tree

Read `<docs_root>/snapshot.md`. If absent, **REQUIRED SUB-SKILL:** `keel:repo-snapshot`.

Then check its header commit and branch against `git log -1` and `git status`. **Do not skip this.**
A baseline found a snapshot describing a different branch: different auth, different SQL safety,
different test count. Every conclusion from it would have been about a codebase nobody was porting.

Where they differ, say in the assessment which one is being ported.

## Step 2: Name what has no source to port from

Confirm the target stack, then compare it part by part against what exists. Anything with no
counterpart in the source is **new build, not port**, and is split out or scoped separately.

Observed: "port to NestJS and React" against a service with no UI and `has_ui: false`. The React
half had nothing to port from and would have been sold as a translation.

## Step 3: Delegate the reading

Dispatch these `Explore` agents in one message, model `sonnet`. Each is told: cite `path:line`, mark anything absent
as `Unknown` rather than inferring it, and never estimate effort.

| Agent | Brief |
|---|---|
| A. Contract | Every route, its request and response shape, status codes, media types, headers. Flag oddities callers may depend on: a port that tidies one breaks them |
| B. Wire format | Anything the far side validates byte by byte: signatures, field order, null handling, encoding. Name where bytes matter rather than values |
| C. Integrations | Each partner, its auth, how success and failure are actually signalled, and any status semantics that are not the HTTP status |
| D. Data | Schema, migrations, transactions, and what the database does that the application assumes |
| E. Runtime | Config, secrets, key material, scheduled work, file handling, and today's deployment |
| F. Gaps | Test coverage, and everything the snapshot names but does not resolve |

## Step 4: Verify the wire format by running it

Where the far side validates bytes, prove the new stack reproduces them. Run both, diff the output.

A baseline compiled the Java serialiser and found it emits explicit nulls in declaration order where
the obvious replacement dropped them: identical meaning, different bytes, every signature rejected.
No ordinary test catches that.

Bytes asserted but not executed are `inferred`, and say so.

## Step 5: Sweep for what you skipped

**A second pass, not optional, and written down.** One row per input the snapshot, the agents, or a
finding names, marked read or not. Open the unread ones. Repeat until a pass adds nothing.

**A grep count is not reading a file. Nor is its first dozen lines.** Two runs judged a document from
a proxy and admitted it only afterwards. The ledger is section 9, so the skipping is visible to the
reader and not only to you.

## Step 6: Write it

Write `<docs_root>/port/<service>-assessment.md`, following
[references/assessment-template.md](references/assessment-template.md).

Every claim carries `verified`, `inferred`, or `estimated`. **No hours, no story points, no ranges, no
aggregate size.** Rank work against itself where that helps, and name the driver.

Carry every unresolved snapshot finding into the risk table. A port closes none of them.

## Step 7: Route onwards

Offer one: `write-prd` when the port is agreed, `design-architecture` when the stack is open,
`security-audit` when step 5 surfaced credentials or key material. Then stop.

## Common mistakes

| Mistake | Instead |
|---|---|
| Trusting the snapshot's branch | Step 1. Check it against the working tree |
| Selling new build as a port | Step 2. Name what has no source |
| One pass | Step 5. The gaps are known and unopened, not unknown |
| An engineer-week headline | Units of work, the driver, what narrows it |
| Tidying a contract oddity | Freeze the wire contract. Test it, do not improve it |
