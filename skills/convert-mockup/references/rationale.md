# Why the convert-mockup skill works the way it does

Read this before changing a step. Each entry is the reason for one instruction in this skill's
`SKILL.md`, and where one exists, the failure that produced it.

The reasons shared with Mock (the mockup is the specification; plain HTML, framework shaped) are
in [the mockup skill's rationale](../../mockup/references/rationale.md).

## Contract first, client generated

keel's rule is that a schema is never maintained alongside the code it describes. Drafting the
OpenAPI document from the mockup's `needs.api` and fixtures puts the contract in front of the backend
team early, as something concrete to agree or correct. Generating the client, the hooks, the mocks
and the validators from it with Orval means none of them can drift from it or from each other, and a
contract change shows up as compile errors at every place it reaches. Parsing the fixtures against
the generated schemas is the first test of whether the mockup and the contract even agree.

## Stop for approval before code

The component map and route table are the cheapest place to correct a wrong assumption: a line in a
plan, not a refactor. Running unattended is allowed, but then the assumptions go at the top of the
plan, where the person returning reads them first.

## Hand the plan to keel in a keel project

keel's `execute-plan` already brings test-first development, review and the delivery gates. A
conversion that ran its own loop beside them would be a second, weaker process for the same code.

## Seed the standards before porting

keel's house defaults bind a project through its `standards.md`, with departures recorded there. A
converted app with no standards document has defaults nobody agreed to and no place to record a
departure. Seeding first also wires the mechanical checks before there is code that fails them.

## The port order

Tokens and the contract come first because everything else references them. Components go leaf
first so each one is ported against already ported children. Formatting helpers matter more than
they look: the visual diff compares rendered text, so a date formatted differently fails it.

## Never hide or disable an undesigned action

Disabling a button changes how it looks, so the visual diff fails, and it hides the gap from
whoever reads the app later. Keeping it identical with a stub that logs `[todo]` keeps parity and
keeps the gap visible in three places: the UI, the code comment, and the gap report.

## Verify with the visual diff, not by eye

Comparing screenshots by eye misses small differences and wastes time on large ones. The pixel diff
says whether something differs; the component diff says which component and in which dimension. In
proving this skill it named a fieldset 72px taller than designed after a formatting tool had
silently undone an edit: a defect nobody would have looked for.

The app-mode threshold is 0 (0.2% for a js-kit, whose components the mockup only approximates;
the defaults are in [mockup-config.md](../../mockup/references/mockup-config.md)) because both sides render in the same
Chromium, so a faithful port reaches 0. Raising it to pass hides exactly the regressions it exists to catch.

## Check the built app under its real headers

A development server is not what ships. Serving a mocked production build with the production
security headers is how the strict CSP gets tested before deploy. It caught the visual diff's own
injected stylesheet being blocked, which is the policy working, and it is where a library that
injects inline styles would be caught.

## The gap report

Everything the mockup did not specify has to be decided by someone. Writing it down, with an owner,
turns "the developer guessed" into "the backend team confirmed". It also lists the server-side
enforcement the frontend assumes, because a permission enforced only by hiding UI is no permission.

## Per-record actions come from the API

Whether a payment can be refunded depends on the user's permissions, the payment's state, and rules
such as "the initiator cannot approve". Recomputing that in the browser duplicates the policy in a
second language that drifts from the first. `allowed_actions` keeps the decision on the server and
leaves the UI one question: is the action listed.

## The menu is built from the route table

A menu kept beside the routes eventually links to a page the route refuses, or omits one a role may
open. Building it from the same table makes that impossible rather than checked.

## Exports are built by the server

An export made in the browser contains the rows on the screen, while the user expects the whole
filtered report. Building it on the server, in the background, also puts the audit record, the
permission check and the CSV injection guard where they cannot be skipped.

## Versions: newest at least 14 days old, pinned

Taking the newest release avoids starting a project on a major version that is already behind; the
first proving run found MSW, Vitest, Zod and React Router all a major version ahead of what the
first draft assumed. Waiting 14 days avoids the window in which a compromised or broken release is
usually caught. Pinning and a committed lockfile make the build that was tested the build that
ships. A security fix may skip the wait, because the known vulnerability is the bigger risk.

## Tests live in tests/, not beside the code

`src/` then holds only what ships, so a reader, the bundler and a coverage report see the app
alone, and the test tree mirrors the source tree so each test is found by its subject's path. A
rule in `check-frontend` keeps it that way, because a convention nobody checks drifts the first
time someone copies a pattern from a blog post.

## Two skills and a port worker

Mock and Convert are two skills because each stops for people at different points (the client at
intake and sign-off; the approver of the plan) and both work inside a repository with its own
standards, in the session of the person who approves. A skill carries the steps and references
into that session; only the main session can ask anyone anything or chain keel's other skills.
The port itself is the exception: one slice of an approved plan, ported until its gate passes, is
long, mechanical and noisy, so `agents/keel-port-worker.md` does it in isolation and returns the
gate's own summary lines. It never changes the mockup, the gate's configuration or a threshold.

## Large ports are run in waves from seams the main session builds

Agents in parallel are fast only when they cannot collide. The main session builds the shared
components, the per-area mock and route files and the test resets first, gives each agent a file
list, and applies every change outside it at the merge. Each wave is gated against the previous
merged run, case by case, because a total hides a case that got worse.
