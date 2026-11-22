# The production bar

The frontend bar (Convert Step 7: typecheck, lint, tests, audit, the visual diff and the quality
check on a mocked production build under its headers) proves the port. It does not prove the app can
go live: a mocked build never met a server, its headers live only in `vite preview`, nothing bounds
its size, and its gaps may have no owner. This is the second bar, checked after the first, before
Step 8's report. Its six items: **headers**, **performance**, **staging** (after a **contract
diff**), **gaps** owned and dated, the **security audit**, and the **deploy** (or its handoff).

**Status.** Met on React, Vue and Next.js example apps against the sample backend, on a Tailwind
port (`tailwind-vue`, the utility-CSS route), and locally with the API on another origin of the
same site (for an app with no sign-in screen too, on Vue); and sign-in through a real identity provider (a local Keycloak over OpenID Connect,
`staging-flows.oidc.json`); not proven: a js-kit port against a backend, a real staging backend, the
organisation's own provider, a deploy, or a cross-site API. The record is in the README's test log.

**The engine checks; keel does the work.** `security-audit` audits, `setup-deployment` owns CI,
environments and the deploy. The engine never writes their records for them: a bar met with a
hand-written audit or runbook is not met.

## What is checked

`node S/production-bar.mjs <app>` reads the records below (under the app's
`<docs_root>/production/`) and prints `ok:` or `not met:` per item, then `production bar: met` or
`not met, N` (`--env NAME=value` fills `{origin:VAR}` placeholders for `--url`):

| Item | Met when | Written by |
|---|---|---|
| headers | `security-headers.json` holds the minimum set (a CSP without `'unsafe-inline'`, `X-Content-Type-Options: nosniff`, a `Referrer-Policy`, `Strict-Transport-Security` with `max-age` above 0) and the served app sends every header in it (the record is of the current file; or `--url` checks now) | `headers.mjs --check <url> --record` |
| performance | the production build is within `perf-budget.json`, and the record is of the current build; a record with initial JS 0 or `vitals: []` is not met | `perf-budget.mjs --record` |
| staging | every flow passed, after a drift check with no breaking change, on the app's current contract and build (a record for another build is not met; one with no `build` is a note, "unbound") | `staging-run.mjs --record` |
| gaps | every row of Blocking go-live and of Server-side enforcement has an owner and a date, and each owned table has a row or `None` on its own line under its heading ([gap-report-template.md](gap-report-template.md)) | Step 8 |
| security | the latest keel `security-audit` report, `<docs_root>/audits/YYYY-MM-DD-security.md`, has its Findings row and every critical and high finding closed (one listed as a gap is still open) | keel `security-audit` |
| deploy | a CI definition with a deploy job or step (a bare lint workflow does not count), keel `setup-deployment`'s `<docs_root>/runbooks/deploy.md`, or a recorded handoff `<docs_root>/production/deploy-handoff.md` (build command, environment variables, headers, health check); the runbook or handoff needs a body under each section | keel `setup-deployment`, or the handoff written for it |

## Headers: one source

