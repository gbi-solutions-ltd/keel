/**
 * What a screen is, shared by visual-diff.mjs and quality-check.mjs so the two cannot disagree.
 *
 * A screen in mockup.config.json:
 *   { name, page, route, states?: [...], role?: 'support', steps?: [...] }
 *   - page:  the mockup file, with its query (pages/transaction-detail.html?id=TX-1004)
 *   - route: the app URL with params filled in (/transactions/TX-1004)
 *   - role:  previewed on both sides with ?as=<role>
 *   - theme: 'light' or 'dark', previewed on both sides with ?theme=<theme> (the theming module)
 *   - locale: a locale code, or 'pseudo', previewed on both sides with ?locale=<code> (mk.js strings)
 *   - steps: interactions run after the page settles, then it settles again:
 *       { click: { role, name } }     getByRole, exact name
 *       { click: { role, name, appName } }  appName replaces name on the app side only (a mockup
 *                                     identifier the app draws wider: INV-0406 against INV-000406)
 *       { select: { label, value } }  a labelled select
 *       { fill: { label, value } }    a labelled text field ({ label, totp: <base32 secret> } types
 *                                     the authenticator's current code, lib/totp.mjs)
 *       { press: 'Control+k' }        a key or chord
 *       { type: 'nam' }               typed into whatever has focus
 *       { wait: 300 }                 milliseconds, only when nothing observable changes
 *     Any step may add "settleLayout": true: before it runs, wait for layout to be stable
 *     (layoutStable below). runSteps(page, steps, { settleLayout: true }) does it before every
 *     step (visual-diff.mjs --settle-steps). Off by default.
 *   - expectStatus: HTTP statuses the steps provoke on purpose ([401] for a wrong password), so
 *     the quality check does not count the browser's log of them as a console error
 *   - expectConsole: text a screen logs on purpose (a preview of a page that fails to render),
 *     so the quality check accepts those console errors and no others
 */
import { totp } from './totp.mjs';

/** The name part of a screen's slug: its name, else its route made safe for a file name. */
export function screenKey(screen) {
  return screen.name || screen.route.replace(/[^\w]+/g, '_').replace(/^_|_$/g, '') || 'root';
}

export function slugFor(screen, state, viewport) {
  return `${screenKey(screen)}--${state}--${viewport}`;
}

/**
 * Route filters (visual-diff.mjs --route / --exclude-route): include and exclude are RegExp or
 * null, tested against the screen's route, or its page when it has no route. True when the screen
 * is selected.
 */
export function routeSelected(screen, { include = null, exclude = null } = {}) {
  const target = screen.route ?? screen.page ?? '';
  if (include && !include.test(target)) return false;
  if (exclude && exclude.test(target)) return false;
  return true;
}

function withParams(url, screen, state) {
  const [path, query = ''] = url.split('?');
  const params = new URLSearchParams(query);
  if (state && state !== 'default') params.set('state', state);
  if (screen.role) params.set('as', screen.role);
  if (screen.theme) params.set('theme', screen.theme);
  if (screen.locale) params.set('locale', screen.locale);
  const qs = params.toString();
  return qs ? `${path}?${qs}` : path;
}

/**
 * The mockup URL, from the http base of a server for the mockup folder (lib/serve.mjs). Every
 * script loads the mockup served, never over file:// (fetch and localStorage differ there).
 */
export function mockupUrl(screen, state, { base } = {}) {
  if (!base) throw new Error('mockupUrl: needs { base }, the URL lib/serve.mjs serveMockup gives');
  return `${base}/${withParams(screen.page, screen, state)}`;
}

export function appUrl(screen, state, appBase) {
  return appBase + withParams(screen.route, screen, state);
}

/**
 * Settled: loaded, network idle or given up on (a ?state=loading request never ends by design),
 * fonts ready, and no DOM change for 400ms.
 */
export async function settle(page) {
  // A step that loads a new page (location.href, a form post) may still be navigating: an evaluate
  // then fails with "Execution context was destroyed". Wait for the new page and settle again.
  for (let attempt = 1; ; attempt++) {
    try {
      await settleOnce(page);
      return;
    } catch (e) {
      if (attempt >= 3 || !/Execution context was destroyed|navigation/i.test(e.message)) throw e;
      await page.waitForLoadState('load').catch(() => {});
    }
  }
}

async function settleOnce(page) {
  await page.waitForLoadState('networkidle', { timeout: 4000 }).catch(() => {});
  await page.evaluate(() => document.fonts.ready);
  await page.evaluate(() => new Promise((done) => {
    let t = setTimeout(end, 400);
    const stop = setTimeout(end, 10000);
    const o = new MutationObserver(() => { clearTimeout(t); t = setTimeout(end, 400); });
    o.observe(document.documentElement, { subtree: true, childList: true, attributes: true, characterData: true });
    function end() { o.disconnect(); clearTimeout(t); clearTimeout(stop); done(); }
  }));
}

