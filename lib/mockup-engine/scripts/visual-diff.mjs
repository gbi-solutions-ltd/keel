#!/usr/bin/env node
/**
 * visual-diff.mjs: screenshot a mockup and measure how far it is from a running app (app mode) or
 * from stored PNGs of another mockup (baseline mode).
 *
 * App mode:
 *   node visual-diff.mjs --mockup <mockup-dir> --app <base-url> [--out <dir>]
 *                        [--screen <name-substring>] [--viewport <name>] [--state <name>] [--tz <zone>]
 *                        [--clock <iso-instant>] [--seed <int>] [--route <regex>] [--exclude-route <regex>]
 *                        [--settle-steps] [--shard K/N]
 *
 * --clock and --seed pin both sides as baseline mode does (lib/pin.mjs), so dated and seeded
 * screens compare at the values the mockup was designed with.
 *
 * Reads <mockup-dir>/mockup.config.json for screens, states, viewports and thresholds.
 * For every screen × state × viewport:
 *   - mockup: <page>?state=<state>, served over HTTP from <mockup-dir> (lib/serve.mjs) as in
 *     baseline mode; report.json records it relative to <mockup-dir> (mockupUrl)
 *   - app:    <base-url><route>?state=<state>      (the app's mock layer must honour ?state)
 *   - full-page screenshots with animations off and [data-diff-ignore] masked
 *   - pixel diff (pixelmatch) -> mismatch %
 *   - --expected <file> (app mode reads it only when named): the expected-diffs format of
 *     lib/expected-diffs.mjs. Its masks are painted into both captures and a screens entry raises that
 *     case's limit (status expected, which passes). Validated before any capture against the config's
 *     cases (exit 2 when missing, not JSON or invalid); a screens[].size entry is refused in app mode.
 *   - component diff: every [data-component] box in mockup vs app, matched by name + order,
 *     so failures point at a component, not just a pixel region
 * Writes <out>/report.md, <out>/report.json and per-case PNGs (mockup / app / diff).
 * Prints `X of N planned captures measured, not measured: M` (a case that errored is not measured)
 * before the `X/Y passing` line. Exit code 1 if any case exceeds diff.maxMismatchPercent (default 0,
 * or 0.2 when project.designFramework.kind is js-kit) or errored; 2 (before any capture) when the
 * config and the filters select no case. --skip and --workers are refused in app mode (exit 2).
 * Baseline mode uses diff.baselineMaxMismatchPercent instead (default: diff.maxMismatchPercent when
 * set, else 0.2, capped at 0.2).
 *   - --shard K/N runs only shard K of N (lib/shard.mjs planAppShards: whole screens, balanced by
 *     captures and steps). Each writes its own --out (default
 *     <mockup-dir>/.mockup-engine/diff-shards/K, a stale report.json there is removed first) with
 *     the whole plan in report.json; merge-shards.mjs app merges them into the report a serial app
 *     run writes. A shard with nothing to capture exits 0 without a browser.
 *
 * Config checks in every mode, before any capture (exit 2): two viewports or two screens with one
 * name, a state listed twice, two cases with one slug, a screen with neither name nor route, and in
 * app mode a screen with no route (lib/screens.mjs screenProblems).
 *
 * Filters and options shared by every mode (app, baseline, write-baseline):
 *   - --route <regex> / --exclude-route <regex>: keep only the screens whose route (their page when
 *     they have no route) matches --route and does not match --exclude-route. Like --screen they
 *     select: a screen they drop is not planned, listed or counted. They combine with --screen,
 *     --state and --viewport (all must select a case) and, in baseline mode, with --skip (a selected
 *     screen --skip matches is listed as skipped). An invalid regex exits 2; when a route filter is
 *     given and nothing is selected the run exits 2 before any capture, as with any filter that
 *     selects nothing.
 *   - --settle-steps: before each config step, on both sides, wait for layout to be stable
 *     (document.fonts.ready, then document scroll height unchanged across two animation frames,
 *     capped at 2s: lib/screens.mjs layoutStable), so a page that reflows after a focus call
 *     scrolled is not captured mid-reflow. A single step can ask for the same with
 *     "settleLayout": true in the config. Off by default. A baseline written with it should be
 *     compared with it.
 *   - Unused expected-diffs entries: after a run with an expected-diffs file (app mode with
 *     --expected, baseline mode with --expected or the default file), the screens entries the run did
 *     not need (every case they cover measured at or under the config limit, or no config case
 *     matched) are printed as a warning after the summary and written to report.md and to
 *     report.json (unusedExpected). An entry is not judged when one of its cases was filtered out,
 *     skipped or not measured; rules (masks) are never judged. The exit status is unchanged. A
 *     shard does not list them; the merge does.
 *
 * Baseline mode (a rebuilt mockup against PNGs captured from the old one):
 *   node visual-diff.mjs --mockup <mockup-dir> --baseline <png-dir> [--expected <file>] [--out <dir>]
 *                        [--screen <name-substring>] [--viewport <name>] [--state <name>]
 *                        [--skip <regex>] [--workers 4] [--clock <iso-instant>] [--seed <int>]
 *                        [--tz <zone>] [--shard K/N] [--route <regex>] [--exclude-route <regex>] [--settle-steps]
 *                        [--allow-missing-baseline]
 *
 *   - Pairs every config screen × state × viewport with <png-dir>/<name>--<state>--<viewport>.png
 *     (the slugFor name). A case with no PNG is listed as no-baseline and fails the run (a screen
 *     added after the baseline was written is otherwise never compared); --allow-missing-baseline
 *     lists those cases as a warning instead and they do not fail. A screen whose name matches
 *     --skip (a regex, e.g. "-tour$") is listed as skipped.
 *   - The mockup is served over HTTP from <mockup-dir>, captured full page after settle, the freeze
 *     stylesheet and the steps (no [data-diff-ignore] paint: use expected-diffs masks instead).
 *   - --clock fixes Date at that instant, --seed pins Math.random (mulberry32), --tz sets the time
 *     zone (default config.timezoneId, else UTC; the locale as lib/project.mjs configLocale): pass the values the
 *     baseline was captured with so dates and generated values repeat.
 *   - --expected: masks, raised per-screen limits (capped at 5%) and declared size changes, each with
 *     a reason. Defaults to <mockup-dir>/docs/expected-diffs.json when that file exists. Its format
 *     is documented in lib/expected-diffs.mjs. It is validated in full before any capture.
 *   - Status per case: pass, expected (within its expected-diffs entry), fail, size-mismatch, error.
 *   - --shard K/N runs only shard K of N (lib/shard.mjs: whole screen names, balanced by captures,
 *     baseline megapixels and steps), so N processes can share one run. Each writes its own --out
 *     (default <mockup-dir>/.mockup-engine/baseline-diff-shards/K) with the whole plan in
 *     report.json; merge-shards.mjs diff merges them into the report a serial run writes. A shard
 *     with nothing to capture exits 0.
 * Writes <out>/report.md, <out>/report.json, <out>/<slug>/capture.png for every compared case and
 * <out>/<slug>/diff.png for every case that is not a pass. Default out: <mockup-dir>/.mockup-engine/baseline-diff.
 * Exit 2 before any capture when the expected-diffs file is missing (when named), unreadable or
 * invalid, when the baseline dir is missing, or when the filters select no case. Exit 1 before any
 * capture when no selected case has a baseline PNG, and after the run when any case fails, is
 * size-mismatch or errors, has no baseline PNG (unless --allow-missing-baseline), or nothing was
 * compared.
 * Exit 2, in every mode, on a bad argument (lib/args.mjs: an unknown flag, a value flag with no value
 * or another flag as its value) or a bad flag value (--clock, --seed, --skip, --workers, --shard, a
 * route regex), and on a crash.
 * In baseline mode --out is emptied first, so it is refused (exit 2) when it is, or contains, the
 * mockup folder, the current folder or the home folder, or is a git root or holds one
 * (lib/baseline-report.mjs outDirRefusal). An earlier run's out folder is fine. App mode writes into
 * --out without emptying it.
 *
 * Write-baseline mode (store PNGs of this mockup, for a later --baseline run against a rebuild):
 *   node visual-diff.mjs --mockup <mockup-dir> --write-baseline <png-dir>
 *                        [--screen <name-substring>] [--viewport <name>] [--state <name>]
 *                        [--skip <regex>] [--workers 4] [--clock <iso-instant>] [--seed <int>] [--tz <zone>]
 *                        [--route <regex>] [--exclude-route <regex>] [--settle-steps]
 *
 *   - Captures every case the filters select exactly as --baseline does (same server, pinned context,
 *     settle, freeze stylesheet, steps, full page) and writes <png-dir>/<name>--<state>--<viewport>.png,
 *     the names --baseline reads. Creates <png-dir>; other files in it are left alone, and a case
 *     that fails to capture leaves any older PNG of its name in place.
 *   - Prints `baseline written: N cases (S screens) -> <png-dir>` (N written, S their screens).
 *   - Exit 0 when every selected case was written; exit 2 when the filters select no case (before
 *     any capture); exit 1 when any capture failed. With --app, --baseline, --expected or --shard it is refused
 *     (exit 2). A later --baseline run on the same mockup with the same pins passes every case at 0%.
 */
