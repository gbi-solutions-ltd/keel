/**
 * template.test.mjs: the engine's own parts of the backend (lib/), on a contract and tables of
 * its own, so it holds for every backend built from the template. The engine keeps this file
 * byte-identical in every example backend. Run: npm test (TEST_DATABASE_URL, see .env.example)
 */
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { buildApp, readHeaders } from '../lib/app.mjs';
import { loadContract } from '../lib/contract.mjs';
import { testApp } from '../lib/testing.mjs';

const CONTRACT = `openapi: 3.1.0
info: { title: template test, version: '1' }
servers: [{ url: /api }]
security: []
paths:
  /things:
    get:
      operationId: listThings
      responses:
        '200':
          description: the things
          content: { application/json: { schema: { type: array, items: { type: string } } } }
    post:
      operationId: addThings
      responses:
        '201': { description: added }
        '409': { description: refused }
`;

function tmp(prefix) {
  return mkdtempSync(join(tmpdir(), prefix));
}
/** A backend of its own: one table, no seed, the handlers given. */
async function make(t, handlers, over = {}) {
  const dir = tmp('template-test-');
  writeFileSync(join(dir, 'openapi.yaml'), CONTRACT);
  mkdirSync(join(dir, 'migrations'));
  writeFileSync(join(dir, 'migrations', '0001_things.sql'), 'CREATE TABLE things (name text NOT NULL);');
  const b = await testApp({ contract: join(dir, 'openapi.yaml'), migrations: join(dir, 'migrations'), seed: async () => {}, handlers }, over);
  t.after(b.close);
  return b;
}
const names = async (pool) => (await pool.query('SELECT name FROM things ORDER BY name')).rows.map((r) => r.name);
function headersFile(csp) {
  const f = join(tmp('template-headers-'), 'security-headers.json');
  writeFileSync(f, JSON.stringify({ headers: { 'Content-Security-Policy': csp, 'X-Content-Type-Options': 'nosniff' } }));
  return f;
}

// --- Static files: cache and types ------------------------------------------------------------

test('only hashed assets under /assets/ are immutable; root files, index.html and a missing asset are not', async (t) => {
  const dist = tmp('template-dist-');
  mkdirSync(join(dist, 'assets'));
  writeFileSync(join(dist, 'index.html'), '<!doctype html><title>app</title>');
  writeFileSync(join(dist, 'assets', 'app-3f9a1c.js'), 'export {}');
  writeFileSync(join(dist, 'favicon.ico'), 'icon');
  writeFileSync(join(dist, 'robots.txt'), 'User-agent: *');
  const { app } = await make(t, {}, { staticDir: dist, headersFile: headersFile(["default-src 'self'"]) });
  const get = (url) => app.inject({ method: 'GET', url });
  assert.equal((await get('/assets/app-3f9a1c.js')).headers['cache-control'], 'public, max-age=31536000, immutable');
  for (const url of ['/favicon.ico', '/robots.txt', '/', '/index.html', '/some/route']) {
    const r = await get(url);
    assert.equal(r.statusCode, 200, url);
    assert.equal(r.headers['cache-control'], 'no-cache', url);
  }
  // As nginx answers (try_files $uri =404): an old hashed name is a 404, never index.html cached for a year.
  for (const url of ['/assets/app-0000.js', '/assets/%2e%2e/favicon.ico']) {
    const r = await get(url);
    assert.notEqual(r.headers['cache-control'], 'public, max-age=31536000, immutable', url);
    assert.doesNotMatch(r.body, /<title>app<\/title>/, `${url} is not the app's page`);
  }
  assert.equal((await get('/assets/app-0000.js')).statusCode, 404);
});

test('an app with its own sign-in keeps its client routes under /auth/: the page, not a 404', async (t) => {
  const dist = tmp('template-dist-');
  writeFileSync(join(dist, 'index.html'), '<!doctype html><title>app</title>');
  const { app } = await make(t, {}, { staticDir: dist, headersFile: headersFile(["default-src 'self'"]), signIn: 'none' });
  for (const url of ['/auth/reset', '/auth/sign-in']) assert.match((await app.inject({ method: 'GET', url })).body, /<title>app<\/title>/, url);
});

