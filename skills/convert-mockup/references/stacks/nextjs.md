# Stack: Next.js App Router (`nextjs`)

**Proven on one app, server rendered**, through the production bar (`examples/equipment-loans-next` (in the proving repository),
the twin of `equipment-loans-app` and `equipment-loans-vue` from one signed-off package; Next.js
16.4.5, React 19.3, Turbopack), and on the direct route onto a design framework
(`examples/tailwind-next` (in the proving repository), `examples/kit-next`; neither ran the bar against a backend). Not proven:
an API on another site, a deploy to a real host. The numbers are in the README's test log.

Next.js 16 renamed and changed what earlier versions called middleware and more. Its documentation
ships in the package (`node_modules/next/dist/docs/`): read the pages on `proxy.ts`, Content Security
Policy and Server Actions there before writing those files, not from memory.

Apply [../frontend-defaults.md](../frontend-defaults.md) and
[../api-integration.md](../api-integration.md) throughout. Scaffold from
`templates/app-scaffold/nextjs/` (`http.ts`, `telemetry.ts`, `query.ts`, `session.ts`, `biome.json`,
`orval.config.ts`, `security-headers.json` with `{nonce}`, and a `perf-budget.json` that starts at
230 KB, `next.config.ts`, `proxy.ts`, `package.json` with the exact pins, the server mutator
`lib/server/api.ts` with its flags and the `/api` route handler).

## Shape

Decide it at intake; it changes what the production bar runs against.

| Shape | What it is | When |
|---|---|---|
| **Server rendered** (proven) | Server Components read the API with the user's cookie; Server Actions write; the Next.js server is the origin, proxies `/api` to the backend for frontend and sets the headers | the default |
| Client components only | every page a client component calling `/api` from the browser, still behind the Next.js server for the nonce CSP | when the team wants Next.js routing but no server reads |
| Static export | `output: 'export'` on a static host | rarely: Next.js's inline scripts then need hashes, or `unsafe-inline` |

The rest of this file is the server-rendered shape.

## Libraries

Newest release at least 14 days old, pinned exactly, lockfile committed.

| Concern | Choice |
|---|---|
| Framework | Next.js App Router, `src/` directory, TypeScript strict, Turbopack (the default), no ESLint (Biome with the `react` and `next` domains) |
| Rendering | Server Components by default; `'use client'` only on files holding state or handlers. **A `'use client'` file exports components only**: anything else it exports (a helper, a constant) is a client reference on the server, and calling it there throws. Helpers both sides use live in a plain module (`lib/queries.ts`) |
| Reads | a page's server component reads through Orval's `fetch` client with a server mutator (`lib/server/api.ts`, `server-only`) that forwards the request's `cookie` header to `BACKEND_URL`, times out, and maps the error envelope to the same `ApiError` the browser's client throws. A filter, a tab or a page change refetches in the browser through Orval's `react-query` hooks on `/api`, seeded with the server's first page (`initialData` for the first query only) |
| Writes | Server Actions in one `'use server'` file. Each takes its arguments as strings, **encodes any id before it reaches a path** (`encodeURIComponent`, the arguments come from the browser), and returns `{ ok, data } \| { ok: false, status, code, details }` rather than throwing (production masks a thrown error's message, and the page needs the contract's `code`). The browser wraps the call so a refusal becomes its `ApiError` for the query client. An `Idempotency-Key` is made in the browser once per intent and passed in, so a retried action reuses it |
| Orval | two outputs from one contract: `client: 'react-query'` with the browser mutator, and `client: 'fetch'` with the server mutator, sharing one model folder; `formatter: 'biome'` written out in each output (check-frontend reads it there) |
| Styles | the mockup's `tokens.css`, `base.css` and `components.css` imported once in the root layout, global (as on Vue). CSS Modules change the class names the DOM oracle compares and are not needed |
| Strings | whatever the mockup's strings need, on the client too. One locale with named placeholders only: a twelve-line lookup (`lib/i18n.ts`, refusing to load on a plural key) instead of i18next, which cost 15.5 KB on every page (measured: the initial load before and after). A key that is also a prefix of another rules out next-intl (it nests on dots); import with `--i18n i18next --flat` |
| Dates | instants formatted in the organisation's zone on both sides (`Intl.DateTimeFormat` with `timeZone`), never the viewer's: the server renders first and may run in any zone, and hydration must agree. Record it as a deviation when the mockup used the viewer's zone; the gate pins the browser to the same zone |
| Tests | Vitest and Testing Library in `tests/`, never `app/`. Async Server Components do not render there: test client views by props, server helpers and actions as functions (mock `next/headers`), and `proxy.ts` in a `// @vitest-environment node` file. Pages as a whole are the gate's |

