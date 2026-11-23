# Step detail: Convert

Read the section for a step before doing that step. `S` is the scripts folder Step 0's
`toolchain.mjs --project` prints: the project's own install of the engine.

## Convert, Step 1: read the package, ask only what it leaves open

Convert starts from the sign-off package ([signoff.md](../../mockup/references/signoff.md)), not from a conversation:

```bash
node S/check-config.mjs <mockup> --ready-to-port   # decisions, sign-off and, for an existing repo, the repo against the package
```

Convert asks two kinds of question, no others: each `not ready:` line (a decision still open, a
mockup or contract changed since sign-off, which goes back to the `mockup` skill's sign-off (its Step 5), or an existing repo that
disagrees with the package), and each of the brief's open questions that blocks the port. A `note:`
line is work, not a question. The new repo is an empty folder; `check-config` reads only an existing
one. Then read, in this order, and take each answer from where it is written:

| Read | It answers |
|---|---|
| `mockup.config.json` `project` | the stack, design framework, locales (the i18n library is the stack reference's default, or the existing repo's), auth, tenancy, browsers, accessibility, theming, target, telemetry, and who signs off and who answers technical questions |
| `<docs_root>/mockups/<name>/brief.md` | why each answer, who gave it, what is deferred and to whom, open questions with owners |
| `<docs_root>/mockups/<name>/signoff.md` (or `docs/signoff.json` in the mockup) | the round, who signed off and when, every screen and state, the pins, the contract's version |
| `<docs_root>/mockups/<name>/decisions.md` | the design decisions from review rounds: each becomes an Assumption in the plan, citing its D number; "not reversible" means the backend depends on it. Absent when no round decided anything: write "none" in the plan |
| `token-map.md` (with a framework), `component-map.md` (a js-kit) | the theme keys and kit components the app uses ([design-frameworks.md](../../mockup/references/design-frameworks.md)); for any other kind the component map is a Step 4 output |
| `docs/behaviours.json`, `docs/inventory-accepted.json` | what each screen must do; the findings accepted and why |
| the contract (`project.contract.location`) | every operation, signed off with the screens |
| `<docs_root>/architecture/`, `decisions/ADR-*` (keel `design-architecture`) | the stack's reasons and constraints, when `project.stack.decidedBy` is `design-architecture` |
| for an existing repo: its `snapshot.md` and `standards.md` (keel `repo-snapshot`, `coding-standards`) | its layout, conventions, CI and checks: [existing-repo.md](existing-repo.md) |

**An answer the package holds is never asked again**, not even to confirm. A question in the
conversion plan names where its answer will be recorded: a package field (`project.telemetry`, a
`later` checklist item) or the brief's open question it carries. Anything else is a port detail the
plan decides and lists under Assumptions. A blocking question with no home in the package is a gap
in it: add it to the brief's open questions (no new round: the brief is a record, not design).

**The plan and the component map are written with the app**, in the target's `<docs_root>`, never
into the mockup. Nothing at Convert writes into the signed-off package: every check below and in
Step 7 takes an `--out` under the app, `<app>/.mockup-engine/<check>` (git-ignored by the
scaffold). A check run without one writes `<mockup>/.mockup-engine/`, which the sign-off hash
skips, so the gate stays green, but the records then live in the package instead of with the port.
An answer Convert gets goes in the plan and the gap report, and the technical owner closes the
brief's open question with it (who, when, a pointer to the plan): the brief is a record, not
design, so no round is needed, and the next Convert run does not ask it again.

## Convert, Step 2: check the mockup

The `mockup` skill's Step 4 checks except the baseline, each with its `--out` under the app:

```bash
node S/inventory.mjs <mockup> --ready-to-port --out <app>/.mockup-engine/inventory   # writes inventory.json there, which split-css reads
node S/quality-check.mjs --mockup <mockup> --out <app>/.mockup-engine/quality
node S/spill-check.mjs --mockup <mockup> --out <app>/.mockup-engine/spill            # then with --text 1.25, then --locale pseudo
node S/check-behaviours.mjs --mockup <mockup>                                        # the config's pins; writes nothing
```

`--locale pseudo` leaves out screens with steps and lists them. No valid sign-off is a `not ready:`
line: back to the `mockup` skill's sign-off (its Step 5).

## Convert, Step 3: the contract

Confirm the contract is the signed-off one (the gate already checked its hash and fixtures) and
read its operations against each page's `needs.api`, and against what the shell shows (its `load`
and the layout's props: the user's name, the role's label, the organisation). A value the shell
shows that no operation serves is a contract gap: a new sign-off round, or a gap entry and an
expected difference. Step 6 imports the contract.

## Convert, Step 5: scaffold and bind the standards

