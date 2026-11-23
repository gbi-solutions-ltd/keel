# API integration: contract first, client generated

Read this at the contract step of a conversion, and whenever the API changes. `orval.config.ts` and
`src/api/http.ts` come from the app scaffold (`templates/app-scaffold/<stack>/`); this file says why
they are as they are. The worked example is `examples/paydesk-react/` (in the proving repository) (`api/openapi.yaml`,
`src/mocks/handlers.ts`).

keel's `api-contracts.md` rule is that the schema is generated from the code or the code from the
schema, never maintained alongside it. A converted frontend is on the second side of that rule: an
OpenAPI document is the source, and Orval generates the client, the query hooks, the mock handlers
and the runtime validators from it. Nobody writes a fetch call or a response type by hand.

## Where the contract comes from

| Situation | Contract | Who owns it |
|---|---|---|
| The backend exists and publishes OpenAPI | Theirs, fetched or vendored into `api/openapi.yaml` | Backend |
| The backend is being built alongside | A draft written from the mockup, then agreed | Proposed by us, owned by backend once agreed |
| No backend yet | The draft is the specification the backend is built to | Same |

**A vendored contract wins.** The rules under "Drafting from the mockup" are defaults for a contract
we write. A backend's own contract may differ on purpose: `403 step_up_required` instead of `401`,
an Origin check instead of a CSRF token, RFC 9457 `problem+json` errors, `page` and `pageSize`
paging, money as a decimal string. Follow it. The mutator then parses that error shape (a request id
from an `X-Request-ID` header, a Blob for a non-JSON success), money is formatted from the string and
never through `parseFloat`, and each departure from these defaults is a row in the conversion plan.

**Drafting from the mockup.** Each `needs.api` line becomes an operation; each fixture entity
becomes a schema, with its JSDoc `@typedef` giving the enums. Apply keel's `api-contracts.md` while
drafting, because the draft becomes the real contract more often than not:

- Path versioning, `/v1/...`.
- Every collection is cursor paginated from the first version (`next_cursor`, a capped `limit`).
- Errors use the keel envelope, `{ error: { code, message, request_id, details } }`, as one
  `default` response on every operation. Callers branch on `code`.
- The app scaffold's held files import from the generated client by name, so the draft gives
  them those names: the envelope's schema is `ErrorEnvelope`; every operation has a tag (Orval
  splits the client by tag); `getSession` is tagged `session` and returns `Session` with
  `user_id` and a required `permissions` array of a `Permission` enum. A draft without them fails
  the port's first typecheck and needs a new sign-off round.
- Money, where there is any, is an integer `amount` in minor units plus a `currency`; instants are
  `format: date-time`.
- A write that must not happen twice takes an `Idempotency-Key`, one per intent: the same details
  retried reuse the key; changed details get a new one. The mock API replays the first answer for
  a reused key and refuses one reused with a different body (`422 idempotency_key_reused`). With
  Orval, pass the header per call through the generated function in `useMutation`; a hook's
  request options are fixed when the hook is created.
- Authentication is a cookie security scheme, served by the app's own API (a backend for frontend)
  whatever identity provider sits behind it, so the browser never holds a token. A step-up is asked
  for with `401 step_up_required` and handled by one generic guard. Permissions are data
  (`Session.permissions`), never roles. The auth-mfa module's operations are in
  [modules.md](../../mockup/references/modules.md).
- Anything the mockup did not design is still drafted, marked `x-mockup-status: not-designed`, and
  listed in the gap report, so the generated client has a function for it and nobody invents one.
- A record the user can act on carries `allowed_actions`, computed by the server; the session
  carries the role and its permissions. The UI never recomputes either.
- Reports take filters, a `sort` enum (`-created_at`, `amount`), a cursor and a capped `limit`.
  Exports are `POST /v1/exports` returning `202` with an id, then `GET /v1/exports/{id}` until
  `ready` with a `download_url`. Per-user settings are `GET` and `PUT /v1/preferences/{key}`.
  Search is `GET /v1/search?q=` with a minimum length, returning only what the user may see.

The example's contract (`examples/paydesk-react/api/openapi.yaml` (in the proving repository), `0.2.0-draft`) has all of
these and is a reasonable starting point for a dashboard app.

Mark the document's `info.version` as a draft (`0.1.0-draft`) until the backend agrees it.

