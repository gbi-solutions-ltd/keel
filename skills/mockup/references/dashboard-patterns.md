# Dashboard patterns

Read this when mocking or converting an app with a dashboard, reports, or more than one role, which
is most client web apps. Each pattern is in the example mockup (`examples/paydesk-mockup/` (in the proving repository)) and the
React example, passes the visual diff and the quality check, and has the rules below. Where a rule
is a keel standard, the standard is named; where it was new, it is now in `coding-standards`' `frontend.md` in keel. Copy a pattern's components from the modules (`templates/modules/`); the
starter holds only the core (tables, states, skeletons, fields, the grid), so `FilterTabs`,
`DetailList`, `Notice`, `StatTile` and the rest named below are in `examples/paydesk-mockup/` (in the proving repository) only.

| Pattern | Mockup | React example | Vue and Next.js |
|---|---|---|---|
| Role-aware UI | `MK.shell` nav, `needs.permission`, `MK.can`, `?as=` | `routes.tsx`, `lib/permissions.tsx`, `allowed_actions` | proven (`lib/session.ts`; `examples/equipment-loans-vue` (in the proving repository), `equipment-loans-next`) |
| Shape-matched skeletons | `TableSkeleton`, `StatTilesSkeleton`, `ChartSkeleton` | same names, `lib/useDelayed.ts` | `TableSkeleton` proven (`examples/tailwind-vue` (in the proving repository), `tailwind-next`, `kit-next`, `vuetify-vue`); stat tile and chart skeletons unproven |
| Command palette | `CommandPalette`, shell `keys` | `CommandPalette`, `AppLayout` | shell `keys` proven; the palette unproven |
| Reports | `DataTable`, `ColumnMenu`, `ExportMenu`, `Pagination` | same, on TanStack Table | `DataTable` and `Pagination` proven (`examples/tailwind-vue` (in the proving repository), `tailwind-next`); column menu and exports unproven |
| Dashboard | `StatTile`, `BarChart`, period `FilterTabs` | `DashboardPage` | unproven |
| Error pages | `ErrorPage`, `not-found.html`, shell `forbidden` | `ErrorPage` in `App.tsx` and `RequirePermission` | proven (the system-pages module, same examples) |

## Role-aware UI

keel's `authorisation.md` governs the server. These are the display rules on top of it.

- **One route table holds every page and its permission, and the menu is built from it.** A menu
  item is a route with a `nav` label, so it can never link to a page the route refuses. The
  inventory checks the mockup's menu against each page's `needs.permission` (`nav-permission`).
- **Deny by default.** A route without a permission does not compile; an open one says `public`.
- **Hide, do not disable, by default.** Disable with an explanation only when the user needs to know
  the action exists ("needs approval rights"). Decide this per control in the plan, not ad hoc.
- **Per-record actions come from the API.** A record carries `allowed_actions`, computed by the
  server from the user's permissions and the record's state (a failed payment cannot be refunded;
  whoever initiated it cannot approve it). The UI shows a control when the action is listed and
  never recomputes the rule. *New: proposed for keel's `frontend.md`.*
- **`useCan` and `<Can>` only for page-level capabilities** (may this user export at all).
- **Every role is signed off.** The mockup previews any role with `?as=<role>` (a picker in the
  corner for the client; hidden under automation), and `mockup.config.json` lists screens per role
  so the visual diff compares what each role sees. The inventory prints a role by page and control
  matrix for the client to approve.
- **The server enforces everything the UI hides.** The mock API returns 403 when a role lacks a
  permission, as the real one must, and the gap report lists each check the frontend assumes.

## Skeletons

- **Shaped like what they stand in for**: the real table header with placeholder rows, the stat
  tile grid, the chart card. Built from one `SkeletonBox` primitive. Nothing moves when data
  arrives.
- **First load only.** A filter, sort or page change keeps the current rows on screen
  (`placeholderData: keepPreviousData`) and marks the region `aria-busy`.
