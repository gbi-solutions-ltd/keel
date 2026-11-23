#!/usr/bin/env node
/**
 * dom-oracle.mjs: compare the mockup's DOM with a port's, case by case, before the pixel gate.
 * Where the visual diff points at a region, this points at a wrong attribute, a missing node or a
 * text difference by name. The normaliser and the diff are lib/dom-oracle.mjs (pure, tested).
 *
 * Case mode (the same cases as visual-diff.mjs app mode):
 *   node dom-oracle.mjs --mockup <mockup-dir> --app <base-url> [--out <dir>]
 *                       [--screen <name-substring>] [--state <name>] [--viewport <name>]
 *                       [--clock <iso-instant>] [--seed <int>] [--tz <zone>] [--root <selector>] [--app-root <selector>]
 *                       [--reference <report.json | out-dir>] [--drop-attributes <a,b,...>]
 *
 *   - Reads <mockup-dir>/mockup.config.json: every screen x state (filtered by --screen and --state)
 *     at one viewport, --viewport or else the config's "desktop", else its first. The DOM rarely
 *     changes with the viewport, so one is enough; pass --viewport to check another.
 *   - Each side is loaded as the gate loads it (the mockup served over HTTP from <mockup-dir> by
 *     lib/serve.mjs on a free port, the app at <base-url><route>; ?state, ?as,
 *     ?theme), pinned the same way (--clock, --seed, --tz, config.locale), settled, the screen's
 *     steps run, then <root> (default config.domOracle.root, else #app) innerHTML is read; on the app
 *     side <app-root> when given (--app-root, config.domOracle.appRoot), else the same root.
 *   - config.domOracle (optional): { root, dropAttributes, skipHiddenActions, skipHiddenIds }, see
 *     lib/dom-oracle.mjs. Put mockup-specific plumbing (hidden buttons the port does not draw) there.
 *     At Convert the config is signed off and read only: --drop-attributes adds names to its list
 *     for one run (in either mode), for a port that hashes class names or omits mk.js's data-*.
 *   - Writes <out>/<slug>/mockup.html, app.html, diff.txt (edge whitespace ignored) and, when edge
 *     whitespace differs, diff-strict.txt; plus <out>/report.md and <out>/report.json with, per case,
 *     diff lines, edge-only lines, line counts and diffHash (a hash of the changed lines, for
 *     --reference). Default out: <mockup-dir>/.mockup-engine/dom-oracle. The out folder is emptied
 *     first, so one that is or holds the mockup, the current folder, the home folder, a git root or a
 *     git repository is refused (exit 2; lib/baseline-report.mjs outDirRefusal, the rule visual-diff
 *     and gate-sharded.sh use); any other folder is allowed.
 *
 * Reference (--reference <previous report.json, or the out dir that holds it>): compares this run
 * with a previous one case by case, by slug. It is read and checked before anything else, so the
 * default out dir can be passed as its own reference (copy it first to keep it: this run replaces it).
 * A bad reference (missing, not JSON, no cases array, another viewport) exits 2 before any browser.
 *   - Verdict per case: worse (more diff lines; as many but a different diff, by diffHash, printed
 *     as "content changed"; or an error now and not before), better (fewer, or
 *     no error now after one before), same (equal, or an error both times), new (not in the
 *     reference), new-error (not in the reference, and an error now), missing (in the reference, no longer in the config at this viewport), not-run (in
 *     the config but filtered out by --screen / --state; no verdict). Classified on diff lines and
 *     their hash; the edge line delta is shown beside it. A reference written before hashes were
 *     stored is compared on diff line counts alone, with a note saying how many cases were.
 *   - Printed as a summary line and a line per case that is not same; written to report.json as
 *     `reference` ({ path, counts, cases: [{ slug, verdict, before, after, diffDelta, edgeDelta }] },
 *     before/after a diff line count or "error") and to report.md as an "Against the reference" table.
 *   - Exit code with --reference: 1 when any case is worse, new-error or missing, else 0, so differences the
 *     reference already had (known, listed ones) pass while any regression fails. 2 on bad arguments.
 *
 * File mode (two saved dumps, no browser):
 *   node dom-oracle.mjs --diff <mockup.html> <app.html> [--strict] [--config <mockup.config.json>] [--drop-attributes <a,b,...>]
 *   Prints the unified diff (edge whitespace ignored; --strict prints the strict one) and a summary.
 *   A case-mode flag (--mockup, --app, --out, --reference, --root, --app-root, the filters, the
 *   pins) is refused with --diff (exit 2), as --strict and --config are outside it.
 *
 * Counts: "diff lines" is removed plus added normalised lines with edge whitespace ignored, the
 * number to drive to zero apart from known, listed differences; "edge lines" is how many more a
 * strict comparison finds. Exit 0 when every case has 0 diff lines, 1 when any has more or a side
 * failed to load, 2 on bad arguments. With --reference, see Reference above.
 */