import './lib/browsers-env.mjs'; // first: playwright reads its browsers path when it loads
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, statSync, rmSync } from 'node:fs';
import { join, resolve, relative } from 'node:path';
import { chromium } from 'playwright';
import pixelmatch from 'pixelmatch';
import { PNG } from 'pngjs';
import { appSteps, appUrl, mockupUrl, routeSelected, runSteps, screenKey, screenProblems, settle, slugFor } from './lib/screens.mjs';
import { appStatus, compareImages, exitCodeFor, expectedCover, formatUnused, maskCases, missingBaselineLines, parseBaselineName, unusedEntries, validateAppExpected, validateExpected } from './lib/expected-diffs.mjs';
import { outDirRefusal, writeAppReport, writeBaselineReport } from './lib/baseline-report.mjs';
import { adoptStyle, newPinnedContext, parsePins } from './lib/pin.mjs';
import { appMaxMismatchDefault, configLocale, configZone, pinDefaults } from './lib/project.mjs';
import { serveMockup } from './lib/serve.mjs';
import { parseShard, planAppShards, planDiffShards } from './lib/shard.mjs';
import { cli } from './lib/args.mjs';

const { values: flags } = cli('visual-diff');
const opt = (name, fallback) => flags[name] ?? fallback;
const has = (name) => Object.hasOwn(flags, name);

