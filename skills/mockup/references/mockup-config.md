# Mockup config: `mockup.config.json`

Section 13 of the [mockup conventions](mockup-conventions.md). Read it when writing or changing the config (Step 3), or when a config check fails.

```json
{
  "name": "example-app",
  "timezoneId": "Europe/London",
  "pins": { "clock": "2026-10-28T09:00:00Z", "seed": 20261028 },
  "project": { "designFramework": { "kind": "none" }, "i18n": { "locales": ["en-GB"], "defaultLocale": "en-GB" } },
  "modules": ["auth-mfa", "tours-help"],
  "checklist": { "audit-log": "later", "system-pages": "designed" },
  "viewports": [{ "name": "mobile", "width": 390, "height": 844 }, { "name": "desktop", "width": 1440, "height": 900 }],
  "screens": [
    { "name": "items", "page": "pages/items.html", "route": "/items", "states": ["default", "empty", "loading", "error"] },
    { "name": "items-sorted", "page": "pages/items.html", "route": "/items", "steps": [{ "click": { "role": "button", "name": "Name" } }] },
    { "name": "items-as-viewer", "page": "pages/items.html", "route": "/items", "role": "viewer" },
    { "name": "item", "page": "pages/item.html?id=1004", "route": "/items/1004", "states": ["default", "loading", "error"] }
  ],
  "diff": { "pixelThreshold": 0.1, "boxTolerancePx": 4 },
  "quality": { "targetMinPx": 44 }
}
```

`route` is a concrete URL with params filled in, so the scripts can open it in the app. `role`
previews a role on both sides. `steps` run on both sides after the page settles, each followed by
another settle: `{ "click": { "role", "name" } }` (exact accessible name; an `appName` replaces `name` on the app
side only, for a mockup identifier the app draws wider), `{ "select": { "label",
"value" } }`, `{ "fill": { "label", "value" } }` (`select` and `fill` match the label's text exactly as it reads, a required marker included: `"Subject *"`, even when the marker is `aria-hidden`), `{ "press": "Control+k" }`, `{ "type": "text" }`, `{ "wait": 300 }` (milliseconds;
only when nothing observable changes, since every step already waits for the page to settle).
Add a screen for every state a user can reach by interacting: a sorted table, an open menu, a
dialog with results, a wrong code. A screen whose steps or state provoke an error on purpose lists the
statuses in `expectStatus` (`[401]` for a wrong password, `[404]` for a designed not-found under
`?state=empty`), so the quality check accepts the
browser's log of them and nothing else; `expectConsole` lists text a screen logs on purpose (a
preview of a page that fails to render). `modules` and `checklist` are in [modules.md](modules.md); the
inventory checks both.

**The whole file is validated** against
[mockup-config.schema.json](../../../lib/mockup-engine/mockup-config.schema.json) on every inventory run: an unknown key anywhere
(a misspelt diff, viewport or screen key too), a wrong type or a value outside its list is lint
(rule `config`). `screens`, when present, needs at least one entry (leave the key out until the
first screen exists). Duplicate screen or viewport names, a state listed twice, or two cases that
make one slug are config problems too: `visual-diff` and `quality-check` cannot run on them (exit
2), and `check-config` and the inventory list them with the other config problems (exit 1). `project` holds the decisions the
production app is built from: tier 1 fields are asked at intake because they change how the mockup is
built, tier 2 fields change only the port and may be deferred with an owner and a date
(`{ "deferred": { "owner": "...", "by": "2026-12-15" } }`; `by` is a real date, and `check-config`
warns once it has passed). The schema says which is which (`x-tier`)
and what each field takes. The reasons behind each answer go in the brief, not here.
`check-config.mjs --ready-to-port` (no browser) and `inventory.mjs --ready-to-port` fail until every
tier 1 field is answered, every tier 2 field is decided or deferred, and the checklist is decided,
and there is a valid sign-off ([signoff.md](signoff.md): a record, at least one screen, nothing
changed since the last round, every mapped fixture valid); both print a `ready to port (decisions only):` line on every run,
which covers decisions, not screens, and a `signed off:` line. `pins` are the clock and seed the
baselines were captured with: `visual-diff`, `dom-oracle` and `check-behaviours` use them when
`--clock` or `--seed` is not passed (the quality and spill checks take no pins), so they are
written once, here.

The other keys, all optional:

| Key | Where | Does |
|---|---|---|
| `locale` | top level | the browser locale for every check (quality, visual diff, spill, behaviours); default `project.i18n.defaultLocale`, then `en-GB` |
| `targetStack` | top level | kept for older configs; `project.stack.name` is the decision, and the two must agree |
| `timezoneId` | top level | the browser time zone; `check-behaviours.mjs --tz` overrides it |
| `theme` | a screen | `"light"` or `"dark"`, previewed on both sides with `?theme=` (the theming module) |
| `expectStatus` | a screen | HTTP statuses its steps or state provoke on purpose (`[401]`), accepted by the quality check |
| `expectConsole` | a screen | console text it logs on purpose, accepted by the quality check |
| `spill.cards` | top level | selectors, added to the defaults (`.panel`, `.card`, `.dialog`, `[role="dialog"]`, a focusable region), for the card a spill finding is attributed to |
| `spill.scrollAllowed` | top level | selectors, added to the defaults (a focusable `role="region"` or named `section`, `[role="tablist"]`), for boxes allowed to scroll sideways, such as a wide table's wrapper |
| `domOracle` | top level | for `dom-oracle.mjs`: `root` (default `#app`), `appRoot` (the app's mount point when it differs, `#root`), `dropAttributes` (added to the defaults `data-action`, `data-group`), `skipHiddenActions` and `skipHiddenIds` (hidden plumbing buttons this mockup draws and a port does not; dropped with their subtree), `opaqueComponents` (a js-kit's component names: each compared as one line with its text, its inner DOM not) |
| `diff` | top level | for `visual-diff.mjs`, and the one place its tolerance defaults are stated: `maxMismatchPercent` (app mode; default 0, or 0.2 when `project.designFramework.kind` is `js-kit`), `baselineMaxMismatchPercent` (baseline mode; when unset, `maxMismatchPercent` capped at 0.2, or 0.2 when neither is set), `pixelThreshold` (default 0.1), `boxTolerancePx` (default 4) |

```json
{ "locale": "en-GB", "spill": { "cards": [".summary"], "scrollAllowed": [".amount-grid"] },
  "screens": [{ "name": "settings-dark", "page": "pages/settings.html", "route": "/settings", "theme": "dark" }] }
```