The app keeps its headers in `security-headers.json`, `{ "headers": { "<Name>": "<value>" |
["<part>", ...] } }` (a list is joined with `; `, for a CSP's directives), starting from the app
scaffold's (`templates/app-scaffold/<stack>/`). `vite.config.ts` reads it for `vite preview`
(`next.config.ts` and `proxy.ts` on Next.js), the server or CDN sets the same values, and the check
compares a served URL with it.
Two placeholders: `{origin:VAR}`, the origin of the URL in that variable or nothing (the telemetry
collector in `connect-src`), and `{nonce}`, a fresh nonce per response.

- `node S/headers.mjs security-headers.json --emit nginx` prints an nginx fragment for a static
  host. It refuses a `{nonce}` policy: a static host cannot write a fresh nonce per response, so a
  CSS-in-JS kit needs an app server or an edge function in front of its HTML
  ([stacks/react-vite.md](stacks/react-vite.md)). Other targets are `setup-deployment`'s.
- `node S/headers.mjs security-headers.json --check <url> --record <docs>/production/headers.json`
  passes only on a 2xx answer with every header matching (a nonce: any fresh value of at least 16
  characters, the same within one response; with `{nonce}` it fetches twice and fails a nonce that
  repeats). `--record` applies to `--check` only. A page behind sign-in (a backend for frontend
  redirects a page load with no session) is checked with `--session <file>`, the signed-in session
  `staging-run.mjs --save-session` kept: its cookies for the URL are sent, and a file with none for
  it exits 2.
- Either mode exits 2 when it cannot run: a file that names no header (an empty set checks
  nothing), and for `--check` a URL it cannot reach. Exit 1 is a mismatch, a non-2xx answer or a
  refused emit.

## Performance budget

`perf-budget.json` in the app (a skeleton in the app scaffold), `{ "bundle": { "initialJsKb", "initialCssKb", "lazyChunkKb" },
"vitals": { "lcpMs", "cls", "gate" } }`, in KB of gzip; `bundle.initialJsKb` is required. A file
`index.html` names that is not under `dist`, no initial JS, `--runs` not a positive integer, or no
screen selected with `--url` exits 2: nothing measured is not within budget. So does a flag that
does not apply: `--dist` with `--next`, or `--mockup`, `--route`, `--runs` or `--session` without
`--url`.

```bash
npm run build      # the production build: never the mocked one, which carries the mock worker and fixtures
node S/perf-budget.mjs --budget perf-budget.json --dist dist --record docs/production/perf.json \
  [--url <served app> --mockup <mockup> --route '<regex>' --session <file>]
```

A Next.js build has no `index.html`: `--next .next --url <served app> --mockup <mockup> --session <file>`
fetches each selected route signed in and counts what its HTML names, the largest route's as the
initial load ([stacks/nextjs.md](stacks/nextjs.md#budget) for the runtime's own floor). Either
mode fails a route that ends on another page (a sign-in), instead of measuring that page.

The bundle is the gate: the initial load (what `dist/index.html` names and those scripts import
statically) and each lazy chunk. Vitals (LCP and CLS, at the mockup's narrowest viewport, CPU slowed
4 times, the median of three loads) move with the machine's load: set budgets with headroom, and
they warn unless `"gate": true`. Measure them on the real build behind a backend (the staging
server), signed in with the session `staging-run.mjs --save-session` keeps. Set the scaffold's
numbers from the first real build, with headroom, and tighten for the client's devices.

## Before any run against a backend: the contract

```bash
node S/contract-diff.mjs api/openapi.yaml <the backend's live document: file or URL>
```

Both documents must be OpenAPI 3.x with paths (else exit 2). The diff covers each operation's
parameters, request body, response codes and their schemas, by direction: breaking changes for a
frontend built on the signed-off contract (an operation, schema or property removed, a type
changed, a field newly required in a request or no longer required in a response, an enum value
removed from a request) come first and exit 1; additive ones after (a new enum value is additive,
and the UI must show a value it does not know).
A breaking change is a contract change: agree it, regenerate, sign it off as a new round
([signoff.md](../../mockup/references/signoff.md)). Telling drift apart from app bugs is the point: a staging failure on a
drifted contract says nothing about the app.

## The staging run

The production build, served the way it will be, against a backend, once: sign in, then one read
and one write per area.

```bash
node S/staging-run.mjs --url <served app> --flows staging-flows.json --contract api/openapi.yaml \
  --live-contract <the backend's document> --build dist/index.html [--stub | --sample] \
  [--api <the API's origin>] --record docs/production/staging.json
```

`--build` (`.next/BUILD_ID` for Next.js) records the served build's hash, so the bar can tell a run
of an older build.

With the API on another origin of the same site, `--api` names it: the reset and the stats go
there, and its answers are checked like the app's own
([api-integration.md](api-integration.md), "Another origin (same site)").

`staging-flows.json` in the app (a skeleton in `templates/app-scaffold/shared/`) lists the flows,
run in order in one browser session, with the config's step forms (`fill`, `click`, ...) and what each must show: a path, a text, a request with a
2xx answer, and the statuses it expects (`allowStatus: [401]` for the first load before sign-in).
One file per backend or shape, named `staging-flows.<kind>.json` (`staging-flows.sample.json` for the
sample backend's sign-in, `staging-flows.cross-origin.json` for an API on another origin), with
plain `staging-flows.json` for the stub or the real backend.
Each flow asserts at least one of path, text, request, else the run exits 2. A
flow fails on any other 400 or more, a console error, a CSP violation, or a request for the mock
service worker. **Writes must repeat**: choose a toggle, or reset the data first (a stub's
`POST /__stub/reset`, which `--stub` calls).

**Before the real backend: the sample backend, by default.** Until a staging backend exists, Convert writes one and records the staging run against it: a server written from the contract alone
(`templates/sample-backend`, [sample-backend.md](sample-backend.md)), on Postgres, run as a local
container stack with a mail catcher: every request and response validated against the contract,
sessions, CSRF and permissions enforced on its side, one transaction per request, the production
build served same origin with the headers file. `--sample` resets it, reads its stats and fails the
run on any request or response outside the contract. It proves the frontend against an independent
backend, which a stub cannot (a stub runs the app's own mocks, so the two never disagree). The run
is recorded as `sample`, and the run against the real backend stays a blocking gap.

**A stub proves the frontend's half.** The example's `scripts/stub-staging.mjs` serves the production
build with the headers file, and answers the API same origin from the app's mock handlers run on the
server, behind a real `HttpOnly` session cookie set at sign-in and enforced double-submit CSRF. It
caught a frontend that stopped sending the CSRF header (the writes answered 403). Bind a stub to `127.0.0.1` with no dev websocket: the example's
gives every session the admin role and an unauthenticated reset, which the audit rightly flagged
while it listened on every interface. It cannot prove
the server's enforcement, its data or its identity provider: a run against a stub is recorded as
`stub`, the bar notes it, and the run against the real staging backend stays a blocking gap with an
owner and a date. Server-side enforcement rows stay `assumed` until the backend confirms them.

**A backend on another origin of the same site** (`app.example.com` and `api.example.com`) needs
CORS with credentials for the app's exact origin and the CSRF token repeated in a response header;
its cookies stay `SameSite=Lax; Secure`. Proven locally with PayDesk
([api-integration.md](api-integration.md), "Another origin (same site)"). The engine's default (a
backend for frontend on the same origin) needs neither. A cross-site API (another registrable
domain) would need `SameSite=None` cookies, which browsers block as third-party: not supported.

## Security audit and deploy

- Run keel `security-audit` on the app before the report. The bar reads the latest report's
  Findings row and requires every critical and high finding closed, even one listed as a gap;
  lower ones are closed or listed as blocking gaps with owners.
- Hand CI, environments and the deploy to keel `setup-deployment`. Until it runs, record the handoff
  in `<docs_root>/production/deploy-handoff.md` with four sections: **Build command** (and which
  build: never the mocked one), **Environment variables** (each build-time and server variable with
  its default, and the mocks switch unset everywhere), **Headers** (the file, how the host or the
  app's server sets it, the check after a deploy), **Health check** (what answers 200, caching of
  `index.html` against hashed assets). The commands and variables are the stack file's Done when.
  Ask the user before running `setup-deployment`: it changes CI and infrastructure.