const mockupDir = resolve(opt('mockup', '.'));
const appBase = (opt('app') || '').replace(/\/$/, '');
const baselineArg = opt('baseline');
const writeArg = opt('write-baseline');
if (writeArg && (appBase || baselineArg)) { console.error('--write-baseline is a mode of its own; do not pass --app or --baseline with it'); process.exit(2); }
if (appBase && baselineArg) { console.error('--app and --baseline are two modes; pass one'); process.exit(2); }
if (!appBase && !baselineArg && !writeArg) { console.error('--app <base-url>, --baseline <png-dir> or --write-baseline <png-dir> is required, e.g. --app http://localhost:5173'); process.exit(2); }
if (writeArg && has('expected')) { console.error('--expected applies to --baseline and --app modes, not --write-baseline'); process.exit(2); }
if (writeArg && has('shard')) { console.error('--shard applies to --baseline and --app modes, not --write-baseline'); process.exit(2); }
if (writeArg && has('out')) { console.error('--out applies to --baseline and --app modes, not --write-baseline (it writes only the PNGs, into its own folder)'); process.exit(2); }
const allowMissingBaseline = has('allow-missing-baseline');
if (allowMissingBaseline && !baselineArg) { console.error('--allow-missing-baseline applies to --baseline mode only'); process.exit(2); }
// App mode captures one case at a time and compares every selected screen: --skip and --workers
// would be ignored there, so they are refused
for (const f of ['skip', 'workers']) if (appBase && has(f)) { console.error(`--${f} applies to --baseline and --write-baseline modes, not --app`); process.exit(2); }
// A shard's default out is its own folder, so parallel shards do not empty each other's
const shardK = has('shard') ? String(opt('shard')).split('/')[0] : null;
const shardOut = shardK === null ? null : baselineArg ? `.mockup-engine/baseline-diff-shards/${shardK}` : `.mockup-engine/diff-shards/${shardK}`;
const outDir = resolve(opt('out', join(mockupDir, shardOut || (baselineArg ? '.mockup-engine/baseline-diff' : '.mockup-engine/diff'))));
const onlyScreen = opt('screen');
const onlyViewport = opt('viewport');
const onlyState = opt('state');
const settleSteps = has('settle-steps');
const routeFilter = {};
for (const [flag, key] of [['route', 'include'], ['exclude-route', 'exclude']]) {
  if (!has(flag)) continue;
  try { routeFilter[key] = new RegExp(opt(flag)); } catch (e) { console.error(`--${flag} is not a valid regex: ${e.message}`); process.exit(2); }
}
const routeFiltered = Boolean(routeFilter.include || routeFilter.exclude);

const configPath = join(mockupDir, 'mockup.config.json');
if (!existsSync(configPath)) { console.error(`missing ${configPath}`); process.exit(2); }
const config = JSON.parse(readFileSync(configPath, 'utf8'));
// Colliding names would overwrite one case's PNGs with another's; a screen with no route cannot be opened in the app
const problems = screenProblems(config, { app: Boolean(appBase) });
if (problems.length) { console.error(`error: ${configPath} cannot be run:\n${problems.map((p) => `  ${p}`).join('\n')}`); process.exit(2); }
const viewports = (config.viewports || [{ name: 'desktop', width: 1440, height: 900 }]).filter((v) => !onlyViewport || v.name === onlyViewport);
// App mode only; baseline mode has its own key below.
const maxMismatch = config.diff?.maxMismatchPercent ?? appMaxMismatchDefault(config);
const pixelThreshold = config.diff?.pixelThreshold ?? 0.1;
const boxTolerance = config.diff?.boxTolerancePx ?? 4;
const timezoneId = opt('tz') ?? configZone(config);
// The config's pins under the flags, by name (pinDefaults returns { clock, seed }).
const pinArgs = pinDefaults(config, opt('clock'), opt('seed'));

