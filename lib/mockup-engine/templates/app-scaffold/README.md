# App scaffold

The files Convert writes into every new app before the first page: the HTTP client, telemetry, the
query client, permissions, the bundler or framework config, `package.json`, and the configuration
the checks and the production bar read. One folder
per stack, plus `shared/` for what is the same on all three. How and when: the engine's
`skills/mockup/references/step-detail.md` (Convert, Step 5; Step 6, items 2 and 8) and the stack's reference.

```bash
cp -R templates/app-scaffold/<stack>/. <app>/
cp templates/app-scaffold/shared/staging-flows.json <app>/
cp scripts/check-frontend.mjs <app>/scripts/
```

`cp -R <stack>/.` copies the dot files too (`.env.example`, `.env.mocked`, `.gitignore`). The app then writes its
own `index.html` (Vite), entry, shell, pages and mocks, and `api/openapi.yaml` before the first
`npm run typecheck`: `generate` runs first and reads it.

The stacks' `package.json` files differ where their proven apps do: only React and Vite has
`test:coverage`; Next.js's `import:mockup` and `import:check` pass `--i18n i18next --flat`, and it
runs `start` and `start:mocked` where the Vite stacks run `preview` and `preview:mocked`.

Two kinds of file. **Held** files are the proven apps' own, kept by
`scripts/test/app-scaffold.test.mjs` byte for byte, or with the app's names replaced by placeholders
and the calls into modules the scaffold does not carry taken out: keep them unchanged except where
the table says to fill something in, and when a proven app improves one, the test fails until the
template follows. **Skeletons** hold each app's own values: fill every `<placeholder>`. The test
checks the configuration of both kinds with the engine's own checks: the headers' minimum set
(`lib/production.mjs`), `perf-budget.mjs`, `staging-run.mjs`'s flow validation, and
`check-frontend.mjs` rule `generated-format` on a scratch app built from each stack's folder.

## Every stack