## Mocks and scenarios

A mocked build exists to run the gate on built output; it is never deployed.

- **`MOCKS` is a build-time constant**, inlined by `next.config.ts` `env` (`next dev` and
  `MOCKS=true next build`, into its own `distDir`). **Write `process.env.MOCKS === 'true'` out at every
  branch.** An imported `const MOCKS = ...` hid the branch from the bundler, and the fixtures shipped in
  the production build's server chunks until each guard was written out. Mock modules are imported
  dynamically inside those branches.
- **Check the production build**: grep all of `.next/`, server chunks included, for fixture strings,
  mock cookie and header names and the preview messages; only server-side `.map` files may mention them
  (never served). A production server with no `BACKEND_URL` must answer `/api` with 503.
- **One mock API for both sides**: the server's reads and a mocked-build `/api` route handler answer
  through MSW's `getResponse` with the same `createHandlers()`, no network.
- **State per visit.** A server's mock state outlives a page, unlike an SPA's worker. `proxy.ts` mints a
  visit id on each document load (`sec-fetch-dest: document`, no `rsc` header), keeps `?as` in a
  cookie, and passes the visit, the role and that load's `?state` and `?system` to the server as
  request headers: a cookie set in this answer is not in this request. Keep the store on `globalThis`;
  route handlers and pages are separate bundles.
- **`?state=loading` and `error`.** A server read cannot be held open (the document would never
  finish). The page's loader, in a mocked build only, returns the loading status without reading and
  the page draws its loading view; `error` and `empty` come from the mock API as real answers.
- **`?system=crash` fails in the browser**, after hydration: a server-side throw is masked and answers
  500, and the mockup's config expects the preview's own message.
- **The mock clock** is the mockup's pin, inlined (`MOCK_NOW`): the gate pins only the browser.

## Security headers

- `security-headers.json` stays the one source. Write the nonce as `{nonce}` alone, standing for the
  whole `'nonce-<value>'` token: `script-src 'self' {nonce} 'strict-dynamic'`. `proxy.ts` fills it per
  request, sets the header on the answer and on the request (`NextResponse.next({ request: { headers } })`),
  so Next.js puts the nonce on its scripts; `next.config.ts` `headers()` sets the others on every path,
  static files included. `next dev` needs `'unsafe-eval'`; a build never does.
- `headers.mjs --check` fetches twice and needs a fresh nonce each time; `--emit nginx` refuses it, rightly: only a server
  writing each answer can.
- Every page is dynamically rendered (a nonce per request).

## Serving and the backend

- **`proxy.ts` proxies `/api` to `BACKEND_URL`** with `NextResponse.rewrite`, read at start. **Check the
  resolved URL, not the raw path**: the server hands `/api/%2e%2e/x` to the proxy as it came, and `new
  URL` resolves it to `/x` after a check on the raw path passed (security audit, M-01). Refuse
  anything that leaves the prefix.
- **The sample backend's dev routes** (`/__sample/*`) are proxied only with an explicit local flag
  (`PROXY_SAMPLE_ROUTES=1`): proxied by a reachable server they republish loopback-only routes, the
  password-free sign-in among them (M-02). `SIGN_IN_URL` is required, with no default.
