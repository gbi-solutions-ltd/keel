# The backend

The production bar's staging run needs a backend. A stub that runs the app's own mock handlers
proves only the frontend's half, and it cannot disagree with the frontend: both run the same code.
Until the client's backend exists, Convert writes one from the signed-off contract: a real server
on Postgres, in containers, which the app's production build is run against
([production-bar.md](production-bar.md), the staging run). It is the reference implementation of
the contract: the backend team can adopt it, or hold their own to the same tests and flows.

**Three kinds of backend**, and what a pass against each proves:

| Kind | What it is | A pass proves |
|---|---|---|
| Stub | the app's own mock handlers on a server | the frontend's wiring: cookies, CSRF, headers, no mock worker |
| This backend | written from the contract alone, on Postgres, in containers | the frontend against an independent implementation of the contract, both sides of the wire, with real persistence, sessions, codes and mail |
| The client's backend | their server, their data, their identity provider | that it can go live |

**Status.** Proven as a local container stack (the backend, Postgres 16, Mailpit) by
`examples/equipment-loans-api` (in the proving repository) (a backend for frontend with no sign-in screen; React, Vue and
Next.js apps against it), `examples/paydesk-api` (in the proving repository) (sign-in in two steps) and
`examples/deliveries-api` (in the proving repository) (the Tailwind port `tailwind-vue`), with the API on another origin of
the site (PayDesk, and equipment-loans' Vue twin), and with sign-in through a local Keycloak over
OpenID Connect; not proven: a real deploy, or the organisation's own provider. The counts and what each caught are in the README's test log.

## What it proves, and what it does not

It proves, against an independent server:
- every request the frontend sends is inside the contract, and every answer it relies on came from
  a server that kept to it;
- the frontend works with a session it cannot read, copies the CSRF token, and shows the server's
  refusals (401, 403, 409, 422, 429) the way the design says;
- the rules in the contract's descriptions hold when someone else implements them, on a real
  database, under concurrent requests, across a restart.

Where it still stands in for the real thing, by design or because the contract stops there (name
each in the app's gap report): figures the real system computes elsewhere are served from a seeded
table (PayDesk's dashboard summaries); a background job finishes at once (an export is ready on its
first poll) and its file is not served (no download operation); a state the backend never leaves
(a refund stays pending: no payment provider); an invitation mailed with no way to accept it.

Not built, and named in the gap report as the backend's: the organisation's own identity provider
(an app with no sign-in screen signs in through a stand-in page here, or through a local Keycloak
over OpenID Connect: [below](#sign-in-through-an-identity-provider)), a real email and SMS provider (Mailpit
catches every message; SMS goes through it too), TLS, the deploy, backups, monitoring and load. The
run against the client's staging backend stays a blocking gap with an owner and a date, and the
Server-side enforcement rows stay `assumed` until that backend confirms them. A pass here is
recorded as `sample` and the bar notes it.

## The template

`templates/sample-backend/` holds the generic part. Copy it next to the app (`<app>-api/`) and keep
the engine's files unchanged (`test/sample-backend.test.mjs` checks every example's copy):

| File | Whose | What |
|---|---|---|
| `lib/contract.mjs` | the engine's | the contract as routing table and validator; OpenAPI 3.1 schemas with Ajv's 2020-12 dialect (3.0 is refused) |
| `lib/app.mjs` | the engine's | Fastify: one transaction per request, request and response validation, sessions, CSRF, idempotency, mail, `/healthz`, the static build with the app's headers |
| `lib/db.mjs`, `lib/migrations/` | the engine's | the pool (a schema per backend or per test), the migrations runner, the sessions and idempotency tables |
| `lib/testing.mjs` | the engine's | a backend under test on its own schema, seeded, dropped after; its mail kept in an array |
| `server.mjs`, `Dockerfile`, `.dockerignore`, `docker-compose.yml` | the engine's | the command line and the container stack |
| `docker-compose.dev.yml`, `docker-compose.api-only.yml` | the engine's | the local staging override (dev routes, seed) and the override for an app with its own server (no build served) |
| `test/template.test.mjs` | the engine's | the template's own parts on a contract and tables of its own |
| `lib/oidc.mjs`, `test/oidc.test.mjs` | the engine's | sign-in over OpenID Connect, and its checks against a provider run in the test |
| `backend.config.mjs`, `migrations/`, `handlers.mjs`, `seed/`, the rest of `test/`, `.env.example` | the app's | the tables, the rules, the seed, the tests, the ports |

Dependencies are pinned to exact versions in a committed lockfile (Fastify 5, Ajv 8, `pg` 8,
nodemailer 10, openid-client 6), and images by tag and digest (`postgres:16.15-alpine`, `axllent/mailpit:v1.27`,
`node:24.20-alpine`). Security review: the engine's backends audit of 2026-11-20 (kept with the engine's proving
repository), every finding fixed with a test.

### What every backend gets from the template

- **One transaction per request.** Committed when the answer is below 500, so a refusal keeps what
  it recorded (a counted attempt, an audit row: roll those back and a lockout never fires); rolled
  back on a 5xx, a contract violation or a crash. The idempotency row is written in the same
  transaction. A handler that writes, then may refuse, and must not keep the write wraps that part
  in `ctx.savepoint(fn)` (opt in): a throw inside it undoes its writes and queued mail, and the
  request's transaction goes on.
- **The contract both ways.** 400 `invalid_request` before the handler, 500 `contract_violation`
  after it, both counted. A schema key that is no JSON Schema or OpenAPI keyword (a typo such as
  `minLenght`) refuses the contract at load; a key that is the rest of a description cut at a comma
  in a YAML flow mapping only warns.
- **The static build**: only the hashed files under `/assets/` are cached as `immutable`; root files
  (`favicon.ico`, `robots.txt`) and `index.html` are `no-cache`, and a missing hashed asset is a
  404, never the app's page. Fonts, images, `.map`, `.wasm` and the other web types get their MIME
  type. `{origin:VAR}` in the headers file is filled from the server's environment (`.env.api` in
  the container), and a `{nonce}` policy is refused: a static build cannot carry a per-response
  nonce, so that app is served from its own server (`docker-compose.api-only.yml`).
