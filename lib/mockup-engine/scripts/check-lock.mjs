#!/usr/bin/env node
/**
 * check-lock.mjs: every lockfile the engine owns, or the folders named, checked against the
 * toolchain policy (DEPENDENCIES.md; the rules are lib/lockfile.mjs).
 *
 *   node check-lock.mjs                         every entry of lockfiles.json (next to this script)
 *   node check-lock.mjs <dir>... [--packages N]  the folders named, as apps: install scripts
 *                                                reviewed through allowScripts, the app .npmrc supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
 *
 * Offline: it reads files only. The registry's signatures (`npm audit signatures`) and release
 * ages (release-age.mjs) are checked at every dependency update, not here.
 *
 * Exit 0 every lockfile passes, 1 a rule fails (each printed with its folder), 2 bad usage or a
 * lockfiles.json that cannot be read.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { cli, usageError } from './lib/args.mjs';
import { lockProblems } from './lib/lockfile.mjs';
import { NPMRC, NPMRC_TOOLCHAIN, SUPPORTED } from './lib/toolchain.mjs';

const { values, positional } = cli('check-lock');
const here = path.dirname(fileURLToPath(import.meta.url));

/** lockfiles.json's entries as [label, dir, policy]. */
function configured(file) {
  const config = JSON.parse(fs.readFileSync(file, 'utf8'));
  const base = path.dirname(file);
  return Object.entries(config.lockfiles ?? {}).map(([rel, entry]) => [
    rel,
    path.resolve(base, rel),
    {
      npmrc: entry.toolchain ? NPMRC_TOOLCHAIN : NPMRC,
      engines: SUPPORTED.engines,
      installScripts: entry.toolchain ? 'none' : 'reviewed',
      packages: entry.packages,
      duplicates: entry.duplicates,
      prereleases: entry.prereleases ?? {},
    },
  ]);
}

let targets;
if (positional.length) {
  if (values.packages != null && positional.length > 1) usageError('check-lock', '--packages applies to one folder');
  const packages = values.packages == null ? undefined : Number(values.packages);
  if (packages !== undefined && !Number.isInteger(packages)) usageError('check-lock', `--packages ${values.packages} is not a whole number`);
  targets = positional.map((d) => [d, path.resolve(d), { npmrc: NPMRC, installScripts: 'reviewed', packages }]);
} else {
  if (values.packages != null) usageError('check-lock', '--packages applies to a folder named, not to lockfiles.json');
  try {
    targets = configured(path.join(here, 'lockfiles.json'));
  } catch (e) {
    usageError('check-lock', `lockfiles.json: ${e.message}`);
  }
}

let failed = 0;
for (const [label, dir, policy] of targets) {
  if (!fs.existsSync(dir)) usageError('check-lock', `${label}: no such folder`);
  const { problems, count } = lockProblems(dir, policy);
  if (!problems.length) console.log(`check-lock: ${label}: ok, ${count} packages`);
  for (const p of problems) console.log(`check-lock: ${label}: FAIL ${p}`);
  if (problems.length) failed++;
}
if (failed) console.log(`check-lock: ${failed} of ${targets.length} failed`);
process.exit(failed ? 1 : 0);
