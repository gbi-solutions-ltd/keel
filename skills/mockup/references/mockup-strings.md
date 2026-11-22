# Mockup strings and locales: `strings/<locale>.js`

Section 17 of the [mockup conventions](mockup-conventions.md). Read it before writing the first screen's copy, and when adding a locale or fixing an `i18n-*` finding.

Copy is never written into a template. Every user-visible string (headings, labels, buttons,
`aria-label`, `title`, placeholders, empty and error copy, status labels, column headers, nav labels,
document titles) comes from a strings file through `MK.t`, from the first screen, whether the app has
one language or five. One language costs a file; a second language added later costs an extraction
pass over every screen.

```js
// strings/en-GB.js, loaded on every page straight after mk.js; the first file loaded is the default
MK.strings('en-GB', {
  'invoices.title': 'Invoices',
  'invoices.count': { one: '{count} invoice', other: '{count} invoices' },
  'Pagination.next': 'Next page',
});
```

```js
html`<h1>${MK.t('invoices.title')}</h1> <p>${MK.t('invoices.count', { count: rows.length })}</p>`
```

- **Files are scripts, not JSON**, so a mockup still opens from `file://`. One file per locale in
  `project.i18n.locales`, the default locale's loaded first on every page. `import-mockup.mjs`
  turns them into the app's locale files.
- **Keys** are `<page-id>.<thing>` for page copy, `<ComponentName>.<thing>` for a component's,
  `shell.<thing>` for the layout, and `common.<thing>` only for words truly shared. A key names what
  the string is for, not what it says (`invoices.empty.title`, not `invoices.no-invoices-yet`).
- **Messages** use `{name}` placeholders, and plural forms as `{ one, other }` (any CLDR category:
  `zero`, `two`, `few`, `many`), chosen by `vars.count`. Nothing else: no markup in a message, no
  concatenated fragments. A sentence with a link or emphasis is split where the markup goes.
- **Resolve at render, not at load.** A string chosen when a script loads (a table's column labels,
  the shell's nav) is English in `MK.inspect()` and in what the app imports. Nav entries take a
  `labelKey` instead of a `label`, resolved when the menu renders; other load-time tables hold keys
  and call `MK.t` in their render function.
- **Spaces and markup stay outside a message.** "Reference <span>ab12</span>" is
  `` `${MK.t('ErrorPage.reference')} <span>${ref}</span>` ``, with the message `"Reference"`; never a
  leading or trailing space inside the message, and never markup.
- **Data is not copy.** Fixture values (names, numbers, codes) stay in fixtures. An enum's label is
  copy: `MK.t(`invoice.status.${status}`)`.
- **Formatting follows the locale.** `MK.format` uses the locale shown, so dates, numbers and money
  change with it. With no strings file loaded, it keeps its original fixed locales. Choose the locale
  code whose formats the client wants: `en-UG` writes Ugandan shillings as "USh", `en-GB` as "UGX".
- **Previews.** `?locale=<code>` shows a registered locale (links keep it); a screen in
  `mockup.config.json` takes `"locale": "fr-FR"`, and the app honours the same flag in a mocked build.
  A screen with steps in another locale names its controls in that locale (steps match accessible
  names exactly), so pseudo-locale sweeps cover screens without steps.
  `?locale=pseudo` shows the default locale accented and about 40% longer, in brackets: copy that is
  not in a strings file shows up unaccented, and a layout that cannot take longer text spills. Run
  `spill-check.mjs --locale pseudo` with `project.i18n.expansionCheck`.
- **Right to left.** A right-to-left locale sets `<html dir="rtl">`. Write CSS with logical properties
  (`margin-inline-start`, `inset-inline-end`, `text-align: start`) so it mirrors without a second
  stylesheet, and add an RTL screen to the config.
- **Checked.** A missing key renders `[[key]]` and logs a console error, which the quality check
  fails. The inventory, with `project.i18n`, fails a page that loads no strings (`i18n-strings`), a
  first file that is not the default locale (`i18n-default`), a locale with no strings
  (`i18n-locale`), and a locale missing keys the default has, or with keys it does not
  (`i18n-keys`).
