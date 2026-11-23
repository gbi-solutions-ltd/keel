# Mockup conventions

Read this in full before building or changing a mockup, and when a conversion meets a mockup that
does not follow it. A mockup that follows these rules opens from a folder with no build, looks
finished to the client, passes keel's frontend checks before sign-off, and converts to React, Vue or
Next.js almost mechanically. Each rule says what it becomes, so you know what breaks if you skip it.

## Folder layout

```
my-mockup/
  index.html              client-facing list of every screen and state (not converted)
  mockup.config.json      screens, routes, states, viewports, time zone, thresholds
  assets/
    mk.js                 the runtime; never edited per project
    tokens.css            design tokens: the only raw values
    base.css              reset, focus, reduced motion, layout primitives (.stack, .row, .card, .button)
    components.css        one /* ComponentName */ block per component that has its own DOM
  components/
    AppLayout.js          the layout component and MK.shell (menu, shortcuts, shared field actions)
    Badge.js              one component per file
  data/
    fixtures.js           window.FIXTURES, shaped exactly like the API, with a @typedef per entity
    list-query.js         a data helper: shared page logic as a pure function (search, filter, sort, cursor)
  pages/
    invoices.html         one file per screen
  api/
    openapi.yaml          the contract, drafted by sign-off (references/signoff.md)
  docs/
    behaviours.json       what each screen must do, checked by check-behaviours.mjs (mockup-behaviours.md)
    signoff.json          the sign-off record, written by signoff.mjs; never edited by hand
```

Start from `templates/mockup-starter/`, the minimal core: this layout, `mk.js`, the shell, the
components every app needs (tables, states, skeletons, text and money fields, an ARIA grid), the
`list-query`, `money` and `grid` helpers, and two sample pages. A module adds its own files (for
tours: `assets/tours.js`, `assets/vendor/`, `data/help.js`; for exports: `data/exports/`), copied
from the full example, `examples/paydesk-mockup/` (in the proving repository), when the client opts in ([modules.md](modules.md)).

## 1. Tokens: `assets/tokens.css`

- Every colour, font, size, weight, space, radius, shadow, width and touch target is a `--token`.
- Names say the role, not the look: `--color-danger`, not `--red`.
- Text colours meet 4.5:1 on their background, large text and control borders 3:1. Decide it here,
  once, rather than per component. The contrast check is `scripts/quality-check.mjs`: axe's
  `color-contrast` rule runs on every screen, state and viewport. There is no separate contrast script.
- `base.css` and `components.css` hold only `var(--name)`, unitless numbers, percentages and `1px`
  borders. The inventory and `check-frontend` both flag raw values.
- Breakpoints are listed here as reference values (`--breakpoint-md: 768px`) and written literally in
  `min-width` queries: a custom property cannot appear in a media query.

Becomes: the app's `tokens.css`, copied unchanged.

## 2. Components: `components/*.js`

```js
MK.component('Badge', ({ tone, label }) => MK.html`
  <span class="badge badge--${tone}">${label}</span>
`, { layer: 'primitive' });
```

- A pure function from props to markup: no DOM access, no state, no listeners.
- **Tagged with its layer**, keel's four: `primitive` (knows nothing of the domain: Badge,
  Skeleton), `composite` (built from primitives: EmptyState, ErrorState, MoneyField),
  `domain` (knows the business: TransactionTable), `layout` (the shell). A component contains only
  its own layer or below; the inventory flags `layer-order` and `no-layer`.
- **One root element.** The runtime stamps `data-component="Name"` on it, which the inventory and the
  visual diff use to find component boundaries. A wrapper whose root is another component
  (`TransactionStatusBadge` returns a `Badge`) keeps the inner name and needs no CSS block.
- **A domain value never reaches a primitive.** Map it in a domain component: the status `failed`
  becomes `{ tone: 'danger', label: 'Failed' }` in `TransactionStatusBadge`, so `Badge` stays
  reusable.
- PascalCase name; CSS classes take the kebab-case name as a BEM prefix (`.transaction-table__wide`).
- Styles live in a `/* Name */` block in `components.css`. A block with no component of that name is
  flagged `orphan-css-block`, because its styles would be lost in conversion; shared styles go in
  `base.css`. Write the heading bare: `/* Name: note */` is flagged `css-block-heading` (split-css
  would fold the block into the one above); put the note in its own comment.
