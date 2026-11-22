/**
 * production-bar.test.mjs: production-bar.mjs on a made-up app whose records all hold, then six
 * plants, each failing with its own line: a header missing on the served origin, a bundle over
 * budget, a blocking gap with no date, the live contract drifted, a staging run on an older
 * contract, no security audit. A Next.js build matched by its BUILD_ID. Also staging-run.mjs
 * stopping on breaking drift before any flow.
 * No browser except where staging-run would need one (it stops first). Run: node --test test/production-bar.test.mjs
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { renderHeaders, sha256 } from '../lib/production.mjs';

const BAR = fileURLToPath(new URL('../production-bar.mjs', import.meta.url));
const STAGING = fileURLToPath(new URL('../staging-run.mjs', import.meta.url));
const run = (script, ...a) => new Promise((done) => { const p = spawn(process.execPath, [script, ...a]); let out = ''; p.stdout.on('data', (d) => { out += d; }); p.stderr.on('data', (d) => { out += d; }); p.on('close', (code) => done({ code, out })); });
const notMet = (out) => out.split('\n').filter((l) => l.startsWith('not met:'));

const HEADERS = { headers: { 'Content-Security-Policy': ["default-src 'self'", "style-src 'self'"], 'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'strict-origin-when-cross-origin', 'Strict-Transport-Security': 'max-age=31536000' } };
const CONTRACT = 'openapi: 3.1.0\ninfo: { title: x, version: 0.1.0 }\npaths:\n  /v1/items:\n    get: { responses: { "200": { description: ok } } }\ncomponents:\n  schemas:\n    Item: { type: object, required: [id], properties: { id: { type: string } } }\n';
const GAPS = (by) => `# Gaps\n\n## Blocking go-live\n\n| # | Area | Gap | Source | Owner | By | Next step |\n|---|---|---|---|---|---|---|\n| 1 | Staging | real run owed | stub | backend | ${by} | run it |\n\n## Server-side enforcement the frontend assumes\n\n| Assumption | Owner | By | Status |\n|---|---|---|---|\n| CSRF checked | backend | 2026-12-15 | assumed |\n`;

function madeUpApp() {
  const app = mkdtempSync(join(tmpdir(), 'bar-'));
  const w = (f, c) => { mkdirSync(join(app, f, '..'), { recursive: true }); writeFileSync(join(app, f), c); };
  w('security-headers.json', JSON.stringify(HEADERS));
  w('dist/index.html', '<!doctype html><script type="module" src="/assets/a.js"></script>');
  w('api/openapi.yaml', CONTRACT);
  w('docs/production/headers.json', JSON.stringify({ date: '2026-11-19T10:00:00Z', url: 'http://x/', ok: true, problems: [], headersSha: sha256(readFileSync(join(app, 'security-headers.json'))) }));
  w('docs/production/perf.json', JSON.stringify({ date: '2026-11-19T10:00:00Z', buildSha: sha256(readFileSync(join(app, 'dist/index.html'))), bundle: { initialJsKb: 100, initialCssKb: 5, lazy: [] }, vitals: [{ screen: 'home', route: '/', lcpMs: 900, cls: 0 }], problems: [], warnings: [] }));
  w('docs/production/staging.json', JSON.stringify({ date: '2026-11-19T10:00:00Z', url: 'http://x', stub: true, contract: { file: 'api/openapi.yaml', sha256: sha256(Buffer.from(CONTRACT)) }, drift: { breaking: [], additive: [] }, flows: [{ name: 'sign in', ok: true, problems: [] }], ok: true }));
  w('docs/mockups/x/gaps.md', GAPS('2026-12-15'));
  w('docs/audits/2026-11-19-security.md', '# Security audit: x\n\n| | |\n|---|---|\n| Findings | 0 critical, 0 high, 0 medium, 0 low |\n');
  w('docs/production/deploy-handoff.md', '# Deploy handoff\n\n## Build command\n\nnpm run build\n\n## Environment variables\n\nnone\n\n## Headers\n\nsecurity-headers.json\n\n## Health check\n\nGET /\n');
  return app;
}

test('a made-up app whose records all hold meets the bar, and says the staging run was a stub', async () => {
  const app = madeUpApp();
  try {
    const r = await run(BAR, app);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /^production bar: met \(6 items\)$/m);
    assert.match(r.out, /^note: staging: run against a stub/m);
  } finally { rmSync(app, { recursive: true, force: true }); }
});

test('a Next.js build is matched by .next/BUILD_ID: the same build meets the bar, a rebuilt one does not', async () => {
  const app = madeUpApp();
  try {
    rmSync(join(app, 'dist'), { recursive: true });
    mkdirSync(join(app, '.next'), { recursive: true });
    writeFileSync(join(app, '.next/BUILD_ID'), 'build-one');
    const f = join(app, 'docs/production/perf.json');
    const p = JSON.parse(readFileSync(f, 'utf8'));
    writeFileSync(f, JSON.stringify({ ...p, build: 'next', buildSha: sha256(Buffer.from('build-one')) }));
    const same = await run(BAR, app);
    assert.equal(same.code, 0, same.out);
    writeFileSync(join(app, '.next/BUILD_ID'), 'build-two');
    const rebuilt = await run(BAR, app);
    assert.equal(rebuilt.code, 1, rebuilt.out);
    assert.deepEqual(notMet(rebuilt.out), ['not met: performance: the recorded budget run is not of the current production build (.next/BUILD_ID differs); build and measure again']);
  } finally { rmSync(app, { recursive: true, force: true }); }
});

test('each plant fails the bar with its own line', async () => {
  const plants = {
    'a header missing on the served origin': async (app) => {
      const server = createServer((q, s) => { const h = renderHeaders(HEADERS); delete h['X-Content-Type-Options']; s.writeHead(200, h).end('x'); });
      await new Promise((r) => server.listen(0, '127.0.0.1', r));
      return { args: ['--url', `http://127.0.0.1:${server.address().port}/`], after: () => server.close(), want: /^not met: headers: header X-Content-Type-Options: missing$/ };
    },
    'a bundle over budget': (app) => {
      const f = join(app, 'docs/production/perf.json'); const p = JSON.parse(readFileSync(f, 'utf8'));
      writeFileSync(f, JSON.stringify({ ...p, problems: ['initial JS 300 KB gzip is over the budget of 250 KB'] }));
      return { want: /^not met: performance: initial JS 300 KB gzip is over the budget of 250 KB$/ };
    },
    'a blocking gap with no date': (app) => { writeFileSync(join(app, 'docs/mockups/x/gaps.md'), GAPS('')); return { want: /^not met: gaps: 1 problems: gaps: "Blocking go-live" row 1 \(Staging\): no date/ }; },
    'the live contract drifted': (app) => {
      const f = join(app, 'docs/production/staging.json'); const s = JSON.parse(readFileSync(f, 'utf8'));
      writeFileSync(f, JSON.stringify({ ...s, ok: false, drift: { breaking: ['operation GET /v1/items removed'], additive: [] } }));
      return { want: /^not met: staging: breaking drift: operation GET \/v1\/items removed$/ };
    },
    'a staging run on an older contract': (app) => { writeFileSync(join(app, 'api/openapi.yaml'), CONTRACT.replace('0.1.0', '0.2.0')); return { want: /^not met: staging: the staging run was on another contract than the app's current one/ }; },
    'no security audit': (app) => { rmSync(join(app, 'docs/audits'), { recursive: true }); return { want: /^not met: security: no docs\/audits\/YYYY-MM-DD-security\.md: run keel security-audit on the app$/ }; },
  };
  for (const [name, plant] of Object.entries(plants)) {
    const app = madeUpApp();
    try {
      const { args = [], after, want } = await plant(app);
      const r = await run(BAR, app, ...args);
      after?.();
      assert.equal(r.code, 1, `${name}: ${r.out}`);
      const lines = notMet(r.out);
      assert.equal(lines.length, 1, `${name}: ${lines.join('\n')}`);
      assert.match(lines[0], want, name);
    } finally { rmSync(app, { recursive: true, force: true }); }
  }
});

test('staging-run stops on breaking drift before any flow, and records it', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'staging-'));
  try {
    writeFileSync(join(dir, 'signed.yaml'), CONTRACT);
    writeFileSync(join(dir, 'live.yaml'), CONTRACT.replace('required: [id]', 'required: [id, owner]'));
    writeFileSync(join(dir, 'flows.json'), JSON.stringify({ flows: [{ name: 'never runs', path: '/', expect: { path: '/' } }] }));
    const r = await run(STAGING, '--url', 'http://127.0.0.1:9', '--flows', join(dir, 'flows.json'), '--contract', join(dir, 'signed.yaml'), '--live-contract', join(dir, 'live.yaml'), '--record', join(dir, 'rec.json'));
    assert.equal(r.code, 1, r.out);
    assert.match(r.out, /drift: breaking: schema Item: owner is now required/);
    assert.match(r.out, /staging-run: stopped: the live contract breaks the app's/);
    const rec = JSON.parse(readFileSync(join(dir, 'rec.json'), 'utf8'));
    assert.deepEqual([rec.ok, rec.flows.length], [false, 0]);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('a staging run against the sample backend meets the bar with its own note, never the stub one', async () => {
  const app = madeUpApp();
  try {
    const f = join(app, 'docs/production/staging.json');
    const s = JSON.parse(readFileSync(f, 'utf8'));
    writeFileSync(f, JSON.stringify({ ...s, stub: false, kind: 'sample', sampleStats: { requests: 20 } }));
    const r = await run(BAR, app);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /^note: staging: run against the sample backend \(written from the contract, 20 API requests/m);
    assert.doesNotMatch(r.out, /against a stub/);
  } finally { rmSync(app, { recursive: true, force: true }); }
});
