/**
 * diff-backlog.test.mjs: app-mode shard planning and merging (lib/shard.mjs planAppShards,
 * mergeAppShards, measuredLine), the merge-shards.mjs app CLI on synthetic shard reports, the route
 * filter (lib/screens.mjs routeSelected and the visual-diff CLI's refusals), and the unused
 * expected-diffs report (lib/expected-diffs.mjs expectedCover, unusedEntries, formatUnused). No
 * browser is launched.
 * Run: node --test test/diff-backlog.test.mjs   (from scripts/)
 */
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { measuredLine, mergeAppShards, planAppShards } from '../lib/shard.mjs';
import { routeSelected, screenKey, slugFor } from '../lib/screens.mjs';
import { expectedCover, formatUnused, unusedEntries } from '../lib/expected-diffs.mjs';
import { writeAppReport, writeBaselineReport } from '../lib/baseline-report.mjs';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/diff-app-shard', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'diff-backlog-'));
after(() => rmSync(TMP, { recursive: true, force: true }));
const reason = 'a reason';

// ---- App-mode shard planning and merge ----------------------------------------------------------

test('planAppShards: whole screens, balanced by cases and steps, every key once', () => {
  const jobs = [
    ...['default', 'empty'].map(() => ({ key: 'invoices', steps: [] })),
    { key: 'orders', steps: [{}, {}, {}, {}] }, // 1 + 2 = 3
    { key: 'home', steps: [] },
  ];
  const bins = planAppShards(jobs, 2);
  assert.equal(bins.length, 2);
  const all = bins.flatMap((b) => [...b]);
  assert.deepEqual(all.sort(), ['home', 'invoices', 'orders']);
  // orders (3) alone; invoices (2) and home (1) together
  assert.deepEqual(bins.map((b) => [...b].sort()), [['orders'], ['home', 'invoices']]);
  // more shards than screens: the extra shards are empty
  assert.deepEqual(planAppShards(jobs, 5).map((b) => b.size), [1, 1, 1, 0, 0]);
});

test('screenKey: the name, else the route made safe; nameless screens do not collapse into one key', () => {
  assert.equal(screenKey({ name: 'invoices', route: '/x' }), 'invoices');
  assert.equal(screenKey({ route: '/orders/INV-0412' }), 'orders_INV_0412');
  assert.notEqual(screenKey({ route: '/a' }), screenKey({ route: '/b' }));
  assert.equal(slugFor({ route: '/a' }, 'default', 'desktop'), 'a--default--desktop');
});

const planned = [
  { slug: 'a--default--desktop', key: 'a', name: 'a', route: '/a', state: 'default', viewport: 'desktop' },
  { slug: 'b--default--desktop', key: 'b', name: 'b', route: '/b', state: 'default', viewport: 'desktop' },
  { slug: 'c--default--desktop', key: 'c', name: 'c', route: '/c', state: 'default', viewport: 'desktop' },
];
const owner = { a: 1, b: 2, c: 2 };
const appCase = (name, mismatchPercent, status = 'pass') => ({
  slug: `${name}--default--desktop`, name, route: `/${name}`, state: 'default', viewport: 'desktop', mismatchPercent, status, pass: status !== 'fail',
  size: { mockup: '800x600', app: '800x600' }, componentIssues: [],
  files: { mockup: `${name}--default--desktop/mockup.png`, app: `${name}--default--desktop/app.png`, diff: `${name}--default--desktop/diff.png` },
});
const appReport = (k, n, cases, extra = {}) => ({ generatedAt: 'x', appBase: 'http://127.0.0.1:1', maxMismatch: 0.2, expectedFile: null, shard: { k, n, owner, planned }, cases, ...extra });

