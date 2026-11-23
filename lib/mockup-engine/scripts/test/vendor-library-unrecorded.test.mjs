/**
 * vendor-library-unrecorded.test.mjs: --check reports a file in the vendored copy that the record
 * does not list (a rogue src/rogue.js is drift), except the sync's own .vendored.json and VENDORED.md
 * and the globs the sync was given with --allow (an app's own sheet kept beside the copy).
 * Run: node --test test/vendor-library-unrecorded.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const FIX = fileURLToPath(new URL('./fixtures/vendor-library/lib', import.meta.url));
const TOOL = fileURLToPath(new URL('../vendor-library.mjs', import.meta.url));
const run = (...args) => spawnSync(process.execPath, [TOOL, ...args], { encoding: 'utf8', timeout: 60000 });

function workspace() {
  const ws = mkdtempSync(join(tmpdir(), 'vendor-unrecorded-'));
  cpSync(FIX, join(ws, 'lib'), { recursive: true });
  mkdirSync(join(ws, 'app'));
  return { lib: join(ws, 'lib'), to: join(ws, 'app/vendor/acme-ui') };
}

test('a file in the copy the record does not list is drift; the sync\'s own files are not', () => {
  const { lib, to } = workspace();
  assert.equal(run('--from', lib, '--to', to).status, 0);
  assert.equal(run('--check', '--to', to).status, 0, 'the record and the note are not drift');
  writeFileSync(join(to, 'src/rogue.js'), 'export const rogue = 1;\n');
  const r = run('--check', '--to', to);
  assert.equal(r.status, 1, r.stdout);
  assert.match(r.stdout, /not in the record: src\/rogue\.js/);

  rmSync(lib, { recursive: true, force: true });
  const offline = run('--check', '--to', to);
  assert.equal(offline.status, 1, 'seen without the source too');
  assert.match(offline.stdout, /not in the record: src\/rogue\.js/);
});

test('--allow globs are recorded, kept on a resync, and let the app keep its own files in the copy', () => {
  const { lib, to } = workspace();
  const r = run('--from', lib, '--to', to, '--allow', 'app-*.css');
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual(JSON.parse(readFileSync(join(to, '.vendored.json'), 'utf8')).allow, ['app-*.css']);
  assert.match(readFileSync(join(to, 'VENDORED.md'), 'utf8'), /--allow 'app-\*\.css'/);
  writeFileSync(join(to, 'app-overrides.css'), '/* the app\'s own */\n');
  assert.equal(run('--check', '--to', to).status, 0);
  writeFileSync(join(to, 'other.css'), '/* not allowed */\n');
  const bad = run('--check', '--to', to);
  assert.equal(bad.status, 1);
  assert.match(bad.stdout, /not in the record: other\.css/);
  assert.doesNotMatch(bad.stdout, /app-overrides/);
  rmSync(join(to, 'other.css'));
  assert.equal(run('--from', lib, '--to', to).status, 0, 'a resync with no --allow');
  assert.deepEqual(JSON.parse(readFileSync(join(to, '.vendored.json'), 'utf8')).allow, ['app-*.css'], 'keeps the recorded globs');
  assert.equal(run('--check', '--to', to).status, 0);
});

test('a record written before allow existed still checks, allowing only the sync\'s own files', () => {
  const { lib, to } = workspace();
  assert.equal(run('--from', lib, '--to', to).status, 0);
  const recPath = join(to, '.vendored.json');
  const rec = JSON.parse(readFileSync(recPath, 'utf8'));
  delete rec.allow;
  writeFileSync(recPath, `${JSON.stringify(rec, null, 2)}\n`);
  assert.equal(run('--check', '--to', to).status, 0);
});
