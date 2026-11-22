# Design frameworks: the fallback route, a pixel port then adoption

The fallback route of [design-frameworks.md](../../mockup/references/design-frameworks.md): a framework named after sign-off, adopted after a pixel port. Read it only on that route; Strings, library findings, the headless gotchas and the framework notes in that file apply here too.

## Rules that change on the fallback route

Adopting a framework after a pixel port is a redesign the client asked for. On that route only, these
engine rules end at the adoption phase, and the plan says so in its Assumptions, so a later run does
not read the work as a breach:

- "Never redesign" (SKILL.md, Step 6) holds until the pixel port is proven, then yields to the
  framework's look. It still holds for behaviour: copy, states, roles, focus and flows stay exactly
  as designed.
- Pixel parity (Step 7, "never raise a threshold") applies to unconverted pages only. Converted
  pages are reported, not gated, on pixels.
- "Keep `components.css` global and byte-copied" (stacks/vue.md) applies while port components
  remain; the sheet shrinks as they go (about 80% went in the proven run).

## Adopting after a pixel port (the fallback)

The sections below describe the fallback route, as proven. [Strings](../../mockup/references/design-frameworks.md#strings) apply to
both routes once the mockup has a strings file (it should from the first screen; see
[mockup-strings.md](../../mockup/references/mockup-strings.md)).

## Order of work

1. **Bring the library in, read-only.** A client library is vendored with a sync script
   (`scripts/vendor-library.mjs` is the template; run its `--check` in CI, which also reports files
   in the copy the record does not list: name the app's own with `--allow <globs>`) that
   records the source commit, leaves out its tests, fonts and stories, installs its dependencies at
   the client's exact versions and aliases its package paths. Keep the app's linter out of the
   vendor folder. Vendor rather than link, so there is one copy of the framework (two copies of
   Vue or React break reactivity and context silently). A public kit is a normal pinned
   dependency.
2. **Run the two style systems side by side without touching unconverted pages** (see Isolation).
   Prove it before converting anything: every unconverted screen still at its port result.
3. **Trial on two modules.** One shared layer plus two pages. Write the result down: what adoption
   removes, what it does not, and what it adds (keeping the vendored copy in sync, library
   findings). Then decide whether to go on. The trial is the cheapest place to stop.
4. **Adapters first.** Build the shared components on the framework with the same props, slots and
   events as the port components they replace, so a page swaps imports and little else. Extend an
   adapter only in a backward-compatible way while unconverted pages still use the old component.
   The first round needs most of the adapters; later rounds are mostly page work.
5. **Convert by area, in rounds**, strings in the same round as the markup. One round per area or
   batch, each verified before the next (see Verify).
6. **The shell last**: layout, navigation, menus, overlays, sign-in. It touches every screen.
7. **Clean up once, at the end**, by script (see Cleanup).

## Isolation: two style systems in one app

The proven setup, Tailwind 4 with a component library over the port's global CSS:

- Generate utilities only from the library and converted folders (`@import "tailwindcss" source(none)`
  with an `@source` per folder), so unconverted markup gets no new utilities.
- Scope the framework's reset (preflight) to converted roots and to the library's own elements,
  `@scope (.converted-root, [data-slot]) { ... }`. Portalled sheets, menus and dialogs render
  outside the page, so a root selector alone misses them. Unscoped, in the proven run, the reset
  moved a sign-in page 2 to 5% and a menu up to 8%.
- Layer the framework's theme variables under the library's tokens, and those under the port's,
  so unconverted pages keep their fonts and weights.
- **Audit the port's bare element rules** (`h1, h2 { color }`, `button { font }`). An element rule
  in an unlayered sheet beats inheritance inside library components; in the proven run one such
  rule caused 42 contrast failures.
- **Never reuse a port class on library markup** (a density modifier, a state class). Its unlayered
  rule beats the library's values. Give the library its own hook attribute.

A CSS-in-JS kit (Material UI's emotion, Chakra) needs the same three things in its own terms: an
insertion point that keeps its styles in a known order against the port's sheet, its baseline reset
(`CssBaseline`) scoped or left off until the shell converts, and a theme built from the mockup's
tokens. Check the CSP: runtime style injection needs a nonce that changes on every response, never
`style-src 'unsafe-inline'` (the React stack reference has the setup).

## Verify each round

Once pixels change on purpose, the visual diff changes job:

- **On unconverted screens it is an isolation proof**: each stays at 0% or at its recorded expected
  difference (select it with `visual-diff.mjs --route` or `--exclude-route`). That set shrinks every round (in the proven run, 192 screens, then 158, down to 10).
  A step that navigates from an unconverted page into a converted one fails for the right reason,
  and so can a capture that catches the dev server's first compile of the library; label both,
  never count them as leaks.
- **Converted pages are gated by** typecheck, lint, the full test suite and the quality check
  (accessibility, 320px overflow, target size, focus, console and CSP). Their pixel median and
  maximum against the mockup are reported, never gated.
- **One verification script per round, run by the main session**, not by the agent that converted
  the batch: typecheck, lint, the full suite (a failure rerun alone), the isolation gate on the
  unconverted routes, then pixels (reported) and quality on the batch. The main session fixes what
  is ours and records it.
- **Every quality failure is fixed or put down to a numbered library finding.**
- **Lost features come back in the adapter first.** A move to library markup can drop saved views,
  column state or density. Restore them before converting more pages. When a page loses the
  component a cross-cutting test drives, move that test to a page that still has it with every
  assertion kept; never delete it.
- **Test timeouts**: library pages render more slowly, and a page's first test compiles the library.
  Raise the async wait and the test timeout once, with the reason in a comment (the proven run
  needed 3 s and 10 s). A test
  that fails in the full run and passes alone is load; one that fails alone is real. Fix races
  (`getBy` to `findBy`) rather than widening waits further.
- **Snapshot every changed file before a round**, outside the repo, so a reversible decision can be
  reversed.

Write each round in an adoption log: what converted, the checks with their numbers, findings,
decisions, named debt.

## Done when

Every page and the shell on the framework and locales; tests, typecheck, lint and audit clean; both
builds pass; the quality check clean on the production build under the strict CSP; no inline
styles; a cross-app sample (every area, every role's home, the overlays) reported on pixels; the
library findings list handed to the library's owners.

## Cleanup

Track, each round, the port components left with no users, but delete them in one scripted pass at
the end: a snapshot first, then removal by import graph, then CSS removal by class use (a script
that lists every selector no remaining template uses). The proven run removed 155 components, 69
test files and about 80% of the port's CSS. After cleanup, check that `check-frontend`'s
`layer-import` still covers the adapter folder: a folder outside the layer names is not checked.