/** The steps as the app side runs them: a click's appName, when given, replaces its name. */
export function appSteps(steps = []) {
  return steps.map((step) => {
    if (!step.click?.appName) return step;
    const { appName, ...click } = step.click;
    return { ...step, click: { ...click, name: appName } };
  });
}

/**
 * Layout stable: document.fonts.ready, then document scroll height unchanged across two animation
 * frames, capped at capMs (default 2000) so a page that never stops growing does not hang a run.
 * Resolves true when stable, false when the cap was hit.
 */
export async function layoutStable(page, capMs = 2000) {
  return page.evaluate(async (cap) => {
    const deadline = performance.now() + cap;
    const frame = () => new Promise((r) => requestAnimationFrame(() => r()));
    const capped = (p) => Promise.race([p, new Promise((r) => setTimeout(() => r('cap'), Math.max(0, deadline - performance.now())))]);
    if ((await capped(document.fonts.ready.then(() => 'ok'))) === 'cap') return false;
    let last = document.documentElement.scrollHeight;
    while (performance.now() < deadline) {
      if ((await capped(frame().then(frame))) === 'cap') return false;
      const h = document.documentElement.scrollHeight;
      if (h === last) return true;
      last = h;
    }
    return false;
  }, capMs);
}

/**
 * A click step lands where a person's click would. When the named element is visible but another
 * element above it takes the pointer (a kit's field around its own input: Vuetify's select input is
 * pointer-events: none, and the field's mousedown opens the menu), the click goes to the same point
 * with force, so the element under the pointer gets it. Any other failure is the normal click's.
 */
export async function clickStep(page, { role, name }) {
  const target = page.getByRole(role, { name, exact: true }).first();
  try {
    await target.click({ trial: true, timeout: 1000 });
  } catch (err) {
    if (/pointer events/i.test(String(err?.message)) && (await target.isVisible().catch(() => false))) return target.click({ force: true });
  }
  return target.click();
}

export async function runSteps(page, steps = [], { settleLayout = false } = {}) {
  for (const step of steps) {
    if (settleLayout || step.settleLayout) await layoutStable(page);
    if (step.click) await clickStep(page, step.click);
    else if (step.select) await page.getByLabel(step.select.label, { exact: true }).selectOption(step.select.value);
    else if (step.fill) await page.getByLabel(step.fill.label, { exact: true }).fill(step.fill.totp ? totp(step.fill.totp) : step.fill.value);
    else if (step.press) await page.keyboard.press(step.press);
    else if (step.type) await page.keyboard.type(step.type, { delay: 30 });
    else if (step.wait) await page.waitForTimeout(step.wait);
    else throw new Error(`unknown step ${JSON.stringify(step)}`);
    await settle(page);
  }
}

/**
 * What makes a config's screens unusable to visual-diff.mjs, whatever the filters: two viewports
 * or two screens with one name (their PNGs and case folders collide, and --write-baseline
 * overwrites one with the other), a state listed twice, two cases with one slug through the --
 * separator, a screen with neither name nor route (no slug at all), and with { app: true } a
 * screen with no route. Returns a list of "path: problem" strings, empty when there is none.
 */
export function screenProblems(config, { app = false } = {}) {
  const out = [];
  const viewports = config?.viewports || [{ name: 'desktop' }];
  const vpSeen = new Map();
  viewports.forEach((v, i) => {
    if (vpSeen.has(v?.name)) out.push(`viewports[${i}]: name ${v.name} is also viewports[${vpSeen.get(v.name)}]'s (their PNGs and case folders would collide)`);
    else vpSeen.set(v?.name, i);
  });
  const keySeen = new Map(), slugSeen = new Map();
  (config?.screens || []).forEach((s, i) => {
    if (!s?.name && !s?.route) { out.push(`screens[${i}]: neither name nor route, so it has no slug`); return; }
    const key = screenKey(s);
    const label = `screens[${i}] ${key}`;
    if (app && !s.route) out.push(`${label}: no route, which app mode needs`);
    if (keySeen.has(key)) { out.push(`screens[${i}]: name ${key}${s.name ? '' : ' (from its route)'} is also screens[${keySeen.get(key)}]'s (their PNGs and case folders would collide)`); return; }
    keySeen.set(key, i);
    const states = s.states || ['default'];
    const twice = states.filter((st, j) => states.indexOf(st) !== j);
    for (const st of new Set(twice)) out.push(`${label}: state ${st} is listed twice`);
    for (const st of new Set(states)) {
      for (const v of vpSeen.keys()) {
        const slug = slugFor(s, st, v);
        if (slugSeen.has(slug) && slugSeen.get(slug) !== i) out.push(`${label}: slug ${slug} is also screens[${slugSeen.get(slug)}]'s`);
        else slugSeen.set(slug, i);
      }
    }
  });
  return out;
}

/** Every screen and state the config gives, in order: [{ name, state, route }]. */
export function casesFor(config) {
  return (config.screens || []).flatMap((s) => (s.states || ['default']).map((state) => ({ name: screenKey(s), state, route: s.route ?? s.page })));
}
