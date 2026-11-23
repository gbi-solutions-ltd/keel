#!/usr/bin/env node
/**
 * quality-check.mjs: Keel frontend checks a browser has to run, against a mockup or an app.
 *
 *   node quality-check.mjs --mockup <mockup-dir>                 the design, before sign-off
 *   node quality-check.mjs --mockup <mockup-dir> --app <url>     the app (screens from the mockup config)
 *
 * For every screen x state x viewport in mockup.config.json:
 *   axe        WCAG 2.2 A and AA rules (axe-core); every violation fails. This is also the contrast
 *              check: axe's color-contrast rule measures text against its background, and the engine
 *              has no separate contrast script
 *   overflow   no horizontal scroll at each viewport and at 320px wide
 *   target     a warning only: a button, select or input under config.quality.targetMinPx
 *              (default 44) on the mobile viewport. The WCAG 2.5.8 failure (24px, unless spaced
 *              apart) is axe's target-size rule above, which judges spacing box to box and exempts
 *              inline links. Each candidate is scrolled into view (scrollIntoViewIfNeeded) and probed
 *              with elementFromPoint at its centre (and the centre of each line box): one still off
 *              screen (left:-9999px) is skipped as offscreen; one whose topmost element there is
 *              neither the target, inside it, nor inside its label (a fixed sheet, a tour popover, a
 *              dialog) is skipped as covered. A skipped target gets no warning; the counts and a few
 *              examples are in report.json as targetSkipped. Sizes are measured at the page's own
 *              scroll position, which is restored afterwards; the probe pass scrolls instantly even
 *              on a page with scroll-behavior: smooth
 *   focus      every element reached by Tab shows a visible focus indicator (default state only).
 *              Elements are told apart by identity, so repeated labels ("Edit" per row) are each
 *              checked; the walk ends when focus leaves the page or returns to an element already
 *              visited, and a cap (twice the interactive count plus 20, at least 60) warns when hit
 *   dash       no em or en dash in visible text (Keel house style)
 *   console    no console error, page error or Content-Security-Policy violation
 * Writes <out>/report.md and report.json; exit 1 on any failure. A previous run's report.json
 * and report.md are removed first, so a run that stops early leaves none behind. Warnings never fail.
 * Exit 2, before any browser, when it cannot run (lib/args.mjs's rule): bad arguments (an unknown
 * flag, a value flag with no value), a missing config, screens that collide or (with --app) a screen
 * with no route (lib/screens.mjs screenProblems, as visual-diff.mjs checks), no case selected (a
 * --screen that matches no screen, by name, else route, else page, or no screens), or a crash.
 *
 * Failures print in full under each case line. Warnings are summarised: one console line per check
 * (`warnings: target 28000 in 312 case(s) (40 distinct)`) and, in report.md, per check the count and
 * the 5 most frequent details. report.json always holds every warning.
 *   --warnings all      also print every warning under its case line, and list every distinct warning
 *                       in report.md, as before (default: summary)
 *
 * Sharding (lib/quality-merge.mjs):
 *   --shard K/N         run only shard K of N. Screens are split whole (all states and viewports of a
 *                       screen key in one shard), balanced by lpt on rough page loads; --screen applies
 *                       first. Each shard's report.json carries the whole plan (shard: { k, n, owner:
 *                       {screenKey: K}, planned: [{ slug, screen }] }). Default out
 *                       <mockup-dir>/.mockup-engine/quality-shards/<mockup|app>/K. A shard that owns no
 *                       screen writes an empty report and exits 0. `merge-shards.mjs quality` merges the
 *                       shards into the serial report with "N of N planned cases measured, not
 *                       measured: M", and fails on M > 0, a dead shard or any failed case.
 */
import './lib/browsers-env.mjs'; // first: playwright reads its browsers path when it loads
import { existsSync, readFileSync, mkdirSync, rmSync } from 'node:fs';
import { join, resolve, relative } from 'node:path';
import { chromium } from 'playwright';
import { AxeBuilder } from '@axe-core/playwright';
import { appSteps, appUrl, mockupUrl, runSteps, screenProblems, settle, slugFor } from './lib/screens.mjs';
import { configLocale, configZone } from './lib/project.mjs';
import { parseShard } from './lib/shard.mjs';
import { serveMockup } from './lib/serve.mjs';
import { cli } from './lib/args.mjs';
import { NARROW, planQualityShards, screenKey, warningLines, writeQualityReport } from './lib/quality-merge.mjs';