test('mergeAppShards: rows in plan order, files rewritten into the merged folder, a dead shard is an error per case', () => {
  const ok = mergeAppShards([
    { k: 1, dir: '/w/app-1', report: appReport(1, 2, [appCase('a', 0)]), code: 0 },
    { k: 2, dir: '/w/app-2', report: appReport(2, 2, [appCase('c', 0.1), appCase('b', 0)]), code: 0 },
  ], { outDir: '/w/app' });
  assert.deepEqual(ok.rows.map((r) => r.slug), planned.map((p) => p.slug));
  assert.equal(ok.rows[0].files.diff, '../app-1/a--default--desktop/diff.png');
  assert.equal(ok.rows[2].files.app, '../app-2/c--default--desktop/app.png');
  assert.deepEqual(ok.extra, []);
  assert.equal(ok.failedShards, 0);
  assert.equal(ok.meta.appBase, 'http://127.0.0.1:1');
  assert.equal(measuredLine(ok.rows).line, '3 of 3 planned captures measured, not measured: 0');

  const died = mergeAppShards([{ k: 1, report: appReport(1, 2, [appCase('a', 0)]), code: 0 }, { k: 2, report: null, code: 1 }]);
  assert.deepEqual(died.rows[1], { slug: 'b--default--desktop', name: 'b', route: '/b', state: 'default', viewport: 'desktop', error: 'no result from shard 2', status: 'error', mismatchPercent: 100, pass: false });
  assert.deepEqual(died.extra, ['shard 2: no report.json']);
  assert.equal(died.failedShards, 1);
  assert.equal(measuredLine(died.rows).line, '1 of 3 planned captures measured, not measured: 2');

  const crashed = mergeAppShards([{ k: 1, report: appReport(1, 2, [appCase('a', 0)]), code: 139 }, { k: 2, report: appReport(2, 2, [appCase('b', 0), appCase('c', 0)]), code: 0 }]);
  assert.deepEqual(crashed.extra, ['shard 1: exit 139 with no failed row']);
  assert.equal(crashed.failedShards, 1);

  // a shard that failed a case and exited 1 is not a dead shard
  const failing = mergeAppShards([{ k: 1, report: appReport(1, 2, [appCase('a', 3, 'fail')]), code: 1 }, { k: 2, report: appReport(2, 2, [appCase('b', 0), appCase('c', 0)]), code: 0 }]);
  assert.equal(failing.failedShards, 0);
});

test('mergeAppShards refuses shards that disagree on the plan or the app, or a baseline report', () => {
  assert.match(mergeAppShards([{ k: 1, report: null }, { k: 2, report: null }]).error, /no shard left a report/);
  assert.match(mergeAppShards([
    { k: 1, report: appReport(1, 2, []), code: 0 },
    { k: 2, report: appReport(2, 2, [], { appBase: 'http://other' }), code: 0 },
  ]).error, /planned a different run/);
  assert.match(mergeAppShards([{ k: 1, report: { ...appReport(1, 2, []), shard: undefined }, code: 0 }, { k: 2, report: null }]).error, /not written by a --shard run/);
  assert.match(mergeAppShards([{ k: 2, report: appReport(1, 2, []), code: 0 }, { k: 1, report: null }]).error, /is shard 1's/);
});

const merge = (...args) => spawnSync(process.execPath, ['merge-shards.mjs', ...args], { cwd: SCRIPTS, encoding: 'utf8', timeout: 20000 });

function writeShards(dir, shards) {
  rmSync(dir, { recursive: true, force: true });
  for (const [k, report, code] of shards) {
    mkdirSync(join(dir, `app-${k}`), { recursive: true });
    if (report) writeFileSync(join(dir, `app-${k}`, 'report.json'), JSON.stringify(report));
    if (code !== null) writeFileSync(join(dir, `app-${k}.code`), String(code));
  }
}

test('cli: merge-shards app writes the serial app report and states every planned capture was measured', () => {
  const dir = join(TMP, 'app');
  writeShards(dir, [[1, appReport(1, 2, [appCase('a', 0)]), 0], [2, appReport(2, 2, [appCase('b', 0), appCase('c', 0.1)]), 0]]);
  const r = merge('app', '--dir', dir, '--shards', '2');
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /^3 of 3 planned captures measured, not measured: 0$/m);
  assert.match(r.stdout, /^3\/3 passing -> /m);
  const rep = JSON.parse(readFileSync(join(dir, 'app', 'report.json'), 'utf8'));
  assert.deepEqual(Object.keys(rep).slice(0, 4), ['generatedAt', 'appBase', 'maxMismatch', 'expectedFile']);
  assert.equal(rep.measured, '3 of 3 planned captures measured, not measured: 0');
  assert.deepEqual(rep.cases.map((c) => c.slug), ['c--default--desktop', 'a--default--desktop', 'b--default--desktop']);
  const md = readFileSync(join(dir, 'app', 'report.md'), 'utf8');
  assert.match(md, /3\/3 passing/);
  assert.match(md, /3 of 3 planned captures measured/);
});