test('static files are served with their media type, so nosniff never blocks one', async (t) => {
  const dist = tmp('template-dist-');
  mkdirSync(join(dist, 'assets'));
  writeFileSync(join(dist, 'index.html'), '<!doctype html><title>app</title>');
  const want = {
    'm.mjs': /^text\/javascript/,
    'm.js.map': /^application\/json/,
    'robots.txt': /^text\/plain/,
    'f.woff': /^font\/woff$/,
    'f.woff2': /^font\/woff2$/,
    'f.ttf': /^font\/ttf$/,
    'f.otf': /^font\/otf$/,
    'p.jpg': /^image\/jpeg$/,
    'p.JPEG': /^image\/jpeg$/,
    'p.webp': /^image\/webp$/,
    'p.avif': /^image\/avif$/,
    'p.gif': /^image\/gif$/,
    'm.wasm': /^application\/wasm$/,
  };
  for (const f of Object.keys(want)) writeFileSync(join(dist, 'assets', f), 'x');
  const { app } = await make(t, {}, { staticDir: dist, headersFile: headersFile(["default-src 'self'"]) });
  for (const [f, type] of Object.entries(want)) assert.match((await app.inject({ method: 'GET', url: `/assets/${f}` })).headers['content-type'], type, f);
});

// --- Headers: the placeholders, as production.mjs renderHeaders fills them ---------------------

test('{origin:VAR} is the origin of the URL in VAR, or nothing when VAR is unset or a path', () => {
  const f = headersFile(["default-src 'self'", "connect-src 'self' {origin:COLLECTOR} {origin:API}"]);
  assert.equal(readHeaders(f)['Content-Security-Policy'], "default-src 'self'; connect-src 'self'");
  assert.equal(readHeaders(f, { env: { COLLECTOR: 'https://otel.example:4318/v1/traces', API: '/api' } })['Content-Security-Policy'], "default-src 'self'; connect-src 'self' https://otel.example:4318");
  assert.throws(() => readHeaders(f, { env: { COLLECTOR: 'not a url' } }), /COLLECTOR/);
});

test('{nonce}: the source is dropped from answers that carry no page, and a static build with one is refused', async (t) => {
  const f = headersFile(["default-src 'self'", "script-src 'self' {nonce} 'strict-dynamic'"]);
  assert.equal(readHeaders(f)['Content-Security-Policy'], "default-src 'self'; script-src 'self' 'strict-dynamic'");
  const { app } = await make(t, { listThings: async () => ({ status: 200, body: [] }) }, { headersFile: f });
  for (const url of ['/healthz', '/api/things']) {
    const csp = (await app.inject({ method: 'GET', url })).headers['content-security-policy'];
    assert.equal(csp, "default-src 'self'; script-src 'self' 'strict-dynamic'", url);
  }
  // A static build's page holds no nonce: a fresh one in the header, or none, blocks its scripts.
  const dist = tmp('template-dist-');
  writeFileSync(join(dist, 'index.html'), '<!doctype html><title>app</title>');
  const contract = join(dist, 'openapi.yaml');
  writeFileSync(contract, CONTRACT);
  await assert.rejects(buildApp({ contract, pool: {}, staticDir: dist, headersFile: f }), /\{nonce\}/);
});

// --- Transactions: the default, and the savepoint for a write then a refusal -------------------

test('a refusal below 500 keeps what the handler wrote (the default, unchanged)', async (t) => {
  const { app, pool } = await make(t, {
    async addThings(ctx) {
      await ctx.db.query("INSERT INTO things VALUES ('counted')");
      ctx.fail(409, 'conflict', 'refused');
    },
  });
  assert.equal((await app.inject({ method: 'POST', url: '/api/things' })).statusCode, 409);
  assert.deepEqual(await names(pool), ['counted']);
});

