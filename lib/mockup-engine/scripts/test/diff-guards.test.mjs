/**
 * diff-guards.test.mjs: the refusals of visual-diff.mjs and merge-shards.mjs that come before any
 * capture, and the shard merges' judgement on synthetic reports. No browser is launched.
 *   - an app-mode selection that matches nothing, and an app merge with nothing planned, exit 1
 *   - lib/screens.mjs screenProblems: duplicate viewports, colliding slugs, a screen with no route
 *     in app mode (exit 2 before any capture)
 *   - an --out that is, or contains, the mockup, the cwd, a git root or the home folder is refused
 *     (exit 2) and nothing is deleted
 *   - no-baseline cases fail unless --allow-missing-baseline, serial and merged
 *   - a truncated shard report.json is "unreadable", not a crash; mergeDiffShards counts a shard
 *     with no report in failedShards
 * Run: node --test test/diff-guards.test.mjs   (from scripts/)
 */
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PNG } from 'pngjs';
// namespace imports, so a missing export fails its own tests rather than the whole file
import * as screens from '../lib/screens.mjs';
import * as report from '../lib/baseline-report.mjs';
import * as expectedDiffs from '../lib/expected-diffs.mjs';
import { mergeAppShards, mergeDiffShards } from '../lib/shard.mjs';

const screenProblems = (...a) => screens.screenProblems(...a);
const outDirRefusal = (...a) => report.outDirRefusal(...a);
const exitCodeFor = (...a) => expectedDiffs.exitCodeFor(...a);
const missingBaselineLines = (...a) => expectedDiffs.missingBaselineLines(...a);

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/diff-app-shard', import.meta.url));
const TMP = realpathSync(mkdtempSync(join(tmpdir(), 'diff-guards-')));
after(() => rmSync(TMP, { recursive: true, force: true }));

const run = (script, args, opts = {}) => spawnSync(process.execPath, [join(SCRIPTS, script), ...args], { cwd: SCRIPTS, encoding: 'utf8', timeout: 60000, ...opts });
const vd = (mockup, args, opts) => run('visual-diff.mjs', ['--mockup', mockup, ...args], opts);
const NOWHERE = 'http://127.0.0.1:9';

/** A copy of the app-shard fixture, with its config changed by edit. */
function mockup(name, edit = (c) => c) {
  const dir = join(TMP, name);
  cpSync(FIXTURE, dir, { recursive: true });
  const file = join(dir, 'mockup.config.json');
  writeFileSync(file, JSON.stringify(edit(JSON.parse(readFileSync(file, 'utf8')))));
  return dir;
}
function pngDir(name, slugs) {
  const dir = join(TMP, name);
  mkdirSync(dir, { recursive: true });
  const img = new PNG({ width: 4, height: 4 });
  img.data.fill(255);
  for (const s of slugs) writeFileSync(join(dir, `${s}.png`), PNG.sync.write(img));
  return dir;
}

// ---- A4: an empty selection in app mode ----------------------------------------------------------

test('app mode: --screen or --viewport that matches nothing exits 2 (could not run) before any capture', () => {
  const m = mockup('a4');
  for (const filter of [['--screen', 'nomatch'], ['--viewport', 'tablet'], ['--state', 'nomatch'], ['--screen', 'nomatch', '--shard', '1/2']]) {
    const r = vd(m, ['--app', NOWHERE, ...filter, '--out', join(TMP, 'a4-out')]);
    assert.equal(r.status, 2, `${filter.join(' ')}: ${r.stdout}${r.stderr}`);
    assert.match(r.stderr, /nothing to capture/, filter.join(' '));
    assert.doesNotMatch(r.stdout, /0\/0 passing/, filter.join(' '));
  }
});

const appReport = (k, n, planned, owner, cases = []) => ({ generatedAt: 'x', appBase: 'http://a', maxMismatch: 0.2, expectedFile: null, shard: { k, n, owner, planned }, measured: '', cases });

