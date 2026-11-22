/**
 * visual-diff.test.mjs: the baseline mode's judgement (lib/expected-diffs.mjs) on generated PNGs,
 * and the CLI's refusals that happen before any browser starts. No browser is launched.
 * Run: node --test test/visual-diff.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PNG } from 'pngjs';
import { appStatus, compareImages, exitCodeFor, maskCases, parseBaselineName, summarise, validateAppExpected, validateExpected, MAX_PERCENT_CAP } from '../lib/expected-diffs.mjs';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/visual-diff', import.meta.url));
const VIEWPORTS = [{ name: 'mobile', width: 390, height: 844 }, { name: 'desktop', width: 1440, height: 900 }];
const BASELINE = [
  { name: 'home', state: 'default', viewport: 'mobile' },
  { name: 'home', state: 'default', viewport: 'desktop' },
  { name: 'home', state: 'empty', viewport: 'desktop' },
];

/** A white w x h PNG with the given rectangles painted black. */
function png(w, h, rects = []) {
  const img = new PNG({ width: w, height: h });
  img.data.fill(255);
  for (const { x, y, w: rw, h: rh } of rects) {
    for (let yy = y; yy < y + rh; yy++) for (let xx = x; xx < x + rw; xx++) img.data.set([0, 0, 0, 255], (yy * w + xx) * 4);
  }
  return PNG.sync.write(img);
}

const base = { name: 'home', viewport: 'desktop', state: 'default', maxMismatchPercent: 0.2, pixelThreshold: 0.1 };
const reason = 'a reason';

test('identical images pass at 0%', () => {
  const r = compareImages({ ...base, baseline: png(100, 100), actual: png(100, 100) });
  assert.equal(r.mismatchPercent, 0);
  assert.equal(r.status, 'pass');
  assert.equal(r.diff, null);
});

test('a difference over the config limit fails and returns a diff image', () => {
  // 10 x 10 of 100 x 100 = 1%
  const r = compareImages({ ...base, baseline: png(100, 100), actual: png(100, 100, [{ x: 0, y: 0, w: 10, h: 10 }]) });
  assert.equal(r.mismatchPercent, 1);
  assert.equal(r.status, 'fail');
  assert.ok(Buffer.isBuffer(r.diff));
});

test('a difference under the config limit passes', () => {
  // 1 x 1 of 100 x 100 = 0.01%
  const r = compareImages({ ...base, baseline: png(100, 100), actual: png(100, 100, [{ x: 50, y: 50, w: 1, h: 1 }]) });
  assert.equal(r.mismatchPercent, 0.01);
  assert.equal(r.status, 'pass');
});

test('a screens entry turns an over-limit difference into expected, and only up to its own limit', () => {
  const actual = png(100, 100, [{ x: 0, y: 0, w: 10, h: 10 }]); // 1%
  const ok = { rules: [], screens: [{ name: 'home', viewport: 'desktop', maxMismatchPercent: 1.5, reason }] };
  assert.equal(compareImages({ ...base, baseline: png(100, 100), actual, expected: ok }).status, 'expected');
  const tight = { rules: [], screens: [{ name: 'home', viewport: 'desktop', maxMismatchPercent: 0.5, reason }] };
  assert.equal(compareImages({ ...base, baseline: png(100, 100), actual, expected: tight }).status, 'fail');
  const otherState = { rules: [], screens: [{ name: 'home', viewport: 'desktop', state: 'empty', maxMismatchPercent: 1.5, reason }] };
  assert.equal(compareImages({ ...base, baseline: png(100, 100), actual, expected: otherState }).status, 'fail');
});