import './lib/browsers-env.mjs'; // first: playwright reads its browsers path when it loads
import { readFileSync, writeFileSync, mkdirSync, existsSync, rmSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { compare, compareWithReference, DEFAULT_OPTIONS, optionsFromConfig } from './lib/dom-oracle.mjs';
import { outDirRefusal } from './lib/baseline-report.mjs';
import { appSteps, appUrl, mockupUrl, runSteps, settle, slugFor } from './lib/screens.mjs';
import { newPinnedContext, parsePins } from './lib/pin.mjs';
import { configLocale, configZone, pinDefaults } from './lib/project.mjs';
import { serveMockup } from './lib/serve.mjs';
import { cli } from './lib/args.mjs';

const { values: flags, positional } = cli('dom-oracle');
const opt = (name, fallback) => flags[name] ?? fallback;
const fail = (msg) => { console.error(`error: ${msg}`); process.exit(2); };
/** --drop-attributes a,b: added to the config's list (and the defaults), so a port's own run can drop
 *  more of the mockup's plumbing without editing the signed-off config. */
function addDropped(options) {
  const v = flags['drop-attributes'];
  if (v === undefined) return;
  const names = String(v).split(',').map((x) => x.trim()).filter(Boolean);
  if (!names.length) fail('--drop-attributes takes attribute names, comma separated');
  options.dropAttributes = [...new Set([...(options.dropAttributes ?? DEFAULT_OPTIONS.dropAttributes), ...names])];
}

function loadConfig(path) {
  if (!existsSync(path)) fail(`missing ${path}`);
  try { return JSON.parse(readFileSync(path, 'utf8')); } catch (e) { return fail(`${path} is not valid JSON: ${e.message}`); }
}

/** A previous run's report: a report.json, or an out dir holding one. Exits 2 when unusable. */
function readReference(target) {
  if (!existsSync(target)) fail(`--reference ${target} does not exist`);
  const path = statSync(target).isDirectory() ? join(target, 'report.json') : target;
  if (!existsSync(path)) fail(`--reference ${target} holds no report.json`);
  let report;
  try { report = JSON.parse(readFileSync(path, 'utf8')); } catch (e) { return fail(`--reference ${path} is not valid JSON: ${e.message}`); }
  if (!report || !Array.isArray(report.cases) || report.cases.some((c) => !c || typeof c.slug !== 'string'))
    fail(`--reference ${path} is not a dom-oracle report (no cases array with a slug per case)`);
  return { path, report };
}

function summary(r) {
  return `# mockup ${r.mockupLines} lines, app ${r.appLines} lines, diff lines ${r.diffLines}, edge lines ${r.edgeLines}`;
}

// ---- File mode ----------------------------------------------------------------------------------

if (flags.diff) {
  // Case-mode flags do not apply to two saved files: refused, never ignored
  for (const f of ['mockup', 'app', 'out', 'reference', 'root', 'app-root', 'screen', 'state', 'viewport', 'clock', 'seed', 'tz']) if (flags[f] !== undefined) fail(`--${f} applies to case mode, not --diff`);
  const [a, b] = positional;
  if (positional.length !== 2) fail('--diff takes two files: --diff <mockup.html> <app.html>');
  for (const f of [a, b]) if (!existsSync(f)) fail(`missing ${f}`);
  const cfg = flags.config !== undefined ? optionsFromConfig(loadConfig(flags.config)) : { options: {} };
  if (cfg.error) fail(cfg.error);
  addDropped(cfg.options);
  const r = compare(readFileSync(a, 'utf8'), readFileSync(b, 'utf8'), cfg.options);
  const text = flags.strict ? r.strictDiff : r.diff;
  console.log(text || 'IDENTICAL');
  console.log(summary(r));
  process.exit(r.diffLines ? 1 : 0);
}

// ---- Case mode ----------------------------------------------------------------------------------

if (positional.length) fail(`unexpected argument ${positional[0]}: files are compared with --diff <mockup.html> <app.html>`);
for (const f of ['strict', 'config']) if (flags[f] !== undefined) fail(`--${f} applies to --diff only`);
const mockupDir = resolve(opt('mockup', '.'));
const appBase = (opt('app') || '').replace(/\/$/, '');
if (!appBase) fail('--app <base-url> is required (or --diff <mockup.html> <app.html>), e.g. --app http://localhost:5173');
const config = loadConfig(join(mockupDir, 'mockup.config.json'));
const cfg = optionsFromConfig(config);
if (cfg.error) fail(`mockup.config.json: ${cfg.error}`);
addDropped(cfg.options);
// A mockup link names a page file; the app's names a route. Each page's MK.page route template says
// which route the file is, so pages/my-requests.html and /loans/mine compare equal, and
// request-new.html?item=itm_08 and /equipment/itm_08/request do too.
cfg.options.pageRoutes = {};
for (const x of config.screens || []) {
  if (!x.page) continue;
  const file = x.page.split('?')[0];
  const abs = join(mockupDir, file);
  if (!existsSync(abs)) continue;
  const m = readFileSync(abs, 'utf8').match(/MK\.page\(\{[\s\S]*?\broute:\s*['"]([^'"]+)['"]/);
  if (m) cfg.options.pageRoutes[file.replace(/^pages\//, '').replace(/\.html$/, '')] = m[1];
}
const pinArgs = pinDefaults(config, opt('clock'), opt('seed'));
const pins = parsePins(pinArgs.clock, pinArgs.seed);
if (pins.error) fail(pins.error);
const root = opt('root') ?? cfg.root ?? '#app';
// The app's mount point when it differs from the mockup's (a React app on #root, the mockup on #app).
const appRoot = opt('app-root') ?? cfg.appRoot ?? root;
const allViewports = config.viewports || [{ name: 'desktop', width: 1440, height: 900 }];
const vpName = opt('viewport');
const vp = vpName ? allViewports.find((v) => v.name === vpName) : allViewports.find((v) => v.name === 'desktop') || allViewports[0];
if (!vp) fail(`no viewport named ${vpName} in mockup.config.json (${allViewports.map((v) => v.name).join(', ')})`);
const onlyScreen = opt('screen');
const onlyState = opt('state');
const outDir = resolve(opt('out', join(mockupDir, '.mockup-engine/dom-oracle')));
const outProblem = outDirRefusal(outDir, { mockupDir });
if (outProblem) fail(outProblem);
const pinned = { timezoneId: opt('tz') ?? configZone(config), locale: configLocale(config), clock: pins.clock, seed: pins.seed };

const cases = [];
const planned = []; // every slug the config gives at this viewport, before the filters
for (const screen of config.screens || []) {
  for (const state of screen.states || ['default']) {
    planned.push(slugFor(screen, state, vp.name));
    if (onlyScreen && !(screen.name || screen.route || screen.page || '').includes(onlyScreen)) continue;
    if (onlyState && state !== onlyState) continue;
    cases.push({ screen, state, slug: slugFor(screen, state, vp.name) });
  }
}
if (!cases.length) fail('no screen matches --screen / --state');
const reference = flags.reference !== undefined ? readReference(resolve(flags.reference)) : null;
if (reference?.report.viewport && reference.report.viewport !== vp.name)
  fail(`--reference ${reference.path} was run at viewport ${reference.report.viewport}, this run is at ${vp.name}: pass --viewport ${reference.report.viewport}`);

const { chromium } = await import('playwright');

async function dump(browser, url, steps, sel = root) {
  const ctx = await newPinnedContext(browser, vp, pinned);
  try {
    const page = await ctx.newPage();
    await page.goto(url, { waitUntil: 'load' });
    await settle(page);
    await runSteps(page, steps);
    const html = await page.evaluate((s) => document.querySelector(s)?.innerHTML ?? null, sel);
    if (html === null) return { error: `no ${sel} element` };
    return { html };
  } catch (e) {
    return { error: String(e.message || e).split('\n')[0] };
  } finally {
    await ctx.close();
  }
}

rmSync(outDir, { recursive: true, force: true });
mkdirSync(outDir, { recursive: true });
// Over HTTP, as visual-diff and check-behaviours load it: fetch and storage behave as in a browser.
const mockupServer = await serveMockup(mockupDir);
const browser = await chromium.launch();
const results = [];
try {
  for (const c of cases) {
    const mUrl = mockupUrl(c.screen, c.state, { base: mockupServer.base });
    const aUrl = appUrl(c.screen, c.state, appBase);
    const m = await dump(browser, mUrl, c.screen.steps);
    const a = await dump(browser, aUrl, appSteps(c.screen.steps), appRoot);
    const dir = join(outDir, c.slug);
    mkdirSync(dir, { recursive: true });
    const row = { slug: c.slug, screen: c.screen.name, state: c.state, mockupUrl: mUrl, appUrl: aUrl };
    if (m.html !== undefined) writeFileSync(join(dir, 'mockup.html'), m.html);
    if (a.html !== undefined) writeFileSync(join(dir, 'app.html'), a.html);
    if (m.error || a.error) {
      row.status = 'error';
      row.error = [m.error && `mockup: ${m.error}`, a.error && `app: ${a.error}`].filter(Boolean).join('; ');
    } else {
      const r = compare(m.html, a.html, cfg.options);
      Object.assign(row, { status: r.diffLines ? 'diff' : 'match', diffLines: r.diffLines, edgeLines: r.edgeLines, mockupLines: r.mockupLines, appLines: r.appLines, diffHash: r.diffHash });
      writeFileSync(join(dir, 'diff.txt'), (r.diff || 'IDENTICAL') + '\n' + summary(r) + '\n');
      if (r.edgeLines) writeFileSync(join(dir, 'diff-strict.txt'), r.strictDiff + '\n' + summary(r) + '\n');
    }
    results.push(row);
    console.log(`${row.status.padEnd(5)} ${c.slug}${row.status === 'error' ? `  ${row.error}` : `  diff ${row.diffLines}, edge ${row.edgeLines}`}`);
  }
} finally {
  await browser.close();
  mockupServer.server.close();
}

const counts = { match: 0, diff: 0, error: 0 };
for (const r of results) counts[r.status]++;
const report = { mockup: mockupDir, app: appBase, viewport: vp.name, root, clock: pins.clock ?? null, seed: pins.seed, counts, cases: results };
const against = reference ? compareWithReference(results, reference.report.cases, planned) : null;
const shown = (v) => (v === null ? '' : String(v));
const signed = (d) => (d === null ? '' : d > 0 ? `+${d}` : String(d));
const refSummary = against
  ? `against the reference: ${against.counts.worse} worse, ${against.counts.better} better, ${against.counts.same} same, ${against.counts.new} new, ${against.counts.missing} missing${against.counts['new-error'] ? `, ${against.counts['new-error']} new with an error` : ''}${against.counts['not-run'] ? `, ${against.counts['not-run']} not run` : ''}`
  : '';
if (against) report.reference = { path: reference.path, counts: against.counts, unhashed: against.unhashed, cases: against.cases };
writeFileSync(join(outDir, 'report.json'), JSON.stringify(report, null, 2) + '\n');
const md = [
  '# DOM oracle',
  '',
  `Mockup ${mockupDir}, app ${appBase}, viewport ${vp.name}, root ${root}${pins.clock ? `, clock ${pins.clock}` : ''}${pins.seed !== null ? `, seed ${pins.seed}` : ''}.`,
  '',
  `${counts.match} match, ${counts.diff} differ, ${counts.error} error, of ${results.length}. Diff lines ignore edge whitespace; edge lines are the extra a strict comparison finds.`,
  '',
  '| Case | Status | Diff lines | Edge lines | Mockup lines | App lines |',
  '|---|---|---|---|---|---|',
  ...results.map((r) => (r.status === 'error' ? `| ${r.slug} | error: ${r.error.replaceAll('|', '\\|')} | | | | |` : `| ${r.slug} | ${r.status} | ${r.diffLines} | ${r.edgeLines} | ${r.mockupLines} | ${r.appLines} |`)),
  '',
  ...(against
    ? [
        '## Against the reference',
        '',
        `Reference ${reference.path}: ${refSummary.replace('against the reference: ', '')}. Before and after are diff lines; worse, new-error or missing fails the run.`,
        '',
        '| Case | Verdict | Before | After | Diff delta | Edge delta |',
        '|---|---|---|---|---|---|',
        ...against.cases.map((c) => `| ${c.slug} | ${c.verdict}${c.contentChanged ? ' (content changed)' : ''} | ${shown(c.before)} | ${shown(c.after)} | ${signed(c.diffDelta)} | ${signed(c.edgeDelta)} |`),
        '',
      ]
    : []),
];
writeFileSync(join(outDir, 'report.md'), md.join('\n'));
console.log(`\n${counts.match} match, ${counts.diff} differ, ${counts.error} error. Report: ${join(outDir, 'report.md')}`);
if (against) {
  for (const c of against.cases.filter((x) => x.verdict !== 'same'))
    console.log(`${c.verdict.padEnd(7)} ${c.slug}  ${shown(c.before) || '-'} -> ${shown(c.after) || '-'}${c.diffDelta !== null ? ` (diff ${signed(c.diffDelta)}, edge ${signed(c.edgeDelta)}${c.contentChanged ? ', content changed' : ''})` : ''}`);
  if (against.unhashed) console.log(`note: ${against.unhashed} case(s) compared on diff line counts only: the reference has no diff hash for them (written before hashes were stored)`);
  console.log(refSummary);
  process.exit(against.counts.worse || against.counts['new-error'] || against.counts.missing ? 1 : 0);
}
process.exit(counts.diff || counts.error ? 1 : 0);