| File | What it is | What to change | Governed by |
|---|---|---|---|
| `src/api/http.ts` | The Orval mutator every generated call goes through: base URL, a 10 second timeout combined with the caller's signal, the session cookie (`same-origin`, or `include` for an API on another origin of the site), the double-submit CSRF header on state-changing methods (the `csrf_token` cookie, else the token the server last sent in `X-CSRF-Token`), and `ApiError` from the contract's error envelope | Nothing. It imports `ErrorEnvelope` from the generated model, so the contract must define it | `api-integration.md` (The mutator; Another origin), `frontend-defaults.md` (Security) |
| `src/lib/telemetry.ts` | OpenTelemetry (3.x line), off unless the collector's endpoint is set, loaded on demand; `redact`, `setActor`, `reportError` | `SERVICE`: the app's name, `<app>-web` | `frontend-defaults.md` (Error reporting and telemetry; Gotchas on every stack: the 3.x line) |
| `src/lib/query.ts` | The one query client: reads retry 5xx, network and timeout failures with jittered backoff, writes never retry, only failures a human must look at are reported | Nothing. The `system-pages` and `session-password` modules add their `noteApiResult`, `noteNetworkResult` and `noteSessionError` calls here (`modules.md`) | `frontend-defaults.md` (Error reporting and telemetry), `api-integration.md` |
| `biome.json` | Biome: format, lint, a11y, `noDangerouslySetInnerHtml`; `api/`, `docs/` and `import-mockup`'s outputs left out; the Orval folder kept in with its linter off | Add an `import-mockup` output to `files.includes` as `!path` only if the app has one not listed. Never exclude `src/api/generated` | `api-integration.md` (Orval configuration), `frontend-defaults.md` (Gotchas on every stack) |
| `orval.config.ts` | The client, models and Zod schemas from `api/openapi.yaml`, each output formatted by Biome | Nothing, while the contract is at `api/openapi.yaml` (`import-mockup --only contract` writes it there) | `api-integration.md` (Orval configuration), `step-detail.md` (Step 6, item 2) |
| `security-headers.json` | The one source of the app's headers: a CSP without `'unsafe-inline'`, `nosniff`, a `Referrer-Policy`, HSTS | Add any other origin the app talks to (a map tile host, an image CDN) to its directive | `production-bar.md` (Headers), `frontend-defaults.md` (Security) |
| `package.json` | **Skeleton.** The scripts the checks and the references run (`generate`, `import:mockup`, `import:check`, `dev`, `build`, `build:mocked`, the preview or start of each build, `typecheck`, `lint` with `check-frontend`, `test`, `audit`), the engines, `overrides` and `allowScripts`, and every dependency at the exact version the proven example pins (the test names it) | `name`: `<app>`. In `import:*`, `<engine>` is the engine's folder and `<mockup>` the signed-off mockup's; add `--flat` when a string key is also a prefix of another. Add the app's own libraries at the newest release 14 days old, pinned exactly; move a pin only with the lockfile and a green run | `frontend-defaults.md` (The checks; Gotchas on every stack: npm 11, audit, `allowScripts`), the stack's reference (Libraries; Done when) |
| `package-lock.json` | **Skeleton.** The proven example's lockfile with the placeholder name: the tree that example's gates ran on, every version at least 14 days old when it was locked, from the public registry with sha512 hashes (`scripts/test/check-lock.test.mjs` holds it to the example) | Nothing before the first `npm ci`. After that it is the app's own: add a library with `npm install <name>@<version>`, which the `.npmrc` keeps to aged versions, and run `check-lock.mjs` on the app | [`DEPENDENCIES.md`](../../DEPENDENCIES.md) (The rules; Updating) <!-- supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read --> |
| `.npmrc` | Exact pins (`save-exact`), the tested Node and npm (`engine-strict` against `engines`: Node 24 from 24.18.0 or 26 from 26.13.0, npm from 11.16.0), only versions published 14 or more days ago (`min-release-age`), and no install script that `allowScripts` does not name (`strict-allow-scripts`). Not `ignore-scripts`: it would skip the app's own `prebuild`, which generates the client | Nothing. A new package with an install script fails the install until `allowScripts` denies it (`false`) or approves that one version (`"name@1.2.3": true`) | [`DEPENDENCIES.md`](../../DEPENDENCIES.md) (The rules), `frontend-defaults.md` (Gotchas on every stack: `allowScripts`) <!-- supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read --> |
| `.env.example` | The variables the app reads, each commented; never a secret | Nothing; the app's own variables are added here | `frontend-defaults.md` (Security), the stack's reference (Done when) |
| `.gitignore` | **Skeleton.** Keeps out the generated client (`src/api/generated/`), every `.env*` but the ones the scaffold ships (`.env.example`, and `.env.mocked` on the Vite stacks, which hold no secret), keys, both builds (`dist/` and `dist-mocked/`; on Next.js `.next/`, `.next-mocked/`, `next-env.d.ts`, `tsconfig.tsbuildinfo` and the `AGENTS.md` `create-next-app` writes), coverage and the engine's `.mockup-engine/` outputs | Add the app's own generated or local files | `api-integration.md` (Orval configuration), `frontend-defaults.md` (Security) |
| `perf-budget.json` | **Skeleton.** The bundle budget in KB of gzip (`bundle.initialJsKb` is required) and the vitals, warning only until `"gate": true` | Set the numbers for the client's devices, from the first real build, with headroom | `production-bar.md` (Performance budget) |
| `staging-flows.json` (in `shared/`) | **Skeleton.** The staging run's flows: sign in, then one read and one write per area, each asserting a path, a text or a request | Fill every `<placeholder>` from the contract and the seed data; add a read and a write for each area; copy it as `staging-flows.sample.json` for the sample backend's identity provider, and `staging-flows.cross-origin.json` for an API on another origin | `production-bar.md` (The staging run), `sample-backend.md` |

## React and Vite (`react-vite/`)

