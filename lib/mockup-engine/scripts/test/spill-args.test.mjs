/**
 * spill-args.test.mjs: spill-check.mjs refuses a --text that is not a positive number before any
 * browser starts, and a screen with no name (a page only) is matched and run, not a crash (B12).
 * Run: node --test test/spill-args.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const FIXTURE = fileURLToPath(new URL('./fixtures/spill', import.meta.url));
const TOOL = fileURLToPath(new URL('../spill-check.mjs', import.meta.url));
const run = (...args) => spawnSync(process.execPath, [TOOL, ...args], { encoding: 'utf8', timeout: 120000 });

test('--text abc, 0 and -1 exit 2 and write nothing', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'spill-args-'));
  try {
    for (const t of ['abc', '0', '-1', 'Infinity']) {
      const out = join(tmp, `out-${t}`);
      const r = run('--mockup', FIXTURE, '--widths', '600', '--text', t, '--out', out);
      assert.equal(r.status, 2, `--text ${t}: ${r.stdout}${r.stderr}`);
      assert.match(r.stderr, /--text must be a number above 0/);
      assert.ok(!existsSync(out), `--text ${t} wrote a result`);
    }
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('a screen with no name is matched by its page and run, not a crash', { timeout: 120000 }, () => {
  const tmp = mkdtempSync(join(tmpdir(), 'spill-args-'));
  try {
    const m = join(tmp, 'm');
    cpSync(FIXTURE, m, { recursive: true });
    const config = JSON.parse(readFileSync(join(m, 'mockup.config.json'), 'utf8'));
    config.screens = config.screens.map(({ name, ...s }) => s);
    writeFileSync(join(m, 'mockup.config.json'), JSON.stringify(config));
    const none = run('--mockup', m, '--widths', '600', '--screen', 'nosuch', '--out', join(tmp, 'o1'));
    assert.equal(none.status, 2, none.stdout + none.stderr);
    assert.doesNotMatch(none.stderr, /crashed/);
    assert.match(none.stderr, /matches no screen/);
    const r = run('--mockup', m, '--widths', '600', '--screen', 'cases', '--out', join(tmp, 'o2'));
    assert.doesNotMatch(r.stderr, /crashed/, r.stderr);
    assert.ok(existsSync(join(tmp, 'o2/spill.json')), r.stdout + r.stderr);
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});