test('mergeAppShards: a plan with no case is an error, not 0 of 0 passing', () => {
  const m = mergeAppShards([{ k: 1, report: appReport(1, 2, [], {}), code: 0 }, { k: 2, report: appReport(2, 2, [], {}), code: 0 }]);
  assert.match(m.error ?? '', /planned no case/);
});

test('cli: merge-shards app with nothing planned exits 2 (nothing to merge)', () => {
  const dir = join(TMP, 'app-empty');
  for (const k of [1, 2]) {
    mkdirSync(join(dir, `app-${k}`), { recursive: true });
    writeFileSync(join(dir, `app-${k}`, 'report.json'), JSON.stringify(appReport(k, 2, [], {})));
    writeFileSync(join(dir, `app-${k}.code`), '0');
  }
  const r = run('merge-shards.mjs', ['app', '--dir', dir, '--shards', '2']);
  assert.equal(r.status, 2, r.stdout + r.stderr);
  assert.match(r.stderr, /planned no case/);
});

// ---- B7: screen and viewport names --------------------------------------------------------------

test('screenProblems: the fixture and a plain config have none', () => {
  const config = JSON.parse(readFileSync(join(FIXTURE, 'mockup.config.json'), 'utf8'));
  assert.deepEqual(screenProblems(config), []);
  assert.deepEqual(screenProblems(config, { app: true }), []);
  assert.deepEqual(screenProblems({ screens: [{ page: 'a.html', route: '/a' }] }), []);
});

test('screenProblems: duplicate viewports, screen names, slugs and states, and a screen with neither name nor route', () => {
  const vp = { name: 'desktop', width: 800, height: 600 };
  assert.deepEqual(screenProblems({ viewports: [vp, { ...vp, width: 1440 }], screens: [{ name: 'a', page: 'a.html', route: '/a' }] }), ['viewports[1]: name desktop is also viewports[0]\'s (their PNGs and case folders would collide)']);
  assert.deepEqual(screenProblems({ screens: [{ name: 'a', page: 'a.html', route: '/a' }, { name: 'a', page: 'b.html', route: '/b' }] }), ['screens[1]: name a is also screens[0]\'s (their PNGs and case folders would collide)']);
  // a screen with no name takes its key from its route
  assert.deepEqual(screenProblems({ screens: [{ name: 'orders', page: 'a.html', route: '/a' }, { page: 'b.html', route: '/orders' }] }), ['screens[1]: name orders (from its route) is also screens[0]\'s (their PNGs and case folders would collide)']);
  assert.deepEqual(screenProblems({ screens: [{ name: 'a', page: 'a.html', route: '/a', states: ['default', 'empty', 'empty'] }] }), ['screens[0] a: state empty is listed twice']);
  // two different keys can still give one slug through the -- separator
  assert.deepEqual(screenProblems({ screens: [{ name: 'a--x', page: 'a.html', route: '/a' , states: ['y'] }, { name: 'a', page: 'b.html', route: '/b', states: ['x--y'] }] }), ['screens[1] a: slug a--x--y--desktop is also screens[0]\'s']);
  assert.deepEqual(screenProblems({ screens: [{ page: 'a.html' }] }), ['screens[0]: neither name nor route, so it has no slug']);
});

test('screenProblems: a screen with no route is refused in app mode only', () => {
  const config = { screens: [{ name: 'a', page: 'a.html' }] };
  assert.deepEqual(screenProblems(config), []);
  assert.deepEqual(screenProblems(config, { app: true }), ['screens[0] a: no route, which app mode needs']);
});

