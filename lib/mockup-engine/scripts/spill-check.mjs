#!/usr/bin/env node
/**
 * spill-check.mjs: finds content that does not fit its own box, which a page-level overflow check
 * misses (an amount wider than its card, a word wider than its column, a button wider than its row).
 * Every screen and state in mockup.config.json at 13 widths from 320 to 1920 px, the mockup served
 * over HTTP (lib/serve.mjs), as the other checks load it. For each, it reports
 * each element whose content is wider than it, the card it is in, by how much, and the kind:
 *   spills   the content shows outside the box
 *   clipped  the box hides it (overflow hidden or clip)
 *   scrolls  the box scrolls sideways; allowed only for tab strips, labelled scroll regions and the
 *            selectors in spill.scrollAllowed
 * Nested overflow: an element is reported, and so is every ancestor that overflows further than the
 * spilling content inside it explains (a clipped label does not hide its row running off the window).
 * An ancestor whose overflow is only a descendant's spill carried up is not reported again.
 * Not counted:
 *   - form controls: a long value in a field scrolls inside it by design
 *   - intended truncation: a clipped box with computed `text-overflow: ellipsis`
 *   - a box marked `data-clip` (its overflow is intended, whatever the kind; say why in a comment)
 *   - hidden boxes: [hidden], a closed dialog, display none, and visually hidden boxes (the box or an
 *     ancestor is at most 1px square and clips, by overflow, `clip` or `clip-path`, whatever its class)
 *   - absolutely and fixed positioned descendants: they are taken out when a box is measured, so an
 *     open popover panel does not count as overflow of its button (the panel is measured on its own)
 * mockup.config.json keys it reads (all optional):
 *   locale     the browser locale (default en-GB), as quality-check and visual-diff use it
 *   timezoneId the browser timezone (UTC when absent)
 *   spill: {
 *     cards:         selectors, added to the defaults, for the "card" a finding is attributed to
 *                    (defaults: .panel, .card, .dialog, [role="dialog"], [role="region"][tabindex])
 *     scrollAllowed: selectors, added to the defaults, for boxes allowed to scroll sideways, such as
 *                    a wide table's wrapper (defaults: [role="region"][tabindex], a named
 *                    section[tabindex] (implicit region), [role="tablist"])
 *   }
 * --text 1.25 repeats the run with the root font at 125%, as for a reader with larger default text;
 * a value that is not a number above 0 exits 2. --screen matches a screen's name, else its route,
 * else its page.
 * --locale <code> runs every screen in that locale (?locale=<code>), overriding a screen's own; use
 * --locale pseudo for text about 40% longer than the default locale's, as a long translation is.
 * A screen with steps is left out under a --locale other than its own (steps name controls in the
 * screen's locale) and listed; give it a screen entry in that locale to cover it.
 * Writes .mockup-engine/spill.json into the mockup, or spill-text-<k>.json, spill-locale-<code>.json
 * or spill-text-<k>-locale-<code>.json for those runs.
 * Exits 1 when anything is found, so it can gate a build; 2 when it cannot run (a bad argument, no
 * config, a --screen that matches nothing, a crash).
 * --out <dir> writes the result file there instead (at Convert, so the package is not written).
 * Usage: node spill-check.mjs --mockup <dir> [--screen substr] [--widths 320,1024] [--text 1.25] [--locale pseudo] [--out <dir>]
 */
import './lib/browsers-env.mjs'; // first: playwright reads its browsers path when it loads
import { chromium } from 'playwright';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { mockupUrl, settle, runSteps, slugFor } from './lib/screens.mjs';
import { serveMockup } from './lib/serve.mjs';
import { configLocale, configZone } from './lib/project.mjs';
import { SPECS, cli } from './lib/args.mjs';

const CARDS = ['.panel', '.card', '.dialog', '[role="dialog"]', '[role="region"][tabindex]', 'section[aria-label][tabindex]', 'section[aria-labelledby][tabindex]'];
// A section with an accessible name has the implicit role region, so it counts as one
const SCROLLS_OK = ['[role="region"][tabindex]', 'section[aria-label][tabindex]', 'section[aria-labelledby][tabindex]', '[role="tablist"]'];

const { values: flags } = cli('spill-check');
const arg = (k) => flags[k] ?? null;

function fail(message) {
  console.error(`spill-check: ${message}`);
  process.exit(2);
}

/**
 * Runs in the page. Measures in passes by depth, the number of absolutely or fixed positioned boxes
 * an element is in (itself included): pass k shows the positioned boxes of depth k or less, hides the
 * deeper ones, and measures the elements of depth k, so no box counts a positioned descendant.
 */
