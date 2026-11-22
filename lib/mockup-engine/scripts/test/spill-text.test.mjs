/**
 * spill-text.test.mjs: spill-check.mjs --text with a valid scale (sweep F; bad values are in
 * spill-args.test.mjs). On fixtures/sweep-f/spill-text a 200px label holds ten characters at the
 * default text size and not at 250%: the plain run exits 0 and writes spill.json with nothing; the
 * --text 2.5 run exits 1, reports the label as spilling and writes its own spill-text-2.5.json,
 * leaving the plain run's file as it was. Launches a browser.
 * Run: node --test test/spill-text.test.mjs   (from scripts/)
 */
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SPILL = fileURLToPath(new URL('../spill-check.mjs', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/sweep-f/spill-text', import.meta.url));
const OUT = mkdtempSync(join(tmpdir(), 'spill-text-'));
after(() => rmSync(OUT, { recursive: true, force: true }));
const spill = (...a) => {
  const r = spawnSync(process.execPath, [SPILL, '--mockup', FIXTURE, '--widths', '400', '--out', OUT, ...a], { encoding: 'utf8', timeout: 110000 });
  return { code: r.status, out: `${r.stdout}${r.stderr}` };
};

test('the label fits at the default text size, and spills at --text 2.5 into its own file', { timeout: 240000 }, () => {
  const plain = spill();
  assert.equal(plain.code, 0, plain.out);
  assert.match(plain.out, /^1 cases, 0 spills, 0 distinct$/m);
  assert.deepEqual(JSON.parse(readFileSync(join(OUT, 'spill.json'), 'utf8')), []);

  const big = spill('--text', '2.5');
  assert.equal(big.code, 1, big.out);
  assert.match(big.out, /^1x {2}\[spills\] div\.badge in \(no card\): "ABCDEFGHIJ"$/m);
  assert.match(big.out, /^1 cases, 1 spills, 1 distinct$/m);
  const file = join(OUT, 'spill-text-2.5.json');
  assert.ok(existsSync(file), 'a --text run writes spill-text-<k>.json');
  const rows = JSON.parse(readFileSync(file, 'utf8'));
  assert.equal(rows.length, 1);
  assert.equal(rows[0].kind, 'spills');
  assert.equal(rows[0].el, 'div.badge');
  assert.ok(rows[0].over > 1, JSON.stringify(rows[0]));
  assert.deepEqual(JSON.parse(readFileSync(join(OUT, 'spill.json'), 'utf8')), [], 'the plain run\'s file is untouched');

  // --text 1 is the plain run
  const one = spill('--text', '1');
  assert.equal(one.code, 0, one.out);
  assert.equal(existsSync(join(OUT, 'spill-text-1.json')), false);
});
