# Design frameworks: porting onto Tailwind, a component kit or the client's library

A target stack is more than its core framework. A client who asks for Vue, React or Next.js usually
also names how the app is styled and built from parts: Tailwind, a component kit (Material UI,
Vuetify, Quasar, PrimeVue, Ant Design, Chakra), a headless library with a styled layer over it
(shadcn/ui on Radix, a reka-ui or Headless UI based kit), or the client's own design system. Often
i18n comes with it (vue-i18n, react-i18next, next-intl), plus the client's icon set and fonts. The
engine must build for that whole target, not only the framework.

Read this at the intake (question 2 in [intake.md](intake.md)), again before building the first
screen, and at Convert.

**Status.** The framework is asked at intake, recorded in `project.designFramework`, and the
inventory holds each kind's rules (below). Both direct routes (`utility-css`, `js-kit` with
calibration) are proven on React, Vue and Next.js example ports, and the fallback on one Vue port;
the numbers are in the README's test log.

## The framework is a tier 1 answer

It changes how the mockup is built, so it is settled before the first screen, never discovered at
Convert. The intake records it (`kind`, `name`, `version`, `owner`, `source`), validated by
[mockup-config.schema.json](../../../lib/mockup-engine/mockup-config.schema.json):

```json
"project": { "designFramework": { "kind": "css-library", "name": "<package>", "version": "3.2.0", "owner": "client", "source": "<repo or registry>" } }
```

`kind` is `none` (the mockup's own CSS), `utility-css` (Tailwind and the like), `css-library` (a design
system shipped as CSS the mockup can load) or `js-kit` (components that need a framework runtime:
Material UI, Vuetify, shadcn/ui, a reka-ui kit). `owner` is `client` for the client's own design system.

**Tokens.** With a framework, its theme is where colours, type and spacing come from, and the
mockup's `tokens.css` holds only what the framework lacks. Write the mapping (mockup token to framework
theme key) in `<docs_root>/mockups/<name>/token-map.md` as the tokens are chosen; Convert builds the
app's theme from it.

## Building the mockup in the framework

| Kind | The mockup | Checked by the inventory |
|---|---|---|
| `none` | its own tokens, `base.css` and `components.css`, as [mockup-conventions.md](mockup-conventions.md) says | the usual rules |
| `utility-css` | the framework's classes in component templates (never in page markup), and its built CSS in `assets/vendor/<name>/`. For Tailwind, build it with the CLI pinned to the version the app will use, from an input file the app will reuse (`assets/tailwind.css`: `@import "tailwindcss" source(none)`, `@import "./tokens.css"`, `@source` over `../components` and `../pages`; below). Not the in-browser build: its output is not the app's | every page loads a CSS file from `assets/vendor/` that exists (`framework-css`); no `components.css` block per component |
| `css-library` | the library's built CSS copied into `assets/vendor/<name>/` at the pinned version, its markup and class names; mockup components named as the library's where it has one, `components.css` only for what it lacks | `framework-css`, as above |
| `js-kit` | an approximation in the mockup's own CSS, each component named as the kit's (`Button`, `DataGrid`) with the kit's props, calibrated against the kit (below), and a component map (`<docs_root>/mockups/<name>/component-map.md`: mockup component, kit component, props) | the agreed tolerance declared as `diff.maxMismatchPercent`, the kit components listed as `domOracle.opaqueComponents`, and `docs/behaviours.json` present (`framework-gate`) |

Copy vendor files into the mockup rather than linking a CDN, so the mockup opens offline and a
signed-off screen cannot change under a new release.

### Tailwind in a mockup