const FREEZE_CSS = `
  *, *::before, *::after { animation: none !important; transition: none !important; caret-color: transparent !important; }
  html { scroll-behavior: auto !important; }
`;

async function capture(page, url, steps) {
  try {
    await page.goto(url, { waitUntil: 'load' });
    await settle(page);
    await runSteps(page, steps, { settleLayout: settleSteps });
  } catch (e) {
    return { error: String(e.message || e).split('\n')[0] };
  }
  // Everything after the steps is inside a try too: one screenshot timeout on a loaded machine
  // otherwise ended the whole run with no report. A failed screenshot is retried once, then the
  // case is an error and the run goes on.
  try {
    await adoptStyle(page, FREEZE_CSS);
    const boxes = await page.evaluate(() =>
      [...document.querySelectorAll('[data-component]')].map((el) => {
        const r = el.getBoundingClientRect();
        return { name: el.dataset.component, x: Math.round(r.x + scrollX), y: Math.round(r.y + scrollY), w: Math.round(r.width), h: Math.round(r.height) };
      }),
    );
    const shot = () => page.screenshot({ fullPage: true, mask: [page.locator('[data-diff-ignore]')], maskColor: '#ff00ff' });
    const png = await shot().catch(() => shot());
    return { png, boxes };
  } catch (e) {
    return { error: String(e.message || e).split('\n')[0] };
  }
}

function pad(img, width, height) {
  if (img.width === width && img.height === height) return img;
  const out = new PNG({ width, height });
  // fill with magenta so size differences count as mismatches
  for (let i = 0; i < out.data.length; i += 4) { out.data[i] = 255; out.data[i + 1] = 0; out.data[i + 2] = 255; out.data[i + 3] = 255; }
  PNG.bitblt(img, out, 0, 0, img.width, img.height, 0, 0);
  return out;
}

function compareBoxes(mock, app) {
  const issues = [];
  const byName = (list) => list.reduce((acc, b) => ((acc[b.name] ||= []).push(b), acc), {});
  const m = byName(mock);
  const a = byName(app);
  for (const name of new Set([...Object.keys(m), ...Object.keys(a)])) {
    const ml = m[name] || [];
    const al = a[name] || [];
    if (ml.length !== al.length) issues.push({ component: name, issue: `count mockup ${ml.length} vs app ${al.length}` });
    for (let i = 0; i < Math.min(ml.length, al.length); i++) {
      const d = ['x', 'y', 'w', 'h'].filter((k) => Math.abs(ml[i][k] - al[i][k]) > boxTolerance);
      if (d.length) {
        issues.push({
          component: `${name}[${i}]`,
          issue: d.map((k) => `${k} ${ml[i][k]}→${al[i][k]}`).join(', '),
        });
      }
    }
  }
  return issues;
}

// ---- Baseline and write-baseline modes -----------------------------------------------------------

/** Every config screen x state x viewport that --screen, --route, --exclude-route, --state and --viewport select, in config order. */
function selectCases() {
  const cases = [];
  for (const screen of config.screens) {
    if (onlyScreen && !(screen.name || screen.route).includes(onlyScreen)) continue;
    if (!routeSelected(screen, routeFilter)) continue;
    for (const state of screen.states || ['default']) {
      if (onlyState && state !== onlyState) continue;
      for (const vp of viewports) cases.push({ screen, state, vp, slug: slugFor(screen, state, vp.name) });
    }
  }
  return cases;
}

/** Every case of the config, unfiltered, as { slug, name, state, viewport } (for expectedCover). */
function allConfigCases() {
  const vps = config.viewports || [{ name: 'desktop', width: 1440, height: 900 }];
  return config.screens.flatMap((sc) => (sc.states || ['default']).flatMap((st) => vps.map((v) => ({ slug: slugFor(sc, st, v.name), name: sc.name, state: st, viewport: v.name }))));
}

