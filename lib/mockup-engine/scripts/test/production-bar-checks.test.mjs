/**
 * production-bar-checks.test.mjs: production-bar.mjs refuses records that go green without measuring
 * (sweep A1, B11). A made-up app that meets the bar, then one plant per hole, each failing with its
 * own line: gap tables with no rows (an explicit "None" passes), an empty gap report, a zero-byte or
 * hand-written audit, an open high finding (a closed one passes), an empty or weak headers file, a
 * CI workflow that deploys nothing, a handoff of bare headings, perf records with no vitals or no
 * initial JS. With --url: {origin:VAR} filled from the environment, a hard-coded nonce, a non-2xx
 * answer. The staging record bound to the build (a rebuilt app is not met; an old record is a note).
 * No browser. Run: node --test test/production-bar-checks.test.mjs   (from scripts/)
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
const run = (args, env = {}) => new Promise((done) => { const p = spawn(process.execPath, [BAR, ...args], { env: { ...process.env, ...env } }); let out = ''; p.stdout.on('data', (d) => { out += d; }); p.stderr.on('data', (d) => { out += d; }); p.on('close', (code) => done({ code, out })); });
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
const AUDIT = (findings, body = '') => `# Security audit: x\n\n| | |\n|---|---|\n| Date | 2026-11-19 |\n| Findings | ${findings} |\n\n## Findings\n\n${body}\n## Not covered\n\n- CI\n`;
const HANDOFF = '# Deploy handoff\n\n## Build command\n\nnpm run build\n\n## Environment variables\n\nnone public\n\n## Headers\n\nsecurity-headers.json, set by the host\n\n## Health check\n\nGET / answers 200\n';

function madeUpApp() {
  const app = mkdtempSync(join(tmpdir(), 'bar-checks-'));
  const w = (f, c) => { mkdirSync(join(app, f, '..'), { recursive: true }); writeFileSync(join(app, f), c); };
  w('security-headers.json', JSON.stringify(HEADERS));
  w('dist/index.html', INDEX);
  w('api/openapi.yaml', CONTRACT);
  w('docs/production/headers.json', JSON.stringify({ date: '2026-11-19T10:00:00Z', url: 'http://x/', ok: true, problems: [], headersSha: sha256(readFileSync(join(app, 'security-headers.json'))) }));
  w('docs/production/perf.json', JSON.stringify({ date: '2026-11-19T10:00:00Z', buildSha: sha256(Buffer.from(INDEX)), bundle: { initialJsKb: 100, initialCssKb: 5, lazy: [] }, vitals: [{ screen: 'home', route: '/', lcpMs: 900, cls: 0 }], problems: [], warnings: [] }));
  w('docs/production/staging.json', JSON.stringify({ date: '2026-11-19T10:00:00Z', url: 'http://x', kind: 'sample', stub: false, sampleStats: { requests: 3 }, contract: { file: 'api/openapi.yaml', sha256: sha256(Buffer.from(CONTRACT)) }, build: { kind: 'vite', file: 'dist/index.html', sha256: sha256(Buffer.from(INDEX)) }, drift: { breaking: [], additive: [] }, flows: [{ name: 'sign in', ok: true, problems: [] }], ok: true }));
  w('docs/mockups/x/gaps.md', GAPS);
  w('docs/audits/2026-11-19-security.md', AUDIT('0 critical, 0 high, 1 medium, 0 low', '### M-01 Something\n\n| | |\n|---|---|\n| Severity | Medium |\n\nOpen, listed as a gap.\n\n'));
  w('docs/production/deploy-handoff.md', HANDOFF);
  return { app, w, edit: (f, fn) => w(f, JSON.stringify(fn(JSON.parse(readFileSync(join(app, f), 'utf8'))))) };
}
const rehash = (a) => a.edit('docs/production/headers.json', (r) => ({ ...r, headersSha: sha256(readFileSync(join(a.app, 'security-headers.json'))) }));

async function expectOne(name, plant, want) {
  const a = madeUpApp();
  try {
    const { args = [], env, after } = (await plant(a)) || {};
    const r = await run([a.app, ...args], env);
    after?.();
    const lines = notMet(r.out);
    if (want === 'met') { assert.equal(r.code, 0, `${name}: ${r.out}`); return r; }
    assert.equal(r.code, 1, `${name}: ${r.out}`);
    assert.equal(lines.length, 1, `${name}: ${lines.join('\n')}`);
    assert.match(lines[0], want, name);
    return r;
  } finally { rmSync(a.app, { recursive: true, force: true }); }
}

test('the made-up app meets the bar, bound to its build', async () => {
  const r = await expectOne('baseline', () => {}, 'met');
  assert.match(r.out, /^production bar: met \(6 items\)$/m);
  assert.doesNotMatch(r.out, /unbound/);
});

test('A1 gaps: tables with no rows, or an empty file, are not met; an explicit None is', async () => {
  const empty = GAPS.replace(/\| 1 \| Staging.*\n/, '').replace(/\| CSRF checked.*\n/, '');
  await expectOne('no rows', (a) => { a.w('docs/mockups/x/gaps.md', empty); }, /^not met: gaps: .*"Blocking go-live" has no rows.*"Server-side enforcement the frontend assumes" has no rows/);
  await expectOne('empty file', (a) => { a.w('docs/mockups/x/gaps.md', ''); }, /^not met: gaps: /);
  await expectOne('None', (a) => { a.w('docs/mockups/x/gaps.md', '# Gaps\n\n## Blocking go-live\n\nNone\n\n## Server-side enforcement the frontend assumes\n\nNone.\n'); }, 'met');
});

test('A1 security: a zero-byte or hand-written audit and an open high finding are not met; a closed one is', async () => {
  await expectOne('zero bytes', (a) => { a.w('docs/audits/2026-11-19-security.md', ''); }, /^not met: security: docs\/audits\/2026-11-19-security\.md is not a keel security-audit report \(no "\| Findings \| N critical, N high" row\)/);
  await expectOne('hand-written', (a) => { a.w('docs/audits/2026-11-19-security.md', '# Security audit: x\n\nLooks fine.\n'); }, /^not met: security: .*no "\| Findings \| N critical, N high" row/);
  const high = '### H-01 Tokens in the log\n\n| | |\n|---|---|\n| Severity | High |\n\n**What.** x\n\n';
  await expectOne('open high', (a) => { a.w('docs/audits/2026-11-19-security.md', AUDIT('0 critical, 1 high, 0 medium, 0 low', high)); }, /^not met: security: 1 critical or high finding open: H-01 Tokens in the log/);
  await expectOne('counted but not written', (a) => { a.w('docs/audits/2026-11-19-security.md', AUDIT('1 critical, 0 high, 0 medium, 0 low')); }, /^not met: security: .*counts 1 critical or high, 0 written out/);
  await expectOne('closed high', (a) => { a.w('docs/audits/2026-11-19-security.md', AUDIT('0 critical, 1 high, 0 medium, 0 low', `${high}**Closed** after the audit: fixed, with a test.\n\n`)); }, 'met');
});

test('A1 headers: an empty headers file and one short of the minimum set are not met', async () => {
  await expectOne('empty', (a) => { a.w('security-headers.json', '{"headers":{}}'); rehash(a); }, /^not met: headers: security-headers\.json lacks the minimum set: no Content-Security-Policy; no X-Content-Type-Options: nosniff; no Referrer-Policy; no Strict-Transport-Security/);
  await expectOne('unsafe-inline', (a) => {
    a.w('security-headers.json', JSON.stringify({ headers: { ...HEADERS.headers, 'Content-Security-Policy': ["default-src 'self'", "style-src 'self' 'unsafe-inline'"] } })); rehash(a);
  }, /^not met: headers: security-headers\.json lacks the minimum set: Content-Security-Policy allows 'unsafe-inline'$/);
  await expectOne('no HSTS max-age', (a) => {
    const h = { ...HEADERS.headers, 'Strict-Transport-Security': 'max-age=0' }; a.w('security-headers.json', JSON.stringify({ headers: h })); rehash(a);
  }, /^not met: headers: security-headers\.json lacks the minimum set: Strict-Transport-Security has no max-age above 0$/);
});

test('A1 deploy: a CI workflow that deploys nothing does not count, one that deploys does; bare handoff headings are not met', async () => {
  const ci = (yml) => (a) => { rmSync(join(a.app, 'docs/production/deploy-handoff.md')); a.w('.github/workflows/ci.yml', yml); };
  await expectOne('tests only', ci('name: ci\non: push\njobs:\n  test:\n    runs-on: ubuntu-latest\n    steps:\n      - run: npm test\n'), /^not met: deploy: no CI definition that deploys \(\.github\/workflows has no deploy job or step\), no docs\/runbooks\/deploy\.md and no docs\/production\/deploy-handoff\.md$/);
  await expectOne('a release trigger', ci('name: ci\non:\n  release:\n    types: [published]\njobs:\n  test:\n    steps:\n      - run: npm test\n'), /^not met: deploy: no CI definition that deploys/);
  await expectOne('deploy only in a comment', ci('jobs:\n  test:\n    steps:\n      # deploy comes later\n      - run: npm test # not a deploy\n'), /^not met: deploy: no CI definition that deploys/);
  await expectOne('an empty runbook', (a) => { rmSync(join(a.app, 'docs/production/deploy-handoff.md')); a.w('docs/runbooks/deploy.md', '# Deploy\n\n## Steps\n'); }, /^not met: deploy: no CI definition, no docs\/runbooks\/deploy\.md and no /);
  await expectOne('a runbook', (a) => { rmSync(join(a.app, 'docs/production/deploy-handoff.md')); a.w('docs/runbooks/deploy.md', '# Deploy\n\nPush to main; the pipeline deploys.\n'); }, 'met');
  await expectOne('deploys', ci('name: release\non: push\njobs:\n  deploy:\n    runs-on: ubuntu-latest\n    steps:\n      - run: npm run build\n      - run: rsync -a dist/ host:/srv/app\n'), 'met');
  await expectOne('tests-only CI falls through to the handoff', (a) => { a.w('.github/workflows/ci.yml', 'jobs:\n  test:\n    steps:\n      - run: npm test\n'); }, 'met');
  await expectOne('bare headings', (a) => { a.w('docs/production/deploy-handoff.md', '# Deploy handoff\n\n## Build command\n\n## Environment variables\n\n## Headers\n\n## Health check\n'); }, /^not met: deploy: deploy-handoff\.md has an empty section for build command, environment variables, headers, health check$/);
});

test('A1 performance: a record with no vitals screen or no initial JS is not met', async () => {
  await expectOne('vitals []', (a) => { a.edit('docs/production/perf.json', (p) => ({ ...p, vitals: [] })); }, /^not met: performance: the record measured vitals on no screen/);
  await expectOne('initial JS 0', (a) => { a.edit('docs/production/perf.json', (p) => ({ ...p, bundle: { ...p.bundle, initialJsKb: 0 } })); }, /^not met: performance: the record measured no initial JS/);
});

async function serve(handler) {
  const server = createServer(handler);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  return { url: `http://127.0.0.1:${server.address().port}/`, close: () => server.close() };
}

test('B11 --url: {origin:VAR} is filled from the environment, as headers.mjs does', async () => {
  const spec = { headers: { ...HEADERS.headers, 'Content-Security-Policy': ["default-src 'self'", "connect-src 'self' {origin:API_BASE}"] } };
  const s = await serve((q, res) => res.writeHead(200, renderHeaders(spec, { env: { API_BASE: 'https://api.example.org/v1' } })).end('x'));
  await expectOne('origin', (a) => { a.w('security-headers.json', JSON.stringify(spec)); rehash(a); return { args: ['--url', s.url], env: { API_BASE: 'https://api.example.org/v1' }, after: s.close }; }, 'met');
});

test('B11 --url: a nonce the same on two responses, and a non-2xx answer, are not met', async () => {
  const spec = { headers: { ...HEADERS.headers, 'Content-Security-Policy': ["default-src 'self'", "script-src 'self' {nonce}"] } };
  const fixed = await serve((q, res) => res.writeHead(200, renderHeaders(spec, { nonce: 'hardcodedNonceValue123' })).end('x'));
  await expectOne('fixed nonce', (a) => { a.w('security-headers.json', JSON.stringify(spec)); rehash(a); return { args: ['--url', fixed.url], after: fixed.close }; }, /^not met: headers: the nonce is the same on two responses \(hard-coded\?\)/);
  let n = 0;
  const fresh = await serve((q, res) => res.writeHead(200, renderHeaders(spec, { nonce: `freshNonceValue${String(++n).padStart(4, '0')}` })).end('x'));
  await expectOne('fresh nonce', (a) => { a.w('security-headers.json', JSON.stringify(spec)); rehash(a); return { args: ['--url', fresh.url], after: fresh.close }; }, 'met');
  const missing = await serve((q, res) => res.writeHead(404, renderHeaders(HEADERS)).end('x'));
  await expectOne('404', () => ({ args: ['--url', missing.url], after: missing.close }), /^not met: headers: .* answered 404, not 2xx/);
});

test('B11 staging: the record is bound to the build; a rebuilt app is not met; a record with no build is a note', async () => {
  await expectOne('rebuilt', (a) => {
    a.w('dist/index.html', INDEX.replace('a.js', 'b.js'));
    a.edit('docs/production/perf.json', (p) => ({ ...p, buildSha: sha256(Buffer.from(INDEX.replace('a.js', 'b.js'))) }));
  }, /^not met: staging: the staging run was of another build than the current one \(dist\/index\.html differs\); run it again$/);
  const r = await expectOne('unbound', (a) => { a.edit('docs/production/staging.json', (s) => { delete s.build; return s; }); }, 'met');
  assert.match(r.out, /^note: staging: unbound: the record names no build/m);
});