const { values: flags } = cli('quality-check');
const opt = (name, fallback) => flags[name] ?? fallback;
const mockupDir = resolve(opt('mockup', '.'));
const appBase = opt('app')?.replace(/\/$/, '');
const target = appBase ? 'app' : 'mockup';
const shard = flags.shard !== undefined ? parseShard(opt('shard')) : null;
if (shard?.error) { console.error(`quality-check: ${shard.error}`); process.exit(2); }
const warningsMode = opt('warnings', 'summary');
if (!['summary', 'all'].includes(warningsMode)) { console.error(`quality-check: --warnings must be summary or all, got ${warningsMode}`); process.exit(2); }
// A shard's default out is its own folder, so parallel shards do not overwrite each other
const outDir = resolve(opt('out', shard ? join(mockupDir, '.mockup-engine/quality-shards', target, String(shard.k)) : join(mockupDir, '.mockup-engine/quality', target)));
// A run that stops early (a config that does not parse, no case selected, a crash) must not leave an earlier run's verdict behind
// for a merge or a gate to read. Only the two report files go; the rest of the out folder stays.
for (const f of ['report.json', 'report.md']) rmSync(join(outDir, f), { force: true });

if (!existsSync(join(mockupDir, 'mockup.config.json'))) { console.error(`quality-check: missing ${join(mockupDir, 'mockup.config.json')}`); process.exit(2); }
const config = JSON.parse(readFileSync(join(mockupDir, 'mockup.config.json'), 'utf8'));
// Colliding names would write one case's results over another's; a screen with no route cannot be
// opened in the app. The same check as visual-diff.mjs (lib/screens.mjs screenProblems), before any browser.
const problems = screenProblems(config, { app: Boolean(appBase) });
if (problems.length) { console.error(`quality-check: ${join(mockupDir, 'mockup.config.json')} cannot be run:\n${problems.map((p) => `  ${p}`).join('\n')}`); process.exit(2); }
const viewports = config.viewports || [{ name: 'desktop', width: 1440, height: 900 }];
const mobile = [...viewports].sort((a, b) => a.width - b.width)[0];
const targetMin = config.quality?.targetMinPx ?? 44;
const AXE_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'];

// The mockup is served over HTTP, not file://: axe fetches stylesheets to check contrast, and a
// browser blocks that from a file URL. lib/serve.mjs, the server the other checks use.
let mockupBase;
if (!appBase) {
  const served = await serveMockup(mockupDir);
  mockupBase = served.base;
  process.on('exit', () => served.server.close());
}

function urlFor(screen, state) {
  return appBase ? appUrl(screen, state, appBase) : mockupUrl(screen, state, { base: mockupBase });
}

const INTERACTIVE = 'a[href], button, input:not([type=hidden]), select, textarea, summary, [role=button], [role=link], [tabindex]:not([tabindex="-1"])';

