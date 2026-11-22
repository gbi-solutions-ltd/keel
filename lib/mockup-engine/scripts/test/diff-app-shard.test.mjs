/**
 * diff-app-shard.test.mjs: visual-diff.mjs --app end to end on fixtures/diff-app-shard, with the
 * fixture itself served (lib/serve.mjs) as the "app", so every case is 0%: a serial run with an
 * unneeded expected-diffs entry, a --route run, two shards merged by merge-shards.mjs app (and the
 * merge failing once a shard's report is gone), and lib/screens.mjs layoutStable. Launches a
 * browser; keep it small.
 * Run: node --test test/diff-app-shard.test.mjs   (from scripts/)
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
import { serveMockup } from '../lib/serve.mjs';
import { layoutStable } from '../lib/screens.mjs';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/diff-app-shard', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'diff-app-shard-'));
let served;
before(async () => { served = await serveMockup(FIXTURE); });
after(() => { served.server.close(); rmSync(TMP, { recursive: true, force: true }); });

function run(script, args) {
  return new Promise((done) => {
    execFile(process.execPath, [script, ...args], { cwd: SCRIPTS, encoding: 'utf8', timeout: 120000 }, (err, stdout, stderr) => {
      done({ status: err ? (typeof err.code === 'number' ? err.code : -1) : 0, stdout, stderr });
    });
  });
}
const vd = (args) => run('visual-diff.mjs', ['--mockup', FIXTURE, '--app', served.base, ...args]);

test('serial app run: every capture measured, an unneeded expected-diffs entry is a warning and the run still passes', { timeout: 150000 }, async () => {
  const expected = join(TMP, 'expected.json');
  writeFileSync(expected, JSON.stringify({ screens: [{ name: 'invoices', viewport: 'desktop', maxMismatchPercent: 2, reason: 'a table that once drew wider' }] }));
  const out = join(TMP, 'serial');
  const r = await vd(['--expected', expected, '--settle-steps', '--out', out]);
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /^2 of 2 planned captures measured, not measured: 0$/m);
  assert.match(r.stdout, /^warning: 1 expected-diffs entry not needed \(the exit status is unchanged\):$/m);
  assert.match(r.stdout, /^ {2}screens\[0\] invoices at desktop \(every state\): measured at most 0% over 1 case, at or under the 0.2% limit$/m);
  assert.match(r.stdout, /^2\/2 passing \(0 expected, /m);
  const rep = JSON.parse(readFileSync(join(out, 'report.json'), 'utf8'));
  assert.equal(rep.unusedExpected.length, 1);
  assert.deepEqual(rep.cases.map((c) => c.mismatchPercent), [0, 0]);
});

test('--route keeps only the matching screens', { timeout: 120000 }, async () => {
  const out = join(TMP, 'route');
  const r = await vd(['--route', '^/orders', '--out', out]);
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /^1 of 1 planned captures measured, not measured: 0$/m);
  assert.deepEqual(JSON.parse(readFileSync(join(out, 'report.json'), 'utf8')).cases.map((c) => c.slug), ['orders--default--desktop']);
});

test('two app shards merge into the report the serial run writes; a shard with no report fails the merge as not measured', { timeout: 300000 }, async () => {
  const expected = join(TMP, 'expected.json');
  writeFileSync(expected, JSON.stringify({ screens: [{ name: 'invoices', viewport: 'desktop', maxMismatchPercent: 2, reason: 'a table that once drew wider' }] }));
  const flags = ['--expected', expected, '--settle-steps'];
  const serial = await vd([...flags, '--out', join(TMP, 'serial-ref')]);
  assert.equal(serial.status, 0, serial.stdout + serial.stderr);
  const dir = join(TMP, 'shards');
  const shards = await Promise.all([1, 2].map((k) => vd([...flags, '--shard', `${k}/2`, '--out', join(dir, `app-${k}`)])));
  shards.forEach((s, i) => {
    assert.equal(s.status, 0, s.stdout + s.stderr);
    assert.doesNotMatch(s.stdout, /not needed/, 'a shard does not judge the entries');
    writeFileSync(join(dir, `app-${i + 1}.code`), String(s.status));
  });
  // whole screens, one per shard
  const owned = [1, 2].map((k) => JSON.parse(readFileSync(join(dir, `app-${k}`, 'report.json'), 'utf8')).cases.map((c) => c.slug));
  assert.deepEqual(owned.flat().sort(), ['invoices--default--desktop', 'orders--default--desktop']);
  assert.equal(owned[0].length, 1);

  let m = await run('merge-shards.mjs', ['app', '--dir', dir, '--shards', '2']);
  assert.equal(m.status, 0, m.stdout + m.stderr);
  assert.match(m.stdout, /^2 of 2 planned captures measured, not measured: 0$/m);
  assert.match(m.stdout, /^2\/2 passing \(0 expected, /m);
  const warning = (out) => out.split('\n').filter((l) => /^warning:|^ {2}screens\[/.test(l));
  assert.equal(warning(m.stdout).length, 2);
  assert.deepEqual(warning(m.stdout), warning(serial.stdout));
  const merged = JSON.parse(readFileSync(join(dir, 'app', 'report.json'), 'utf8'));
  const ref = JSON.parse(readFileSync(join(TMP, 'serial-ref', 'report.json'), 'utf8'));
  const strip = (cases) => cases.map(({ files: _f, ...c }) => c);
  assert.deepEqual(strip(merged.cases), strip(ref.cases));
  assert.deepEqual(merged.unusedExpected, ref.unusedExpected);
  assert.equal(merged.measured, ref.measured);
  for (const c of merged.cases) assert.ok(readFileSync(join(dir, 'app', c.files.diff)).length > 0, `${c.files.diff} resolves from the merged folder`);

  rmSync(join(dir, 'app-2', 'report.json'));
  m = await run('merge-shards.mjs', ['app', '--dir', dir, '--shards', '2']);
  assert.equal(m.status, 1, m.stdout + m.stderr);
  assert.match(m.stdout, /shard 2: no report.json/);
  assert.match(m.stdout, /^1 of 2 planned captures measured, not measured: 1$/m);
  assert.doesNotMatch(m.stdout, /not needed/, 'an entry whose case went unmeasured is not judged');
});

test('layoutStable waits for a growing page to stop, and gives up at its cap on one that never stops', { timeout: 60000 }, async () => {
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await page.goto(`${served.base}/grows.html`);
    assert.equal(await layoutStable(page), true);
    const settled = await page.evaluate(() => document.documentElement.scrollHeight);
    assert.ok(settled > 1200 + 20 * 5, `the page grew before it settled (${settled}px)`);
    await page.waitForTimeout(400);
    assert.equal(await page.evaluate(() => document.documentElement.scrollHeight), settled, 'no growth after layoutStable resolved');

    await page.goto(`${served.base}/grows.html?forever`);
    const t0 = Date.now();
    assert.equal(await layoutStable(page, 500), false);
    assert.ok(Date.now() - t0 < 3000, 'the cap holds');
  } finally { await browser.close(); }
});

test('baseline mode: --route selects, a case with no PNG fails unless --allow-missing-baseline, and an unneeded expected-diffs entry is a warning that leaves the exit status at 0', { timeout: 150000 }, async () => {
  const png = join(TMP, 'baseline');
  const w = await run('visual-diff.mjs', ['--mockup', FIXTURE, '--write-baseline', png, '--route', 'invoices']);
  assert.equal(w.status, 0, w.stdout + w.stderr);
  assert.match(w.stdout, /^baseline written: 1 cases \(1 screens\)/m);
  const expected = join(TMP, 'baseline-expected.json');
  writeFileSync(expected, JSON.stringify({ screens: [{ name: 'invoices', viewport: '*', maxMismatchPercent: 1, reason: 'a late font' }] }));
  // orders has no PNG: that fails the run and is listed, unless --allow-missing-baseline
  const strict = await run('visual-diff.mjs', ['--mockup', FIXTURE, '--baseline', png, '--expected', expected, '--out', join(TMP, 'bdiff')]);
  assert.equal(strict.status, 1, strict.stdout + strict.stderr);
  assert.match(strict.stdout, /^error: 1 case has no baseline PNG/m);
  assert.match(strict.stdout, /^ {2}orders--default--desktop$/m);
  const b = await run('visual-diff.mjs', ['--mockup', FIXTURE, '--baseline', png, '--expected', expected, '--allow-missing-baseline', '--out', join(TMP, 'bdiff')]);
  assert.equal(b.status, 0, b.stdout + b.stderr);
  assert.match(b.stdout, /^baseline diff: 1 compared \(1 screens\), max mismatch 0%; 1 pass, 1 no-baseline$/m);
  assert.match(b.stdout, /^warning: 1 case has no baseline PNG and was not compared/m);
  assert.match(b.stdout, /^ {2}screens\[0\] invoices at \* \(every state\): measured at most 0% over 1 case/m);
  assert.equal(JSON.parse(readFileSync(join(TMP, 'bdiff', 'report.json'), 'utf8')).unusedExpected.length, 1);
});