- **Sessions in the database**, stored by the hash of a random token, in an `HttpOnly`,
  `SameSite=Lax` cookie named by the contract's cookie security scheme (`Secure` with
  `SECURE_COOKIES=1`), with an idle and an absolute lifetime and a fresh token at every sign-in.
- **Permissions read on every request** (`permissionsOf(user, db)`), so a role change reaches open
  sessions at once.
- **CSRF**: with a session, the `X-CSRF-Token` header must match the token bound to that session
  (its hash on the session row). Without a session, a write from another site (Origin,
  Sec-Fetch-Site) is refused. Request bodies are JSON only, so a cross-site form cannot send one.
  The token is derived one way from the session token, so the server can give it again: it goes
  out as the `csrf_token` cookie at sign-in, and as an `X-CSRF-Token` header on every answer with a
  session.
- **Another origin**: `ALLOWED_ORIGINS` (exact origins, comma-separated) turns on CORS with
  credentials for those origins only, and lets their pre-session writes through. When it is unset,
  no CORS header is sent at all. The shape and its proof are in
  [api-integration.md](api-integration.md), "Another origin (same site)".
- **Least privilege**: `lib/db-roles.sh` creates `backend_owner` (owns the schema, runs migrations,
  `MIGRATE_DATABASE_URL`) and `backend_app` (the server, `DATABASE_URL`, granted DML only; the
  app's `migrations/grants.sql` takes more away, such as `UPDATE` and `DELETE` on an audit log).
  The schema is `app` (`DB_SCHEMA`), never `public`.
- **Fails closed**: cookies are `Secure` unless `SECURE_COOKIES=0`; `--reset` needs `--dev`; a
  build is never served without its headers file; a statement may run 10 s and a transaction sit
  idle 15 s; mail goes out only after the commit; invalid requests keep at most 20 problems.
- **Idempotency keys** cover the path, the query and the body, and are held under a lock while the
  first request runs.
- **Migrations in their own service**: compose runs `node server.mjs --migrate-only` once, as the
  owner, then starts the server with the application's role only (`MIGRATIONS=external`); only the
  dev override gives the server the owner's URL, for its reset. Outside dev the server closes any
  owner connection after migrating. The roles script runs only on an empty data directory: on an
  existing volume, `docker compose down -v` first (it drops the data), or create the roles by hand.
- **Behind a proxy, `TRUST_PROXY`** (the number of proxies in front): without it every request
  comes from the proxy's address, so per-client limits stay off and the audit's addresses are the
  proxy's.
- **Secrets for the container only** go in `.env.api` (never committed), which compose passes to
  the backend alone: the superuser's password never reaches it.

## Writing it

1. **The contract, byte for byte**: `node S/import-mockup.mjs --mockup <mockup> --app <backend>
   --only contract` (the backend folder must exist). A port from before sign-off records (its mockup holds no contract) copies the
   app's and says so in `api/contract-source.json` (`copiedFrom` and the reason).
2. **The seed**: a byte copy of the mockup's `data/fixtures.js` in `seed/fixtures.js`, with
   `seed/source.json` naming the source (the image must hold it). Only data comes from the mockup.
   Hash seeded secrets as you insert them. Derive what the server computes (availability,
   `allowed_actions`) instead of copying the fixture's values; then test that the derived values
   match the fixtures, which checks the rules against the design.
3. **The tables** (`migrations/0001_<app>.sql`): let the database hold the rules it can. An
   exclusion constraint for "no two bookings share a day", a unique index for "one account per
   address", a trigger for "the audit log is append-only", sequences for numbers (never max + 1).
4. **The handlers, from each operation's description, never from the app's mock handlers.**
   `ctx.db.query` and `ctx.db.one` run in the request's transaction; `await ctx.need(permission)`;
   `ctx.fail(status, code, message, details, headers)`; `ctx.mark` for a session's own marks (a
   step-up); `ctx.endSessions(userId)` to sign someone out everywhere; `ctx.sendMail`. Pass
   `ctx.now()` into SQL, never `now()`, so a pinned clock holds. Lock what a rule reads before it
   writes (`FOR UPDATE`), or two requests both pass it.