- **A component uses only its own classes and global utilities from `base.css`** (`.card`,
  `.button`, `.stat-grid`, `.popover-menu`). Never another component's classes: each block becomes
  that component's CSS Module, where another component's names do not exist. When two components
  share a look, the look is a utility. A component rule may target a utility
  (`.bar-chart__table .numeric`); the conversion wraps it as `:global(.numeric)`.
- The second time markup appears, it becomes a component.
- Interactive components take the name of a page action as a prop and put
  `data-action="${action}"` on the element; the page owns the handler (see the starter's
  `Pagination`). `FilterTabs`, `DetailList` and `Notice`, named in other references, are not in the
  starter: they live in `examples/paydesk-mockup/components/` (in the proving repository) and may be copied from there, with
  their `/* Name */` blocks.
- Always `MK.html`, which escapes; `MK.raw` only for trusted markup. **Quote every interpolated
  attribute**: `aria-label="${label}"`. Unquoted, a value with a space breaks the attribute.
- Use the element that already does the job: `button`, `a`, `table` with `caption` and `scope`,
  `fieldset` and `legend` for a group of controls, real heading levels.
- **Icons have one source**, so the conversion can generate them: an `ICON_PATHS` table in
  `components/Icon.js` (icon name to its inner SVG markup, double-quoted attributes), or one file
  per icon in `assets/icons/<name>.svg`. An icon drawn inline in a component's template is not
  imported by `scripts/import-mockup.mjs` and has to be ported by hand.

Becomes: one framework component per mockup component, in the folder for its layer.

## 3. The shell: `MK.shell` in `components/AppLayout.js`

What every page shares, registered once:

```js
MK.shell({
  layout: 'AppLayout',
  forbidden: 'ForbiddenPage',               // shown inside the layout when a role lacks a page's permission
  nav: [{ label: 'Dashboard', href: './dashboard.html', route: '/dashboard', permission: 'dashboard:read' }],
  keys: { 'mod+k': 'openPalette', '/': 'openPalette', 'mod+enter': 'save' },
  state: ({ params }) => ({ paletteOpen: false, query: '', sessionExpiring: params.session === 'expiring' }),
  load: (fixtures, { state, session, nav, params }) => ({ /* shell data, such as search results */ }),
  actions: { openPalette(state, e, el, ctx) { /* ... */ } },
});
```

- The layout component receives `{ page, state, nav, session, shell, params, children }`. `nav` is
  already filtered to the role's permissions; the inventory checks each menu item's permission
  against its page's (`nav-permission`). `params` is the page URL's query as a plain object
  (`?id=TX-1&as=finance` is `{ id: 'TX-1', as: 'finance' }`); the shell's `load` gets it too.
- **Preview flags come from `params`, never from `location.search`.** A flag that seeds state the
  user then changes goes in a state function, `state: ({ params }) => ({ ... })`, evaluated once
  per page load (the idle warning, `?session=expiring`, which Stay signed in clears). A flag nothing
  changes is read by the layout from its `params` (the offline banner, `?system=offline`). Both
  are in `examples/paydesk-mockup/components/AppLayout.js` (in the proving repository). The app reads the same flags from its
  router's query where its mock API runs (`lib/preview.ts`). Each flag gets a screen in the config.
- **Keys.** A combo is modifiers joined by `+`, then a key matched against `KeyboardEvent.key`
  without case: `'mod+k'`, `'mod+enter'`, `'mod+shift+d'`, `'ctrl+d'`, `'alt+n'`, `'shift+?'`, `'/'`,
  `'escape'`. `mod` is Ctrl or Cmd, whichever the platform uses; `ctrl` and `meta` name one exactly.
  Aliases: `esc`, `space`, `up`, `down`, `left`, `right`; `+` itself is written `'shift++'` or `'+'`.
  A **chord** (any combo with `mod`, `ctrl`, `meta` or `alt`) fires even while the user types in a
  field, so `'mod+enter'` can save a form. A **bare key** (or shift plus a key) does not fire in a
  field, so `/` can still be typed into a search box, and it also does not fire while Ctrl, Cmd or
  Alt is held: `/` ignores Ctrl+/. Shift is matched exactly for a letter (`'mod+d'` is not
  Ctrl+Shift+D) and when the combo names it; a symbol such as `?` already needs Shift on most
  layouts, so there it is optional. Keys work on pages inside the shell's layout only.
