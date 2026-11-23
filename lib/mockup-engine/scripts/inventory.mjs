#!/usr/bin/env node
/**
 * inventory.mjs: read a convention-following mockup and describe it.
 *
 *   node inventory.mjs <mockup-dir> [--out <dir>] [--accepted <file>] [--ready-to-port]
 *   node inventory.mjs --mockup <mockup-dir> [--out <dir>] [--accepted <file>] [--ready-to-port]
 *
 * Writes <out>/inventory.json and <out>/inventory.md (default out: <mockup-dir>/.mockup-engine).
 * Loads every page in a real browser (components render via JS), served over HTTP from a local
 * server (lib/serve.mjs), as the other checks load the mockup, then records:
 *   pages, routes, layouts, component tree, actions, links, forms, needs/todos,
 *   tokens, fixtures shape, and convention violations ("lint").
 * A page is described once per distinct role among its config screens (the screen's role, or an
 * ?as= in its page query), as that role. Components used and tour anchors are collected over every
 * config screen, in every state, with its role and steps.
 * Exit codes (lib/args.mjs): 0 passed. 1, after the summary line and both files, when lint found
 * any issue (config problems included) or no page was found, or with --ready-to-port when the
 * mockup is not ready. 2 when it could not run, with no summary line and nothing written: a bad
 * argument (an unknown flag, a value flag with no value), no mockup.config.json (as check-config.mjs),
 * a config that is not valid JSON or not a JSON object, a bad accepted-findings file, a crash (a
 * page that does not load). Undecided checklist items are listed but never change the exit code: a
 * fresh starter leaves them all undecided on purpose. A config without screens lists pages/*.html
 * as its screens (lint rule no-config).
 *
 * Accepted findings (--accepted <file>, default <mockup-dir>/docs/inventory-accepted.json when it
 * exists; the same place and shape of decision record as visual-diff's docs/expected-diffs.json, kept
 * out of mockup.config.json so the config stays what the mockup is, not what was waived):
 *   { "accepted": [{ "rule": "raw-value", "where": "assets/base.css", "detail"?: "#fff", "reason": "..." }] }
 *   - An entry matches a finding with the same rule, and the same where; a where without a line
 *     number ("assets/base.css") also matches every "assets/base.css:<line>", so an edit above the
 *     line does not break it. detail, when given, must be a substring of the finding's detail.
 *     One entry may match several findings; when entries overlap, each one that matches counts as
 *     used and the first one's reason is listed.
 *   - reason is required (a non-empty string). Unknown keys, at the top or in an entry, a missing or
 *     non-string rule or where, a named file that is missing, or bad JSON: exit 2 before any page
 *     loads, with no summary line.
 *   - Accepted findings are listed apart (inventory.json "accepted", with their reason; an
 *     "Accepted lint" table in inventory.md; ", N accepted" on the summary line) and do not fail
 *     the run. Every other finding stays in "lint" and still exits 1.
 *   - An entry that matches no finding is stale: a warning on stderr, listed in inventory.json
 *     "acceptedStale" and inventory.md. It never changes the exit code.
 *
 * The config (lib/project.mjs, lib/mockup-engine/mockup-config.schema.json): mockup.config.json is validated
 * on every run. Unknown keys, wrong types and values, and the rules the schema cannot say (a design
 * framework with no name, a default locale not in the locales) are lint, rule "config". A project
 * answer settles its checklist item as a module does (project.i18n settles localisation,
 * project.theming settles dark-mode). The project's readiness is always written to inventory.json
 * ("readiness") and inventory.md, and printed as one line, "ready to port (decisions only)": it covers
 * the decisions, not whether the screens are designed (that is the sign-off's question). check-config.mjs
 * runs the same config checks without a browser, for straight after the intake.
 *
 * Strings: with project.i18n, every page must load strings (rule i18n-strings), its first strings file
 * must be the default locale (i18n-default), every project locale must have strings (i18n-locale) and
 * the same keys as the default (i18n-keys). Without project.i18n these rules do not run; the
 * readiness check asks for it.
 *
 *   --ready-to-port   also exit 1 when the mockup is not ready to convert: a tier 1 project answer
 *                     missing, a tier 2 answer neither decided nor deferred with an owner and a date,
 *                     or a checklist item undecided. Each is printed as "not ready: <field>: <why>".
 *                     Also no valid sign-off (lib/signoff.mjs, skills/mockup/references/signoff.md): no record, the
 *                     mockup or the contract changed since its last round, a fixture the contract
 *                     rejects; each printed as "not ready: signoff: <problem>". The sign-off is always
 *                     printed ("signed off: yes, round N" or "no") and written to inventory.json.
 */
import './lib/browsers-env.mjs'; // first: playwright reads its browsers path when it loads
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from 'node:fs';
import { signoffStatus } from './lib/signoff.mjs';
import { join, resolve, relative } from 'node:path';
import vm from 'node:vm';
import { chromium } from 'playwright';
import { mockupUrl, runSteps, settle } from './lib/screens.mjs';
import { serveMockup } from './lib/serve.mjs';
import { CHECKLIST, MODULE_COVERS, configProblems, readiness, settledByProject } from './lib/project.mjs';
import { cli } from './lib/args.mjs';

const { values: flags, positional: [positional] } = cli('inventory');
const opt = (name) => flags[name];
const readyToPort = Boolean(flags['ready-to-port']);
const mockupDir = resolve(opt('mockup') || positional || '.');
const outDir = resolve(opt('out') || join(mockupDir, '.mockup-engine'));
let browser;
let server;