/** --skip, --workers, --clock and --seed, shared by both modes. Returns { error, code: 2 } (a bad argument) or { skip, workers, clock, seed }. */
function parseRunArgs() {
  let skip = null;
  if (opt('skip')) { try { skip = new RegExp(opt('skip')); } catch (e) { return { error: `--skip is not a valid regex: ${e.message}`, code: 2 }; } }
  const workers = Number(opt('workers', '4'));
  if (!Number.isInteger(workers) || workers < 1) return { error: `--workers must be an integer >= 1, got ${opt('workers')}`, code: 2 };
  const pins = parsePins(pinArgs.clock, pinArgs.seed);
  if (pins.error) return { error: pins.error, code: 2 };
  return { skip, workers, clock: pins.clock, seed: pins.seed };
}

/** Serves the mockup, launches one browser, and runs fn over jobs with `workers` at a time. */
async function runCaptures(jobs, workers, fn) {
  const { server, base } = await serveMockup(mockupDir);
  const browser = await chromium.launch();
  try {
    let next = 0;
    const worker = async () => { while (next < jobs.length) await fn(browser, base, jobs[next++]); };
    await Promise.all(Array.from({ length: Math.min(workers, jobs.length) }, worker));
  } finally {
    await browser.close();
    server.close();
  }
}

/** Validate everything a baseline run needs, then plan it. Returns { error } or the plan. No browser. */
function planBaseline() {
  const baselineDir = resolve(baselineArg);
  if (!existsSync(baselineDir) || !statSync(baselineDir).isDirectory()) return { error: `baseline dir ${baselineDir} does not exist`, code: 2 };
  const baseline = readdirSync(baselineDir).map((f) => ({ file: f, ...parseBaselineName(f) })).filter((b) => b.name);
  const files = new Set(baseline.map((b) => b.file));

  const named = opt('expected');
  const expectedFile = named ? resolve(named) : join(mockupDir, 'docs', 'expected-diffs.json');
  let expected = null;
  if (named && !existsSync(expectedFile)) return { error: `--expected ${expectedFile} does not exist`, code: 2 };
  if (existsSync(expectedFile)) {
    try { expected = JSON.parse(readFileSync(expectedFile, 'utf8')); } catch (e) { return { error: `${expectedFile} is not valid JSON: ${e.message}`, code: 2 }; }
    const allViewports = config.viewports || [{ name: 'desktop', width: 1440, height: 900 }];
    const errors = validateExpected(expected, { viewports: allViewports, baseline });
    if (errors.length) return { error: `${expectedFile} is invalid:\n${errors.map((e) => `  ${e}`).join('\n')}`, code: 2 };
  }

  const run = parseRunArgs();
  if (run.error) return run;
  const { skip, workers, clock, seed } = run;
  const shard = has('shard') ? parseShard(opt('shard')) : null;
  if (shard && shard.error) return { error: shard.error, code: 2 };

  const rows = [], jobs = [];
  for (const { screen, state, vp, slug } of selectCases()) {
    const row = { slug, name: screen.name, state, viewport: vp.name, mismatchPercent: null };
    rows.push(row);
    if (skip && skip.test(screen.name || '')) { row.status = 'skipped'; continue; }
    if (!files.has(`${slug}.png`)) { row.status = 'no-baseline'; continue; }
    // A compared row starts as an error: only its judged capture can make it pass
    Object.assign(row, { status: 'error', error: 'not captured' });
    jobs.push({ row, screen, state, vp, file: join(baselineDir, `${slug}.png`) });
  }
  if (!rows.length && routeFiltered) return { error: 'no screen matches --route / --exclude-route and the other filters; nothing to compare', code: 2 };
  if (!rows.length) return { error: 'no screen, state and viewport matches the config and the --screen, --state and --viewport filters; nothing to compare', code: 2 };
  if (!jobs.length) return { error: `no screen matches a baseline PNG in ${baselineDir} (expected names like ${slugFor(config.screens[0] || { name: 'home' }, 'default', viewports[0]?.name || 'desktop')}.png); nothing to compare` };
  const cover = expected ? expectedCover(expected, allConfigCases()) : null;
  const plan = { baselineDir, expected, expectedFile: expected ? expectedFile : null, rows, jobs, workers, clock, seed, cover };
  if (!shard) return plan;
  // Every shard plans the whole run, keeps only its own names, and records the plan for the merge
  const names = planDiffShards(jobs.map((j) => ({ name: j.row.name, steps: j.screen.steps, png: j.file })), shard.n);
  const owner = {};
  names.forEach((set, i) => { for (const nm of set) owner[nm] = i + 1; });
  const planned = rows.map((r) => ({ slug: r.slug, name: r.name, state: r.state, viewport: r.viewport, status: r.status === 'error' ? 'compared' : r.status }));
  const mine = jobs.filter((j) => owner[j.row.name] === shard.k);
  return { ...plan, rows: mine.map((j) => j.row), jobs: mine, shard: { k: shard.k, n: shard.n, owner, planned, ...(cover ? { expectedCover: cover } : {}) } };
}