5. **Secrets for real.** Passwords with scrypt; authenticator codes checked against the user's
   secret (RFC 6238); codes by email random, hashed, single use, sent over SMTP; reset tokens and
   recovery codes hashed.
6. **Tests on the server's own rules** (`lib/testing.mjs`, a schema each, `TEST_DATABASE_URL`): no
   session 401; each role 403 where it lacks the permission; CSRF; every conflict and transition;
   the contract refusing a malformed request; a planted response outside the contract rolled back;
   two racing requests where a rule must let one through; a restart keeping the data. Plant each
   rule's removal once and see a test fail.

The contract's own ambiguities show up here first: a schema limit that pre-empts a business error
(`minLength` against `too_short`), error details the UI reads that the contract never names, a
link to a file no operation serves, an order the UI depends on and the contract leaves open.
Record each under the gap report's Contract section for the backend team.

## Running it

```bash
cd <backend> && cp .env.example .env && npm install       # fill the three database passwords
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build   # db, mail, api, on 127.0.0.1
npm test                            # against the db service (TEST_DATABASE_URL)
node S/staging-run.mjs --url http://127.0.0.1:<API_PORT> --flows <app>/staging-flows.sample.json \
  --contract <app>/api/openapi.yaml --live-contract http://127.0.0.1:<API_PORT>/api/openapi.yaml \
  --build <app>/dist/index.html --sample --save-session <file> --record <app>/docs/production/staging.json
docker compose down                 # this project only (-v drops the data)
```

The compose file builds the backend's image and mounts the app's `dist/` and
`security-headers.json` read only. On its own it has no dev routes and seeds nothing: a database
it starts on stays empty until the backend's own data arrives. The override
`docker-compose.dev.yml`, for a local staging run only, sets `DEV=1` with
`DEV_PUBLISHED_ON_LOOPBACK=1`: then an empty database is seeded with the design's data and the
seeded password, and the stand-in sign-in (`/__sample/sign-in`, a plain form, no script),
`POST /__sample/reset` (the schema rebuilt and seeded) and `GET /__sample/stats` exist; the server
refuses them on any other host. Never deploy with the override.

**An app with its own server** (server rendered, [stacks/nextjs.md](stacks/nextjs.md)) puts that
server in front: add `-f docker-compose.api-only.yml` (no build mounted, no static file served; the
base file still wants `APP_DIR` set, which is not mounted), set `ALLOWED_ORIGINS` to the app server's
origin (through its proxy the backend sees its own host), and let the app server proxy `/api`, and
`/__sample` for a local run only. `GET /__sample/stats` lists every `/api` answer, numbered
(`served`, `servedLog`): `staging-run.mjs --sample` reads it around each flow, so a flow's expected
request may be one the app's server made, held to the same `allowStatus`.
Give each backend its own `COMPOSE_PROJECT_NAME` and ports, and only ever take down your own
project. Several apps can share one backend (`examples/equipment-loans-api` (in the proving repository) serves
`equipment-loans-app` and its Vue and Next.js twins): `.env` names one, and another is served by
setting `APP_DIR=<that app>` on the compose command line, which overrides `.env` and leaves it
unedited. An app with its own server (the Next.js twin) also takes the API-only override and
`ALLOWED_ORIGINS`, below. Mailpit shows every message at `http://127.0.0.1:<MAIL_UI_PORT>`.