test('cli: merge-shards app fails when a shard died, left no exit status, or a capture was not measured', () => {
  const dir = join(TMP, 'app-dead');
  writeShards(dir, [[1, appReport(1, 2, [appCase('a', 0)]), 0], [2, null, 1]]);
  let r = merge('app', '--dir', dir, '--shards', '2');
  assert.equal(r.status, 1);
  assert.match(r.stdout, /shard 2: no report.json/);
  assert.match(r.stdout, /^1 of 3 planned captures measured, not measured: 2$/m);

  writeShards(dir, [[1, appReport(1, 2, [appCase('a', 0)]), null], [2, appReport(2, 2, [appCase('b', 0), appCase('c', 0)]), 0]]);
  r = merge('app', '--dir', dir, '--shards', '2');
  assert.equal(r.status, 1);
  assert.match(r.stdout, /shard 1: exit unknown with no failed row/);
  assert.match(r.stdout, /not measured: 0/);

  const errored = { ...appCase('b', 100, 'error'), error: 'page.goto: net::ERR_CONNECTION_REFUSED', pass: false };
  writeShards(dir, [[1, appReport(1, 2, [appCase('a', 0)]), 0], [2, appReport(2, 2, [errored, appCase('c', 0)]), 1]]);
  r = merge('app', '--dir', dir, '--shards', '2');
  assert.equal(r.status, 1);
  assert.match(r.stdout, /^2 of 3 planned captures measured, not measured: 1$/m);
  assert.doesNotMatch(r.stdout, /with no failed row/);
});

// ---- Route filter -------------------------------------------------------------------------------

test('routeSelected matches the route, falls back to the page, and applies the exclusion after', () => {
  const inv = { name: 'invoices', page: 'pages/invoices.html', route: '/invoices' };
  const pageOnly = { name: 'legacy', page: 'pages/legacy-orders.html' };
  assert.equal(routeSelected(inv), true);
  assert.equal(routeSelected(inv, { include: /^\/invoices/ }), true);
  assert.equal(routeSelected(inv, { include: /orders/ }), false);
  assert.equal(routeSelected(inv, { exclude: /invoices/ }), false);
  assert.equal(routeSelected(inv, { include: /invoices/, exclude: /^\/invoices$/ }), false);
  assert.equal(routeSelected(pageOnly, { include: /legacy-orders/ }), true);
  assert.equal(routeSelected(pageOnly, { exclude: /legacy/ }), false);
});

const vd = (args) => spawnSync(process.execPath, ['visual-diff.mjs', '--mockup', FIXTURE, ...args], { cwd: SCRIPTS, encoding: 'utf8', timeout: 20000 });

test('cli: an invalid --route or --exclude-route regex exits 2 in every mode, before any capture', () => {
  for (const mode of [['--app', 'http://127.0.0.1:1'], ['--baseline', TMP], ['--write-baseline', join(TMP, 'wb')]]) {
    for (const flag of ['--route', '--exclude-route']) {
      const r = vd([...mode, flag, '(', ...(mode[0] === '--write-baseline' ? [] : ['--out', join(TMP, 'out')])]);
      assert.equal(r.status, 2, `${mode[0]} ${flag}: ${r.stdout}${r.stderr}`);
      assert.match(r.stderr, new RegExp(`${flag} is not a valid regex`));
    }
  }
});

