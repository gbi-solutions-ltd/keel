/**
 * quality-target.test.mjs: WCAG 2.5.8 target spacing is judged by axe's target-size rule alone
 * (run under the wcag22aa tag), which measures a 24px circle against the neighbouring boxes and
 * exempts inline links. quality-check's own crowding rule (centre to centre) only repeated it, so it
 * is gone; the mobile touch-size warning (config.quality.targetMinPx) stays.
 * Runs quality-check.mjs on a fixture page in a real browser.
 * Run: node --test test/quality-target.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../quality-check.mjs', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/quality/covered', import.meta.url));

test('crowded targets fail once, as axe target-size, with no own target failure beside it', { timeout: 120000 }, async () => {
  const out = mkdtempSync(join(tmpdir(), 'quality-target-'));
  try {
    const r = await new Promise((done) => execFile(process.execPath, [SCRIPT, '--mockup', FIXTURE, '--out', out, '--screen', 'covered'], { timeout: 90000 }, (err, stdout, stderr) => done({ code: err ? err.code : 0, stdout, stderr })));
    assert.equal(r.code, 1, r.stdout + r.stderr);
    const desktop = JSON.parse(readFileSync(join(out, 'report.json'), 'utf8')).cases.find((c) => c.slug === 'covered--default--desktop');
    assert.deepEqual(desktop.failures.filter((f) => f.check === 'target'), []);
    assert.equal(desktop.failures.filter((f) => f.check === 'axe' && f.detail.startsWith('target-size:')).length, 1);
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});