**When.** The draft is written at sign-off ([signoff.md](../../mockup/references/signoff.md)), not at Convert: every input
exists by then, and the backend can start building to it while the port is planned. Mark each entity
schema the mockup's data stands for with `x-mockup-fixture: <fixture key>` (`roles.*` for every value
of a map): `signoff.mjs` and the readiness gate check those fixtures against it without an app. A
response assembled from several fixtures is left to the app's contract test below.

**Check the mockup against the contract.** The example's `tests/mocks/fixtures.test.ts` parses every
fixture with the generated Zod schemas. A fixture that fails means the mockup and the contract
disagree; fix whichever is wrong and say which in the gap report.

**When the contract is fixed and the fixtures predate it**, keep the mockup unchanged and add an
adapter layer, `src/mocks/adapt/`: one transform per operation from the mockup's fixture shape to
the contract's, each tested against the generated Zod schema. Responses the mockup's page computed
in the browser are built in the handlers. Sort the mismatches into two kinds:

- **Invisible** (field names, money format, id format, enum codes): the adapter absorbs them.
- **Visible** (a longer number pattern, a count the contract does not serve, a different list
  order): an expected-diffs entry with its reason, or a question for the user.

Decide list order once per port: the contract's documented order (newest first, say), with an
expected-diffs entry and a backend ask where the fixtures were hand ordered. Mixing fixture order on
some lists and contract order on others leaves two rules to explain.

## Orval configuration

Two outputs from one document, generated into `src/api/generated/`, which is gitignored and never
edited. `predev`, `prebuild`, `pretypecheck` and `pretest` regenerate it, so a stale client cannot
pass the build.

```ts
// orval.config.ts
export default defineConfig({
  client: {
    input: { target: './api/openapi.yaml' },
    output: {
      target: './src/api/generated/endpoints.ts',
      schemas: './src/api/generated/model',
      mode: 'tags-split',
      client: 'react-query',            // 'vue-query' for Vue; 'fetch' for Next.js server code
      httpClient: 'fetch',
      override: {
        mutator: { path: './src/api/http.ts', name: 'apiFetch' },
        fetch: { includeHttpResponseReturnType: false },  // hooks return the body, not an envelope
        // query: { version: 5 },          // needed for 'vue-query' (TanStack Query 5, zod 4)
      },
      mock: { generators: [{ type: 'msw', delay: false }] },  // drop when the app writes its own handlers
      clean: true,
      formatter: 'biome',               // formatted with the app's own Biome (below)
    },
  },
  zod: {
    input: { target: './api/openapi.yaml' },
    output: { target: './src/api/generated/zod.ts', client: 'zod', mode: 'single', formatter: 'biome' },
  },
});
```

**Generated code is formatted, not linted.** Orval writes ragged code; `formatter: 'biome'` runs the
app's Biome over it after each generation, so no second formatter (Prettier) is needed. Biome skips
whatever `files.includes` excludes, so do not exclude `src/api/generated` there (Orval's formatter
would then do nothing, and only warn): keep it in, and turn linting off for it with an override,
`"overrides": [{ "includes": ["src/api/generated/**"], "linter": { "enabled": false }, "assist":
{ "enabled": false } }]`. `biome ci` then checks it is formatted, which `npm run generate` keeps true.
This is the default on every stack (React, Vue, Next.js), not an option: Convert writes it into the
scaffold, and `check-frontend.mjs` (run by `npm run lint`) fails with `generated-format` when an
Orval output sets no formatter, `biome.json` excludes an Orval output folder, or `vcs.useIgnoreFile`
skips it through `.gitignore` (which lists it: the generated folder is never committed). In all five React
examples.

Orval's generated MSW handlers can fail a strict typecheck on a large contract. Since the app
replaces them with fixture handlers anyway (see Mocks), drop the `mock` generator then and exclude any
stale `*.msw.ts`. Tested with Orval 8.41. Generated paths have no base URL; `apiFetch` adds `VITE_API_BASE_URL`, and
the generated MSW handlers match `*/v1/...` on any origin.

## The mutator is where keel's client rules live

Every generated call goes through `src/api/http.ts`, so these are written once:

- Base URL from configuration, timeout combined with the caller's abort signal.
- `credentials: 'same-origin'` for an API on the app's origin (the default, `/api`), `'include'` only
  when `VITE_API_BASE_URL` names another origin; the session is an `HttpOnly` cookie, never a token
  in JavaScript.
- `X-CSRF-Token` on every state-changing method: the token from the server's last `X-CSRF-Token`
  response header, else the `csrf_token` cookie (an app on another origin cannot read the API's
  cookies, so the server repeats the token on every answer).
- Non-2xx responses throw `ApiError` with `status`, `code` and `requestId` from the envelope, and a
  `retryable` flag that the query client's retry policy reads. Transport failures become
  `network_error` or `timeout` with status 0.

## Mocks: the mockup's fixtures, served the way the server will serve them

Orval generates one MSW handler per operation, filled with faker data. The app replaces them with
handlers that serve the mockup's fixtures (`src/mocks/handlers.ts`) and behave like the server
will, so dev, tests and the visual diff all show exactly what the client signed off:

- **The same URL flags as the mockup.** `?state=loading` holds page data open with a `holdOpen`
  helper whose requests the test teardown releases (`releaseHeldRequests()`); a bare
  `delay('infinite')` leaks open requests between tests. The scenario applies only to the reads
  the page's `load` makes, never to the session or shell reads. `?state=error` answers 500 with an envelope, `?state=empty` returns no
  items. `?as=<role>` chooses the signed-in role, remembered for the tab because in-app links do
  not carry it. `?locale=<code>` (and `pseudo`) is honoured by the app's i18n setup in a mocked
  build, so a screen with a `locale` compares like for like.
- **Permissions enforced**: 403 with an envelope when the role lacks one, as the real server must.
  A UI test that hides a control and a mock that refuses the call cover both halves.
- **`allowed_actions` filtered by the role**, from `fixtures.action_permissions`.
- **Server-side behaviour**: filtering, sorting and cursor paging; a 404 for an unknown id; exports
  that are pending on creation and ready on the first poll, with a file built by `toCsv` under the
  CSV rules; preferences kept in memory.
- Tests pass `getScenario` and `getRole` instead of reading the URL.
- **Effects the server will have**: when the mockup shows an approval, the mock applies its effect
  to the record, through one `afterDecision` hook each area registers with, or the screens after an
  approval cannot be tested.
- **Optimistic concurrency** where the contract has it: the mutator sends `If-Match` from the read's
  ETag; the mock answers 428 when it is missing and 412 when it is stale; the 412 copy is ours.
- **A detail route by a human number** (not an id) resolves through the list search plus an exact
  match; the page accepts the id too.
- **Planned or release-scoped endpoints** (the contract marks them planned, or refuses them in this
  release): the mock keeps the mockup's success flow, production shows the contract's refusal in our
  copy, and each is a gap of the highest impact.
- **A mock rule that stands in for a missing contract field** (tab counts from one `pageSize=1` read
  per tab, an event set chosen by page path) is a gap, and its comment names the gap.

Mocks start through MSW's stable `setupWorker` API (`src/mocks/browser.ts`), only when
`import.meta.env.DEV` or `VITE_ENABLE_MOCKS` is true, in every stack. Use one
flag name throughout an app, and test it statically (`import.meta.env.X === '...'`), so the bundler
drops the mocks from a production build. MSW 3's Vite plugin serves the worker script
in `worker-only` mode and is added to the config only when mocks are on, so a production build
contains no worker, no fixtures and no faker. Check it: `grep -r "Sarah Namuli" dist` finds nothing
after `npm run build`. A `--mode mocked` build keeps the mocks, which is how the visual diff and the
quality check run against built output under real security headers.

MSW's `virtual:msw` module is not used: it is built on `msw/experimental` and is not a house default
until it is stable.

Tests reuse the same handlers in Node (`tests/support/setup.ts`) with a scenario the test sets, so a
test exercises the real generated client, the real mutator and the real fixtures.

## Handing contract gaps to the backend

