/**
 * write-baseline.test.mjs: visual-diff.mjs --write-baseline captures every selected case into the
 * file names --baseline reads, and a --baseline run on the same mockup with the same pins then
 * passes every case at 0%. Launches a browser on fixtures/visual-diff.
 * Run: node --test test/write-baseline.test.mjs   (from scripts/)
 */
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { cpSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/visual-diff', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'write-baseline-'));
after(() => rmSync(TMP, { recursive: true, force: true }));
const PINS = ['--clock', '2026-11-06T09:00:00Z', '--seed', '20261106', '--tz', 'Africa/Kampala'];

function cli(args) {
  return new Promise((done) => {
    execFile(process.execPath, ['visual-diff.mjs', '--mockup', FIXTURE, ...args], { cwd: SCRIPTS, encoding: 'utf8', timeout: 90000 }, (err, stdout, stderr) => {
      done({ status: err ? (typeof err.code === 'number' ? err.code : -1) : 0, stdout, stderr });
    });
  });
}

test('--write-baseline writes <name>--<state>--<viewport>.png for every case, and --baseline then passes all at 0%', { timeout: 180000 }, async () => {
  const dir = join(TMP, 'baseline', 'nested');
  const w = await cli(['--write-baseline', dir, ...PINS]);
  assert.equal(w.status, 0, w.stdout + w.stderr);
  assert.match(w.stdout, new RegExp(`^baseline written: 4 cases \\(1 screens\\) -> ${dir.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'm'));
  assert.deepEqual(readdirSync(dir).sort(), ['home--default--desktop.png', 'home--default--mobile.png', 'home--empty--desktop.png', 'home--empty--mobile.png']);

  // the fixture's own docs/expected-diffs.json is invalid on purpose; this run names an empty one
  const expected = join(TMP, 'expected.json');
  writeFileSync(expected, JSON.stringify({ rules: [], screens: [] }));
  const b = await cli(['--baseline', dir, '--expected', expected, '--out', join(TMP, 'diff'), ...PINS]);
  assert.equal(b.status, 0, b.stdout + b.stderr);
  assert.match(b.stdout, /^baseline diff: 4 compared \(1 screens\), max mismatch 0%; 4 pass$/m);
});

test('--write-baseline honours --state and --viewport, and leaves other files in the folder alone', { timeout: 120000 }, async () => {
  const dir = join(TMP, 'filtered');
  const w = await cli(['--write-baseline', dir, '--state', 'empty', '--viewport', 'mobile', ...PINS]);
  assert.equal(w.status, 0, w.stdout + w.stderr);
  assert.match(w.stdout, /^baseline written: 1 cases \(1 screens\) -> /m);
  writeFileSync(join(dir, 'keep.txt'), 'x');
  const again = await cli(['--write-baseline', dir, '--state', 'default', '--viewport', 'desktop', ...PINS]);
  assert.equal(again.status, 0, again.stdout + again.stderr);
  assert.deepEqual(readdirSync(dir).sort(), ['home--default--desktop.png', 'home--empty--mobile.png', 'keep.txt']);
});

test('a raised app tolerance does not loosen baseline mode; baselineMaxMismatchPercent does', { timeout: 180000 }, async () => {
  const mockup = join(TMP, 'tolerance');
  cpSync(FIXTURE, mockup, { recursive: true });
  const run = (args) => new Promise((done) => {
    execFile(process.execPath, ['visual-diff.mjs', '--mockup', mockup, ...args], { cwd: SCRIPTS, encoding: 'utf8', timeout: 90000 }, (err, stdout, stderr) => {
      done({ status: err ? (typeof err.code === 'number' ? err.code : -1) : 0, stdout, stderr });
    });
  });
  const dir = join(mockup, 'png');
  const sel = ['--viewport', 'mobile', '--state', 'default', ...PINS];
  assert.equal((await run(['--write-baseline', dir, ...sel])).status, 0);
  // A 50 by 40 box: about 0.6% of the 390 by 844 page, over 0.2 and under a js-kit's 1.0.
  const page = join(mockup, 'index.html');
  writeFileSync(page, readFileSync(page, 'utf8').replace('</body>', '<div style="width:50px;height:40px;background:#000"></div></body>'));
  const expected = join(TMP, 'expected-empty.json');
  writeFileSync(expected, JSON.stringify({ rules: [], screens: [] }));
  const setDiff = (diff) => {
    const file = join(mockup, 'mockup.config.json');
    const c = JSON.parse(readFileSync(file, 'utf8'));
    c.diff = diff;
    writeFileSync(file, JSON.stringify(c));
  };
  setDiff({ maxMismatchPercent: 1.0, pixelThreshold: 0.1 });
  const loose = await run(['--baseline', dir, '--expected', expected, '--out', join(mockup, 'd1'), ...sel]);
  assert.equal(loose.status, 1, loose.stdout + loose.stderr);
  setDiff({ maxMismatchPercent: 1.0, baselineMaxMismatchPercent: 1.0, pixelThreshold: 0.1 });
  const declared = await run(['--baseline', dir, '--expected', expected, '--out', join(mockup, 'd2'), ...sel]);
  assert.equal(declared.status, 0, declared.stdout + declared.stderr);
});
