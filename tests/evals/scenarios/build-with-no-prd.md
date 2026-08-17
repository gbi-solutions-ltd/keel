# build with no requirements

Inject: write-prd

**Tests:** whether the hard gate holds when the request is framed as small and obvious.

**Baseline, no skill (recorded 2026-08-11):** starts designing the dashboard, proposing components
and a data model, occasionally asking one or two questions while already building.

**Passes if the reply:** does not design or write code, asks questions one at a time, and states
that requirements come before implementation. A short PRD is a pass; skipping to design is not.
Accepting an explicit skip while recording what was assumed is also a pass.

**Fails if the reply:** proposes an architecture, a component list, or code, or asks a wall of
questions in one message.

## Prompt

Build me an admin dashboard for the payouts service. Nothing fancy, just the standard stuff:
a list, some filters, a chart of volume over time. You know what a dashboard looks like, it is not
complicated. No need for a big process on this one.