/** Reads and validates the accepted-findings file (see the file comment). Returns { error } or { file, entries }. */
function loadAccepted() {
  const named = opt('accepted');
  const file = named ? resolve(named) : join(mockupDir, 'docs/inventory-accepted.json');
  if (!existsSync(file)) return named ? { error: `${file}: missing` } : { file: null, entries: [] };
  let data;
  try { data = JSON.parse(readFileSync(file, 'utf8')); } catch (e) { return { error: `${file}: not valid JSON: ${e.message}` }; }
  if (!data || typeof data !== 'object' || Array.isArray(data)) return { error: `${file}: must be an object with an "accepted" array` };
  const top = Object.keys(data).filter((k) => k !== 'accepted');
  if (top.length) return { error: `${file}: unknown keys: ${top.join(', ')}` };
  if (!Array.isArray(data.accepted)) return { error: `${file}: "accepted" must be an array` };
  const errors = [];
  data.accepted.forEach((e, i) => {
    const at = `accepted[${i}]`;
    if (!e || typeof e !== 'object' || Array.isArray(e)) { errors.push(`${at} must be an object`); return; }
    const unknown = Object.keys(e).filter((k) => !['rule', 'where', 'detail', 'reason'].includes(k));
    if (unknown.length) errors.push(`${at} has unknown keys: ${unknown.join(', ')}`);
    for (const k of ['rule', 'where']) if (typeof e[k] !== 'string' || !e[k].trim()) errors.push(`${at}.${k} must be a non-empty string`);
    if (e.detail !== undefined && typeof e.detail !== 'string') errors.push(`${at}.detail must be a string`);
    if (typeof e.reason !== 'string' || !e.reason.trim()) errors.push(`${at}.reason is required: say why this finding is accepted`);
  });
  if (errors.length) return { error: `${file}: ${errors.join('; ')}` };
  return { file, entries: data.accepted };
}

const acceptedMatches = (e, l) =>
  e.rule === l.rule && (e.where === l.where || e.where === String(l.where).replace(/:\d+$/, '')) && (e.detail === undefined || String(l.detail).includes(e.detail));

