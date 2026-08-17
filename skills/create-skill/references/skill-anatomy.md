# Skill anatomy

The shape every keel skill follows, enforced by `tests/validate-skills.sh`.

## Frontmatter

```yaml
---
name: kebab-case-name
description: Use when <triggering conditions, symptoms, situations>.
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
---
```

- `name`: letters, numbers, hyphens.
- `description`: starts with "Use when", under 260 characters, third person. **Triggering
  conditions only.** Never a summary of the process, because that summary becomes a shortcut the
  model follows instead of reading the body.
- `allowed-tools`: the minimum that works.

Compare:

```yaml
# Bad: summarises the workflow, so the body gets skipped
description: Use when reviewing code - checks correctness, then style, then reports findings

# Good: says only when it applies
description: Use when asked to review changes, look at a diff, or check work before it ships
```

## Body

Target 700 words. 900 is a hard ceiling; past it the model skims, which is the failure the budget
prevents. `tests/validate-skills.sh` warns over the target, and crossing it needs a passing eval arm
at that length, per `docs/decisions/ADR-0001-skill-body-word-ceiling.md`.

Shorter is still better, and the warning is a question rather than a quota to fill. The previous
numbers were 400 and 600 under a hard 700, and every skill drifted to the ceiling because it was the
only one enforced.

```markdown
# Skill Name

## Overview
What it does in one line, then the core principle in one sentence.

## Step 1..N
Numbered, each one action. Verify lines where something must be checked.

## Common mistakes
A table. Mistake, then what to do instead.
```

Sections that earn their place when the skill needs them: an iron law for a discipline skill, a
rationalisation table built from observed excuses, and red flags for self-checking under pressure.

## What stays in the body, and what moves

**Body:** the decisions, the gates, the ordering, and any brief the skill dispatches to a subagent.
A brief in a reference file is one the model may not have loaded at the moment it builds the
dispatch. Progressive disclosure is right for reading and wrong for constructing a call.

**References:** checklists, templates, worked examples, long tables, and anything used only at one
step. Unbounded in length.

Link with a relative markdown link and a sentence saying when to read it. **Never `@`**, which
force-loads at parse time and burns context before it is needed.

## Cross-referencing

```markdown
**REQUIRED SUB-SKILL:** `keel:tdd`
```

Explicit, by name, with the marker. `See keel:debug` leaves it ambiguous whether it is
required.

## Paths

Never a literal `docs/keel`. Skills use `<docs_root>` and read `profile.docs_root`; templates use
`{{DOCS_ROOT}}`. A literal path fails silently: the skill writes successfully, to a directory
nobody reads.

## Rules with reasons

Every rule states why, and the best reasons name a real failure. "Numbers come from commands, not
committed reports, because a committed report said 1.94% where the truth was 23.29%" survives
pressure. "Be accurate" does not.

An unexplained rule gets rationalised away at exactly the moment it matters.
