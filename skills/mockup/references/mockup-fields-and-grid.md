# Mockup fields and the ARIA grid

Sections 7 and 8 of the [mockup conventions](mockup-conventions.md). Read them when a page has a text, select or money field, or a set of cells the user moves through in two directions.

## Fields

- **Help text goes below the input** and the input names it, with the error, in
  `aria-describedby` (`TextField`: label, input, hint, error).
- **An amount is typed in a `MoneyField`.** It shows thousands separators as the user types,
  keeps the caret after the same digit, takes no more decimals than the currency has (a pasted
  `1,250,000.50` in UGX is `1,250,000`; a point typed in UGX changes nothing), and submits the plain
  integer in minor units from a hidden input that carries the `name`; the visible input has none.
  The shell action `moneyInput` keeps the typed digits in `state.values[name]` and records the
  caret; an `MK.onRender` hook in `AppLayout.js` puts it back. The currency's decimals come from
  Intl, as `MK.format.money` takes them. Read the submitted value with `new FormData(form)`.
- A field that re-renders on input keeps its text in state (see the shell, [mockup-conventions.md](mockup-conventions.md#3-the-shell-mkshell-in-componentsapplayoutjs)), or the next render
  resets it.
- **A select draws its own chevron** (`SelectField`). Chromium ignores a native select's right
  padding and paints its arrow about 4px from the border, while the text keeps the field's full
  inset, so the arrow looks pushed to the edge. Set `appearance: none`, pad the right for the
  chevron, and draw it as a background image at the text's inset (`right var(--space-3) center`).
  The image is a `data:` SVG in `tokens.css` (`--icon-chevron-down`; the raw-value rule allows it
  only there), which the default CSP's `img-src 'self' data:` permits; an image cannot read a
  custom property, so its stroke repeats the muted text colour. The element stays a native
  `<select>`, so keyboard, screen reader and `select` steps are unchanged. A design framework's
  select is the framework's, not this.
- Fields side by side line up by their bottom edge (`.toolbar`): give each one a hint, or none.

Becomes: the app's `TextField`, `SelectField` and `MoneyField` components; the money helpers move into the
component or `lib/money.ts`, and the caret hook into the component.

## Keyboard widgets: the ARIA grid

A set of cells the user moves through in two directions (a permission matrix, a schedule, a
spreadsheet-like editor) is an ARIA grid, not a table of buttons reached one Tab at a time. The
starter's `PermissionGrid` on `access.html` is the pattern:

- `role="grid"` on the `<table>`, `th scope` for the column and row headers, a `<caption>`.
- **Roving tabindex**: the active cell has `tabindex="0"`, every other cell `"-1"`, so the grid
  is one Tab stop and Tab leaves it.
- **Keys** (`data/grid.js`): arrows move one cell and stop at the edges; Home and End go to the
  first and last cell of the row; Ctrl+Home and Ctrl+End (Cmd on a Mac) to the first and last
  cell of the grid; PageUp and PageDown to the first and last row.
- The page keeps the active cell in state. A `keydown` action on the grid (`data-on="keydown"`)
  calls `gridMove`, calls `preventDefault` for a key it handles, sets the cell and moves focus with
  `ctx.focus(cellId)`; it returns `false` for any other key, so the page does not re-render. A
  click action on each cell makes the clicked cell the active one.
- Cells have stable ids (`${gridId}-${row}-${col}`) so focus can be put back after a render.
- A cell that does something (toggles a permission) holds a button, or the cell takes Enter and
  Space in the same keydown action.

```js
gridKey(state, e, el, ctx) {
  const next = window.gridMove(state.cell, e, { rows: Number(el.dataset.rows), cols: Number(el.dataset.cols) });
  if (!next) return false;
  e.preventDefault();
  state.cell = next;
  ctx.focus(`access-grid-${next.row}-${next.col}`);
},
```

**An editable cell** (a limit, a price, a quota) is changed in an editor, not typed into the cell:

- Enter, Space or F2 on the active cell opens the editor, for a role that may change it
  (`ctx.can(...)`); the same keydown action handles these keys before it calls `gridMove`, calls
  `preventDefault`, and moves focus into the editor with `ctx.focus(editorId)`. Pointer users get a
  visible button ("Change selected limit") that opens the same editor for the active cell.
- The editor is prefilled with the cell's current value. For money that is a `MoneyField` whose
  `state.values[name]` is set to `money.fromMinor(amount, currency)`, read from `ctx.fixtures` (and
  this visit's changes) in the action, since an action is not given the loaded data.
- Save, Cancel and Escape each close the editor and return focus to the cell it came from, by id
  (`` ctx.focus(`${gridId}-${row}-${col}`) ``), so the keyboard user is back where they were.
- A role that may look but not change gets `aria-readonly="true"` on the grid (or on each cell it
  may not change), no editor keys and no edit button.

Becomes: a grid component holding the active cell itself (`useState` or `ref`), with the same
keydown handler and a ref or `focus()` after the update.