async function captureBaselineCase(browser, base, { screen, state, vp }, { clock, seed }) {
  const ctx = await newPinnedContext(browser, vp, { timezoneId, locale: configLocale(config), clock, seed });
  try {
    const page = await ctx.newPage();
    page.on('dialog', (d) => d.dismiss());
    await page.goto(mockupUrl(screen, state, { base }), { waitUntil: 'load' });
    await settle(page);
    await adoptStyle(page, FREEZE_CSS);
    await runSteps(page, screen.steps, { settleLayout: settleSteps });
    return await page.screenshot({ fullPage: true });
  } finally { await ctx.close(); }
}

async function runBaseline() {
  // The out folder is emptied below: never when it is the mockup, the cwd, home or a git root, or holds one
  const refusal = outDirRefusal(outDir, { mockupDir });
  if (refusal) { console.error(`error: ${refusal}; pass another --out`); return 2; }
  const plan = planBaseline();
  if (plan.error) { console.error(`error: ${plan.error}`); return plan.code ?? 1; }
  const { expected, expectedFile, rows, jobs, workers, clock, seed } = plan;
  // A mockup against its own stored PNGs is the same renderer: a js-kit's raised app tolerance
  // (diff.maxMismatchPercent) must not loosen it, so baseline mode has its own key and the app
  // limit only ever tightens it.
  const maxMismatchPercent = config.diff?.baselineMaxMismatchPercent ?? Math.min(config.diff?.maxMismatchPercent ?? 0.2, 0.2);
  console.log(`baseline: ${plan.baselineDir} · expected-diffs: ${expectedFile ? relative(process.cwd(), expectedFile) : 'none'} · ${jobs.length} cases to compare${clock ? ` · clock ${clock}` : ''}${seed !== null ? ` · seed ${seed}` : ''}${plan.shard ? ` · shard ${plan.shard.k}/${plan.shard.n}` : ''}`);

  rmSync(outDir, { recursive: true, force: true });
  mkdirSync(outDir, { recursive: true });
  const meta = { baseline: plan.baselineDir, expectedFile, expected, maxMismatchPercent, clock, seed, allowMissingBaseline };
  if (plan.shard && !jobs.length) {
    writeBaselineReport(outDir, rows, meta, { shard: plan.shard });
    console.log(`shard ${plan.shard.k}/${plan.shard.n}: nothing to capture\n-> ${relative(process.cwd(), outDir)}/report.md`);
    return 0;
  }
  await runCaptures(jobs, workers, async (browser, base, job) => {
    const { row } = job;
    try {
      const png = await captureBaselineCase(browser, base, job, { clock, seed });
      const r = compareImages({ baseline: readFileSync(job.file), actual: png, name: row.name, viewport: row.viewport, state: row.state, expected, maxMismatchPercent, pixelThreshold });
      delete row.error;
      Object.assign(row, { mismatchPercent: r.mismatchPercent, status: r.status }, r.size ? { size: r.size } : {}, r.compared ? { compared: r.compared } : {});
      const caseDir = join(outDir, row.slug);
      mkdirSync(caseDir, { recursive: true });
      writeFileSync(join(caseDir, 'capture.png'), png);
      if (r.diff) writeFileSync(join(caseDir, 'diff.png'), r.diff);
    } catch (e) {
      Object.assign(row, { status: 'error', error: String(e.message || e).split('\n')[0] });
    }
    if (row.status !== 'pass') console.log(`${row.status === 'expected' ? '~' : '✗'} ${row.slug}  ${row.mismatchPercent ?? row.status}${row.mismatchPercent !== null ? '%' : ''}${row.error ? ` ${row.error}` : ''}`);
  });

  // A shard sees only its share, so the unused entries are listed by the merge, never per shard
  const unused = expected && !plan.shard ? unusedEntries(expected, rows, { maxMismatchPercent, cover: plan.cover }) : null;
  const summary = writeBaselineReport(outDir, rows, meta, plan.shard ? { shard: plan.shard } : unused ? { unusedExpected: unused } : {});
  console.log(`\n${summary}`);
  // A shard's rows are its own captures only; the merge lists and judges the planned no-baseline cases
  for (const l of missingBaselineLines(rows, { allowMissingBaseline })) console.log(l);
  for (const l of formatUnused(unused || [], maxMismatchPercent)) console.log(l);
  console.log(`-> ${relative(process.cwd(), outDir)}/report.md`);
  return exitCodeFor(rows, { allowMissingBaseline });
}