test('cli: a route filter that selects nothing exits 2 (could not run) before any capture, in every mode', () => {
  const app = vd(['--app', 'http://127.0.0.1:1', '--route', '^/nowhere', '--out', join(TMP, 'out')]);
  assert.equal(app.status, 2, app.stdout + app.stderr);
  assert.match(app.stderr, /no screen matches --route/);
  const both = vd(['--app', 'http://127.0.0.1:1', '--route', 'invoices', '--screen', 'orders', '--out', join(TMP, 'out')]);
  assert.equal(both.status, 2, 'the filters combine: --route invoices and --screen orders select nothing');
  const base = vd(['--baseline', TMP, '--exclude-route', '.', '--out', join(TMP, 'out')]);
  assert.equal(base.status, 2, base.stdout + base.stderr);
  assert.match(base.stderr, /no screen matches --route/);
  const baseScreen = vd(['--baseline', TMP, '--screen', 'nomatch', '--out', join(TMP, 'out')]);
  assert.equal(baseScreen.status, 2, baseScreen.stdout + baseScreen.stderr);
  assert.match(baseScreen.stderr, /nothing to compare/);
  const wb = vd(['--write-baseline', join(TMP, 'wb'), '--route', '^/nowhere']);
  assert.equal(wb.status, 2);
  assert.match(wb.stdout, /baseline written: 0 cases/);
});

test('cli: --shard is refused with --write-baseline, and a bad --shard in app mode exits 2 (a bad argument)', () => {
  assert.equal(vd(['--write-baseline', join(TMP, 'wb'), '--shard', '1/2']).status, 2);
  const r = vd(['--app', 'http://127.0.0.1:1', '--shard', '3/2', '--out', join(TMP, 'out')]);
  assert.equal(r.status, 2);
  assert.match(r.stderr, /--shard must be K\/N/);
});

test('cli: an app shard with nothing to capture writes the whole plan and exits 0 without a browser', () => {
  // two screens, three shards: shard 3 is empty
  const out = join(TMP, 'empty-shard');
  mkdirSync(out, { recursive: true });
  writeFileSync(join(out, 'report.json'), '{"stale":true}');
  const r = vd(['--app', 'http://127.0.0.1:1', '--shard', '3/3', '--out', out]);
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /shard 3\/3: nothing to capture/);
  const rep = JSON.parse(readFileSync(join(out, 'report.json'), 'utf8'));
  assert.equal(rep.stale, undefined);
  assert.deepEqual(rep.cases, []);
  assert.deepEqual(rep.shard.planned.map((p) => p.slug), ['invoices--default--desktop', 'orders--default--desktop']);
  assert.deepEqual(Object.values(rep.shard.owner).sort(), [1, 2]);
});

// ---- Unused expected-diffs entries --------------------------------------------------------------

const CASES = ['default', 'empty'].flatMap((state) => ['mobile', 'desktop'].map((viewport) => ({ slug: `home--${state}--${viewport}`, name: 'home', state, viewport })));
const row = (state, viewport, mismatchPercent, more = {}) => ({ slug: `home--${state}--${viewport}`, name: 'home', state, viewport, mismatchPercent, status: mismatchPercent === null ? 'error' : mismatchPercent > 0.2 ? 'expected' : 'pass', ...more });
const allRows = (pct) => CASES.map((c) => row(c.state, c.viewport, pct));

test('unusedEntries: an entry whose every case measured at or under the limit is not needed; one over it is', () => {
  const expected = { screens: [
    { name: 'home', viewport: 'desktop', maxMismatchPercent: 2, reason },
    { name: 'home', viewport: 'mobile', state: 'empty', maxMismatchPercent: 2, reason },
  ] };
  const cover = expectedCover(expected, CASES);
  assert.deepEqual(cover, [['home--default--desktop', 'home--empty--desktop'], ['home--empty--mobile']]);
  const rows = [row('default', 'desktop', 0.2), row('empty', 'desktop', 0.05), row('default', 'mobile', 0), row('empty', 'mobile', 1.4)];
  assert.deepEqual(unusedEntries(expected, rows, { maxMismatchPercent: 0.2, cover }), [
    { index: 0, name: 'home', viewport: 'desktop', why: 'at-or-under-limit', maxMeasured: 0.2, cases: 2 },
  ]);
  // an entry without a state is needed when any of its states is over the limit
  const over = [row('default', 'desktop', 0), row('empty', 'desktop', 0.9), row('empty', 'mobile', 0)];
  assert.deepEqual(unusedEntries(expected, over, { maxMismatchPercent: 0.2, cover }).map((u) => u.index), [1]);
});