test('a mask over the difference makes it pass, on its viewport only', () => {
  const actual = png(100, 100, [{ x: 0, y: 0, w: 10, h: 10 }]);
  const expected = { rules: [{ viewport: 'desktop', mask: { x: 0, y: 0, w: 20, h: 20 }, reason }], screens: [] };
  assert.equal(compareImages({ ...base, baseline: png(100, 100), actual, expected }).mismatchPercent, 0);
  assert.equal(compareImages({ ...base, viewport: 'mobile', baseline: png(100, 100), actual, expected }).status, 'fail');
  const star = { rules: [{ viewport: '*', mask: { x: 0, y: 0, w: 20, h: 20 }, reason }], screens: [] };
  assert.equal(compareImages({ ...base, viewport: 'mobile', baseline: png(100, 100), actual, expected: star }).status, 'pass');
});

test('a size change is size-mismatch unless declared, and a declared size is compared over the common region', () => {
  const baseline = png(100, 100);
  const taller = png(100, 120, [{ x: 0, y: 100, w: 100, h: 20 }]); // the extra rows differ, the common region does not
  assert.equal(compareImages({ ...base, baseline, actual: taller }).status, 'size-mismatch');
  const declared = { rules: [], screens: [{ name: 'home', viewport: 'desktop', maxMismatchPercent: 1, size: { w: 100, h: 120 }, reason }] };
  const r = compareImages({ ...base, baseline, actual: taller, expected: declared });
  assert.equal(r.status, 'pass');
  assert.equal(r.compared, '100x100');
  const stale = { rules: [], screens: [{ name: 'home', viewport: 'desktop', maxMismatchPercent: 1, size: { w: 100, h: 130 }, reason }] };
  const s = compareImages({ ...base, baseline, actual: taller, expected: stale });
  assert.equal(s.status, 'size-mismatch');
  assert.equal(s.size.declared, '100x130');
  // A stale declaration is size-mismatch even when baseline and capture are the same size
  assert.equal(compareImages({ ...base, baseline, actual: png(100, 100), expected: stale }).status, 'size-mismatch');
});

test('a valid expected-diffs file has no errors', () => {
  const expected = {
    rules: [{ viewport: 'mobile', mask: { x: 0, y: 40, w: 390, h: 56 }, reason }],
    screens: [
      { name: 'home', viewport: 'desktop', maxMismatchPercent: MAX_PERCENT_CAP, reason },
      { name: 'home', viewport: 'mobile', state: 'default', maxMismatchPercent: 1, size: { w: 390, h: 900 }, reason },
    ],
  };
  assert.deepEqual(validateExpected(expected, { viewports: VIEWPORTS, baseline: BASELINE }), []);
});

test('validation rejects a limit over 5%, a missing reason, unknown keys, bad masks and viewports', () => {
  const expected = {
    extra: true,
    rules: [
      { viewport: 'tablet', mask: { x: 0, y: 0, w: 10, h: 10 }, reason },
      { viewport: 'mobile', mask: { x: 0, y: 0, w: 0, h: 10 }, reason: ' ' },
      { viewport: 'desktop', reason },
    ],
    screens: [
      { name: 'home', viewport: 'desktop', maxMismatchPercent: 5.01, reason },
      { name: 'home', viewport: 'mobile', maxMismatchPercent: 1, colour: 'red' },
    ],
  };
  const errors = validateExpected(expected, { viewports: VIEWPORTS, baseline: BASELINE });
  const has = (re) => assert.ok(errors.some((e) => re.test(e)), `no error matching ${re} in:\n${errors.join('\n')}`);
  has(/unknown key "extra"/);
  has(/rules\[0\]: viewport "tablet"/);
  has(/rules\[1\]: mask must be/);
  has(/rules\[1\]: no reason/);
  has(/rules\[2\]: no mask/);
  has(/screens\[0\] \(home\): maxMismatchPercent 5.01 is over the cap of 5/);
  has(/screens\[1\] \(home\): unknown key "colour"/);
  has(/screens\[1\] \(home\): no reason/);
});

