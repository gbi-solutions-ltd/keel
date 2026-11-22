#!/usr/bin/env node
/**
 * check-behaviours.mjs: load each entry of a behaviours file in a mockup, run its steps and assert
 * its expectations, so what a screenshot cannot show (a count, an attribute, a drawer off canvas, a
 * toast under a dialog, a value cut by its box) is checked on every run.
 *
 *   node check-behaviours.mjs --mockup <mockup-dir> [--file <behaviours.json>] [--only <prefix>[,<prefix>]]
 *                             [--clock <iso-instant>] [--seed <int>] [--tz <zone>] [--shard K/N]
 *
 *   --file   default <mockup-dir>/docs/behaviours.json
 *   --only   runs the entries whose id, or page file name, starts with a prefix; matching nothing exits 2
 *   --clock, --seed  pin Date and Math.random as visual-diff.mjs does (lib/pin.mjs); pass the values
 *            the baseline was captured with
 *   --tz     the time zone, default mockup.config.json timezoneId, else UTC; the locale is config.locale, then project.i18n.defaultLocale, else en-GB
 *   --shard  runs only shard K of N (lib/shard.mjs, balanced by loads, steps, waits and typing), so N
 *            processes can share one run; merge-shards.mjs behaviours merges their output back into
 *            file order. A shard with no entries prints `0/0 behaviours ok` and exits 0.
 *
 * Pages are served over HTTP from <mockup-dir> (lib/serve.mjs), one fresh context per entry.
 *
 * Entry: { id, page, role?, viewport?, steps?, expect: [{ text } | { noText } | { selector, count } |
 *          { attr: { selector, name, value } } | { visible: <selector> } | { box: { selector, width?, height?, minWidth? } } |
 *          { inside: { selector, container } } | { onTop: <selector> } | { fits: <selector> }] }
 *   page      mockup-relative, with its query (pages/invoices.html?state=empty); the query may not
 *             set ?as= (that would preview a role the role check never saw): the role goes in role
 *   role      previewed with ?as=<role> (lib/screens.mjs mockupUrl). It must be a known role, since
 *             mk.js quietly falls back to the session role for a name it does not know. Known roles
 *             are mockup.config.json `roles` (an array of names, or an object keyed by name) when the
 *             config has them, else the keys of MK.inspect().roles read from the loaded page; an
 *             entry with a role on a page that has neither fails.
 *   viewport  a mockup.config.json viewport name (mobile, desktop), or { width, height } for a window
 *             size no screen uses (a topbar at 768 or 1180px); when absent, desktop if the config
 *             has it, else its widest viewport
 *   steps     config steps (lib/screens.mjs runSteps)
 *   text / noText: the page's visible text (body innerText) includes / does not include it, with
 *            whitespace normalised on both sides first (every run of \s, U+00A0 and U+202F included,
 *            is one plain space, trimmed), so "UGX 1,250,000" typed with a plain space matches Intl's
 *            "UGX\u00a01,250,000" and a phrase split over two lines still matches
 *   selector + count: exactly that many matches; attr: the first match has that attribute value
 *            (value null: the attribute is absent, which a blank render also meets)
 *   visible: the first match is rendered (Playwright isVisible), lies within the viewport's width
 *            (left >= 0, right <= viewport width) and overlaps it vertically, so a drawer translated
 *            off canvas, or a chip pushed past the right edge, is not visible
 *   box: the first match's rendered width and/or height, in CSS px (within half a pixel); minWidth is
 *        a floor instead (at least that wide, within half a pixel), so a label cut to 2px fails where
 *        `visible` passes. An element that is not rendered has no box and fails.
 *   inside: the first match of `selector`, when rendered, lies within the box of the first match of
 *            `container` (half a pixel either way); one that is not rendered paints nothing outside
 *            and passes. The container must be rendered, and either matching nothing fails.
 *   onTop: the first match is rendered and is what the user sees and can reach at its centre:
 *          document.elementFromPoint there is the element or inside it. An element drawn under
 *          something else (a toast under a modal dialog, which the browser also makes inert, so hit
 *          testing skips it) fails, naming what is on top; one not rendered, or centred off screen, fails.
 *   fits: every rendered match holds its own content: scrollWidth - clientWidth is at most 1px
 *         (spill-check.mjs's own test), so a value, cell or button row wider than its box fails,
 *         naming the first by how many px it is over and its text. Matches that are not rendered
 *         (display none, no box) are skipped; it fails when nothing matches or no match is rendered.
 *         A select's scrollWidth does not count the text it cuts, so a matched <select> must also be
 *         at least as wide (within 1px) as a hidden copy of it, laid out beside it with
 *         field-sizing: content, needs for its chosen option; a narrower one fails as cutting that
 *         option's text.
 *
 * An entry holds only the keys above, an expectation only the assertion keys above (selector and
 * count together), attr, box and inside only theirs: any other key (a typo such as "step") fails the
 * entry. An expectation holding several assertions ({ text, visible }) checks every one.
 * The config's pins (pins.clock, pins.seed) apply under --clock and --seed and are validated the
 * same way. Exit 2, with `error: ...` on stderr and before any browser, when the run cannot start
 * (lib/args.mjs's rule): a bad pin in the config, no mockup.config.json, no behaviours file, either
 * not JSON (or the file not an array), duplicate ids, a file or --only that selects nothing; also a
 * bad flag value (--clock, --seed, --shard), an unknown flag or a value flag with no value, and a
 * crash.
 *
 * Prints `<id>: ok` or `<id>: fail: <first failed expectation>`, then `X/Y behaviours ok`; any fail
 * exits 1. An entry fails when: its page file does not exist (`page not found`), its `expect` is
 * missing or empty (it would pass vacuously), it has no positive expectation (only noText, count 0
 * or attr value null, which a blank render meets), a `text` is empty or only spaces, its role is not
 * a known role (or no roles are known), its page query sets ?as=, or the page throws (`pageerror`)
 * during load, steps or expectations. Duplicate ids are rejected before anything runs (exit 2).
 */
