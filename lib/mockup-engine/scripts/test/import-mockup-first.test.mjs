/**
 * import-mockup-first.test.mjs: on an app's first import (no .import-mockup.json), a byte copy that
 * already exists with other bytes than the import would write is the app's own until shown
 * otherwise: the run refuses it (exit 1, nothing written) unless --force, and --check lists it as
 * unrecorded. One equal to what would be written is fine and gets recorded.
 * No browser. Run: node --test test/import-mockup-first.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../import-mockup.mjs', import.meta.url));
const GOOD = fileURLToPath(new URL('./fixtures/import-mockup/good', import.meta.url));
const RECORD = '.import-mockup.json';
const imp = (...args) => {
  const r = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: 'utf8', timeout: 150000 });
  return { code: r.status, out: r.stdout + r.stderr };
};

test('first import: an existing byte copy with other bytes is refused unless --force; --check names it unrecorded', () => {
  const app = mkdtempSync(join(tmpdir(), 'import-first-'));
  const base = join(app, 'src/styles/base.css');
  mkdirSync(join(app, 'src/styles'), { recursive: true });
  writeFileSync(base, '/* the app\'s own base sheet */\n');

  const refused = imp('--mockup', GOOD, '--app', app);
  assert.equal(refused.code, 1, refused.out);
  assert.match(refused.out, /src\/styles\/base\.css exists with other bytes and no import recorded it/);
  assert.match(refused.out, /nothing written/);
  assert.equal(readFileSync(base, 'utf8'), '/* the app\'s own base sheet */\n', 'left as it was');
  assert.ok(!existsSync(join(app, RECORD)), 'no record written');
  assert.ok(!existsSync(join(app, 'src/mocks/fixtures.ts')), 'no other output written');

  const check = imp('--mockup', GOOD, '--app', app, '--check');
  assert.equal(check.code, 1, check.out);
  assert.match(check.out, /would change: src\/styles\/base\.css \(unrecorded\)/);

  const forced = imp('--mockup', GOOD, '--app', app, '--force');
  assert.equal(forced.code, 0, forced.out);
  assert.match(forced.out, /overwrote src\/styles\/base\.css, which no import had recorded/);
  assert.ok(readFileSync(base).equals(readFileSync(join(GOOD, 'assets/base.css'))));
  assert.ok(JSON.parse(readFileSync(join(app, RECORD), 'utf8')).files['src/styles/base.css']);
});

test('first import: an existing byte copy equal to what would be written is fine and recorded', () => {
  const app = mkdtempSync(join(tmpdir(), 'import-first-'));
  mkdirSync(join(app, 'src/styles'), { recursive: true });
  writeFileSync(join(app, 'src/styles/base.css'), readFileSync(join(GOOD, 'assets/base.css')));
  const r = imp('--mockup', GOOD, '--app', app);
  assert.equal(r.code, 0, r.out);
  const rec = JSON.parse(readFileSync(join(app, RECORD), 'utf8'));
  assert.equal(rec.files['src/styles/base.css'].part, 'css');
  assert.match(rec.files['src/styles/base.css'].sha256, /^[0-9a-f]{64}$/);
});

test('a record with no entry for a byte copy: an existing file with other bytes is refused too (not overwritten with a warning)', () => {
  const app = mkdtempSync(join(tmpdir(), 'import-partial-'));
  const first = imp('--mockup', GOOD, '--app', app, '--only', 'fixtures');
  assert.equal(first.code, 0, first.out);
  assert.ok(existsSync(join(app, RECORD)), 'the fixtures run records');
  const base = join(app, 'src/styles/base.css');
  mkdirSync(join(app, 'src/styles'), { recursive: true });
  writeFileSync(base, '/* the app\'s own base sheet */\n');

  const refused = imp('--mockup', GOOD, '--app', app, '--only', 'css');
  assert.equal(refused.code, 1, refused.out);
  assert.match(refused.out, /src\/styles\/base\.css exists with other bytes and no import recorded it/);
  assert.equal(readFileSync(base, 'utf8'), '/* the app\'s own base sheet */\n', 'left as it was');

  const forced = imp('--mockup', GOOD, '--app', app, '--only', 'css', '--force');
  assert.equal(forced.code, 0, forced.out);
});

