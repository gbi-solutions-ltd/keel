/**
 * perf-budget-served.test.mjs: the perf-budget.mjs paths that load pages (sweep F). --next on a
 * made-up .next build: each screen's served HTML names its initial scripts and stylesheets under
 * /_next/static, every other .js under .next/static is lazy, the record says build "next" with
 * buildSha the sha256 of BUILD_ID; a build whose env inlines MOCKS=true is over (exit 1); no
 * BUILD_ID, or --next without --url and --mockup, exits 2. --session: a page behind sign-in without
 * one ends on the sign-in page and exits 2; with a saved session (storageState) it is measured, in
 * --next and in vitals. Vitals (--url with --dist): over the LCP budget warns when the budget does
 * not gate, and fails (exit 1) when it does. The app is a small server on 127.0.0.1. Launches a
 * browser. Run: node --test test/perf-budget-served.test.mjs   (from scripts/)
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const PERF = fileURLToPath(new URL('../perf-budget.mjs', import.meta.url));
const run = (args) => new Promise((done) => {
  const p = spawn(process.execPath, [PERF, ...args]);
  let out = '';
  p.stdout.on('data', (d) => { out += d; });
  p.stderr.on('data', (d) => { out += d; });
  p.on('close', (code) => done({ code, out }));
});
const noise = (n, salt = 1) => Array.from({ length: n }, (_, i) => `const v${i}=${(i * 7919 * salt) % 104729};`).join('');
const sha = (b) => createHash('sha256').update(b).digest('hex');

const TMP = mkdtempSync(join(tmpdir(), 'perf-served-'));
const w = (f, c) => { mkdirSync(dirname(join(TMP, f)), { recursive: true }); writeFileSync(join(TMP, f), c); return join(TMP, f); };

// A Next.js server build: chunks/main.js and css/app.css are named by the page, chunks/lazy.js is not.
const NEXT = join(TMP, 'app', '.next');
w('app/.next/BUILD_ID', 'build-abc123');
w('app/.next/static/chunks/main.js', noise(300));
w('app/.next/static/chunks/lazy.js', noise(200, 3));
w('app/.next/static/css/app.css', `.a{color:red}${'.b{margin:0}'.repeat(50)}`);
// A Vite build for the vitals runs.
const DIST = join(TMP, 'vite', 'dist');
w('vite/dist/index.html', '<!doctype html><script type="module" src="/assets/entry.js"></script>');
w('vite/dist/assets/entry.js', noise(100));

const MOCKUP = join(TMP, 'mockup');
w('mockup/mockup.config.json', JSON.stringify({
  viewports: [{ name: 'desktop', width: 1024, height: 768 }, { name: 'mobile', width: 390, height: 844 }],
  screens: [{ name: 'invoices', page: 'invoices.html', route: '/invoices' }, { name: 'stepped', page: 'x.html', route: '/stepped', steps: [{ click: { role: 'button', name: 'x' } }] }],
}));
const budget = (b) => w(`budget-${sha(JSON.stringify(b)).slice(0, 8)}.json`, JSON.stringify(b));
const BUNDLE = { initialJsKb: 50, initialCssKb: 10, lazyChunkKb: 50 };

const PAGE = '<!doctype html><html lang="en"><head><title>Invoices</title><link rel="stylesheet" href="/_next/static/css/app.css"></head>'
  + '<body><h1 style="font-size:48px">Invoices for this month</h1><p>INV-0412 and the rest of the list.</p>'
  + '<script src="/_next/static/chunks/main.js?v=1" async></script></body></html>';
const SIGN_IN = '<!doctype html><html lang="en"><head><title>Sign in</title></head><body><h1>Sign in</h1></body></html>';
let server, base, locked = false;
before(async () => {
  server = createServer((q, res) => {
    const path = q.url.split('?')[0];
    const signedIn = /(^|;\s*)sid=ok(;|$)/.test(q.headers.cookie || '');
    if (path === '/invoices') {
      if (locked && !signedIn) return res.writeHead(302, { location: '/sign-in' }).end();
      return res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }).end(PAGE);
    }
    if (path === '/sign-in') return res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }).end(SIGN_IN);
    if (path.startsWith('/_next/static/')) {
      try { return res.writeHead(200, { 'content-type': path.endsWith('.css') ? 'text/css' : 'text/javascript' }).end(readFileSync(join(NEXT, 'static', path.slice('/_next/static/'.length)))); } catch { /* 404 below */ }
    }
    res.writeHead(404).end('not found');
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => { server.close(); rmSync(TMP, { recursive: true, force: true }); });

const SESSION = w('session.json', JSON.stringify({ cookies: [{ name: 'sid', value: 'ok', domain: '127.0.0.1', path: '/', expires: -1, httpOnly: true, secure: false, sameSite: 'Lax' }], origins: [] }));

test('--next: the initial load is what the served page names under /_next/static; the rest is lazy; the record is bound to BUILD_ID', { timeout: 120000 }, async () => {
  locked = false;
  const rec = join(TMP, 'next-record.json');
  const r = await run(['--budget', budget({ bundle: BUNDLE }), '--next', NEXT, '--url', base, '--mockup', MOCKUP, '--record', rec]);
  assert.equal(r.code, 0, r.out);
  assert.match(r.out, /^route \/invoices: initial JS [\d.]+ KB, CSS [\d.]+ KB gzip \(2 files\)$/m);
  assert.match(r.out, /^bundle: initial JS [\d.]+ KB, initial CSS [\d.]+ KB gzip \(2 files\); 1 lazy chunks, largest chunks\/lazy\.js [\d.]+ KB$/m);
  assert.match(r.out, /^perf-budget: within budget$/m);
  const j = JSON.parse(readFileSync(rec, 'utf8'));
  assert.equal(j.build, 'next');
  assert.equal(j.buildSha, sha(readFileSync(join(NEXT, 'BUILD_ID'))));
  assert.ok(j.bundle.initialJsKb > 0 && j.bundle.initialCssKb > 0, JSON.stringify(j.bundle));
  assert.deepEqual(j.bundle.lazy.map((c) => c.file), ['chunks/lazy.js']);
  // --url also measures vitals (one screen; the one with steps is left out)
  assert.deepEqual(j.vitals.map((v) => v.screen), ['invoices']);
});