| File | What it is | What to change | Governed by |
|---|---|---|---|
| `src/lib/permissions.tsx` | `SessionProvider` (loads the session once; before any session, a 401 reloads once so the backend for frontend can sign the user in), `useSession`, `useCan`, `<Can>`, `RequirePermission`; `Permission` comes from the contract's own schema | Nothing, when the contract has a `session` tag with `getSession` returning `Session` (`user_id`, `permissions`) and a `Permission` enum. It imports the `ErrorState` and `ForbiddenPage` composites and `react-i18next` (keys `ErrorState.title`, `ErrorState.body`). The `session-password` module adds `noteSessionStarted()` after `setActor` | `frontend-defaults.md` (Security: permissions, never roles), `dashboard-patterns.md` |
| `vite.config.ts` | **Skeleton**, from proven parts. `vite preview` sets the headers from `security-headers.json` on static files, and on every page a fresh nonce through `perRequestNonce` and `html.cspNonce` (both functions held byte for byte from the proven Vue app with a kit, which the test names); MSW's plugin only in dev or the mocked mode; the mocked build in `dist-mocked`, so `dist` (the build the production bar hashes) never holds the mocks; the `@/` alias; Vitest from `tests/` | Add the design framework's plugin, fixed ports (`server.port`, `preview.port`, `strictPort`) clear of the machine's other apps, and the business zone as `test.env.TZ`. Write `{nonce}` into `style-src` of `security-headers.json` only for a kit that injects styles; the nonce's placeholder then also needs replacing per response in production | `stacks/react-vite.md` (A kit that injects styles; Done when), `frontend-defaults.md` (Security: headers) |
| `.env.mocked` | `VITE_ENABLE_MOCKS=true` for `vite build --mode mocked` and `vite preview --mode mocked` | Nothing | `stacks/react-vite.md` (Done when) |
| `src/vite-env.d.ts` | The public `VITE_*` variables the modules read | Add the app's own `VITE_*` names; never a secret (rule `public-secret`) | `frontend-defaults.md` (Security) |
| `tsconfig.json` | Strict, `noUncheckedIndexedAccess`, `@/` alias, tests included | Nothing | `stacks/react-vite.md` (Libraries) |

`security-headers.json` names `{origin:VITE_API_BASE_URL}` and `{origin:VITE_OTEL_EXPORTER_OTLP_ENDPOINT}`
in `connect-src`: `headers.mjs` fills each from the environment and drops it when it is unset or a
path, so the same file serves a same-origin API and one on another origin of the site. `vite.config.ts`
does the same for `vite preview`: a path such as the default `/api` is the page's own origin, already
`'self'`, so it passes only a full URL to the filler.

## Vue (`vue/`)

| File | What it is | What to change | Governed by |
|---|---|---|---|
| `vite.config.ts` | **Skeleton**, as React's with `@vitejs/plugin-vue` and the vue-i18n feature flags | As React's | `stacks/vue.md` (Mocks; Done when), `design-frameworks.md` |
| `.env.mocked` | As React's | Nothing | `stacks/vue.md` (Done when) |
| `src/lib/session.ts` | `SessionKey`, `canIn`, `useSession`, `useCan` (a computed); the session is loaded by the app's `SessionGate` and provided under `SessionKey`; `Permission` comes from the contract's own schema | Nothing; the contract needs a `Session` (`permissions`) and a `Permission` enum | `stacks/vue.md`, `frontend-defaults.md` (Security) |
| `env.d.ts` | The public `VITE_*` variables | Add the app's own; never a secret | `stacks/vue.md` |
| `tsconfig.json`, `tsconfig.app.json`, `tsconfig.node.json`, `tsconfig.vitest.json` | The app, the Node side (Vite and Orval configs) and the tests, each strict | Nothing | `stacks/vue.md` |

`biome.json` turns `useAnchorContent` off for the `AppLink` primitive only, where no comment can sit
before the element (`stacks/vue.md`). `src/api/http.ts` and `security-headers.json` are the React
stack's, byte for byte: the client is the same on both Vite stacks.

## Next.js (`nextjs/`)