test('validation rejects masks that add up to more than 10% of a viewport', () => {
  // mobile 390 x 844: cap 32916 px². Two rules of 390 x 50 (19500 each) sum over it.
  const rule = { viewport: 'mobile', mask: { x: 0, y: 0, w: 390, h: 50 }, reason };
  const star = { viewport: '*', mask: { x: 0, y: 0, w: 390, h: 50 }, reason };
  assert.match(validateExpected({ rules: [rule, rule], screens: [] }, { viewports: VIEWPORTS })[0], /masks on mobile .* cover 39000 px², over the cap of 32916/);
  assert.match(validateExpected({ rules: [rule, star], screens: [] }, { viewports: VIEWPORTS })[0], /masks on mobile/);
  assert.deepEqual(validateExpected({ rules: [rule], screens: [] }, { viewports: VIEWPORTS }), []);
});

test('validation rejects an entry that matches no baseline PNG, and duplicates', () => {
  const errors = validateExpected({
    rules: [],
    screens: [
      { name: 'nowhere', viewport: 'desktop', maxMismatchPercent: 1, reason },
      { name: 'home', viewport: 'mobile', state: 'empty', maxMismatchPercent: 1, reason },
      { name: 'home', viewport: 'desktop', maxMismatchPercent: 1, reason },
      { name: 'home', viewport: '*', maxMismatchPercent: 1, reason },
      { name: 'home', viewport: 'desktop', state: 'empty', maxMismatchPercent: 1, reason },
    ],
  }, { viewports: VIEWPORTS, baseline: BASELINE });
  assert.ok(errors.some((e) => /screens\[0\] \(nowhere\): matches no baseline PNG/.test(e)), errors.join('\n'));
  assert.ok(errors.some((e) => /screens\[1\] \(home\): matches no baseline PNG \(home empty at mobile\)/.test(e)), errors.join('\n'));
  assert.ok(errors.some((e) => /screens\[3\] \(home\): duplicate of screens\[2\] for home at desktop/.test(e)), errors.join('\n'));
  assert.ok(errors.some((e) => /screens\[4\] \(home\): duplicate of screens\[2\]/.test(e)), errors.join('\n'));
});

test('baseline file names parse back into name, state and viewport', () => {
  assert.deepEqual(parseBaselineName('ap-payments--default--mobile.png'), { name: 'ap-payments', state: 'default', viewport: 'mobile' });
  assert.equal(parseBaselineName('manifest.json'), null);
  assert.equal(parseBaselineName('loose.png'), null);
});

test('exit code: 1 when nothing was compared or anything failed, else 0', () => {
  assert.equal(exitCodeFor([{ status: 'no-baseline', mismatchPercent: null }]), 1);
  assert.equal(exitCodeFor([]), 1);
  assert.equal(exitCodeFor([{ status: 'pass', mismatchPercent: 0 }, { status: 'expected', mismatchPercent: 1 }]), 0);
  assert.equal(exitCodeFor([{ status: 'pass', mismatchPercent: 0 }, { status: 'size-mismatch', mismatchPercent: null }]), 1);
  assert.equal(exitCodeFor([{ status: 'pass', mismatchPercent: 0 }, { status: 'error', mismatchPercent: null }]), 1);
  assert.equal(exitCodeFor([{ status: 'error', mismatchPercent: null }]), 1);
});

test('summary: the worst case is named only when its mismatch is above 0', () => {
  const r = (name, status, mismatchPercent) => ({ slug: `${name}--default--desktop`, name, state: 'default', viewport: 'desktop', status, mismatchPercent });
  assert.equal(summarise([r('a', 'pass', 0), r('b', 'pass', 0)]), 'baseline diff: 2 compared (2 screens), max mismatch 0%; 2 pass');
  assert.equal(summarise([r('a', 'pass', 0), r('b', 'pass', 0.01)]), 'baseline diff: 2 compared (2 screens), max mismatch 0.01% (b--default--desktop); 2 pass');
  assert.equal(summarise([r('a', 'no-baseline', null)]), 'baseline diff: 0 compared (0 screens), max mismatch 0%; 1 no-baseline');
});

