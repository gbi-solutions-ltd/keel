# Intake: the decisions a mockup is built from

Read this before the first screen of a new mockup, and again before Convert when the readiness check
lists open answers. The intake turns a request into two records the rest of the engine reads without
asking again:

- **`mockup.config.json` `project` block**: the machine-readable answers, validated by
  [mockup-config.schema.json](../../../lib/mockup-engine/mockup-config.schema.json).
- **`<docs_root>/mockups/<name>/brief.md`** (`docs/mockups/<name>/brief.md` outside a keel project):
  the record. Who answered, why, the alternatives offered, what was deferred and to whom. From
  [brief-template.md](brief-template.md).

`<name>` is the app's short name in kebab case (`field-visits`). It is the config's `name`, the
brief's folder and, by default, the mockup's folder (`mockup/` beside `docs/` in a project, or
`<name>-mockup/` on its own). Secrets, credentials and tenant data go in neither record.

## Why two tiers

Asking every production question before a client sees a screen slows the cheapest phase, and a
mockup often comes before the client has decided. Asking none of them builds a mockup on assumptions
that cost a second pass later (strings inline when there are two languages, the mockup's own CSS when
the client has a design system). So:

- **Tier 1, before the first screen**: answers that change how the mockup is built. Asked now.
- **Tier 2, before Convert**: answers that change only the port. Asked now when someone knows,
  otherwise deferred with an owner and a date. The readiness check refuses to convert while any is
  open.

The schema's `x-tier` is the list; this file says how to ask.

## Read before asking

An answer that already exists is cited, not asked. List the folders, then read, in this order, and
skip every question a record answers:

1. `<docs_root>/ideas/` (keel `shape-idea`): the problem, who has it, open questions.
2. `<docs_root>/prd/` (keel `write-prd`): roles, locales, accessibility, devices, browsers.
3. `<docs_root>/architecture/` and `<docs_root>/decisions/` (keel `design-architecture`): the stack,
   the identity provider, the backend, hosting.
4. For an existing repo: its `snapshot.md` (keel `repo-snapshot`) and its standards. The repo's design
   system, i18n library and stack are read there, not asked.
