/**
 * staging-run-stub.test.mjs: staging-run.mjs against a local stub (sweep F). --stub resets the stub
 * (POST /__stub/reset) before the first flow and reads /__stub/stats after, records kind "stub" with
 * the stats, and says the run proves the frontend half only. --save-session keeps the session the
 * flows signed in with (a storageState file holding the HttpOnly session cookie). --api names an API
 * on another origin: the reset and the stats go there, not to the app; its answers are checked as
 * the app's own are (a 500 from it fails the flow, exit 1); the record's crossOrigin names both
 * origins, the API's cookies and which of them the app's page could read (none, all HttpOnly).
 * The app and the stub are small servers on 127.0.0.1. Launches a browser.
 * Run: node --test test/staging-run-stub.test.mjs   (from scripts/)
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const STAGING = fileURLToPath(new URL('../staging-run.mjs', import.meta.url));
const run = (args) => new Promise((done) => {
  const p = spawn(process.execPath, [STAGING, ...args]);
  let out = '';
  p.stdout.on('data', (d) => { out += d; });
  p.stderr.on('data', (d) => { out += d; });
  p.on('close', (code) => done({ code, out }));
});

const CONTRACT = `openapi: 3.1.0
info: { title: x, version: 0.1.0 }
paths:
  /api/v1/session:
    post: { responses: { "204": { description: signed in } } }
  /api/v1/items:
    get: { responses: { "200": { description: ok }, "401": { description: no session } } }
`;
const TMP = mkdtempSync(join(tmpdir(), 'staging-stub-'));
writeFileSync(join(TMP, 'openapi.yaml'), CONTRACT);

/**
 * The app: one page for every route that draws itself from location.pathname, as a single-page app
 * does; sign-in moves to /dashboard with history.pushState. apiBase is '' for same origin, else the
 * API's origin. fullLoad makes sign-in a full page load instead (location.href).
 */
const spa = (apiBase, { fullLoad = false } = {}) => `<!doctype html><html lang="en"><head><title>App</title></head><body><main id="main"></main>
<script>
const api = '${apiBase}';
const main = document.getElementById('main');
function draw() {
  const p = location.pathname;
  if (p === '/dashboard') {
    main.innerHTML = '<h1>Dashboard</h1><ul id="items"></ul>';
    fetch(api + '/api/v1/items', { credentials: 'include' }).then((r) => r.json()).then((xs) => { for (const x of xs) document.getElementById('items').append(Object.assign(document.createElement('li'), { textContent: x })); });
  } else if (p === '/broken') {
    main.innerHTML = '<h1>Broken page</h1>';
    fetch(api + '/api/v1/broken', { credentials: 'include' });
  } else {
    main.innerHTML = '<h1>Sign in</h1><button type="button" id="go">Sign in</button>';
    document.getElementById('go').addEventListener('click', async () => {
      const r = await fetch(api + '/api/v1/session', { method: 'POST', credentials: 'include' });
      if (!r.ok) return;
      ${fullLoad ? "location.href = '/dashboard';" : "history.pushState({}, '', '/dashboard'); draw();"}
    });
  }
}
draw();
</script></body></html>`;
const pages = (apiBase, o) => Object.fromEntries(['/', '/dashboard', '/broken'].map((p) => [p, spa(apiBase, o)]));

/**
 * One server: the app's pages when given, and the stub API (session, items, broken, __stub/*).
 * log keeps every request in order; stats are what /__stub/stats answers.
 */
function server({ html = null, cors = null } = {}) {
  const log = [];
  const stats = { resets: 0, noSession: 0, csrfChecked: 0, csrfRefused: 0 };
  const s = createServer((q, res) => {
    const path = q.url.split('?')[0];
    log.push(`${q.method} ${path}`);
    const h = cors ? { 'access-control-allow-origin': cors(), 'access-control-allow-credentials': 'true', vary: 'origin' } : {};
    if (html && q.method === 'GET' && html[path]) return res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }).end(html[path]);
    if (q.method === 'POST' && path === '/__stub/reset') { stats.resets++; return res.writeHead(204).end(); }
    if (q.method === 'GET' && path === '/__stub/stats') return res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(stats));
    if (q.method === 'POST' && path === '/api/v1/session') return res.writeHead(204, { ...h, 'set-cookie': 'sid=s3cr3t; Path=/; HttpOnly; SameSite=Lax' }).end();
    if (q.method === 'GET' && path === '/api/v1/items') {
      if (!/(^|;\s*)sid=s3cr3t(;|$)/.test(q.headers.cookie || '')) { stats.noSession++; return res.writeHead(401, h).end(); }
      return res.writeHead(200, { ...h, 'content-type': 'application/json' }).end(JSON.stringify(['INV-0412']));
    }
    if (path === '/api/v1/broken') return res.writeHead(500, h).end('boom');
    if (path === '/favicon.ico') return res.writeHead(204).end();
    res.writeHead(404, h).end('not found');
  });
  return new Promise((r) => s.listen(0, '127.0.0.1', () => r({ s, log, stats, base: `http://127.0.0.1:${s.address().port}` })));
}

const FLOWS = [
  { name: 'sign in', path: '/', steps: [{ click: { role: 'button', name: 'Sign in' } }], expect: { path: '/dashboard', request: 'POST /api/v1/session' } },
  { name: 'items', path: '/dashboard', expect: { text: 'INV-0412', request: 'GET /api/v1/items' } },
];
const flowsFile = (name, flows) => { const f = join(TMP, `${name}.json`); writeFileSync(f, JSON.stringify({ flows })); return f; };
const common = (url, flows) => ['--url', url, '--flows', flows, '--contract', join(TMP, 'openapi.yaml'), '--live-contract', join(TMP, 'openapi.yaml')];

