# Stack: React and Vite (`react-vite`)

Proven by `examples/paydesk-react/` (in the proving repository) against its mockup, `examples/paydesk-mockup/` (screens,
states, three roles, interactions, two viewports), on the dev server and on a production build
served under the CSP; the current counts are in the README's test log. Scaffold from
`templates/app-scaffold/react-vite/` (`http.ts`, `telemetry.ts`, `query.ts`, `permissions.tsx`,
`biome.json`, `orval.config.ts`, `tsconfig.json`, `vite.config.ts` with the per-request nonce,
`package.json` with the exact pins, the env files, the headers and budget files). Two more ports prove the
design framework routes on this stack: `examples/tailwind-react/` (in the proving repository) (Tailwind 4 and two locales, against `examples/tailwind-mockup/`) and
`examples/kit-react/` (in the proving repository) (Material UI by a declared tolerance, against `examples/kit-mockup/`).

Apply [../frontend-defaults.md](../frontend-defaults.md) and
[../api-integration.md](../api-integration.md) throughout; this file adds only what is specific to
the stack. The code it describes (the test setup, `renderApp`, the money field, the grid, the tests
every app writes) is in [react-vite-patterns.md](react-vite-patterns.md), taken from the proven
ports.

## Libraries

Versions are not listed here because they go stale. The scaffold's `package.json` holds the exact
pins the proven apps run (`scripts/test/app-scaffold.test.mjs` keeps it level with them); a library
the app adds takes the newest release at least 14 days old, pinned exactly, with the lockfile
committed.

| Concern | Choice |
|---|---|
| Build | Vite with `@vitejs/plugin-react` |
| Language | TypeScript, `strict`, `noUncheckedIndexedAccess`; typecheck is `tsc -p .` |
| UI | React |
| Routing | `react-router`, declarative mode (`BrowserRouter`, nested `Route`, `Outlet`) |
| Server state | `@tanstack/react-query`, through Orval's generated hooks only |
| Tables | `@tanstack/react-table` (v9: `useTable`, explicit `tableFeatures`), manual sorting, column visibility |
| UI state | `useState` in the page; context only when two routes share it |
| API client and mocks | Orval (`react-query` client, fetch mutator, MSW mocks, Zod schemas); MSW |
| Styles | global `tokens.css` and `base.css`; a CSS Module per component. With a design framework, as it says: Tailwind through `@tailwindcss/vite` on the copied `tailwind.css`; a js-kit's components behind adapters with the mockup's props, our own parts in CSS Modules ([../design-frameworks.md](../../../mockup/references/design-frameworks.md)) |
| Strings | `i18next` and `react-i18next`, loading `src/locales/` as `import-mockup --only strings` writes it (below); `--flat` with `keySeparator: false` when a key is also a prefix of another |
| Telemetry | OpenTelemetry web SDK, OTLP exporters, loaded on demand |
| Page tours (tours-help) | `driver.js`, bundled; started by `lib/usePageTours.ts` in the layout |
| Lint and format | Biome, plus `scripts/check-frontend.mjs` |
| Tests | Vitest, jsdom, Testing Library, `user-event`, MSW in Node |
| Package manager | npm 11 or later |

## Layout

```
api/openapi.yaml               the contract (drafted from the mockup, or the backend's)
orval.config.ts
scripts/check-frontend.mjs     copied from the skill, byte for byte (the engine copy is Biome-formatted)
src/
  main.tsx                     telemetry, mocks in dev, QueryClientProvider
  App.tsx                      SessionProvider, layout route, routes from routes.tsx
  routes.tsx                   every route with its permission; the menu is built from it
  api/http.ts                  the mutator: base URL, timeout, cookie, CSRF, ApiError
  api/generated/               Orval output, gitignored
  mocks/fixtures.ts            the mockup's fixtures, typed by the contract
  mocks/handlers.ts            generated handlers with fixture overrides, scenario gate
  mocks/browser.ts             setupWorker
  lib/format.ts                mirrors MK.format exactly
  lib/permissions.tsx          SessionProvider, useSession, useCan, Can, RequirePermission
  lib/useDelayed.ts            skeletons wait 200ms
  lib/useDebounced.ts          search waits 200ms
  mocks/csv.ts                 CSV as the server must write it, pinned by a test
  lib/query.ts                 QueryClient: retry policy, error reporting
  lib/telemetry.ts             OpenTelemetry, reportError, redact
  styles/tokens.css, base.css  from the mockup (utility-css: tokens.css and tailwind.css)
  components/{primitives,composites,domain,layout}/<Name>/<Name>.tsx + <Name>.module.css
  pages/<Name>Page.tsx
tests/                         every test, at the path its subject has under src/
  support/setup.ts             MSW server, mock state per test, jsdom stand-ins
  support/render.tsx           renderApp(path): the whole app on a memory router
  pages/TransactionsPage.test.tsx, lib/format.test.ts, ...
```

