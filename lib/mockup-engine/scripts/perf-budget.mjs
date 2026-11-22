#!/usr/bin/env node
/**
 * perf-budget.mjs: the production bar's performance budget (skills/convert-mockup/references/production-bar.md).
 *
 *   node perf-budget.mjs --budget <perf-budget.json> --dist <app>/dist
 *        [--url <served base> --mockup <mockup-dir> [--route <regex>] [--runs 3] [--session <file>]] [--record <file>]
 *   node perf-budget.mjs --budget <perf-budget.json> --next <app>/.next --url <served base> --mockup <mockup-dir>
 *        [--route <regex>] [--runs 3] [--session <file>] [--record <file>]
 *
 * --next (a Next.js server build, which has no index.html): the initial load is measured from the
 * served pages. Each selected screen's route is fetched (signed in with --session) and the scripts and
 * stylesheets its HTML names under /_next/static are its initial load; the largest across the routes
 * is reported. Every other .js file under .next/static is a lazy chunk. buildSha is .next/BUILD_ID's
 * sha256. A build whose inlined env says MOCKS=true (required-server-files.json) is refused as mocked.
 *
 * Bundle (the gate): measured on the production build (`npm run build`, never the mocked one, which
 * carries the mock worker and the fixtures). The initial load is every file dist/index.html names
 * (module scripts, modulepreload links, stylesheets) and the files those scripts import statically;
 * every other .js file under dist is a lazy chunk. Sizes are gzip (level 9), in KB of 1,000 bytes.
 * Vitals (with --url): each selected screen of the mockup config, at its narrowest viewport, CPU
 * slowed 4 times (Chromium DevTools protocol), the median of --runs loads: LCP (largest contentful
 * paint) and CLS (layout shift, as the browser reports it). On a loaded machine they move, so
 * budgets need headroom; they gate only when the budget says "gate": true, else they warn.
 * --session loads a signed-in session (staging-run.mjs --save-session), so pages behind sign-in
 * are measured, not the sign-in page.
 *
 * perf-budget.json:
 *   { "bundle": { "initialJsKb": 200, "initialCssKb": 40, "lazyChunkKb": 100 },
 *     "vitals": { "lcpMs": 2500, "cls": 0.1, "gate": false } }
 *
 * --record writes { date, buildSha, contractSha, bundle, vitals, problems, warnings } for
 * production-bar.mjs; buildSha is dist/index.html's sha256 (it names every hashed asset), so the
 * record can be matched to the build;
 * contractSha comes from the app's api/contract-source.json when it is there.
 * The budget must set bundle.initialJsKb; --runs is a positive integer. A file index.html names that
 * is not under dist (a base path is allowed for), an initial load with no JS, and --url with no
 * screen selected are refused: nothing measured is not within budget.
 * --dist with --next, and --mockup, --route, --runs or --session without --url, are refused (exit 2):
 * a flag that does not apply is never ignored.
 * Exit 0 within budget, 1 over, 2 bad arguments (lib/args.mjs), no build, nothing measured, or a crash.
 */
import './lib/browsers-env.mjs'; // first: playwright reads its browsers path when it loads
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { gzipSync } from 'node:zlib';
import { sha256 } from './lib/production.mjs';
import { cli, usageError } from './lib/args.mjs';

