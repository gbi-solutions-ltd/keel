/**
 * production-bar-flags.test.mjs: production-bar.mjs's --gaps, --contract and --url (sweep F; the
 * --url nonce, {origin:VAR} and status cases are in production-bar-checks.test.mjs). --gaps: two gap
 * reports under docs/mockups are not met until one is named, and the named one is the one judged.
 * --contract: the staging record is held to the contract at that path in the app, not
 * api/openapi.yaml. --url: the served headers are checked now, instead of the recorded check (a
 * stale or missing headers.json does not matter), and a header the server leaves out is not met.
 * No browser; the served app is a small server on 127.0.0.1.
 * Run: node --test test/production-bar-flags.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { renderHeaders, sha256 } from '../lib/production.mjs';

const BAR = fileURLToPath(new URL('../production-bar.mjs', import.meta.url));
const run = (args) => new Promise((done) => {
  const p = spawn(process.execPath, [BAR, ...args]);
  let out = '';
  p.stdout.on('data', (d) => { out += d; });
  p.stderr.on('data', (d) => { out += d; });
  p.on('close', (code) => done({ code, out }));
});
const notMet = (out) => out.split('\n').filter((l) => l.startsWith('not met:'));

const HEADERS = { headers: {
  'Content-Security-Policy': ["default-src 'self'", "style-src 'self'", "frame-ancestors 'none'"],
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
} };
const CONTRACT = 'openapi: 3.1.0\ninfo: { title: x, version: 0.1.0 }\npaths:\n  /v1/items:\n    get: { responses: { "200": { description: ok } } }\n';
const INDEX = '<!doctype html><script type="module" src="/assets/a.js"></script>';
const GAPS = `# Gaps\n\n## Blocking go-live\n\n| # | Area | Gap | Source | Owner | By | Next step |\n|---|---|---|---|---|---|---|\n| 1 | Staging | real run owed | sample | backend | 2026-12-15 | run it |\n\n## Server-side enforcement the frontend assumes\n\n| Assumption | Owner | By | Status |\n|---|---|---|---|\n| CSRF checked | backend | 2026-12-15 | assumed |\n`;
// A blocking row with no owner: gapProblems flags it.
const GAPS_UNOWNED = GAPS.replace('| backend | 2026-12-15 | run it |', '|  |  | run it |');
const AUDIT = '# Security audit: x\n\n| | |\n|---|---|\n| Date | 2026-11-19 |\n| Findings | 0 critical, 0 high, 0 medium, 0 low |\n\n## Findings\n\nNone.\n\n## Not covered\n\n- CI\n';
const HANDOFF = '# Deploy handoff\n\n## Build command\n\nnpm run build\n\n## Environment variables\n\nnone public\n\n## Headers\n\nsecurity-headers.json, set by the host\n\n## Health check\n\nGET / answers 200\n';

/** An app whose every record holds; the staging record is on the contract at contractPath. */
function app({ contractPath = 'api/openapi.yaml' } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'bar-flags-'));
  const w = (f, c) => { mkdirSync(join(dir, f, '..'), { recursive: true }); writeFileSync(join(dir, f), c); };
  w('security-headers.json', JSON.stringify(HEADERS));
  w('dist/index.html', INDEX);
  w(contractPath, CONTRACT);
  w('docs/production/headers.json', JSON.stringify({ date: '2026-11-19T10:00:00Z', url: 'http://x/', ok: true, problems: [], headersSha: sha256(readFileSync(join(dir, 'security-headers.json'))) }));
  w('docs/production/perf.json', JSON.stringify({ date: '2026-11-19T10:00:00Z', buildSha: sha256(Buffer.from(INDEX)), bundle: { initialJsKb: 100, initialCssKb: 5, lazy: [] }, vitals: [{ screen: 'home', route: '/', lcpMs: 900, cls: 0 }], problems: [], warnings: [] }));
  w('docs/production/staging.json', JSON.stringify({ date: '2026-11-19T10:00:00Z', url: 'http://x', kind: 'backend', stub: false, contract: { file: contractPath, sha256: sha256(Buffer.from(CONTRACT)) }, build: { kind: 'vite', file: 'dist/index.html', sha256: sha256(Buffer.from(INDEX)) }, drift: { breaking: [], additive: [] }, flows: [{ name: 'sign in', ok: true, problems: [] }], ok: true }));
  w('docs/mockups/x/gaps.md', GAPS);
  w('docs/audits/2026-11-19-security.md', AUDIT);
  w('docs/production/deploy-handoff.md', HANDOFF);
  return { dir, w, done: () => rmSync(dir, { recursive: true, force: true }) };
}