// The CLI: these all stop before chromium.launch(), so they need no browser
function cli(args) {
  return spawnSync(process.execPath, ['visual-diff.mjs', '--mockup', FIXTURE, ...args], { cwd: SCRIPTS, encoding: 'utf8', timeout: 20000 });
}

function baselineDir(files) {
  const dir = mkdtempSync(join(tmpdir(), 'visual-diff-test-'));
  for (const f of files) writeFileSync(join(dir, f), png(10, 10));
  return dir;
}

test('cli: an invalid expected-diffs file (the default docs/expected-diffs.json) exits 2 (an invalid input) before any capture', () => {
  const dir = baselineDir(['home--default--desktop.png']);
  try {
    const r = cli(['--baseline', dir]);
    assert.equal(r.status, 2, r.stderr);
    assert.match(r.stderr, /expected-diffs\.json is invalid/);
    assert.match(r.stderr, /maxMismatchPercent 6 is over the cap of 5/);
    assert.doesNotMatch(r.stdout, /cases to compare/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('cli: a named --expected file that does not exist, or is not JSON, or a missing baseline dir, exits 2', () => {
  const dir = baselineDir(['home--default--desktop.png']);
  try {
    const missing = cli(['--baseline', dir, '--expected', join(dir, 'nope.json')]);
    assert.equal(missing.status, 2);
    assert.match(missing.stderr, /does not exist/);
    const noDir = cli(['--baseline', join(dir, 'no-such-dir')]);
    assert.equal(noDir.status, 2, noDir.stderr);
    assert.match(noDir.stderr, /baseline dir .* does not exist/);
    writeFileSync(join(dir, 'bad.json'), '{ not json');
    const bad = cli(['--baseline', dir, '--expected', join(dir, 'bad.json')]);
    assert.equal(bad.status, 2);
    assert.match(bad.stderr, /is not valid JSON/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('cli: no screen matching a baseline PNG exits 1 before any capture', () => {
  const dir = baselineDir(['other--default--desktop.png']);
  try {
    writeFileSync(join(dir, 'ok.json'), JSON.stringify({ rules: [], screens: [] }));
    const r = cli(['--baseline', dir, '--expected', join(dir, 'ok.json')]);
    assert.equal(r.status, 1, r.stderr);
    assert.match(r.stderr, /no screen matches a baseline PNG/);
    const skipped = cli(['--baseline', dir, '--expected', join(dir, 'ok.json'), '--skip', '^home$']);
    assert.equal(skipped.status, 1);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('cli: --app and --baseline together are refused', () => {
  assert.equal(cli(['--app', 'http://localhost:1', '--baseline', '/tmp']).status, 2);
});

test('cli: app mode checks a named --expected file before any capture (exit 2: an invalid input)', () => {

  // --skip and --workers belong to the baseline modes: app mode refuses them rather than ignore them
  for (const flag of [['--skip', 'x'], ['--workers', '2']]) {
    const r = cli(['--app', 'http://localhost:1', ...flag, '--out', join(tmpdir(), 'vd-app-flag')]);
    assert.equal(r.status, 2, r.stdout + r.stderr);
    assert.match(r.stderr, new RegExp(`${flag[0]} applies to --baseline and --write-baseline modes, not --app`));
  }
  const dir = mkdtempSync(join(tmpdir(), 'visual-diff-test-'));
  try {
    const missing = cli(['--app', 'http://localhost:1', '--expected', join(dir, 'nope.json'), '--out', join(dir, 'out')]);
    assert.equal(missing.status, 2, missing.stdout + missing.stderr);
    assert.match(missing.stderr, /does not exist/);
    writeFileSync(join(dir, 'sized.json'), JSON.stringify({ screens: [{ name: 'home', viewport: 'mobile', maxMismatchPercent: 2, size: { w: 390, h: 900 }, reason }] }));
    const sized = cli(['--app', 'http://localhost:1', '--expected', join(dir, 'sized.json'), '--out', join(dir, 'out')]);
    assert.equal(sized.status, 2, sized.stdout + sized.stderr);
    assert.match(sized.stderr, /size applies to --baseline mode only/);
    writeFileSync(join(dir, 'nowhere.json'), JSON.stringify({ screens: [{ name: 'nowhere', viewport: '*', maxMismatchPercent: 2, reason }] }));
    const nowhere = cli(['--app', 'http://localhost:1', '--expected', join(dir, 'nowhere.json'), '--out', join(dir, 'out')]);
    assert.equal(nowhere.status, 2);
    assert.match(nowhere.stderr, /matches no baseline PNG/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('app mode: appStatus passes under the limit, is expected within a screens entry, else fails', () => {
  const expected = { screens: [{ name: 'home', viewport: 'mobile', state: 'default', maxMismatchPercent: 2, reason }] };
  const at = (pct, over = {}) => appStatus(pct, { expected, name: 'home', viewport: 'mobile', state: 'default', maxMismatchPercent: 0.2, ...over });
  assert.equal(at(0.1), 'pass');
  assert.equal(at(1.5), 'expected');
  assert.equal(at(2.5), 'fail');
  assert.equal(at(1.5, { viewport: 'desktop' }), 'fail');
  assert.equal(at(1.5, { state: 'empty' }), 'fail');
  assert.equal(appStatus(1.5, { name: 'home', viewport: 'mobile', maxMismatchPercent: 0.2 }), 'fail');
});

test('app mode: masks paint both images on their viewport only, and size entries are refused', () => {
  const a = PNG.sync.read(png(20, 20));
  const b = PNG.sync.read(png(20, 20, [{ x: 0, y: 0, w: 5, h: 5 }]));
  const expected = { rules: [{ viewport: 'desktop', mask: { x: 0, y: 0, w: 5, h: 5 }, reason }] };
  maskCases(a, b, expected, 'mobile');
  assert.notDeepEqual(a.data, b.data);
  maskCases(a, b, expected, 'desktop');
  assert.deepEqual(a.data, b.data);
  const cases = [{ name: 'home', state: 'default', viewport: 'mobile' }];
  assert.deepEqual(validateAppExpected({ screens: [{ name: 'home', viewport: 'mobile', maxMismatchPercent: 2, reason }] }, { viewports: VIEWPORTS, cases }), []);
  const errors = validateAppExpected({ screens: [{ name: 'home', viewport: 'mobile', maxMismatchPercent: 2, size: { w: 1, h: 1 }, reason }] }, { viewports: VIEWPORTS, cases });
  assert.ok(errors.some((e) => /size applies to --baseline mode only/.test(e)), errors.join('\n'));
});

test('cli: --write-baseline is refused with --app, --baseline, --expected, --shard or --out', () => {
  const dir = mkdtempSync(join(tmpdir(), 'visual-diff-test-'));
  try {
    for (const extra of [['--app', 'http://localhost:1'], ['--baseline', dir], ['--expected', 'x.json'], ['--shard', '1/2'], ['--out', join(dir, 'report')]]) {
      const r = cli(['--write-baseline', join(dir, 'out'), ...extra]);
      assert.equal(r.status, 2, `${extra.join(' ')}: ${r.stdout}${r.stderr}`);
      assert.doesNotMatch(r.stdout, /baseline written/);
    }
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('cli: --write-baseline with filters that select no case exits 2 (could not run) before any capture', () => {
  const dir = mkdtempSync(join(tmpdir(), 'visual-diff-test-'));
  try {
    const r = cli(['--write-baseline', join(dir, 'out'), '--screen', 'nowhere']);
    assert.equal(r.status, 2, r.stdout + r.stderr);
    assert.match(r.stdout, new RegExp(`^baseline written: 0 cases \\(0 screens\\) -> ${join(dir, 'out').replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'm'));
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
