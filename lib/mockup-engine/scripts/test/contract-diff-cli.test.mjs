/**
 * contract-diff-cli.test.mjs: contract-diff.mjs as a command (sweep F). Identical documents exit 0
 * and say so; a removed operation is listed as breaking and exits 1, an added one as additive;
 * --record writes { date, signed, signedSha, live, liveSha, breaking, additive } with the sha256 of
 * each file's bytes, also when the run exits 1; the live document may be a URL (served here on
 * 127.0.0.1), and a URL that does not answer 2xx exits 2. No browser.
 * Run: node --test test/contract-diff-cli.test.mjs   (from scripts/)
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sha256 } from '../lib/production.mjs';

const DIFF = fileURLToPath(new URL('../contract-diff.mjs', import.meta.url));
const run = (...a) => new Promise((done) => {
  const p = spawn(process.execPath, [DIFF, ...a]);
  let out = '';
  p.stdout.on('data', (d) => { out += d; });
  p.stderr.on('data', (d) => { out += d; });
  p.on('close', (code) => done({ code, out }));
});

const SIGNED = `openapi: 3.1.0
info: { title: x, version: 1.0.0 }
paths:
  /v1/items:
    get: { operationId: listItems, responses: { "200": { description: ok } } }
  /v1/items/{id}:
    delete: { operationId: deleteItem, parameters: [{ name: id, in: path, required: true, schema: { type: string } }], responses: { "204": { description: gone } } }
`;
// The live one drops deleteItem (breaking) and adds createItem (additive).
const LIVE = `openapi: 3.1.0
info: { title: x, version: 1.1.0 }
paths:
  /v1/items:
    get: { operationId: listItems, responses: { "200": { description: ok } } }
    post: { operationId: createItem, responses: { "201": { description: made } } }
`;

const TMP = mkdtempSync(join(tmpdir(), 'contract-diff-cli-'));
const signed = join(TMP, 'signed.yaml');
const live = join(TMP, 'live.yaml');
writeFileSync(signed, SIGNED);
writeFileSync(live, LIVE);
let server, base;
before(async () => {
  server = createServer((q, res) => {
    if (q.url === '/openapi.yaml') res.writeHead(200, { 'content-type': 'application/yaml' }).end(LIVE);
    else res.writeHead(404).end('no');
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => { server.close(); rmSync(TMP, { recursive: true, force: true }); });

test('identical documents exit 0 and say identical', async () => {
  const r = await run(signed, signed);
  assert.equal(r.code, 0, r.out);
  assert.match(r.out, /^contract-diff: identical \(signed-off 1\.0\.0, live 1\.0\.0\)$/m);
  assert.doesNotMatch(r.out, /^(breaking|additive):/m);
});

test('a removed operation is breaking (exit 1), an added one additive; breaking lines come first', async () => {
  const r = await run(signed, live);
  assert.equal(r.code, 1, r.out);
  const lines = r.out.trim().split('\n');
  const kinds = lines.filter((l) => /^(breaking|additive):/.test(l)).map((l) => l.split(':')[0]);
  assert.ok(kinds.includes('breaking') && kinds.includes('additive'), r.out);
  assert.ok(kinds.lastIndexOf('breaking') < kinds.indexOf('additive'), 'every breaking line before every additive one');
  assert.match(r.out, /^breaking: .*deleteItem|^breaking: .*\/v1\/items\/\{id\}/m);
  assert.match(r.out, /^additive: .*(createItem|POST \/v1\/items|post)/im);
  assert.match(lines.at(-1), /^contract-diff: [1-9]\d* breaking, [1-9]\d* additive \(signed-off 1\.0\.0, live 1\.1\.0\)$/);
});

test('--record writes the documented fields, with each file\'s sha256, also when the run exits 1', async () => {
  const rec = join(TMP, 'record.json');
  const r = await run(signed, live, '--record', rec);
  assert.equal(r.code, 1, r.out);
  assert.ok(existsSync(rec), 'the record is written on a breaking run');
  const j = JSON.parse(readFileSync(rec, 'utf8'));
  assert.deepEqual(Object.keys(j).sort(), ['additive', 'breaking', 'date', 'live', 'liveSha', 'signed', 'signedSha']);
  assert.ok(!Number.isNaN(Date.parse(j.date)), j.date);
  assert.equal(j.signed, signed);
  assert.equal(j.live, live);
  assert.equal(j.signedSha, sha256(readFileSync(signed)));
  assert.equal(j.liveSha, sha256(readFileSync(live)));
  assert.ok(j.breaking.length >= 1 && j.additive.length >= 1, JSON.stringify(j));
  for (const l of j.breaking) assert.match(r.out, new RegExp(`^breaking: ${l.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'm'));

  const same = join(TMP, 'same.json');
  const s = await run(signed, signed, '--record', same);
  assert.equal(s.code, 0, s.out);
  const k = JSON.parse(readFileSync(same, 'utf8'));
  assert.equal(k.signedSha, k.liveSha);
  assert.deepEqual([k.breaking, k.additive], [[], []]);
});

test('the live document may be a URL; one that does not answer 2xx exits 2 before any diff', async () => {
  const rec = join(TMP, 'url.json');
  const r = await run(signed, `${base}/openapi.yaml`, '--record', rec);
  assert.equal(r.code, 1, r.out);
  const j = JSON.parse(readFileSync(rec, 'utf8'));
  assert.equal(j.live, `${base}/openapi.yaml`);
  assert.equal(j.liveSha, sha256(Buffer.from(LIVE)));

  const missing = join(TMP, 'missing.json');
  const m = await run(signed, `${base}/nothing.yaml`, '--record', missing);
  assert.equal(m.code, 2, m.out);
  assert.match(m.out, /HTTP 404/);
  assert.doesNotMatch(m.out, /^(breaking|additive):/m);
  assert.equal(existsSync(missing), false, 'no record when a document cannot be read');
});

test('a missing signed-off file exits 2', async () => {
  const r = await run(join(TMP, 'nope.yaml'), live);
  assert.equal(r.code, 2, r.out);
});
