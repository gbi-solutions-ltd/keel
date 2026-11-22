/**
 * check-lock.test.mjs: every lockfile the engine owns passes check-lock.mjs; every package.json
 * the engine owns carries the tested engines and an .npmrc; DEPENDENCIES.md has an entry for every supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
 * direct dependency of the engine's toolchains; and each rule fails on its planted defect. The
 * examples' lockfiles, and the scaffold's against them, are held by the proof suite.
 * Run: node --test test/check-lock.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { lockProblems, scriptCover } from '../lib/lockfile.mjs';
import { NPMRC, NPMRC_TOOLCHAIN, SUPPORTED } from '../lib/toolchain.mjs';

const SCRIPT = fileURLToPath(new URL('../check-lock.mjs', import.meta.url));
const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const ENGINE = fileURLToPath(new URL('../..', import.meta.url));
const read = (f) => JSON.parse(readFileSync(f, 'utf8'));
const run = (args) => {
  const r = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: 'utf8', cwd: SCRIPTS });
  return { code: r.status, out: r.stdout + r.stderr };
};
const CONFIG = read(join(SCRIPTS, 'lockfiles.json')).lockfiles;
const STACKS = ['react-vite', 'vue', 'nextjs'];

test('every lockfile the engine owns passes', () => {
  const r = run([]);
  assert.equal(r.code, 0, r.out);
  for (const rel of Object.keys(CONFIG)) assert.match(r.out, new RegExp(`check-lock: ${rel.replace(/[.]/g, '\\.')}: ok, ${CONFIG[rel].packages} packages`));
});

test('every package.json the engine owns carries the tested engines and an .npmrc', () => { // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
  const dirs = [SCRIPTS, join(ENGINE, 'templates/sample-backend'), ...STACKS.map((s) => join(ENGINE, 'templates/app-scaffold', s))];
  for (const d of dirs) {
    assert.deepEqual(read(join(d, 'package.json')).engines, SUPPORTED.engines, d);
    assert.ok(existsSync(join(d, '.npmrc')), `${d} has no .npmrc`); // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
  }
});

test('DEPENDENCIES.md has an entry for every direct dependency of the engine\'s own toolchains', () => {
  const doc = readFileSync(join(ENGINE, 'DEPENDENCIES.md'), 'utf8');
  for (const d of [SCRIPTS, join(ENGINE, 'templates/sample-backend')]) {
    const pkg = read(join(d, 'package.json'));
    for (const name of [...Object.keys(pkg.dependencies ?? {}), ...Object.keys(pkg.overrides ?? {})])
      assert.ok(doc.includes(`| \`${name}\` |`), `DEPENDENCIES.md has no row for ${name}`);
  }
});

test('allowScripts: a denial or a pinned approval covers a script, a name-only approval is flagged', () => {
  assert.equal(scriptCover({ esbuild: false }, 'esbuild', '0.25.0'), 'denied');
  assert.equal(scriptCover({ 'esbuild@0.25.0': true }, 'esbuild', '0.25.0'), 'approved');
  assert.equal(scriptCover({ 'esbuild@0.24.0': true }, 'esbuild', '0.25.0'), null);
  assert.equal(scriptCover({ esbuild: true }, 'esbuild', '0.25.0'), 'any-version');
  assert.equal(scriptCover({ '@scope/x@1.0.0': true }, '@scope/x', '1.0.0'), 'approved');
  assert.equal(scriptCover({}, 'esbuild', '0.25.0'), null);
});

// --- plants: each rule against a copy of the scripts' own toolchain -----------------------------

const POLICY = { npmrc: NPMRC_TOOLCHAIN, engines: SUPPORTED.engines, installScripts: 'none', packages: CONFIG['.'].packages, duplicates: [], prereleases: {} };

/** Copy the scripts' package.json, lockfile and .npmrc, change them, and return the problems. supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read */
function planted(change, policy = POLICY) {
  const dir = mkdtempSync(join(tmpdir(), 'check-lock-'));
  try {
    for (const f of ['package.json', 'package-lock.json', '.npmrc']) cpSync(join(SCRIPTS, f), join(dir, f)); // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
    const pkg = read(join(dir, 'package.json'));
    const lock = read(join(dir, 'package-lock.json'));
    const npmrc = { text: readFileSync(join(dir, '.npmrc'), 'utf8') }; // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
    change({ pkg, lock, npmrc, p: lock.packages });
    writeFileSync(join(dir, 'package.json'), JSON.stringify(pkg));
    writeFileSync(join(dir, 'package-lock.json'), JSON.stringify(lock));
    writeFileSync(join(dir, '.npmrc'), npmrc.text); // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
    return lockProblems(dir, policy).problems;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
const Y = 'node_modules/yaml';

test('the unchanged copy passes', () => assert.deepEqual(planted(() => {}), []));

test('a source other than the registry, a missing or weak hash, a link: each refused', () => {
  assert.deepEqual(planted(({ p }) => (p[Y].resolved = 'git+ssh://git@github.com/eemeli/yaml.git#abc')), [`${Y} resolves from git+ssh://git@github.com/eemeli/yaml.git#abc, not https://registry.npmjs.org/`]);
  assert.deepEqual(planted(({ p }) => (p[Y].resolved = 'https://registry.example.com/yaml/-/yaml-2.9.1.tgz')), [`${Y} resolves from https://registry.example.com/yaml/-/yaml-2.9.1.tgz, not https://registry.npmjs.org/`]);
  assert.deepEqual(planted(({ p }) => delete p[Y].integrity), [`${Y} has no integrity hash`]);
  assert.deepEqual(planted(({ p }) => (p[Y].integrity = 'sha1-abc')), [`${Y} has a non-sha512 integrity hash`]);
  assert.ok(planted(({ p }) => (p[Y] = { resolved: '../yaml', link: true })).includes(`${Y} is a link to ../yaml, not a registry package`));
});

test('an install script: none allowed in a toolchain; in an app, only a reviewed one', () => {
  assert.deepEqual(planted(({ p }) => (p[Y].hasInstallScript = true)), [`${Y} 2.9.1 has an install script, and this toolchain allows none`]);
  const app = { ...POLICY, installScripts: 'reviewed' };
  assert.match(planted(({ p }) => (p[Y].hasInstallScript = true), app).join('\n'), /allowScripts does not cover \(deny it with false, or approve yaml@2\.9\.1\)/);
  assert.deepEqual(planted(({ p, pkg }) => ((p[Y].hasInstallScript = true), (pkg.allowScripts = { yaml: false })), app), []);
  assert.deepEqual(planted(({ p, pkg }) => ((p[Y].hasInstallScript = true), (pkg.allowScripts = { 'yaml@2.9.1': true })), app), []);
  assert.deepEqual(planted(({ p, pkg }) => ((p[Y].hasInstallScript = true), (pkg.allowScripts = { yaml: true })), app), [`${Y} has an install script approved for any version: pin the approval to yaml@2.9.1`]);
});

test('pins: a range, a lockfile out of date, the hoisted copy at another version, an override not held', () => {
  assert.deepEqual(planted(({ pkg, p }) => ((pkg.dependencies.yaml = '^2.9.1'), (p[''].dependencies.yaml = '^2.9.1'))), ['dependencies.yaml is "^2.9.1", not an exact version']);
  assert.deepEqual(planted(({ pkg }) => (pkg.dependencies.yaml = '2.9.2')), ["the lockfile is out of date: its dependencies differs from package.json's (run npm install --package-lock-only)", 'dependencies.yaml is 2.9.2, the lockfile has 2.9.1']);
  assert.deepEqual(planted(({ p }) => (p[Y].version = '2.9.0')), ['dependencies.yaml is 2.9.1, the lockfile has 2.9.0']);
  assert.match(planted(({ p }) => (p['node_modules/playwright-core'].version = '1.64.1')).join('\n'), /overrides\.playwright-core is 1\.63\.0, node_modules\/playwright-core is 1\.64\.1/);
  assert.match(planted(({ pkg }) => (pkg.overrides['playwright-core'] = '>=1.63.0')).join('\n'), /overrides\.playwright-core is ">=1\.63\.0", not an exact version/);
});

test('the tree: a new package, a duplicate, a stale allowance, a prerelease', () => {
  const extra = { version: '1.0.0', resolved: 'https://registry.npmjs.org/x/-/x-1.0.0.tgz', integrity: 'sha512-x' };
  assert.deepEqual(planted(({ p }) => (p['node_modules/x'] = extra)), [`the tree has ${POLICY.packages + 1} packages, the recorded count is ${POLICY.packages}: a new package is a decision, raise the count with its reason`]);
  const twice = planted(({ p }) => (p['node_modules/playwright/node_modules/yaml'] = { ...p[Y], version: '2.8.0' }), { ...POLICY, packages: undefined });
  assert.deepEqual(twice, ['yaml is in the tree at 2.9.1 and 2.8.0: dedupe it (overrides) or allow it']);
  assert.deepEqual(planted(() => {}, { ...POLICY, duplicates: ['yaml'] }), ['yaml is allowed to be duplicated but is not: drop the allowance']);
  assert.deepEqual(planted(({ p }) => (p[Y].version = '3.0.0-rc.1'), { ...POLICY }).filter((m) => /prerelease/.test(m)), [`${Y} is 3.0.0-rc.1, a prerelease no allowance names`]);
  assert.deepEqual(planted(({ p }) => ((p[Y].version = '3.0.0-rc.1'), (p[Y].optional = true))).filter((m) => /prerelease/.test(m)), [], "an optional package's prerelease is another platform's");
  assert.deepEqual(planted(({ p }) => (p[Y].version = '3.0.0-rc.1'), { ...POLICY, prereleases: { yaml: 'reason' } }).filter((m) => /prerelease/.test(m)), []);
});

test('a bundled package passes only when its parent declares it', () => {
  const bundled = (declare) => ({ p }) => {
    p['node_modules/playwright/node_modules/tiny'] = { version: '1.0.0', inBundle: true };
    if (declare) p['node_modules/playwright'].bundleDependencies = ['tiny'];
  };
  const policy = { ...POLICY, packages: POLICY.packages + 1 };
  assert.deepEqual(planted(bundled(true), policy), []);
  assert.deepEqual(planted(bundled(false), policy), ['node_modules/playwright/node_modules/tiny is marked bundled, but node_modules/playwright does not declare it in bundleDependencies']);
});

test('the .npmrc and engines: each weaker setting named', () => { // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
  assert.deepEqual(planted(({ npmrc }) => (npmrc.text = npmrc.text.replace('min-release-age=14', 'min-release-age=3'))), ['.npmrc min-release-age is 3, not at least 14']); // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
  assert.deepEqual(planted(({ npmrc }) => (npmrc.text = npmrc.text.replace('ignore-scripts=true\n', ''))), ['.npmrc ignore-scripts is unset, not true']); // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
  assert.deepEqual(planted(() => {}, { ...POLICY, npmrc: NPMRC }), [], 'an app needs no ignore-scripts');
  assert.deepEqual(planted(({ pkg, p }) => ((pkg.engines.node = '>=22'), (p[''].engines.node = '>=22'))), [`package.json engines is {"node":">=22","npm":">=11.16.0"}, not ${JSON.stringify(SUPPORTED.engines)}`]);
  assert.deepEqual(planted(({ pkg, p }) => (delete pkg.engines.npm, delete p[''].engines.npm), { ...POLICY, engines: undefined }), ['package.json engines does not name both node and npm']);
  assert.deepEqual(planted(({ lock }) => (lock.lockfileVersion = 2)), ['lockfileVersion is 2, not 3']);
});

test('the CLI: exit 1 naming the folder, 2 for bad usage', () => {
  const dir = mkdtempSync(join(tmpdir(), 'check-lock-cli-'));
  try {
    for (const f of ['package.json', 'package-lock.json']) cpSync(join(SCRIPTS, f), join(dir, f));
    const r = run([dir]);
    assert.equal(r.code, 1, r.out);
    assert.match(r.out, /FAIL no \.npmrc/); // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
    assert.equal(run(['--packages', '3']).code, 2);
    assert.equal(run([dir, SCRIPTS, '--packages', '3']).code, 2);
    assert.equal(run([join(dir, 'nowhere')]).code, 2);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