const { values: flags } = cli('perf-budget');
const opt = (n, d) => flags[n] ?? d;
const fail = (m) => { console.error(`perf-budget: ${m}`); process.exit(2); };
if (!opt('budget') || (!opt('dist') && !opt('next'))) usageError('perf-budget', '--budget and one of --dist or --next are required');
// A flag that does not apply is refused, never ignored: one build, and the vitals flags need --url
if (opt('dist') && opt('next')) usageError('perf-budget', 'pass --dist or --next, not both');
for (const f of ['mockup', 'route', 'runs', 'session']) if (flags[f] !== undefined && !opt('url')) usageError('perf-budget', `--${f} applies to the vitals, which need --url`);
let budget;
try { budget = JSON.parse(readFileSync(opt('budget'), 'utf8')); } catch (e) { fail(`${opt('budget')}: ${e.message}`); }
// A budget with no initial JS limit gates nothing: refuse it rather than pass it.
if (!Number.isFinite(budget?.bundle?.initialJsKb)) fail(`${opt('budget')}: bundle.initialJsKb must be a number (the initial JS budget, KB gzip)`);
if (flags.runs !== undefined && !/^[1-9]\d*$/.test(opt('runs') ?? '')) fail(`--runs ${opt('runs')}: want a positive integer`);
const nextDir = opt('next') ? resolve(opt('next')) : null;
const dist = nextDir ? join(nextDir, 'static') : resolve(opt('dist'));
if (nextDir) {
  if (!existsSync(join(nextDir, 'BUILD_ID'))) fail(`${nextDir}/BUILD_ID not found: run the production build first (next build)`);
  if (!opt('url') || !opt('mockup')) fail('--next measures the served pages: it needs --url and --mockup');
} else if (!existsSync(join(dist, 'index.html'))) fail(`${dist}/index.html not found: run the production build first`);

const kb = (file) => Math.round(gzipSync(readFileSync(file), { level: 9 }).length / 10) / 100;
const rel = (f) => relative(dist, f).split(sep).join('/');
const sum = (files) => Math.round(files.reduce((t, f) => t + kb(f), 0) * 100) / 100;
const all = [];
const walk = (d) => { for (const n of readdirSync(d)) { const p = join(d, n); if (statSync(p).isDirectory()) walk(p); else if (/\.(js|css)$/.test(n)) all.push(p); } };
walk(dist);
const namedIn = (html) => [...html.matchAll(/<(?:script[^>]*\bsrc|link[^>]*\bhref)="([^"]+)"/g)].map((m) => m[1]).filter((u) => !/^[a-z]+:|^\/\//i.test(u));

