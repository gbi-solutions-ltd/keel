/**
 * check-frontend-roots.test.mjs: a missing source root, or a run that scans no files, is a usage
 * error (exit 2), never `clean (0 files)`; and a style prop given an object (`style={obj}`) is an
 * inline style like `style={{ ... }}`.
 * Run: node --test test/check-frontend-roots.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../check-frontend.mjs', import.meta.url));

/** Writes files into a fresh app folder and runs the check there with the given roots. */
function check(files, roots) {
  const app = mkdtempSync(join(tmpdir(), 'check-frontend-roots-'));
  try {
    for (const [path, text] of Object.entries(files)) {
      mkdirSync(dirname(join(app, path)), { recursive: true });
      writeFileSync(join(app, path), text);
    }
    const r = spawnSync(process.execPath, [SCRIPT, ...roots], { cwd: app, encoding: 'utf8' });
    return { status: r.status, out: `${r.stdout}${r.stderr}` };
  } finally {
    rmSync(app, { recursive: true, force: true });
  }
}

const ok = { 'src/components/primitives/A.tsx': 'export const A = () => <span className="a" />;\n' };

test('the default root src missing exits 2', () => {
  const r = check({}, []);
  assert.equal(r.status, 2, r.out);
  assert.match(r.out, /src/);
});

test('a named root that is missing exits 2, even beside one that exists', () => {
  const r = check(ok, ['src', 'app']);
  assert.equal(r.status, 2, r.out);
  assert.match(r.out, /app/);
});

test('roots that hold no files to scan exit 2', () => {
  const r = check({ 'src/readme.txt': 'nothing here\n' }, ['src']);
  assert.equal(r.status, 2, r.out);
  assert.match(r.out, /no files/);
});

test('an existing root with files is still clean', () => {
  const r = check(ok, ['src']);
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /clean \(1 files\)/);
});

test('style={obj} is an inline style; sx={obj} and data-style={x} are not', () => {
  const r = check({
    'src/components/primitives/B.tsx': 'const s = { color: "var(--text)" };\nexport const B = () => <div style={s} />;\n',
    'src/components/primitives/C.tsx': 'export const C = () => <div sx={s} data-style={x} />;\n',
  }, ['src']);
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /B\.tsx:2 {2}inline-style/);
  assert.doesNotMatch(r.out, /C\.tsx/);
});
