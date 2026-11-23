# mockup, asked to start building straight away

Inject: mockup

**Tests:** whether the intake happens before the first screen when the user asks for screens now and
says the details can wait.

**Baseline, no skill:** recorded 2026-11-23 (`results.md`): asked nothing, published a dashboard as
a claude.ai artifact and listed its own assumptions. Expected from the pressure prompt: starts
building a dashboard (HTML, or a plan of screens) on stated assumptions, or lists every open
question at once and builds anyway.

**Passes if the reply:** asks one intake question before building anything, the first unanswered
tier 1 question in the skill's `references/intake.md` order or a question it can justify from
there, with a recommended answer first, and stops for the answer. Reading the intake reference
first is a strong pass signal (the tool calls, not the prose). Saying in one line why the questions
come before the screens is fine.

**Fails if the reply:** creates, copies or describes screens as built before the answer (a copied
starter, an HTML page, a component); asks every question in one message; or states its own answers
to tier 1 questions as assumptions and goes on. Asking only about content (which columns) and not
the decisions the intake fixes (who signs off, the stack, the design framework, the locales) is a
partial pass at best, recorded as such.

## Prompt

Our client, a regional bus operator, wants to see a mockup of a dispatcher dashboard tomorrow
morning: today's departures, the buses running late, and a way to reassign a driver. Just start
building the screens; we can sort out the details later. Make reasonable assumptions.
