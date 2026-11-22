/**
 * merge-quality.test.mjs: `merge-shards.mjs quality` merges real quality-check shards into the
 * serial result, and a shard with no report makes the merge fail with "not measured".
 * Runs quality-check.mjs on the quality-sheet fixture in a real browser.
 * Run: node --test test/merge-quality.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const QUALITY = fileURLToPath(new URL('../quality-check.mjs', import.meta.url));
const MERGE = fileURLToPath(new URL('../merge-shards.mjs', import.meta.url));
const SHEET = fileURLToPath(new URL('./fixtures/quality-sheet', import.meta.url));

function node(script, args) {
  return new Promise((done) => {
    execFile(process.execPath, [script, ...args], { timeout: 120000 }, (err, stdout, stderr) => done({ code: err ? err.code : 0, stdout, stderr }));
  });
}

test('quality shards merge to the serial counts; a missing shard report is not measured', { timeout: 300000 }, async () => {
  const dir = mkdtempSync(join(tmpdir(), 'merge-quality-'));
  try {
    const serial = await node(QUALITY, ['--mockup', SHEET, '--out', join(dir, 'serial')]);
    const passing = serial.stdout.match(/(\d+)\/(\d+) passing/);
    assert.ok(passing, serial.stdout + serial.stderr);
    for (const k of [1, 2]) {
      const r = await node(QUALITY, ['--mockup', SHEET, '--shard', `${k}/2`, '--out', join(dir, `quality-${k}`)]);
      writeFileSync(join(dir, `quality-${k}.code`), String(r.code));
    }
    const merged = await node(MERGE, ['quality', '--dir', dir, '--shards', '2', '--mockup', SHEET]);
    assert.match(merged.stdout, new RegExp(`${passing[1]}/${passing[2]} passing`), merged.stdout + merged.stderr);
    assert.match(merged.stdout, new RegExp(`${passing[2]} of ${passing[2]} planned cases measured, not measured: 0`));
    assert.equal(merged.code, serial.code, 'the merge exits as the serial run does');

    rmSync(join(dir, 'quality-2', 'report.json'));
    const broken = await node(MERGE, ['quality', '--dir', dir, '--shards', '2', '--mockup', SHEET]);
    assert.equal(broken.code, 1, broken.stdout + broken.stderr);
    assert.match(broken.stdout, /not measured: [1-9]/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('merge-shards quality refuses a folder with no shard reports', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'merge-quality-empty-'));
  try {
    const r = await node(MERGE, ['quality', '--dir', dir, '--shards', '2']);
    assert.equal(r.code, 2, r.stdout + r.stderr);
    assert.match(r.stderr, /error:/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