- **The CLI needs the package beside it.** `@import "tailwindcss"` resolves from `node_modules`, and
  a mockup has none (one would put thousands of files under the inventory's scans). Keep a dot
  folder, `.tools/`, with a `package.json` pinning `tailwindcss` and `@tailwindcss/cli` at the
  app's version, and a build script that runs the CLI with `NODE_PATH=.tools/node_modules` and has a
  `--check` mode that fails when the built sheet is stale. Rebuild after every markup change.
- **`@theme` lives in `tokens.css`.** `check-frontend`'s raw-value rule allows raw values only in a
  file named `tokens.css`, in the mockup and the app alike.
- **Containers are layout components.** There are no `base.css` utilities to lay a page out with,
  and the inventory's `layer-order` judges a container by what it holds, so `Card` and `Stack` are
  `layout`, not `primitive`.
- **The app reuses the input file.** `import-mockup --only css` copies `tailwind.css` and
  `tokens.css` into `src/styles/`, where the same `@source "../components"` and `"../pages"` land on
  `src/components` and `src/pages`; the app builds it with the framework's bundler plugin at the same
  version. Same CSS on both sides is what makes 0% reachable and lets the DOM oracle compare class
  lists exactly. On Next.js the App Router has no `src/pages`: the copied `@source "../pages"`
  scans nothing, silently, so keep pages' class strings in components (or add an `@source` for
  `src/app` in the app's own input).
- **Comments are scanned too.** Tailwind's scanner takes any word in a scanned file as a candidate,
  comments included: a comment saying "the filter's kept value" put a `.filter` utility in the
  app's sheet, and `static getDerivedStateFromError` put `.static` in tailwind-react's. Check the
  built sheet's class selectors against the mockup's (`examples/tailwind-vue/scripts/check-tailwind-classes.mjs` (in the proving repository))
  and reword the comment.

### A js-kit: calibrate, then a near-zero tolerance

An approximation drawn by eye differs from the kit by a few pixels in many places, and a tolerance
wide enough to cover that also covers real defects: in the proof, 1% passed a focus bug and a wrong
label colour. So:

1. **Calibrate before the first screen is signed off.** Render each kit component the mockup
   approximates in a throwaway page of the kit at the pinned version and theme, read its computed
   styles (sizes, padding, borders, radii, shadows, type, the focus and error states), and set the
   mockup's CSS to them. Use the kit's real font files, vendored in the mockup.
2. **Declare the tolerance after calibrating**, near zero (the proof reached 0 px at the gate's
   pixel threshold), with named masks or expected-diffs entries for what cannot match (a ripple, a
   shadow's last channel value). Baseline mode keeps its own limit
   (`diff.baselineMaxMismatchPercent`; defaults in [mockup-config.md](mockup-config.md)), so the
   kit's tolerance does not loosen the mockup's own regression check.
3. **Read every non-zero case**, even under the limit. A pass under a tolerance is not a proof.
4. **List the kit components in `domOracle.opaqueComponents`.** The DOM oracle then compares each as
   one line with its copy, and everything of ours around it in full. The kit's own wrappers outside
   the component (a modal's backdrop and focus guards) still differ: record them as expected. A kit
   that teleports its dialog to the end of `<body>` (Vuetify) leaves it out of `#app` altogether:
   compare its content with a second pass, `--root '[data-component="VDialog"]'`.
5. **Write down where the real kit and the approximation part**, even under the gate's threshold,
   for the mockup's owner: hover and focus elevation, paint order of tonal underlays, attributes
   the kit does or does not write (`aria-invalid`), hidden helper rows with `role="alert"`, and
   behaviour such as a scrim click closing a dialog the native `<dialog>` keeps open. The Vuetify
   port lists six (`examples/vuetify-vue/docs/mockups/tickets/gaps.md` (in the proving repository), K-1 to K-6).

**Calibrating against Vuetify** (proven, `examples/vuetify-mockup` (in the proving repository)): Vuetify 4 puts its CSS in
`@layer`, so any unlayered rule in the mockup (or the app) beats it. Put the mockup's reset inside
the kit's own layer name (`@layer vuetify-core.reset`), or it overrides the kit's button font.
Read focus from the field's class (`v-field--focused`), which Vue applies on the next render; the
quality check waits two frames for it. A select's `<input>` takes no pointer
(`pointer-events: none`): the engine's click step falls back to a forced click at the same point,
as a person's click lands.

**Server rendering and a js-kit** (proven, `examples/kit-next` (in the proving repository)): the nonce covers elements, never
attributes, so a kit that writes `style="..."` into server-rendered markup loses those styles under
the CSP. Material UI 9 does (Paper's `--Paper-shadow`, Skeleton's width); move them into the kit's
class-based styling (`sx`); a `style` prop that only clears the kit's inline variable (so no
`style` attribute is rendered) carries a `check-frontend-allow` comment with its reason. Check the served HTML of every scenario holds no `style` attribute
(`examples/kit-next/scripts/ssr-style-check.mjs` (in the proving repository)). In the browser React sets `style` through the
CSSOM, which the CSP does not govern, so an SPA never meets this. A kit's initial load on Next.js
is heavy: Material UI with Emotion measured 280 KB of JS gzip, far above the runtime's own floor
([stacks/nextjs.md](../../convert-mockup/references/stacks/nextjs.md#budget)).

## Routes, and what proves each

| The framework is | Route | The port is proven by |
|---|---|---|
| known at intake, `none`, `utility-css` or `css-library` | the mockup is built in it; Convert ports straight onto it, the same CSS on both sides | the visual diff at 0%, the DOM oracle, behaviours (`check-behaviours.mjs` on the mockup, and the app's own tests for the same behaviours: the script does not run against an app), the quality check |
| known at intake, `js-kit` | the mockup approximates it; Convert builds on the kit | the declared tolerance, the DOM oracle on the parts we own (layout, our own composites), behaviours, the quality check. The client was told at intake that sign-off is on an approximation |
| not known until after sign-off (the fallback) | a pixel port with the mockup's CSS first, then adoption in rounds ([design-frameworks-fallback.md](../../convert-mockup/references/design-frameworks-fallback.md)) | the visual diff at 0% for the pixel port, then the isolation gate per round ([Verify](../../convert-mockup/references/design-frameworks-fallback.md#verify-each-round)) |

The fallback costs a second pass over every page. It is the right call only when the framework
arrives late; the intake exists so that it rarely does.

Read [design-frameworks-fallback.md](../../convert-mockup/references/design-frameworks-fallback.md) only on the fallback route: the rules that change, the order of work, isolation, verify each round, done when and cleanup. Vendoring a client library, on either route, is its Order of work, step 1.

## When not to use the library's control

Keep the port's own control, or build one from the library's parts, where the library control would
break tested behaviour. Seen in the proven run: portalled menus against the outside-click and Escape
rules the tests hold; a filtering combobox that owns its option ids where the app's
`aria-activedescendant` wiring needs them; a picker that ignores a blur on an exact match. Record
each as a reversible decision for the client's review.

## Library findings

The client's library has defects the port's checks find and its own checks never ran (narrow
widths, target sizes, missing names). Keep a numbered list, `library-findings.md`, beside the gap
report: each finding with its measured symptom, the screen that shows it and the fix proposed to the
library's owners. Patch locally only in one stylesheet, each patch citing its finding number and
marked "remove once fixed upstream". Never edit the vendored copy.

Seen in the proven run (17 findings): fixed-width inputs, action groups and tab lists that cannot
shrink or wrap at 320px; scroll containers with `tabindex="-1"`; a table with no caption or footer
slot; the same accessible name on every row checkbox; no radio group; a resize handle under the
target size. The engine's 320px overflow and target-size checks found most of them: run them on
every round.

## Gotchas with headless libraries

- **Their modals make the rest of the page inert** to assistive technology. A toast region must
  render inside the topmost open modal, and app code that looks for an open dialog (a tour's "page
  busy" check) must also find portalled `role="dialog"` with `data-state="open"`.
- **Never override the library's generated ids** (tabs, panels, menus). Its ARIA wiring breaks
  without an error (axe `aria-valid-attr-value`). Target an element by a data hook.
- **Library default labels collide** with the app's ("Next" on pagination and on a tour). Keep the
  port's more specific names and per-row control names.
- **A headless select does not answer native test helpers.** `fireEvent.update` or a `change` event
  does nothing to it, silently. Drive it from the keyboard, and after each round audit every test
  step that sets a select: three tests had steps that did nothing.

## Strings

- Move strings in the same round as the markup, one locale file per area. Helper modules read the
  translator through the global instance, so their unit tests need no new setup.
- **A shared helper stays in English while any unconverted page imports it.** Put translated
  exports beside it; when the last importer converts, translate it in place, keep the exports and
  delete the copy. List it as named debt each round.
- **Some English stays on purpose**: values sent to the API, stored or lookup values, URL and query
  values, typed confirmations ("type DELETE"). Labels map from them; never parse a label back into a
  value (several helpers had parsed a time-ago helper's English output).
- **Generated copy moves by changing its generator** (help, tours, route titles): copy to locale
  JSON, structure to code, read lazily by key. Prove each move with deep-equal exports before and
  after, and a byte-identical regeneration.
- **Escape the i18n syntax characters** in copy, in the generator: vue-i18n treats `{ } @ |` as
  syntax and `|` as the plural separator; react-i18next treats `{{ }}` and `$t(`. Turn off the HTML
  warning only where the markup is the app's own and never rendered as HTML.

## Framework notes

| Family | What to settle first | Watch for |
|---|---|---|
| Tailwind alone (`utility-css`) | Theme from `tokens.css` (`@theme` in v4); `check-frontend`'s raw-value rule still holds the tokens file as the only raw values | Arbitrary values (`w-[13px]`) are raw values by another name; class lists are the new inline styles, so keep them in components, never in page markup |
| Headless plus styles (shadcn/ui, a reka-ui or Radix kit) (proven via a client library) | Which parts are copied into the repo (shadcn) and so owned by the app, against which are a dependency | Portals, generated ids, inert modals, native test helpers (see Gotchas) |
| Component kit (Material UI, Vuetify, Quasar, PrimeVue) (Material UI proven on React and Next.js, Vuetify on Vue) | The theme object from the mockup's tokens, density, the kit's breakpoints against the mockup's, its default theme (Vuetify 4 defaults to `system`, which draws an undesigned dark theme) | CSS-in-JS and the CSP (a per-request nonce; Vuetify's runtime theme sheet needs `cspNonce`, so a static host cannot serve it); the kit's own focus ring (often drawn on a sibling element, which the quality check reads) and target sizes; its default colours against the contrast check (Material UI's default primary fails AA on an outlined button's hover tint); its components' DOM differs from the mockup's, so list them in `domOracle.opaqueComponents` |
| Client library | The vendoring script, the token mapping, who fixes findings and how fast | It moves under you: pin its commit and sync on purpose |


### Vue

Proven on Vue: the pixel port ([stacks/vue.md](../../convert-mockup/references/stacks/vue.md)), then every page and the shell moved onto the client's component library
(Tailwind 4 with reka-ui) and vue-i18n, in 18 rounds. The method and the library gotchas are above; the isolation setup and the gate that replaces
pixel parity are in [design-frameworks-fallback.md](../../convert-mockup/references/design-frameworks-fallback.md). Vue specifics:

- **Give `createI18n` `pluralRules` from `Intl.PluralRules`** for every locale, mapping CLDR categories onto the
  forms in the order `import-mockup` writes them. vue-i18n's default two-form rule sends 0 to the second form, so
  French reads "0 livraisons" where the mockup (`MK.t`, CLDR) reads "0 livraison". vue-i18n 11 picks the form from
  a `count` in the named values; no plural argument is needed (`examples/tailwind-vue` (in the proving repository), a test per locale).
- **Tailwind on Vue**: `@tailwindcss/vite` at the mockup's CLI version, the mockup's `tailwind.css` imported
  as it is; check the built sheet's class set against the mockup's ([Tailwind in a mockup](#tailwind-in-a-mockup)).
- **Vuetify** (`examples/vuetify-vue` (in the proving repository)): the adapters carry the kit's names and `vite-plugin-vuetify` runs with
  `autoImport: false`, so a forgotten adapter import fails the typecheck rather than rendering the raw kit. Set
  `defaultTheme: 'light'` when only light is designed (Vuetify 4 defaults to `system`). Give `createVuetify` the
  per-response nonce (`theme.cspNonce`, read from `<meta property="csp-nonce">`): Vuetify writes its theme as a
  runtime `<style>`, so production needs a server that writes a fresh nonce per HTML answer, not a static host.
  VDialog teleports to the end of `<body>`; make `#app` `inert` while it is open, as the native modal does.
  Vuetify's own focus on open (after its enter transition) undoes `autofocus`: focus the first field after the
  dialog has entered. Hold a transitive dependency that falls inside the 14-day rule with an npm `overrides`
  pin (`@vuetify/v0` 1.3.2).
- After cleanup, `components.css` holds only what the remaining port components still use (about a fifth of it in
  the proven run).