async function inspectPage(page, { checkFocus, isMobile }) {
  const failures = [];
  const warnings = [];

  const axe = await new AxeBuilder({ page }).withTags(AXE_TAGS).analyze();
  for (const v of axe.violations) {
    failures.push({ check: 'axe', detail: `${v.id}: ${v.help} (${v.nodes.length}x) ${v.nodes.slice(0, 2).map((n) => n.target.join(' ')).join(', ')}` });
  }

  const layout = await page.evaluate((selector) => {
    const overflow = document.documentElement.scrollWidth - window.innerWidth;
    const els = [...document.querySelectorAll(selector)]
      .filter((el) => el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden');
    // Pass 1, the geometry: every rect at the page's own scroll position, so distances between
    // targets are measured in one frame.
    const rects = els.map((el) => {
      const r = el.getBoundingClientRect();
      const label = (el.getAttribute('aria-label') || el.textContent || el.tagName).trim().replace(/\s+/g, ' ').slice(0, 40);
      return { tag: el.tagName.toLowerCase(), label, x: r.x, y: r.y, w: r.width, h: r.height, skip: null };
    });
    // Pass 2, can a pointer reach it: scroll it into view, then probe the centre of its box and of
    // each line box. None on screen: offscreen. On screen but the topmost element is not the target,
    // inside it or inside its label (a styled checkbox): covered. Scroll positions of the window and
    // of the target's ancestors are put back after each probe.
    // scroll-behavior: smooth would animate these scrolls, and no frame runs inside this loop, so
    // the pass forces instant scrolling and removes the override afterwards.
    // A constructed sheet, not a <style>: a strict CSP blocks inline style and would log the
    // check's own element as the app's violation.
    const instantSheet = new CSSStyleSheet();
    instantSheet.replaceSync('*, html { scroll-behavior: auto !important; }');
    document.adoptedStyleSheets = [...document.adoptedStyleSheets, instantSheet];
    const instant = { remove: () => { document.adoptedStyleSheets = document.adoptedStyleSheets.filter((x) => x !== instantSheet); } };
    const sx = window.scrollX, sy = window.scrollY;
    const hits = (el, top) => top && (top === el || el.contains(top) || [...(el.labels || [])].some((l) => l === top || l.contains(top)));
    els.forEach((el, i) => {
      const saved = [];
      for (let a = el.parentElement; a; a = a.parentElement) if (a.scrollTop || a.scrollLeft || a.scrollHeight > a.clientHeight || a.scrollWidth > a.clientWidth) saved.push([a, a.scrollLeft, a.scrollTop]);
      if (el.scrollIntoViewIfNeeded) el.scrollIntoViewIfNeeded(true); else el.scrollIntoView({ block: 'center', inline: 'center' });
      const r = el.getBoundingClientRect();
      const pts = [[r.x + r.width / 2, r.y + r.height / 2], ...[...el.getClientRects()].slice(0, 4).map((c) => [c.x + c.width / 2, c.y + c.height / 2])]
        .filter(([x, y]) => x >= 0 && x < window.innerWidth && y >= 0 && y < window.innerHeight);
      if (!pts.length) rects[i].skip = 'offscreen';
      else if (!pts.some(([x, y]) => hits(el, document.elementFromPoint(x, y)))) rects[i].skip = 'covered';
      for (const [a, l, t] of saved) { a.scrollLeft = l; a.scrollTop = t; }
      window.scrollTo({ left: sx, top: sy, behavior: 'instant' });
    });
    instant.remove();
    const text = document.body.innerText;
    return { overflow, rects, dash: /[\u2013\u2014]/.test(text) ? text.match(/.{0,30}[\u2013\u2014].{0,30}/)?.[0] : null };
  }, INTERACTIVE);

  if (layout.overflow > 1) failures.push({ check: 'overflow', detail: `page scrolls horizontally by ${layout.overflow}px` });
  if (layout.dash) failures.push({ check: 'dash', detail: `visible text contains a dash: "${layout.dash}"` });

  // A covered or offscreen target is not hit by a pointer, so it is neither judged nor a neighbour.
  const live = layout.rects.filter((r) => !r.skip);
  const skippedRects = layout.rects.filter((r) => r.skip);
  const targetSkipped = {
    covered: skippedRects.filter((r) => r.skip === 'covered').length,
    offscreen: skippedRects.filter((r) => r.skip === 'offscreen').length,
    examples: skippedRects.slice(0, 10).map((r) => `${r.skip}: ${r.tag} "${r.label}"`),
  };
  // WCAG 2.5.8 (24px, or spaced apart) is axe's target-size rule, run under wcag22aa above: it
  // measures a 24px circle against the neighbouring boxes and exempts inline links. This pass adds
  // only the touch-size warning axe does not have.
  for (const r of live) {
    if (isMobile && ['button', 'select', 'input'].includes(r.tag) && Math.min(r.w, r.h) < targetMin) {
      warnings.push({ check: 'target', detail: `${r.tag} "${r.label}" is ${Math.round(r.w)}x${Math.round(r.h)}, under ${targetMin}px for touch` });
    }
  }

  if (checkFocus) {
    // Elements are told apart by identity (a WeakSet kept in the page), not by tag and text, so two
    // buttons labelled "Edit" are two stops. The walk ends when focus leaves the page or reaches an
    // element it has already visited (the cycle back to the first, or a focus trap); the cap only
    // guards against a page that makes new elements as it is tabbed through, and says when it is hit.
    await page.evaluate(() => { document.activeElement?.blur(); window.scrollTo(0, 0); window.__mkFocusSeen = new WeakSet(); });
    const cap = Math.max(60, 2 * layout.rects.length + 20);
    let stops = 0;
    let capped = true;
    for (let i = 0; i < cap; i++) {
      await page.keyboard.press('Tab');
      const f = await page.evaluate(async () => {
        const el = document.activeElement;
        if (!el || el === document.body) return null;
        if (window.__mkFocusSeen.has(el)) return { repeat: true };
        window.__mkFocusSeen.add(el);
        const s = getComputedStyle(el);
        const outline = s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) > 0;
        const ring = s.boxShadow && s.boxShadow !== 'none';
        const path = el.id ? `#${el.id}` : `${el.tagName.toLowerCase()}:${(el.textContent || '').trim().slice(0, 30)}`;
        if (outline || ring) return { path, visible: true };
        // A kit often draws focus on a sibling or a wrapper (an outlined field's border is a
        // separate element), or in a layer of the control itself (Vuetify: a child overlay's
        // opacity, an ::after border). Visible means focus changes how the element or its
        // surroundings look: compare the outline, ring, border, background and opacity of the
        // element, its ancestors up to three levels and their descendants, and the element's own
        // ::before and ::after, focused and blurred, with transitions off so the blurred values are
        // final. Refocusing puts the Tab order back where it was.
        let top = el;
        for (let i = 0; i < 3 && top.parentElement && top.parentElement !== document.body; i++) top = top.parentElement;
        const nodes = [top, ...top.querySelectorAll('*')].slice(0, 200);
        const props = ['outline-style', 'outline-width', 'outline-color', 'box-shadow', 'border-top-color', 'border-top-width', 'border-bottom-color', 'border-bottom-width', 'background-color', 'opacity'];
        const read = (c) => props.map((p) => c.getPropertyValue(p)).join('|');
        const snap = () => [...nodes.map((n) => read(getComputedStyle(n))), read(getComputedStyle(el, '::before')), read(getComputedStyle(el, '::after'))];
        const still = new CSSStyleSheet();
        still.replaceSync('*, *::before, *::after { transition: none !important; animation: none !important; }');
        document.adoptedStyleSheets = [...document.adoptedStyleSheets, still];
        // A kit may apply its focus state a frame after the event (Vuetify sets its focused class
        // through Vue's next render), so each state is read two frames after the change.
        const frames = () => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
        try {
          await frames();
          const on = snap();
          el.blur();
          await frames();
          const off = snap();
          el.focus();
          await frames();
          return { path, visible: on.some((v, i) => v !== off[i]) };
        } finally {
          document.adoptedStyleSheets = document.adoptedStyleSheets.filter((x) => x !== still);
        }
      });
      if (!f || f.repeat) { capped = false; break; }
      stops += 1;
      if (!f.visible) failures.push({ check: 'focus', detail: `no visible focus indicator on ${f.path}` });
    }
    if (capped) warnings.push({ check: 'focus', detail: `focus walk stopped at its cap of ${cap} tab stops; later elements were not checked` });
    if (stops === 0 && layout.rects.length) failures.push({ check: 'focus', detail: 'Tab reaches nothing, but the page has interactive elements' });
  }
  return { failures, warnings, targetSkipped };
}

