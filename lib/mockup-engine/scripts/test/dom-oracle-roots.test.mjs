/**
 * dom-oracle-roots.test.mjs: dom-oracle.mjs's --root, --app-root and --strict as flags (sweep F; the
 * audit lists them under spill-check, which has none of them). Case mode on fixtures/sweep-f/oracle:
 * the root defaults to #app on both sides; --root names another for both; --app-root names the
 * app's side only (the mockup keeps --root, else #app). File mode: --diff prints IDENTICAL when two
 * dumps differ only in edge whitespace, --diff --strict prints that difference; the exit status
 * follows the diff lines, so both exit 0. The "app" is a small server on 127.0.0.1 serving
 * fixtures/sweep-f/oracle/app-home.html at /home. Launches a browser.
 * Run: node --test test/dom-oracle-roots.test.mjs   (from scripts/)
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ORACLE = fileURLToPath(new URL('../dom-oracle.mjs', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/sweep-f/oracle', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'dom-oracle-roots-'));
const run = (args) => new Promise((done) => {
  const p = spawn(process.execPath, [ORACLE, ...args]);
  let out = '';
  p.stdout.on('data', (d) => { out += d; });
  p.stderr.on('data', (d) => { out += d; });
  p.on('close', (code) => done({ code, out }));
});

let server, base;
before(async () => {
  const page = readFileSync(join(FIXTURE, 'app-home.html'));
  server = createServer((q, res) => {
    if (q.url.split('?')[0] === '/home') return res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }).end(page);
    res.writeHead(404).end('not found');
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => { server.close(); rmSync(TMP, { recursive: true, force: true }); });

let n = 0;
/** One case-mode run; returns the exit code, output and the case's mockup and app dumps. */
async function oracle(flags) {
  const out = join(TMP, `run-${++n}`);
  const r = await run(['--mockup', FIXTURE, '--app', base, '--out', out, ...flags]);
  const c = JSON.parse(readFileSync(join(out, 'report.json'), 'utf8')).cases[0];
  const slug = c.slug;
  const read = (f) => readFileSync(join(out, slug, f), 'utf8');
  return { ...r, c, mockup: read('mockup.html'), app: read('app.html') };
}

test('the default root is #app on both sides: the chrome differs, exit 1', { timeout: 120000 }, async () => {
  const r = await oracle([]);
  assert.equal(r.code, 1, r.out);
  assert.match(r.mockup, /Mockup chrome/);
  assert.match(r.app, /App chrome/);
  assert.ok(r.c.diffLines > 0, JSON.stringify(r.c));
});

test('--root names the root on both sides', { timeout: 120000 }, async () => {
  const r = await oracle(['--root', '#content']);
  assert.equal(r.code, 0, r.out);
  assert.equal(r.c.diffLines, 0, JSON.stringify(r.c));
  assert.match(r.mockup, /INV-0412/);
  assert.match(r.app, /INV-0412/);
  assert.doesNotMatch(r.app, /chrome/);
});

test('--app-root names the app\'s side only; the mockup keeps #app, or --root', { timeout: 120000 }, async () => {
  const r = await oracle(['--app-root', '#root']);
  assert.equal(r.code, 0, r.out);
  assert.equal(r.c.diffLines, 0, JSON.stringify(r.c));
  assert.match(r.mockup, /Mockup chrome/);
  assert.match(r.app, /Mockup chrome/);

  // --root sets the mockup's side; --app-root still wins on the app's
  const both = await oracle(['--root', '#content', '--app-root', '#root']);
  assert.equal(both.code, 1, both.out);
  assert.match(both.mockup, /INV-0412/);
  assert.match(both.app, /Mockup chrome/);
});

test('--diff ignores edge whitespace and prints IDENTICAL; --diff --strict prints it; both exit 0', async () => {
  const m = join(TMP, 'm.html');
  const a = join(TMP, 'a.html');
  writeFileSync(m, '<button>Save</button>');
  writeFileSync(a, '<button> Save </button>');
  const loose = await run(['--diff', m, a]);
  assert.equal(loose.code, 0, loose.out);
  assert.match(loose.out, /^IDENTICAL$/m);
  assert.match(loose.out, /diff lines 0, edge lines 2$/m);
  const strict = await run(['--diff', m, a, '--strict']);
  assert.equal(strict.code, 0, strict.out);
  assert.doesNotMatch(strict.out, /^IDENTICAL$/m);
  assert.match(strict.out, /^-\s*T:Save$/m);
  assert.match(strict.out, /^\+\s*T: Save $/m);

  writeFileSync(a, '<button>Saved</button>');
  const real = await run(['--diff', m, a, '--strict']);
  assert.equal(real.code, 1, real.out);
});
