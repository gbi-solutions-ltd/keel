# Frontend defaults for a converted app

Read this before scaffolding, and again before calling a conversion done. It says how a converted app
meets keel's standards, which mechanical check holds each rule, and where the worked example shows it.

**The standards themselves live in keel**, in `keel:coding-standards`: `house-defaults.md`,
`frontend.md`, `observability.md`, `resilience.md`, `api-contracts.md`, `authorisation.md` and
`time-and-dates.md`. This file is the how, not the what. Where it disagrees with keel, keel wins and
this file is wrong. Where the target project's `<docs_root>/standards.md` records a departure, the
departure wins.

Two sections below were marked **Proposed for keel**; they are now keel's own rules, in
`coding-standards`' `frontend.md` (responsive layout, permission-aware UI, reports and exports, no
silent failure, sign-in and second factors) and `observability.md` (In the browser), and the API
client and tour libraries are rows in the `keel` skill's `tool-choices.md`.

Example paths are relative to `examples/paydesk-react/` (in the proving repository). The modules every app starts with
(`api/http.ts`, `lib/telemetry.ts`, `lib/query.ts`, permissions or the session), the configs
(`vite.config.ts` or `next.config.ts` and `proxy.ts`, `package.json`, the env files) and the files
the checks read (`biome.json`, `orval.config.ts`, `security-headers.json`, `perf-budget.json`,
`staging-flows.json`) come from the app scaffold, `templates/app-scaffold/<stack>/`, not from the
example. The example code a port needs beyond the scaffold (the test setup, the tests every app
writes, the focus and input patterns) is in [stacks/react-vite-patterns.md](stacks/react-vite-patterns.md).

## The checks, and what each one holds

| Command | Holds |
|---|---|
| `npm run typecheck` | Strict types, generated client matches the contract |
| `npm run lint` | Biome (format, lint, a11y, `noDangerouslySetInnerHtml`) then `scripts/check-frontend.mjs` |
| `npm test` | Vitest, from `tests/` at the app root (never inside `src/`: rule `test-location`). `tests/sweep/` holds the cross-cutting checks: every data page in its error, empty and loading states, sessions that end, maintenance recovery, off-site links, idempotency on retry, failures shown in our copy. On React and Vite, the scaffold's `npm run test:coverage` reports coverage by file. Also: behaviour, error copy, permissions per role, sorting and paging requests, saved columns, exports, the palette, CSRF, CSV rules, redaction, fixtures against the contract ([the fixtures test](stacks/react-vite-patterns.md#fixtures-against-the-contract)) |
| `scripts/visual-diff.mjs` | The app matches the signed-off mockup, every screen, state, role, interaction and viewport |
| `scripts/quality-check.mjs` | axe WCAG 2.2 AA (its `color-contrast` rule is the contrast check, its `target-size` rule the 24px target check), no horizontal scroll down to 320px, a 44px touch warning on mobile, visible focus, no dashes, no console or CSP errors |
| `npm audit --audit-level=high` | No high severity advisory, or a recorded exception |