- Shell state and actions merge into every page's, so a page's markup can trigger them.
- A modal is a `<dialog data-modal>`; the runtime opens it with `showModal()`. Its Escape arrives as
  a `cancel` action (`data-on="cancel"`).
- Actions receive `ctx` with `focus(id)` to move focus after the re-render (to an input when a
  dialog opens, back to the trigger when it closes), `navigate(path)`, `href(path)` and `can`.
- The runtime keeps focus, caret and each component's scroll position across re-renders, as a
  framework does by keeping elements. Every control shows what its new markup says: an input its
  `value` attribute, a textarea its text, a select the options marked `selected` (even when the
  same render added options). So a typed value must be in state, or the next render resets it:
  give the field an action that stores it (the starter's shell action `setValue` keeps a text
  field's text in `state.values[name]`).
- `MK.onRender((info) => ...)` runs after every render with `{ page, status, session, scenario,
  params, data }`. It is for the shell and for modules that act on a ready page (tours start from
  it; MoneyField's caret is put back by one), and lives in the shell's file or the module's runtime
  file. A page or component never uses it. Becomes an effect or watcher in the layout, or the
  component's own `nextTick` for a hook that serves one component (the caret).
- Roles are looked up as own keys of `fixtures.roles`, so `?as=__proto__` or `?as=constructor`
  previews nobody and the signed-in role stays.

Becomes: the app's layout route, a route table that the menu is built from, and the layout's state.

## 4. Data: `data/fixtures.js`

```js
/** @typedef {{ id: string, amount: number, currency: 'UGX'|'KES'|'USD', status: 'successful'|'pending'|'failed', created_at: string }} Transaction */
window.FIXTURES = { transactions: [ /* ... */ ] };
```

(The sample domain is payments. The rules are the same for appointments, shipments or courses.)

- **All** displayed data comes from here: no names, amounts or dates typed into markup. Labels and
  copy are fine.
- **Shaped exactly like the API**: field names, casing, nesting. The conversion drafts the OpenAPI
  contract from these shapes and the app's mocks serve them back, so a mismatch here becomes a
  contract mismatch.
- **If the app shows money, it is an integer amount in minor units plus a currency** (UGX has no
  minor unit, KES and USD have two). `MK.format.money` divides by the currency's exponent. Never a
  float. An app without money drops the helper; quantities, durations and percentages follow the
  same idea: the wire carries an exact value, formatting happens once, in `MK.format`.
- **How a currency is written** is `fixtures.format.currency_display`, read by `MK.format.money`:
  `'code'` writes the ISO code (`UGX 1,250,000`, `KES 1,250.50`); absent, or any other value,
  writes the symbol (`USh 1,250,000`, `US$12.50`; KES has no symbol in this locale, so it stays
  `KES`). Either way Intl puts a no-break space after the code or symbol. It is a display preference of the mockup,
  not API data: it does not go into the contract, and in the app it becomes a constant (or a user
  setting) in `lib/format.ts`.
- **Instants are RFC 3339 in UTC**; a business date is a plain `YYYY-MM-DD`.
- A `@typedef` per entity, with enums as unions. It becomes the contract schema and the TypeScript
  type.
- Include the awkward cases: a long name, a large amount, a two-decimal currency, every enum value.

## 5. Data helpers: `data/*.js`

Logic that several pages share, and that is not markup, goes in a data helper: one file in
`data/`, one or a few **pure functions on `window`**, no DOM, no state of their own, documented at
the top with their arguments and result. Pages call them from `load`, `render` or an action.

| Helper (starter) | Does | Called from |
|---|---|---|
| `list-query.js`: `listQuery(rows, { search, searchKeys, filters, sort, cursor, limit })` | search, filters, sort and cursor paging; returns `{ rows, next_cursor, limit }` (no total) | a list page's `load` |
| `money.js`: `money.digits`, `group`, `minorUnits`, `fromMinor`, `decimals`, `caretAfter` | typed text to an amount, as MoneyField and the shell's `moneyInput` need it; `fromMinor(amount, currency)` the other way, a stored amount as the digits a MoneyField keeps (125050 KES is `'1250.50'`), to prefill an editor | MoneyField, the shell, an editor's open action |
| `grid.js`: `gridMove(cell, event, { rows, cols })` | where an ARIA grid's active cell goes for a key | a grid page's keydown action |

```js
load: (fx, { scenario, state }) => window.listQuery(scenario === 'empty' ? [] : fx.invoices, {
  search: state.search, searchKeys: ['number', 'customer_name'],
  filters: [{ key: 'amount', value: state.min || '', fn: (r, min) => r.amount >= min }],
  sort: state.sort, cursor: state.cursors[state.cursors.length - 1], limit: 8,
}),
```

Paging is by cursor, as the contract's is ([api-integration.md](../../convert-mockup/references/api-integration.md)): `next_cursor`
opens the following page and is `null` on the last; `limit` is capped at 100; there is no total.
The page keeps the cursors it followed in state (`cursors: []`), so Previous drops the last one,
and a sort or filter change clears them (a cursor is good only for the query that made it). To
show "Page N", count: `cursors.length + 1`. The starter's `Pagination` hands `next_cursor` to the
next action as `data-cursor` on its button (`el.dataset.cursor`), because an action is not given
the loaded data. `needs.api` says so: `GET /v1/invoices?q=&sort=&cursor=&limit= -> InvoicePage
{ items, next_cursor }`.

- A helper stands in for work the server will do (list-query is the API's `?q=&sort=&cursor=&limit=`), or
  for a pure rule the app needs too (money, grid). Name the API keys it mirrors in its header.
- Load a helper only on the pages that call it, after `fixtures.js`.
- When the same few lines of logic appear in a second page, they become a helper, as markup
  becomes a component.
- Not for markup (that is a component) and not for DOM work (that is the runtime or a module).

Becomes: a module in `lib/` (React) or a composable or util (Vue,
[stacks/vue.md](../../convert-mockup/references/stacks/vue.md)), unit tested there. A helper that stood in for the server
(list-query) becomes the query parameters the generated hook sends; its logic moves to the API.

## 6. Pages: `pages/*.html`

Each page loads the three stylesheets, `mk.js`, `fixtures.js`, the data helpers it calls, the
components it renders, then one inline `MK.page({...})`:

| Field | Purpose | Becomes |
|---|---|---|
| `id` | kebab-case page id | page component name |
| `route` | app route, with `:params` | router path |
| `title` | document title | head or metadata |
| `layout` | layout component name | layout route |
| `needs.api` | `METHOD /v1/path -> Shape` per call | contract operations, generated hooks, gap report |
| `needs.permission` | the one permission that opens the page; `'authenticated'` for any signed-in user (account, help); `'public'` for signed-out pages | route permission (deny by default), gap report |
| `needs.uses` | permissions for controls on the page (`transaction:export`) | `<Can>` checks, the role matrix, gap report |
| `needs.notes` | open questions | gap report |
| `state` | initial UI state (filters, tabs, open dialogs), an object or `({ params }) => ({ ... })` to seed it from the URL; evaluated once per page load, and `MK.inspect().page.initialState` is the evaluated object | `useState` or `ref`, seeded from the route query |
| `load(fixtures, { params, scenario, state, session })` | the data this page shows; runs on every render, so it can depend on filters, sort and page (with a data helper such as `listQuery`) | the generated query hook |
| `actions` | `name(state, event, el, ctx)`; return `false` to skip re-render. `ctx` is `{ params, fixtures, session, can, navigate, href, focus, shellData }`: there is no loaded data in it, so an action reads records from `ctx.fixtures` (or from the element it was given, `el.dataset`) | handlers or mutations |
| `render({ state, data, status, params })` | markup | the page component |

- **Every page declares `needs.permission`**, or `'authenticated'` or `'public'` written out. The inventory flags
  `no-permission`. Permissions, never roles: `transaction:refund`, not `admin`.
- **Load stands in for the API**, so filtering, sorting and paging happen in `load`, not in
  `render`, exactly where the server will do them.
- **Per-record actions come from the data.** A record carries `allowed_actions` as the API would
  return it; `load` removes any action whose permission (`fixtures.action_permissions`) the role
  lacks, and `render` shows a control only when its action is listed.
- Use `MK.href(path)` for links, so a reviewer previewing a role stays in it.
- Route params travel as query strings in the mockup (`transaction-detail.html?id=TX-1001`) and are
  declared in `route` (`/transactions/:id`).
- Links are relative (`./transaction-detail.html?id=<id>`) so the mockup works from `file://`.
- Events: `data-action="name"`. The default is `submit` for forms, `change` for inputs and selects,
  `click` otherwise; override with `data-on`. An `input` action re-renders on every keystroke, so
  it must keep the text in state (section 7, [Fields](mockup-fields-and-grid.md#fields)); otherwise prefer `change` on text fields.
- Forms: every field has a `name`, a `type`, a real `<label for>`, and `required` where it applies.
  The inventory lists them as the form contract.

## 7. Fields

Moved to [mockup-fields-and-grid.md](mockup-fields-and-grid.md#fields): read it when a page has a text, select or money field.

## 8. Keyboard widgets: the ARIA grid

Moved to [mockup-fields-and-grid.md](mockup-fields-and-grid.md#keyboard-widgets-the-aria-grid): read it when the user moves through cells in two directions, or edits a value in a cell.

## 9. Roles

- `fixtures.roles` lists each role's label and permissions; `fixtures.session.role` is who is
  signed in. `?as=<role>` previews another, on any page, and a picker in the corner lets the client
  switch. The picker is not part of the design and is never rendered under automation.
- `MK.can(permission)` for page-level controls (may this role export at all).
- The inventory prints a role by page and control matrix. The client signs it off with the screens.

## 10. States: every data-driven page handles all four

| `?state=` | `status` in render | Must render |
|---|---|---|
| none | `ready` | the happy path |
| `empty` | `ready`, with `load` given `scenario: 'empty'` | `EmptyState` |
| `loading` | `loading`, data `null` | a skeleton shaped like the content (`TableSkeleton`, `StatTilesSkeleton`, ...) |
| `error` | `error`, data `null` | `ErrorState`, with copy we wrote |

The inventory flags a page that loads data whose loading state renders no skeleton or whose error
state does not render `ErrorState`. Keep toolbars and filters on screen while loading. Link every state from
`index.html` so the client signs them off too. The app honours the same flag in development through
its mock API, which is how the visual diff compares them.

## 11. Layout: mobile first

- Base rules are the narrow layout; `min-width` queries add the wider one.
- No horizontal page scroll down to 320px. Wide content scrolls inside its container.
- Controls are at least `--target-min` (44px) high on touch; nothing interactive is smaller than
  24px unless it stands well apart from other targets.
- Every viewport in `mockup.config.json` is part of the sign-off.

## 12. Annotations

- `data-todo="kind: description"` on anything not designed or not working. Kinds: `screen`, `flow`,
  `api`, `copy`, `rule`. Each becomes a gap report entry.
- `data-diff-ignore` on content that legitimately differs between mockup and app (relative times).
  Masked in screenshots. Use sparingly.
- `data-tour="name"` marks an anchor a page tour points at (the tours-help module). Put it on a
  page-owned element, or pass a `tour` prop to a component that renders it on its root. Converted
  as is.

## 13. Config: `mockup.config.json`

Moved to [mockup-config.md](mockup-config.md): read it when writing or changing `mockup.config.json` (Step 3), or when a config check fails.

## 14. Before the client sees it

Every check in [step-detail.md](step-detail.md) (Step 4), each clean.
A defect found here is fixed in one file. Found after conversion, it is fixed in the mockup, the app
and the sign-off.

## 15. Do not

- Touch the DOM from pages or components (`querySelector`, `addEventListener`, `innerHTML`). The
  runtime owns it, and an `MK.onRender` hook in the shell or a module's runtime file is the only
  other place that may. An action may read the element it was given (`el.value`, `new FormData(el)`).
- Use an inline `style` attribute.
- Use an em or en dash anywhere, copy and comments included (keel house style). Commas, colons,
  parentheses.
- Add a CSS framework or UI kit the app will not use, or a web font the app will not load from the
  same files. Font differences are the most common visual diff failure.
- Extend `mk.js` for one project. Anything the runtime can do, every conversion must reproduce.

## 16. Behaviours: `docs/behaviours.json`

Moved to [mockup-behaviours.md](mockup-behaviours.md): read it when writing `docs/behaviours.json` (Step 4), or when `check-behaviours.mjs` fails.

## 17. Strings and locales: `strings/<locale>.js`

Moved to [mockup-strings.md](mockup-strings.md): read it before writing the first screen's copy, and when adding a locale or fixing an `i18n-*` finding.