/** --write-baseline: capture every selected case as --baseline would and store it under the name --baseline reads. */
async function runWriteBaseline() {
  const dir = resolve(writeArg);
  const run = parseRunArgs();
  if (run.error) { console.error(`error: ${run.error}`); return run.code; }
  const { skip, workers, clock, seed } = run;
  const cases = selectCases().filter((c) => !(skip && skip.test(c.screen.name || '')));
  const line = (list) => `baseline written: ${list.length} cases (${new Set(list.map((c) => c.screen.name || c.screen.route)).size} screens) -> ${dir}`;
  if (!cases.length) {
    console.error('error: no screen, state and viewport matches the filters; nothing to capture');
    console.log(line([]));
    return 2;
  }
  console.log(`write-baseline: ${cases.length} cases to capture${clock ? ` · clock ${clock}` : ''}${seed !== null ? ` · seed ${seed}` : ''}${timezoneId ? ` · tz ${timezoneId}` : ''}`);
  mkdirSync(dir, { recursive: true });
  const written = [];
  let failed = 0;
  await runCaptures(cases, workers, async (browser, base, c) => {
    try {
      writeFileSync(join(dir, `${c.slug}.png`), await captureBaselineCase(browser, base, c, { clock, seed }));
      written.push(c);
    } catch (e) {
      failed++;
      console.log(`✗ ${c.slug}  error ${String(e.message || e).split('\n')[0]}`);
    }
  });
  if (failed) console.log(`${failed} of ${cases.length} cases failed to capture`);
  console.log(line(written));
  return failed ? 1 : 0;
}

if (writeArg) process.exit(await runWriteBaseline());
if (baselineArg) process.exit(await runBaseline());