Copy `templates/app-scaffold/<stack>/`, `shared/staging-flows.json` and `scripts/check-frontend.mjs`
as [its README](../../../lib/mockup-engine/templates/app-scaffold/README.md) says: it lists every file, which are held
unchanged and which are skeletons, and what to fill in in each (`package.json`'s name and import
paths, the budget, the flows, the ports). Into an existing repo, copy only what it lacks and merge
the rest (that README's "Existing repo", and [existing-repo.md](existing-repo.md)). Then see
`typecheck`, `lint`, `test` and `audit` each fail on a planted defect before the first page.

The bare scaffold cannot typecheck or test: `generate` needs the contract, and the held
`permissions.tsx` imports two composites and the i18n library. The minimum first, from Step 6: item
1 (tokens and globals), item 2 (the contract, `npm run generate`), the strings and i18n setup (item
10), the `ErrorState` and `ForbiddenPage` composites, `tests/support/setup.ts` and one test. Then
plant: a type error, an unused import (Biome), an inline style (`check-frontend`), a failing
assertion, and a known vulnerable version in the lockfile only (the audit). Revert each.

`keel:coding-standards` seed mode runs on the scaffolded app as on a project with no code: the
scaffold is configuration, not the app's code.

## Convert, Step 6: the port, in order

1. **Tokens and globals.** Copy `tokens.css` and `base.css` unchanged into the app's global styles
   (`import-mockup --only css`; with `utility-css` there is no `base.css` or `components.css`: it
   copies `tokens.css` and `tailwind.css`, which holds the base layer; with any kind, the font files
   the sheets name). Never run `split-css.mjs` on a utility-css mockup.
   Add only app-specific globals after them (the example adds one rule for headings that take
   programmatic focus).
2. **Contract and client.** The contract is the signed-off one, imported, never copied by hand:
   `import-mockup --only contract` writes `api/openapi.yaml` (byte for byte) and
   `api/contract-source.json` (the sign-off round it came from), refuses a mockup whose sign-off is
   not valid, and `--check` in CI catches an app built from an older round or a hand edit
   (`--contract-out` for an existing repo's own path). A byte copy changed since the last import is
   refused unless `--force`. Orval ignores the `x-mockup-fixture` marks.
   `package.json`, the build config, `orval.config.ts`, `biome.json` and `src/api/http.ts` (the
   mutator) come from the app scaffold,
   `templates/app-scaffold/<stack>/` (its README says what to fill in; the reasons are in
   [api-integration.md](api-integration.md)): `formatter: 'biome'` on every output and the
   generated folder linted off by a `biome.json` override, never excluded (`check-frontend.mjs`
   fails `generated-format` otherwise). `npm run generate`, then typecheck.
3. **Mocks.** `mocks/fixtures.ts` is the mockup's `fixtures.js` data, typed by the generated models.
   `mocks/handlers.ts` serves them the way the server will: the scenario gate in front, the role
   from `?as=`, 403 for a missing permission, `allowed_actions` filtered by role, server-side
   filtering, sorting and paging. Write the fixtures-against-contract test now: it is the first proof the mockup and the
   contract agree. Mocks honour the mockup's other preview flags too (`?tours=reset`,
   `?system=maintenance`), never gate shell data (the notification summary) by the page scenario, and keep
   their state per server instance, rebuilt for each test.
4. **Components, leaf first**: primitives, composites, domain, layout. Styles depend on the stack
   and the mockup. Count the mockup's cross-component selectors first (`.layout--rail .side-nav`,
   `.topbar .menu`, `.cell:has(> .badge)`): where there are many, keep `components.css` global and
   byte-copied, as the Vue reference does, because splitting it changes the cascade. Otherwise,
   for CSS Modules, `node S/split-css.mjs <mockup> src/components --inventory
   <app>/.mockup-engine/inventory/inventory.json` (Step 2's) writes each `/* Name */` block as
   that component's module (the `src/styles/components.css` copy `import-mockup` writes stays, not
   imported: `import:check` keeps it level with the mockup), unchanged except for global utilities wrapped as `:global(.name)`; it
   exits 1 when a block is not written (its component has no layer in the inventory), when rules
   sit before the first block, or when nothing is written. Never copy blocks by hand. With a design framework chosen at intake the mockup is already
   built in it: `utility-css` and `css-library` ports keep the same classes on the same CSS;
   `js-kit` ports build each kit component as an adapter with the mockup's props
   ([design-frameworks.md](../../mockup/references/design-frameworks.md)). Only on the fallback route (a framework named
   after sign-off, [design-frameworks-fallback.md](design-frameworks-fallback.md)) does the pixel
   port come first and the framework after. The root keeps
   `data-component="Name"`; a wrapper adds none. Props come from the mockup function's destructured
   arguments; a domain value never reaches a primitive.
