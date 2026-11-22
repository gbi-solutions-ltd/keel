/**
 * headers.test.mjs: headers.mjs --check (sweep B11): a policy with {nonce} is fetched twice and a nonce
 * the same on both responses fails (a hard-coded nonce); a non-2xx answer fails, and the record
 * says which status it saw. Run: node --test test/headers.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { renderHeaders, sessionCookie } from '../lib/production.mjs';

const HEADERS = fileURLToPath(new URL('../headers.mjs', import.meta.url));
const run = (...a) => new Promise((done) => { const p = spawn(process.execPath, [HEADERS, ...a]); let out = ''; p.stdout.on('data', (d) => { out += d; }); p.stderr.on('data', (d) => { out += d; }); p.on('close', (code) => done({ code, out })); });
const SPEC = { headers: { 'Content-Security-Policy': ["default-src 'self'", "script-src 'self' {nonce}"], 'X-Content-Type-Options': 'nosniff' } };

async function withServer(handler, fn) {
  const server = createServer(handler);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const dir = mkdtempSync(join(tmpdir(), 'headers-b11-'));
  writeFileSync(join(dir, 'h.json'), JSON.stringify(SPEC));
  try { return await fn(`http://127.0.0.1:${server.address().port}/`, dir); } finally { server.close(); rmSync(dir, { recursive: true, force: true }); }
}

test('a nonce the same on two responses fails; a fresh one each time passes', async () => {
  await withServer((q, res) => res.writeHead(200, renderHeaders(SPEC, { nonce: 'hardcodedNonceValue123' })).end('x'), async (url, dir) => {
    const r = await run(join(dir, 'h.json'), '--check', url);
    assert.equal(r.code, 1, r.out);
    assert.match(r.out, /not ok: the nonce is the same on two responses \(hard-coded\?\)/);
  });
  let n = 0;
  await withServer((q, res) => res.writeHead(200, renderHeaders(SPEC, { nonce: `freshNonceValue${String(++n).padStart(4, '0')}` })).end('x'), async (url, dir) => {
    const r = await run(join(dir, 'h.json'), '--check', url);
    assert.equal(r.code, 0, r.out);
  });
});

test('a non-2xx answer fails, with its status in the record', async () => {
  const spec = { headers: { 'X-Content-Type-Options': 'nosniff' } };
  await withServer((q, res) => res.writeHead(302, { ...renderHeaders(spec), location: '/sign-in' }).end(), async (url, dir) => {
    writeFileSync(join(dir, 'h.json'), JSON.stringify(spec));
    const r = await run(join(dir, 'h.json'), '--check', url, '--record', join(dir, 'rec.json'));
    assert.equal(r.code, 1, r.out);
    assert.match(r.out, /not ok: .* answered 302, not 2xx/);
    const rec = JSON.parse(readFileSync(join(dir, 'rec.json'), 'utf8'));
    assert.deepEqual([rec.ok, rec.status], [false, 302]);
  });
});

test('an empty headers set, an unreachable URL, and --record with --emit cannot run: exit 2', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'headers-exit-'));
  try {
    writeFileSync(join(dir, 'empty.json'), JSON.stringify({ headers: {} }));
    for (const mode of [['--emit', 'nginx'], ['--check', 'http://127.0.0.1:9/']]) {
      const r = await run(join(dir, 'empty.json'), ...mode);
      assert.equal(r.code, 2, `${mode[0]}: ${r.out}`);
      assert.match(r.out, /headers: .*empty\.json: names no header/);
      assert.doesNotMatch(r.out, /all 0 match/);
    }
    writeFileSync(join(dir, 'h.json'), JSON.stringify(SPEC));
    const down = await run(join(dir, 'h.json'), '--check', 'http://127.0.0.1:9/', '--record', join(dir, 'rec.json'));
    assert.equal(down.code, 2, down.out);
    assert.match(down.out, /headers: could not fetch http:\/\/127\.0\.0\.1:9\//);
    const rec = await run(join(dir, 'h.json'), '--emit', 'nginx', '--record', join(dir, 'rec.json'));
    assert.equal(rec.code, 2, rec.out);
    assert.match(rec.out, /--record applies to --check only/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('--session: a page behind sign-in is checked with the saved session; without it, the redirect fails', async () => {
  const spec = { headers: { 'X-Content-Type-Options': 'nosniff' } };
  const handler = (q, res) => (/(^|; )session=s1(;|$)/.test(q.headers.cookie ?? '') ? res.writeHead(200, renderHeaders(spec)).end('page') : res.writeHead(302, { location: '/sign-in' }).end());
  await withServer(handler, async (url, dir) => {
    writeFileSync(join(dir, 'h.json'), JSON.stringify(spec));
    const { hostname } = new URL(url);
    const state = { cookies: [{ name: 'session', value: 's1', domain: hostname, path: '/', expires: -1, httpOnly: true, secure: true, sameSite: 'Lax' }], origins: [] };
    writeFileSync(join(dir, 'session.json'), JSON.stringify(state));
    assert.equal((await run(join(dir, 'h.json'), '--check', url)).code, 1, 'no session: the 302 fails');
    const signed = await run(join(dir, 'h.json'), '--check', url, '--session', join(dir, 'session.json'));
    assert.equal(signed.code, 0, signed.out);
    writeFileSync(join(dir, 'other.json'), JSON.stringify({ cookies: [{ ...state.cookies[0], domain: 'api.example.com' }] }));
    const other = await run(join(dir, 'h.json'), '--check', url, '--session', join(dir, 'other.json'));
    assert.equal(other.code, 2, other.out);
    assert.match(other.out, /no live cookie in it for/);
    const emit = await run(join(dir, 'h.json'), '--emit', 'nginx', '--session', join(dir, 'session.json'));
    assert.equal(emit.code, 2, emit.out);
    assert.match(emit.out, /--session applies to --check only/);
  });
});

test('sessionCookie: domain, path, expiry and Secure the way a browser sends them', () => {
  const c = (o) => ({ name: 'n', value: 'v', domain: 'app.example.com', path: '/', expires: -1, secure: true, ...o });
  const state = (...cookies) => ({ cookies });
  assert.equal(sessionCookie(state(c()), 'https://app.example.com/x'), 'n=v');
  assert.equal(sessionCookie(state(c()), 'http://app.example.com/x'), '', 'Secure stays off plain http');
  assert.equal(sessionCookie(state(c({ domain: '127.0.0.1' })), 'http://127.0.0.1:4320/x'), 'n=v', 'loopback counts as secure');
  assert.equal(sessionCookie(state(c({ domain: '.example.com' })), 'https://app.example.com/'), 'n=v', 'a parent domain cookie');
  assert.equal(sessionCookie(state(c({ domain: 'example.com' })), 'https://app.example.com/'), '', 'a host-only cookie of the parent');
  assert.equal(sessionCookie(state(c({ path: '/api' })), 'https://app.example.com/deliveries'), '');
  assert.equal(sessionCookie(state(c({ expires: 1 })), 'https://app.example.com/'), '', 'expired');
  assert.equal(sessionCookie(state(c(), c({ name: 'm', value: 'w' })), 'https://app.example.com/'), 'n=v; m=w');
});
