---
name: apex-export
description: Use when asked to export, extract, read, or inspect an Oracle APEX application, when planning to port an APEX app off Oracle, or when given an APEX app id and a database connection together.
allowed-tools: [Read, Write, Grep, Glob, Bash, AskUserQuestion]
---

# APEX Export

## Overview

Turn one APEX application into a directory an agent can grep, then stop. The assessment is
`apex-port-plan`, and doing both in one pass produces a plan written before the export was read.

**Core principle:** the native APEX export is not the artifact. Every reference inside `f100.sql`
is a 14 digit internal id, so grepping it for a table name finds nothing. The APEX dictionary
views carry the same metadata with real names, and they need lower privileges. `keel apex-export`
reads the views and keeps the native export under `raw/` only as ground truth.

## Step 1: Check what you have

Run `keel apex-export --help`. It fails with a named dependency if `python3` or `java` is absent.

SQLcl is the only supported client. It needs Java and nothing else, no Oracle Instant Client. If
it is missing, say so and stop: unzip `sqlcl-latest.zip` from Oracle and put its `bin/` on PATH.

## Step 2: Get a connection without putting a password in the transcript

**Never ask the user to paste a password into the conversation, and never write one into a
command you run.** Both land in the transcript, which is stored and may be reviewed.

Ask them to create `~/.keel/apex-targets.json` themselves:

```json
{ "prod-ro": { "conn": "user/pass@host:1521/service" } }
```

then run with `--target prod-ro`. Suggest they type `! chmod 600 ~/.keel/apex-targets.json`.

**Ask for a read only user mapped to the workspace**, not a DBA account. The dictionary views
show only applications in workspaces the connecting schema is associated with, so a read only user
is sufficient and is the right thing to request.

## Step 3: Probe before exporting

```
keel apex-export --app <id> --target <name> --probe-only
```

Report the APEX version, the application name, the parsing schema, and the connected user back to
the user in one line. **If the version or the application name is not what they expected, stop and
ask.** Exporting the wrong application from the wrong environment wastes the export and, worse,
seeds every later decision with the wrong system.

## Step 4: Export

```
keel apex-export --app <id> --target <name>
```

Writes `<docs_root>/apex/APP-<id>/`. Add `--raw` only when the native export is genuinely wanted;
it is large and nothing reads it by default.

## Step 5: Report honestly, then hand off

Read `INDEX.md` and `manifest.json`. Three things get reported, and none may be skipped:

**The "What could not be read" section is scope, not a footnote.** A view absent on this APEX
version is a component class the export does not cover. Say which, and say that it is unknown
rather than absent.

**`REDACTIONS.md` is a finding.** A credential in a page process is a live secret sitting in a
production application. Name the count and the files. Do not print the values, and do not re-run
with `--no-redact` to see them.

**Bands are signals, not estimates.** Give the band counts. Say plainly that the numbers rank
pages against each other and are not hours, because a number in a table gets quoted as one.

Then offer `apex-port-plan`. Do not start assessing here.

Connection problems, wallets, ORDS, and the privilege questions that come up are in
[references/connection-and-privileges.md](references/connection-and-privileges.md).