let same, app, api, nav;
before(async () => {
  same = await server({ html: pages('') });
  nav = await server({ html: pages('', { fullLoad: true }) });
  api = await server({ cors: () => app.base });
  app = await server({ html: pages(api.base) });
});
after(() => { for (const x of [same, app, api, nav]) x?.s.close(); rmSync(TMP, { recursive: true, force: true }); });

test('--stub resets the stub before the first flow, reads its stats after, and records kind stub; --save-session keeps the session', { timeout: 120000 }, async () => {
  const rec = join(TMP, 'stub.json');
  const session = join(TMP, 'session.json');
  same.log.length = 0;
  const r = await run([...common(same.base, flowsFile('stub', FLOWS)), '--stub', '--record', rec, '--save-session', session]);
  assert.equal(r.code, 0, r.out);
  assert.equal(same.stats.resets, 1);
  assert.equal(same.log[0], 'POST /__stub/reset', `the reset comes first: ${same.log.join(', ')}`);
  assert.equal(same.log.at(-1), 'GET /__stub/stats', 'the stats are read after the flows');
  assert.match(r.out, /^ok {4}sign in$/m);
  assert.match(r.out, /^ok {4}items$/m);
  assert.match(r.out, /^staging-run: 2\/2 flows passed \(against a stub: the frontend half only\); stub refused 0 without a session, 0 of 0 on CSRF$/m);
  const j = JSON.parse(readFileSync(rec, 'utf8'));
  assert.equal(j.kind, 'stub');
  assert.equal(j.stub, true);
  assert.equal(j.ok, true);
  assert.equal(j.api, same.base);
  assert.deepEqual(j.stubStats, same.stats);
  assert.equal(j.crossOrigin, undefined, 'same origin: no crossOrigin');
  assert.deepEqual(j.flows.map((f) => [f.name, f.ok]), [['sign in', true], ['items', true]]);

  assert.ok(existsSync(session), '--save-session writes the file');
  const st = JSON.parse(readFileSync(session, 'utf8'));
  const sid = st.cookies.find((c) => c.name === 'sid');
  assert.ok(sid, JSON.stringify(st));
  assert.equal(sid.value, 's3cr3t');
  assert.equal(sid.httpOnly, true);
});

test('without --stub the stub is neither reset nor read, and the record is kind backend', { timeout: 120000 }, async () => {
  const rec = join(TMP, 'backend.json');
  same.log.length = 0;
  const resets = same.stats.resets;
  const r = await run([...common(same.base, flowsFile('backend', FLOWS)), '--record', rec]);
  assert.equal(r.code, 0, r.out);
  assert.equal(same.stats.resets, resets);
  assert.ok(!same.log.some((l) => l.includes('/__stub/')), same.log.join(', '));
  const j = JSON.parse(readFileSync(rec, 'utf8'));
  assert.equal(j.kind, 'backend');
  assert.equal(j.stubStats, null);
  assert.doesNotMatch(r.out, /against a stub/);
});

test('--api: the reset and stats go to the API\'s origin; crossOrigin names both and no readable API cookie', { timeout: 120000 }, async () => {
  const rec = join(TMP, 'api.json');
  app.log.length = 0;
  api.log.length = 0;
  const r = await run([...common(app.base, flowsFile('api', FLOWS)), '--stub', '--api', api.base, '--record', rec]);
  assert.equal(r.code, 0, r.out);
  assert.equal(api.log[0], 'POST /__stub/reset', api.log.join(', '));
  assert.equal(api.log.at(-1), 'GET /__stub/stats');
  assert.ok(!app.log.some((l) => l.includes('/__stub/')), `nothing for the stub reached the app: ${app.log.join(', ')}`);
  assert.match(r.out, /^cross-origin: the API's cookies sid; readable by the app: none$/m);
  const j = JSON.parse(readFileSync(rec, 'utf8'));
  assert.equal(j.url, app.base);
  assert.equal(j.api, api.base);
  assert.deepEqual(j.crossOrigin, { app: app.base, api: api.base, apiCookies: ['sid'], readableByApp: [] });
  assert.deepEqual(j.stubStats, api.stats);
  assert.equal(j.ok, true);
});

test('--api: an answer of 500 from the API fails the flow, exit 1', { timeout: 120000 }, async () => {
  const rec = join(TMP, 'api-broken.json');
  const flows = [...FLOWS, { name: 'broken', path: '/broken', expect: { text: 'Broken page' } }];
  const r = await run([...common(app.base, flowsFile('api-broken', flows)), '--stub', '--api', api.base, '--record', rec]);
  assert.equal(r.code, 1, r.out);
  assert.match(r.out, /^fail {2}broken\n {6}GET \/api\/v1\/broken answered 500$/m);
  const j = JSON.parse(readFileSync(rec, 'utf8'));
  assert.equal(j.ok, false);
  assert.deepEqual(j.flows.map((f) => f.ok), [true, true, false]);
});

test('a sign-in step that loads a new page (location.href, a form post) passes like a client-side one', {
  timeout: 120000,
}, async () => {
  const r = await run([...common(nav.base, flowsFile('nav', FLOWS)), '--stub']);
  assert.equal(r.code, 0, r.out);
});