async function runApp() {
  const appPins = parsePins(pinArgs.clock, pinArgs.seed);
  if (appPins.error) { console.error(appPins.error); return 2; }
  // --expected in app mode: only when named, so a mockup's docs/expected-diffs.json written for baseline
  // runs never changes an app run silently
  let appExpected = null;
  const appExpectedFile = opt('expected') ? resolve(opt('expected')) : null;
  if (appExpectedFile) {
    if (!existsSync(appExpectedFile)) { console.error(`error: --expected ${appExpectedFile} does not exist`); return 2; }
    try { appExpected = JSON.parse(readFileSync(appExpectedFile, 'utf8')); } catch (e) { console.error(`error: ${appExpectedFile} is not valid JSON: ${e.message}`); return 2; }
    const allViewports = config.viewports || [{ name: 'desktop', width: 1440, height: 900 }];
    const allCases = config.screens.flatMap((sc) => (sc.states || ['default']).flatMap((st) => allViewports.map((v) => ({ name: sc.name, state: st, viewport: v.name }))));
    const errors = validateAppExpected(appExpected, { viewports: allViewports, cases: allCases });
    if (errors.length) { console.error(`error: ${appExpectedFile} is invalid:\n${errors.map((e) => `  ${e}`).join('\n')}`); return 2; }
    console.log(`expected-diffs: ${relative(process.cwd(), appExpectedFile)}`);
  }
  const shard = has('shard') ? parseShard(opt('shard')) : null;
  if (shard && shard.error) { console.error(`error: ${shard.error}`); return 2; }

  let selected = selectCases();
  // Checked on the whole plan, before a shard takes its share: a shard with no share still exits 0
  if (routeFiltered && !selected.length) { console.error('error: no screen matches --route / --exclude-route and the other filters; nothing to capture'); return 2; }
  if (!selected.length) { console.error('error: no screen, state and viewport matches the config and the --screen, --state and --viewport filters; nothing to capture'); return 2; }
  const cover = appExpected ? expectedCover(appExpected, allConfigCases()) : null;
  let shardPlan = null;
  if (shard) {
    // Every shard plans the whole run and records it, so the merge knows the cases of a shard that died
    const keys = planAppShards(selected.map((c) => ({ key: screenKey(c.screen), steps: c.screen.steps })), shard.n);
    const owner = {};
    keys.forEach((set, i) => { for (const key of set) owner[key] = i + 1; });
    const planned = selected.map(({ screen, state, vp, slug }) => ({ slug, key: screenKey(screen), name: screen.name, route: screen.route, role: screen.role, state, viewport: vp.name }));
    shardPlan = { k: shard.k, n: shard.n, owner, planned, ...(cover ? { expectedCover: cover } : {}) };
    selected = selected.filter((c) => owner[screenKey(c.screen)] === shard.k);
  }
  mkdirSync(outDir, { recursive: true });
  // A stale report from an earlier run must never merge as this shard's
  if (shard) rmSync(join(outDir, 'report.json'), { force: true });
  const meta = { appBase, maxMismatch, expectedFile: appExpectedFile };
  if (shard && !selected.length) {
    writeAppReport(outDir, [], meta, { shard: shardPlan });
    console.log(`shard ${shard.k}/${shard.n}: nothing to capture\n-> ${relative(process.cwd(), outDir)}/report.md`);
    return 0;
  }
  // The mockup is served over HTTP as baseline mode and check-behaviours serve it (lib/serve.mjs):
  // under file:// its fetch and localStorage behave otherwise, and a page that fetches its data breaks
  const { server, base } = await serveMockup(mockupDir);
  const browser = await chromium.launch();
  const cases = [];
  if (appPins.clock || appPins.seed !== null || shard) console.log(`app: ${appBase}${appPins.clock ? ` · clock ${appPins.clock}` : ''}${appPins.seed !== null ? ` · seed ${appPins.seed}` : ''}${shard ? ` · shard ${shard.k}/${shard.n} · ${selected.length} cases` : ''}`);

  try {
    for (const { screen, state, vp, slug } of selected) {
      const served = mockupUrl(screen, state, { base });
      // recorded relative to the mockup folder: the server's port changes every run
      const mUrl = served.slice(base.length + 1);
      const aUrl = appUrl(screen, state, appBase);
      const caseDir = join(outDir, slug);
      mkdirSync(caseDir, { recursive: true });
      // Pinned as baseline mode (--clock, --seed; both optional). The freeze stylesheet is inline, so
      // CSP is bypassed here; CSP is checked by quality-check.mjs, not here.
      const ctx = await newPinnedContext(browser, vp, { timezoneId, locale: configLocale(config), clock: appPins.clock, seed: appPins.seed });
      const page = await ctx.newPage();
      page.on('dialog', (d) => d.dismiss());

      const mock = await capture(page, served, screen.steps);
      const app = await capture(page, aUrl, appSteps(screen.steps));
      await ctx.close();

      const result = { slug, name: screen.name, route: screen.route, role: screen.role, state, viewport: vp.name, mockupUrl: mUrl, appUrl: aUrl };
      if (mock.error || app.error) {
        Object.assign(result, { error: mock.error || app.error, status: 'error', mismatchPercent: 100, pass: false });
        cases.push(result);
        console.log(`✗ ${slug}  ERROR ${result.error}`);
        continue;
      }

      const a = PNG.sync.read(mock.png);
      const b = PNG.sync.read(app.png);
      const width = Math.max(a.width, b.width);
      const height = Math.max(a.height, b.height);
      const pa = pad(a, width, height);
      const pb = pad(b, width, height);
      // Masks paint the decoded images only; the PNGs written below are the untouched captures
      if (appExpected) maskCases(pa, pb, appExpected, vp.name);
      const diff = new PNG({ width, height });
      const mismatched = pixelmatch(pa.data, pb.data, diff.data, width, height, { threshold: pixelThreshold, includeAA: false });
      const mismatchPercent = +((mismatched / (width * height)) * 100).toFixed(3);

      writeFileSync(join(caseDir, 'mockup.png'), mock.png);
      writeFileSync(join(caseDir, 'app.png'), app.png);
      writeFileSync(join(caseDir, 'diff.png'), PNG.sync.write(diff));

      const componentIssues = compareBoxes(mock.boxes, app.boxes);
      const status = appStatus(mismatchPercent, { expected: appExpected, name: screen.name, viewport: vp.name, state, maxMismatchPercent: maxMismatch });
      Object.assign(result, {
        mismatchPercent,
        status,
        pass: status !== 'fail',
        size: { mockup: `${a.width}x${a.height}`, app: `${b.width}x${b.height}` },
        componentIssues,
        files: { mockup: relative(outDir, join(caseDir, 'mockup.png')), app: relative(outDir, join(caseDir, 'app.png')), diff: relative(outDir, join(caseDir, 'diff.png')) },
      });
      cases.push(result);
      console.log(`${status === 'expected' ? '~' : result.pass ? '✓' : '✗'} ${slug}  ${mismatchPercent}%${componentIssues.length ? `  (${componentIssues.length} component issues)` : ''}`);
    }
  } finally {
    await browser.close();
    server.close();
  }

  // A shard sees only its share, so the unused entries are listed by the merge, never per shard
  const unused = appExpected && !shard ? unusedEntries(appExpected, cases, { maxMismatchPercent: maxMismatch, cover }) : null;
  const r = writeAppReport(outDir, cases, meta, shard ? { shard: shardPlan } : unused ? { unusedExpected: unused } : {});
  console.log(`\n${r.measured.line}`);
  for (const l of formatUnused(unused || [], maxMismatch)) console.log(l);
  console.log(`${r.passing} -> ${relative(process.cwd(), outDir)}/report.md`);
  return r.failed ? 1 : 0;
}

process.exit(await runApp());
