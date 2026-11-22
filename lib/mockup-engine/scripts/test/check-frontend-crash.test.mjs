/**
 * check-frontend-crash.test.mjs: a crash (here a broken symlink under src/, which statSync cannot
 * follow) exits 2, could not run, never 1, which check-frontend keeps for findings.
 * Run: node --test test/check-frontend-crash.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../check-frontend.mjs', import.meta.url));

test('a broken symlink in src/ is a crash: exit 2, named on stderr', () => {
  const app = mkdtempSync(join(tmpdir(), 'check-frontend-crash-'));
  try {
    mkdirSync(join(app, 'src'));
    writeFileSync(join(app, 'src', 'a.ts'), 'export const a = 1;\n');
    symlinkSync(join(app, 'no-such-file.ts'), join(app, 'src', 'gone.ts'));
    const r = spawnSync(process.execPath, [SCRIPT], { cwd: app, encoding: 'utf8' });
    assert.equal(r.status, 2, `${r.stdout}${r.stderr}`);
    assert.match(r.stderr, /^check-frontend: crashed: .*ENOENT/m);
  } finally {
    rmSync(app, { recursive: true, force: true });
  }
});
