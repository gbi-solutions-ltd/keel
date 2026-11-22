# Conversion plan: {{project}} to {{stack}}

| | |
|---|---|
| Mockup | `{{mockup-dir}}`, inventory of {{date}} |
| Sign-off | round {{n}}, {{date}}, by {{who}} (`docs/signoff.json`); `check-config --ready-to-port` {{passes / the lines it printed}} |
| Package | brief `{{path}}`, decisions `{{path}}`, sign-off page `{{path}}`{{, token map, component map}} |
| Target | {{new repo at `{{output-dir}}` / existing repo `{{path}}`, snapshot `{{path}}`, standards `{{path or "seeded in Step 5"}}`}} |
| Output | `{{output-dir}}` |
| Contract | `{{location}}` {{version}}, sign-off round {{n}}, imported with `import-mockup --only contract`; {{drafted from the mockup / the backend's}} |
| Design framework | {{none: the mockup's CSS / Tailwind / a component kit / the client's library, name and version}}; i18n {{none / library, locales}}; route {{pixel port then adopt / straight onto the framework}} ([design-frameworks.md](../../mockup/references/design-frameworks.md)) |
| Size | {{pages}} pages, {{screens}} screens; {{one session / waves, see large-ports.md}} |
| Standards | `<docs_root>/standards.md`, {{existing / seeded by keel:coding-standards}}; departures: {{none / list}} |

> Approve or correct this before any code is written.

## Assumptions

Every row of `decisions.md` the port relies on, citing its D number (a "not reversible" one is a
backend dependency). Then only where the package was silent, or when running unattended. One line each; each becomes a gap
report entry if it is not confirmed. Running unattended across waves, keep one numbered decision log
instead, each decision marked reversible or not ([large-ports.md](large-ports.md), Records).

-

## Modules and checklist

Modules from `mockup.config.json` (`auth-mfa`, `tours-help`) and the files copied for each.
Checklist items marked `later` become gap report entries; any still undecided is an open question
below.

| Module or item | Decision | What the app gets |
|---|---|---|

## Routes

| Mockup page | Route | Layout | Permission | Page component |
|---|---|---|---|---|
| `pages/x.html` | `/x` | AppLayout | `x:read` | `XPage` |

## Components

For more components than this plan can carry, write the full map from
[component-map-template.md](component-map-template.md) (with Used by and stack notes) and keep here
only the components the plan discusses.

| Mockup component | Layer | Target file | Props | Interactive |
|---|---|---|---|---|
| `Badge` | primitive | `components/primitives/Badge/Badge.tsx` | `{ tone, label }` | no |

## Contract

| Operation | From | Used by | Status |
|---|---|---|---|
| `GET /v1/x` | `needs.api` on `/x` | `XPage` | drafted / agreed / `not-designed` |

Fixtures checked against the schemas: {{all pass / list of mismatches and which side is wrong}}.
With a fixed backend contract: the adapter layer's transforms, and the visible mismatches with what
each becomes (expected-diffs entry or question).

**Departures from the engine's API defaults** (a vendored contract wins):

| Default | This contract | What the app does |
|---|---|---|

## Page state and actions

| Page | State | Actions and their handlers | Stubbed, with gap entry |
|---|---|---|---|

## Mockup findings carried in

Inventory lint and quality-check failures on the mockup, and what was decided for each: fixed in the
mockup before conversion, or carried into the app as a gap.

| Finding | Decision |
|---|---|

## Open questions for the user

Only what the package leaves open: each names where its answer is recorded (a field such as
`project.telemetry`, a checklist item, a `not ready:` line, or the brief's open question it
carries). A question the package answers is a defect in this plan.

1.