- **The backend allows the app's origin** (the sample backend's `ALLOWED_ORIGINS`): through the
  rewrite it sees its own host, the browser sends the app's, and its pre-session check refuses the
  sign-in otherwise.
- **The session.** The layout reads it on the server (`react` `cache`, shared with the page); a 401
  redirects to `SIGN_IN_URL` with `return_to` the current path (from a request header `proxy.ts`
  sets: a layout has no pathname); 503 maintenance draws the maintenance page in place of the app.
- **CSRF.** The server sends the `csrf_token` cookie's value as the header, so the backend's
  double-submit check passes by construction. Next.js refuses a Server Action whose `Origin` is not
  the host (proven by a probe); with the session cookie `SameSite=Lax` that is the defence. Audit it.
- **`Set-Cookie` from a server read is dropped**: fine while only the sign-in (proxied) and sign-out
  set cookies; forward it in an action that can.
- **Client addresses**: the server's reads come from its own address; tell a backend with per-client
  limits the client's.

## Mapping

| Mockup | Next.js |
|---|---|
| component without actions | Server Component |
| page with `state` or `actions` | a server `page.tsx` that reads, and a `'use client'` view taking the data as props |
| `layout` | `app/(app)/layout.tsx` (server: the session, the menu by permission) with a client shell for the current link (`usePathname`), focus and keys |
| `route` with `:id` | `app/(app)/x/[id]/page.tsx`; `params` is a Promise; encode before it reaches a read |
| `<a href>` | `next/link` |
| `needs.permission` | checked in each page on the server, drawing the designed refusal in place |
| `title` | `export const metadata` |
| not-found | a catch-all `[...missing]/page.tsx` calling `notFound()` and the group's `not-found.tsx`, inside the layout. It answers HTTP 404: give the gate copy's screen `expectStatus: [404]` |
| server-error | the group's `error.tsx`, with the error's digest as the reference |
| form `data-action` | a Server Action |
| the root | `<div id="app">` in the root layout, so the DOM oracle reads the mockup's root; the live region after it |
| shell `keys` | one `keydown` listener in the client shell, added in an effect and removed in its cleanup, with the mockup's rule for bare keys in fields (proven, `examples/equipment-loans-next` (in the proving repository)) |
| `<dialog data-modal>` | a client `Dialog` on a native `<dialog>`: `showModal()` in an effect on mount, rendered only while open, `onCancel` prevented and passed up (proven, `examples/equipment-loans-next` (in the proving repository), `kit-next`) |
| `MoneyField` with its `MK.onRender` caret hook, the ARIA grid | as [react-vite.md](react-vite.md#mapping), in a `'use client'` component (unproven on Next.js: no example has either) |

## Gotchas to watch

The stack-neutral gotchas are in [../frontend-defaults.md](../frontend-defaults.md#gotchas-on-every-stack),
and the React ones (`selected` on an option, `StrictMode`) in [react-vite.md](react-vite.md#gotchas-found-while-proving-the-example).

- **`next dev` shows an "Issues" badge** once an error is caught, even with `devIndicators: false`,
  and also on the app's own `console.error` (a failed write logged in development): the server-error
  and refused-save previews differ on the dev server only. Gate on the mocked build.
- **`next dev` writes into `.next/dev`**, server chunks with the mocks included. Check the production
  build for mocks after `rm -rf .next` with no dev server running, or the grep finds the dev chunks.
- **`next dev`'s developer tools inject `<style>` without the nonce** (about 30 CSP errors per load,
  dev server only; Next.js's own guide answers with `style-src 'unsafe-inline'` in development).
  Harmless to the visual diff; run the quality check on the mocked build.
- **The route announcer** (`<next-route-announcer>`, after `#app`) holds an empty `role="alert"` in a
  shadow root: a page-wide count of alerts finds one more than the mockup. Count inside `#app`.
- **No `loading.tsx` for a page whose frame depends on the session** (an intro per role): it cannot
  read it. Next.js keeps the previous page until the next one arrives.
- **React attributes**: write `data-diff-ignore=""` and `data-modal=""`; a bare attribute renders `"true"`.
- **The first request to a route on `next dev`** compiles it; a gate case that refetches at once can
  time out on the first run.
- `next/image` changes markup and size; use `<img>`.
- Next.js writes `AGENTS.md` and edits `tsconfig.json` on its first run; ignore the first in git.

## Design frameworks

The method is [../design-frameworks.md](../../../mockup/references/design-frameworks.md); what Next.js changes:

- **Tailwind**: `@tailwindcss/postcss` at the mockup's CLI version, the mockup's `tailwind.css`
  imported in the root layout. The App Router has no `src/pages`, so the copied `@source "../pages"`
  scans nothing and nothing warns. A nested `@import "./tokens.css"` resolves inside Tailwind's PostCSS
  pass. Compare the built sheet with the mockup's after normalising both (lightningcss, the same
  targets): Next's pipeline evaluates `calc(infinity * 1px)` to a number.
- **Strings with plurals**: the twelve-line lookup refuses a plural key, so a mockup with plurals takes
  i18next with `--flat` (`examples/tailwind-next` (in the proving repository)). Decide the locale on the server (`proxy.ts`), and set
  `<html lang>` there.
- **A CSS-in-JS kit**: Material UI through `@mui/material-nextjs`'s App Router cache provider, given the
  request's nonce (read from the request header `proxy.ts` sets), so Emotion's `<style>` elements carry
  it. **A kit's inline `style` attributes on server-rendered markup are blocked by the nonce CSP**
  (nonces cover elements, never attributes): Material UI 9's Paper writes its elevation as
  `style="--Paper-shadow: ..."`. Move such values into `sx` (a `style` prop that only clears the kit's
  inline variable, so no attribute is rendered, carries a `check-frontend-allow` comment with its
  reason), and check the served HTML of every scenario
  for `style=` (`examples/kit-next/scripts/ssr-style-check.mjs` (in the proving repository)). The kit's own CSS blocks stay out of the
  app's global sheet: generate `own.css` from `components.css` with the approximation blocks dropped.
- **Budget**: Material UI with Emotion and the app measured 280 KB of initial JS gzip, about 106 KB over
  the empty app's floor; set a kit app's budget from that, not from a plain app's.

## Budget

An empty one-page Next.js 16.4.5 app (a root layout and a dynamic page, `next build && next start`)
loads 173.9 KB of JS gzip before any app code: six chunks, the largest react-dom (72 KB) and the App
Router (50 KB). The proven app measured 199.6 KB, so its own code is about 26 KB; its budget is
230 KB, decided by the user and recorded. Budget a Next.js port from that floor, not from a Vite app's
(the same app on Vite measured 122 KB with React, 76 KB with Vue).

## Done when

`tsc --noEmit`, lint, tests and audit clean; the visual diff on `next dev`; the mocked build
(`MOCKS=true next build && MOCKS=true next start`, into and from `.next-mocked`) passing the visual
diff, the quality check and the DOM oracle under its nonce CSP; the production build (`next build &&
next start`) free of mocks. Build-time: `MOCKS`, `MOCK_NOW` and `NEXT_PUBLIC_*`; read by the server
at start: `BACKEND_URL`, `SIGN_IN_URL`, and `PROXY_SAMPLE_ROUTES=1` for a local run against the
sample backend only. Then the production bar
([../production-bar.md](../production-bar.md)) with the production build in front of the backend
(`docker-compose.api-only.yml`, [../sample-backend.md](../sample-backend.md)): `staging-run.mjs`
counts the server's own requests from the sample backend's log, and `perf-budget.mjs --next .next`
measures the served pages, signed in.