async function main() {
  // Could not run (exit 2, no summary line, nothing written): no config, a config that is not a
  // JSON object, a bad accepted-findings file.
  const cannotRun = (msg) => { console.error(`inventory: ${msg}`); process.exitCode = 2; };
  const cfgFile = join(mockupDir, 'mockup.config.json');
  if (!existsSync(cfgFile)) return cannotRun(`missing ${cfgFile} (check-config.mjs checks a new one)`);
  let config;
  try { config = JSON.parse(readFileSync(cfgFile, 'utf8')); } catch (e) { return cannotRun(`${cfgFile} is not valid JSON: ${e.message}`); }
  if (!config || typeof config !== 'object' || Array.isArray(config)) return cannotRun(`${cfgFile} is not a JSON object`);
  const acceptedFile = loadAccepted();
  if (acceptedFile.error) return cannotRun(acceptedFile.error);
  mkdirSync(outDir, { recursive: true });

  const read = (p) => (existsSync(p) ? readFileSync(p, 'utf8') : '');

  // ---------- static analysis ----------------------------------------------------
  const tokensCss = read(join(mockupDir, 'assets/tokens.css'));
  const tokens = {};
  for (const m of tokensCss.matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)) tokens[m[1]] = m[2].trim();
  const tokenGroups = {};
  for (const name of Object.keys(tokens)) {
    const group = name.replace(/^--/, '').split('-')[0];
    (tokenGroups[group] ||= []).push(name);
  }

  function shapeOf(value, depth = 0) {
    if (Array.isArray(value)) {
      if (!value.length) return 'unknown[]';
      return `${shapeOf(value[0], depth)}[]`;
    }
    if (value === null) return 'null';
    if (typeof value === 'object') {
      if (depth > 3) return 'object';
      const inner = Object.entries(value).map(([k, v]) => `${k}: ${shapeOf(v, depth + 1)}`).join('; ');
      return `{ ${inner} }`;
    }
    if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(value)) return 'string /* ISO date */';
    return typeof value;
  }
  let fixtures = {};
  const fixturesSrc = read(join(mockupDir, 'data/fixtures.js'));
  if (fixturesSrc) {
    const sandbox = { window: {} };
    vm.runInNewContext(fixturesSrc, sandbox);
    fixtures = sandbox.window.FIXTURES || {};
  }
  const fixtureShapes = Object.fromEntries(
    Object.entries(fixtures).map(([k, v]) => [k, { shape: shapeOf(v), count: Array.isArray(v) ? v.length : 1 }]),
  );
  const jsdocTypedefs = [...fixturesSrc.matchAll(/@typedef\s+(\{[\s\S]*?\})\s+(\w+)/g)].map((m) => ({ name: m[2], type: m[1].replace(/\s*\*\s*/g, ' ') }));

  const componentFiles = existsSync(join(mockupDir, 'components'))
    ? readdirSync(join(mockupDir, 'components')).filter((f) => f.endsWith('.js'))
    : [];
  const componentsCss = read(join(mockupDir, 'assets/components.css'));
  const cssBlocks = [...componentsCss.matchAll(/\/\*\s*([A-Z][\w /]*?)\s*\*\//g)].flatMap((m) => m[1].split('/').map((s) => s.trim()));

  const lint = [];
  for (const problem of configProblems(config)) {
    const [where, ...rest] = problem.split(': ');
    lint.push({ rule: 'config', where: `mockup.config.json ${where}`, detail: rest.join(': ') });
  }
  // Keel house style: no em or en dash anywhere, UI copy and comments included
  function walkFiles(dir) {
    return readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
      if (e.name.startsWith('.')) return [];
      const p = join(dir, e.name);
      return e.isDirectory() ? walkFiles(p) : /\.(html|js|css|json)$/.test(e.name) ? [p] : [];
    });
  }
  for (const f of walkFiles(mockupDir)) {
    read(f).split('\n').forEach((line, i) => {
      if (/[\u2013\u2014]/.test(line)) lint.push({ rule: 'dash', where: `${relative(mockupDir, f)}:${i + 1}`, detail: line.trim().slice(0, 80) });
    });
  }
  // raw colour values outside tokens.css
  for (const f of ['assets/base.css', 'assets/components.css']) {
    const src = read(join(mockupDir, f));
    src.split('\n').forEach((line, i) => {
      if (/#[0-9a-fA-F]{3,8}\b|rgb\(|hsl\(/.test(line) && !line.includes('var(--')) {
        lint.push({ rule: 'raw-value', where: `${f}:${i + 1}`, detail: line.trim() });
      }
    });
  }

  // ---------- discover pages -----------------------------------------------------
  let screens = config.screens;
  if (!screens) {
    const pagesDir = join(mockupDir, 'pages');
    screens = existsSync(pagesDir)
      ? readdirSync(pagesDir).filter((f) => f.endsWith('.html')).map((f) => ({ page: `pages/${f}`, states: ['default', 'empty', 'loading', 'error'] }))
      : [];
    lint.push({ rule: 'no-config', where: 'mockup.config.json', detail: 'no screens: screens discovered from pages/; list them in the config so routes and states are explicit' });
  }

  // Several screens may show one page (roles, steps, themes); describe each page once per distinct
  // role among its screens, as that role (the screen's role wins over an ?as= in its page query, as
  // in lib/screens.mjs), from the first screen with that role, without its steps or theme.
  const roleOf = (sc) => sc.role || new URLSearchParams(sc.page.split('?')[1] || '').get('as') || null;
  {
    const seen = new Set();
    screens = screens.filter((sc) => { const k = `${sc.page.split('?')[0]}|${roleOf(sc) || ''}`; if (seen.has(k)) return false; seen.add(k); return true; })
      .map((sc) => ({ ...sc, role: sc.role || undefined, steps: undefined, theme: undefined }));
  }
  const pageFiles = new Set(screens.map((sc) => sc.page.split('?')[0]));

  // Served over HTTP, as every other check loads the mockup: fetch and localStorage behave as in a
  // browser, which they do not under file://.
  let base;
  ({ server, base } = await serveMockup(mockupDir));
  const urlFor = (screen, state) => mockupUrl({ page: screen.page, role: screen.role }, state, { base });
  // Tour anchors seen on any render, by the rendered page's route (a route pattern, as tours name it).
  const anchorsByRoute = new Map();
  const addAnchors = (route, anchors) => {
    if (!route) return;
    if (!anchorsByRoute.has(route)) anchorsByRoute.set(route, new Set());
    for (const a of anchors) anchorsByRoute.get(route).add(a);
  };
  const readAnchors = () => ({
    route: window.MK?.inspect().page?.route || null,
    anchors: [...new Set([...document.querySelectorAll('[data-tour]')].map((el) => el.dataset.tour))],
  });

  // ---------- runtime analysis ---------------------------------------------------
  browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const results = [];

  for (const screen of screens) {
    const page = await ctx.newPage();
    const consoleErrors = [];
    page.on('console', (m) => { if (['error', 'warning'].includes(m.type())) consoleErrors.push(m.text()); });
    page.on('pageerror', (e) => consoleErrors.push(String(e)));
    page.on('dialog', (d) => d.dismiss());

    const res = await page.goto(urlFor(screen, 'default'));
    // a page that is not there is a 404 from the server (under file:// it was a navigation error)
    if (res && !res.ok()) throw new Error(`${screen.page}: HTTP ${res.status()}, the page does not load`);
    await page.waitForLoadState('load');

    const dom = await page.evaluate(() => {
      const tree = (el) => {
        const kids = [];
        el.querySelectorAll(':scope > *').forEach((c) => kids.push(...(c.dataset.component ? [tree(c)] : tree(c).children || [])));
        return el.dataset?.component ? { name: el.dataset.component, children: kids } : { children: kids };
      };
      const text = (el) => (el.innerText || el.value || '').trim().replace(/\s+/g, ' ').slice(0, 60);
      return {
        mk: window.MK ? window.MK.inspect() : null,
        // A role without the page's permission sees the shell's forbidden page instead.
        forbidden: (() => {
          const perm = window.MK?.inspect().page?.needs?.permission;
          return Boolean(perm && typeof window.MK.can === 'function' && !window.MK.can(perm));
        })(),
        componentTree: tree(document.getElementById('app') || document.body).children,
        actions: [...document.querySelectorAll('[data-action]')].map((el) => ({
          action: el.dataset.action, tag: el.tagName.toLowerCase(), on: el.dataset.on || null, label: text(el),
          inComponent: el.closest('[data-component]')?.dataset.component || null,
        })),
        links: [...new Set([...document.querySelectorAll('a[href]')].map((a) => a.getAttribute('href')))],
        forms: [...document.querySelectorAll('form')].map((f) => ({
          action: f.dataset.action || null,
          fields: [...f.querySelectorAll('input,select,textarea')].map((i) => ({ name: i.name || null, type: i.type, required: i.required })),
        })),
        todos: [...document.querySelectorAll('[data-todo]')].map((el) => ({ todo: el.dataset.todo, label: text(el) })),
        dashText: (document.body.innerText.match(/.{0,30}[\u2013\u2014].{0,30}/) || [null])[0],
        inlineStyles: [...document.querySelectorAll('#app [style]')].map((el) => `${el.tagName.toLowerCase()}[style="${el.getAttribute('style')}"]`),
        diffIgnored: document.querySelectorAll('[data-diff-ignore]').length,
        tours: window.HELP?.tours || null,
        tourAnchors: [...new Set([...document.querySelectorAll('[data-tour]')].map((el) => el.dataset.tour))],
        // stylesheets and scripts the page loads, as written (for the design framework rules)
        assetsLoaded: [...document.querySelectorAll('link[rel="stylesheet"][href], script[src]')].map((el) => el.getAttribute('href') || el.getAttribute('src')),
      };
    });

    // which components appear in each non-happy state?
    const stateCoverage = {};
    for (const state of ['empty', 'loading', 'error']) {
      await page.goto(urlFor(screen, state));
      await page.waitForLoadState('load');
      stateCoverage[state] = await page.evaluate(() => ({
        scenario: window.MK?.inspect().page?.scenario,
        used: window.MK?.inspect().componentsUsed || [],
      }));
      const seen = await page.evaluate(readAnchors);
      addAnchors(seen.route, seen.anchors);
    }
    addAnchors(dom.mk?.page?.route, dom.tourAnchors);
    await page.close();

    const id = dom.mk?.page?.id || screen.page;
    if (!dom.mk) lint.push({ rule: 'no-runtime', where: screen.page, detail: 'page does not use mk.js, so conversion will be manual' });
    if (dom.mk && !dom.mk.page) lint.push({ rule: 'no-page-def', where: screen.page, detail: 'MK.page() never called' });
    if (dom.mk?.page && !dom.mk.page.route) lint.push({ rule: 'no-route', where: screen.page, detail: 'page has no route' });
    if (dom.mk?.page && !dom.mk.page.needs?.permission) lint.push({ rule: 'no-permission', where: id, detail: 'needs.permission is missing: every route declares who may see it (deny by default); write "public" if it is open' });
    if (dom.dashText) lint.push({ rule: 'dash', where: id, detail: `rendered text: ${dom.dashText}` });
    if (dom.inlineStyles.length) lint.push({ rule: 'inline-style', where: screen.page, detail: dom.inlineStyles.slice(0, 5).join(', ') });
    // A page that loads data shows a skeleton while loading and our own error copy on failure (not
    // judged for a role the page refuses, which sees the forbidden page in every state).
    if (dom.mk?.page?.loads && !dom.forbidden) {
      if (!stateCoverage.loading.used.some((c) => /Skeleton/.test(c))) lint.push({ rule: 'missing-state', where: id, detail: '?state=loading renders no skeleton component' });
      if (!stateCoverage.error.used.includes('ErrorState')) lint.push({ rule: 'missing-state', where: id, detail: '?state=error does not render ErrorState' });
    }
    consoleErrors.forEach((e) => lint.push({ rule: 'console', where: id, detail: e }));

    results.push({ screen, ...dom, stateCoverage, consoleErrors });
  }
  // Components and tour anchors that appear only for another role, in a later state or after an
  // interaction (a palette, a menu, a tab) count as present: replay every configured screen in each
  // of its states, with its role and steps.
  const replayed = new Set();
  for (const sc of config?.screens || []) {
    for (const state of sc.states || ['default']) {
      const pg = await ctx.newPage();
      pg.on('dialog', (d) => d.dismiss());
      try {
        await pg.goto(mockupUrl(sc, state, { base }));
        await settle(pg);
        await runSteps(pg, sc.steps);
        (await pg.evaluate(() => window.MK?.inspect().componentsUsed || [])).forEach((c) => replayed.add(c));
        const seen = await pg.evaluate(readAnchors);
        addAnchors(seen.route, seen.anchors);
      } catch (e) {
        lint.push({ rule: 'screen-steps', where: `${sc.name || sc.page}${state === 'default' ? '' : ` (${state})`}`, detail: String(e.message).split('\n')[0] });
      }
      await pg.close();
    }
  }
  await browser.close();
  browser = null;
  server.close();
  server = null;

  // cross-page lint
  const registered = new Set(results.flatMap((r) => r.mk?.componentsRegistered || []));
  const meta = Object.assign({}, ...results.map((r) => r.mk?.componentMeta || {}));
  const LAYER_ORDER = ['primitive', 'composite', 'domain', 'layout'];
  for (const [name, m] of Object.entries(meta)) {
    if (!LAYER_ORDER.includes(m.layer)) lint.push({ rule: 'no-layer', where: name, detail: `register with { layer: ${LAYER_ORDER.join(' | ')} }` });
  }
  // a component may contain only components of its own layer or below
  function checkTree(nodes, parent) {
    for (const n of nodes) {
      const pl = parent && LAYER_ORDER.indexOf(meta[parent]?.layer);
      const cl = LAYER_ORDER.indexOf(meta[n.name]?.layer);
      if (parent && pl >= 0 && cl > pl) lint.push({ rule: 'layer-order', where: `${parent} > ${n.name}`, detail: `${meta[parent].layer} contains ${meta[n.name].layer}` });
      checkTree(n.children || [], n.name);
    }
  }
  results.forEach((r) => checkTree(r.componentTree, null));
  const usedAnywhere = new Set([...results.flatMap((r) => [r.mk?.componentsUsed || [], ...Object.values(r.stateCoverage).map((s) => s.used)].flat()), ...replayed]);
  const stamped = new Set();
  const collect = (nodes) => nodes.forEach((n) => { stamped.add(n.name); collect(n.children || []); });
  results.forEach((r) => collect(r.componentTree));
  for (const c of registered) {
    if (!usedAnywhere.has(c)) lint.push({ rule: 'unused-component', where: c, detail: 'registered but never rendered' });
    const kebab = c.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase();
    // A wrapper (its root is another component) has no box of its own, so it needs no styles.
    if (!stamped.has(c)) continue;
    // A utility-css mockup styles a component with classes in its template, not a CSS block.
    if (config?.project?.designFramework?.kind === 'utility-css') continue;
    if (!cssBlocks.includes(c) && !componentsCss.includes(`.${kebab}`)) lint.push({ rule: 'no-css-block', where: c, detail: `no /* ${c} */ block or .${kebab} class in components.css` });
  }

  // Roles: who sees which page, menu entry and permission-gated control. The client signs this off.
  const roles = results.find((r) => r.mk?.roles)?.mk.roles || {};
  const shell = results.find((r) => r.mk?.shell)?.mk.shell || null;
  // A page described for several roles has one definition: the first description of a route wins.
  const pagesByRoute = Object.fromEntries(results.filter((r) => r.mk?.page).reverse().map((r) => [r.mk.page.route, r.mk.page]));
  for (const n of shell?.nav || []) {
    const target = pagesByRoute[n.route];
    if (!target) lint.push({ rule: 'nav-target', where: `nav ${n.label ?? n.labelKey}`, detail: `no page with route ${n.route}` });
    else if (target.needs?.permission !== n.permission) lint.push({ rule: 'nav-permission', where: `nav ${n.label ?? n.labelKey}`, detail: `menu needs ${n.permission} but the page needs ${target.needs?.permission}: a role could see a link the page refuses` });
  }
  const known = new Set(Object.values(roles).flatMap((r) => r.permissions));
  for (const pg of Object.values(pagesByRoute)) {
    for (const perm of [pg.needs?.permission, ...(pg.needs?.uses || [])].filter((x) => x && x !== 'public' && x !== 'authenticated')) {
      if (Object.keys(roles).length && !known.has(perm)) lint.push({ rule: 'unknown-permission', where: pg.id, detail: `${perm} is held by no role` });
    }
  }
  const matrix = [];
  for (const pg of Object.values(pagesByRoute)) {
    const p = pg.needs?.permission;
    matrix.push({ what: `page ${pg.route}`, permission: p, roles: Object.fromEntries(Object.entries(roles).map(([k, r]) => [k, p === 'public' || p === 'authenticated' || r.permissions.includes(p)])) });
    for (const u of pg.needs?.uses || []) {
      const perm = u.split(' ')[0];
      matrix.push({ what: `  on ${pg.route}`, permission: perm, roles: Object.fromEntries(Object.entries(roles).map(([k, r]) => [k, r.permissions.includes(perm)])) });
    }
  }

  // ---------- modules and the checklist (skills/mockup/references/modules.md) -------------------
  // Each module's pages, and the checklist items it settles when it is on.
  const MODULES = {
    'auth-mfa': { routes: ['/sign-in', '/sign-in/verify', '/account/security'] },
    'tours-help': { routes: ['/help'] },
    'users-roles': { routes: ['/settings/users', '/settings/users/:id', '/settings/roles'] },
    'audit-log': { routes: ['/audit'] },
    'session-password': { routes: ['/forgot-password', '/reset-password', '/signed-out'] },
    notifications: { routes: ['/notifications', '/account/notifications'] },
    'system-pages': { routes: ['*', '*:render-error', '*:maintenance'] },
  };
  for (const [m, covers] of Object.entries(MODULE_COVERS)) MODULES[m].covers = covers;
  const DECISIONS = ['designed', 'later', 'not-needed'];
  const modules = config?.modules || [];
  for (const m of modules) {
    if (!MODULES[m]) { lint.push({ rule: 'unknown-module', where: 'mockup.config.json modules', detail: `${m}: known modules are ${Object.keys(MODULES).join(', ')}` }); continue; }
    for (const route of MODULES[m].routes) if (!pagesByRoute[route]) lint.push({ rule: 'module-page', where: m, detail: `no page with route ${route}` });
  }
  // Every tour step must point at an anchor its page renders on some config screen: any role, state
  // or step, judged only after every screen has been seen.
  const tours = results.find((r) => r.tours)?.tours || [];
  if (tours.length && !modules.includes('tours-help')) lint.push({ rule: 'module-undeclared', where: 'data/help.js', detail: 'tours are defined: add "tours-help" to modules in mockup.config.json' });
  for (const t of tours) {
    const host = results.find((r) => r.mk?.page?.route === t.route);
    if (!host) { lint.push({ rule: 'tour-route', where: `tour ${t.id}`, detail: `no page with route ${t.route}` }); continue; }
    if (t.permission !== host.mk.page.needs?.permission) lint.push({ rule: 'tour-permission', where: `tour ${t.id}`, detail: `tour needs ${t.permission} but the page needs ${host.mk.page.needs?.permission}` });
    const anchors = anchorsByRoute.get(t.route) || new Set();
    for (const step of t.steps) if (!anchors.has(step.target)) lint.push({ rule: 'tour-anchor', where: `tour ${t.id}`, detail: `no data-tour="${step.target}" on any screen of ${t.route}` });
  }
  // Design framework (intake.md, question 2; design-frameworks.md): a utility-css or css-library
  // mockup loads the framework's CSS from assets/vendor/ on every page, and the file is there. A
  // js-kit mockup declares its gate: diff.maxMismatchPercent set in the config, behaviours, and the
  // kit components the DOM oracle leaves opaque.
  const df = config?.project?.designFramework;
  if (df && ['utility-css', 'css-library'].includes(df.kind)) {
    for (const r of results.filter((x) => x.mk?.page)) {
      const file = r.screen.page.split('?')[0];
      const vendor = (r.assetsLoaded || []).filter((a) => /(^|\/)assets\/vendor\//.test(a) && /\.css(\?|$)/.test(a));
      if (!vendor.length) lint.push({ rule: 'framework-css', where: file, detail: `project.designFramework is ${df.kind} (${df.name || 'unnamed'}): load its CSS from assets/vendor/<name>/ on every page` });
      for (const a of vendor) {
        const abs = resolve(mockupDir, file.split('/').slice(0, -1).join('/'), a.split('?')[0]);
        if (!existsSync(abs)) lint.push({ rule: 'framework-css', where: file, detail: `${a} is not there: copy the framework's built CSS in at the pinned version` });
      }
    }
  }
  if (df?.kind === 'js-kit') {
    if (config?.diff?.maxMismatchPercent === undefined) lint.push({ rule: 'framework-gate', where: 'mockup.config.json diff', detail: 'a js-kit mockup is an approximation: declare the agreed tolerance as diff.maxMismatchPercent' });
    if (!existsSync(join(mockupDir, 'docs/behaviours.json'))) lint.push({ rule: 'framework-gate', where: 'docs/behaviours.json', detail: 'a js-kit port is proven by its behaviours as much as its pixels: write docs/behaviours.json' });
    if (!config?.domOracle?.opaqueComponents?.length) lint.push({ rule: 'framework-gate', where: 'mockup.config.json domOracle', detail: 'the DOM oracle compares the parts we own: list the kit components it leaves opaque as domOracle.opaqueComponents' });
  }
  // Strings and locales (mockup-strings.md): with project.i18n every page loads the
  // strings, its default locale is the project's, every project locale has a strings file, and every
  // locale has the default's keys. Strings with no project.i18n are left to the readiness check,
  // which already asks for project.i18n, so a starter carries no language answer it never asked.
  const i18nDecl = config?.project?.i18n;
  const pagesI18n = results.filter((r) => r.mk?.page).map((r) => ({ file: r.screen.page, i18n: r.mk.i18n }));
  if (i18nDecl) {
    for (const pg of pagesI18n) {
      const file = pg.file.split('?')[0];
      if (!pg.i18n?.defaultLocale) { lint.push({ rule: 'i18n-strings', where: file, detail: 'loads no strings file: copy comes from strings/<locale>.js through MK.t' }); continue; }
      if (pg.i18n.defaultLocale !== i18nDecl.defaultLocale) lint.push({ rule: 'i18n-default', where: file, detail: `its first strings file is ${pg.i18n.defaultLocale}, but project.i18n.defaultLocale is ${i18nDecl.defaultLocale}: load the default locale's file first` });
      for (const code of i18nDecl.locales || []) if (!pg.i18n.keys?.[code]) lint.push({ rule: 'i18n-locale', where: file, detail: `loads no strings for ${code}` });
    }
    const keys = Object.assign({}, ...pagesI18n.map((p) => p.i18n?.keys || {}));
    const base = new Set(keys[i18nDecl.defaultLocale] || []);
    for (const [code, list] of Object.entries(keys)) {
      if (code === i18nDecl.defaultLocale) continue;
      const have = new Set(list);
      const missing = [...base].filter((k) => !have.has(k));
      const extra = list.filter((k) => !base.has(k));
      if (missing.length) lint.push({ rule: 'i18n-keys', where: `strings/${code}.js`, detail: `${missing.length} key${missing.length > 1 ? 's' : ''} missing: ${missing.slice(0, 8).join(', ')}${missing.length > 8 ? ', ...' : ''}` });
      if (extra.length) lint.push({ rule: 'i18n-keys', where: `strings/${code}.js`, detail: `${extra.length} key${extra.length > 1 ? 's' : ''} not in ${i18nDecl.defaultLocale}: ${extra.slice(0, 8).join(', ')}` });
    }
  }
  const covered = new Map(modules.flatMap((m) => (MODULES[m]?.covers || []).map((item) => [item, m])));
  const checklist = { ...(config?.checklist || {}) };
  for (const [item, m] of covered) {
    if (checklist[item] && checklist[item] !== 'designed') lint.push({ rule: 'checklist', where: `checklist ${item}`, detail: `"${checklist[item]}", but module ${m} is on and designs it` });
    checklist[item] = 'designed';
  }
  for (const [item, answer] of Object.entries(settledByProject(config))) checklist[item] ??= answer;
  for (const [k, v] of Object.entries(checklist)) {
    if (!CHECKLIST.includes(k)) lint.push({ rule: 'checklist', where: `checklist ${k}`, detail: `unknown item: known items are in skills/mockup/references/modules.md` });
    else if (!DECISIONS.includes(v)) lint.push({ rule: 'checklist', where: `checklist ${k}`, detail: `"${v}": use ${DECISIONS.join(', ')}` });
  }
  const undecided = CHECKLIST.filter((k) => !checklist[k]);

  // every styled block in components.css must belong to a component, or its styles get lost in conversion
  for (const block of new Set(cssBlocks)) {
    if (!registered.has(block)) lint.push({ rule: 'orphan-css-block', where: `components.css /* ${block} */`, detail: 'no MK.component with this name: make it a component, or move the rules to base.css as a global primitive' });
  }
  // a heading that names a component and then a note is not a block: split-css would fold its rules
  // into the block above, so the heading is a bare /* Name */ with any note in its own comment
  for (const m of componentsCss.matchAll(/\/\*\s*([A-Z]\w*)\s*:[^*]*\*\//g)) {
    if (registered.has(m[1])) lint.push({ rule: 'css-block-heading', where: `components.css /* ${m[1]}: ... */`, detail: `write the heading as /* ${m[1]} */ and put the note in its own comment, or split-css folds these rules into the block above` });
  }

  // ---------- output --------------------------------------------------------------
  // A page described for several roles reports its own lint once.
  {
    const seen = new Set();
    const unique = lint.filter((l) => { const k = `${l.rule}|${l.where}|${l.detail}`; if (seen.has(k)) return false; seen.add(k); return true; });
    lint.length = 0;
    lint.push(...unique);
  }
  // Accepted findings (docs/inventory-accepted.json) are listed apart and do not fail the run.
  const accepted = [];
  const used = new Set();
  {
    const open = lint.filter((l) => {
      const matching = acceptedFile.entries.filter((x) => acceptedMatches(x, l));
      if (!matching.length) return true;
      for (const e of matching) used.add(e); // an overlapping entry is not stale either
      accepted.push({ ...l, reason: matching[0].reason });
      return false;
    });
    lint.length = 0;
    lint.push(...open);
  }
  const acceptedStale = acceptedFile.entries.filter((e) => !used.has(e));
  const ready = readiness(config || {});
  const notReady = [
    ...ready.open.map((o) => ({ field: o.field, detail: `tier ${o.tier} ${o.detail}` })),
    ...undecided.map((k) => ({ field: `checklist ${k}`, detail: 'undecided (skills/mockup/references/modules.md)' })),
  ];
  const sign = signoffStatus(mockupDir, config || {});
  const inventory = {
    generatedAt: new Date().toISOString(),
    mockupDir: relative(process.cwd(), mockupDir) || '.',
    config,
    tokens, tokenGroups,
    fixtures: fixtureShapes, typedefs: jsdocTypedefs,
    componentFiles, componentsRegistered: [...registered], componentLayers: meta,
    roles, shell, permissionMatrix: matrix,
    modules, tours, checklist, checklistUndecided: undecided,
    pages: results.map((r) => ({
      file: r.screen.page, role: roleOf(r.screen), forbidden: r.forbidden,
      id: r.mk?.page?.id, route: r.mk?.page?.route || r.screen.route, title: r.mk?.page?.title,
      layout: r.mk?.page?.layout, initialState: r.mk?.page?.initialState, actions: r.mk?.page?.actions,
      needs: r.mk?.page?.needs, componentTree: r.componentTree, actionsInDom: r.actions,
      links: r.links, forms: r.forms, todos: r.todos, diffIgnored: r.diffIgnored,
      statesCovered: Object.fromEntries(Object.entries(r.stateCoverage).map(([k, v]) => [k, v.used])),
    })),
    lint,
    acceptedFile: acceptedFile.file && relative(process.cwd(), acceptedFile.file),
    accepted,
    acceptedStale,
    readiness: { ready: !notReady.length, open: notReady, deferred: ready.deferred },
    signoff: { signed: sign.signed, round: sign.round ?? null, date: sign.date ?? null, by: sign.by ?? null, problems: sign.problems },
    // what each page loaded, whether or not project.i18n is set
    i18n: { declared: i18nDecl || null, pages: pagesI18n.map((p) => ({ file: p.file, defaultLocale: p.i18n?.defaultLocale ?? null, locales: Object.keys(p.i18n?.keys || {}) })) },
  };
  writeFileSync(join(outDir, 'inventory.json'), JSON.stringify(inventory, null, 2));

  const pagesLabel = `${pageFiles.size} pages${inventory.pages.length !== pageFiles.size ? ` (${inventory.pages.length} views by role)` : ''}`;
  const treeMd = (nodes, d = 0) => {
    const grouped = [];
    for (const n of nodes) {
      const last = grouped[grouped.length - 1];
      if (last && last.name === n.name) last.count += 1; else grouped.push({ ...n, count: 1 });
    }
    return grouped.map((n) => `${'  '.repeat(d)}- ${n.name}${meta[n.name]?.layer ? ` (${meta[n.name].layer})` : ''}${n.count > 1 ? ` x${n.count}` : ''}\n${treeMd(n.children || [], d + 1)}`).join('');
  };
  let md = `# Mockup inventory\n\nGenerated ${inventory.generatedAt} from \`${inventory.mockupDir}\`\n\n`;
  md += `## Summary\n\n| | |\n|---|---|\n| Pages | ${pagesLabel} |\n| Components | ${registered.size} (${LAYER_ORDER.map((l) => `${l} ${Object.values(meta).filter((m) => m.layer === l).length}`).join(', ')}) |\n| Tokens | ${Object.keys(tokens).length} (${Object.entries(tokenGroups).map(([g, l]) => `${g} ${l.length}`).join(', ')}) |\n| Fixture entities | ${Object.keys(fixtureShapes).join(', ') || 'none'} |\n| Lint issues | ${lint.length}${accepted.length ? ` (${accepted.length} more accepted)` : ''} |\n\n`;
  md += `## Pages\n\n`;
  for (const p of inventory.pages) {
    md += `### ${p.title || p.id} (\`${p.route}\`)${p.role ? `, as ${p.role}` : ''}\n\nFile: \`${p.file}\` · layout: ${p.layout || 'none'} · actions: ${p.actions?.join(', ') || 'none'}\n\n`;
    md += `Component tree:\n\n${treeMd(p.componentTree) || '_none_\n'}\n`;
    if (p.needs && Object.keys(p.needs).length) md += `Needs:\n\n\`\`\`json\n${JSON.stringify(p.needs, null, 2)}\n\`\`\`\n\n`;
    if (p.todos.length) md += `Todos: ${p.todos.map((t) => `\`${t.todo}\``).join('; ')}\n\n`;
    if (p.forms.length) md += `Forms: ${p.forms.map((f) => `${f.action || 'form'}(${f.fields.map((x) => x.name).join(', ')})`).join('; ')}\n\n`;
    md += `Links: ${p.links.map((l) => `\`${l}\``).join(', ') || 'none'}\n\n`;
  }
  if (Object.keys(roles).length) {
    const names = Object.keys(roles);
    md += `## Roles and permissions\n\nWhat each role sees. Display only: the server enforces every permission.\n\n| | Permission | ${names.map((n) => roles[n].label).join(' | ')} |\n|---|---|${names.map(() => '---').join('|')}|\n`;
    md += matrix.map((m) => `| ${m.what} | \`${m.permission}\` | ${names.map((n) => (m.roles[n] ? 'yes' : 'no')).join(' | ')} |`).join('\n') + '\n\n';
    if (shell?.nav?.length) md += `Menu: ${shell.nav.map((n) => `${n.label ?? n.labelKey} (\`${n.permission}\`)`).join(', ')}. Shortcuts: ${Object.keys(shell.keys).join(', ') || 'none'}.\n\n`;
  }
  md += `## Fixtures\n\n${Object.entries(fixtureShapes).map(([k, v]) => `- **${k}** (${v.count}): \`${v.shape}\``).join('\n') || '_none_'}\n\n`;
  md += `## Modules and checklist\n\nModules: ${modules.join(', ') || 'none'}. Tours: ${tours.map((t) => `${t.id} (${t.route}, ${t.steps.length} steps)`).join(', ') || 'none'}.\n\n`;
  md += `| Checklist item | Decision |\n|---|---|\n${CHECKLIST.map((k) => `| ${k} | ${checklist[k] || '**undecided**'} |`).join('\n')}\n\n`;
  md += `## Lint\n\n${lint.length ? `| Rule | Where | Detail |\n|---|---|---|\n${lint.map((l) => `| ${l.rule} | ${l.where} | ${String(l.detail).replace(/\|/g, '\\|')} |`).join('\n')}` : 'Clean: the mockup follows the conventions.'}\n`;
  if (accepted.length) md += `\n## Accepted lint\n\nFrom \`${relative(process.cwd(), acceptedFile.file)}\`: known findings that do not fail the run.\n\n| Rule | Where | Detail | Reason |\n|---|---|---|---|\n${accepted.map((l) => `| ${l.rule} | ${l.where} | ${String(l.detail).replace(/\|/g, '\\|')} | ${l.reason.replace(/\|/g, '\\|')} |`).join('\n')}\n`;
  if (acceptedStale.length) md += `\n## Stale accepted entries\n\nThese match no finding any more: remove them.\n\n${acceptedStale.map((e) => `- ${e.rule} at ${e.where}${e.detail !== undefined ? ` (detail "${e.detail}")` : ''}: ${e.reason}`).join('\n')}\n`;
  md += `\n## Ready to port\n\n${notReady.length ? `Not yet. Open:\n\n| Field | Why |\n|---|---|\n${notReady.map((o) => `| ${o.field} | ${o.detail} |`).join('\n')}\n` : 'Yes: every project answer is decided or deferred with an owner, and the checklist is decided.\n'}`;
  md += `\n## Signed off\n\n${sign.signed ? `Yes: round ${sign.round}, ${sign.date}, by ${sign.by}. The mockup and the contract are as signed off.\n` : `No:\n\n${sign.problems.map((p) => `- ${p.replace(/\|/g, '\\|')}`).join('\n')}\n`}`;
  if (ready.deferred.length) md += `\nDeferred:\n\n| Field | Owner | By | Reason |\n|---|---|---|---|\n${ready.deferred.map((d) => `| ${d.field} | ${d.owner} | ${d.by} | ${d.reason || ''} |`).join('\n')}\n`;
  writeFileSync(join(outDir, 'inventory.md'), md);

  console.log(`inventory: ${pagesLabel}, ${registered.size} components, ${lint.length} lint issues${accepted.length ? `, ${accepted.length} accepted` : ''} -> ${relative(process.cwd(), outDir)}/inventory.{json,md}`);
  for (const e of acceptedStale) console.warn(`inventory: warning: stale accepted entry, matches no finding: ${e.rule} at ${e.where}${e.detail !== undefined ? ` (detail "${e.detail}")` : ''}`);
  if (undecided.length) console.log(`checklist: ${undecided.length} undecided (${undecided.join(', ')}); see skills/mockup/references/modules.md`);
  if (!pageFiles.size) console.error(`inventory: no pages found in ${mockupDir} (no config screens and no pages/*.html)`);
  console.log(`ready to port (decisions only): ${notReady.length ? `no, ${notReady.length} open` : 'yes'}${ready.deferred.length ? ` (${ready.deferred.length} deferred)` : ''}`);
  if (readyToPort) for (const o of notReady) console.log(`not ready: ${o.field}: ${o.detail}`);
  console.log(sign.signed ? `signed off: yes, round ${sign.round} (${sign.date}, ${sign.by})` : `signed off: no${sign.problems.length ? `, ${sign.problems.length} problem${sign.problems.length > 1 ? 's' : ''}` : ''}`);
  if (readyToPort) for (const p of sign.problems) console.log(`not ready: signoff: ${p}`);
  for (const w of sign.warnings) console.log(`warning: ${w}`);
  if (lint.length || !pageFiles.size || (readyToPort && (notReady.length || !sign.signed))) process.exitCode = 1;
}

try {
  await main();
} catch (e) {
  console.error(`inventory: failed: ${e?.stack || e}`);
  process.exitCode = 2;
} finally {
  await browser?.close().catch(() => {});
  server?.close();
}