test('the made-up app meets the bar with no flags', async () => {
  const a = app();
  try {
    const r = await run([a.dir]);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /^production bar: met \(6 items\)$/m);
  } finally { a.done(); }
});

test('--gaps: two gap reports are not met until one is named; the named one is the one judged', async () => {
  const a = app();
  try {
    a.w('docs/mockups/y/gaps.md', GAPS_UNOWNED);
    const two = await run([a.dir]);
    assert.equal(two.code, 1, two.out);
    assert.deepEqual(notMet(two.out), ['not met: gaps: 2 gap reports under docs/mockups; name one with --gaps']);

    const good = await run([a.dir, '--gaps', join(a.dir, 'docs/mockups/x/gaps.md')]);
    assert.equal(good.code, 0, good.out);
    assert.match(good.out, /^ok: gaps: 1 blocking and 1 enforcement rows, each owned and dated$/m);

    const bad = await run([a.dir, '--gaps', join(a.dir, 'docs/mockups/y/gaps.md')]);
    assert.equal(bad.code, 1, bad.out);
    const lines = notMet(bad.out);
    assert.equal(lines.length, 1, lines.join('\n'));
    assert.match(lines[0], /^not met: gaps: \d+ problems: /);
  } finally { a.done(); }
});

test('--gaps names a report outside docs/mockups too', async () => {
  const a = app();
  try {
    rmSync(join(a.dir, 'docs/mockups'), { recursive: true });
    const none = await run([a.dir]);
    assert.deepEqual(notMet(none.out), ['not met: gaps: no docs/mockups/<name>/gaps.md']);
    a.w('elsewhere/gaps.md', GAPS);
    const r = await run([a.dir, '--gaps', join(a.dir, 'elsewhere/gaps.md')]);
    assert.equal(r.code, 0, r.out);
  } finally { a.done(); }
});

test('--contract: the staging record is held to the contract at that path, not api/openapi.yaml', async () => {
  const a = app({ contractPath: 'spec/api.yaml' });
  try {
    const dflt = await run([a.dir]);
    assert.equal(dflt.code, 1, dflt.out);
    assert.deepEqual(notMet(dflt.out), ['not met: staging: the staging run was on another contract than the app\'s current one; run it again']);

    const named = await run([a.dir, '--contract', 'spec/api.yaml']);
    assert.equal(named.code, 0, named.out);
    assert.match(named.out, /^ok: staging: 1 flows passed on http:\/\/x, 2026-11-19$/m);

    a.w('spec/api.yaml', CONTRACT.replace('get:', 'post:'));
    const changed = await run([a.dir, '--contract', 'spec/api.yaml']);
    assert.equal(changed.code, 1, changed.out);
    assert.match(notMet(changed.out).join('\n'), /^not met: staging: the staging run was on another contract/);
  } finally { a.done(); }
});

/** A server on 127.0.0.1 answering every request with handler's headers. */
async function serve(headers) {
  const server = createServer((q, res) => res.writeHead(200, headers()).end('<!doctype html><title>x</title>'));
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  return { url: `http://127.0.0.1:${server.address().port}/`, close: () => new Promise((r) => server.close(r)) };
}

test('--url: the served headers are checked now, not the record; a header left out is not met', async () => {
  const a = app();
  const full = await serve(() => renderHeaders(HEADERS));
  const short = await serve(() => { const h = renderHeaders(HEADERS); delete h['Referrer-Policy']; delete h['referrer-policy']; return h; });
  try {
    // a record that would not be met (stale sha, not ok) is not read under --url
    a.w('docs/production/headers.json', JSON.stringify({ date: '2026-11-01T10:00:00Z', url: 'http://x/', ok: false, problems: ['old'], headersSha: 'stale' }));
    const stale = await run([a.dir]);
    assert.match(notMet(stale.out).join('\n'), /^not met: headers: security-headers\.json changed since the recorded check/);

    const r = await run([a.dir, '--url', full.url]);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, new RegExp(`^ok: headers: all match on ${full.url.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'm'));

    rmSync(join(a.dir, 'docs/production/headers.json'));
    const noRecord = await run([a.dir, '--url', full.url]);
    assert.equal(noRecord.code, 0, noRecord.out);

    const missing = await run([a.dir, '--url', short.url]);
    assert.equal(missing.code, 1, missing.out);
    const lines = notMet(missing.out);
    assert.equal(lines.length, 1, lines.join('\n'));
    assert.match(lines[0], /^not met: headers: .*Referrer-Policy/i);
  } finally { await full.close(); await short.close(); a.done(); }
});
