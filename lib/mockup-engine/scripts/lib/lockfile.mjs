/**
 * lockfile.mjs: what check-lock.mjs checks in one folder's package.json, package-lock.json and
 * .npmrc, as messages. A lockfile is checked, not trusted: it must name only the public registry supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
 * with sha512 hashes, match its package.json, run no install script nobody reviewed, and, for the
 * engine's own toolchains, hold exactly the recorded number of packages. It must also be complete:
 * every dependency of every entry resolves to an entry. A package bundled in
 * another's tarball (inBundle) is covered by that tarball's hash, when the parent declares it.
 *
 * lockProblems(dir, policy) with policy:
 *   npmrc         the settings the .npmrc must carry (lib/toolchain.mjs NPMRC or NPMRC_TOOLCHAIN) supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
 *   engines       when set, package.json's engines must equal it exactly
 *   installScripts 'none' (no package may have one) or 'reviewed' (each covered by allowScripts:
 *                 denied with false, or approved with true on a name@version that matches)
 *   packages      when set, the tree's package count must equal it (raise it in the same commit)
 *   duplicates    when set, the names allowed at more than one version (and only those)
 *   prereleases   names allowed at a prerelease version, to the reason; an optional package's
 *                 prerelease (another platform's binary) is allowed without one
 *
 * Import-safe: no side effects.
 */
import fs from 'node:fs';
import path from 'node:path';
import { isExact, nameOf, npmrcProblems, readJson, readNpmrc, REGISTRY } from './toolchain.mjs';

const DEP_FIELDS = ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies'];

const same = (a, b) => JSON.stringify(a ?? {}) === JSON.stringify(b ?? {});

/** Whether allowScripts covers an install script of name at version, and how. */
export function scriptCover(allowScripts, name, version) {
  let approved = null;
  for (const [key, value] of Object.entries(allowScripts ?? {})) {
    const at = key.lastIndexOf('@');
    const keyName = at > 0 ? key.slice(0, at) : key;
    const keyVersion = at > 0 ? key.slice(at + 1) : null;
    if (keyName !== name) continue;
    if (value === false) return 'denied';
    if (value === true && keyVersion === version) approved = 'approved';
    else if (value === true && keyVersion === null) approved ??= 'any-version';
  }
  return approved;
}

/** Whether dep is found from the package at key the way Node looks it up: nested first, then each folder up. */
export function resolves(packages, key, dep) {
  let base = key;
  for (;;) {
    if (packages[`${base ? `${base}/` : ''}node_modules/${dep}`]) return true;
    if (!base) return false;
    const i = base.lastIndexOf('/node_modules/');
    base = i < 0 ? '' : base.slice(0, i);
  }
}

