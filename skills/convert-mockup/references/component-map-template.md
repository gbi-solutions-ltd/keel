# Component map: {{project}} to {{stack}}

The conversion plan's Components table ([conversion-plan-template.md](conversion-plan-template.md)),
written out in full for a mockup with more components than a plan can carry, with two more columns:
**Used by** and **Stack notes**. Write it beside the conversion plan, in the target's
`<docs_root>/mockups/<name>/component-map.md` (`docs/` outside keel), never into the mockup: the
signed-off package is read, not written. Link it from the plan, and keep the plan's own table to
the components the plan discusses. A script that generates it lives beside it in the same docs
folder, committed, so the map can be regenerated. A js-kit package already holds a component map
from the mockup ([design-frameworks.md](../../mockup/references/design-frameworks.md)): start from it.

| | |
|---|---|
| Mockup | `{{mockup-dir}}`, inventory of {{date}} |
| Components | {{n}} files in `components/`: {{p}} primitive, {{c}} composite, {{d}} domain, {{l}} layout |
| Target | `{{stack}}`, layout from `references/stacks/{{stack}}.md` |

## How the columns are made

Generate the table with a script from the files and `.mockup-engine/inventory.json`, not by hand,
and say here how, so a reader can trust each column:

- **Target file**: the stack reference's layout (React `components/<folder>/<Name>/<Name>.tsx` with
  folders `primitives`, `composites`, `domain`, `layout`; Vue `components/<layer>s/<Name>.vue`,
  layouts in `components/layout/`).
- **Props**: the keys the component's render function destructures, so they are what the code
  uses; each file's header comment documents them in full.
- **Interactive**: yes when the markup carries a `data-action` (an event the page or shell handles).
- **Used by**: the page ids whose rendered component tree (`pages[].componentTree`) or empty,
  loading and error states (`pages[].statesCovered`) contain the component. The inventory renders
  each page once, in its default state, with no clicks, so a component seen only after a click (a
  dialog, a menu panel) or only for another role is missing there. Mark those rows `*` and list
  instead the pages that load the component's script; say which rule makes that sound (a page
  loads only the components it renders) and that `unused-component` confirms each one renders on
  some config screen. Long lists show the first six ids and a count.
- **Stack notes**: what changes in the port and nothing that does not: emitted actions
  (`defineEmits`, callback props), slots or `children` for markup props (`MK.raw`), native dialogs,
  imports for data helpers, behaviour the runtime gave for free that the stack must do itself (focus,
  caret, a select's held value), and the deviation or gap number where a component has one.
  "Direct port" when there is nothing to say.

## Components

| Mockup component | Layer | Target file | Props | Interactive | Used by | Stack notes |
|---|---|---|---|---|---|---|
| `AppLayout` | layout | `components/layout/AppLayout.vue` | `{ page, state, nav, session, shell, params, children }` | yes | every page | Layout route with `<RouterView />`; shell state in provide/inject or a Pinia store; `params` from `useRoute().query`; each `MK.onRender` hook becomes a watcher with `nextTick` |
| `MoneyField` | composite | `components/composites/MoneyField.vue` | `{ id, name, label, value, currency, hint, error, required, action }` | yes | `invoices` | `v-model` on the digits; the caret is put back in the component's own `nextTick`; `data/money.js` becomes `lib/money.ts` |
| `Badge` | primitive | `components/primitives/Badge.vue` | `{ tone, label }` | no | `invoices` | Direct port |

## Data helpers

| Helper | Target | Used by | Stack notes |
|---|---|---|---|
| `data/list-query.js` | `composables/useListQuery.ts`, or the query keys the generated hook sends | `invoices` | The server does the work; the composable holds the query state |

## Not ported

Components that exist only for the mockup (a role preview, a demo bar), with the reason.

| Mockup component | Why |
|---|---|
