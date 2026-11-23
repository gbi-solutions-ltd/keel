/**
 * staging-run.test.mjs: staging-run.mjs checks its inputs before a browser (sweep A9, A8, B11): a flow
 * with no assertion (expect missing, empty, or only unknown keys) exits 2; a live contract that is not
 * OpenAPI 3.x exits 2; the record binds the run to the build (--build, dist/index.html or
 * .next/BUILD_ID), written even when drift stops the run. Run: node --test test/staging-run.test.mjs
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sha256 } from '../lib/production.mjs';

const STAGING = fileURLToPath(new URL('../staging-run.mjs', import.meta.url));
const run = (...a) => new Promise((done) => { const p = spawn(process.execPath, [STAGING, ...a]); let out = ''; p.stdout.on('data', (d) => { out += d; }); p.stderr.on('data', (d) => { out += d; }); p.on('close', (code) => done({ code, out })); });
const CONTRACT = 'openapi: 3.1.0\ninfo: { title: x, version: 0.1.0 }\npaths:\n  /v1/items:\n    get: { responses: { "200": { description: ok } } }\n';

function setup(flows) {
  const dir = mkdtempSync(join(tmpdir(), 'staging-a9-'));
  writeFileSync(join(dir, 'signed.yaml'), CONTRACT);
  writeFileSync(join(dir, 'live.yaml'), CONTRACT.replace('get:', 'post:'));
  writeFileSync(join(dir, 'flows.json'), JSON.stringify({ flows }));
  const base = ['--url', 'http://127.0.0.1:9', '--flows', join(dir, 'flows.json'), '--contract', join(dir, 'signed.yaml'), '--live-contract', join(dir, 'live.yaml')];
  return { dir, base };
}

test('a flow with no assertion exits 2 before anything runs', async () => {
  for (const [name, flow] of Object.entries({
    'no expect': { name: 'loads', path: '/' },
    'empty expect': { name: 'loads', path: '/', expect: {} },
    'only an unknown key': { name: 'loads', path: '/', expect: { txt: 'Dashboard' } },
    'empty text': { name: 'loads', path: '/', expect: { text: '' } },
  })) {
    const s = setup([{ name: 'sign in', path: '/', expect: { path: '/home' } }, flow]);
    try {
      const r = await run(...s.base);
      assert.equal(r.code, 2, `${name}: ${r.out}`);
      assert.match(r.out, /staging-run: .*flow 2 \(loads\): (no assertion: give expect a path, text or request|expect has unknown key txt)/, name);
      assert.doesNotMatch(r.out, /^drift:/m, name);
    } finally { rmSync(s.dir, { recursive: true, force: true }); }
  }
});

test('a live contract that is not OpenAPI 3.x exits 2', async () => {
  const s = setup([{ name: 'sign in', path: '/', expect: { path: '/home' } }]);
  try {
    writeFileSync(join(s.dir, 'live.yaml'), 'foo: bar\n');
    const r = await run(...s.base);
    assert.equal(r.code, 2, r.out);
    assert.match(r.out, /staging-run: --live-contract .*live\.yaml is not an OpenAPI 3\.x document/);
  } finally { rmSync(s.dir, { recursive: true, force: true }); }
});

test('the record names the build it ran against (--build), also when drift stops the run', async () => {
  const s = setup([{ name: 'sign in', path: '/', expect: { path: '/home' } }]);
  try {
    mkdirSync(join(s.dir, 'dist'));
    writeFileSync(join(s.dir, 'dist/index.html'), '<!doctype html>');
    const r = await run(...s.base, '--build', join(s.dir, 'dist/index.html'), '--record', join(s.dir, 'rec.json'));
    assert.equal(r.code, 1, r.out);
    const rec = JSON.parse(readFileSync(join(s.dir, 'rec.json'), 'utf8'));
    assert.deepEqual(rec.build, { kind: 'vite', file: join(s.dir, 'dist/index.html'), sha256: sha256(Buffer.from('<!doctype html>')) });
    const missing = await run(...s.base, '--build', join(s.dir, 'nope/index.html'));
    assert.equal(missing.code, 2, missing.out);
    assert.match(missing.out, /staging-run: --build .*nope\/index\.html: not found/);
  } finally { rmSync(s.dir, { recursive: true, force: true }); }
});

test("a flow's URL off the app's and the API's origins exits 2; one on the API's origin is taken", async () => {
  const s = setup([{ name: 'sign in', path: '/', expect: { path: '/home' } }, { name: 'away', path: 'http://evil.example/sign-out', expect: { text: 'x' } }]);
  try {
    const r = await run(...s.base, '--api', 'http://127.0.0.1:8');
    assert.equal(r.code, 2, r.out);
    assert.match(r.out, /flow 2 \(away\): path "http:\/\/evil\.example\/sign-out" is neither a path on the app nor a URL on the app's or the API's origin/);
    writeFileSync(join(s.dir, 'flows.json'), JSON.stringify({ flows: [{ name: 'sign out', path: 'http://127.0.0.1:8/auth/sign-out', expect: { path: '/auth/signed-out' } }] }));
    const ok = await run(...s.base, '--api', 'http://127.0.0.1:8');
    assert.equal(ok.code, 1, ok.out);
    assert.match(ok.out, /^drift: /m, 'past the flow checks: the drift check ran');
  } finally { rmSync(s.dir, { recursive: true, force: true }); }
});