export function lockProblems(dir, policy) {
  const out = [];
  const pkgFile = path.join(dir, 'package.json');
  const lockFile = path.join(dir, 'package-lock.json');
  if (!fs.existsSync(pkgFile)) return { problems: [`no package.json`], count: 0 };
  if (!fs.existsSync(lockFile)) return { problems: [`no package-lock.json`], count: 0 };
  const pkg = readJson(pkgFile);
  const lock = readJson(lockFile);
  const packages = lock.packages ?? {};
  const root = packages[''] ?? {};

  if (lock.lockfileVersion !== 3) out.push(`lockfileVersion is ${lock.lockfileVersion}, not 3`);
  out.push(...npmrcProblems(readNpmrc(dir), policy.npmrc)); // supply-chain-scan: allow the policy field named npmrc, not a file

  // engines: present always; the tested range exactly when the policy names it.
  if (!pkg.engines?.node || !pkg.engines?.npm) out.push('package.json engines does not name both node and npm');
  else if (policy.engines && !same(pkg.engines, policy.engines)) out.push(`package.json engines is ${JSON.stringify(pkg.engines)}, not ${JSON.stringify(policy.engines)}`);

  // The lockfile is current: its root entry records the same dependencies and engines.
  for (const field of [...DEP_FIELDS, 'engines'])
    if (!same(pkg[field], root[field])) out.push(`the lockfile is out of date: its ${field} differs from package.json's (run npm install --package-lock-only)`);

  // Direct dependencies: exact pins, the hoisted copy at that version.
  for (const field of DEP_FIELDS.slice(0, 3)) {
    for (const [name, spec] of Object.entries(pkg[field] ?? {})) {
      if (!isExact(spec)) out.push(`${field}.${name} is ${JSON.stringify(spec)}, not an exact version`);
      else if (packages[`node_modules/${name}`]?.version !== spec) out.push(`${field}.${name} is ${spec}, the lockfile has ${packages[`node_modules/${name}`]?.version ?? 'none'}`);
    }
  }
  // Flat overrides: exact, and every copy of that package at that version.
  for (const [name, spec] of Object.entries(pkg.overrides ?? {})) {
    if (typeof spec !== 'string') continue;
    if (!isExact(spec)) out.push(`overrides.${name} is ${JSON.stringify(spec)}, not an exact version`);
    for (const [key, entry] of Object.entries(packages)) if (key && nameOf(key) === name && entry.version !== spec) out.push(`overrides.${name} is ${spec}, ${key} is ${entry.version}`);
  }

  const versions = new Map();
  let count = 0;
  for (const [key, entry] of Object.entries(packages)) {
    if (!key) continue;
    count++;
    const name = nameOf(key);
    if (entry.link) {
      out.push(`${key} is a link to ${entry.resolved}, not a registry package`);
      continue;
    }
    if (entry.inBundle) {
      // Shipped inside its parent's tarball, so the parent's hash covers it: the parent must declare it.
      const parentKey = key.slice(0, key.lastIndexOf('/node_modules/'));
      const parent = packages[parentKey];
      if (!parent?.bundleDependencies?.includes(name)) out.push(`${key} is marked bundled, but ${parentKey || 'its parent'} does not declare it in bundleDependencies`);
    } else {
      if (!String(entry.resolved ?? '').startsWith(REGISTRY)) out.push(`${key} resolves from ${entry.resolved ?? 'nowhere'}, not ${REGISTRY}`);
      if (!String(entry.integrity ?? '').startsWith('sha512-')) out.push(`${key} has ${entry.integrity ? 'a non-sha512' : 'no'} integrity hash`);
    }
    if (entry.hasInstallScript) {
      if (policy.installScripts === 'none') out.push(`${key} ${entry.version} has an install script, and this toolchain allows none`);
      else {
        const cover = scriptCover(pkg.allowScripts, name, entry.version);
        if (!cover) out.push(`${key} ${entry.version} has an install script allowScripts does not cover (deny it with false, or approve ${name}@${entry.version})`);
        else if (cover === 'any-version') out.push(`${key} has an install script approved for any version: pin the approval to ${name}@${entry.version}`);
      }
    }
    if (!/^\d+\.\d+\.\d+$/.test(entry.version ?? '') && !entry.optional && !policy.prereleases?.[name])
      out.push(`${key} is ${entry.version}, a prerelease no allowance names`);
    if (!versions.has(name)) versions.set(name, new Set());
    versions.get(name).add(entry.version);
  }

  // Complete: every dependency of every entry resolves, by Node's lookup, to an entry. An optional
  // dependency, or a peer marked optional, may be absent.
  for (const [key, entry] of Object.entries(packages)) {
    if (entry.link) continue;
    const optionalPeers = Object.entries(entry.peerDependenciesMeta ?? {}).filter(([, m]) => m?.optional).map(([n]) => n);
    const needed = [...Object.keys(entry.dependencies ?? {}), ...Object.keys(entry.peerDependencies ?? {}).filter((n) => !optionalPeers.includes(n))];
    if (!key) needed.push(...Object.keys(entry.devDependencies ?? {}));
    for (const dep of new Set(needed)) if (!resolves(packages, key, dep)) out.push(`the lockfile is incomplete: ${key || 'the root'} needs ${dep}, which no entry provides (run npm install --package-lock-only, then check again)`);
  }

  if (policy.duplicates) {
    const dup = [...versions].filter(([, s]) => s.size > 1).map(([n]) => n);
    for (const n of dup) if (!policy.duplicates.includes(n)) out.push(`${n} is in the tree at ${[...versions.get(n)].join(' and ')}: dedupe it (overrides) or allow it`);
    for (const n of policy.duplicates) if (!dup.includes(n)) out.push(`${n} is allowed to be duplicated but is not: drop the allowance`);
  }
  if (policy.packages != null && count !== policy.packages)
    out.push(`the tree has ${count} packages, the recorded count is ${policy.packages}: ${count > policy.packages ? 'a new package is a decision, raise the count with its reason' : 'lower the count'}`);
  return { problems: out, count };
}
