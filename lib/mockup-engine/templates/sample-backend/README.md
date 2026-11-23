# Sample backend

A backend written from the signed-off contract, on Postgres, run as a container stack with a mail
catcher, for the production bar's staging run. How to write, run and read it: the engine's
`skills/convert-mockup/references/sample-backend.md`.

- `lib/` (its `migrations/` are the engine's sessions, CSRF and pending sign-in tables; `oidc.mjs` the
  OpenID Connect client), `server.mjs`, `Dockerfile`,
  `.dockerignore`, `docker-compose.yml`, `docker-compose.dev.yml`, `docker-compose.api-only.yml`
  `test/template.test.mjs` and `test/oidc.test.mjs` are the engine's: keep them unchanged (the engine's
  `scripts/test/sample-backend.test.mjs` checks each example's copy).
- `package.json` and `package-lock.json` pin every dependency exactly (the same test checks it):
  set `name`, and add a dependency only pinned, with the lockfile. `.gitignore` keeps out
  `node_modules/`, `.env` and `.env.api`.
- `backend.config.mjs` and `.env.example` ship as skeletons to fill. `migrations/` (the app's
  tables), `handlers.mjs`, `seed/` (`fixtures.js`, a byte copy of the mockup's, and `source.json`
  naming where from), `api/openapi.yaml` and the rest of `test/` are not shipped: the app writes
  them, the tables and the handlers from the contract's descriptions, never from the app's mock
  handlers.

Security: the engine's `docs/audits/2026-11-20-backends-security.md`, every finding fixed. Before
the first start, fill the three database passwords in `.env` (and the app's own secrets, such as an
encryption key, in `.env.api`). Behind a proxy, set `TRUST_PROXY`. For an app served from another
origin (same site), set `ALLOWED_ORIGINS` to its origin. For sign-in through an identity provider over
OpenID Connect, set `OIDC_ISSUER`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` (in `.env.api`) and
`OIDC_REDIRECT_URI`, and write `userFromClaims` in `backend.config.mjs`.

```bash
cp .env.example .env && npm install
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build   # local staging: dev routes, seed
docker compose up -d --build     # without the override: no dev routes, no seed
npm test                         # against the db service
```