test('unusedEntries: an entry is not judged when a case it covers was filtered out, skipped or not measured', () => {
  const expected = { screens: [{ name: 'home', viewport: '*', maxMismatchPercent: 2, reason }] };
  const cover = expectedCover(expected, CASES);
  const judge = (rows) => unusedEntries(expected, rows, { maxMismatchPercent: 0.2, cover });
  assert.equal(judge(allRows(0)).length, 1);
  assert.deepEqual(judge(allRows(0).slice(1)), [], 'one case filtered out of the run');
  assert.deepEqual(judge([...allRows(0).slice(1), { ...row('default', 'mobile', null), status: 'skipped' }]), []);
  assert.deepEqual(judge([...allRows(0).slice(1), row('default', 'mobile', null, { error: 'timeout' })]), []);
  // app mode: an error row carries mismatchPercent 100, and is still not measured
  assert.deepEqual(judge([...allRows(0).slice(1), row('default', 'mobile', 100, { error: 'timeout', status: 'error' })]), []);
  // a measured case over the limit decides it even when another was not measured
  assert.deepEqual(judge([row('default', 'mobile', 1.1), row('empty', 'mobile', 0)]), []);
});

test('unusedEntries: a size entry is needed while its capture is resized; an entry matching no config case is listed', () => {
  const expected = { screens: [
    { name: 'home', viewport: 'mobile', state: 'default', maxMismatchPercent: 1, size: { w: 390, h: 900 }, reason },
    { name: 'gone', viewport: 'desktop', maxMismatchPercent: 1, reason },
  ] };
  const cover = expectedCover(expected, CASES);
  const resized = [row('default', 'mobile', 0, { compared: '390x844' })];
  assert.deepEqual(unusedEntries(expected, resized, { cover }), [{ index: 1, name: 'gone', viewport: 'desktop', why: 'no-case' }]);
  const same = [row('default', 'mobile', 0)];
  assert.deepEqual(unusedEntries(expected, same, { cover }).map((u) => u.index), [0, 1]);
  assert.deepEqual(unusedEntries(null, same, { cover: [] }), []);
});

test('formatUnused: one warning line, then a line per entry; nothing when the list is empty', () => {
  assert.deepEqual(formatUnused([], 0.2), []);
  const lines = formatUnused([
    { index: 0, name: 'home', viewport: 'desktop', why: 'at-or-under-limit', maxMeasured: 0.05, cases: 2 },
    { index: 3, name: 'gone', viewport: 'mobile', state: 'empty', why: 'no-case' },
  ], 0.2);
  assert.deepEqual(lines, [
    'warning: 2 expected-diffs entries not needed (the exit status is unchanged):',
    '  screens[0] home at desktop (every state): measured at most 0.05% over 2 cases, at or under the 0.2% limit',
    '  screens[3] gone at mobile empty: matches no case in mockup.config.json',
  ]);
});

