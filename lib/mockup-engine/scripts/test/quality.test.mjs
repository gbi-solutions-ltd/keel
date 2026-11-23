/**
 * quality.test.mjs: a covered target is skipped for the touch warning (gap 15; crowding itself is
 * axe's target-size) and a run of 0 cases fails (gap 19); targets under a fixed sheet or off screen
 * are skipped, --shard K/N and the
 * shard merge give the serial result, and warnings print summarised unless --warnings all.
 * Runs quality-check.mjs on fixture pages in a real browser.
 * Run: node --test test/quality.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { mergeQualityShards } from '../lib/quality-merge.mjs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../quality-check.mjs', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/quality/covered', import.meta.url));
const SHEET = fileURLToPath(new URL('./fixtures/quality-sheet', import.meta.url));

function run(args) {
  return new Promise((done) => {
    execFile(process.execPath, [SCRIPT, ...args], { timeout: 90000 }, (err, stdout, stderr) => done({ code: err ? err.code : 0, stdout, stderr }));
  });
}

test('crowding fails as axe target-size, not an own target rule; a covered target is still counted as skipped (gap 15)', { timeout: 120000 }, async () => {
  const out = mkdtempSync(join(tmpdir(), 'quality-test-'));
  try {
    await run(['--mockup', FIXTURE, '--out', out]);
    const report = JSON.parse(readFileSync(join(out, 'report.json'), 'utf8'));
    const desktop = report.cases.find((c) => c.slug === 'covered--default--desktop');
    // Crowding is axe's target-size alone (test/quality-target.test.mjs): it judges every pair,
    // the covered A and B too, so the case fails once on it and has no own target failure.
    assert.deepEqual(desktop.failures.filter((f) => f.check === 'target'), []);
    assert.ok(desktop.failures.some((f) => f.check === 'axe' && f.detail.startsWith('target-size:')));
    // A sits under the popover: still skipped as covered for the touch warning
    assert.equal(desktop.targetSkipped.covered, 1);
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});

test('a --screen that matches nothing exits 2 (could not run) and says so (gap 19)', { timeout: 60000 }, async () => {
  const out = mkdtempSync(join(tmpdir(), 'quality-test-'));
  try {
    const r = await run(['--mockup', FIXTURE, '--out', out, '--screen', 'nosuchscreen']);
    assert.equal(r.code, 2);
    assert.match(r.stderr, /--screen "nosuchscreen" matches no screen/);
    assert.match(r.stderr, /0 cases run/);
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});

test('a config whose screens collide, or (with --app) a screen with no route, exits 2 before any capture, as visual-diff does', { timeout: 60000 }, async () => {
  const dir = mkdtempSync(join(tmpdir(), 'quality-test-'));
  try {
    writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify({ screens: [{ name: 'a', page: 'a.html', route: '/a' }, { name: 'a', page: 'b.html', route: '/b' }] }));
    const twice = await run(['--mockup', dir, '--out', join(dir, 'out')]);
    assert.equal(twice.code, 2, twice.stdout + twice.stderr);
    assert.match(twice.stderr, /cannot be run:\n {2}screens\[1\]: name a is also screens\[0\]'s/);
    writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify({ screens: [{ name: 'a', page: 'a.html' }] }));
    const noRoute = await run(['--mockup', dir, '--app', 'http://127.0.0.1:9', '--out', join(dir, 'out')]);
    assert.equal(noRoute.code, 2, noRoute.stdout + noRoute.stderr);
    assert.match(noRoute.stderr, /screens\[0\] a: no route, which app mode needs/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

const targetFails = (c) => c.failures.filter((f) => f.check === 'target').map((f) => f.detail.match(/"(.+?)"/)[1]).sort();

test('targets under a fixed sheet (in view or below the fold) or off screen are skipped; an open pair below the fold still fails; sharded runs merge to the serial result; warnings summarised', { timeout: 300000 }, async () => {
  const out = mkdtempSync(join(tmpdir(), 'quality-test-'));
  try {
    const serial = await run(['--mockup', SHEET, '--out', join(out, 'serial'), '--warnings', 'all']);
    assert.equal(serial.code, 1);
    const report = JSON.parse(readFileSync(join(out, 'serial', 'report.json'), 'utf8'));
    const sheet = report.cases.find((c) => c.slug === 'sheet--default--desktop');
    // G and H sit under the sheet in view, I and J under it below the fold, K and L at
    // left:-9999px; M and N are open and crowded, which axe's target-size judges (no own rule)
    assert.deepEqual(targetFails(sheet), []);
    assert.ok(sheet.failures.some((f) => f.check === 'axe' && f.detail.startsWith('target-size:')));
    assert.equal(sheet.targetSkipped.covered, 4);
    assert.equal(sheet.targetSkipped.offscreen, 2);
    assert.ok(sheet.targetSkipped.examples.includes('offscreen: a "Away K"'));
    // failures print in full; with --warnings all every warning prints, and report.md lists them
    assert.match(serial.stdout, /fail axe: target-size: /);
    assert.equal((serial.stdout.match(/warning target: button "Pay"/g) || []).length, 6);
    assert.match(readFileSync(join(out, 'serial', 'report.md'), 'utf8'), /## Warnings\n\n- target: button "Pay"/);

    const shards = [];
    for (const k of [1, 2]) {
      const r = await run(['--mockup', SHEET, '--shard', `${k}/2`, '--out', join(out, `quality-${k}`)]);
      shards.push({ k, code: r.code, stdout: r.stdout, report: JSON.parse(readFileSync(join(out, `quality-${k}`, 'report.json'), 'utf8')) });
    }
    // screens split whole: each shard runs one screen's cases only, and carries the whole plan
    for (const s of shards) {
      assert.equal(new Set(s.report.cases.map((c) => c.slug.split('--')[0])).size, 1);
      assert.equal(s.report.shard.planned.length, 6);
      assert.equal(s.report.shard.k, s.k);
    }
    // default: a summary line per check, never each warning
    const withWarn = shards.find((s) => s.report.cases.some((c) => c.warnings.length));
    assert.match(withWarn.stdout, /warnings: target 8 in 2 case\(s\) \(2 distinct\)/);
    assert.doesNotMatch(withWarn.stdout, /warning target:/);
    assert.match(readFileSync(join(out, `quality-${withWarn.k}`, 'report.md'), 'utf8'), /### target: 8 \(2 distinct\)\n\n- 6x button "Pay"/);

    const m = mergeQualityShards(shards);
    assert.equal(m.summary, '6 of 6 planned cases measured, not measured: 0');
    assert.deepEqual(m.extra, []);
    assert.equal(m.exitCode, 1); // the sheet screen fails, as in the serial run
    assert.deepEqual(m.rows.map((r) => [r.slug, r.pass, r.failures.map((f) => f.detail)]), report.cases.map((r) => [r.slug, r.pass, r.failures.map((f) => f.detail)]));

    // negative: the shard owning the passing screen died before writing its report
    const passing = shards.find((s) => s.report.cases.every((c) => c.pass));
    const dead = mergeQualityShards(shards.map((s) => (s === passing ? { k: s.k, code: null, report: null } : s)));
    assert.equal(dead.summary, '2 of 6 planned cases measured, not measured: 4');
    assert.deepEqual(dead.extra, [`shard ${passing.k}: no report.json`]);
    assert.equal(dead.exitCode, 1);
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});

test('a bad --shard or --warnings value exits 2 before any browser starts', { timeout: 60000 }, async () => {
  const a = await run(['--mockup', SHEET, '--shard', '3/2']);
  assert.equal(a.code, 2);
  assert.match(a.stderr, /--shard must be K\/N/);
  const b = await run(['--mockup', SHEET, '--warnings', 'some']);
  assert.equal(b.code, 2);
  assert.match(b.stderr, /--warnings must be summary or all/);
});

test('a shard that owns no screen writes an empty report with the plan and exits 0', { timeout: 60000 }, async () => {
  const out = mkdtempSync(join(tmpdir(), 'quality-test-'));
  try {
    const r = await run(['--mockup', FIXTURE, '--shard', '2/2', '--out', out]);
    assert.equal(r.code, 0);
    assert.match(r.stdout, /owns no screen/);
    const report = JSON.parse(readFileSync(join(out, 'report.json'), 'utf8'));
    assert.deepEqual(report.cases, []);
    assert.equal(report.shard.planned.length, 2);
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});

test('under a strict CSP the check adds no violation of its own; focus drawn on a sibling, in a layer of the control or a frame late counts, no change at all still fails', { timeout: 120000 }, async () => {
  const out = mkdtempSync(join(tmpdir(), 'quality-test-'));
  try {
    await run(['--mockup', fileURLToPath(new URL('./fixtures/quality/csp-focus', import.meta.url)), '--out', out]);
    const report = JSON.parse(readFileSync(join(out, 'report.json'), 'utf8'));
    const [c] = report.cases;
    const details = c.failures.map((f) => `${f.check}: ${f.detail}`);
    assert.ok(!details.some((d) => /CSP|console/i.test(d)), `no CSP failure expected, got ${details.join('; ')}`);
    const focus = c.failures.filter((f) => f.check === 'focus').map((f) => f.detail);
    assert.deepEqual(focus, ['no visible focus indicator on #bare']);
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});