Tests never sit beside app files: `src/` holds only what ships, so a reader, a bundler and a
coverage report see the app alone. Tests import their subject as `@/lib/format` (a Vite alias and
a `paths` entry in `tsconfig.json`) and their helpers relatively. `check-frontend` rule
`test-location` fails a test, spec, `__tests__`, `__mocks__` or `test/` folder inside `src/`.
`tests/support/setup.ts` and `tests/support/render.tsx` are in react-vite-patterns.md:
[the setup](react-vite-patterns.md#test-setup) and
[`renderApp`](react-vite-patterns.md#rendering-the-app-in-a-test).

## Mapping

| Mockup | React |
|---|---|
| `MK.component('X', fn, { layer })` | `components/<folder>/X/X.tsx` (folders `primitives`, `composites`, `domain`, `layout`), `export function X(props: XProps)` |
| `/* X */` block in `components.css` | `X.module.css`, rules unchanged except global utilities wrapped as `:global(.name)`; `s['x__el']` |
| Global classes (`.stack`, `.card`, `.button`) | `className="stack"` |
| `data-component` stamped by the runtime | written on the root element; a wrapper adds none |
| `${cond ? A : B}`, `${list.map(fn)}` | JSX ternary, `.map` keyed by entity id |
| Markup passed as a prop | `ReactNode` prop |
| `layout: 'AppLayout'` | layout route rendering `<Outlet />` inside an `ErrorBoundary` |
| `route` with `:id`, mockup `?id=` | `<Route path="/x/:id">`, `useParams()` |
| `<a href="./x.html?id=1">` | `<Link to="/x/1">`; `NavLink` where the mockup sets `aria-current` |
| `MK.shell` nav, keys, palette | `routes.tsx` with `nav` labels; shortcuts and palette state in `AppLayout` |
| `needs.permission` | `permission` on the route in `routes.tsx` |
| `needs.uses` | `<Can permission>` around the control |
| `allowed_actions` checked in `render` | `t.allowed_actions.includes('refund')` from the API |
| `<dialog data-modal>` | `<dialog>` with a ref and `showModal()` in an effect; `onCancel` closes |
| `ctx.focus(id)` | a ref and `.focus()` (for example back to the search trigger) |
| `state` | `useState` per field |
| `actions.name(state, e, el)` | handler; `el.dataset.value` becomes a typed argument |
| Action named in a component prop | callback prop (`onChange`) |
| `load(fixtures, { state })` | the generated hook (`useListTransactions(params)`) with the page's state as its params, `placeholderData: keepPreviousData`. Filters and sort live where the mockup keeps them: in the URL where it reads them from the URL, else in page state; never add URL state the mockup lacks |
| `status === 'loading'`, `'error'` | `query.isPending`, `query.isError` |
| `title` | `document.title` in an effect |
| Action marked `data-todo` | same element, a handler that logs `[todo]`, a `TODO(mockup)` comment naming the gap |
| `MoneyField` with `data/money.js`, the shell's `moneyInput` and its `MK.onRender` caret hook | `lib/money.ts`; a controlled input whose `onChange` counts the digits before the caret, writes the regrouped value and calls `setSelectionRange` in the handler itself (an effect loses the caret when the value does not change), then reports the digits; a hidden input carries `name` and the minor units ([the code](react-vite-patterns.md#money-field-caret)) |
| ARIA grid: `PermissionGrid` with `data/grid.js`, the page's `cell` state, `gridKey` and `gridClick` | `lib/grid.ts`; the active cell in the grid component's `useState`, roving `tabIndex`, `onKeyDown` on the table calling `gridMove` and `preventDefault`, focus by ref in an effect after a handled key only (never on mount); a cell's `onClick` sets it ([the code](react-vite-patterns.md#permission-grid-roving-focus)) |
| `window.listQuery(rows, { search, filters, sort, cursor, limit })` in `load` | the query state in `useState` (a state function becomes the initialiser), with the `next_cursor` of each page followed; a pure mapping onto the generated hook's params (`q`, `min_amount`, `sort`, `cursor`, `limit`, empty values left out), `placeholderData: keepPreviousData`; the helper itself, ported unchanged, runs in the mock API (`examples/starter-react` (in the proving repository)) |

## Gotchas found while proving the example

The stack-neutral ones (npm, MSW, OpenTelemetry, Biome, Orval, Zod, `Intl`, jsdom, test isolation)
are in [../frontend-defaults.md](../frontend-defaults.md#gotchas-on-every-stack); these are React's
or Vite's.

- **Biome reformats CSS Modules onto several lines.** Edit them with the editor, not a one-line
  `sed`, or the edit silently misses: the visual diff caught exactly that as a 72px height change.
- **`vite preview` reads `process.env`** for the telemetry origin in `connect-src` only if the
  config reads it explicitly.
- **`StrictMode` runs effects twice in development, and keeps refs between the two runs.** Keep side
  effects out of render. A "first run" ref breaks: the layout skipped the `h1` focus on the first
  run with one, so the second run saw it cleared and focused the heading on every fresh dev load.
  No gate caught it: the heading's outline is removed by design, and the tests did not render under
  `StrictMode`. Compare with the last path instead (`lastPath.current === pathname`), and turn
  `StrictMode` on in the tests with `configure({ reactStrictMode: true })` in `setup.ts`, plus a
  test that the first load leaves focus on `document.body`
  ([the code](react-vite-patterns.md#focus-on-the-page-heading)).
- **The mockup's own markup trips two Biome recommended rules**, and both are expected:
  `<form role="search">` (`lint/a11y/useSemanticElements`) and a scrolling table `section` with
  `tabIndex={0}` (`lint/a11y/noNoninteractiveTabindex`). Keep the markup, which the visual diff
  and the DOM oracle compare, and suppress each with a reason on the line before, as the examples
  do:

  ```tsx
  // biome-ignore lint/a11y/useSemanticElements: the mockup's form role="search" is the landmark; a <search> wrapper would change the markup
  <form className="stack" role="search" aria-label="Filter invoices" onSubmit={applyFilters}>

  // biome-ignore lint/a11y/noNoninteractiveTabindex: a scrollable region must be reachable by keyboard (WCAG 2.1.1)
  <section data-component="DataTable" className={s['data-table']} aria-label={caption} tabIndex={0}>
  ```

  A `//` comment works where the element is the root of an expression (after `return (`); inside
  JSX children it is `{/* biome-ignore ... */}`.
- **A global utility inside a CSS Module is hashed away** unless written `:global(.numeric)`. The
  splitter that turns `components.css` into modules does this; if a module is written by hand,
  check it.
- **The mockup re-renders by replacing DOM; React keeps elements.** The runtime now keeps focus,
  caret and scroll positions so the two match, but if a diff shows a scroll or focus difference
  after a step, suspect this first.
- **Import global CSS before any component.** Vite orders CSS by import order, so `main.tsx`
  imports `tokens.css`, `base.css` and third-party sheets (driver.js, then `tours.css`) first. When
  `base.css` came after the component modules, `.card` overrode a component's own padding.
- **A tour effect must not cancel its own start.** Navigating to drop `?tour=` re-runs the effect;
  a cleanup that cancels the pending frame then stops the tour from ever starting. The hook keeps
  per-visit state in a ref instead, which also survives `StrictMode`'s double effects.

## Strings and locales

`import-mockup --only strings` (i18next is this stack's default) writes `src/locales/<locale>.ts`
and `src/locales/index.ts` with `LOCALES`, `DEFAULT_LOCALE` and `messages`. The app:

- **Initialises i18next once**, before the first render, with `resources` built from `messages`,
  `lng` from the locale chosen, `fallbackLng: DEFAULT_LOCALE`, and `interpolation.escapeValue: false`
  (React escapes). The mockup's `{name}` placeholders become i18next's `{{name}}` in the import.
- **Sets `<html lang dir>`** from the active locale on start and on every change, as mk.js does.
- **Formats through the active locale**: `lib/format.ts` takes the locale i18next reports, so dates,
  numbers and money change with it, as `MK.format` does. Test it against `MK.format` itself, loaded
  in a vm, and every key at counts 0, 1, 2 and 5 against `MK.t`: that is what proves the strings
  ([the test, and its gotchas](react-vite-patterns.md#format-helpers-against-the-mockup-runtime)).
- **Honours `?locale=<code>` and `?locale=pseudo` where mocks run** (dev and the mocked build), never
  in production. Pseudo is built at start as a resource set: each message of the default locale
  through the same accenting and padding as mk.js's `pseudoize`. Not an i18next post-processor: it
  would also accent the values interpolated into a message, which mk.js leaves alone.

## A kit that injects styles: the per-request nonce

A CSS-in-JS kit (Material UI's emotion) inserts `<style>` elements at runtime. Under `style-src
'self'` they need a nonce, and a nonce is only a defence when it changes on every response:

- Mark the place in `index.html` with Vite's `html.cspNonce` placeholder and give emotion's cache
  the nonce from a `<meta property="csp-nonce">` tag (`createCache({ key, nonce, prepend: true })`).
- `vite preview` serves a fixed file, so a small preview middleware writes a fresh nonce into the
  CSP header and the meta tag on each HTML response (the scaffold's `vite.config.ts` has it and
  `html.cspNonce`; a kit adds `{nonce}` to the headers file and reads the meta tag). Production needs the same at its server or
  edge: a static file host that cannot rewrite the response cannot serve this kit under a strict
  CSP. Record that in the gaps, owner the deploy (keel `setup-deployment`).
- Plant it: an empty nonce must fail the quality check and the production visual diff (both now run
  under the page's CSP).

## Gotchas from the design framework proofs

- **React Router's `Link` writes `data-discover`**; pass `discover="none"` or the DOM oracle counts it.
- **React keeps `selected` on the first `<option>`** where the mockup moves it. Key the `<select>` on
  the applied value so it re-renders, or the DOM oracle shows the difference.
- **Tailwind's scanner makes classes from words in code** (`static` in an error boundary gave
  `.static`): harmless, but compare the built sheet's selectors with the mockup's vendor sheet once.
  Keep `index.html` free of classes: it is not under `@source`.

## Done when

`npm run typecheck`, `npm run lint`, `npm test` and `npm audit --audit-level=high` are clean; the
visual diff passes against the dev server (`npm run dev`, Vite's 5173); and `npm run build:mocked`
(`vite build --mode mocked`, into `dist-mocked`: the scaffold's `vite.config.ts` sets
`build.outDir` per mode, `dist-mocked` in mocked mode and `dist` otherwise, so the production build
the bar hashes never holds the mocks) served by `npm run preview:mocked` (`vite preview --mode
mocked`, 4173) passes both the visual diff and the quality check. Build-time variables, all public: `VITE_API_BASE_URL` (default `/api`),
`VITE_OTEL_EXPORTER_OTLP_ENDPOINT` (unset: telemetry off), `VITE_APP_ENV`, and `VITE_ENABLE_MOCKS`
(`true` only in the mocked build). Then the production bar
([../production-bar.md](../production-bar.md)), met on this stack as on Vue and Next.js:
`security-headers.json`, `perf-budget.json` and `staging-flows.json` start from the app scaffold,
and `examples/paydesk-react` (in the proving repository) keeps its stub server (`scripts/stub-staging.mjs`) and its records in
`docs/production/`.
