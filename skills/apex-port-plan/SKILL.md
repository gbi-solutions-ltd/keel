---
name: apex-port-plan
description: Use when deciding whether or how to port an Oracle APEX application to another stack, after apex-export has produced an export, or when asked to scope, size, or plan an APEX migration.
allowed-tools: [Read, Write, Grep, Glob, Bash, Agent, AskUserQuestion]
---

# APEX Port Plan

## Overview

Read an export produced by `apex-export` and produce one assessment that says what the application
does, what porting it costs, and what should not be ported at all.

**Core principle:** every claim cites a `path:line` inside the export, or is marked `Unknown`. The
export exists so that nothing here is recalled from what APEX applications usually look like.

## Step 1: Find the export and read only its index

Locate `<docs_root>/apex/APP-<id>/`. If there is none, invoke `apex-export` first and stop.

Read `INDEX.md`, `manifest.json`, and `xref.tsv`. **Read no page files yourself.** A large
application is tens of megabytes of SQL, and reading it inline puts it in context for the rest of
the session. That is what the subagents are for.

Confirm the target stack before dispatching. If the profile does not name one, ask once: the data
model brief and the screens brief both change with the answer.

## Step 2: Delegate the reading

Dispatch these `Explore` agents **in one message** so they run concurrently, model `sonnet`, and
say which model in one line. Each is told: cite
`path:line` from the export for every claim, mark anything absent as `Unknown` rather than
inferring it, and never estimate hours.

| Agent | Brief |
|---|---|
| A. Data | Read `db/tables/` and `xref.tsv`. Produce the entity list, keys, foreign keys, and which tables are written by the application rather than only read. Flag tables in `xref.tsv` with no file under `db/tables/`: those are objects the export could not see, and each is unscoped work |
| B. Logic | Read `db/plsql/`. For each package: what it does, which pages call it, and whether it is a candidate to keep behind an API or must be rewritten. Name any package that does DML across several tables in one call, because that is a transaction boundary the new stack has to reproduce |
| C. Screens | Read every `pages/*/page.md`. Produce a route map: page id, purpose, its regions, and the proposed route. Group pages that are one flow. Name every page whose only purpose is navigation, since those usually disappear |
| D. Auth | Read `shared/authorization/`, `shared/authentication/`, and the Authorization column of the page inventory. State the authentication mechanism, every distinct authorization scheme, and which pages use each. Flag any page with no authorization scheme and no page access protection |
| E. Integrations | Grep the whole export for `apex_web_service`, `utl_http`, `apex_mail`, `utl_smtp`, `apex_application_temp_files`, `wwv_flow_files`, and any `shared/web_sources/`. Every hit is an outbound or inbound dependency that must be rebuilt. Report endpoint, direction, and calling page |
| F. Gaps | Read the "What could not be read" section, `REDACTIONS.md`, and `shared/build_options/`. Report what the export does not cover, every credential found in application source, and any feature behind a build option set to Exclude, which is code that ships but never runs |

For an application under roughly 20 pages, collapse to three agents: A+B, C+D, E+F.

## Step 3: Challenge the bands

The bands in `INDEX.md` are computed from counts. They are a starting point and they are often
wrong in one direction:

**A band is too low when** the page's PL/SQL calls a package that does the real work, because the
score counts characters on the page, not behind it. Cross check agent B's output against agent C's.

**A band is too high when** an Interactive Report is used as a plain table with no saved reports,
no aggregates, and no downloads. Say so, and say what you checked.

Record every band you revise, with the reason. An unrevised band is also a judgement; do not let it
look like one nobody made.

## Step 4: Write the assessment

Write `<docs_root>/apex/APP-<id>/PORT-ASSESSMENT.md` using
[references/assessment-template.md](references/assessment-template.md).

The mapping from each APEX mechanic to its replacement, and the four that have no replacement, are
in [references/apex-to-web-mapping.md](references/apex-to-web-mapping.md). Read it before writing
Step 4, not before Step 2.

## Step 5: Route onwards

Offer one next step and stop: `write-prd` when the port is agreed and needs requirements,
`design-architecture` when the stack is still open, `write-plan` when both are settled.