import './lib/browsers-env.mjs'; // first: playwright reads its browsers path when it loads
import { existsSync, readFileSync } from 'node:fs';
import { basename, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { chromium } from 'playwright';
import { mockupUrl, runSteps, settle } from './lib/screens.mjs';
import { newPinnedContext, parsePins } from './lib/pin.mjs';
import { configLocale, configZone, pinDefaults } from './lib/project.mjs';
import { serveMockup } from './lib/serve.mjs';
import { parseShard, planBehaviourShards } from './lib/shard.mjs';
import { ArgError, SPECS, crashExits2, parseArgs } from './lib/args.mjs';

const DEFAULT_VIEWPORTS = [{ name: 'mobile', width: 390, height: 844 }, { name: 'desktop', width: 1440, height: 900 }];

// A positive expectation is one a blank, broken or forbidden render cannot meet by accident: text,
// a selector matched at least once, attr with a value, visible, box, inside, onTop or fits. noText,
// count 0 and attr value null (absent) are negative.
const isPositive = (e) => Boolean(e) && ('text' in e || ('selector' in e && e.count > 0) || (e.attr && e.attr.value !== null && e.attr.value !== undefined) || 'visible' in e || 'box' in e || 'inside' in e || 'onTop' in e || 'fits' in e);

// The keys an entry and an expectation may hold (mockup-behaviours.md). Anything else is
// a typo ("step" for "steps") that would otherwise be ignored, so the entry would pass having
// checked less than it says.
const ENTRY_KEYS = ['id', 'page', 'role', 'viewport', 'steps', 'expect'];
const ASSERTION_KEYS = ['text', 'noText', 'selector', 'count', 'attr', 'visible', 'box', 'inside', 'onTop', 'fits'];
const SUB_KEYS = { attr: ['selector', 'name', 'value'], box: ['selector', 'width', 'height', 'minWidth'], inside: ['selector', 'container'] };

/**
 * The first problem with an entry's keys, or null: an unknown key on the entry, on an expectation or
 * inside attr, box or inside; an expectation that is not an object or is empty; selector without
 * count or count without selector.
 */
export function entryProblem(b) {
  if (!b || typeof b !== 'object' || Array.isArray(b)) return 'entry is not an object';
  const stray = Object.keys(b).find((k) => !ENTRY_KEYS.includes(k));
  if (stray) return `unknown key "${stray}" (an entry holds ${ENTRY_KEYS.join(', ')})`;
  for (const [i, e] of (Array.isArray(b.expect) ? b.expect : []).entries()) {
    const at = `expect[${i}]`;
    if (!e || typeof e !== 'object' || Array.isArray(e)) return `${at} is not an object`;
    const keys = Object.keys(e);
    if (!keys.length) return `${at} is an empty expectation`;
    const bad = keys.find((k) => !ASSERTION_KEYS.includes(k));
    if (bad) return `${at} has an unknown key "${bad}" (known: ${ASSERTION_KEYS.join(', ')})`;
    if ('selector' in e && !('count' in e)) return `${at}: selector needs count`;
    if ('count' in e && !('selector' in e)) return `${at}: count needs selector`;
    for (const [k, allowed] of Object.entries(SUB_KEYS)) {
      if (!(k in e)) continue;
      if (!e[k] || typeof e[k] !== 'object' || Array.isArray(e[k])) return `${at}: ${k} must be an object with ${allowed.join(', ')}`;
      const sub = Object.keys(e[k]).find((x) => !allowed.includes(x));
      if (sub) return `${at}: ${k} has an unknown key "${sub}" (known: ${allowed.join(', ')})`;
    }
  }
  return null;
}

/**
 * Every run of whitespace (\s: spaces, tabs, line breaks, U+00A0, U+202F and the other Unicode
 * spaces) becomes one plain space, trimmed. text and noText compare both sides this way, as role
 * names in steps are matched, so Intl's no-break spaces and a line break in the layout do not
 * decide the result.
 */
export const normaliseSpace = (s) => String(s).replace(/\s+/g, ' ').trim();

/** The --only predicate: an id, or a page file name, starts with a prefix. */
export const matchesOnly = (only) => (b) => !only.length || only.some((p) => String(b?.id ?? '').startsWith(p) || basename(String(b?.page ?? '').split('?')[0]).startsWith(p));

/** Duplicate ids and --only, on the whole file. Returns { error } (the line to print) or { list }. */
export function selectBehaviours(all, only, fileName) {
  const seen = new Set();
  const dupes = [...new Set(all.map((b) => b.id).filter((id) => seen.has(id) || !seen.add(id)))];
  if (dupes.length) return { error: `error: duplicate id in ${fileName}: ${dupes.join(', ')}` };
  const list = all.filter(matchesOnly(only));
  if (!list.length) return { error: `0 behaviours checked (${all.length} in ${fileName})${only.length ? `: --only ${only.join(',')} matches nothing` : ''}` };
  return { list };
}

/** The config's roles as names, or null when it lists none. */
function configRoles(config) {
  if (Array.isArray(config.roles)) return config.roles.map(String);
  if (config.roles && typeof config.roles === 'object') return Object.keys(config.roles);
  return null;
}

// A viewport by config name, or { width, height } in whole positive pixels
function viewportFor(v, viewports) {
  if (v && typeof v === 'object') {
    const ok = ['width', 'height'].every((k) => Number.isInteger(v[k]) && v[k] > 0) && Object.keys(v).length === 2;
    return ok ? { name: `${v.width}x${v.height}`, width: v.width, height: v.height } : null;
  }
  if (v === undefined) return viewports.find((x) => x.name === 'desktop') || viewports.reduce((m, x) => (x.width > m.width ? x : m), viewports[0]) || null;
  return viewports.find((x) => x.name === v) || null;
}

async function checkOne(browser, base, b, env) {
  const { mockupDir, viewports, roles, context } = env;
  const keyProblem = entryProblem(b);
  if (keyProblem) return `fail: ${keyProblem}`;
  if (typeof b.page !== 'string' || !b.page) return 'fail: no page';
  const file = b.page.split('?')[0];
  if (!Array.isArray(b.expect) || !b.expect.length) return 'fail: no expectations (an entry with an empty expect passes vacuously)';
  if (b.expect.some((e) => e && 'text' in e && (typeof e.text !== 'string' || !e.text.trim()))) return 'fail: empty text (every page includes "" and almost every page a space, so it always passes)';
  if (!b.expect.some(isPositive)) return 'fail: no positive expectation (noText, count 0 and attr value null alone pass on a blank or forbidden render)';
  if (new URLSearchParams(b.page.split('?')[1] || '').has('as')) return `fail: page query sets ?as= (${b.page}); put the role in role, where it is checked against the known roles`;
  if (b.role !== undefined && roles && !roles.includes(b.role)) return `fail: unknown role ${b.role} (mockup.config.json roles: ${roles.join(', ')})`;
  if (!existsSync(join(mockupDir, file))) return `fail: page not found (${file})`;
  const vp = viewportFor(b.viewport, viewports);
  if (!vp) return `fail: unknown viewport ${typeof b.viewport === 'object' ? JSON.stringify(b.viewport) : b.viewport} (known: ${viewports.map((v) => v.name).join(', ')}, or { width, height })`;
  const errors = [];
  const thrown = () => (errors.length ? `fail: pageerror: ${errors[0]}` : null);
  let ctx;
  try {
    ctx = await newPinnedContext(browser, vp, context);
    const page = await ctx.newPage();
    page.on('dialog', (d) => d.dismiss());
    page.on('pageerror', (err) => errors.push(String(err.message || err).split('\n')[0]));
    const res = await page.goto(mockupUrl(b, 'default', { base }));
    if (!res || res.status() >= 400) return `fail: page not found (${file}, HTTP ${res ? res.status() : 'none'})`;
    await settle(page);
    if (thrown()) return thrown();
    if (b.role !== undefined && !roles) {
      // No roles in the config: the page's own, as mk.js resolves ?as= against them
      const known = await page.evaluate(() => (window.MK && typeof window.MK.inspect === 'function' ? Object.keys(window.MK.inspect().roles || {}) : null));
      if (!known) return `fail: cannot check role ${b.role}: mockup.config.json has no roles and the page has no MK.inspect()`;
      if (!known.includes(b.role)) return `fail: unknown role ${b.role} (MK.inspect().roles: ${known.join(', ')})`;
    }
    await runSteps(page, b.steps || []);
    if (thrown()) return thrown();
    // Every assertion an expectation holds is checked, in this order, not only the first
    for (const e of b.expect) {
      if ('text' in e) {
        const t = normaliseSpace(await page.evaluate(() => document.body.innerText));
        if (!t.includes(normaliseSpace(e.text))) return `fail: text "${e.text}" not found`;
      }
      if ('noText' in e) {
        const t = normaliseSpace(await page.evaluate(() => document.body.innerText));
        if (t.includes(normaliseSpace(e.noText))) return `fail: text "${e.noText}" present`;
      }
      if ('selector' in e) {
        const n = await page.locator(e.selector).count();
        if (n !== e.count) return `fail: ${e.selector} matched ${n}, expected ${e.count}`;
      }
      if (e.attr) {
        const loc = page.locator(e.attr.selector);
        if (!(await loc.count())) return `fail: ${e.attr.selector} matched nothing`;
        const v = await loc.first().getAttribute(e.attr.name);
        if (v !== e.attr.value) return `fail: ${e.attr.selector} [${e.attr.name}] is ${JSON.stringify(v)}, expected ${JSON.stringify(e.attr.value)}`;
      }
      if ('visible' in e) {
        const loc = page.locator(e.visible).first();
        const box = (await loc.count()) && (await loc.isVisible()) ? await loc.boundingBox() : null;
        const size = page.viewportSize();
        const onScreen = box && box.x >= -0.5 && box.x + box.width <= size.width + 0.5 && box.y + box.height > 0 && box.y < size.height;
        if (!onScreen) return `fail: ${e.visible} is not visible${box ? ` (box at x ${Math.round(box.x)}, y ${Math.round(box.y)}, outside the ${size.width}x${size.height} viewport)` : ''}`;
      }
      if (e.box) {
        const loc = page.locator(e.box.selector);
        if (!(await loc.count())) return `fail: ${e.box.selector} matched nothing`;
        const box = await loc.first().boundingBox();
        if (!box) return `fail: ${e.box.selector} has no box (not rendered)`;
        if (e.box.width === undefined && e.box.height === undefined && e.box.minWidth === undefined) return `fail: box ${e.box.selector} names no width or height`;
        if (e.box.minWidth !== undefined && !Number.isFinite(e.box.minWidth)) return `fail: box ${e.box.selector} minWidth ${JSON.stringify(e.box.minWidth)} is not a number`;
        if (e.box.minWidth !== undefined && box.width < e.box.minWidth - 0.5) return `fail: ${e.box.selector} is ${+box.width.toFixed(2)}px wide, expected at least ${e.box.minWidth}`;
        if (e.box.width !== undefined && Math.abs(box.width - e.box.width) > 0.5) return `fail: ${e.box.selector} is ${+box.width.toFixed(2)}px wide, expected ${e.box.width}`;
        if (e.box.height !== undefined && Math.abs(box.height - e.box.height) > 0.5) return `fail: ${e.box.selector} is ${+box.height.toFixed(2)}px high, expected ${e.box.height}`;
      }
      if (e.inside) {
        const loc = page.locator(e.inside.selector), cont = page.locator(e.inside.container);
        if (!(await loc.count())) return `fail: ${e.inside.selector} matched nothing`;
        if (!(await cont.count())) return `fail: ${e.inside.container} matched nothing`;
        const outer = await cont.first().boundingBox();
        if (!outer || !outer.width || !outer.height) return `fail: ${e.inside.container} is not rendered`;
        const box = await loc.first().boundingBox();
        if (box && box.width && box.height) {
          const out = Math.max(outer.x - box.x, box.x + box.width - (outer.x + outer.width), outer.y - box.y, box.y + box.height - (outer.y + outer.height));
          if (out > 0.5) return `fail: ${e.inside.selector} sticks out of ${e.inside.container} by ${+out.toFixed(1)}px`;
        }
      }
      if ('onTop' in e) {
        const loc = page.locator(e.onTop);
        if (!(await loc.count())) return `fail: ${e.onTop} matched nothing`;
        const r = await loc.first().evaluate((el) => {
          const b = el.getBoundingClientRect();
          if (!b.width || !b.height) return { none: true };
          const hit = document.elementFromPoint(b.x + b.width / 2, b.y + b.height / 2);
          const name = (x) => `${x.tagName.toLowerCase()}${x.id ? `#${x.id}` : ''}${typeof x.className === 'string' && x.className.trim() ? `.${x.className.trim().split(/\s+/).join('.')}` : ''}`;
          return { top: Boolean(hit && el.contains(hit)), hit: hit ? name(hit) : null };
        });
        if (r.none) return `fail: ${e.onTop} is not rendered`;
        if (!r.top) return r.hit ? `fail: ${e.onTop} is covered at its centre by ${r.hit}` : `fail: ${e.onTop} is centred off screen`;
      }
      if ('fits' in e) {
        const loc = page.locator(e.fits);
        if (!(await loc.count())) return `fail: ${e.fits} matched nothing`;
        const r = await loc.evaluateAll((els) => {
          const shown = els.filter((el) => el.getClientRects().length && el.clientWidth);
          const over = shown.map((el) => ({ over: el.scrollWidth - el.clientWidth, sw: el.scrollWidth, cw: el.clientWidth, text: (el.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 50) })).find((x) => x.over > 1);
          // a select's need: a copy beside it (same font and padding) sized to its chosen option by field-sizing: content
          const cut = shown.filter((el) => el.tagName === 'SELECT' && el.selectedIndex > -1).map((el) => {
            const copy = el.cloneNode(true);
            copy.removeAttribute('id');
            Object.assign(copy.style, { fieldSizing: 'content', width: 'auto', minWidth: '0', maxWidth: 'none', flex: 'none', position: 'absolute', visibility: 'hidden' });
            copy.selectedIndex = el.selectedIndex;
            el.after(copy);
            const need = copy.getBoundingClientRect().width;
            copy.remove();
            const w = el.getBoundingClientRect().width;
            return { w: Math.round(w), need: Math.round(need), short: need - w, text: el.options[el.selectedIndex].text };
          }).find((x) => x.short > 1);
          return { shown: shown.length, over, cut };
        });
        if (!r.shown) return `fail: ${e.fits} is not rendered`;
        if (r.over) return `fail: ${e.fits} is ${r.over.over}px wider than its box (scrollWidth ${r.over.sw}, clientWidth ${r.over.cw}): "${r.over.text}"`;
        if (r.cut) return `fail: ${e.fits} cuts its chosen option "${r.cut.text}": ${r.cut.w}px wide, its text needs ${r.cut.need}px`;
      }
      if (thrown()) return thrown();
    }
    return thrown() || 'ok';
  } catch (err) {
    return `fail: ${String(err.message || err).split('\n')[0]}`;
  } finally { await ctx?.close(); }
}

/** Reads the CLI arguments (lib/args.mjs). Returns { error } (a bad argument), { help } or the parsed options. */
export function readArgs(argv) {
  let flags;
  try { ({ values: flags } = parseArgs(argv, SPECS['check-behaviours'])); } catch (e) {
    if (e instanceof ArgError) return { error: `check-behaviours: ${e.message}\n${SPECS['check-behaviours'].usage}` };
    throw e;
  }
  if (flags.help) return { help: true };
  const has = (k) => flags[k] !== undefined;
  const arg = (k, d) => flags[k] ?? d;
  const mockupDir = resolve(arg('mockup', '.'));
  const file = resolve(arg('file', join(mockupDir, 'docs', 'behaviours.json')));
  const only = (arg('only', '') || '').split(',').map((s) => s.trim()).filter(Boolean);
  // Validated here so a bad flag fails before anything is read; main applies the config's pins
  // under the flags (pinDefaults) and validates the result again.
  const pins = parsePins(arg('clock'), arg('seed'));
  if (pins.error) return { error: `error: ${pins.error}` };
  const shard = has('shard') ? parseShard(arg('shard')) : null;
  if (shard && shard.error) return { error: `error: ${shard.error}` };
  return { mockupDir, file, only, clock: pins.clock, seed: pins.seed, clockArg: arg('clock'), seedArg: arg('seed'), tz: arg('tz'), shard };
}

async function main(argv) {
  const o = readArgs(argv);
  if (o.help) { console.log(SPECS['check-behaviours'].usage); return 0; }
  if (o.error) { console.error(o.error); return 2; }
  // Could not run (exit 2, on stderr): no config, no file, a file or config that is not JSON or
  // not of its shape, duplicate ids, a selection that matches nothing, bad pins in the config.
  const cannot = (msg) => { console.error(msg); return 2; };
  const readJson = (file) => { try { return { value: JSON.parse(readFileSync(file, 'utf8')) }; } catch (e) { return { error: `error: ${file} is not valid JSON: ${e.message}` }; } };
  const configPath = join(o.mockupDir, 'mockup.config.json');
  if (!existsSync(configPath)) return cannot(`error: missing ${configPath}`);
  if (!existsSync(o.file)) return cannot(`error: missing ${o.file}`);
  const read = readJson(o.file);
  if (read.error) return cannot(read.error);
  if (!Array.isArray(read.value)) return cannot(`error: ${o.file} is not an array of entries`);
  const sel = selectBehaviours(read.value, o.only, basename(o.file));
  if (sel.error) return cannot(sel.error);
  const list = o.shard ? planBehaviourShards(sel.list, o.shard.n)[o.shard.k - 1] : sel.list;
  if (!list.length) { console.log('0/0 behaviours ok'); return 0; }
  const cfg = readJson(configPath);
  if (cfg.error) return cannot(cfg.error);
  if (!cfg.value || typeof cfg.value !== 'object' || Array.isArray(cfg.value)) return cannot(`error: ${configPath} is not a JSON object`);
  const config = cfg.value;
  // The config's pins pass the same check as the flags (a bad pins.clock is an error line, not a
  // stack trace from the browser), as visual-diff.mjs does.
  const d = pinDefaults(config, o.clockArg, o.seedArg);
  const pins = parsePins(d.clock, d.seed);
  if (pins.error) return cannot(`error: mockup.config.json pins or flags: ${pins.error}`);
  const env = {
    mockupDir: o.mockupDir,
    viewports: config.viewports || DEFAULT_VIEWPORTS,
    roles: configRoles(config),
    context: { timezoneId: o.tz ?? configZone(config), locale: configLocale(config), clock: pins.clock, seed: pins.seed },
  };
  const { server, base } = await serveMockup(o.mockupDir);
  const browser = await chromium.launch();
  let failed = 0;
  try {
    for (const b of list) {
      const r = await checkOne(browser, base, b, env);
      if (r !== 'ok') failed++;
      console.log(`${b.id}: ${r}`);
    }
  } finally { await browser.close(); server.close(); }
  console.log(`${list.length - failed}/${list.length} behaviours ok`);
  return failed ? 1 : 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  crashExits2('check-behaviours');
  process.exitCode = await main(process.argv.slice(2));
}