5. **Shell, layout and routes.** The mockup's `layout` becomes the layout route, with an error
   boundary around its outlet and focus moved to the new `h1` on navigation. Every route in the
   route table carries the page's `needs.permission`, and the shell's `nav` becomes `nav` labels on
   those routes, so the menu is built from the table. Shell `keys` and state (the palette) live in
   the layout. A 403 page for a role without access and a 404 route close the table.
6. **Pages.** `state` becomes local state; `actions` become handlers; `load` becomes the generated
   hook, and a filter the mockup applied in the browser becomes a query parameter; the `status`
   branches become the query's pending and error states with the same components and copy.
7. **Formatting.** `MK.format.*` becomes `lib/format.ts` with identical output. The visual diff
   compares rendered text, so a different date or money format fails it.
8. **Telemetry, permissions and the query client**: `lib/telemetry.ts`, `lib/query.ts`, and
   `lib/permissions.tsx` on React (`lib/session.ts` on Vue and Next.js) from the app scaffold, with
   the service name set; `Permission` comes from the contract.
9. **Modules** the config lists ([modules.md](../../mockup/references/modules.md)): copy the example's files for each,
   then port the project's own copy. For tours, `help/content.ts` is the mockup's `data/help.js`
   unchanged, and every `data-tour` anchor keeps its name. Generate such content files (help,
   tours, fixtures, icons, the nav config) from the mockup's data with a script committed to the
   app's `scripts/`, never by hand: a rerun must be byte-identical, and the copy has one source.
   `S/import-mockup.mjs --mockup <mockup> --app <app>` (an existing folder) writes fixtures, icons,
   the byte-copied CSS and the nav config, and records each file in `.import-mockup.json` (commit
   it); exclude its outputs from Biome and run it with `--check` in CI, which also lists orphans.
   With no record, or a record with no entry for the file (a part not imported before), a byte
   copy already there with other bytes is refused unless `--force`, and `--check` lists it as
   unrecorded.
