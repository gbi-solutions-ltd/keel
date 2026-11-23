/**
 * toolchain.mjs: the Node toolchain policy as data and checks, shared by toolchain.mjs (the
 * preflight), check-lock.mjs and their tests. The policy itself, with its reasons, is
 * DEPENDENCIES.md at the engine's root.
 *
 * - SUPPORTED: the runtime lines tested, as the `engines` every engine-owned package.json carries.
 *   The floors are where npm 11.16 arrives (allowScripts and strict-allow-scripts are new there;
 *   min-release-age is from 11.10): Node 24.18.0 and 26.13.0, the first LTS of line 26.
 * - NPMRC: the settings every engine-owned and scaffolded .npmrc carries. `ignore-scripts=true` is supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
 *   for the engine's own toolchains only: in an app it would also skip the app's own pre-scripts
 *   (`prebuild` runs the API client's generation), so apps deny install scripts per package through
 *   `allowScripts` and `strict-allow-scripts` instead.
 *
 * Import-safe: no side effects.
 */
import fs from 'node:fs';
import path from 'node:path';

export const SUPPORTED = {
  engines: { node: '^24.18.0 || ^26.13.0', npm: '>=11.16.0' },
  /** Node major line to its lowest tested version. */
  lines: { 24: '24.18.0', 26: '26.13.0' },
  npm: '11.16.0',
};

export const NPMRC = { 'save-exact': 'true', 'engine-strict': 'true', 'min-release-age': '14', 'strict-allow-scripts': 'true' };
export const NPMRC_TOOLCHAIN = { ...NPMRC, 'ignore-scripts': 'true' };
export const MIN_RELEASE_AGE_DAYS = 14;

export const REGISTRY = 'https://registry.npmjs.org/';
/** Environment variables that send Playwright's browser download to another host. */
export const DOWNLOAD_HOST_VARS = ['PLAYWRIGHT_DOWNLOAD_HOST', 'PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST', 'PLAYWRIGHT_FIREFOX_DOWNLOAD_HOST', 'PLAYWRIGHT_WEBKIT_DOWNLOAD_HOST'];

const EXACT = /^\d+\.\d+\.\d+$/;
export const isExact = (v) => typeof v === 'string' && EXACT.test(v);

/** `v24.21.0` or `24.21.0` to [24, 21, 0]; null for anything else (a prerelease included). */
export function parseVersion(v) {
  const m = /^v?(\d+)\.(\d+)\.(\d+)$/.exec(String(v ?? '').trim());
  return m ? m.slice(1).map(Number) : null;
}

/** a >= b, both plain versions. */
export function atLeast(a, b) {
  const x = parseVersion(a);
  const y = parseVersion(b);
  if (!x || !y) return false;
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] > y[i];
  return true;
}

/**
 * Why this runtime may not run the engine, as messages (empty: it may).
 * @param {{ version: string, lts: string | undefined, npmVersion: string | null, env?: Record<string, string | undefined> }} rt
 */
export function runtimeProblems({ version, lts, npmVersion, env = {} }) {
  const out = [];
  const v = parseVersion(version);
  if (!v) out.push(`Node ${version} is not a release version`);
  else {
    const floor = SUPPORTED.lines[v[0]];
    if (!lts) out.push(`Node ${version} is not an LTS release (process.release.lts is unset): use an LTS release of line ${Object.keys(SUPPORTED.lines).join(' or ')}`);
    if (!floor) out.push(`Node line ${v[0]} is not one the engine is tested on (${Object.keys(SUPPORTED.lines).join(', ')})`);
    else if (!atLeast(version, floor)) out.push(`Node ${version} is older than ${floor}, the lowest tested on line ${v[0]}`);
  }
  if (npmVersion == null) out.push('npm was not found on PATH');
  else if (!parseVersion(npmVersion)) out.push(`npm ${npmVersion} is not a release version`);
  else if (!atLeast(npmVersion, SUPPORTED.npm)) out.push(`npm ${npmVersion} is older than ${SUPPORTED.npm} (allowScripts and strict-allow-scripts start there)`);
  for (const name of DOWNLOAD_HOST_VARS)
    if (env[name]) out.push(`${name} is set: Playwright would download the browser from ${env[name]}, and checks only its size`);
  return out;
}

export function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

/** Keys that carry or point at a credential: _auth, _authToken, _password, username, email, certfile, keyfile. */
const AUTH_KEY = /(^|:)(_auth\w*|_password|username|email|certfile|keyfile)$/i;

/** An .npmrc as a map of key to value (comments, blank lines and credential keys dropped); null when there is none. supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read */
export function readNpmrc(dir) {
  const file = path.join(dir, '.npmrc'); // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
  if (!fs.existsSync(file)) return null;
  const out = {};
  for (const raw of fs.readFileSync(file, 'utf8').split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#') || line.startsWith(';')) continue;
    const i = line.indexOf('=');
    if (i <= 0) continue;
    const key = line.slice(0, i).trim();
    // A project's config may carry a registry credential; it is never read into memory here.
    if (AUTH_KEY.test(key)) continue;
    out[key] = line.slice(i + 1).trim();
  }
  return out;
}

/** Each way an .npmrc falls short of the required settings, as messages. supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read */
export function npmrcProblems(npmrc, required) {
  if (!npmrc) return ['no .npmrc']; // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
  const out = [];
  for (const [key, want] of Object.entries(required)) {
    const got = npmrc[key];
    if (key === 'min-release-age') {
      if (!(Number(got) >= Number(want))) out.push(`.npmrc min-release-age is ${got ?? 'unset'}, not at least ${want}`); // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
    } else if (got !== want) out.push(`.npmrc ${key} is ${got ?? 'unset'}, not ${want}`); // supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
  }
  return out;
}

/** The package name of a lockfile key: `node_modules/a/node_modules/@s/b` is `@s/b`. */
export const nameOf = (key) => key.slice(key.lastIndexOf('node_modules/') + 'node_modules/'.length);

/**
 * Whether what is installed in dir/node_modules is the tree dir/package-lock.json locks, compared
 * through npm's own record of the install (node_modules/.package-lock.json). Messages; empty when
 * it is. An optional package absent is fine (another platform's binary).
 */
export function installProblems(dir) {
  const lockFile = path.join(dir, 'package-lock.json');
  if (!fs.existsSync(lockFile)) return [`no package-lock.json in ${dir}`];
  const hidden = path.join(dir, 'node_modules', '.package-lock.json');
  if (!fs.existsSync(hidden)) return [`nothing is installed in ${dir} (no node_modules/.package-lock.json)`];
  const want = readJson(lockFile).packages ?? {};
  const got = readJson(hidden).packages ?? {};
  const out = [];
  for (const [key, entry] of Object.entries(got)) {
    const w = want[key];
    if (!w) out.push(`${key} is installed but not in the lockfile`);
    else if (w.version !== entry.version || w.integrity !== entry.integrity) out.push(`${key} is ${entry.version} installed, ${w.version} locked`);
  }
  for (const [key, entry] of Object.entries(want)) if (key && !entry.optional && !got[key]) out.push(`${key} ${entry.version} is locked but not installed`);
  return out;
}