test('ctx.savepoint: a refusal inside undoes its writes and its mail, and keeps the rest', async (t) => {
  const { app, pool, mail } = await make(t, {
    async addThings(ctx) {
      await ctx.db.query("INSERT INTO things VALUES ('audit')");
      await ctx.sendMail({ to: 'kept@sample.invalid', subject: 'kept', text: 'kept' });
      await ctx.savepoint(async () => {
        await ctx.db.query("INSERT INTO things VALUES ('written then refused')");
        await ctx.sendMail({ to: 'undone@sample.invalid', subject: 'undone', text: 'undone' });
        ctx.fail(409, 'conflict', 'refused');
      });
      return { status: 201 };
    },
  });
  const r = await app.inject({ method: 'POST', url: '/api/things' });
  assert.equal(r.statusCode, 409);
  assert.equal(r.json().error.code, 'conflict');
  assert.deepEqual(await names(pool), ['audit']);
  await new Promise((done) => setImmediate(done));
  assert.deepEqual(mail.map((m) => m.to), ['kept@sample.invalid']);
});

test('ctx.savepoint: nests, returns its value, and an SQL error inside leaves the request usable', async (t) => {
  const { app, pool } = await make(t, {
    async addThings(ctx) {
      const v = await ctx.savepoint(async () => {
        await ctx.db.query("INSERT INTO things VALUES ('outer')");
        await ctx.savepoint(async () => ctx.db.query("INSERT INTO things VALUES ('inner kept')"));
        await assert.rejects(
          ctx.savepoint(async () => {
            await ctx.db.query("INSERT INTO things VALUES ('inner undone')");
            ctx.fail(422, 'invalid', 'no');
          }),
        );
        return 'value';
      });
      assert.equal(v, 'value');
      await assert.rejects(ctx.savepoint(() => ctx.db.query('SELECT 1 / 0')), /division by zero/);
      await ctx.db.query("INSERT INTO things VALUES ('after the error')");
      return { status: 201 };
    },
  });
  assert.equal((await app.inject({ method: 'POST', url: '/api/things' })).statusCode, 201);
  assert.deepEqual(await names(pool), ['after the error', 'inner kept', 'outer']);
});

// --- The contract: a keyword JSON Schema and OpenAPI do not have is refused, not ignored ---------

function contractWith(schemaYaml) {
  const f = join(tmp('template-contract-'), 'openapi.yaml');
  writeFileSync(f, `${CONTRACT}components:\n  schemas:\n${schemaYaml}`);
  return f;
}

test('a contract with an unknown schema keyword is refused, naming it and where', () => {
  assert.throws(() => loadContract(contractWith('    Thing: { type: string, minLenght: 3 }\n')), /Thing.*minLenght/);
  assert.throws(() => loadContract(contractWith('    Thing: { type: object, properties: { name: { type: string, nullable: true } } }\n')), /Thing.*name.*nullable/);
  assert.throws(() => loadContract(contractWith('    Things: { type: array, itmes: { type: string } }\n')), /itmes/);
  const inline = join(tmp('template-contract-'), 'openapi.yaml');
  writeFileSync(inline, CONTRACT.replace('items: { type: string }', 'items: { type: string, formatt: date }'));
  assert.throws(() => loadContract(inline), /listThings.*formatt/);
});

test('a description cut short by a comma in YAML (a key of words, no value) is a warning, not a refusal', (t) => {
  const warned = [];
  t.mock.method(console, 'error', (m) => warned.push(String(m)));
  const f = contractWith('    Thing: { type: string, description: E.164, for SMS only }\n');
  assert.doesNotThrow(() => loadContract(f));
  assert.match(warned.join('\n'), /Thing: for SMS only/);
  // A keyword's typo with a value is still refused, words or not.
  assert.throws(() => loadContract(contractWith('    Thing: { type: string, max Length: 3 }\n')), /max Length/);
});

test('a contract is not refused for names and values that only look like keywords', () => {
  const ok = contractWith(
    [
      '    Thing:',
      '      type: object',
      '      required: [minLenght]',
      '      properties: { minLenght: { type: string, enum: [itmes] }, kind: { const: { formatt: 1 } } }',
      '      example: { minLenght: a, nullable: true }',
      '      x-mockup-fixture: things',
      '    Pet:',
      '      oneOf: [{ $ref: "#/components/schemas/Thing" }]',
      '      discriminator: { propertyName: kind, mapping: { formatt: "#/components/schemas/Thing" } }',
      '',
    ].join('\n'),
  );
  assert.doesNotThrow(() => loadContract(ok));
});