function scan({ cards, scrollsOk }) {
  const CARD = cards.join(', ');
  const SCROLLS = scrollsOk.join(', ');
  const MARK = 'data-spill-check-out';
  const name = (el) => `${el.tagName.toLowerCase()}${el.id ? `#${el.id}` : ''}.${[...el.classList].slice(0, 2).join('.')}`;
  const all = [...document.querySelectorAll('body *')].filter((el) => !(el instanceof SVGElement));
  const style = new Map(all.map((el) => [el, getComputedStyle(el)]));
  const positioned = (el) => ['absolute', 'fixed'].includes(style.get(el).position);
  const depth = new Map();
  const depthOf = (el) => {
    if (!style.has(el)) return 0;
    if (depth.has(el)) return depth.get(el);
    const d = depthOf(el.parentElement) + (positioned(el) ? 1 : 0);
    depth.set(el, d);
    return d;
  };
  // visually hidden: at most 1px square and clipping, measured with everything shown
  const vh = new Map();
  const tiny = (el) => {
    const cs = style.get(el);
    if (cs.display === 'contents') return false;
    const clips = cs.clip !== 'auto' || cs.clipPath !== 'none' || ['hidden', 'clip'].includes(cs.overflowX);
    if (!clips) return false;
    const r = el.getBoundingClientRect();
    return r.width <= 1 && r.height <= 1;
  };
  const hiddenOf = (el) => {
    if (!style.has(el)) return false;
    if (vh.has(el)) return vh.get(el);
    const h = hiddenOf(el.parentElement) || tiny(el);
    vh.set(el, h);
    return h;
  };
  for (const el of all) { depthOf(el); hiddenOf(el); }
  const maxDepth = Math.max(0, ...depth.values());
  // A constructed sheet, not a <style>: a strict CSP blocks inline style.
  const constructed = new CSSStyleSheet();
  constructed.replaceSync(`[${MARK}] { display: none !important; }`);
  document.adoptedStyleSheets = [...document.adoptedStyleSheets, constructed];
  const sheet = { remove: () => { document.adoptedStyleSheets = document.adoptedStyleSheets.filter((x) => x !== constructed); } };
  const out = [];
  try {
    for (let k = 0; k <= maxDepth; k++) {
      for (const el of all) {
        if (positioned(el) && depth.get(el) > k) el.setAttribute(MARK, '');
        else el.removeAttribute(MARK);
      }
      const boxes = [];
      for (const el of all) {
        if (depth.get(el) !== k) continue;
        if (el.matches('input, textarea, select') || el.closest('.visually-hidden, [hidden], dialog:not([open])') || vh.get(el)) continue;
        const cs = style.get(el);
        if (cs.display === 'none' || cs.display === 'inline' || cs.display === 'contents') continue;
        if (!el.clientWidth || el.matches('html, body')) continue;
        const over = el.scrollWidth - el.clientWidth;
        if (over <= 1) continue;
        const kind = ['hidden', 'clip'].includes(cs.overflowX) ? 'clipped' : ['auto', 'scroll'].includes(cs.overflowX) ? 'scrolls' : 'spills';
        const r = el.getBoundingClientRect();
        const right = r.left + el.clientLeft - el.scrollLeft + el.scrollWidth; // where its content ends
        const intended = el.hasAttribute('data-clip')
          || (kind === 'clipped' && cs.textOverflow === 'ellipsis')
          || (kind === 'scrolls' && el.matches(SCROLLS));
        boxes.push({ el, kind, over, right, intended });
      }
      for (const b of boxes) {
        if (b.intended) continue;
        // an ancestor of a spill reaches no further than the spill: the same overflow carried up
        const carried = boxes.some((d) => d !== b && d.kind === 'spills' && b.el.contains(d.el) && d.right >= b.right - 1);
        if (carried) continue;
        const card = b.el.closest(CARD);
        const text = (b.el.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 50);
        out.push({ kind: b.kind, el: name(b.el), card: card ? name(card) : null, over: b.over, text });
      }
    }
  } finally {
    for (const el of all) el.removeAttribute(MARK);
    sheet.remove();
  }
  return out;
}