test('cli: duplicate names exit 2 before any capture in every mode; a missing route only in app mode', () => {
  const dupVp = mockup('b7-vp', (c) => ({ ...c, viewports: [...c.viewports, c.viewports[0]] }));
  const png = pngDir('b7-png', ['invoices--default--desktop']);
  for (const args of [['--app', NOWHERE], ['--baseline', png], ['--write-baseline', join(TMP, 'b7-write')]]) {
    const r = vd(dupVp, [...args, ...(args[0] === '--write-baseline' ? [] : ['--out', join(TMP, 'b7-out')])]);
    assert.equal(r.status, 2, `${args[0]}: ${r.stdout}${r.stderr}`);
    assert.match(r.stderr, /viewports\[1\]: name desktop is also viewports\[0\]'s/);
  }
  assert.equal(existsSync(join(TMP, 'b7-write')), false, 'nothing written');
  const noRoute = mockup('b7-route', (c) => ({ ...c, screens: c.screens.map(({ route: _r, ...s }) => s) }));
  const app = vd(noRoute, ['--app', NOWHERE, '--out', join(TMP, 'b7-out')]);
  assert.equal(app.status, 2, app.stdout + app.stderr);
  assert.match(app.stderr, /screens\[0\] invoices: no route, which app mode needs/);
  // baseline mode has no use for a route: it goes on to its own check (no PNG matches)
  const base = vd(noRoute, ['--baseline', pngDir('b7-none', [])]);
  assert.equal(base.status, 1, base.stdout + base.stderr);
  assert.match(base.stderr, /no screen matches a baseline PNG/);
});

// ---- B8: an --out that would delete the wrong folder --------------------------------------------

test('outDirRefusal: the mockup, the cwd, home, a git root and their parents are refused; any other folder is not', () => {
  const root = join(TMP, 'b8-unit');
  const m = join(root, 'work', 'mockup');
  const repo = join(root, 'repo');
  mkdirSync(m, { recursive: true });
  mkdirSync(join(repo, '.git'), { recursive: true });
  mkdirSync(join(repo, 'sub', 'mockup'), { recursive: true });
  const ctx = { mockupDir: m, cwd: join(root, 'work'), home: join(root, 'home') };
  mkdirSync(ctx.home, { recursive: true });
  assert.match(outDirRefusal(m, ctx), /is the mockup folder/);
  assert.match(outDirRefusal(join(root, 'work'), ctx), /is the current folder/);
  assert.match(outDirRefusal(root, ctx), /contains the mockup folder/);
  assert.match(outDirRefusal(ctx.home, ctx), /is the home folder/);
  assert.match(outDirRefusal(repo, { ...ctx, mockupDir: join(repo, 'sub', 'mockup') }), /is a git root/);
  // a git root found above the mockup is refused, as is any folder holding one
  assert.match(outDirRefusal(join(repo, 'sub'), { ...ctx, mockupDir: join(repo, 'sub', 'mockup'), cwd: root }), /contains the mockup folder/);
  // an earlier run's folder, full of case folders, is fine; so is one that does not exist yet
  const earlier = join(m, '.mockup-engine', 'baseline-diff');
  mkdirSync(join(earlier, 'home--default--desktop'), { recursive: true });
  writeFileSync(join(earlier, 'report.json'), '{}');
  assert.equal(outDirRefusal(earlier, ctx), null);
  assert.equal(outDirRefusal(join(root, 'elsewhere', 'new'), ctx), null);
});

test('cli: baseline mode refuses an --out that is or contains the mockup or the cwd, and deletes nothing', () => {
  const m = mockup('b8');
  const png = pngDir('b8-png', ['invoices--default--desktop', 'orders--default--desktop']);
  const ok = join(TMP, 'b8-expected.json');
  writeFileSync(ok, JSON.stringify({ rules: [], screens: [] }));
  for (const [out, why] of [[m, /is the mockup folder/], [TMP, /contains the mockup folder/], ['.', /is the current folder/]]) {
    const r = vd(m, ['--baseline', png, '--expected', ok, '--out', out], { cwd: join(TMP, 'b8-png') });
    assert.equal(r.status, 2, `${out}: ${r.stdout}${r.stderr}`);
    assert.match(r.stderr, why);
    assert.ok(existsSync(join(m, 'mockup.config.json')), 'the mockup is still there');
    assert.ok(existsSync(join(png, 'orders--default--desktop.png')), 'the cwd is still there');
  }
});

// ---- A11: a case with no baseline PNG -----------------------------------------------------------

test('exitCodeFor: a no-baseline row fails unless missing baselines are allowed', () => {
  const rows = [{ slug: 'a--default--desktop', status: 'pass', mismatchPercent: 0 }, { slug: 'b--default--desktop', status: 'no-baseline', mismatchPercent: null }];
  assert.equal(exitCodeFor(rows), 1);
  assert.equal(exitCodeFor(rows, { allowMissingBaseline: true }), 0);
  assert.equal(exitCodeFor([{ status: 'no-baseline', mismatchPercent: null }], { allowMissingBaseline: true }), 1, 'nothing compared still fails');
  assert.deepEqual(missingBaselineLines(rows), ['error: 1 case has no baseline PNG (write it with --write-baseline, or pass --allow-missing-baseline to list it without failing):', '  b--default--desktop']);
  assert.deepEqual(missingBaselineLines(rows, { allowMissingBaseline: true }), ['warning: 1 case has no baseline PNG and was not compared (--allow-missing-baseline):', '  b--default--desktop']);
  assert.deepEqual(missingBaselineLines(rows.slice(0, 1)), []);
});

test('cli: --allow-missing-baseline is refused outside baseline mode', () => {
  const m = mockup('a11-flag');
  for (const args of [['--app', NOWHERE], ['--write-baseline', join(TMP, 'a11-w')]]) {
    const r = vd(m, [...args, '--allow-missing-baseline']);
    assert.equal(r.status, 2, `${args[0]}: ${r.stdout}${r.stderr}`);
    assert.match(r.stderr, /--allow-missing-baseline applies to --baseline mode/);
  }
});

const diffReport = (k, n, owner, planned, cases, extra = {}) => ({ generatedAt: 'x', baseline: '/b', expected: null, maxMismatch: 0.2, clock: null, seed: null, ...extra, shard: { k, n, owner, planned }, summary: 's', cases });
const planned = [
  { slug: 'a--default--desktop', name: 'a', state: 'default', viewport: 'desktop', status: 'compared' },
  { slug: 'c--default--desktop', name: 'c', state: 'default', viewport: 'desktop', status: 'no-baseline' },
];
const passRow = { slug: 'a--default--desktop', name: 'a', state: 'default', viewport: 'desktop', mismatchPercent: 0, status: 'pass' };

function diffShards(name, extra) {
  const dir = join(TMP, name);
  for (const k of [1, 2]) {
    mkdirSync(join(dir, `diff-${k}`), { recursive: true });
    writeFileSync(join(dir, `diff-${k}`, 'report.json'), JSON.stringify(diffReport(k, 2, { a: 1 }, planned, k === 1 ? [passRow] : [], extra)));
    writeFileSync(join(dir, `diff-${k}.code`), '0');
  }
  return dir;
}

test('cli: merge-shards diff fails on a no-baseline case unless the shards ran with --allow-missing-baseline, and lists it', () => {
  let r = run('merge-shards.mjs', ['diff', '--dir', diffShards('a11-strict', {}), '--shards', '2']);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stdout, /^error: 1 case has no baseline PNG/m);
  assert.match(r.stdout, /^ {2}c--default--desktop$/m);
  r = run('merge-shards.mjs', ['diff', '--dir', diffShards('a11-allowed', { allowMissingBaseline: true }), '--shards', '2']);
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /^warning: 1 case has no baseline PNG and was not compared/m);
  assert.match(r.stdout, /^ {2}c--default--desktop$/m);
});

