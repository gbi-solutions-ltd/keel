#!/usr/bin/env node
/**
 * toolchain.mjs: the preflight every engine step that needs Node runs first, and the install it
 * asks for. It refuses, with the reason, a runtime the engine is not tested on, and a toolchain that
 * is not installed as locked.
 *
 *   node toolchain.mjs --project <dir>              check the project's toolchain; print S=<scripts>
 *   node toolchain.mjs --install <dir>              install it there (reaches the registry: ask first)
 *   node toolchain.mjs [--dir <scripts dir>] [--runtime-only]   check an install in place
 *
 * Runtime: Node is an LTS release (process.release.lts) of a tested line at or above its floor;
 * npm is at least the version whose install-script policy the .npmrc files rely on (supply-chain-scan: allow npm's project config, named, not read here); no variable
 * sends Playwright's browser download elsewhere.
 *
 * A project's toolchain is a copy of this engine in <dir>/.mockup-engine/toolchain/ (the scripts,
 * templates and schema, never another project's install), kept out of the project's git by a
 * .gitignore of `*` in .mockup-engine/, its packages from `npm ci --ignore-scripts`, and its browser
 * in its own browsers/ folder, checked against browsers.json. install.json records the engine's
 * fingerprint, so a toolchain from another engine version reads as stale and is installed again.
 * Removing the folder removes all of it.
 *
 * Exit 0 fit to run (or installed), 1 the browser downloaded is not the one recorded, 2 not fit to
 * run or the install failed (each reason printed, and the one command to run when it is missing).
 * The policy and its reasons: DEPENDENCIES.md.
 */
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { cli, usageError } from './lib/args.mjs';
import { verifyBrowser } from './lib/browsers.mjs';
import { installProblems, runtimeProblems } from './lib/toolchain.mjs';

const { values } = cli('toolchain');
const SCRIPTS = path.dirname(fileURLToPath(import.meta.url));
const ENGINE = path.dirname(SCRIPTS);
const modes = ['dir', 'project', 'install'].filter((k) => values[k] != null);
if (modes.length > 1) usageError('toolchain', `--${modes.join(' and --')} are separate modes`);
if (values['runtime-only'] && (values.project || values.install)) usageError('toolchain', '--runtime-only applies to the in-place check');

const NPM = process.platform === 'win32' ? 'npm.cmd' : 'npm';
const npm = spawnSync(NPM, ['--version'], { encoding: 'utf8' });
const npmVersion = npm.status === 0 ? npm.stdout.trim() : null;
const problems = runtimeProblems({ version: process.version, lts: process.release.lts, npmVersion, env: process.env });
const runtime = `Node ${process.version} (${process.release.lts}, LTS), npm ${npmVersion}`;
const say = (m) => console.log(`toolchain: ${m}`);
function refuse(lines, code = 2) {
  for (const l of lines) say(l);
  process.exit(code);
}
if (problems.length) refuse(problems);

/** What an install copies: everything in the engine but installs, outputs and the scripts' tests. */
const SKIP = new Set(['node_modules', '.mockup-engine', 'browsers']);
const copied = (src) => !SKIP.has(path.basename(src)) && path.relative(ENGINE, src) !== path.join('scripts', 'test');

/** The engine's fingerprint: every file an install copies, by path and content. */
function fingerprint() {
  const lines = [];
  const walk = (d) => {
    for (const e of readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const p = path.join(d, e.name);
      if (!copied(p)) continue;
      if (e.isDirectory()) walk(p);
      else lines.push(`${path.relative(ENGINE, p)} ${createHash('sha256').update(readFileSync(p)).digest('hex')}`);
    }
  };
  walk(ENGINE);
  return createHash('sha256').update(lines.join('\n')).digest('hex');
}