const onlyScreen = opt('screen');
const selected = (config.screens || []).filter((screen) => !onlyScreen || (screen.name || screen.route || screen.page || '').includes(onlyScreen));
if (!selected.length) {
  console.error(onlyScreen
    ? `quality-check: --screen "${onlyScreen}" matches no screen in ${join(mockupDir, 'mockup.config.json')}; 0 cases run`
    : `quality-check: mockup.config.json lists no screens; 0 cases run`);
  process.exit(2);
}
// Every shard plans the whole run and keeps only its own screens; the plan goes in its report.json.
const plan = shard ? { k: shard.k, n: shard.n, ...planQualityShards(selected, viewports, shard.n) } : null;
const mine = plan ? selected.filter((s) => plan.owner[screenKey(s)] === shard.k) : selected;
const source = appBase || relative(process.cwd(), mockupDir);
const meta = { target, app: appBase || null, source, warnings: warningsMode, ...(plan ? { shard: plan } : {}) };

mkdirSync(outDir, { recursive: true });
if (!mine.length) {
  writeQualityReport(outDir, [], meta);
  console.log(`shard ${shard.k}/${shard.n}: owns no screen, nothing to check -> ${relative(process.cwd(), outDir)}/report.md`);
  process.exit(0);
}
const browser = await chromium.launch();
const cases = [];