test('mergeDiffShards: shards that disagree on --allow-missing-baseline do not merge', () => {
  const m = mergeDiffShards([
    { k: 1, report: diffReport(1, 2, { a: 1 }, planned, [passRow], { allowMissingBaseline: true }), code: 0 },
    { k: 2, report: diffReport(2, 2, { a: 1 }, planned, []), code: 0 },
  ]);
  assert.match(m.error ?? '', /planned a different run/);
});

// ---- B12: truncated shard reports, and the failedShards count -----------------------------------

test('mergeDiffShards: a shard that owned cases and left no report counts in failedShards', () => {
  const m = mergeDiffShards([{ k: 1, report: null, code: 1 }, { k: 2, report: diffReport(2, 2, { a: 1 }, planned, []), code: 0 }]);
  assert.equal(m.failedShards, 1);
  assert.deepEqual(m.extra, ['shard 1: no report.json']);
});

test('cli: a truncated report.json is "shard K: report.json unreadable", not a crash, in every merge; none readable exits 2', () => {
  for (const [cmd, prefix] of [['diff', 'diff'], ['app', 'app'], ['quality', 'quality']]) {
    const dir = join(TMP, `b12-${cmd}`);
    mkdirSync(join(dir, `${prefix}-1`), { recursive: true });
    mkdirSync(join(dir, `${prefix}-2`), { recursive: true });
    writeFileSync(join(dir, `${prefix}-1`, 'report.json'), '{"generatedAt": "x", "cas');
    writeFileSync(join(dir, `${prefix}-2`, 'report.json'), '');
    for (const k of [1, 2]) writeFileSync(join(dir, `${prefix}-${k}.code`), '1');
    const r = run('merge-shards.mjs', [cmd, '--dir', dir, '--shards', '2']);
    assert.equal(r.status, 2, `${cmd}: ${r.stdout}${r.stderr}`);
    assert.match(r.stdout + r.stderr, /shard 1: report\.json unreadable/, cmd);
    assert.doesNotMatch(r.stderr, /SyntaxError|at JSON\.parse/, `${cmd}: no stack trace`);
  }
});

