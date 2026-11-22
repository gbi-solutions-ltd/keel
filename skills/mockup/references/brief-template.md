# Brief template

The structure of `<docs_root>/mockups/<name>/brief.md` (`docs/mockups/<name>/brief.md` outside a keel
project). Written at intake ([intake.md](intake.md)), updated every review round, read by Convert,
which does not ask again what it answers. The machine-readable answers live in `mockup.config.json`'s
`project` block; this file holds what a script cannot: who, why, what else was offered, and what is
still open.

```markdown
# Brief: <app name>

| | |
|---|---|
| Client | Who the app is for |
| Signs off | Name or role (project.people.signsOff) |
| Technical owner | Name or role (project.people.technicalOwner) |
| Records read | The idea, PRD, architecture record or repo snapshot this brief draws on, with paths; or "none" |
| Status | intake / in review (round N) / signed off / converting |

## What the app is for

Two or three sentences: who uses it and for what. From the PRD or idea record when there is one, with
its path; otherwise the request in the client's own words.

## Decisions

One row per intake question that was answered. The config holds the value; this table holds the rest.

| # | Decision | Answer | Answered by | Source | Alternatives offered | Why |
|---|---|---|---|---|---|---|
| 2 | Design framework | css-library: the client's design system, v3 | technical owner | asked, 2026-11-20 | none; Tailwind | the client's other apps use it |

## Deferred

Tier 2 answers not known yet. Each is also a `deferred` entry in the config, with the same owner and
date.

| Decision | Owner | By | Why not yet |
|---|---|---|---|

## Open questions

Questions that do not block building screens, each with an owner. A question that blocks is asked,
not filed here.

| Question | Owner | Blocks |
|---|---|---|

## Change log

When an answer changes after screens exist: the date, what changed, who decided, and the rework it
causes.

| Date | Change | Decided by | Rework |
|---|---|---|---|
```

## Rules

- **The brief and the config agree.** Every answered or deferred `project` field has a row here, and
  every row here that a script reads is in the config. When one changes, change both.
- **An answer taken from a record cites it** (the PRD's path and section), so it is not asked again
  and its owner is known.
- **Not the design decisions.** Decisions taken in review rounds (what a role may not see, why a
  step exists) go in `decisions.md` as numbered rows ([signoff.md](signoff.md)); a change log row
  here cites the D number.
- **Not a PRD.** No numbered requirements and no acceptance criteria: those belong to keel
  `write-prd`. Not an architecture record: a stack chosen here without `design-architecture` says
  `decidedBy: "user"` and why.