| File | What it is | What to change | Governed by |
|---|---|---|---|
| `src/lib/session.ts` | `canIn` and the `Permission`, `Session` and `Access` types, for server and client code alike | Nothing; the contract needs a `Session` (`permissions`) and a `Permission` enum | `stacks/nextjs.md`, `frontend-defaults.md` (Security) |
| `tsconfig.json` | Strict, the `next` plugin, the `@/` alias, both build folders' types | Nothing | `stacks/nextjs.md` |
| `next.config.ts` | `MOCKS` and `MOCK_NOW` inlined at build (`next dev` and `MOCKS=true next build`, into `.next-mocked`); every header but the CSP from `security-headers.json` on every path | `<pins.clock>`: the mockup's `pins.clock` | `stacks/nextjs.md` (Mocks and scenarios; Security headers) |
| `src/proxy.ts` | The CSP with a fresh nonce on every answer, on the request too so Next.js puts it on its scripts; `/api` proxied to `BACKEND_URL` (503 when unset), checked on the resolved URL; `/__sample/*` only with `PROXY_SAMPLE_ROUTES=1`; in a mocked build, the visit, `?as`, `?state` and `?system` as request headers | Nothing. Test `backendUrl` in a `// @vitest-environment node` file | `stacks/nextjs.md` (Security headers; Serving and the backend; Mocks and scenarios) |
| `src/lib/server/api.ts` | The server mutator (`serverFetch`, `server-only`): the user's cookie and the CSRF cookie's value to `BACKEND_URL`, a 10 second timeout, errors as `ApiError`; in a mocked build the mock API answers, no network | Nothing | `stacks/nextjs.md` (Libraries: Reads; Serving and the backend), `api-integration.md` |
| `src/lib/server/flags.ts` | `mockFlags()`: the mock visit's flags from the request headers `proxy.ts` sets, `null` outside a mocked build | Nothing | `stacks/nextjs.md` (Mocks and scenarios) |
| `src/app/api/[...path]/route.ts` | The browser's `/api` in a mocked build, answered by the same mock API; 404 in production, where `proxy.ts` rewrites `/api` first | Nothing | `stacks/nextjs.md` (Mocks and scenarios) |

Here `src/api/http.ts` is same origin always (the Next.js server proxies `/api` to the backend), and
`src/lib/telemetry.ts` reads `NEXT_PUBLIC_*` names. `orval.config.ts` has a second client for server
code through `src/lib/server/api.ts` (`serverFetch`). It, `flags.ts` and the `/api` route import
`@/mocks/visits`, which the app writes: it exports `VisitFlags` (`visit`, `role`, and `state` and
`system`, each `undefined` to keep the visit's) and `mockFetch(request, flags)`, answering through
MSW's `getResponse` with the app's `createHandlers()`, one store per visit on `globalThis`
(`stacks/nextjs.md`, Mocks and scenarios). `.env.example` names `BACKEND_URL`, `SIGN_IN_URL` and
`PROXY_SAMPLE_ROUTES`, read at start, never built in. Next.js does not follow a symlinked
`node_modules` out of the project (Turbopack's root): install, or clone the folder.
`security-headers.json` writes the nonce as `{nonce}`, which `proxy.ts` fills per request; it does not
fill `{origin:...}`, so a telemetry collector on another origin is written into `connect-src` as
it is. The budget starts above the runtime's floor of about 174 KB (`stacks/nextjs.md`, Budget).

## Existing repo

When the app is a part of a repository the client already runs (`skills/convert-mockup/references/existing-repo.md`),
do not `cp -R` the folder over it. Copy only the files the repo lacks; merge the rest into the
repo's own: the scripts into its `package.json` (the names the checks run, its existing scripts
kept), the plugins, headers, nonce and mocked build folder into its `vite.config.ts` or
`next.config.ts`, the ignores into its `biome.json` (or its own linter's config) and its
`.gitignore`. The repo's layout and conventions win; each merge is a change to the client's repo,
made only with the user's go.

## Not here

Each app's own: `index.html`, the entry and the shell, the pages, the mocks (`src/mocks/`), the
strings, `tests/support/setup.ts` (named by the Vitest config) and, on Next.js, `vitest.config.ts`
(it inlines the same `MOCKS` and `MOCK_NOW`; take it from the Next.js example the test pins `package.json` to). Each
comes from the stack reference and the mockup.