if (values.install || values.project) {
  const project = path.resolve(values.install ?? values.project);
  if (!existsSync(project) || !statSync(project).isDirectory()) usageError('toolchain', `${project} is not a folder`);
  const home = path.join(project, '.mockup-engine');
  const T = path.join(home, 'toolchain');
  const record = path.join(T, 'install.json');
  const installCmd = `node ${JSON.stringify(path.join(SCRIPTS, 'toolchain.mjs'))} --install ${JSON.stringify(project)}`;

  if (values.project) {
    const want = fingerprint();
    const rec = existsSync(record) ? JSON.parse(readFileSync(record, 'utf8')) : null;
    const why = !rec ? ['no toolchain installed in this project']
      : rec.fingerprint !== want ? ['the toolchain installed here is from another engine version']
        : installProblems(path.join(T, 'scripts'));
    if (!why.length && rec.browser === 'mismatch') why.push('its browser did not match the recorded hash; install again');
    if (why.length) refuse([...why.slice(0, 10), `install it (reaches registry.npmjs.org and Playwright's CDN, about 300 MB; ask first): ${installCmd}`]);
    say(`${runtime}; the project's toolchain is installed as locked; browser ${rec.browser}${rec.browser === 'unrecorded' ? ' (no hash recorded for this platform)' : ''}`);
    console.log(`S=${path.join(T, 'scripts')}`);
    process.exit(0);
  }

  // --install: a fresh copy, its packages as locked with no install scripts, then its browser.
  mkdirSync(home, { recursive: true });
  const ignore = path.join(home, '.gitignore');
  if (!existsSync(ignore)) writeFileSync(ignore, '# The engine writes outputs and its toolchain here; none of it belongs in git.\n*\n');
  rmSync(T, { recursive: true, force: true });
  cpSync(ENGINE, T, { recursive: true, filter: copied });
  const ci = spawnSync(NPM, ['ci', '--ignore-scripts', '--no-audit', '--no-fund'], { cwd: path.join(T, 'scripts'), stdio: 'inherit' });
  if (ci.status !== 0) refuse([`npm ci failed in ${path.join(T, 'scripts')} (exit ${ci.status})`]);
  const browsers = path.join(T, 'browsers');
  const env = { ...process.env, PLAYWRIGHT_BROWSERS_PATH: browsers };
  const pw = spawnSync(path.join(T, 'scripts/node_modules/.bin/playwright'), ['install', 'chromium-headless-shell'], { cwd: path.join(T, 'scripts'), stdio: 'inherit', env });
  if (pw.status !== 0) refuse([`the browser download failed (exit ${pw.status})`]);
  const check = verifyBrowser(browsers);
  writeFileSync(record, `${JSON.stringify({ fingerprint: fingerprint(), installedAt: new Date().toISOString(), runtime, browser: check.status }, null, 2)}\n`);
  if (check.status === 'mismatch') refuse([`the browser in ${check.dir} is not the one recorded for ${check.key}: ${check.got.files} files, sha256 ${check.got.sha256}; recorded ${check.want.files}, ${check.want.sha256}. Not used: install again, and report it if it persists`], 1);
  if (check.status === 'missing') refuse([`no headless shell under ${browsers} after the download`]);
  say(`installed in ${T}; browser ${check.status}${check.status === 'unrecorded' ? ` (no hash recorded for ${check.key}: it runs, unverified)` : ''}`);
  console.log(`S=${path.join(T, 'scripts')}`);
  process.exit(0);
}

const dir = path.resolve(values.dir ?? SCRIPTS);
const install = values['runtime-only'] ? [] : installProblems(dir);
if (!install.length) {
  say(`${runtime}${values['runtime-only'] ? '' : `, ${dir} installed as locked`}`);
  process.exit(0);
}
for (const p of install.slice(0, 10)) say(p);
if (install.length > 10) say(`and ${install.length - 10} more`);
refuse([`install the locked tree (reaches registry.npmjs.org; ask first): cd ${JSON.stringify(dir)} && npm ci --ignore-scripts`]);
