/**
 * toolchain.test.mjs: the preflight refuses (exit 2, with the reason) a Node that is not an LTS
 * release of a tested line at or above its floor, an npm older than the install-script policy
 * needs, a variable that redirects the browser download, and a toolchain not installed as locked;
 * it passes this engine's own install.
 * Run: node --test test/toolchain.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { atLeast, installProblems, npmrcProblems, NPMRC, parseVersion, readNpmrc, runtimeProblems, SUPPORTED } from '../lib/toolchain.mjs';

const SCRIPT = fileURLToPath(new URL('../toolchain.mjs', import.meta.url));
const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const run = (args, env = {}) => {
  const r = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: 'utf8', env: { ...process.env, ...env } });
  return { code: r.status, out: r.stdout + r.stderr };
};
const ok = { version: 'v24.21.0', lts: 'Krypton', npmVersion: '11.19.0' };

test('versions: plain releases only, compared numerically', () => {
  assert.deepEqual(parseVersion('v24.21.0'), [24, 21, 0]);
  assert.equal(parseVersion('26.0.0-rc.1'), null);
  assert.ok(atLeast('24.18.10', '24.18.9'));
  assert.ok(!atLeast('24.9.0', '24.18.0'));
  assert.ok(atLeast('11.16.0', SUPPORTED.npm));
});

test('an LTS release of a tested line at or above its floor, with a recent npm, passes', () => {
  assert.deepEqual(runtimeProblems(ok), []);
  assert.deepEqual(runtimeProblems({ version: 'v24.18.0', lts: 'Krypton', npmVersion: '11.16.0' }), []);
  assert.deepEqual(runtimeProblems({ version: 'v26.13.1', lts: 'Lithium', npmVersion: '11.20.0' }), []);
});

test('each unfit runtime is refused with its reason', () => {
  const one = (rt) => runtimeProblems({ ...ok, ...rt });
  assert.match(one({ version: 'v25.2.0', lts: undefined }).join('\n'), /not an LTS release[\s\S]*line 25 is not one the engine is tested on/);
  assert.match(one({ version: 'v26.4.0', lts: undefined }).join('\n'), /v26\.4\.0 is not an LTS release/);
  assert.match(one({ version: 'v24.17.0' }).join('\n'), /older than 24\.18\.0, the lowest tested on line 24/);
  assert.match(one({ version: 'v22.22.2', lts: 'Jod' }).join('\n'), /line 22 is not one the engine is tested on/);
  assert.match(one({ version: 'v27.0.0-nightly' }).join('\n'), /not a release version/);
  assert.match(one({ npmVersion: '11.15.0' }).join('\n'), /npm 11\.15\.0 is older than 11\.16\.0/);
  assert.match(one({ npmVersion: null }).join('\n'), /npm was not found/);
  assert.match(one({ env: { PLAYWRIGHT_DOWNLOAD_HOST: 'https://mirror.example' } }).join('\n'), /PLAYWRIGHT_DOWNLOAD_HOST is set/);
  assert.match(one({ env: { PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST: 'https://mirror.example' } }).join('\n'), /PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST is set/);
});

test('the .npmrc settings: each missing or weaker one named', () => { // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
  assert.deepEqual(npmrcProblems({ ...NPMRC, 'min-release-age': '30' }, NPMRC), []);
  assert.deepEqual(npmrcProblems(null, NPMRC), ['no .npmrc']); // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
  assert.deepEqual(npmrcProblems({ ...NPMRC, 'min-release-age': '7' }, NPMRC), ['.npmrc min-release-age is 7, not at least 14']); // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
  const { 'strict-allow-scripts': _, ...rest } = NPMRC;
  assert.deepEqual(npmrcProblems(rest, NPMRC), ['.npmrc strict-allow-scripts is unset, not true']); // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
});

test('reading a project npm config never holds its credentials', () => {
  const dir = mkdtempSync(join(tmpdir(), 'toolchain-rc-'));
  try {
    const lines = ['save-exact=true', '//registry.npmjs.org/:_authToken=npm_secret', '_auth=c2VjcmV0', '//r.example/:_password=x', 'email=a@example.invalid', 'certfile=/k.pem', 'min-release-age=14'];
    writeFileSync(join(dir, '.npmrc'), `${lines.join('\n')}\n`); // supply-chain-scan: allow a planted project npm config in a temp folder, to show its credential lines are never read
    const rc = readNpmrc(dir);
    assert.deepEqual(rc, { 'save-exact': 'true', 'min-release-age': '14' });
    assert.ok(!JSON.stringify(rc).includes('secret'));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

function installed(lock, hidden) {
  const dir = mkdtempSync(join(tmpdir(), 'toolchain-'));
  writeFileSync(join(dir, 'package-lock.json'), JSON.stringify({ lockfileVersion: 3, packages: lock }));
  if (hidden) {
    mkdirSync(join(dir, 'node_modules'));
    writeFileSync(join(dir, 'node_modules', '.package-lock.json'), JSON.stringify({ lockfileVersion: 3, packages: hidden }));
  }
  return dir;
}

test('the install matches the lockfile, or each difference is named', () => {
  const a = { version: '1.0.0', integrity: 'sha512-a' };
  const b = { version: '2.0.0', integrity: 'sha512-b' };
  const opt = { version: '3.0.0', integrity: 'sha512-c', optional: true };
  const lock = { '': {}, 'node_modules/a': a, 'node_modules/b': b, 'node_modules/opt': opt };
  const dirs = [];
  const check = (hidden) => {
    const d = installed(lock, hidden);
    dirs.push(d);
    return installProblems(d);
  };
  try {
    assert.deepEqual(check({ 'node_modules/a': a, 'node_modules/b': b }), [], 'an optional package absent is fine');
    assert.match(check(null)[0], /nothing is installed/);
    assert.deepEqual(check({ 'node_modules/a': a, 'node_modules/b': { ...b, version: '2.0.1' } }), ['node_modules/b is 2.0.1 installed, 2.0.0 locked']);
    assert.deepEqual(check({ 'node_modules/a': a, 'node_modules/b': { ...b, integrity: 'sha512-x' } }), ['node_modules/b is 2.0.0 installed, 2.0.0 locked']);
    assert.deepEqual(check({ 'node_modules/a': a }), ['node_modules/b 2.0.0 is locked but not installed']);
    assert.deepEqual(check({ 'node_modules/a': a, 'node_modules/b': b, 'node_modules/x': a }), ['node_modules/x is installed but not in the lockfile']);
  } finally {
    for (const d of dirs) rmSync(d, { recursive: true, force: true });
  }
});

test('the CLI passes this engine\'s own install and refuses what it should, printing the install command', () => {
  const clean = Object.fromEntries(Object.keys(process.env).filter((k) => /^PLAYWRIGHT_.*DOWNLOAD_HOST$/.test(k)).map((k) => [k, '']));
  const own = run([], clean);
  assert.equal(own.code, 0, own.out);
  assert.match(own.out, new RegExp(`toolchain: Node ${process.version} \\(${process.release.lts}, LTS\\), npm \\d+\\.\\d+\\.\\d+, .*installed as locked`));
  assert.equal(run(['--dir', SCRIPTS], clean).code, 0);

  const redirected = run(['--runtime-only'], { ...clean, PLAYWRIGHT_DOWNLOAD_HOST: 'https://mirror.example' });
  assert.equal(redirected.code, 2, redirected.out);
  assert.match(redirected.out, /PLAYWRIGHT_DOWNLOAD_HOST is set/);

  const dir = installed({ '': {}, 'node_modules/a': { version: '1.0.0', integrity: 'sha512-a' } }, null);
  try {
    const missing = run(['--dir', dir], clean);
    assert.equal(missing.code, 2, missing.out);
    assert.match(missing.out, /nothing is installed/);
    assert.match(missing.out, /ask first\): cd ".*" && npm ci --ignore-scripts/);
    assert.equal(run(['--dir', dir, '--runtime-only'], clean).code, 0, 'the runtime alone is fit');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// --- the browser manifest, and the project modes ---------------------------------------------

test('the browser hash covers every file of the folder, and each verdict is named', async () => {
  const { folderHash, platformKey, verifyBrowser } = await import('../lib/browsers.mjs');
  assert.equal(platformKey('darwin', 'arm64'), 'mac-arm64');
  assert.equal(platformKey('linux', 'x64'), 'linux64');
  const root = mkdtempSync(join(tmpdir(), 'browsers-'));
  try {
    const shell = join(root, 'chromium_headless_shell-1', 'chrome-headless-shell-mac-arm64');
    mkdirSync(join(shell, 'lib'), { recursive: true });
    writeFileSync(join(shell, 'chrome'), 'binary');
    writeFileSync(join(shell, 'lib', 'a.dylib'), 'library');
    const h = folderHash(shell);
    assert.equal(h.files, 2);
    const manifest = (sha256, files = 2) => ({ 'chromium-headless-shell': { revision: '1', platforms: { 'mac-arm64': { files, sha256 } } } });
    assert.equal(verifyBrowser(root, manifest(h.sha256), 'mac-arm64').status, 'verified');
    writeFileSync(join(shell, 'lib', 'a.dylib'), 'a library someone changed');
    const changed = verifyBrowser(root, manifest(h.sha256), 'mac-arm64');
    assert.equal(changed.status, 'mismatch', 'a changed library, not only the binary, fails');
    assert.equal(verifyBrowser(root, manifest(h.sha256), 'linux64').status, 'missing');
    mkdirSync(join(root, 'chromium_headless_shell-1', 'chrome-headless-shell-linux64'));
    assert.equal(verifyBrowser(root, manifest(h.sha256), 'linux64').status, 'unrecorded');
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('the recorded browser is the pinned Playwright\'s, with a hash for at least one platform', async () => {
  const { MANIFEST } = await import('../lib/browsers.mjs');
  const m = JSON.parse(readFileSync(MANIFEST, 'utf8'));
  const pkg = JSON.parse(readFileSync(join(SCRIPTS, 'package.json'), 'utf8'));
  assert.equal(m.playwright, pkg.dependencies.playwright, 'browsers.json moves with playwright');
  const pinned = JSON.parse(readFileSync(join(SCRIPTS, 'node_modules/playwright-core/browsers.json'), 'utf8')).browsers.find((b) => b.name === 'chromium-headless-shell');
  assert.equal(m['chromium-headless-shell'].revision, pinned.revision);
  const platforms = Object.values(m['chromium-headless-shell'].platforms);
  assert.ok(platforms.length >= 1);
  for (const p of platforms) assert.match(p.sha256, /^[0-9a-f]{64}$/);
});

test('a project with no toolchain: exit 2, the install command printed; the modes do not mix', () => {
  const dir = mkdtempSync(join(tmpdir(), 'toolchain-project-'));
  const clean = Object.fromEntries(Object.keys(process.env).filter((k) => /^PLAYWRIGHT_.*DOWNLOAD_HOST$/.test(k)).map((k) => [k, '']));
  try {
    const r = run(['--project', dir], clean);
    assert.equal(r.code, 2, r.out);
    assert.match(r.out, /no toolchain installed in this project/);
    assert.match(r.out, /ask first\): node ".*toolchain\.mjs" --install ".*"/);
    assert.equal(run(['--project', dir, '--install', dir], clean).code, 2);
    assert.equal(run(['--project', dir, '--runtime-only'], clean).code, 2);
    assert.equal(run(['--project', join(dir, 'nowhere')], clean).code, 2);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