10. **Strings and locales**, with `project.i18n`: `import-mockup --only strings` writes
    `src/locales/<locale>.ts` and `index.ts` in the stack's library (`--i18n vue-i18n|i18next|icu`,
    default per stack; `--flat` when a key is also a prefix of another). Wire the library, the
    locale switch and `<html lang dir>` as the stack file says
    ([react-vite.md](stacks/react-vite.md#strings-and-locales), [vue.md](stacks/vue.md#libraries),
    [nextjs.md](stacks/nextjs.md#libraries)); honour `?locale=<code>` and `?locale=pseudo` where
    mocks run, never in production (not needed with one locale and
    `project.i18n.expansionCheck` off). The pseudo-locale spill run is Step 2's
    (`spill-check --locale pseudo` on the mockup); in the app, a test renders every key through the
    app's library and through `MK.t` and compares.

Write each behaviour's test as you port it, in `tests/` at the path its subject has under `src/` (or let `keel:tdd` drive it under `keel:execute-plan`):
the happy path renders the fixtures, a filter or sort calls the API with it, every mutation's
failure is shown in our copy, the empty and error
states show our copy, each role sees what the role matrix says (a hidden control, a refused page, a
missing menu item), an export reaches its download link, and an error never shows a server
message. Patterns and their rules: [dashboard-patterns.md](../../mockup/references/dashboard-patterns.md).

An action the mockup marked `data-todo`, or that only logs: keep the element exactly as designed,
give it a handler that logs `[todo] <action>`, put a `TODO(mockup)` comment naming the gap entry, and add
the entry.

## Convert, Step 7: the checks and how to read them

The commands are the Vite stacks' (React and Vue build the mocked build into `dist-mocked`, so
`dist` never holds the mocks). Each stack file's Done when holds its own build, preview and
mocked-build commands, ports and build-time variables (Next.js: `npm run build:mocked && npm run
start:mocked`, `MOCKS=true next build` and `next start`, into and from `.next-mocked`). `O` stands
for `<app>/.mockup-engine`.

```bash
npm run typecheck && npm run lint && npm test
npm run audit                                                   # npm audit --audit-level=high (npm 11)
npm run dev                                                     # in another terminal
node S/visual-diff.mjs --mockup <mockup> --app http://localhost:5173 --out O/diff-dev [--expected <file>]
npm run build:mocked && npm run preview:mocked                  # dist-mocked, in another terminal
node S/visual-diff.mjs  --mockup <mockup> --app http://localhost:4173 --out O/diff [--expected <file>]
node S/quality-check.mjs --mockup <mockup> --app http://localhost:4173 --out O/quality-app
node S/dom-oracle.mjs    --mockup <mockup> --app http://localhost:4173 --out O/dom-oracle [--app-root '#root']   # see below
```

Ports are examples: use the app's own (a dev server and a preview each), and keep clear of ports
the fetch standard blocks (4190 among them). **The DOM oracle** compares structure, not pixels; the
mockup mounts on `#app`, and `--app-root` (or `domOracle.appRoot`) names the app's mount point when
it differs. A link to a mockup page compares as the page's `MK.page` route, with each `:param`
filled from the link's query key of the same name. Where the app keeps the mockup's class names
(Vue with the global sheet, `utility-css`, `css-library`), compare them. A React port on CSS
Modules hashes every class name: drop `class` with `--drop-attributes`, with every `data-*` the
mockup's markup carries for mk.js that the app does not emit (`data-on`, `data-value`, `data-id`,
`data-modal`, and the components' own, such as `data-field`, `data-cursor`, `data-row`; list them
from the mockup's markup). The flag adds to the signed-off config's `domOracle.dropAttributes`,
which Convert does not edit. The structure, attributes, text and routes are still compared. Proven on `examples/equipment-loans-app` (in the proving repository): what is
left is what the app adds on purpose (its live-region announcer) and copy written during
conversion; read each, give each a gap entry, and record them as expected by keeping that run's
report and passing it as `--reference` on every later run (exit 1 only when a case gets worse).

The visual diff, the DOM oracle and the behaviours read the config's `pins` when `--clock` and
`--seed` are not passed (and `timezoneId` for `--tz`); pass others only to override them: a dated
screen fails on the wrong clock (an age reads "34 d ago" instead of "3 d ago"). App mode reads no expected-diffs file
unless one is named. For a port too big for one run, see [large-ports.md](large-ports.md).

Re-run one case while fixing it: `--screen <part of the screen name> --state <state> --viewport
<name>` on the visual diff, and `--screen` on the quality check. In every mode a selection that
matches nothing exits 2 (nothing to capture); a shard that owns no case exits 0. The mockup side is
served over HTTP, not `file://`.

**Visual diff, failing case with component issues.** Issues are listed in DOM order. Fix the first
one with a width or height change; the `y` shifts after it are usually that change cascading. A
`count mockup N vs app M` issue for a pair of names means a component was named differently on the
two sides, often a wrapper.

**Visual diff, failing case with no component issues.** Open `diff.png`, then `mockup.png` and
`app.png`, with the Read tool. Usually colour, font, a missing style block, or text content
(formatting helpers, copy).

**A difference that appears only after a step** (a sort, a menu): the mockup re-renders by
replacing DOM while the framework keeps elements. The runtime keeps focus, caret and scroll
positions to match; if a diff shows the table scrolled differently or focus elsewhere, start there.
A step that fails to find its target ("strict mode violation", a timeout) names a control whose
accessible name differs between the two sides. A capture with identical content scrolled a few
pixels differently after a focus step can be the mockup's fault: its page grew after its focus call
scrolled (a log filling in, a late font). Measure heights before and after on both sides before
changing the port, and name it if so ([large-ports.md](large-ports.md), Named failures). Rerun
with `--settle-steps` (or `"settleLayout": true` on the step) to wait for stable layout before each
step, on both sides.

**Visual diff, ERROR on load.** The page never settled within ten seconds, or the dev server is
down. A request held open on purpose (`?state=loading`) is expected and handled. An error on the
screenshot itself (a timeout) is usually machine load: the case is retried once and reported as an
error, and the run goes on. Rerun it alone.

**Quality check failures** are listed by check; warnings are summarised by check (`--warnings all`
lists each). The 44px touch warning skips targets covered by another layer or off screen
(counted in `targetSkipped`); axe's `target-size` rule still judges them. `axe` names the rule and the element; `overflow`
names the width; `target` names the element and its size; `focus` names each element that took
focus with no visible indicator; `console` includes every CSP violation with the directive that
blocked it. Every check runs under the page's own CSP (the visual diff, DOM oracle and behaviours too), and the styles the checks add go in as constructed sheets, which a strict CSP allows: a violation logged is the app's. Focus counts as visible when focusing changes the element or its close surroundings (a kit draws an outlined field's ring on a sibling). Fix CSP violations in the code, never by loosening the policy. Before fixing a failure in the app,
run the same check on the same mockup screen: when the mockup fails too, the defect is inherited
from the design, so record it with design as the owner (and fix it in the app only by decision). A
screen that provokes a 401, 403, 404 or 500 on purpose, in its steps or in its state (a designed
404 under `?state=empty`), lists it in `expectStatus`.

**A difference that is intentional** (a library control renders differently from the mockup's
approximation): `data-diff-ignore` on both sides, and a line in the gap report saying why. Never
raise `maxMismatchPercent` to pass: both sides render in the same Chromium, so a faithful port
reaches about 0%.

Done means every command above is clean, and the gap report is written.
