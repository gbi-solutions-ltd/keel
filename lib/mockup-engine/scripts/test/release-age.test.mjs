/**
 * release-age.test.mjs: release-age.mjs against a stand-in registry. A version published under the
 * age fails (exit 1) and is named; a bundled package is not looked up (its parent's tarball holds
 * it); --since checks only what is new since a commit; --prune removes the young entries (and
 * what is nested under them) and nothing else; an unreachable registry exits 2.
 * Run: node --test test/release-age.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../release-age.mjs', import.meta.url));
const ago = (days) => new Date(Date.now() - days * 864e5).toISOString();
const TIMES = {
  old: { '1.0.0': ago(40) },
  fresh: { '2.0.0': ago(3), '1.9.0': ago(30) },
  '@s/scoped': { '1.0.0': ago(20) },
};
const asked = [];

function registry() {
  const server = createServer((req, res) => {
    const name = decodeURIComponent(req.url.slice(1));
    asked.push(name);
    if (!TIMES[name]) return res.writeHead(404).end();
    res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ name, time: TIMES[name] }));
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

function lockDir(packages) {
  const dir = mkdtempSync(join(tmpdir(), 'release-age-'));
  writeFileSync(join(dir, 'package-lock.json'), JSON.stringify({ lockfileVersion: 3, packages: { '': {}, ...packages } }, null, 2));
  return dir;
}
const PKGS = {
  'node_modules/old': { version: '1.0.0' },
  'node_modules/fresh': { version: '2.0.0' },
  'node_modules/fresh/node_modules/inner': { version: '1.0.0', inBundle: true },
  'node_modules/@s/scoped': { version: '1.0.0' },
};

/** Run the CLI without blocking the event loop the stand-in registry answers on. */
function run(args, cwd) {
  return new Promise((resolve) => {
    const p = spawn(process.execPath, [SCRIPT, ...args], { cwd });
    let out = '';
    p.stdout.on('data', (d) => (out += d));
    p.stderr.on('data', (d) => (out += d));
    p.on('close', (code) => resolve({ code, out }));
  });
}

test('a young version fails and is named; the age, a bundled package and a scoped name handled', async () => {
  const server = await registry();
  const url = `http://127.0.0.1:${server.address().port}/`;
  const dir = lockDir(PKGS);
  try {
    asked.length = 0;
    const r = await run([dir, '--registry', url]);
    assert.equal(r.code, 1, r.out);
    assert.match(r.out, /FAIL fresh@2\.0\.0 was published 3\.0 days ago .*under 14/);
    assert.match(r.out, /3 versions checked, 1 under 14 days; the youngest fresh@2\.0\.0, 3\.0 days/);
    assert.deepEqual(asked.sort(), ['@s/scoped', 'fresh', 'old'], 'the bundled package is not looked up');
    assert.equal((await run([dir, '--registry', url, '--days', '2'])).code, 0);
  } finally {
    server.close();
    rmSync(dir, { recursive: true, force: true });
  }
});

test('--prune removes the young entries and what is nested under them, nothing else', async () => {
  const server = await registry();
  const url = `http://127.0.0.1:${server.address().port}/`;
  const dir = lockDir(PKGS);
  try {
    const r = await run([dir, '--registry', url, '--prune']);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /pruned 2 entries from .*package-lock\.json/);
    const left = Object.keys(JSON.parse(readFileSync(join(dir, 'package-lock.json'), 'utf8')).packages);
    assert.deepEqual(left, ['', 'node_modules/old', 'node_modules/@s/scoped']);
  } finally {
    server.close();
    rmSync(dir, { recursive: true, force: true });
  }
});

test('--since checks only the versions new since the commit', async () => {
  const server = await registry();
  const url = `http://127.0.0.1:${server.address().port}/`;
  const dir = lockDir({ 'node_modules/fresh': { version: '2.0.0' } });
  const git = (...a) => spawnSync('git', a, { cwd: dir, encoding: 'utf8' });
  try {
    git('init', '-q');
    git('-c', 'user.name=t', '-c', 'user.email=t@example.invalid', 'commit', '-q', '--allow-empty', '-m', 'empty');
    git('add', '.');
    git('-c', 'user.name=t', '-c', 'user.email=t@example.invalid', 'commit', '-q', '-m', 'lock');
    writeFileSync(join(dir, 'package-lock.json'), JSON.stringify({ lockfileVersion: 3, packages: { '': {}, 'node_modules/fresh': { version: '2.0.0' }, 'node_modules/old': { version: '1.0.0' } } }));
    const since = await run(['.', '--registry', url, '--since', 'HEAD'], dir);
    assert.equal(since.code, 0, since.out);
    assert.match(since.out, /1 versions checked \(new since HEAD\), 0 under 14 days/);
    const before = await run(['.', '--registry', url, '--since', 'HEAD~1'], dir);
    assert.equal(before.code, 1, 'at the first commit there was no lockfile: everything is new');
  } finally {
    server.close();
    rmSync(dir, { recursive: true, force: true });
  }
});

test('a version the registry has no time for fails; an unreachable registry exits 2', async () => {
  const server = await registry();
  const url = `http://127.0.0.1:${server.address().port}/`;
  const dir = lockDir({ 'node_modules/old': { version: '9.9.9' } });
  try {
    const r = await run([dir, '--registry', url]);
    assert.equal(r.code, 1, r.out);
    assert.match(r.out, /FAIL old@9\.9\.9 has no publish time in the registry/);
    server.close();
    const down = await run([dir, '--registry', url]);
    assert.equal(down.code, 2, down.out);
    assert.match(down.out, /the registry could not be read/);
  } finally {
    server.close();
    rmSync(dir, { recursive: true, force: true });
  }
});
