# Mockup behaviours: `docs/behaviours.json`

Section 16 of the [mockup conventions](mockup-conventions.md). Read it when writing `docs/behaviours.json` (Step 4), or when `check-behaviours.mjs` fails.

A screenshot shows how a screen looks, not what it does: a count, a submitted value, a disabled
button, a drawer off canvas, a toast under a dialog, an amount cut by its box. Write each of those
as a behaviour, and `scripts/check-behaviours.mjs --mockup <mockup>` loads it in a browser, runs its
steps and asserts it on every run. The conversion runs the same file (Convert step 2).

**The file is a JSON array** (the top level is `[ ... ]`, not an object), one entry per behaviour:

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | unique, kebab-case; `--only <prefix>` runs the entries whose id, or page file name, starts with it |
| `page` | yes | mockup-relative, with its query (`pages/invoices.html?state=empty`); never `?as=` |
| `role` | no | previewed with `?as=<role>`; must be a role in the config's `roles` or the fixtures' |
| `viewport` | no | a config viewport name (`mobile`), or `{ "width", "height" }`; default `desktop`, else the widest |
| `steps` | no | the config's steps ([mockup-config.md](mockup-config.md)): `click`, `select`, `fill`, `press`, `type`, `wait` |
| `expect` | yes | a non-empty list of assertions, at least one of them positive |

Every **selector is CSS** (`.data-table tbody tr`, `input[type=hidden][name=min_amount]`), matched
in the page; the steps find things by role and accessible name, as a user would. The assertions:

| Assertion | Passes when |
|---|---|
| `{ "text": "..." }` | the page's visible text includes it |
| `{ "noText": "..." }` | it does not (negative) |
| `{ "selector": "...", "count": n }` | exactly `n` elements match (`count: 0` is negative) |
| `{ "attr": { "selector", "name", "value" } }` | the first match has that attribute value; `"value": null` means absent (negative) |
| `{ "visible": "<selector>" }` | the first match is rendered and inside the viewport (a drawer off canvas fails) |
| `{ "box": { "selector", "width"?, "height"?, "minWidth"? } }` | the first match's rendered size in CSS px, within half a pixel; `minWidth` is a floor |
| `{ "inside": { "selector", "container" } }` | the first match lies within the container's box |
| `{ "onTop": "<selector>" }` | the first match is what the user sees and can reach at its centre (a toast under a modal fails) |
| `{ "fits": "<selector>" }` | every rendered match holds its own content (nothing wider than its box; a `select` shows its whole option) |

An entry with no positive assertion fails, since a blank or refused render meets `noText`, `count:
0` and `"value": null` by accident; so does an empty `text`, an unknown role, a missing page or a
page error. Any key not in the tables (on the entry, the assertion, or inside `attr`, `box` or
`inside`) fails the entry. An assertion object holding several assertions checks every one;
`selector` and `count` go together.

**`text` and `noText` compare with whitespace normalised on both sides**: a no-break space
(U+00A0), a narrow no-break space (U+202F) and any run of whitespace count as one plain space.
Write plain spaces: `"Top-up sent: KES 1,250.50"` matches what `MK.format.money` renders with a
no-break space after `KES`. `attr` stays exact: an attribute value is compared character for
character.

**Pins.** A behaviour that shows a date, a relative time or anything random needs the run pinned:
`--clock <iso-instant>` fixes `Date`, `--seed <int>` fixes `Math.random`, and `--tz <zone>` the time
zone (default the config's `timezoneId`; the locale is the config's `locale`, else `en-GB`). Pass the
same values the visual baseline was captured with (`visual-diff.mjs --write-baseline <dir>`, then
`--baseline <dir>` on later rounds, with the same `--clock`, `--seed` and `--tz`), and record them
next to the file, so every round checks the same screen.

```json
[
  {
    "id": "invoices-first-page",
    "page": "pages/invoices.html",
    "expect": [
      { "selector": ".data-table tbody tr", "count": 8 },
      { "text": "Page 1" },
      { "attr": { "selector": ".pagination button:first-child", "name": "disabled", "value": "" } }
    ]
  },
  {
    "id": "invoices-minimum-in-minor-units",
    "page": "pages/invoices.html",
    "viewport": "mobile",
    "steps": [
      { "fill": { "label": "Minimum amount (USD)", "value": "10000" } },
      { "click": { "role": "button", "name": "Apply" } }
    ],
    "expect": [
      { "selector": ".data-table tbody tr", "count": 5 },
      { "attr": { "selector": "input[type=hidden][name=min_amount]", "name": "value", "value": "1000000" } },
      { "fits": ".money-field" }
    ]
  },
  {
    "id": "access-refused-to-clerk",
    "page": "pages/access.html",
    "role": "clerk",
    "expect": [{ "text": "You do not have access to this page" }, { "selector": "[role=grid]", "count": 0 }]
  }
]
```

Write a behaviour for every rule a reviewer would otherwise check by hand: money in and out of a
field, a role that must not see a control, a state reached by steps, a value that must fit at the
narrowest width.
