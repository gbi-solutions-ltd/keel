#!/usr/bin/env node
/**
 * release-age.mjs: every version a lockfile installs was published at least --days ago (default
 * 14), from the registry's own publish times. `npm ci` does not apply `min-release-age` to a
 * version already in a lockfile (only `npm install` resolving one), so this is the check that the
 * locked tree kept the rule. Run at every dependency update, before the commit.
 *
 *   node release-age.mjs <dir>... [--days N] [--since <git-ref>] [--prune] [--registry <url>]
 *
 * --since checks only the versions that were not in that folder's lockfile at <git-ref> (the ones
 * an update brought in). --prune removes each version too young (and what is nested under it) from
 * the lockfile, so that `npm install --package-lock-only`, under the .npmrc's min-release-age, supply-chain-scan: allow a project's own npm config, read for its policy settings only; credential keys are never read
 * re-resolves only those; run it, then this again. --registry is for the tests (a local stand-in).
 *
 * Reaches the registry (one request per package name). Exit 0 every version is old enough (or,
 * with --prune, the lockfiles were rewritten), 1 one is younger than --days or has no publish
 * time, 2 bad usage, an unreadable lockfile, or the registry unreachable.
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { cli, usageError } from './lib/args.mjs';
import { MIN_RELEASE_AGE_DAYS, nameOf, REGISTRY } from './lib/toolchain.mjs';

const { values, positional } = cli('release-age');
const days = values.days == null ? MIN_RELEASE_AGE_DAYS : Number(values.days);
if (!Number.isFinite(days) || days < 0) usageError('release-age', `--days ${values.days} is not a number of days`);
const registry = (values.registry ?? REGISTRY).replace(/\/?$/, '/');

/** name@version strings a lockfile installs. */
function locked(text) {
  const out = new Set();
  for (const [key, entry] of Object.entries(JSON.parse(text).packages ?? {})) if (key && !entry.link && !entry.inBundle) out.add(`${nameOf(key)}@${entry.version}`);
  return out;
}

const wanted = new Map(); // name -> Set(version)
for (const d of positional) {
  const file = path.resolve(d, 'package-lock.json');
  if (!fs.existsSync(file)) usageError('release-age', `${d}: no package-lock.json`);
  let entries = locked(fs.readFileSync(file, 'utf8'));
  if (values.since) {
    let before = new Set();
    try {
      const rel = path.relative(execFileSync('git', ['rev-parse', '--show-toplevel'], { cwd: path.dirname(file), encoding: 'utf8' }).trim(), fs.realpathSync(file));
      before = locked(execFileSync('git', ['show', `${values.since}:${rel}`], { cwd: path.dirname(file), encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 64 << 20 }));
    } catch {
      // not in that commit: every version is new
    }
    entries = new Set([...entries].filter((e) => !before.has(e)));
  }
  for (const e of entries) {
    const at = e.lastIndexOf('@');
    const name = e.slice(0, at);
    if (!wanted.has(name)) wanted.set(name, new Set());
    wanted.get(name).add(e.slice(at + 1));
  }
}

async function publishTimes(name) {
  const url = registry + name.replace('/', '%2f');
  for (let attempt = 1; ; attempt++) {
    try {
      const res = await fetch(url, { headers: { accept: 'application/json' } });
      if (!res.ok) throw new Error(`${res.status} from ${url}`);
      return (await res.json()).time ?? {};
    } catch (e) {
      if (attempt === 3) throw e;
    }
  }
}

const now = Date.now();
const young = [];
const youngIds = new Set();
let checked = 0;
let oldest = null;
const names = [...wanted.keys()];
try {
  for (let i = 0; i < names.length; i += 8) {
    await Promise.all(
      names.slice(i, i + 8).map(async (name) => {
        const times = await publishTimes(name);
        for (const v of wanted.get(name)) {
          checked++;
          const at = Date.parse(times[v]);
          if (!Number.isFinite(at)) young.push(`${name}@${v} has no publish time in the registry`);
          else {
            const age = (now - at) / 864e5;
            if (age < days) youngIds.add(`${name}@${v}`);
            if (age < days) young.push(`${name}@${v} was published ${age.toFixed(1)} days ago (${times[v].slice(0, 10)}), under ${days}`);
            if (oldest == null || age < oldest.age) oldest = { age, id: `${name}@${v}` };
          }
        }
      }),
    );
  }
} catch (e) {
  console.error(`release-age: the registry could not be read: ${e.message}`);
  process.exit(2);
}

for (const y of young.sort()) console.log(`release-age: FAIL ${y}`);
console.log(`release-age: ${checked} versions checked${values.since ? ` (new since ${values.since})` : ''}, ${young.length} under ${days} days${oldest ? `; the youngest ${oldest.id}, ${oldest.age.toFixed(1)} days` : ''}`);
if (values.prune && youngIds.size) {
  for (const d of positional) {
    const file = path.resolve(d, 'package-lock.json');
    const lock = JSON.parse(fs.readFileSync(file, 'utf8'));
    const drop = Object.keys(lock.packages ?? {}).filter((k) => k && youngIds.has(`${nameOf(k)}@${lock.packages[k].version}`));
    let removed = 0;
    for (const k of Object.keys(lock.packages))
      if (drop.some((x) => k === x || k.startsWith(`${x}/node_modules/`))) {
        delete lock.packages[k];
        removed++;
      }
    if (!removed) continue;
    fs.writeFileSync(file, `${JSON.stringify(lock, null, 2)}\n`);
    console.log(`release-age: pruned ${removed} entries from ${path.relative(process.cwd(), file)}; now run npm install --package-lock-only in ${d} until check-lock.mjs finds it complete (one pass may not re-add all), then this check again`);
  }
  process.exit(0);
}
process.exit(young.length ? 1 : 0);
