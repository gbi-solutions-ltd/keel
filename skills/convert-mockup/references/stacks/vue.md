# Stack: Vue and Vite (`vue`)

What this stack is proven on, and what not yet: [vue-gotchas.md](vue-gotchas.md#proof-record); the numbers are in the README's test log.

Read [vue-gotchas.md](vue-gotchas.md) when the gate fails or the port goes beyond a slice: the runtime table, template whitespace, the gotchas, the DOM oracle, gate config and parallel porting.

For a port of more than a slice, read [../large-ports.md](../large-ports.md) too.

Apply [../frontend-defaults.md](../frontend-defaults.md) (its [stack-neutral gotchas](../frontend-defaults.md#gotchas-on-every-stack) included) and
[../api-integration.md](../api-integration.md) throughout. Scaffold from `templates/app-scaffold/vue/`
(`http.ts`, `telemetry.ts`, `query.ts`, `session.ts`, `biome.json`, `orval.config.ts`, the tsconfigs,
`vite.config.ts` with the per-request nonce, `package.json` with the exact pins, the env files, the
headers and budget files).

## Libraries

The scaffold's `package.json` holds the exact pins the proven apps run; a library the app adds takes
the newest release at least 14 days old, pinned exactly, lockfile committed.

| Concern | Choice |
|---|---|
| Build | Vite with `@vitejs/plugin-vue`, from `templates/app-scaffold/vue/` (no ESLint, no Prettier: Biome replaces both) |
| Language | TypeScript, `<script setup lang="ts">`. Typecheck runs `vue-tsc --noEmit -p <config>` once per tsconfig (app, vitest, node): the scaffold's root tsconfig is `files: []` plus references, so a bare `vue-tsc --noEmit` checks nothing. Prove it with a planted `const x: number = 'x'`. TypeScript stays on the scaffold's 6.x pin, with its vue-tsc: vue-tsc 3.3 resolves `typescript/lib/tsc`, which TypeScript 7's `exports` does not define (`ERR_PACKAGE_PATH_NOT_EXPORTED`). Compatibility with its peers beats the newest-release rule |
| Routing | `vue-router` |
| Server state | `@tanstack/vue-query`. Reads through Orval's generated `useX` hooks. Writes call the generated request function inside `useMutation({ mutationFn })`, because the generated `usePostX` hooks fix request options (headers) when they are created, and each write needs its own per-intent `Idempotency-Key` (same details reuse the key, new details get a new one). Reads retry only `ApiError.retryable` failures, at most 3 times; writes never retry |
| Tables | a `DataTable` composite in plain template (`v-for` rows, `cell-<key>` and `head-<key>` slots) when sorting and paging are the API's, as in the mockup. Add TanStack Table's Vue adapter (`@tanstack/vue-table`) only for client-side sorting, grouping or virtualisation, and check its current major's API first |
| Dialogs | native `<dialog>` in a `Dialog` composite (see the runtime table, [vue-gotchas.md](vue-gotchas.md#runtime-behaviour-and-patterns)) |
| UI state | `ref` in the page; a Pinia store only when two routes share it |
| API client and mocks | Orval with `client: 'vue-query'`, the same fetch mutator, MSW mocks, Zod schemas |
| Styles | global `tokens.css` and `base.css` in `main.ts`, then the mockup's `components.css` byte-copied to `src/styles/components.css` and imported once, after them; no `<style scoped>` for ported components. A rule the port adds (an inline style turned into a class, see [Gotchas](vue-gotchas.md#gotchas-to-watch)) goes in a sheet imported after `components.css` |
| Strings | vue-i18n in Composition mode (`legacy: false`), messages from `import-mockup --only strings`. A mockup with a key that is also the prefix of another (`x.approve` and `x.approve.label`) cannot nest: import with `--flat` and give `createI18n` `messageResolver: (table, key) => table[key] ?? null`, so each key is read whole. The esm-bundler build compiles messages at run time without `eval`, so it runs under `script-src 'self'` (proven, quality check under the CSP); set `__VUE_I18N_FULL_INSTALL__`, `__VUE_I18N_LEGACY_API__` and `__INTLIFY_PROD_DEVTOOLS__` to false in Vite's `define`. Prove every key with a test that renders it through vue-i18n and through the mockup runtime's `MK.t` and compares |
| Telemetry | `lib/telemetry.ts` from the scaffold, framework free; report from `app.config.errorHandler` |
| Lint and format | Biome 2.6 with `html.experimentalFullSupportEnabled: true`, `html.formatter.enabled` and `html.linter.enabled`: it lints and formats `<template>` as well as `<script>`. Its formatter is whitespace sensitive (see [Template whitespace](vue-gotchas.md#template-whitespace)), so leave it on, but prove it on the first component with inline siblings: render it in Vitest before and after `biome format --write` and compare `container.innerHTML`. Keep the Vue domain (`linter.domains.vue: "recommended"`) and `nursery.noVueVHtml: "error"`. Exclude the byte-copied `tokens.css`, `base.css` and `components.css` (Biome reformats them; check with `cmp`) and a large vendored contract. Do not exclude Orval's output: `formatter: 'biome'` formats it on each generation, and an override switches only its linter off ([../api-integration.md](../api-integration.md), Orval configuration; `check-frontend.mjs` checks it). Plus `check-frontend.mjs`, which still scans the copied sheets |
| Tests | Vitest, jsdom, `@testing-library/vue`, MSW in Node; in `tests/` at the app root, mirroring `src/`, as React. A render helper over a memory router must set the history's location before the router starts (`const h = createMemoryHistory(); h.replace(path)`): the router's install begins its own first navigation at the history's location, `/`, and a `push(path)` races it (in the second app, every test at a path other than `/equipment` failed until this, and so did a check of the nav's `aria-current` at `/equipment` itself). `tests/support/renderPage` renders the real route table, guard and titles with a query client that does not retry |
| Install scripts | Deny `vue-demi`'s and `fsevents`' in `allowScripts`, as esbuild's: vue-demi's shipped build already targets Vue 3 |

## Layout

As [React](react-vite.md#layout), with `components/<layer>s/<Name>.vue`, `layouts/` merged into `components/layout/`,
`pages/<Name>Page.vue`, and `router/index.ts` holding the route table with a `meta.permission` on
every route and a global `beforeEach` guard that refuses a route with no `meta.permission` and sends a 401 to
sign-in. A signed-in role without the permission still opens the route: the layout checks
`can(me, route.meta.permission)` and draws the designed no-permission page in the page's place, at the same URL,
as the mockup does. The guard loads the session read with the same query key and fetcher as the `useSession` hook, so both
read one cache entry.

Two shapes are proven; pick one per app and say which in the conversion plan. **The layout as a parent
route** with `<RouterView />` in its `<main>` (the Mapping row; `examples/equipment-loans-vue` (in the proving repository), `tailwind-vue`,
`vuetify-vue`): the simple default, and right when the layout draws the refusal in the page's place, so the
page never mounts without its permission. **The layout as the page's root**, for an app whose pages hand the
layout props or slots of their own (the first full port): a page's template root is its layout component
(`<AppLayout>` or `<AuthLayout>`) with the page body in the
default slot: no wrapper element and no `data-component` of its own, so the DOM is the mockup's
`#app > .app-layout`. In this shape, split a page that reads data into a thin route component (`pages/XPage.vue`: the layout
and one child) and a body (`pages/x/XBody.vue`, every read). When the role lacks the route's permission the
layout draws the refusal in the slot's place, the body never mounts, and no data request is made; test that.

Type `RouteMeta` (`declare module 'vue-router'`) and carry each page-level fact the mockup gives the shell in
route meta, never in a prop chain: `permission` (required; `'public'`, `'authenticated'` or a code), `title`
(the document title, set in a `router.afterEach`), `focusFallback` (the id the layout writes as
`data-focus-fallback`), and `help` (`{ title, steps, tips? }`, the page's help-sheet recipe, MK.page `help`). Add a field for any other
page-level fact the mockup's shell reads (a page whose widgets load on their own, so a whole-page loading preview
does not apply to it), and when a fan-out agent reports a seam it needs from the shell.

## Mapping

| Mockup | Vue |
|---|---|
| `MK.component('X', fn, { layer })` | `components/<layer>s/X.vue` with `defineProps<Props>()` |
| `/* X */` block | stays in the global `components.css`, unchanged and in its original order |
| `data-component` | on the single root element of the template; one root per component. A mockup component that only renders another (StatusBadge renders Badge, ErrorState renders EmptyState) has the inner one's root and no `data-component` of its own, as in the mockup, where it returns the inner component's markup; a page has none (see Layout) |
| `${list.map(fn)}`, `${cond ? A : B}` | `v-for` with `:key`, `v-if` / `v-else` |
| Markup passed as a prop | a slot |
| `layout` | parent route component with `<RouterView />`, or the page's root (Layout, both shapes) |
| `route` with `:id` | `{ path: '/x/:id', meta: { permission } }`, `useRoute().params.id` |
| `<a href>` | an `AppLink` primitive: `<RouterLink custom v-slot="{ href, navigate }">` rendering a plain `<a :href @click="navigate">`. RouterLink's own anchor adds `router-link-active` and `router-link-exact-active` classes the mockup's DOM does not have, and sets `aria-current="page"` on every exact-active link, which can be several at once (side nav, crumb, a tile). The mockup sets `aria-current` only where its markup says so (the current side-nav link), so the caller binds `aria-current` from the mockup's rule (the side nav's matched route) |
| `state`, `actions` | `ref` per field; functions bound with `@click`, `@change`, `@submit.prevent` |
| Action named in a component prop | `defineEmits` |
| `load` | the generated `useX` hook; `isPending`, `isError` are refs |

## Mock-only facts

The mockup draws facts the contract does not serve (a demo persona panel, a phone ending before sign-in, a
donut's centre figure, an approver's name). Never add a non-contract field to a mock response. Put them in
`src/mocks/demo.ts`, load them only through `lib/demo.ts` (a dynamic import) behind a static
`import.meta.env.VITE_ENABLE_MOCKS === 'true'`, and give production a contract-only fallback, tested. Mockup-only chrome
(a demo bar) is drawn behind the same check.

Check it: `npm run build`, then grep the content of `dist/` for fixture names and fixture-only strings (persona
names, usernames, demo passwords). Expect none; record any hit that is real app copy. The grep is on content,
not file names: the bundler may name a shared chunk after `lib/demo.ts` (`demo-*.js`) without the mock in it.
Page tests that need demo facts use `vi.stubEnv('VITE_ENABLE_MOCKS', 'true')`, which `loadDemo()` reads at call time.

Build the mocked build into its own folder (`build.outDir: 'dist-mocked'` in mocked mode), so the grep runs on a
`dist` that never held mocks. Pages of static product copy (help, tour content) draw the mockup's loading and
error states only in a mocked build; production draws the copy at once and makes no read.

## Done when

As [React](react-vite.md#done-when): typecheck, lint, tests and audit clean; visual diff passing on
the dev server (`npm run dev`); and a mocked production build (`npm run build:mocked`, into
`dist-mocked`, served by `npm run preview:mocked`, that is `vite preview --mode mocked`) passing the
visual diff and the quality check under the security headers. The build-time variables are React's
(`VITE_API_BASE_URL`, `VITE_OTEL_EXPORTER_OTLP_ENDPOINT`, `VITE_APP_ENV`, `VITE_ENABLE_MOCKS`, in
the scaffold's `env.d.ts`).
Then the production bar ([../production-bar.md](../production-bar.md)): the same scripts, proven on a Vue app
(`examples/equipment-loans-vue` (in the proving repository)). Serve the production build behind the sample backend with
`APP_DIR=<the app>` on the compose command line; `staging-run.mjs`, `headers.mjs --check` and `perf-budget.mjs`
need nothing Vue-specific.

A case that differs because the contract's data differs from the mockup's (a longer identifier) gets an entry in
an expected-diffs file passed with `--expected` (app mode reads none unless it is named), each with its reason,
at the measured value, rounded up to two decimals. A case that differs because of a recorded user decision gets an
entry the same way, naming the decision. Its limits: a `screens[].size` entry is refused in app mode, where a size difference is
padded and counted as mismatch; an entry is capped at 5%, and masks at a share of the first screen. When a
difference reflows the page past that (a mobile title wrapping onto a second line), prove that it is the only
difference: run the gate once with the mock's data shaped like the mockup's (numbers padded to the mockup's
width), record that result beside the real one, revert, and report the uncovered case as a recorded deviation.

## Design frameworks

The Vue notes for a design framework (vue-i18n, Tailwind, Vuetify, reka-ui, cleanup) are in [../design-frameworks.md](../../../mockup/references/design-frameworks.md#vue), under Framework notes.
