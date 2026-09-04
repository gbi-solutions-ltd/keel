---
name: coding-standards
description: Use when asked about a project's conventions or assessing code against them, setting up linting or formatting, onboarding onto an unfamiliar codebase, or when review feedback keeps repeating the same style point.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---

# Coding Standards

## Overview

Write down what this codebase already does, then move everything mechanical into a tool.

**Core principle:** a convention a linter can check should never be a document anybody reads. Ink
is for judgement calls only.

## Step 0: Choose the mode

Two facts choose it, before anything is read: whether `<docs_root>/standards.md` exists, and whether
there is code. No document and code is **audit**, [references/audit.md](references/audit.md). No
document and no code is **seed**, [references/seed.md](references/seed.md). A document, either way,
is **assess**, [references/assess.md](references/assess.md), naming any check a missing corpus
stopped. **Author** is steps 1 to 5, and is what audit offers at its end.

The request's words win where they conflict. Where a precondition is wrong, say so: asked to assess
with no document, offer seed or audit by which fact holds; asked to seed or author over one, name it
and ask first. Ambiguous with a document present, ask once.

## Step 1: Derive, do not impose

Read the code before writing anything. The conventions that matter are the ones already in use,
not the ones you would choose.

Sample at least ten files across different areas and look for: naming, file and directory layout,
error handling, logging, how tests are structured and named, import ordering, and how
configuration is reached.

Where the codebase is inconsistent, count. The majority pattern is the convention; the minority is
either drift to be fixed or a deliberate exception worth recording. Do not silently pick the one
you prefer.

**Counting decides style, never correctness.** Where the majority pattern is a defect, record the
minority as the rule and say why. A real run found 7 concatenated SQL queries against 3
parameterised: writing the majority down as the convention would have sanctioned an injection
vulnerability. Same for a missing timeout or an absent authorisation check.

## Step 2: Split mechanical from judgement

Sort every convention you found into one of two piles.

| Pile | Goes to | Example |
|---|---|---|
| A tool can check it | Linter, formatter, or a CI script | Indentation, import order, no `console.log`, banned characters |
| It needs judgement | `<docs_root>/standards.md` | When to extract a service, what belongs in a controller, how much to mock |

Anything in the first pile that ends up in prose will be ignored within a month, because nobody
re-reads a style guide. Anything in the second pile put into a linter produces false positives
that teach people to disable the linter.

## Step 3: Wire the mechanical pile

Configure or extend the project's existing tooling, reading `.keel/profile.json` for what is
already there. Add rules incrementally, and fix what they flag in the same commit; a linter
landing with 400 warnings is a linter everyone learns to ignore.

If `profile.verify.lint` is `null`, adding one is the highest-value work here. Prefer a
check-only command for gates and a separate `--fix` variant for local use: a `lint` script that
mutates cannot serve as a CI gate.

Where a rule is right but its violations cannot be fixed now, keep it and suppress the known sites
in a committed file, each entry naming what closes it. Never widen or drop the rule: the suppression
is what keeps anything new failing. List them under "Not yet mechanical" in `standards.md`.

## Step 4: Write the judgement pile

Write `<docs_root>/standards.md`. Follow
[references/standards-template.md](references/standards-template.md).

Every entry states the rule, one line on why, and a concrete example from this codebase. A rule
with no reason gets argued about; a rule with no example gets misread.

Include the house defaults from [references/house-defaults.md](references/house-defaults.md), noting any
this project deliberately departs from. It opens with an index of the topic references and when each
applies. Read the ones that do, no more.

## Step 5: Verify and report

Run `profile.verify.lint`. It must pass on the current codebase, or you have shipped a broken
gate.

Report: what was derived, what is now enforced by a tool, what remains judgement, and any
inconsistency you found but did not resolve.

## Common mistakes

| Mistake | Instead |
|---|---|
| Importing a generic style guide | Derive from the code. Ten files, then count |
| A style guide nobody can enforce | Move it into the linter, or delete it |
| Landing a linter with hundreds of warnings | Add rules incrementally, fix as you go |
| A `lint` script that rewrites files | Gates need a check-only command |
| Rules with no reason | Unexplained rules get relitigated every quarter |
| Treating a cache or a limit as performance work | Both are correctness. Staleness and the effective limit are stated numbers, not emergent ones |
| Fixing the minority pattern silently | Count first, then say which you chose and why |