let initial = new Set();
let initialJs, initialCss;
const extraProblems = [];
if (nextDir) {
  const env = existsSync(join(nextDir, 'required-server-files.json')) ? JSON.parse(readFileSync(join(nextDir, 'required-server-files.json'), 'utf8')).config?.env ?? {} : {};
  if (env.MOCKS === 'true') extraProblems.push('this is the mocked build (its env inlines MOCKS=true): measure `next build`, not the mocked one');
  const { chromium } = await import('playwright');
  const { appUrl, routeSelected } = await import('./lib/screens.mjs');
  const config = JSON.parse(readFileSync(join(resolve(opt('mockup')), 'mockup.config.json'), 'utf8'));
  const include = opt('route') ? new RegExp(opt('route')) : null;
  const screens = (config.screens || []).filter((s) => !s.steps?.length && routeSelected(s, { include }));
  const browser = await chromium.launch();
  const perRoute = [];
  try {
    const ctx = await browser.newContext(opt('session') ? { storageState: opt('session') } : {});
    // Through a page, not ctx.request: a session's Secure cookies go to http://127.0.0.1 from a page
    // (a secure context) but not from Playwright's request API.
    const page = await ctx.newPage();
    for (const route of [...new Set(screens.map((s) => appUrl(s, 'default', opt('url').replace(/\/$/, ''))))]) {
      const res = await page.goto(route, { waitUntil: 'load' });
      if (!res || new URL(page.url()).pathname !== new URL(route).pathname) fail(`${route} ended on ${new URL(page.url()).pathname}, not the page: pass a signed-in --session (staging-run.mjs --save-session) that is still valid`);
      const files = new Set(namedIn(await res.text()).map((u) => u.split('?')[0]).filter((u) => u.startsWith('/_next/static/')).map((u) => join(dist, decodeURIComponent(u.slice('/_next/static/'.length)))).filter((f) => existsSync(f) && /\.(js|css)$/.test(f)));
      if (![...files].some((f) => f.endsWith('.js'))) fail(`${route}: the page names no script found under ${dist}: measure the build that serves it`);
      perRoute.push({ route, files, js: sum([...files].filter((f) => f.endsWith('.js'))), css: sum([...files].filter((f) => f.endsWith('.css'))) });
    }
    await ctx.close();
  } finally { await browser.close(); }
  if (!perRoute.length) fail('--next: no screen selected to fetch');
  for (const r of perRoute) for (const f of r.files) initial.add(f);
  initialJs = Math.max(...perRoute.map((r) => r.js));
  initialCss = Math.max(...perRoute.map((r) => r.css));
  for (const r of perRoute) console.log(`route ${new URL(r.route).pathname}: initial JS ${r.js} KB, CSS ${r.css} KB gzip (${r.files.size} files)`);
} else {
  const html = readFileSync(join(dist, 'index.html'), 'utf8');
  const named = namedIn(html);
  // A URL in index.html carries the build's base (Vite `base: '/app/'` names /app/assets/x.js for
  // dist/assets/x.js): leading segments are dropped until the file is found under dist.
  const toFile = (u) => {
    const segs = decodeURIComponent(u.split(/[?#]/)[0]).replace(/^\.?\//, '').split('/').filter(Boolean);
    for (let i = 0; i < segs.length; i++) {
      const f = resolve(dist, segs.slice(i).join('/'));
      if ((f === dist || f.startsWith(dist + sep)) && existsSync(f) && statSync(f).isFile()) return f;
    }
    fail(`index.html names ${u}, which is not under ${dist} (with or without a base path): measure the build this index.html came from`);
  };
  const visit = (file) => {
    if (initial.has(file)) return;
    if (!existsSync(file)) fail(`${rel(file)} is imported statically but is not under ${dist}`);
    initial.add(file);
    if (!file.endsWith('.js')) return;
    const src = readFileSync(file, 'utf8');
    // Static imports only: `import ... from "./x.js"` and `import "./x.js"`, not import("./x.js").
    for (const m of src.matchAll(/(?:^|[;\s}])import\s*(?:[^'"()]*?from\s*)?["']([^"']+\.js)["']/g)) visit(resolve(dirname(file), m[1]));
  };
  for (const u of named) if (/\.(js|css)$/.test(u.split('?')[0])) visit(toFile(u));
  initialJs = sum([...initial].filter((f) => f.endsWith('.js')));
  initialCss = sum([...initial].filter((f) => f.endsWith('.css')));
}
// Nothing measured is not within budget.
if (![...initial].some((f) => f.endsWith('.js'))) fail(`the initial load names no JS file: nothing measured (${nextDir ? 'the served pages name no /_next/static script' : 'dist/index.html names no script under dist'})`);
const lazy = all.filter((f) => f.endsWith('.js') && !initial.has(f)).map((f) => ({ file: rel(f), kb: kb(f) })).sort((a, b) => b.kb - a.kb);

const problems = [...extraProblems], warnings = [];
const b = budget.bundle || {};
const over = (what, got, max) => { if (max !== undefined && got > max) problems.push(`${what} ${got} KB gzip is over the budget of ${max} KB`); };
over('initial JS', initialJs, b.initialJsKb);
over('initial CSS', initialCss, b.initialCssKb);
for (const c of lazy) over(`lazy chunk ${c.file}`, c.kb, b.lazyChunkKb);
if (all.some((f) => /mockServiceWorker|\bmsw\b/.test(rel(f))) || existsSync(join(dist, 'mockServiceWorker.js'))) problems.push('the build carries the mock service worker: measure `npm run build`, not the mocked build');
console.log(`bundle: initial JS ${initialJs} KB, initial CSS ${initialCss} KB gzip (${initial.size} files); ${lazy.length} lazy chunks${lazy.length ? `, largest ${lazy[0].file} ${lazy[0].kb} KB` : ''}`);

let vitals = null;
if (opt('url')) {
  if (!opt('mockup')) fail('--url needs --mockup, for the screens to load');
  const { chromium } = await import('playwright');
  const { appUrl, routeSelected } = await import('./lib/screens.mjs');
  const config = JSON.parse(readFileSync(join(resolve(opt('mockup')), 'mockup.config.json'), 'utf8'));
  const vp = [...(config.viewports || [{ name: 'mobile', width: 390, height: 844 }])].sort((x, y) => x.width - y.width)[0];
  const include = opt('route') ? new RegExp(opt('route')) : null;
  const screens = (config.screens || []).filter((s) => !s.steps?.length && routeSelected(s, { include }));
  const runs = Number(opt('runs', 3));
  const v = budget.vitals || {};
  if (!screens.length) fail(`--url: no screen selected (${opt('route') ? `--route ${opt('route')} matches none` : 'the mockup config has no screen without steps'}): nothing to measure`);
  const browser = await chromium.launch();
  vitals = [];
  try {
    for (const s of screens) {
      const lcps = [], clss = [];
      for (let i = 0; i < runs; i++) {
        const ctx = await browser.newContext({ viewport: { width: vp.width, height: vp.height }, ...(opt('session') ? { storageState: opt('session') } : {}) });
        const page = await ctx.newPage();
        const cdp = await ctx.newCDPSession(page);
        await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });
        await page.addInitScript(() => {
          window.__vitals = { lcp: 0, cls: 0 };
          new PerformanceObserver((l) => { for (const e of l.getEntries()) window.__vitals.lcp = e.startTime; }).observe({ type: 'largest-contentful-paint', buffered: true });
          new PerformanceObserver((l) => { for (const e of l.getEntries()) if (!e.hadRecentInput) window.__vitals.cls += e.value; }).observe({ type: 'layout-shift', buffered: true });
        });
        const target = appUrl(s, 'default', opt('url').replace(/\/$/, ''));
        await page.goto(target, { waitUntil: 'load' });
        // A page behind sign-in without a valid session measures the sign-in page instead.
        if (new URL(page.url()).pathname !== new URL(target).pathname) fail(`${s.name}: ${target} ended on ${new URL(page.url()).pathname}, not the page: pass a signed-in --session that is still valid`);
        await page.waitForTimeout(1500);
        const got = await page.evaluate(() => window.__vitals);
        lcps.push(got.lcp); clss.push(got.cls);
        await ctx.close();
      }
      const med = (xs) => [...xs].sort((x, y) => x - y)[Math.floor(xs.length / 2)];
      const row = { screen: s.name, route: s.route, lcpMs: Math.round(med(lcps)), cls: Math.round(med(clss) * 1000) / 1000 };
      vitals.push(row);
      const list = v.gate ? problems : warnings;
      if (v.lcpMs !== undefined && row.lcpMs > v.lcpMs) list.push(`${s.name}: LCP ${row.lcpMs} ms is over ${v.lcpMs} ms`);
      if (v.cls !== undefined && row.cls > v.cls) list.push(`${s.name}: CLS ${row.cls} is over ${v.cls}`);
      console.log(`vitals: ${s.name} at ${vp.width}px, CPU 4x, median of ${runs}: LCP ${row.lcpMs} ms, CLS ${row.cls}`);
    }
  } finally { await browser.close(); }
}

for (const w of warnings) console.log(`warning: ${w}`);
for (const p of problems) console.log(`over: ${p}`);
console.log(problems.length ? `perf-budget: ${problems.length} over budget` : 'perf-budget: within budget');
if (opt('record')) {
  const src = join(nextDir ? dirname(nextDir) : dirname(dist), 'api', 'contract-source.json');
  const contractSha = existsSync(src) ? JSON.parse(readFileSync(src, 'utf8')).sha256 : null;
  const buildSha = sha256(readFileSync(nextDir ? join(nextDir, 'BUILD_ID') : join(dist, 'index.html')));
  writeFileSync(opt('record'), `${JSON.stringify({ date: new Date().toISOString(), ...(nextDir ? { build: 'next' } : {}), buildSha, contractSha, bundle: { initialJsKb: initialJs, initialCssKb: initialCss, lazy }, vitals, problems, warnings }, null, 2)}\n`);
}
process.exit(problems.length ? 1 : 0);
