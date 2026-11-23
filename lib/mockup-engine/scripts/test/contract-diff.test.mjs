/**
 * contract-diff.test.mjs: contract-diff.mjs and lib/production.mjs contractDiff (sweep A8). A document
 * that is not OpenAPI 3.x with paths exits 2 (two `foo: bar` files, an empty file). The diff goes
 * into operations: parameters, request bodies, response codes, inline schemas, items, nullable,
 * format, and is direction aware: newly required in a request is breaking, in a response it is not;
 * no longer required in a response is breaking for the reader, in a request it is not.
 * Run: node --test test/contract-diff.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { contractDiff } from '../lib/production.mjs';

const DIFF = fileURLToPath(new URL('../contract-diff.mjs', import.meta.url));
const run = (...a) => new Promise((done) => { const p = spawn(process.execPath, [DIFF, ...a]); let out = ''; p.stdout.on('data', (d) => { out += d; }); p.stderr.on('data', (d) => { out += d; }); p.on('close', (code) => done({ code, out })); });

test('a document that is not OpenAPI 3.x with paths exits 2, an empty one too', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'cdiff-'));
  try {
    writeFileSync(join(dir, 'a.yaml'), 'foo: bar\n');
    writeFileSync(join(dir, 'b.yaml'), 'foo: bar\n');
    writeFileSync(join(dir, 'empty.yaml'), '');
    writeFileSync(join(dir, 'swagger.yaml'), 'swagger: "2.0"\npaths: { /x: { get: {} } }\n');
    writeFileSync(join(dir, 'ok.yaml'), 'openapi: 3.1.0\ninfo: { title: x, version: "1" }\npaths:\n  /x:\n    get: { responses: { "200": { description: ok } } }\n');
    const foo = await run(join(dir, 'a.yaml'), join(dir, 'b.yaml'));
    assert.equal(foo.code, 2, foo.out);
    assert.match(foo.out, /contract-diff: .*a\.yaml is not an OpenAPI 3\.x document: no openapi: 3\.x version; no paths/);
    const empty = await run(join(dir, 'ok.yaml'), join(dir, 'empty.yaml'));
    assert.equal(empty.code, 2, empty.out);
    assert.match(empty.out, /contract-diff: .*empty\.yaml is not an OpenAPI 3\.x document: empty/);
    const swagger = await run(join(dir, 'swagger.yaml'), join(dir, 'ok.yaml'));
    assert.equal(swagger.code, 2, swagger.out);
    const same = await run(join(dir, 'ok.yaml'), join(dir, 'ok.yaml'));
    assert.equal(same.code, 0, same.out);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

const doc = (paths, schemas = {}) => ({ openapi: '3.1.0', info: { title: 'x', version: '1' }, paths, components: { schemas } });
const json = (schema) => ({ content: { 'application/json': { schema } } });
const ok = (schema) => ({ responses: { 200: { description: 'ok', ...json(schema) } } });

test('operations: parameters, request bodies and response codes', () => {
  const before = doc({ '/v1/items': {
    parameters: [{ in: 'query', name: 'page', schema: { type: 'integer' } }],
    get: { parameters: [{ in: 'query', name: 'q', schema: { type: 'string' } }, { in: 'query', name: 'sort', schema: { type: 'string', enum: ['name', 'date'] } }], ...ok({ type: 'object' }) },
    post: { requestBody: { required: false, ...json({ type: 'object', properties: { name: { type: 'string' } } }) }, responses: { 201: { description: 'made' }, 409: { description: 'taken' } } },
  } });
  const after = doc({ '/v1/items': {
    get: { parameters: [{ in: 'query', name: 'page', schema: { type: 'string' } }, { in: 'query', name: 'sort', schema: { type: 'string', enum: ['name'] } }, { in: 'header', name: 'X-Tenant', required: true, schema: { type: 'string' } }, { in: 'query', name: 'limit', schema: { type: 'integer' } }], ...ok({ type: 'object' }) },
    post: { requestBody: { required: true, content: { 'application/xml': { schema: { type: 'object' } } } }, responses: { 200: { description: 'ok' } } },
  } });
  const d = contractDiff(before, after);
  assert.deepEqual(d.breaking.sort(), [
    'operation GET /v1/items: parameter header X-Tenant added, required',
    'operation GET /v1/items: parameter query page: type "integer" became "string"',
    'operation GET /v1/items: parameter query q removed',
    'operation GET /v1/items: parameter query sort: enum value date removed',
    'operation POST /v1/items: parameter query page removed', // a path-level parameter reaches every operation
    'operation POST /v1/items: request body application/json no longer accepted',
    'operation POST /v1/items: request body is now required',
    'operation POST /v1/items: response 201 removed',
  ]);
  assert.ok(d.additive.includes('operation GET /v1/items: parameter query limit added'), d.additive.join('\n'));
  assert.ok(d.additive.includes('operation POST /v1/items: response 409 no longer documented'), d.additive.join('\n'));
  assert.ok(d.additive.includes('operation POST /v1/items: response 200 added'), d.additive.join('\n'));
});

test('inline schemas, items, nullable and format; required is direction aware', () => {
  const body = (s) => ({ requestBody: { required: true, ...json(s) }, ...ok({ type: 'object', required: ['id', 'total'], properties: { id: { type: 'string' }, total: { type: 'number' }, lines: { type: 'array', items: { type: 'object', properties: { qty: { type: 'integer' } } } }, due: { type: 'string', format: 'date' }, note: { type: 'string' } } }) });
  const before = doc({ '/v1/orders': { post: body({ type: 'object', required: ['name'], properties: { name: { type: 'string' }, ref: { type: 'string' }, tag: { type: 'string', nullable: true } } }) } });
  const after = structuredClone(before);
  const req = after.paths['/v1/orders'].post.requestBody.content['application/json'].schema;
  req.required = ['ref'];                          // name no longer required: fine; ref newly required: breaking
  req.properties.tag = { type: 'string' };         // a request field may no longer be null: breaking
  const res = after.paths['/v1/orders'].post.responses[200].content['application/json'].schema;
  res.required = ['id', 'note'];                   // total no longer required: breaking for the reader; note newly required: fine
  res.properties.lines.items.properties.qty = { type: 'string' };
  res.properties.due = { type: 'string', format: 'date-time' };
  res.properties.note = { type: ['string', 'null'] }; // a response field may now be null: breaking
  const d = contractDiff(before, after);
  assert.deepEqual(d.breaking.sort(), [
    'operation POST /v1/orders: request body: property tag may no longer be null',
    'operation POST /v1/orders: request body: ref is now required',
    'operation POST /v1/orders: response 200: property due format date became date-time',
    'operation POST /v1/orders: response 200: property lines[].qty changed from "integer" to "string"',
    'operation POST /v1/orders: response 200: property note may now be null',
    'operation POST /v1/orders: response 200: total is no longer required',
  ]);
  assert.ok(d.additive.includes('operation POST /v1/orders: request body: name is no longer required'), d.additive.join('\n'));
  assert.ok(d.additive.includes('operation POST /v1/orders: response 200: note is now required'), d.additive.join('\n'));
});

test('a component schema is judged by where operations use it; nullable in 3.0 and 3.1 forms are the same', () => {
  const ref = (n) => ({ $ref: `#/components/schemas/${n}` });
  const before = doc({ '/v1/a': { post: { requestBody: json(ref('In')), ...ok(ref('Out')) } } }, {
    In: { type: 'object', required: ['a'], properties: { a: { type: 'string' }, b: { type: 'string', nullable: true } } },
    Out: { type: 'object', required: ['x', 'y'], properties: { x: { type: 'string' }, y: ref('Inner') } },
    Inner: { type: 'object', required: ['k'], properties: { k: { type: 'string' } } },
  });
  const after = structuredClone(before);
  after.components.schemas.In = { type: 'object', required: [], properties: { a: { type: 'string' }, b: { type: ['string', 'null'] } } };
  after.components.schemas.Out.required = ['x', 'y', 'z'];
  after.components.schemas.Out.properties.z = { type: 'string' };
  after.components.schemas.Inner.required = [];
  const d = contractDiff(before, after);
  assert.deepEqual(d.breaking, ['schema Inner: k is no longer required']);
  assert.ok(d.additive.includes('schema In: a is no longer required'));
  assert.ok(d.additive.includes('schema Out: z is now required'));
  assert.deepEqual(contractDiff(before, before), { breaking: [], additive: [] });
});