async function main() {
  if (!arg('mockup')) fail(`--mockup is required\n${SPECS['spill-check'].usage}`);
  const dir = resolve(arg('mockup'));
  let config;
  try { config = JSON.parse(readFileSync(join(dir, 'mockup.config.json'), 'utf8')); } catch (e) { fail(`cannot read ${join(dir, 'mockup.config.json')}: ${e.message}`); }
  const spill = config.spill || {};
  const opts = { cards: [...CARDS, ...(spill.cards || [])], scrollsOk: [...SCROLLS_OK, ...(spill.scrollAllowed || [])] };
  const locale = configLocale(config);
  const widths = (arg('widths') || '320,390,600,768,900,1024,1100,1180,1280,1366,1440,1536,1920').split(',').map(Number);
  if (widths.some((w) => !(w > 0))) fail(`bad --widths ${arg('widths')}`);
  const only = arg('screen');
  // --text 1.25 sets the root font size to 125%, as for a reader who raised the browser's default text size
  const textScale = arg('text') === null ? 1 : Number(arg('text'));
  if (!Number.isFinite(textScale) || textScale <= 0) fail(`--text must be a number above 0 (1.25 for 125%), got ${arg('text')}`);
  const jobs = [];
  // Steps match accessible names exactly, in the screen's own locale: under another --locale (pseudo
  // above all) they name controls that are not there, so a screen with steps is left out and counted.
  const forced = arg('locale');
  const skippedSteps = [];
  for (const s of config.screens || []) {
    // a screen may have no name: it is known by its route, else its page
    const label = s.name || s.route || s.page || '';
    if (only && !label.includes(only)) continue;
    if (forced && s.steps?.length && forced !== (s.locale ?? locale)) { skippedSteps.push(label); continue; }
    for (const state of s.states || ['default']) for (const w of widths) jobs.push({ s, state, w });
  }
  if (skippedSteps.length) console.log(`--locale ${forced}: ${skippedSteps.length} screens with steps left out (their steps name controls in their own locale): ${skippedSteps.join(', ')}`);
  if (!jobs.length) fail(only ? `--screen "${only}" matches no screen in mockup.config.json` : skippedSteps.length ? `every screen has steps; none can run under --locale ${forced}` : 'mockup.config.json has no screens');

  const { server, base } = await serveMockup(dir);
  const browser = await chromium.launch();
  const results = [];
  let next = 0;
  async function worker() {
    while (next < jobs.length) {
      const { s, state, w } = jobs[next++];
      const slug = slugFor(s, state, `${w}`);
      let ctx;
      try {
        ctx = await browser.newContext({ viewport: { width: w, height: 900 }, reducedMotion: 'reduce', timezoneId: configZone(config), locale });
        const page = await ctx.newPage();
        if (textScale !== 1) await page.addInitScript((k) => { document.addEventListener('DOMContentLoaded', () => { document.documentElement.style.fontSize = `${k * 100}%`; }); }, textScale);
        await page.goto(mockupUrl(arg('locale') ? { ...s, locale: arg('locale') } : s, state, { base }), { waitUntil: 'load' });
        await settle(page);
        await runSteps(page, s.steps);
        for (const h of await page.evaluate(scan, opts)) results.push({ slug, width: w, ...h });
      } catch (e) {
        results.push({ slug, width: w, el: 'LOAD', over: 0, text: String(e.message).split('\n')[0] });
      } finally {
        await ctx?.close().catch(() => {});
      }
    }
  }
  try { await Promise.all(Array.from({ length: 6 }, worker)); } finally { await browser.close(); server.close(); }
  // --out keeps a signed-off package untouched at Convert (default: the mockup's own cache).
  const outDir = arg('out') ? resolve(arg('out')) : join(dir, '.mockup-engine');
  mkdirSync(outDir, { recursive: true });
  // One file per run kind, so a --text or --locale run does not overwrite the plain run's.
  const outName = `spill${textScale === 1 ? '' : `-text-${textScale}`}${forced ? `-locale-${forced}` : ''}.json`;
  writeFileSync(join(outDir, outName), JSON.stringify(results, null, 1));
  const groups = {};
  for (const r of results) { const k = `[${r.kind}] ${r.el} in ${r.card || '(no card)'}: "${r.text}"`; (groups[k] ||= []).push(`${r.slug}`); }
  for (const [k, v] of Object.entries(groups).sort((a, b) => b[1].length - a[1].length)) console.log(`${v.length}x  ${k}\n      e.g. ${v.slice(0, 3).join(', ')}`);
  console.log(`\n${jobs.length} cases, ${results.length} spills, ${Object.keys(groups).length} distinct`);
  return results.length ? 1 : 0;
}

try {
  process.exitCode = await main();
} catch (e) {
  console.error(`spill-check: crashed: ${e.stack || e}`);
  process.exitCode = 2;
}
