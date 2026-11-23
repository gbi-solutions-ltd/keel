# React and Vite: patterns from the proven ports

This is the code that [react-vite.md](react-vite.md) and
[../frontend-defaults.md](../frontend-defaults.md) describe. It is taken from the proven ports and
trimmed to what matters. Each block names the example file it comes from; those examples are in the proving repository, which a reader of this skill may
not have, so everything needed is here. `examples/starter-react/` is the port of the engine's
starter mockup; `examples/paydesk-react/` is the larger port.

## Test setup

`tests/support/setup.ts`, from `examples/paydesk-react/` (in the proving repository), trimmed. It
is the `setupFiles` entry of the `test` block in `vite.config.ts` (`environment: 'jsdom'`,
`include: ['tests/**/*.test.{ts,tsx}']`).

```ts
import '@testing-library/jest-dom/vitest';
import { cleanup, configure } from '@testing-library/react';
import { setupServer } from 'msw/node';
import { Agent, type Dispatcher } from 'undici';
import { afterAll, afterEach, beforeAll, beforeEach } from 'vitest';
import { noteApiResult } from '@/lib/maintenance';
import { resetSessionEnd } from '@/lib/sessionEnd';
import { createHandlers, releaseHeldRequests, type Scenario } from '@/mocks/handlers';

// jsdom has no modal dialogs. This stands in for the two behaviours the palette relies on:
// showModal() opens it, and Escape fires a cancelable `cancel`. Real behaviour is covered in
// Chromium by visual-diff.mjs and quality-check.mjs.
if (!HTMLDialogElement.prototype.showModal) {
  HTMLDialogElement.prototype.showModal = function showModal(this: HTMLDialogElement) {
    this.open = true;
    this.querySelector<HTMLElement>('input, button, select, textarea, [tabindex]:not([tabindex="-1"])')?.focus();
    this.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') this.dispatchEvent(new Event('cancel', { cancelable: true }));
    });
  };
  HTMLDialogElement.prototype.close = function close(this: HTMLDialogElement) {
    this.open = false;
  };
}

// jsdom has no matchMedia. Tests run as a phone-sized, motion-reducing browser unless a test sets
// `media.wide`.
export const media = { wide: false };
window.matchMedia = (query: string) =>
  ({
    matches: query.includes('min-width') ? media.wide : query.includes('reduce'),
    media: query,
    onchange: null,
    addEventListener: () => {},
    removeEventListener: () => {},
    addListener: () => {},
    removeListener: () => {},
    dispatchEvent: () => false,
  }) as MediaQueryList;

/** What every request sees; a test sets these before rendering (handlers are rebuilt per test). */
export const mock: { scenario: Scenario; role: string; maintenance?: boolean } = {
  scenario: 'default',
  role: 'admin',
};

const handlers = () =>
  createHandlers({
    getScenario: () => mock.scenario,
    getRole: () => mock.role,
    maintenance: mock.maintenance ?? false,
  });

export const server = setupServer(...handlers());

// The app's live region (lib/announce.tsx) repeats a status message a moment after it appears.
// Text queries skip it; tests of what is announced query it by test id.
configure({ defaultIgnore: 'script, style, [data-testid="announcer"]' });

/** Rebuilds the mock server's state from `mock`, for a test that changes it after the start. */
export const applyMocks = () => server.resetHandlers(...handlers());

beforeAll(() => server.listen({ onUnhandledFrame: 'error' }));

// Each test gets its own connection pool for fetch, and a connection is never reused. On Node 24
// the mock API matches each connection to the request that opened it; a connection kept, or
// queued behind a request held open by ?state=loading, can lose that match and send a later
// request to the real network (ECONNREFUSED).
const DISPATCHER = Symbol.for('undici.globalDispatcher.1');
let dispatcher: Dispatcher | undefined;
beforeEach(() => {
  dispatcher = new Agent().compose((dispatch) => (opts, handler) => dispatch({ ...opts, reset: true }, handler));
  (globalThis as Record<symbol, unknown>)[DISPATCHER] = dispatcher;
});
afterEach(() => {
  cleanup();
  releaseHeldRequests(); // ?state=loading requests, or they pile up and break interception
  void dispatcher?.destroy();
  // Fresh handlers, so state a test changed does not leak into the next.
  mock.scenario = 'default';
  mock.role = 'admin';
  mock.maintenance = undefined;
  noteApiResult(undefined); // module stores outlive a render
  resetSessionEnd();
  media.wide = false;
  server.resetHandlers(...handlers());
});
afterAll(() => server.close());
```