for (const screen of mine) {
  for (const state of screen.states || ['default']) {
    const sizes = [...viewports, NARROW];
    for (const vp of sizes) {
      const ctx = await browser.newContext({ viewport: { width: vp.width, height: vp.height }, timezoneId: configZone(config), locale: configLocale(config) });
      const page = await ctx.newPage();
      const runtime = [];
      // In the error state a failed request is the point, and the browser logs it. A screen that
      // reaches an error on purpose (a wrong code) lists the statuses it expects in `expectStatus`.
      const statuses = (screen.expectStatus || []).join('|');
      const expected = state === 'error' ? /favicon|Failed to load resource/
        : statuses ? new RegExp(`favicon|Failed to load resource: the server responded with a status of (${statuses})\\b`) : /favicon/;
      // A screen that shows a failure on purpose (a page that crashes) lists the text it logs.
      const expectedText = (t) => (screen.expectConsole || []).some((x) => t.includes(x));
      page.on('console', (m) => { if (m.type() === 'error' && !expected.test(m.text()) && !expectedText(m.text())) runtime.push(`console: ${m.text()}`); });
      page.on('pageerror', (e) => { if (!expectedText(e.message)) runtime.push(`pageerror: ${e.message}`); });
      page.on('dialog', (d) => d.dismiss());
      await page.addInitScript(() => {
        document.addEventListener('securitypolicyviolation', (e) => console.error(`CSP violation: ${e.violatedDirective} blocked ${e.blockedURI || 'inline'}`));
      });

      const url = urlFor(screen, state);
      let result;
      try {
        await page.goto(url, { waitUntil: 'load' });
        await settle(page);
        await runSteps(page, appBase ? appSteps(screen.steps) : screen.steps);
        if (vp.name === 'narrow-320') {
          const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
          result = { failures: overflow > 1 ? [{ check: 'overflow', detail: `scrolls horizontally by ${overflow}px at 320px` }] : [], warnings: [] };
        } else {
          result = await inspectPage(page, { checkFocus: state === 'default' && !screen.steps && vp === viewports[viewports.length - 1], isMobile: vp === mobile });
        }
      } catch (e) {
        result = { failures: [{ check: 'load', detail: String(e.message).split('\n')[0] }], warnings: [] };
      }
      for (const r of runtime) result.failures.push({ check: 'console', detail: r });
      await ctx.close();

      const slug = slugFor(screen, state, vp.name);
      cases.push({ slug, url, ...result, pass: result.failures.length === 0 });
      console.log(`${result.failures.length ? '✗' : '✓'} ${slug}${result.failures.length ? `  ${result.failures.length} failure(s)` : ''}${result.warnings.length ? `  ${result.warnings.length} warning(s)` : ''}`);
      for (const f of result.failures) console.log(`    fail ${f.check}: ${f.detail}`);
      if (warningsMode === 'all') for (const w of result.warnings) console.log(`    warning ${w.check}: ${w.detail}`);
    }
  }
}
await browser.close();

const failed = cases.filter((c) => !c.pass);
writeQualityReport(outDir, cases, meta);
const wl = warningLines(cases);
if (wl.length) console.log(`\n${wl.join('\n')}`);
console.log(`\n${cases.length - failed.length}/${cases.length} passing${shard ? ` (shard ${shard.k}/${shard.n})` : ''} -> ${relative(process.cwd(), outDir)}/report.md`);
process.exit(failed.length ? 1 : 0);