test('--next: a lazy chunk over budget is over (exit 1)', { timeout: 120000 }, async () => {
  locked = false;
  const r = await run(['--budget', budget({ bundle: { ...BUNDLE, lazyChunkKb: 0.01 } }), '--next', NEXT, '--url', base, '--mockup', MOCKUP]);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /^over: lazy chunk chunks\/lazy\.js [\d.]+ KB gzip is over the budget of 0\.01 KB$/m);
  assert.doesNotMatch(r.out, /over: lazy chunk chunks\/main\.js/);
});

test('--next: a build whose env inlines MOCKS=true is refused as mocked (exit 1)', { timeout: 120000 }, async () => {
  locked = false;
  const f = w('app/.next/required-server-files.json', JSON.stringify({ config: { env: { MOCKS: 'true' } } }));
  try {
    const r = await run(['--budget', budget({ bundle: BUNDLE }), '--next', NEXT, '--url', base, '--mockup', MOCKUP]);
    assert.equal(r.code, 1, r.out);
    assert.match(r.out, /^over: this is the mocked build \(its env inlines MOCKS=true\)/m);
  } finally { rmSync(f); }
});

test('--next: no BUILD_ID, or no --url and --mockup, exits 2 before a browser', async () => {
  const empty = join(TMP, 'empty', '.next');
  mkdirSync(join(empty, 'static'), { recursive: true });
  const a = await run(['--budget', budget({ bundle: BUNDLE }), '--next', empty, '--url', base, '--mockup', MOCKUP]);
  assert.equal(a.code, 2, a.out);
  assert.match(a.out, /BUILD_ID not found/);
  const b = await run(['--budget', budget({ bundle: BUNDLE }), '--next', NEXT]);
  assert.equal(b.code, 2, b.out);
  assert.match(b.out, /--next measures the served pages: it needs --url and --mockup/);
});

test('--session: behind sign-in, no session ends on the sign-in page (exit 2); a saved session is measured', { timeout: 180000 }, async () => {
  locked = true;
  try {
    const none = await run(['--budget', budget({ bundle: BUNDLE }), '--next', NEXT, '--url', base, '--mockup', MOCKUP]);
    assert.equal(none.code, 2, none.out);
    assert.match(none.out, /\/invoices ended on \/sign-in, not the page: pass a signed-in --session/);
    const signed = await run(['--budget', budget({ bundle: BUNDLE }), '--next', NEXT, '--url', base, '--mockup', MOCKUP, '--session', SESSION]);
    assert.equal(signed.code, 0, signed.out);
    assert.match(signed.out, /^route \/invoices: initial JS/m);

    const vNone = await run(['--budget', budget({ bundle: BUNDLE, vitals: { lcpMs: 60000 } }), '--dist', DIST, '--url', base, '--mockup', MOCKUP, '--runs', '1']);
    assert.equal(vNone.code, 2, vNone.out);
    assert.match(vNone.out, /invoices: .*\/invoices ended on \/sign-in, not the page/);
    const vSigned = await run(['--budget', budget({ bundle: BUNDLE, vitals: { lcpMs: 60000 } }), '--dist', DIST, '--url', base, '--mockup', MOCKUP, '--runs', '1', '--session', SESSION]);
    assert.equal(vSigned.code, 0, vSigned.out);
    assert.match(vSigned.out, /^vitals: invoices at 390px/m);
  } finally { locked = false; }
});

test('vitals: the narrowest viewport, screens with steps left out; over LCP warns unless the budget gates, then it is over', { timeout: 180000 }, async () => {
  locked = false;
  const rec = join(TMP, 'vitals-record.json');
  const warn = await run(['--budget', budget({ bundle: BUNDLE, vitals: { lcpMs: 0, cls: 1 } }), '--dist', DIST, '--url', base, '--mockup', MOCKUP, '--runs', '1', '--record', rec]);
  assert.equal(warn.code, 0, warn.out);
  assert.match(warn.out, /^vitals: invoices at 390px, CPU 4x, median of 1: LCP \d+ ms, CLS [\d.]+$/m);
  assert.doesNotMatch(warn.out, /vitals: stepped/);
  assert.match(warn.out, /^warning: invoices: LCP \d+ ms is over 0 ms$/m);
  assert.match(warn.out, /^perf-budget: within budget$/m);
  const j = JSON.parse(readFileSync(rec, 'utf8'));
  assert.equal(j.vitals.length, 1);
  assert.equal(j.vitals[0].screen, 'invoices');
  assert.ok(j.vitals[0].lcpMs > 0, 'LCP was measured');
  assert.equal(j.warnings.length, 1);
  assert.equal(j.buildSha, sha(readFileSync(join(DIST, 'index.html'))));

  const gate = await run(['--budget', budget({ bundle: BUNDLE, vitals: { lcpMs: 0, gate: true } }), '--dist', DIST, '--url', base, '--mockup', MOCKUP, '--runs', '1']);
  assert.equal(gate.code, 1, gate.out);
  assert.match(gate.out, /^over: invoices: LCP \d+ ms is over 0 ms$/m);
});