Collect gaps as you go (each wave's notes keep a "Contract gaps" section), then write one
deduplicated `contract-gaps.md` for the backend team, reviewed by the user before it is shared:

- A header naming the contract file, the commit and date it was read, and "draft for internal
  review".
- **Highest impact**: items that change what the product can do, not only what it shows.
- **Across every area**: one answer closes many items (an organisation profile, lookups, the person
  behind an approval role, created-by, list counts, a read by business number).
- **By area.**
- Each item has a stable id (`HI-n`, `X-n`, `<AREA>-n`) and a "What the UI does today" column.

With it, hand the backend session a prompt that asks it to classify each item as exactly one of
Covered, Add, Decline or Product decision; to run `git log <commit read>..HEAD -- <contract>` first,
since some items may already be fixed; to prefer additive changes and flag any breaking one; to
group items that share a cause; to treat items worded "confirm" as questions; and to hand back a
table keyed by item id, with one commit per group naming the ids it closes, on a branch, not merged.

## When the API changes

1. Replace or edit `api/openapi.yaml`. If it is the backend's, take their published document.
2. `npm run generate`, then `npm run typecheck`. Every compile error is a place the change reaches;
   fix them rather than casting.
3. `npm test`. A fixture that no longer parses is a mockup fixture to update.
4. Breaking changes (keel's `api-contracts.md` table) need a version bump on the backend and a
   note in the gap report or changelog.

## When the real backend arrives

Nothing in pages or components changes: they only know the generated hooks. Keep the mocks for
tests and the visual diff. But "set the base URL" is the last step, not the first:

1. **Diff the contract first**: `contract-diff.mjs api/openapi.yaml <their live document>`. A
   breaking change is agreed and signed off as a new round before anything runs against them, so
   drift is never mistaken for an app bug.
2. **Same origin or not.** The default is a backend for frontend on the app's origin (a reverse
   proxy), so the session cookie is `SameSite=Lax` and no CORS is needed. Decide it with the
   backend; the next section is the other shape that is proven.
3. **Cookies and CSRF against the real server**: the session cookie set at sign-in is `HttpOnly`,
   the `csrf_token` cookie readable, and a write without `X-CSRF-Token` refused. The staging run
   shows the frontend's half; the server's half is the backend's to confirm.
4. **Set `VITE_API_BASE_URL`** (if not `/api`), build without mocks, and run the staging run
   ([production-bar.md](production-bar.md)).

## Another origin (same site)

Proven 2026-11-20 with PayDesk: the app at `app.paydesk.localhost:4180`, served as a static site
(`templates/static-site`, nginx with the app's headers), the API at `api.paydesk.localhost:4310`.
Those are two origins of one site, the usual production shape (`app.example.com` and
`api.example.com`). What it takes:

- **The API:** CORS with credentials for the app's exact origin only (the sample backend's
  `ALLOWED_ORIGINS`: no wildcard, path or `null`), so any other origin gets no CORS header at all.
  A preflight allows `Content-Type`, `X-CSRF-Token` and `Idempotency-Key`. `X-CSRF-Token` and
  `Retry-After` are exposed. Pre-session writes from the allowed origin (sign-in) are let through,
  and any other site's are refused. The CSRF token is repeated in an `X-CSRF-Token` header on
  every answer with a session, because the API's cookies are its own host's and the app cannot
  read them.
- **Cookies:** `SameSite=Lax` and `Secure` stay as they are. Same-site requests carry them, and no
  `SameSite=None` is needed.
- **The app:** `VITE_API_BASE_URL` set to the API's base URL at build time. `apiFetch` then sends
  `credentials: 'include'` and takes the token from the header. `security-headers.json` names the
  API in `connect-src` with `{origin:VITE_API_BASE_URL}`, which is empty for `/api`.
- **Serving:** the build on its own origin with its headers: `headers.mjs --emit nginx --env
  VITE_API_BASE_URL=...` into `templates/static-site`.
- **The staging run:** `staging-run.mjs --url <the app> --api <the API>`, with its own flows file,
  `staging-flows.cross-origin.json` (the `staging-flows.<kind>.json` convention, [production-bar.md](production-bar.md#the-staging-run)). Reset and stats go to
  the API, the API's answers are checked as the app's are, and the record's `crossOrigin` lists
  the API's cookies the app's page could read (none, in the proof).

The proof: 12/12 flows. The API set `session` and `csrf_token`, and the app could read neither.
Four writes with a session ran after full page loads (notifications read, notification settings, a
role change, sign-out), so their CSRF tokens came from the header; sign-in and its code check run
before a session and carry none. With the API's allowlist removed, the same run fails 0/12. It was
run in Chromium only. `apiFetch` uses the cookie when it can read it, so on one origin a sign-in in
another tab never leaves a stale token in use.

To run it again (PayDesk, from the root of the engine's proving repository, which holds `examples/`; any app the same way):

```bash
# the build, for the API's URL, in a git-ignored folder inside the app (next to dist/, in the
# app's .gitignore and Biome's ignores), so it outlives the session; the nginx fragment in the
# app's git-ignored .mockup-engine/, never inside the served build
(cd examples/paydesk-react && npm run generate && npx tsc -p . && \
  VITE_API_BASE_URL=http://api.paydesk.localhost:4310/api npx vite build --outDir dist-cross-origin)
mkdir -p examples/paydesk-react/.mockup-engine
node scripts/headers.mjs examples/paydesk-react/security-headers.json --emit nginx \
  --env VITE_API_BASE_URL=http://api.paydesk.localhost:4310/api > examples/paydesk-react/.mockup-engine/headers.cross-origin.conf
# the app on its own origin, then the API allowing it
(cd templates/static-site && APP_DIST=$PWD/../../examples/paydesk-react/dist-cross-origin \
  HEADERS_CONF=$PWD/../../examples/paydesk-react/.mockup-engine/headers.cross-origin.conf \
  docker compose -p mockup-engine-paydesk-web up -d --wait)
(cd examples/paydesk-api && ALLOWED_ORIGINS=http://app.paydesk.localhost:4180 \
  docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build --wait)
node scripts/staging-run.mjs --url http://app.paydesk.localhost:4180 --api http://api.paydesk.localhost:4310 \
  --flows examples/paydesk-react/staging-flows.cross-origin.json --contract examples/paydesk-react/api/openapi.yaml \
  --live-contract http://api.paydesk.localhost:4310/api/openapi.yaml \
  --build examples/paydesk-react/dist-cross-origin/index.html \
  --sample --record examples/paydesk-react/docs/production/staging-cross-origin.json
docker compose -p mockup-engine-paydesk-web down     # then the API's project, as above, with down
```

`--build` names the build nginx serves (`dist-cross-origin/index.html`), not the app's `dist/`, or
the record binds the run to a build that was never served. The API's own compose still mounts
`dist/`, so build the same-origin production build there first (`npm run build`): the API refuses
to start on a mocked build.

Not supported: an API on another *site* (`api.other.com` for `app.example.com`). Its cookies are
third-party cookies, which Safari blocks and Firefox partitions, and it would need
`SameSite=None`. Use a backend for frontend on the app's origin instead.

**An app with no sign-in screen on another origin** (proven 2026-11-22 with `equipment-loans-vue`,
the app at `app.loans.localhost:4190`, the API at `api.loans.localhost:4300`, signing in through a
local Keycloak over OpenID Connect). A static host cannot send a page load to sign in, so the app
does: a 401 before any session sends the browser to `VITE_SIGN_IN_URL` (the API's `/auth/sign-in`)
with `return_to` set to the page's own address, once per tab (`startSignIn` in
`src/lib/sessionEnd.ts`, from `SessionGate.vue`); unset, it reloads, as on one origin. The API
keeps an absolute `return_to` only when its origin is in `ALLOWED_ORIGINS` exactly (else `/`),
registers its own `/auth/callback` at the provider (`OIDC_REDIRECT_URI` on the API's host), and
serves the sign-out page there. The run: 8/8 flows (`staging-flows.cross-origin.json`: sign-in
from a page load, the reads and writes, sign-out on the API's origin, the coordinator back on the
page asked for), the API's `session` and `csrf_token` cookies unreadable by the app, every write's
CSRF token from the response header. A flow's `path` may be a URL on the API's origin, and an
expected path is met only on the origin the flow started on (the API's own copy of a page is not
the app).

## Per stack

| Stack | Orval `client` | Mocks in dev | Notes |
|---|---|---|---|
| `react-vite` | `react-query` | MSW browser worker | As above |
| `vue` | `vue-query` | MSW browser worker | Same mutator; hooks return refs |
| `nextjs` | `fetch` for server components, `react-query` for client components | in `next dev` and a mocked build, an `/api` route handler and the server's reads answer through MSW's `getResponse` with the same handlers, no network | Scenario state per visit; see [stacks/nextjs.md](stacks/nextjs.md#mocks-and-scenarios) |