5. The request itself and anything the client sent (a brand guide, a design system's docs).

Record each answer taken from a record with its path in the brief.

## How to ask

These follow keel's `asking-questions.md` (in the keel plugin, `skills/keel/references/`); what
matters here is repeated so this file stands alone:

- **One question per message.** For a single choice, the recommended option goes first and its label
  ends `(Recommended)`. For a multiple choice, the recommended options go first and none is labelled:
  order carries the recommendation.
- **Two to four options**, each saying what happens if chosen. No fake options.
- **A question for the client goes through the user.** You talk to the user; say who the question is
  for ("for the client:"), and the user answers it or takes it to them. Record who actually answered.
- **A cheap, reversible choice is stated, not asked**: "Viewports: phone 390 by 844 and desktop 1440
  by 900; say if not." It still goes in the brief.
- **A list is proposed, not asked item by item.** Modules and the checklist (question 10) are one
  message: a table of proposed answers, with corrections invited.
- **Stop asking when the answer would not change what you build next.** It goes in the brief as an
  open question with an owner.

## Tier 1: before the first screen

| # | Ask | Of | Recommended answer | Writes | Changes in the mockup |
|---|---|---|---|---|---|
| 1 | Who signs the mockup off, and who answers technical questions? | user | the client's product owner signs off; the user is technical owner | `project.people` | who the later questions go to |
| 2 | Does the client have a design system, or want a framework? | client, then technical owner for the details | none, unless one is named | `project.designFramework` | tokens, components, the gate (below) |
| 3 | Which languages, and is any right to left? Will some run longer than the default (German, French, Finnish)? | client | the request's language only, left to right | `project.i18n` | strings in a locale file from the first screen; an expansion check; mirrored layout for RTL |
| 4 | Which roles use it, and must one organisation's data stay apart from another's? | client | the PRD's roles, else a user and an administrator; single tenant | `project.tenancy`; the roles in the brief, the fixtures' roles when they are built | a screen per role; tenant switching designed or not |
| 5 | Devices and browsers | client | phone and desktop (stated); `last 2 versions, not dead` | `viewports`, `project.browsers` as a browserslist query | each viewport signed off |
| 6 | Accessibility target | client | WCAG 2.2 AA | `project.accessibility` | the quality check's level |
| 7 | The business time zone, and the currency, if any | client | no default for the zone: it is a fact, ask it; currency `none` when the app handles no money, else one ISO code | `timezoneId`, `project.currency` | dates and amounts in fixtures, formatting, every baseline. Number and date formats follow the locale and need no answer |
| 8 | Light only, or dark too (following the system, or the user's choice)? | client | light only | `project.theming` | a second token set and its screens. With a design framework, its dark tokens are used when it has them; otherwise the mockup adds a second set mapped onto the framework later, recorded as an open question |
| 9 | Sign-in: in the app, or the identity provider's hosted page? | technical owner | in the app | `project.auth` | which sign-in screens exist. In the app turns the `auth-mfa` module on in question 10; a hosted page leaves sign-in out of the mockup and `password-reset` to the provider |
| 10 | Modules and the checklist, proposed as one table | client | per [modules.md](modules.md): the modules the request and question 9 imply on, every checklist item `later` or `not-needed` with a reason | `modules`, `checklist` | module pages copied in. With `system-pages`, also ask whether work done offline must be queued (it needs a backend sync endpoint; a banner needs nothing) |

**Question 2 decides the most.** Ask it straight after question 1. When the answer is not `none`,
follow up for the details, as one message to the technical owner: the name, the version, whether the
client owns it, and where it comes from (`project.designFramework.name`, `version`, `owner`,
`source`). Then say which gate follows, before moving on:

| Kind | The mockup | The port is proven by |
|---|---|---|
| `none` | its own tokens and CSS | the visual diff at 0% against the mockup |
| `utility-css` (Tailwind and the like) | the framework's built CSS copied into `assets/vendor/<name>/`, its classes in the markup | the visual diff at 0% |
| `css-library` (a design system shipped as CSS) | the library's CSS copied into `assets/vendor/<name>/` at the pinned version, its markup and class names | the visual diff at 0% |
| `js-kit` (Material UI, Vuetify, shadcn/ui) | an approximation of the kit's components in the mockup's own CSS, named after them and calibrated against the kit's computed styles | a near-zero pixel tolerance declared after calibrating, the DOM structure of our own parts, and the behaviour tests. Tell the client: sign-off is on an approximation of the final look |

Copy vendor CSS into the mockup rather than linking a CDN, so the mockup opens offline and the version
cannot move under a signed-off screen. [design-frameworks.md](design-frameworks.md) has the rest.

## Tier 2: before Convert

Ask each when someone can answer; otherwise write
`{ "deferred": { "owner": "<who>", "by": "<YYYY-MM-DD>", "reason": "<why not yet>" } }` and move on
(`by` is a real date; `check-config` warns once it has passed).
All go to the technical owner.

| # | Ask | Recommended answer | Writes |
|---|---|---|---|
| 11 | Does the backend publish an OpenAPI document, or do we draft the contract from the mockup? | drafted, agreed with the backend at sign-off. The one tier 2 answer whose deferral ends at sign-off, not Convert: [signoff.md](signoff.md) | `project.contract` |
| 12 | A new repository, or an existing one (where)? | new. For an existing one, keel `repo-snapshot` runs on it before Convert: [existing-repo.md](../../convert-mockup/references/existing-repo.md) | `project.target` |
| 13 | Which stack? | the architecture record's choice. With no record, recommend running keel `design-architecture` before Convert and deferring this to it; when the user picks instead, record `decidedBy: "user"` and their reason in the brief | `project.stack` |
| 14 | Where it deploys, and who sets up CI | handed to keel `setup-deployment` | `project.deploy` |
| 15 | Where errors and traces go | an OTLP backend, or `none` for now | `project.telemetry` |

## After the intake

1. Write the `project` block, `timezoneId`, `viewports`, `modules` and `checklist`, and the brief.
   Leave the top-level `locale` unset: the checks take it from `project.i18n.defaultLocale`.
2. Run `node scripts/check-config.mjs <mockup>`. It needs no pages: it catches a malformed answer and
   prints `ready to port (decisions only):` with what is still open. The inventory runs the same
   checks with the pages, so run it once the starter is copied and each module's files are in
   (before that, a module that is on fails its `module-page` rule, as it should).
3. Build the mockup to the answers: tokens from the design framework, strings from the locale file,
   the roles and viewports agreed.
4. When an answer changes during review rounds, change it in both records and add a line to the
   brief's change log. A tier 1 answer changing after screens exist is a rework item.
5. At sign-off ([signoff.md](signoff.md)) the decisions must be answered or deferred and the contract
   drafted. Before Convert, `check-config.mjs --ready-to-port` (or the inventory with the same flag)
   must pass: its decision lines are questions to ask or deferrals to record, and its `signoff` lines
   say whether the mockup and contract are still the ones signed off.
