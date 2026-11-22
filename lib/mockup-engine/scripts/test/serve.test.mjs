/**
 * serve.test.mjs: lib/serve.mjs, the static server the checks load a mockup through. A malformed
 * percent escape in a URL is a 400 for that request, not a crash of the server (B12). No browser.
 * Run: node --test test/serve.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { request } from 'node:http';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn } from 'node:child_process';

/** A raw GET, so the path goes out exactly as written (fetch would normalise it). */
const get = (base, path) => new Promise((done, failed) => {
  const u = new URL(base);
  const req = request({ host: u.hostname, port: u.port, path, method: 'GET' }, (res) => {
    let body = '';
    res.on('data', (d) => { body += d; });
    res.on('end', () => done({ status: res.statusCode, body }));
  });
  req.on('error', failed);
  req.end();
});

// The server runs in a child, as in a check: a throw in its handler kills that process, and the
// test sees the request fail instead of hanging on it.
const SERVE = new URL('../lib/serve.mjs', import.meta.url).href;
function child(dir) {
  const p = spawn(process.execPath, ['--input-type=module', '-e', `const { serveMockup } = await import(${JSON.stringify(SERVE)}); const { base } = await serveMockup(${JSON.stringify(dir)}); console.log(base);`]);
  return new Promise((done) => p.stdout.once('data', (d) => done({ p, base: String(d).trim() })));
}

test('a malformed % in a URL is a 400, and the server keeps serving (B12)', { timeout: 20000 }, async () => {
  const tmp = mkdtempSync(join(tmpdir(), 'serve-'));
  mkdirSync(join(tmp, 'pages'));
  writeFileSync(join(tmp, 'pages/a.html'), '<p>a</p>');
  const { p, base } = await child(tmp);
  try {
    const bad = await get(base, '/pages/%zz.html').catch((e) => ({ status: `request failed: ${e.code}` }));
    assert.equal(bad.status, 400);
    const ok = await get(base, '/pages/a.html');
    assert.equal(ok.status, 200);
    assert.equal(ok.body, '<p>a</p>');
    assert.equal((await get(base, '/pages/missing.html')).status, 404);
    assert.equal((await get(base, '/../etc/passwd')).status, 404);
  } finally {
    p.kill();
    rmSync(tmp, { recursive: true, force: true });
  }
});