test('the report writers put the unused entries in report.json and report.md', () => {
  const unused = [{ index: 0, name: 'home', viewport: 'desktop', why: 'at-or-under-limit', maxMeasured: 0, cases: 1 }];
  const b = join(TMP, 'rep-baseline');
  mkdirSync(b, { recursive: true });
  writeBaselineReport(b, [row('default', 'desktop', 0)], { baseline: '/b', expectedFile: '/e.json', expected: { screens: [] }, maxMismatchPercent: 0.2 }, { unusedExpected: unused });
  assert.deepEqual(JSON.parse(readFileSync(join(b, 'report.json'), 'utf8')).unusedExpected, unused);
  assert.match(readFileSync(join(b, 'report.md'), 'utf8'), /## Expected-diffs entries not needed[\s\S]*- screens\[0\] home at desktop \(every state\): measured at most 0%/);
  const a = join(TMP, 'rep-app');
  mkdirSync(a, { recursive: true });
  const r = writeAppReport(a, [appCase('a', 0)], { appBase: 'http://x', maxMismatch: 0.2, expectedFile: join(a, 'e.json') }, { unusedExpected: unused });
  assert.equal(r.failed, 0);
  assert.equal(r.passing, '1/1 passing (0 expected, e.json)');
  assert.deepEqual(JSON.parse(readFileSync(join(a, 'report.json'), 'utf8')).unusedExpected, unused);
  assert.match(readFileSync(join(a, 'report.md'), 'utf8'), /## Expected-diffs entries not needed/);
  // no entries, no section
  writeAppReport(a, [appCase('a', 0)], { appBase: 'http://x', maxMismatch: 0.2, expectedFile: null });
  assert.doesNotMatch(readFileSync(join(a, 'report.md'), 'utf8'), /not needed/);
});

test('cli: merge-shards diff lists the unused entries from the merged rows, not per shard, and keeps exit 0', () => {
  const dir = join(TMP, 'diff-unused');
  const expectedFile = join(dir, 'expected.json');
  mkdirSync(dir, { recursive: true });
  // entry 0 covers a (one shard) and b (the other): only the merge sees both at 0%
  const expected = { screens: [{ name: 'a', viewport: 'desktop', maxMismatchPercent: 1, reason }, { name: 'b', viewport: 'desktop', maxMismatchPercent: 1, reason }] };
  writeFileSync(expectedFile, JSON.stringify(expected));
  const bPlanned = ['a', 'b'].map((name) => ({ slug: `${name}--default--desktop`, name, state: 'default', viewport: 'desktop', status: 'compared' }));
  const cover = [['a--default--desktop'], ['b--default--desktop']];
  const brow = (name, pct) => ({ slug: `${name}--default--desktop`, name, state: 'default', viewport: 'desktop', mismatchPercent: pct, status: pct > 0.2 ? 'expected' : 'pass' });
  for (const [k, cases] of [[1, [brow('a', 0)]], [2, [brow('b', 0.6)]]]) {
    mkdirSync(join(dir, `diff-${k}`), { recursive: true });
    writeFileSync(join(dir, `diff-${k}`, 'report.json'), JSON.stringify({ baseline: '/b', expected: expectedFile, maxMismatch: 0.2, clock: null, seed: null, shard: { k, n: 2, owner: { a: 1, b: 2 }, planned: bPlanned, expectedCover: cover }, cases }));
    writeFileSync(join(dir, `diff-${k}.code`), '0');
  }
  const r = merge('diff', '--dir', dir, '--shards', '2');
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /^warning: 1 expected-diffs entry not needed/m);
  assert.match(r.stdout, /^ {2}screens\[0\] a at desktop/m);
  assert.doesNotMatch(r.stdout, /screens\[1\]/);
  assert.equal(JSON.parse(readFileSync(join(dir, 'diff', 'report.json'), 'utf8')).unusedExpected.length, 1);
});

test('cli: merge-shards app lists the unused entries from the merged rows (cases from both shards) and keeps exit 0', () => {
  const dir = join(TMP, 'app-unused');
  const expectedFile = join(dir, 'expected.json');
  // entry 0 covers a (shard 1) and b (shard 2): only the merge sees both under the limit; entry 1
  // covers c, which is over the limit and needs it
  const cover = [['a--default--desktop', 'b--default--desktop'], ['c--default--desktop']];
  const rep = (k, cases) => ({ ...appReport(k, 2, cases), expectedFile, shard: { k, n: 2, owner, planned, expectedCover: cover } });
  writeShards(dir, [[1, rep(1, [appCase('a', 0)]), 0], [2, rep(2, [appCase('b', 0.1), appCase('c', 1.5, 'expected')]), 0]]);
  writeFileSync(expectedFile, JSON.stringify({ screens: [{ name: 'a', viewport: '*', maxMismatchPercent: 2, reason }, { name: 'c', viewport: 'desktop', maxMismatchPercent: 2, reason }] }));
  const r = merge('app', '--dir', dir, '--shards', '2');
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /^warning: 1 expected-diffs entry not needed \(the exit status is unchanged\):$/m);
  assert.match(r.stdout, /^ {2}screens\[0\] a at \* \(every state\): measured at most 0.1% over 2 cases, at or under the 0.2% limit$/m);
  assert.match(r.stdout, /^3\/3 passing \(1 expected, /m);
  const out = JSON.parse(readFileSync(join(dir, 'app', 'report.json'), 'utf8'));
  assert.deepEqual(out.unusedExpected.map((u) => u.index), [0]);
  assert.match(readFileSync(join(dir, 'app', 'report.md'), 'utf8'), /## Expected-diffs entries not needed/);
});