Its flows are `staging-flows.sample.json` (one file per backend or shape, `staging-flows.<kind>.json`:
[production-bar.md](production-bar.md#the-staging-run)), since its sign-in is the stand-in's. A
flow types an authenticator's code with `{ "fill": { "label": "Code", "totp": "<seeded secret>" } }`
(`lib/totp.mjs`); run that backend on real time (`CLOCK=` empty), since the code is computed from
the clock. `--sample` resets the backend first, reads its stats after, and fails the run on a
request or response outside the contract or a call to an operation with no handler.

## Sign-in through an identity provider

An app with no sign-in screen (`signIn: 'redirect'`) has every page load with no session sent to
sign in and back to the same address. Where to, set at run time: in dev with nothing set, the
stand-in page; with `SIGN_IN_URL`, that page; with `OIDC_ISSUER`, the provider over OpenID Connect
(`lib/oidc.mjs`, on `openid-client`). Setting both is refused at start.

- **The flow**: the authorization code flow for a confidential client, with PKCE (S256), `state`
  and `nonce`. `GET /auth/sign-in?return_to=` stores the pending sign-in in `oidc_logins`, found by
  the hash of a random `oidc_login` cookie (`HttpOnly`, `SameSite=Lax`, path `/auth`, 10 minutes),
  so a callback another browser started (login CSRF) is refused before the code is exchanged.
  `GET /auth/callback` uses it once, exchanges the code with the verifier and the client secret,
  and checks the ID token: its signature against the provider's JWKS (`enableNonRepudiationChecks`:
  openid-client trusts the token endpoint's TLS alone by default, which a planted bad signature
  passed), `iss`, `aud`, expiry and nonce. Then a session, as any sign-in starts one, and a 303 to
  `return_to` (a path on this site, `safeReturn`).
- **Who it is here**: `userFromClaims(claims, db)` in `backend.config.mjs` returns the user, or
  null for someone the provider knows and this backend does not (403, no session, and a link that
  ends the provider's session to switch account). Map from a verified claim, and take the role from
  the provider's groups when the brief says roles live there (equipment-loans: answer A-1); the
  permissions are still read from the database on every request.
- **Sign-out**: `GET /auth/sign-out` is a one-button form; its `POST` (refused from another site)
  ends the session, and over OIDC sends the browser to the provider's end-session endpoint with the
  ID token kept in the session (`id_token_hint`), back to `/auth/signed-out`. With the stand-in or
  `SIGN_IN_URL` it ends this backend's session only. The `/auth` pages have their own policy (no
  script; forms only to this host and the issuer), since a redirect after a form post is held to
  `form-action`.
- **Settings**: `OIDC_ISSUER`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` (in `.env.api`, never in the
  image), `OIDC_REDIRECT_URI` (this backend's `/auth/callback`, as registered at the provider),
  `OIDC_POST_LOGOUT_REDIRECT_URI` (default its origin's `/auth/signed-out`). An `http` issuer or
  redirect URI is refused unless its host is loopback or `.localhost`. The provider is discovered
  on first use, so one that is down answers the sign-in 503 with a way back instead of stopping the
  backend. The start of a sign-in writes a pending row for anyone who asks (swept after ten
  minutes): rate-limit `/auth/` at the proxy in front, which the deploy owns.

**A local provider** (`examples/equipment-loans-api/docker-compose.idp.yml` (in the proving repository)): Keycloak, pinned by
digest, `start-dev` with the app's realm imported (`idp/realm.json`: the client with PKCE required,
two people in the groups the roles come from, and one the backend does not know). Its issuer is
`http://idp.localhost:<IDP_PORT>`, the same URL for both sides: the browser resolves a `.localhost`
name to loopback, and the backend's container reaches the provider through a network alias of that
name, with Keycloak listening on the published port inside too. Give the two different URLs (a
service name inside, `127.0.0.1` outside) and every ID token fails the issuer check.

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.idp.yml up -d --build --wait
node S/staging-run.mjs --url http://127.0.0.1:4300 --flows <app>/staging-flows.oidc.json ... --sample
```

The flows fill the provider's own form (`{ "fill": { "label": "Username or email", ... } }`),
sign out between people, and include the person the backend does not know (`allowStatus: [403]`).
A pass proves the backend against a real provider; the organisation's provider, its client
registration and its claims stay a blocking gap.

Keep the stub for what only it can do (a scenario on demand, such as a 503 maintenance answer).