- **After 200ms** (`useDelayed`), so a fast response never flashes a placeholder. The mockup shows
  it at once; the settled screens match.
- **Announced**: `role="status"` with hidden "Loading" text; the pulse animation stops under
  reduced motion.
- **The toolbar stays usable while loading.** Filters are UI state, not data.

## Command palette

- **Ctrl K, or Cmd K on a Mac, and `/` when not typing**, plus a visible "Search" button in the
  header with the shortcut shown from the medium breakpoint up. Ctrl K is also the browser's own
  search shortcut on Windows and Linux; the page takes it only while it has focus.
- **A native `<dialog>` opened with `showModal()`**: the browser supplies the modal layer, inert
  background and Escape. Inside, the WAI-ARIA combobox pattern: focus stays in the input, arrow
  keys move `aria-activedescendant`, Enter opens, Tab is held, and on close focus returns to the
  trigger.
- **Pages from the route table, filtered by permission, matched in the browser. Records from the
  search API**, which returns only what the user may see: filtering records in the browser would
  reveal that they exist. Two characters minimum, 200ms debounce, previous results kept while the
  next arrive, a live result count.

## Reports

- **The API filters, sorts and pages.** Cursor pagination per keel's `api-contracts.md`: previous
  and next, no total. Sort is a field with a leading minus for descending; a new column sorts
  descending first, a second click reverses.
- **Filters and sort live in the URL**, so a view can be shared and the back button works.
- **Chosen columns are saved per user** through a preferences endpoint, applied optimistically. The
  first column is locked visible.
- **The table scrolls inside its own region on a narrow screen**, and that region is focusable and
  labelled so a keyboard user can scroll it (axe `scrollable-region-focusable`).
- **Sortable headers are buttons inside `th`, with `aria-sort` on the `th`.**
- **Exports are built by the API in the background, for the whole filtered result**, never the
  current page in the browser. The UI posts the request, polls until ready, and links the file in a
  status region. Export is its own permission (`transaction:export`) and is audited server side.
- **The server's export rules**, in the contract and pinned by the example's `csv.test.ts`:
  spreadsheet formulas neutralised (a cell starting with `=`, `+`, `-` or `@` gets a leading quote),
  UTF-8 with a byte order mark, amounts as plain major-unit decimals, PDF capped at `row_limit`.
- **TanStack Table** (headless, so the design tokens apply and no CSP exception is needed), in
  manual sorting mode with column visibility. Version 9 replaced `useReactTable` with `useTable` and
  explicit features; the package ships its own migration notes under `skills/`.

## Dashboard

- **Stat tiles say the change in words and an arrow, never colour alone**, with the comparison
  period written out ("vs previous 7 days"). Rates are in basis points on the wire and shown as a
  percentage; a change in a rate is in points, not percent.
- **"As of" on every figure set**, from the API, so a reader knows how fresh it is.
- **Periods are presets the API understands** (`7d`, `30d`); day boundaries are the business's time
  zone, decided by the server. A custom range is a separate design, not a default.
- **Charts are inline SVG** drawn from the data in a fixed viewBox, with HTML labels, an accessible
  summary (`role="img"`, range and peak), and a "Show as table" alternative. No chart library is
  needed for bars, and none adds a CSP exception.
- **Empty is its own state**: no activity yet, rather than zeros that look like a fault.

## Error pages

- **403** when a role opens a page it may not see: inside the layout, our own copy, no detail about
  why. **404** for an unknown route. **Render failures** are caught by the error boundary around
  the outlet and reported once.
- `/` sends a user to the first page their role may open.

## What the visual diff exercises

`mockup.config.json` screens can name a `role` and a list of `steps`, run on both sides before the
screenshot: `click` (by role and exact name), `select` (by label), `press`, `type`. The example
mockup covers each pattern above: the dashboard per period, as a table and as a role without access; the
report sorted, paged, filtered, with a column hidden, with an export ready, and as a role without
export; the palette with results and a selection; the detail page for a role without refund; the
404.
