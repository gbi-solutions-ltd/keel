/**
 * production.test.mjs: the production bar's pieces with no browser (lib/production.mjs): the gap
 * report's owned and dated tables, the security headers from one file (render, check a served
 * response, emit nginx, refuse a nonce for a static host), and the contract diff. headers.mjs is run
 * against a local server. Run: node --test test/production.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { contractDiff, emitNginx, gapProblems, headerProblems, renderHeaders } from '../lib/production.mjs';

const HEADERS = fileURLToPath(new URL('../headers.mjs', import.meta.url));

const gaps = (blockingRows, enforcementRows) => `# Gaps: x

## Blocking go-live

| # | Area | Gap | Source | Owner | By | Next step |
|---|---|---|---|---|---|---|
${blockingRows.join('\n')}

## Server-side enforcement the frontend assumes

| Assumption | Owner | By | Status |
|---|---|---|---|
${enforcementRows.join('\n')}

## Not blocking

-
`;

test('gap report: every blocking and enforcement row has an owner and a date, and a known status', () => {
  const ok = gapProblems(gaps(['| 1 | Contract | draft | needs.api | backend | 2026-12-01 | agree |'], ['| CSRF checked | backend | 2026-12-01 | assumed |']));
  assert.deepEqual(ok, { problems: [], blocking: 1, enforcement: 1 });
  const bad = gapProblems(gaps(['| 1 | Contract | draft | needs.api | backend |  | agree |', '| 2 | IdP | not chosen | brief | {{owner}} | 2026-12 | pick |'], ['| CSRF checked | backend | 2026-12-01 | probably |']));
  assert.deepEqual(bad.problems, [
    'gaps: "Blocking go-live" row 1 (Contract): no date (By is "", want YYYY-MM-DD)',
    'gaps: "Blocking go-live" row 2 (IdP): no owner',
    'gaps: "Blocking go-live" row 2 (IdP): no date (By is "2026-12", want YYYY-MM-DD)',
    'gaps: "Server-side enforcement the frontend assumes" row 1 (CSRF checked): status "probably" is not assumed, confirmed by backend or verified on staging',
  ]);
  const old = gapProblems('# Gaps\n\n## Blocking go-live\n\n| # | Area | Gap | Source | Owner | Next step |\n|---|---|---|---|---|---|\n| 1 | a | b | c | d | e |\n');
  assert.ok(old.problems.includes('gaps: "Blocking go-live" has no By column'));
  assert.ok(old.problems.includes('gaps: no "## Server-side enforcement the frontend assumes" section'));
});

test('gap report: a By date must be a real calendar date (2026-02-30 is not)', () => {
  const r = gapProblems(gaps(['| 1 | Contract | draft | needs.api | backend | 2026-02-30 | agree |'], ['| CSRF checked | backend | 2026-02-28 | assumed |']));
  assert.deepEqual(r.problems, ['gaps: "Blocking go-live" row 1 (Contract): no date (By is "2026-02-30", want YYYY-MM-DD)']);
});

const SPEC = { headers: {
  'Content-Security-Policy': ["default-src 'self'", "script-src 'self'", "style-src 'self'", "connect-src 'self' {origin:OTEL}", "frame-ancestors 'none'"],
  'X-Content-Type-Options': 'nosniff',
} };
// kit-react's policy: a CSS-in-JS kit styles under a per-response nonce (stacks/react-vite.md).
const NONCE_SPEC = { headers: { 'Content-Security-Policy': ["default-src 'self'", "style-src 'self' {nonce}"], 'X-Content-Type-Options': 'nosniff' } };

test('headers: rendered with origins from the environment; a served response matches or names each problem', () => {
  const h = renderHeaders(SPEC, { env: { OTEL: 'https://otel.example.org:4318/v1/traces' } });
  assert.equal(h['Content-Security-Policy'], "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self' https://otel.example.org:4318; frame-ancestors 'none'");
  assert.equal(renderHeaders(SPEC)['Content-Security-Policy'].includes("connect-src 'self';"), true, 'an unset origin leaves the directive clean');
  assert.equal(renderHeaders(SPEC, { env: { OTEL: '/collector' } })['Content-Security-Policy'].includes("connect-src 'self';"), true, 'a path on this origin is covered by self');
  assert.deepEqual(headerProblems(SPEC, renderHeaders(SPEC)), []);
  assert.deepEqual(headerProblems(SPEC, { 'content-security-policy': renderHeaders(SPEC)['Content-Security-Policy'] }), ['header X-Content-Type-Options: missing']);
  const loose = { ...renderHeaders(SPEC), 'Content-Security-Policy': "default-src 'self'; style-src 'self' 'unsafe-inline'" };
  assert.match(headerProblems(SPEC, loose)[0], /^header Content-Security-Policy: ".*'unsafe-inline'" is not /);
});

test('headers: a nonce matches any fresh value, refuses a short or reused one, and cannot be emitted for a static host', () => {
  const served = (n) => renderHeaders(NONCE_SPEC, { nonce: n });
  assert.deepEqual(headerProblems(NONCE_SPEC, served('r4nd0mN0nceV4lue12345')), []);
  assert.match(headerProblems(NONCE_SPEC, served('short'))[0], /with a nonce of at least 16 characters/);
  assert.match(headerProblems(NONCE_SPEC, { ...served('x'.repeat(20)), 'Content-Security-Policy': "default-src 'self'; style-src 'self'" })[0], /does not match/);
  assert.throws(() => emitNginx(NONCE_SPEC), /per-response nonce, which a static nginx config cannot write/);
  assert.equal(emitNginx({ headers: { 'X-Content-Type-Options': 'nosniff' } }), 'add_header X-Content-Type-Options "nosniff" always;\n');
});

test('headers.mjs --check against a served URL: ok, then a missing header fails with its line and the record says so', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'headers-'));
  let serveAll = true;
  const server = createServer((req, res) => {
    const h = renderHeaders(SPEC);
    if (!serveAll) delete h['X-Content-Type-Options'];
    res.writeHead(200, { ...h, 'content-type': 'text/html' }).end('<!doctype html>');
  });
  await new Promise((r) => server.listen(0, r));
  const url = `http://127.0.0.1:${server.address().port}/`;
  const run = (...a) => new Promise((done) => { const p = spawn(process.execPath, [HEADERS, ...a], { env: { ...process.env, OTEL: '' } }); let out = ''; p.stdout.on('data', (d) => { out += d; }); p.stderr.on('data', (d) => { out += d; }); p.on('close', (code) => done({ code, out })); });
  try {
    writeFileSync(join(dir, 'h.json'), JSON.stringify(SPEC));
    const ok = await run(join(dir, 'h.json'), '--check', url, '--record', join(dir, 'rec.json'));
    assert.equal(ok.code, 0, ok.out);
    assert.match(ok.out, /headers: all 2 match/);
    serveAll = false;
    const bad = await run(join(dir, 'h.json'), '--check', url, '--record', join(dir, 'rec.json'));
    assert.equal(bad.code, 1);
    assert.match(bad.out, /not ok: header X-Content-Type-Options: missing/);
    assert.equal(JSON.parse(readFileSync(join(dir, 'rec.json'), 'utf8')).ok, false);
  } finally { server.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('contract diff: removals, type changes, new required fields and removed enum values are breaking; additions are not', () => {
  const before = { paths: { '/v1/invoices': { get: {}, post: {} } }, components: { schemas: {
    Invoice: { type: 'object', required: ['id'], properties: { id: { type: 'string' }, amount: { type: 'integer' }, status: { type: 'string', enum: ['open', 'paid'] } } },
    Old: { type: 'object' },
  } } };
  const after = { paths: { '/v1/invoices': { get: {} }, '/v1/exports': { post: {} } }, components: { schemas: {
    Invoice: { type: 'object', required: ['id', 'currency'], properties: { id: { type: 'string' }, amount: { type: 'string' }, status: { type: 'string', enum: ['open', 'void'] }, currency: { type: 'string' } } },
    New: { type: 'object' },
  } } };
  const d = contractDiff(before, after);
  assert.deepEqual(d.breaking.sort(), [
    'operation POST /v1/invoices removed',
    'schema Invoice: currency is now required',
    'schema Invoice: property amount changed from "integer" to "string"',
    'schema Invoice: status value paid removed',
    'schema Old removed',
  ]);
  assert.ok(d.additive.includes('operation POST /v1/exports added'));
  assert.ok(d.additive.includes('schema Invoice: status value void added (the UI must show a value it does not know)'));
  assert.deepEqual(contractDiff(before, before), { breaking: [], additive: [] });
});

test('perf-budget: the initial load follows index.html and static imports; lazy chunks apart; over budget fails; a mocked build is refused', async () => {
  const PERF = fileURLToPath(new URL('../perf-budget.mjs', import.meta.url));
  const dir = mkdtempSync(join(tmpdir(), 'perf-'));
  const dist = join(dir, 'dist');
  const { mkdirSync } = await import('node:fs');
  mkdirSync(join(dist, 'assets'), { recursive: true });
  const noise = (n) => Array.from({ length: n }, (_, i) => `const v${i}=${(i * 7919) % 104729};`).join('');
  writeFileSync(join(dist, 'index.html'), '<!doctype html><script type="module" src="/assets/entry.js"></script><link rel="stylesheet" href="/assets/app.css">');
  writeFileSync(join(dist, 'assets/entry.js'), `import{a}from"./shared.js";${noise(400)}const r=()=>import("./lazy.js");`);
  writeFileSync(join(dist, 'assets/shared.js'), `export const a=1;${noise(200)}`);
  writeFileSync(join(dist, 'assets/lazy.js'), noise(3000));
  writeFileSync(join(dist, 'assets/app.css'), '.a{color:red}');
  const run = (budget, ...more) => {
    writeFileSync(join(dir, 'budget.json'), JSON.stringify(budget));
    return new Promise((done) => { const p = spawn(process.execPath, [PERF, '--budget', join(dir, 'budget.json'), '--dist', dist, '--record', join(dir, 'rec.json'), ...more]); let out = ''; p.stdout.on('data', (d) => { out += d; }); p.stderr.on('data', (d) => { out += d; }); p.on('close', (code) => done({ code, out })); });
  };
  try {
    const ok = await run({ bundle: { initialJsKb: 50, initialCssKb: 5, lazyChunkKb: 50 } });
    assert.equal(ok.code, 0, ok.out);
    assert.match(ok.out, /bundle: initial JS [\d.]+ KB, initial CSS [\d.]+ KB gzip \(3 files\); 1 lazy chunks, largest assets\/lazy\.js/);
    const rec = JSON.parse(readFileSync(join(dir, 'rec.json'), 'utf8'));
    assert.deepEqual(rec.bundle.lazy.map((c) => c.file), ['assets/lazy.js']);
    const tight = await run({ bundle: { initialJsKb: 50, lazyChunkKb: 0.5 } });
    assert.equal(tight.code, 1);
    assert.match(tight.out, /over: lazy chunk assets\/lazy\.js [\d.]+ KB gzip is over the budget of 0\.5 KB/);
    writeFileSync(join(dist, 'mockServiceWorker.js'), '/* msw */');
    assert.match((await run({ bundle: { initialJsKb: 50 } })).out, /carries the mock service worker/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
