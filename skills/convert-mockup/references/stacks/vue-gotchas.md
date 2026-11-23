# Stack: Vue gotchas, runtime patterns and the gate

The rest of [vue.md](vue.md). Read it when the gate fails, or when the port goes beyond a slice.

## Proof record

**Proven on one full port**: a slice first (sign-in, reset password, not found, the shell and its overlays, a
home per role, one list with its detail, new and edit pages) met Done when, then the whole app (about 100 pages)
in six waves, every remaining failure a named one with a measured cause. The markers in the runtime table record
what the slice measured; the full port used most rows on many more pages without contradicting them. After that,
every page moved onto the client's component library and vue-i18n: see [Framework notes, Vue](../../../mockup/references/design-frameworks.md#vue).

**Proven through the production bar on a second app** (`examples/equipment-loans-vue` (in the proving repository), the twin of
`examples/equipment-loans-app` (in the proving repository) from the same signed-off package): the contract, fixtures, styles, nav and strings
imported with `import-mockup` and held by `--check`; Orval's vue-query client; then staging against the sample
backend on Postgres, headers, the performance budget and the security audit. Not proven on Vue: an API on another
origin (that app's BFF is same origin).

**The direct route onto a design framework is proven on Vue**, for both kinds: Tailwind 4 with vue-i18n in two
locales (`examples/tailwind-vue` (in the proving repository)) and Vuetify 4 (`examples/vuetify-vue`, from the Vuetify-calibrated
`examples/vuetify-mockup` (in the proving repository)). The numbers are in the README's test log.

## Runtime behaviour and patterns

Rows the slice measured say so; correct the others on the next port.

| Mockup | Vue |
|---|---|
| morph keeps focus, the caret and scroll by keeping elements whose position, tag and id match | (rendered at 0%, behaviour not gated) Vue's patching keeps elements the same way; give `v-for` rows a stable `:key` (never the index) or focus and the caret jump to another row. Keep the ids `ctx.focus(id)` targets; they are in the mockup's DOM, so the port renders them anyway |
| morph shows what the markup says: a textarea's text, a select's `selected` options, an input's `value` (so typed text lives in state) | (proven) `v-model` (or `:value` with `@input`) on each control for behaviour. On an input, `:value` (and `v-model`) writes the attribute as well as the property (measured on Vue 3.5.45), so the input's DOM matches the mockup's with no extra binding. A textarea is the exception: the mockup writes its text as content, and a `:value` binding adds a `value` attribute the mockup lacks. Write the text with `v-text` and set the property from a template ref in a `watch` (corrected 2026-11-21: this row said Vue sets the property only, and asked for `^value` too, which the second app did not need on Vue 3.5.45). On the chosen option `v-bind="on ? { '^selected': '' } : {}"`, with a `watch` keeping the select's value in step. A password input writes `value=""`. This matters for the DOM oracle and for pixels after a refusal: mk.js `morph` sets an input's value from the re-rendered attribute, so the mockup clears a field the port must clear too |
| `ctx.focus(id)` after an action | (proven) the same id: `await nextTick(); document.getElementById(id)?.focus()` (a shell store `focus(id)` when the shell owns the move). Focus is pixels: every `ctx.focus(id)` paints a focus ring the capture sees, so the port must focus the same element at the same moment. A template ref is fine inside one component; across components the id is the seam. Menus return focus to their button as the mockup does, except on click outside or when an overlay opens from the menu |
| `MK.onRender(fn)` in the shell (MoneyField's caret, focus fallbacks) | (unproven) a `watch` (with `flush: 'post'`) or `onUpdated` in the layout; a hook that serves one component (the caret) moves into that component, after `nextTick` |
| `load` and its `status` | (proven) Orval's `vue-query` hooks return refs (`data`, `isPending`, `isError`): read them with `.value` in script and bare in the template; pass reactive query params (a `computed` or a getter) so a filter change refetches |
| `?state=empty\|loading\|error` and the page's `load` | (proven) the mock applies the scenario only to the reads the mockup's page `load` makes (the list read, the dashboard read, a number lookup). The session read, the shell's reads (counts, scopes, notifications) and side reads the mockup draws during loading and error ignore it, or no frame renders. Decide per page which read carries it and write it in the page's handler; a page with no `load` ignores `?state`. `loading` holds the request open (`holdOpen`; the gate's settle waits at most about 4 s for it, never a failure); `error` answers the contract's error shape. With `?state=error` pinned, the query client does not retry. Draw the frame only when every read the closed frame shows has landed (`v-if="me && counts"`), so no capture shows a half-drawn shell |
| `FMT.ago`, "today", a default date, a freshness window (the mockup's fixture now) | (proven) the business now: the response envelope's `timestamp` (the mock serves the fixtures' `format.now`), passed in: `ago(iso, now)`, a default document date, a step-up window. Never `Date.now()` or `new Date()` for a business fact: the gate's `--clock` pins the browser, and the fixtures' now is a different instant (in the first port they were a month apart). Prove it with a negative control: switch one age to the browser clock and watch its case fail |
| shell `state` and `actions` | (rendered at 0%, behaviour not gated) state one layout uses: `provide`/`inject` from the layout (`InjectionKey`, typed); state two routes or the header share (menus, a palette, the idle warning): a Pinia store. The shell's store (`stores/shell.ts`) holds menus, overlay state, `focus(id)`, the toast and the open-modal registry. Preview chrome links (a mockup's simulate or scenario switches) are plain `href`s, full page loads, as the mockup's are, so the boot capture of `?as` and `?state` runs again |
| shell or page `state: ({ params }) => ({ ... })`, the layout's `params` | (proven) `useRoute().query`, read once into the initial `ref` (a seed), or a `computed` when nothing changes it. Page and shell preview flags (`?session=expiring`, and any the project's mockup adds) are read this way, in a mocked build only |
| the visual diff's `?as=<role>` and `?state=<name>` | (proven) `lib/preview.ts` `capturePreview()`, called once in `main.ts` before the mock worker and the router start (a redirect can drop the query). `?as` is kept in `sessionStorage` for the tab, because in-app links do not carry it; `?state` holds for that page load. Both behind a static `import.meta.env.VITE_ENABLE_MOCKS === 'true'`, so a production build answers null. Only the mock layer reads them; page code never does |
| a page the mockup reloads on a query or param change (`?step=code`, `/:token`) | vue-router keeps the same component instance, so reset the page's local `ref`s in a `watch` on that query or param; the mockup did a full page load there |
| a full page load starts at the top | (proven) a router `scrollBehavior`: the saved position on back and forward, the top on a new path, unchanged on a query or hash change (a sheet or tab in place) |
| what a full page load drops (a toast, page state, a preview role in `sessionStorage`) | a single-page app keeps it across navigation. Decide each one (keep, or reset in a route `watch`) and record it |
| tours (driver.js, the tours-help module) | (proven) pin the exact driver.js version the mockup vendors and check its dist files are byte-identical to the mockup's copies; load `driver.css` and the tours sheet after `components.css`. Split pure rules (`lib/tours.ts`), the driver.js adapter (`lib/tourDriver.ts`) and a layout composable (`useTours`). Ready means `queryClient.isFetching() === 0 && isMutating() === 0`, then 100 ms with no `MutationObserver` change in `#app`, capped at 5 s; no tour starts over a failed read. The mockup runtime's re-render repair is not needed |
| shell `keys` (chords fire in fields, bare keys do not) | (proven, `examples/equipment-loans-vue` (in the proving repository)) one `keydown` listener in the layout (`onMounted`, removed in `onUnmounted`), with the same rule: skip a bare key when the target is an input, textarea, select or contenteditable, or when Ctrl, Cmd or Alt is held |
| `<dialog data-modal>` with `data-action="x" data-on="cancel"` | (proven) a `Dialog` composite on a native `<dialog>`: `showModal()` on mount, the caller adds and removes it with `v-if`, the native `cancel` is always prevented and emitted as `cancel` (close button and Escape), and a `locked` dialog drops the close button but still emits `cancel` on Escape. A shell toast raised while a modal is open goes into the topmost modal's toast host |
| markup passed as a prop (`children`, `body`, `MK.raw` content) | a slot (named when there is more than one) |
| data helper in `data/*.js` (`listQuery`, `money`, `gridMove`) | a composable (`useListQuery` holding the query state and returning the API params) or a plain util in `lib/` for a pure rule (`lib/money.ts`, `lib/grid.ts`), unit tested |
| `MoneyField` (digits in state, grouped display, hidden input for the submitted integer) | (rendered at 0%, behaviour not gated) `defineModel` holds the digits; the shown value is a `computed`; on input, recompute the digits, then put the caret back after `nextTick`. The form sends the integer from the model. Keep the mockup's `<input type="hidden" :name v-bind="{ '^value': minorUnits }">` anyway: it is in the mockup's DOM, so the DOM oracle expects it |
| ARIA grid (`PermissionGrid`, roving tabindex, `data/grid.js`) | (unproven) the active cell is a `ref` in the grid component; `:tabindex="active ? 0 : -1"`; `@keydown` calls `gridMove`, `preventDefault` for a key it handles, then focuses the cell's ref after `nextTick` |

## Template whitespace

Vue's compiler (`whitespace: 'condense'`) drops a whitespace-only text node between elements when it holds a
newline. The mockup's template strings keep it. Between inline or inline-block siblings that is a visible gap, so:

- **Reproduce the mockup's spaces exactly** between inline siblings: same line, or an explicit `{{ ' ' }}`
  (Biome may then wrap it as `{{ ' '\n }}`, which is still one space).
- **Flex and grid containers do not render whitespace** between children, so most shell markup (bars, menus,
  toggles) is safe. Text after an icon keeps its leading space (`<Icon /> Scenarios`).
- **Biome hugs inline content** rather than adding a space (`<label\n  >{{ label }}<span>*</span></label\n>`), and
  its new lines sit where condense drops them. Where its wrapping puts whitespace at the edge of a text node (a
  short button label on its own line), nothing renders differently: edge whitespace inside a button or a flex
  item draws no pixels, and the DOM oracle counts it as edge lines, apart from diff lines. Writing the label as an
  interpolation (`{{ 'Save view' }}`) or with `v-text` keeps the oracle at zero lines; it is optional. Only
  spaces between inline siblings must be fixed.
- **Except text that runs on after an inline element** (proven): Biome can move the text after a
  closing `</span>` onto its own line, which Vue keeps as one space ("orders.export . Submit"), and it
  undoes a hand-written `</span\n>text` hug. Write such a run as one interpolation (`` {{ `${a}. Submit` }} ``) or
  `v-text` on its element. Where neither fits, put `<!-- biome-ignore format: mockup DOM parity, the gate diffs
  this markup -->` before the element. Run the DOM oracle after `biome format`: the space shows as a diff line,
  not an edge line, because it sits between siblings.
- **A text run that ends at the edge of a primitive** (`<progress>`, a `<button>` label) gets edge whitespace when
  Biome puts it on its own line; prefer `v-text` there so the oracle's edge count stays at the shell's.

## Gotchas to watch

- **Do not split `components.css` into scoped blocks.** A mockup sheet routinely styles one component from another
  (`.app-layout--rail .side-nav`, `.topbar .scope-menu`, `.data-table__cell:has(> .badge)`), and splitting it
  changes cascade order. Scoped blocks add `data-v-` attributes those selectors do not carry, so the rules stop
  matching without an error. Count the cross-component selectors before you decide; the first port had 51.
- Multi-root templates break `data-component` and scoped root styles.
- **A `{ template: '...' }` stub component renders nothing** in tests: Vue's runtime-only build has no template
  compiler. Write stubs with a render function (`h(...)`).
- **Slow page tests: preload the route module once** (in `beforeAll`) rather than raising timeouts; the first
  render otherwise pays the module's compile. Every raised timeout in the first port went this way. A heavy
  component library is the exception, see [../design-frameworks-fallback.md](../design-frameworks-fallback.md#verify-each-round).
- `v-html` is banned by `check-frontend` for the same reason as `dangerouslySetInnerHTML`.
- **Biome's a11y rules flag some of the mockup's markup** (`role="group"`, `role="region"`, `role="separator"`
  on a `<div>`: `useSemanticElements`; one `keydown` listener on a static element: `noStaticElementInteractions`;
  an SVG chart labelled by `aria-label`: `noSvgWithoutTitle`). The gate diffs that markup, so keep it and put
  `<!-- biome-ignore lint/<group>/<rule>: <reason> -->` on the line before the element. State the true reason:
  "mockup DOM parity, the gate diffs this markup" when that is all it is, the real behaviour when there is one
  (a scroll container that takes focus for keyboard scrolling, a combobox option reached through
  `aria-activedescendant`, a toast whose timer stops under pointer or focus for WCAG 2.2.1). Use a per-file
  `overrides` entry in `biome.json` only where no comment can sit before the element (Biome hugs a slot-only
  `<a>` to its `<RouterLink custom>`, and a comment inside the slot renders a node). Never turn a rule off
  project wide.
- **Which `data-*` attributes to emit.** Always emit `data-component`, `data-tour`, every `data-*` the global
  CSS selects (the first port: `[data-label=""]`, `[data-result]`, `[data-toast-host]`) and every one the port's own
  code reads (`data-focus-fallback`). Never emit `data-action`: the handler is the `@event` binding.
  The rest is the mockup runtime's plumbing (`data-on`, `data-group`, `data-tab`, `data-sort`, `data-scope`,
  `data-density`). It renders nothing. Either emit it or drop it in the oracle normaliser (the gate copy's
  `mockup.config.json`, `domOracle: { dropAttributes: [...] }`), but decide once per port and write the list down; the first port did both by component, which left diff lines to explain.
  The mockup's hidden plumbing buttons (`setChartWidths`, `closeMenus`) draw no pixels and are not ported.
- **Handlers read role and scenario per request**, never at start: `createHandlers({ getScenario, getRole,
  setRole })` with defaults from `lib/preview.ts`, and tests pass in-memory versions (`previewState()` is fixed
  at module load and is null in Vitest). The role is `previewRole()` when it names a fixture role, else the
  fixture session's.
- **`tests/support/setup.ts` `afterEach`** releases held requests (`releaseHeldRequests`), forgets the preview
  role (`resetPreview`, it lives in `sessionStorage`), clears every mock store a handler writes, and rebuilds the
  handlers. A store one test writes otherwise reaches the next.
- **A case under the threshold is not done until it is 0% or explained.** The first port's user menu passed at 0.042%;
  the cause was a wrong mock preference (`toursAutoStart`). Read each non-zero case's diff image.
- **aria booleans bind as booleans** (`:aria-expanded="open"`), not `String(open)`: vue-tsc wants `Booleanish`,
  and Vue writes `false` as `"false"` on an `aria-*` attribute (it removes `false` only on boolean attributes).
- **`Icon` cannot use `v-html`.** Generate `src/lib/icons.ts` from the mockup's icons as `{ tag, attrs }[]` per
  icon and render with `<component :is v-bind>`; check the round trip. `scripts/import-mockup.mjs` writes
  `src/lib/icons.ts` and fails the run when the round trip does not match.
- **Inline `style="..."` in the mockup** is banned by `check-frontend`: each becomes a class with the same
  declarations, in a sheet loaded after `components.css`.
- **`useVueMultiWordComponentNames`** reports one-word names (Icon, Avatar, Callout) as info. Keep the mockup's
  names; they are its `data-component` values. `biome ci` passes.

## DOM oracle

Before the first pixel run of a screen, run `scripts/dom-oracle.mjs` (proven) with the gate's arguments:
`node dom-oracle.mjs --mockup <gate-copy> --app <base-url> --clock <iso> --seed <n>`. It loads each case as the
visual diff does (route, `?as`, `?state`, steps, pins) at one viewport (desktop unless `--viewport`), dumps `#app`
`innerHTML` on both sides and diffs them after normalising: hrefs mapped to routes (`./x.html` and `/a/b` both to
a key), class lists as sets, `data-v-*` and the mk.js plumbing attributes (`data-action`, `data-group`) dropped,
comments dropped, whitespace collapsed. Attributes are read, not DOM properties, so a missing `value` or
`selected` attribute shows. Per case it reports diff lines (edge whitespace ignored, the number to drive to zero)
and edge lines (the extra a strict comparison finds: text nodes differing only in leading or trailing whitespace,
see Template whitespace), and writes both dumps and both diffs. Hidden plumbing buttons the mockup draws and the
port does not go in the gate copy's `mockup.config.json` as `domOracle: { skipHiddenActions, skipHiddenIds }`.
`--diff <a.html> <b.html>` compares two saved dumps without a browser.

Aim for zero diff lines other than known, listed differences (contract numbers, their hrefs, contract codes in
filter options). It points at a wrong attribute, a missing node or a text difference by name, where the pixel
diff points at a region; a case at 0% pixels can still differ here (a `data-on` the port omits draws nothing).
Give each fan-out agent the command and ask for its diff and edge line counts per case.

## Gate config

Run the gate on a trimmed copy of the frozen mockup with its own `mockup.config.json`; leave the mockup's config
as it is. Start with the first screens only (sign-in) to prove the pipeline, then add the rest.

- **App mode builds the app URL from `route` plus `?as` and `?state`** (the mockup side is served over HTTP). A
  screen whose mockup page carries a query (`sign-in.html?step=code&user=ada`) needs that query written into
  its `route` (`/sign-in?step=code&user=ada`).
- **Routes must be concrete and must resolve in the app.** When the contract's identifiers differ from the
  mockup's (`INV-000412` for the mockup's `INV-0412`), write the contract's into `route`; the mockup's
  resolve to "not found".
- **Prove each pin on a screen that can fail without it.** `?state`: a loading or error case at 0%. `?as`: a
  screen whose role differs from the fixture session's default (add one to the trimmed config if needed).
  `--clock`: a screen with a dated element, such as an age (see the business now row). A pass on a screen that
  does not use the pin proves nothing.
- Pass `--clock`, `--seed` and `--tz` at the values the mockup was designed with.
- **A screen whose steps provoke a refusal on purpose** (a wrong password, a locked account, an expired link)
  needs `expectStatus` (`[401]`, `[403]`, `[410]`) for the quality check, because the browser logs every failed
  fetch as a console error. So does a state screen whose read answers an error on purpose (a designed 404 under
  `?state=empty`, a 500 on a simulate screen). Add it to the trimmed config when the mockup's config lacks it.

## Parallel porting

Port the shell and one screen in the main session first, then fan out by area with the seams, ownership, briefs
and wave close in [../large-ports.md](../large-ports.md). The Vue seams: shared mock plumbing in
`src/mocks/http.ts` (envelope, problem, `holdOpen`, `MockContext`); one handler module per area,
`src/mocks/areas/<area>.ts`, concatenated by `createHandlers`; one route file per area,
`src/router/routes/<area>.ts`, spread before the catch-all; an area's store reset called from `tests/support/setup.ts`.