What each part is for:

- **Mock state per test.** `mock` is read by the handlers on every request, so a test sets
  `mock.scenario = 'error'` or `mock.role = 'clerk'` before `renderApp`, and `afterEach` puts it
  back and rebuilds the handlers. Reset every module-level store the app has here too
  (`noteApiResult` and `resetSessionEnd` are the maintenance and session-ended stores). The
  starter's setup is the same without the stand-ins and stores, which its pages do not use.
- **The undici pool** is the fix for the Node 24 gotcha in
  [../frontend-defaults.md](../frontend-defaults.md#gotchas-on-every-stack). `undici` is a pinned
  dev dependency and an `overrides` entry at the same version, on the major Node bundles (7.x for
  Node 24).
- **`onUnhandledFrame: 'error'`** fails a test whose request no handler answers, instead of letting
  it reach the network ([MSW 3](../frontend-defaults.md#gotchas-on-every-stack)).
- **StrictMode.** Neither example sets it. Add `configure({ reactStrictMode: true })` beside
  `defaultIgnore` (Testing Library 16 has the option) so every `render`, the app and a lone
  component alike, runs effects twice as development does. Checked on a copy of the starter: its
  suite still passes, and the heading focus bug in
  [react-vite.md](react-vite.md#gotchas-found-while-proving-the-example) fails a test only with it on.

`releaseHeldRequests` lives in `src/mocks/handlers.ts`, beside the handler that holds a request for
`?state=loading` (from `examples/starter-react/`, in the proving repository):

```ts
const held = new Set<() => void>();
function holdOpen(): Promise<Response> {
  return new Promise((resolve) => {
    const release = () => {
      held.delete(release);
      resolve(HttpResponse.json({ held: false }));
    };
    held.add(release);
  });
}

/** Lets go of every request held open by ?state=loading. Tests call it after each test. */
export function releaseHeldRequests() {
  for (const release of [...held]) setTimeout(release, 0);
}
```

### The development `console.error` from `reportError`

The scaffold's `reportError` writes `console.error('[op]', err)` when telemetry is off and
`import.meta.env.DEV` is true, which it is under Vitest. So every test that expects a 5xx prints a
stderr block. **Neither example filters this globally.** Vitest hides a passing test's logs when it
detects it is run by an agent, so an agent sees a clean run while a person at a terminal sees
about twenty blocks on the larger port. Run `npx vitest run --silent=false` once to see what they
see.

The examples silence it only in the test that expects it, from
`tests/pages/system/System.test.tsx` in `examples/paydesk-react/` (in the proving repository):

```tsx
afterEach(() => vi.restoreAllMocks());

it('shows our page, with a reference, when a page fails to render', async () => {
  vi.spyOn(console, 'error').mockImplementation(() => {});
  // ...
});
```

Not from the examples, but better: in a test that expects a failure, spy and assert the report, so
the output stays clean and the reporting is under test. The op is `query <first key>`, and for an
Orval hook the first key is the path. Keep the `vi.restoreAllMocks()` in `afterEach`:

```ts
const errors = vi.spyOn(console, 'error').mockImplementation(() => {});
mock.scenario = 'error';
renderApp('/invoices');
expect(await screen.findByRole('alert')).toHaveTextContent('We could not load invoices.');
expect(errors).toHaveBeenCalledWith('[query /v1/invoices]', expect.any(Error));
```

## Rendering the app in a test

`tests/support/render.tsx`, from `examples/starter-react/` (in the proving repository). The larger
port also returns `client`, for a test that reads the cache.

```tsx
import { QueryClientProvider } from '@tanstack/react-query';
import { render } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { App } from '@/App';
import { createQueryClient } from '@/lib/query';

/** Renders the whole app at a path, against the mock API, with retries off so failures are immediate. */
export function renderApp(path: string) {
  // The app's own client, so its error handling (reporting, maintenance) runs, without retries.
  const client = createQueryClient();
  const defaults = client.getDefaultOptions();
  client.setDefaultOptions({ ...defaults, queries: { ...defaults.queries, retry: false } });
  return render(
    <QueryClientProvider client={client}>
      <App router={(children) => <MemoryRouter initialEntries={[path]}>{children}</MemoryRouter>} />
    </QueryClientProvider>,
  );
}
```

It works because `App` takes its router as a prop, and `main.tsx` renders `<App />` with the
default (`src/App.tsx`, same example):

```tsx
const browserRouter = (children: ReactNode) => <BrowserRouter>{children}</BrowserRouter>;

/** The app. Tests pass a memory router; the browser uses the history API. */
export function App({ router = browserRouter }: { router?: (children: ReactNode) => ReactNode }) {
  return router(
    <SessionProvider>
      <Routes>
        <Route element={<AppLayout />}>{/* the routes from routes.tsx */}</Route>
      </Routes>
    </SessionProvider>,
  );
}
```

A test then reads like the page: `mock.role = 'clerk'; renderApp('/invoices');
await screen.findByRole('heading', { name: 'Invoices' });`.

## Fixtures against the contract

`tests/mocks/fixtures.test.ts`, from `examples/starter-react/` (in the proving repository). The
schemas are Orval's generated Zod output; the fixtures are the ones `import-mockup` wrote.

```ts
import { describe, expect, it } from 'vitest';
import { ListInvoicesResponse, ListPermissionsResponse, ListRolesResponse } from '@/api/generated/zod';
import { invoices, permissions, roles } from '@/mocks/fixtures';

const valid = (schema: { safeParse: (v: unknown) => { error?: unknown } }, value: unknown) =>
  expect(schema.safeParse(value).error).toBeUndefined();

// The mockup's data is the first consumer of the contract. If a fixture stops matching the
// OpenAPI schema, either the mockup or the contract is wrong.
describe('fixtures match the contract', () => {
  it('every invoice, in a page', () => valid(ListInvoicesResponse, { items: invoices, next_cursor: null }));
  it('the roles', () =>
    valid(
      ListRolesResponse,
      Object.entries(roles).map(([name, r]) => ({ name, ...r })),
    ));
  it('the permission labels', () => valid(ListPermissionsResponse, permissions));
  it('every permission a role holds has a label', () => {
    for (const r of Object.values(roles)) for (const p of r.permissions) expect(permissions).toHaveProperty([p]);
  });
});
```

With many records, `it.each(rows.map((r) => [r.id, r] as const))('%s is a valid Transaction', ...)`
names the record that fails, as the larger port does.

## Skeletons that wait

`src/lib/useDelayed.ts`, the same in both examples (in the proving repository):

```ts
import { useEffect, useState } from 'react';

/**
 * True once `ms` have passed since mount. Skeletons wait 200ms so a fast response never flashes
 * a placeholder for a frame.
 */
export function useDelayed(ms = 200): boolean {
  const [ready, setReady] = useState(ms <= 0);
  useEffect(() => {
    if (ms <= 0) return;
    const t = setTimeout(() => setReady(true), ms);
    return () => clearTimeout(t);
  }, [ms]);
  return ready;
}
```

The skeleton component calls it, not the page: `if (!useDelayed()) return null;` at the top of
`TableSkeleton`, so the page just renders the skeleton while `query.isPending`. A loading test
waits for it with `await screen.findByRole('status')`.

## Money field caret

`lib/money.ts` is a typed port of the mockup's `data/money.js`, function for function (`decimals`,
`digits`, `group`, `minorUnits`, `fromMinor`). Port the mockup's file; the two caret helpers are
the part a React port leans on (`src/lib/money.ts` in `examples/starter-react/`, in the proving
repository):

```ts
/** The index just after the n-th digit (or point) of a shown value: where the caret goes after regrouping. */
export function caretAfter(shown: string, n: number): number {
  let at = 0;
  for (let seen = 0; at < shown.length && seen < n; at++) if (/[\d.]/.test(shown[at] ?? '')) seen++;
  return at;
}

/** How many digits (and points) of a value come before an index: what caretAfter puts back. */
export function digitsBefore(value: string, index: number): number {
  return value.slice(0, index).replace(/[^\d.]/g, '').length;
}
```

The field's input handler (`src/components/composites/MoneyField/MoneyField.tsx`, same example).
The caret is put back in the handler itself, not in an effect: when the shown value does not change
(a letter, or a point in a currency with no minor unit), React restores the input after the handler
and an effect's caret would be lost.

```tsx
function handleInput(e: ChangeEvent<HTMLInputElement>) {
  const el = e.currentTarget;
  const native = e.nativeEvent as InputEvent;
  const before = el.selectionStart ?? el.value.length;
  // A point typed (not pasted) in a currency with no minor unit changes nothing.
  const strayPoint = native.inputType === 'insertText' && native.data === '.' && !decimals(currency);
  const n = digitsBefore(el.value, strayPoint ? before - 1 : before);
  const next = strayPoint ? value : digits(el.value, currency);
  const shown = group(next);
  // Show the regrouped amount and put the caret back now, while this is the focused input.
  el.value = shown;
  if (el.ownerDocument.activeElement === el) {
    const at = caretAfter(shown, n);
    el.setSelectionRange(at, at);
  }
  if (next !== value) onChange(next);
}

// The visible input has no name; the form submits minor units from the hidden one.
<input id={id} type="text" inputMode={decimals(currency) ? 'decimal' : 'numeric'} autoComplete="off"
  value={group(value)} onChange={handleInput} />
<input type="hidden" name={name} value={String(minorUnits(value, currency))} />
```

The caller keeps the digits in major units (`'1250000'`, `'12.5'`) in its own state. A test types
with `user-event` and checks the shown value, the caret and the submitted form:
`await user.type(field(), '1250000'); expect(field()).toHaveValue('1,250,000');
expect([field().selectionStart, field().selectionEnd]).toEqual([9, 9]);`.

## Permission grid roving focus

`lib/grid.ts` is a typed port of the mockup's `data/grid.js`:
`gridMove(cell: { row, col }, event: { key, ctrlKey?, metaKey? }, size: { rows, cols })` returns the
next cell, or `null` for a key the grid does not handle. The component
(`src/components/composites/PermissionGrid/PermissionGrid.tsx` in `examples/starter-react/`, in the
proving repository), trimmed:

```tsx
const [active, setActive] = useState<GridCell>({ row: 0, col: 0 });
const cells = useRef(new Map<string, HTMLTableCellElement>());
// Focus follows the active cell only after a key moved it, never on the first render.
const moved = useRef(false);
useEffect(() => {
  if (!moved.current) return;
  moved.current = false;
  cells.current.get(`${active.row}-${active.col}`)?.focus();
}, [active]);

function onKeyDown(e: KeyboardEvent<HTMLTableElement>) {
  const next = gridMove(active, e, { rows: rows.length, cols: columns.length });
  if (!next) return; // any other key is left to the browser (Tab leaves the grid)
  e.preventDefault();
  moved.current = true;
  setActive(next);
}

return (
  <table
    // biome-ignore lint/a11y/noNoninteractiveElementToInteractiveRole: the WAI-ARIA grid pattern puts role="grid" on a table
    role="grid"
    id={id}
    onKeyDown={onKeyDown}
  >
    {/* caption, thead */}
    <tbody>
      {rows.map((r, i) => (
        <tr key={r.label}>
          <th scope="row">{r.label}</th>
          {r.cells.map((held, j) => (
            // biome-ignore lint/a11y/useKeyWithClickEvents: the grid's keydown handles every key for its cells
            <td
              // biome-ignore lint/suspicious/noArrayIndexKey: a cell is its column; columns never reorder
              key={j}
              id={`${id}-${i}-${j}`}
              ref={(el) => {
                if (el) cells.current.set(`${i}-${j}`, el);
                else cells.current.delete(`${i}-${j}`);
              }}
              tabIndex={i === active.row && j === active.col ? 0 : -1}
              onClick={() => setActive({ row: i, col: j })}
            >
              {held ? 'Yes' : 'No'}
            </td>
          ))}
        </tr>
      ))}
    </tbody>
  </table>
);
```

The `moved` ref is what keeps the grid from taking focus on mount; it is safe under StrictMode
because a double effect sees it already cleared. **jsdom gives a `td` in a `role="grid"` table the
role `cell`, not `gridcell`** (Chromium says `gridcell`, and the visual diff clicks it by that
role), so a test counts cells by element and follows focus by id:
`expect(grid().querySelectorAll('tbody td')).toHaveLength(12)`,
`expect(document.activeElement?.id).toBe('g-0-1')`.

## Focus on the page heading

On navigation the layout moves focus to the new page's `h1`, comparing with the last path so a
first load (and StrictMode's second effect run) moves nothing
(`src/components/layout/AppLayout/AppLayout.tsx` in both examples, in the proving repository):

```tsx
const { pathname } = useLocation();
const main = useRef<HTMLElement>(null);
const lastPath = useRef(pathname);

useEffect(() => {
  if (lastPath.current === pathname) return;
  lastPath.current = pathname;
  const heading = main.current?.querySelector('h1');
  if (heading) {
    heading.tabIndex = -1;
    heading.focus();
  }
}, [pathname]);
```

The global rule that goes with it. The mockup's `base.css` does not have it; the app adds it at
the end of its copy (`src/styles/base.css`, same examples):

```css
/* Headings take programmatic focus on route change; the focus is for screen readers, not a control */
h1[tabindex="-1"]:focus {
  outline: none;
}
```

Because the outline is gone, a heading focused when it should not be shows nothing on screen and
no visual diff catches it. Test it: render a page and `expect(document.body).toHaveFocus()` after
its heading appears, with StrictMode on in the [test setup](#test-setup).

## The http and telemetry tests

The scaffold ships `src/api/http.ts` and `src/lib/telemetry.ts` but no tests for them: the app
writes `tests/api/http.test.ts` and `tests/lib/telemetry.test.ts`. From `examples/paydesk-react/`
(in the proving repository), trimmed.

`http.test.ts` holds the error envelope, CSRF on state-changing methods only, and retryable
transport failures, against the MSW server from the setup:

```ts
import { HttpResponse, http } from 'msw';
import { describe, expect, it } from 'vitest';
import { ApiError, apiFetch } from '@/api/http';
import { server } from '../support/setup';

describe('apiFetch', () => {
  it('maps the error envelope to ApiError, keeping code and request id', async () => {
    server.use(
      http.get('*/v1/boom', () =>
        HttpResponse.json({ error: { code: 'rate_limited', message: 'slow down', request_id: 'req_1' } }, { status: 429 }),
      ),
    );
    const err = await apiFetch('/v1/boom').catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err).toMatchObject({ status: 429, code: 'rate_limited', requestId: 'req_1', retryable: false });
  });

  it('sends the CSRF cookie back as a header on state-changing calls only', async () => {
    // biome-ignore lint/suspicious/noDocumentCookie: the test plays the server setting the CSRF cookie
    document.cookie = 'csrf_token=abc123';
    const seen: Record<string, string | null> = {};
    server.use(
      http.all('*/v1/echo', ({ request }) => {
        seen[request.method] = request.headers.get('X-CSRF-Token');
        return HttpResponse.json({});
      }),
    );
    await apiFetch('/v1/echo');
    await apiFetch('/v1/echo', { method: 'POST' });
    expect(seen).toEqual({ GET: null, POST: 'abc123' });
  });

  it('treats a network failure as retryable', async () => {
    server.use(http.get('*/v1/down', () => HttpResponse.error()));
    const err = await apiFetch('/v1/down').catch((e: unknown) => e);
    expect(err).toMatchObject({ status: 0, code: 'network_error', retryable: true });
  });
});
```

The example adds the cross-origin cases the scaffold's `http.ts` supports: the token the server
last sent in `X-CSRF-Token` when no cookie is readable, a fresh cookie winning over a stale header
token, and `credentials: 'include'` only when `VITE_API_BASE_URL` is another origin (each re-imports
the module after `vi.resetModules()`, and the last uses `vi.stubEnv`).

`telemetry.test.ts` holds the redaction, one case per rule of `redact`:

```ts
import { describe, expect, it } from 'vitest';
import { redact } from '@/lib/telemetry';

describe('redact', () => {
  it('drops query strings, which carry filters and identifiers', () => {
    expect(redact('GET /api/v1/transactions?status=failed&cursor=abc failed')).toBe(
      'GET /api/v1/transactions?[redacted] failed',
    );
  });
  it('masks phone numbers and long digit runs, keeping the last four', () => {
    expect(redact('customer 4415550101 not found')).toBe('customer [digits:0101] not found');
  });
  it('removes tokens and keys', () => {
    expect(redact('Authorization bearer eyJhbGci.abc.def')).toBe('Authorization bearer=[redacted]');
  });
});
```

A rule the app adds to `redact` (the example also redacts reset tokens and challenge ids in URL
paths) gets its own case, with one that proves a literal path segment is left alone.

## Format helpers against the mockup runtime

`lib/format.ts` must give exactly what `MK.format` gives. The test loads the mockup's own `mk.js`
and strings in a `vm` and compares the two, so "identical" is proven rather than typed in. From
`tests/lib/format.test.ts` in `examples/equipment-loans-app/` (in the proving repository), a React
port whose mockup sits beside it:

```ts
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import vm from 'node:vm';
import { describe, expect, it } from 'vitest';
import { formatDate } from '@/lib/format';
import { enGB } from '@/locales/en-GB';

// The mockup runtime itself, loaded in a vm with its strings, is the oracle: lib/format.ts and the
// i18next resources must produce exactly what MK.format and MK.t produce, or the visual diff fails.
const MOCKUP = resolve(process.cwd(), '../equipment-loans/mockup');
function loadMockup() {
  // The runtime writes to window and the strings call the global MK, so window is the vm's global.
  const context = vm.createContext({
    document: { documentElement: { lang: '', dir: '' }, addEventListener: () => {}, readyState: 'loading' },
    location: { search: '' },
    console,
    Intl,
    Date,
    URLSearchParams,
  });
  context.window = context;
  vm.runInContext(readFileSync(resolve(MOCKUP, 'assets/mk.js'), 'utf8'), context);
  vm.runInContext(readFileSync(resolve(MOCKUP, 'strings/en-GB.js'), 'utf8'), context);
  return context.MK as {
    format: { date: (d: string) => string; dateTime: (iso: string) => string };
    t: (key: string, vars?: Record<string, unknown>) => string;
  };
}
const MK = loadMockup();

describe('lib/format mirrors MK.format', () => {
  it.each(['2026-11-27', '2026-12-01', '2027-01-31', '2026-03-29'])('date %s', (day) => {
    expect(formatDate(day)).toBe(MK.format.date(day));
  });
});

describe('strings mirror MK.t', async () => {
  const { i18n } = await import('@/lib/i18n');
  const vars = { name: 'Priya Raman', page: 2 }; // add every placeholder the app's keys use
  it.each(Object.keys(enGB))('%s', (key) => {
    expect(i18n.t(key, vars)).toBe(MK.t(key, vars));
  });
});
```

Point `MOCKUP` at wherever the signed-off mockup is in the app's repository. Pass
`location: { search: '?locale=fr-FR' }` to load the runtime as a page with that query, and compare
money (`MK.format.money(amount, currency)`) the same way.

Gotchas:

- **Resolve the mockup from `process.cwd()`, not with `new URL(rel, import.meta.url)`.** Under
  Vitest with jsdom, Vite rewrites `new URL('../x', import.meta.url)` into a dev server URL
  (`http://localhost:3000/@fs/...`), so `fileURLToPath` and `readFileSync` throw "The URL must be
  of scheme file". Vitest runs from the app root, so `resolve(process.cwd(), ...)` is stable.
- **Give the `vm` what the runtime touches and nothing else**: `window` as the context's own global
  (the strings files call the global `MK`), a stub `document` and `location`, and the host's `Intl`
  and `Date`, so both sides format with the same ICU data.
- **jsdom gives a `td` in a `role="grid"` table no `gridcell` role**: see the
  [permission grid](#permission-grid-roving-focus). Count such cells by element in jsdom; the
  visual diff, in Chromium, can query them by role.