`check-frontend.mjs` exists because each of its rules is mechanical and Biome cannot check it. keel
says a mechanical rule belongs in a tool, not in a document.
It exits 1 on a finding, and 2 when it could not run (a source root missing or holding no files, a
crash). It counts `style={obj}` as an inline
style. A comment `check-frontend-allow <rule>: <reason>` on the line before allows that one finding
(never `dash`), listed and counted in the summary; one with no reason, an unknown rule or nothing to
allow is itself a finding. Use it only for a case the rule cannot tell apart (a style prop that
clears a kit's own inline value, so nothing is rendered).

## Theming

- `tokens.css` is copied from the mockup unchanged and is the only file with a raw colour, font or
  size. Components use `var(--token)` only. Held by `check-frontend` rule `raw-value`.
- One mechanism: CSS custom properties plus CSS Modules, or the mockup's sheet kept global where its
  selectors cross components ([stacks/vue-gotchas.md](stacks/vue-gotchas.md#gotchas-to-watch)). No CSS-in-JS of our own, which would also need
  `style-src 'unsafe-inline'` and break the CSP below. No inline `style`: rule `inline-style`.
- **When the client names a design framework** (Tailwind, a component kit, their own library), it
  is an intake answer and the mockup is built in it, its theme built from these tokens:
  [design-frameworks.md](../../mockup/references/design-frameworks.md). The CSP still holds; a kit that injects styles at
  runtime gets a nonce that changes on every response.
- Dark mode, if the client wants it, is a second token block under `prefers-color-scheme`, decided
  at intake (`project.theming`).

## Components

- Four layers plus pages, as keel's `frontend.md` names them: `components/primitives`,
  `components/composites`, `components/domain`, `components/layout`, then `pages`. The mockup tags each
  component with its layer, so the folder is decided before conversion starts.
- A layer imports only from its own layer or below; a primitive imports no domain or API type.
  Held by `check-frontend` rule `layer-import`, and in the mockup by inventory rules `layer-order`
  and `no-layer`.
- A wrapper whose root is another component (`TransactionStatusBadge` renders `Badge`) adds no DOM
  and no styles of its own.
- `data-component="Name"` stays on each component's root. The visual diff uses it to name the
  component that moved.
- Each component's CSS block becomes its CSS Module unchanged, except that a reference to a global
  utility from `base.css` is wrapped as `:global(.name)`. Without it the rule is silently scoped
  away: the visual diff caught a right-aligned column and a palette's text colour lost this way.

## Accessibility

- Native elements first: `button`, `a`, `table` with `caption` and `scope`, `fieldset` and `legend`
  for a group of controls. Biome's a11y rules catch most misuse.
- `:focus-visible` outline in `base.css`, never removed without a replacement. Route changes move
  focus to the new `h1` (`AppLayout.tsx`, with a global rule for the focused heading:
  [the code](stacks/react-vite-patterns.md#focus-on-the-page-heading)). Held by `quality-check` rule `focus`.
- Loading announces itself (each skeleton has `role="status"` and hidden text); failures use
  `role="alert"`.
- Dialogs are native `<dialog>` elements opened with `showModal()`; focus returns to whatever opened
  them. A region that scrolls on its own (a wide table on a phone) is focusable and labelled. A
  dialog body that may scroll takes `tabindex="0"` only while it overflows, so it adds no tab stop
  when it fits.
- Colour is never the only signal: a badge says its status in words.
- `prefers-reduced-motion` is honoured globally in `base.css`.
- axe runs on every screen, state and viewport, against the mockup before sign-off and against the
  app before done. It catches roughly the mechanical third; tab through the main flow by hand too.

## Responsive layout

**Proposed for keel.** keel's `frontend.md` has no section on this yet.

- **Mobile first.** Base rules are the narrow layout; `min-width` media queries add the wider one.
  A `max-width` query is a desktop design squeezed down, and it is the one that breaks at a width
  nobody tested.
- **One breakpoint list**, documented in `tokens.css` (`--breakpoint-md: 768px`,
  `--breakpoint-lg: 1024px`) and used literally in queries, since a custom property cannot appear in
  a media query.
- **No horizontal page scroll at any width down to 320px.** Wide content scrolls inside its own
  container (`.card` has `overflow-x: auto`). Held by `quality-check` rule `overflow`.
- **Touch targets** are at least 24 by 24 CSS pixels or spaced so a 24px circle on each touches no
  other (WCAG 2.5.8, fails the check), and controls aim for `--target-min` (44px) on a coarse
  pointer (a warning). A small code link in a dense table cell fails 2.5.8; a `min-height: 24px`
  with a matching negative block margin fixes it at no pixel cost. Put it in the data table's CSS
  in the mockup, so mockups pass from the start.
- **Every configured viewport is part of the sign-off.** `mockup.config.json` lists them, and the
  client approves the mobile layout as explicitly as the desktop one.

## Security

- **No token in JavaScript.** The session is an `HttpOnly`, `Secure`, `SameSite` cookie set by the
  server; `apiFetch` sends it with `credentials: 'same-origin'`. Nothing writes a token to storage:
  rule `token-storage`. No token in a URL: rule `token-in-url`.
- **CSRF**: double submit, when we draft the contract (a backend's contract may use an Origin check
  instead; it wins, see [api-integration.md](api-integration.md)). The server sets a readable `csrf_token` cookie; `apiFetch` copies it to
  `X-CSRF-Token` on every state-changing method; the server compares. Tested in `http.test.ts`, which the app writes (the scaffold ships none:
  [an example](stacks/react-vite-patterns.md#the-http-and-telemetry-tests)). The
  server half is a gap until the backend confirms it.
- **XSS**: no `dangerouslySetInnerHTML`, `v-html`, `:innerHTML` binding or `innerHTML` assignment.
  Biome and rule `unsafe-html`.
- **No frontend secrets.** Everything `VITE_*`, `NEXT_PUBLIC_*` or `NUXT_PUBLIC_*` is public. Rule
  `public-secret` scans source and `.env*` files.
- **Permissions, never roles**, and display only. Routes declare a permission in `routes.tsx`, deny
  by default, with `public` written out, and the menu is built from the same table. `<Can>` and
  `useCan` decide page-level controls; per-record actions come from the API's `allowed_actions`.
  Every check also exists on the server, and the gap report says so. Rule `role-check`; tests per
  role in the page tests. Details in [dashboard-patterns.md](../../mockup/references/dashboard-patterns.md).
- **Headers**: `Content-Security-Policy` without `unsafe-inline`, `X-Content-Type-Options`,
  `Referrer-Policy`, `Strict-Transport-Security`, kept in one file, `security-headers.json`:
  `vite.config.ts` reads it for `vite preview`, so the built app is checked under them before
  deploy; production sets the same at the server or CDN, and `headers.mjs --check` proves the
  served app does ([production-bar.md](production-bar.md)).
  `connect-src` adds the telemetry collector's origin. `quality-check` fails on any CSP violation.
- **Error copy is ours.** `ErrorState` never shows a server or exception message. Tested.
- **Sign-in and MFA** (the auth-mfa module): the session cookie is set by the app's own API, never
  by script; codes are `one-time-code` fields; a step-up comes from the server's
  `401 step_up_required`, never from a client rule; recovery codes are shown once. Third-party
  scripts such as driver.js (tours-help) are bundled, never loaded from a CDN, and render only our
  static copy. Rules and gaps in [modules.md](../../mockup/references/modules.md).

## Error reporting and telemetry

**Proposed for keel**, as the browser half of `observability.md`, which today describes services.

- OpenTelemetry, exporting OTLP to the project's backend (SigNoz by default). No vendor SDK in
  application code. `lib/telemetry.ts`.
- **Off unless `VITE_OTEL_EXPORTER_OTLP_ENDPOINT` is set**, and loaded by dynamic import only then,
  so development sends nothing and a build without it carries none of the SDK.
- **Errors are reported once, at the boundary that handled them**: the React error boundary, the
  query and mutation caches, and the window `error` and `unhandledrejection` events. Never log and
  rethrow.
- **Each record carries** `op` (the failing operation, stable), `remediation` (the keel skill to
  start with, per `observability.md`), `actor` (user id, never a name, phone or email),
  `request_id` from the error envelope, `url.path`, the exception type, and `service.name` and
  environment on the resource.
- **Redaction at the boundary**, in one function: query strings, digit runs of seven or more (phone
  and account numbers, last four kept), and anything shaped like a token. Applied to messages,
  stacks and span URLs. Tested in `telemetry.test.ts`, which the app writes
  ([an example](stacks/react-vite-patterns.md#the-http-and-telemetry-tests)).
- **Fetch spans propagate `traceparent` to our own origin only**, so a browser error joins the
  backend trace and no third party receives the header.

## Resilience

- Every request has a timeout (10 seconds in `apiFetch`) combined with the caller's abort signal.
- Reads retry only what can succeed on retry (5xx, network, timeout), at most three attempts, with
  exponential backoff and full jitter, and only in the query client: never a second retry layer.
- Writes never retry automatically. A write that must not happen twice (a payment, a booking, an
  order, an invitation) carries an `Idempotency-Key` generated once per user intent and reused on a
  manual retry.
- A page that fails to render shows our error page inside the layout, with the reference it was
  reported under (`ErrorBoundary`). `503 maintenance` from any request replaces the app with the
  maintenance page, which retries each minute and is not reported as an error. Offline is a banner,
  not a failure. All three are the system-pages module ([modules.md](../../mockup/references/modules.md)).
- An idle session is warned before it ends and lands on a page that says why
  (session-password module). A session the server ends mid-use does the same. "Stay signed in"
  pings or refetches the server, or a shorter server idle timeout still ends the session. Sign-out
  calls the server before navigating, even when the mockup's control is a plain link. A successful
  sign-in invalidates the current-user query before navigating; a session-ending 401 removes it.
- **No failure is silent.** Every mutation has an `onError` that shows our copy where the user is
  looking (a field error, a notice, a failed export), and a guarded action (`useStepUpGuard`) never
  rejects into nothing. A wrong password and a server failure get different copy: only a 401 is
  the user's mistake.
- **Status messages are announced** through one polite live region (`lib/announce.tsx`):
  `<Notice announce>` (the `Notice` composite of the proving repository's `examples/paydesk-react/`;
  its mockup twin is not in the starter but in the modules, `templates/modules/system-pages/components/Notice.js`)
  for a message that appears after an action, `announce()` for one whose
  visible text may not change (a second "Saved."). A region inserted already holding its text is
  often not read.

## Dashboards, reports, search and roles

Skeletons, the command palette, report tables and exports, stat tiles and charts, role-aware UI and
error pages: [dashboard-patterns.md](../../mockup/references/dashboard-patterns.md). Sign-in and MFA, page tours and the
help centre, and the checklist of features clients forget: [modules.md](../../mockup/references/modules.md).

## API integration

Contract first, client generated: [api-integration.md](api-integration.md).

## Money and time

- Where the app shows money, amounts are integer minor units with their currency, as in the contract. `formatMoney` divides by
  the currency's ISO 4217 exponent, taken from `Intl`; display only, never arithmetic.
- Instants are RFC 3339 in UTC on the wire and rendered in the viewer's zone. A business date (a
  value date, a settlement date) is a date, not an instant, and is rendered without conversion.
- The visual diff pins `timezoneId` from `mockup.config.json` so a screenshot does not depend on
  where it was taken.

## Writing

- No em or en dash anywhere: UI copy, comments, docs. Held by `check-frontend` and `quality-check`
  rule `dash`, and in the mockup by the inventory.
- A `TODO` carries an owner and a ticket. In a converted app the ticket is the gap report entry.

## Tooling and dependencies

- Biome for lint and format (`biome ci` is the check-only command), Vitest for tests,
  `tsc -p .` for types (for Vue, `vue-tsc -p` per tsconfig, see `stacks/vue.md`): keel's
  `tool-choices.md` picks for TypeScript. **Prove each check catches a planted failure** when you
  wire it (a type error, an inline style, a raw colour): a check that runs green may be checking
  nothing.
- **Test timeouts stay at the defaults** unless a stated reason in a comment says otherwise (a
  heavy component library's first compile). Preload a slow route module instead. A test that fails
  in the full run and passes alone is load; one that fails alone is real; report both.
- **Versions: the newest release at least 14 days old**, pinned exactly, lockfile committed, CI
  installs with `npm ci`. The scaffold's `.npmrc` (`min-release-age=14`) keeps npm to that when it <!-- supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read -->
  resolves, but `npm ci` installs a locked version however young, so `scripts/release-age.mjs`
  checks the lockfile at each update, and `scripts/check-lock.mjs` checks its sources, hashes,
  pins and install scripts (`DEPENDENCIES.md`). A security fix is the exception and may be newer;
  say so in the PR. So is a peer that the newest release breaks: pin the newest compatible one and
  say why (TypeScript 7 and vue-tsc 3.3, in `stacks/vue.md`).
- **Node 24 from 24.18.0 or 26 from 26.13.0, and npm 11.16 or later,** held by `engines` with
  `engine-strict`. npm 11.16 is the first with `strict-allow-scripts`; npm 10.9 fails to resolve
  Vitest 5's optional peers ("Cannot read properties of null (reading 'edgesOut')").
- `npm audit --audit-level=high` gates CI. A vulnerable transitive build tool is fixed with a scoped
  `overrides` entry (the scaffold's `package.json` pins `undici` under Orval's parser), never by dropping the gate.
- Install scripts are denied unless needed (`allowScripts` in `package.json`), and
  `strict-allow-scripts=true` in `.npmrc` fails the install on one nobody reviewed. The scaffold <!-- supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read -->
  denies esbuild's and fsevents' (prebuilt binaries arrive as optional packages; Vite 8 does not
  use esbuild) and, on Vue, vue-demi's; the proven apps build and test with them denied. Not
  `ignore-scripts`: it also skips the app's own `prebuild`, which generates the client.

## Gotchas on every stack

Found on the React example and true of Vue and Next.js too; each stack file adds its own.

- **MSW 3** replaced 2.x's `onUnhandledRequest` with `onUnhandledFrame` (a frame is a request or a
  WebSocket connection no handler matched): `'bypass'`, `'warn'` (the default), `'error'`, or a
  callback `({ frame, defaults })`. It is one shared option with two call sites: in the browser,
  `setupWorker(...handlers).start({ onUnhandledFrame: 'bypass', quiet: true })` in
  `mocks/browser.ts`, so the app's own assets and the telemetry collector pass through; in Node,
  `server.listen({ onUnhandledFrame: 'error' })` in `tests/support/setup.ts`, so a request no
  handler answers fails the test. The old name is gone from the types, so `tsc` flags it. Its Vite
  plugin emits the worker into every build unless it is only added when mocks are on.
- **OpenTelemetry**: take every package from one line; the newest of each by name mixes 2.x and
  3.x. The 3.x line (late 2026) deprecates `sdk-trace-web` and `sdk-trace-base` for
  `@opentelemetry/sdk-trace` (a `TracerProvider` with `StackContextManager`, no
  `WebTracerProvider`), and the logs API is in `@opentelemetry/api`. On 2.x, span processors go in
  the provider constructor (`spanProcessors`) and `BatchLogRecordProcessor` takes `{ exporter }`.
  `examples/paydesk-react` (in the proving repository) is on 2.x, the app scaffold on 3.x.
- **Biome**: its recommended set does not fail on unused imports or variables (turn on
  `noUnusedImports` and `noUnusedVariables` as errors). 2.6 formats YAML and markdown: exclude
  `api/` (the imported contract must stay the signed-off bytes; `import-mockup --check` fails
  otherwise) and `docs/` (the records) from `files.includes`, beside the generated folders.
  Orval's output is formatted by Biome, not Prettier (`formatter: 'biome'`), and its folder linted
  off by an override rather than excluded ([api-integration.md](api-integration.md), Orval
  configuration).
- **Zod 4 probes `new Function` when a schema is built**, which `script-src 'self'` blocks. Set
  `z.config({ jitless: true })` in a module imported before any schema (in `mocks/handlers.ts`,
  first), and check the bundle keeps it first: the bundler moved it after the schemas once.
- **`Intl` output** uses a no-break space and locale symbols (`US$0.05`; before `€` in French).
  Compare formatted values after normalising whitespace or against the formatter's own output,
  never a typed space.
- **Keep `undici` on the major Node bundles** (7.x for Node 24). The newest release at least 14
  days old was 8.x, which broke every mocked request in the test setup (`invalid onRequestStart
  method`).
- **On Node 24, held requests make later ones escape the mock API.** MSW 3 intercepts at the
  socket and matches each connection to its `fetch` through Node's async context. With the
  undici bundled in Node 24, a connection reused, or opened from a queue behind requests that
  `?state=loading` holds open, can lose that match: later requests in the same test file go to
  the real network and fail with `ECONNREFUSED`, so a loading-state test sees an error instead
  (8 runs in 8 on 24, none on 22 or 25). `tests/support/setup.ts` gives each test a new connection
  pool that never reuses a connection (`undici` as a pinned dev dependency) and releases every held
  request after each test (`releaseHeldRequests`); either alone still failed 2 or 3 runs in 20
  ([the code](stacks/react-vite-patterns.md#test-setup)).
  Run the suite on every Node version the team uses.
- **jsdom has no modal dialogs and no `matchMedia`.** The test setup stands in for `showModal()`
  (open, focus the first control) and Escape (a cancelable `cancel`), and stubs `matchMedia` as a
  phone-sized, reduced-motion browser ([the code](stacks/react-vite-patterns.md#test-setup)); the real behaviour is
  checked in Chromium by the visual diff and the quality check. jsdom also gives a `td` in a
  `role="grid"` table the role `cell`, where Chromium says `gridcell`.
- **Test isolation.** Mock state, module-level stores (maintenance, session ended) and the preview
  role outlive a test unless `afterEach` rebuilds the handlers and resets each store. Render with
  the app's own query client, retries off, so its error handling is under test too
  ([`renderApp`](stacks/react-vite-patterns.md#rendering-the-app-in-a-test)).
- **Unmounted routes have nothing to refetch.** While the maintenance page replaces the routes,
  `refetchQueries` finds no active query, so the check calls the generated `getSession()` itself.
- **A status message exists twice: on screen, and in the live region**, repeated for screen
  readers 50ms later, so a text query finds one or two elements depending on timing. Set Testing
  Library's `defaultIgnore` to skip the announcer; tests of what is announced query it by test id.
- **Testing Library**: a `<select>` is also a combobox (query the palette input by its name), and it
  computes names without CSS. Playwright names a visually hidden span with a space before it
  ("Mark as read : Title"), so a control whose name extends its visible label uses `aria-label`
  (still starting with the visible text, for WCAG 2.5.3) rather than a hidden span.
- **The mock API is the server's stand-in**, so its rules may name a role (keep the last
  administrator); `check-frontend` skips `role-check` under `mocks/` and nowhere else.
- **Make tests prove they can fail.** The React sweep caught three fixes that tests passed without:
  an export failure test that asserted nothing visible, and two stores reset by luck. Break the
  fix, run the test, put it back.