test('cli: an unreadable report fails the merge even when the other shards agree and pass', () => {
  const dir = diffShards('b12-one', { allowMissingBaseline: true });
  writeFileSync(join(dir, 'diff-2', 'report.json'), '{');
  const r = run('merge-shards.mjs', ['diff', '--dir', dir, '--shards', '2']);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stdout, /^shard 2: report\.json unreadable/m);
});

test('cli: merge-shards behaviours with a behaviours file that is not JSON, or missing, exits 2 with a message, not a stack trace', () => {
  const dir = join(TMP, 'beh-bad');
  mkdirSync(join(dir, 'm', 'docs'), { recursive: true });
  writeFileSync(join(dir, 'm', 'docs', 'behaviours.json'), '[{ "id": ');
  const r = run('merge-shards.mjs', ['behaviours', '--dir', dir, '--shards', '1', '--mockup', join(dir, 'm')]);
  assert.equal(r.status, 2, r.stdout + r.stderr);
  assert.match(r.stderr, /behaviours\.json is not valid JSON/);
  assert.doesNotMatch(r.stderr, /at JSON\.parse/);
  const gone = run('merge-shards.mjs', ['behaviours', '--dir', dir, '--shards', '1', '--mockup', join(dir, 'nowhere')]);
  assert.equal(gone.status, 2, gone.stdout + gone.stderr);
  assert.match(gone.stderr, /behaviours\.json does not exist/);
  // a bad --shards or no subcommand is a usage error with its reason
  const bad = run('merge-shards.mjs', ['behaviours', '--dir', dir, '--shards', '0']);
  assert.equal(bad.status, 2);
  assert.match(bad.stderr, /^merge-shards: --shards 0: want an integer >= 1\nusage: /);
  const sub = run('merge-shards.mjs', ['nope', '--dir', dir, '--shards', '1']);
  assert.match(sub.stderr, /^merge-shards: unknown subcommand nope: want behaviours, diff, app or quality\nusage: /);
  const noDir = run('merge-shards.mjs', ['diff', '--shards', '1']);
  assert.match(noDir.stderr, /^merge-shards: --dir is required\nusage: /);
});
