#!/usr/bin/env node
/**
 * vendor-library.mjs: copy a client's component library into the app, read only, and record where
 * it came from, so the app builds on the same components with one copy of the framework
 * (skills/convert-mockup/references/design-frameworks-fallback.md, Order of work, step 1). A template: copy it into
 * the app's scripts/ and adjust the defaults if the library needs it.
 *
 *   node vendor-library.mjs --from <library dir> --to <app>/vendor/<name>
 *                           [--include <globs>] [--exclude <globs>] [--no-default-excludes]
 *                           [--package <package.json>] [--app <dir>] [--allow <globs>] [--force]
 *   node vendor-library.mjs --check --to <app>/vendor/<name> [--from <library dir>]
 *
 * --from is the folder to copy: a package root, or its source folder (packages/components/src). It is only
 * read, never written: git is asked with GIT_OPTIONAL_LOCKS=0 so even its index is left alone.
 * --to is replaced file by file: files the last sync wrote and the source no longer has are removed,
 * files the sync never wrote (a generated sheet of the app's own) are kept; name them with --allow
 * (globs, recorded, kept on a resync that gives none) or --check reports them. A non-empty --to with
 * no .vendored.json is refused unless --force.
 *
 * Globs (comma separated, each flag repeatable): `*` within a segment, `**` across segments, `?`
 * one character. A pattern with no `/` matches any single path segment (`fonts`, `*.test.*`); one
 * with a `/` matches the whole path relative to --from (`src/legacy/**`). --include keeps only the
 * files it matches (default: all). --exclude adds to the default excludes, which leave out tests,
 * stories, fonts, build output and tooling: node_modules .git dist build out coverage .next .nuxt
 * .turbo .cache storybook-static .storybook stories __tests__ __mocks__ __snapshots__ test tests
 * test-utils *.test.* *.spec.* *.stories.* *.story.* fonts *.woff *.woff2 *.ttf *.otf *.eot
 * *.tsbuildinfo .DS_Store. --no-default-excludes turns them off. Symlinks are skipped (listed).
 *
 * Writes, beside the copy:
 *   .vendored.json  source path, package name and version, git commit (null outside git) and
 *                   whether the source had uncommitted changes, the date, the globs, the file
 *                   count, a sha256 per file and one over the whole list (`hash`). --check reads it
 *   VENDORED.md     the same for people, and the commands to resync and check
 *
 * Prints, from the library's package.json (in --from, else the nearest folder above it, or
 * --package):
 *   the dependencies and peer dependencies with exact versions, so the app pins the same ones:
 *   each range is resolved from the nearest node_modules/<dep>/package.json above the library, then
 *   its package-lock.json; one that resolves to nothing is marked "range only, pin by hand";
 *   the alias lines for the package name: Vite `resolve.alias` and tsconfig `compilerOptions.paths`,
 *   relative to the app root (--app, default the folder holding `vendor/`, else the current folder).
 *   When the package's entry (exports ".", module or main) was vendored, the bare name points at it.
 *
 * --check writes nothing. It recomputes the source's file list with the recorded globs and reports
 * drift: files added, removed or changed upstream since the sync, a different commit, and files
 * edited or missing in the vendored copy, and files in the vendored copy the record does not list
 * (`not in the record`), other than .vendored.json, VENDORED.md and the recorded --allow globs.
 * Exit 1 on any drift, 0 when in sync. When the source is
 * not reachable (CI), it checks the vendored copy against its record only and says so.
 * Exit 2 on bad arguments and on a crash (a bug or a system error, lib/args.mjs isCrash); exit 1 on
 * a refused or failed sync.
 */
import { execFileSync } from 'node:child_process';
import { copyFileSync, existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { sha256 } from './lib/production.mjs';
import { SPECS, cli, isCrash } from './lib/args.mjs';

const DEFAULT_EXCLUDES = [
  'node_modules', '.git', 'dist', 'build', 'out', 'coverage', '.next', '.nuxt', '.turbo', '.cache',
  'storybook-static', '.storybook', 'stories', '__tests__', '__mocks__', '__snapshots__', 'test', 'tests',
  'test-utils', '*.test.*', '*.spec.*', '*.stories.*', '*.story.*', 'fonts', '*.woff', '*.woff2', '*.ttf',
  '*.otf', '*.eot', '*.tsbuildinfo', '.DS_Store',
];
const RECORD = '.vendored.json';
const NOTE = 'VENDORED.md';
const { usage } = SPECS['vendor-library'];

class Usage extends Error {}
class Refuse extends Error {}

/** The options from the parsed flags (lib/args.mjs): --include, --exclude and --allow repeat, each a comma list. */
function readOptions({ values: f }) {
  const globs = (list) => (list ?? []).flatMap((v) => v.split(',').map((s) => s.trim()).filter(Boolean));
  const o = { from: f.from, to: f.to, package: f.package, app: f.app, include: globs(f.include), exclude: globs(f.exclude), check: Boolean(f.check), force: Boolean(f.force), defaultExcludes: !f['no-default-excludes'] };
  const allow = f.allow ? globs(f.allow) : null;
  if (!o.to) throw new Usage('--to is required');
  if (!o.check && !o.from) throw new Usage('--from is required');
  if (allow && o.check) throw new Usage('--allow is recorded at sync; --check reads it from the record');
  o.allow = allow; // null: keep what the last sync recorded
  return o;
}

// --- globs ---------------------------------------------------------------------------------------
function globRe(pattern) {
  let re = '';
  for (let i = 0; i < pattern.length; i += 1) {
    const c = pattern[i];
    if (c === '*' && pattern[i + 1] === '*') {
      i += 1;
      if (pattern[i + 1] === '/') { i += 1; re += '(?:.*/)?'; } else re += '.*';
    } else if (c === '*') re += '[^/]*';
    else if (c === '?') re += '[^/]';
    else re += c.replace(/[.+^${}()|[\]\\]/g, '\\$&');
  }
  return new RegExp(`^${re}$`);
}
function matcher(patterns) {
  const compiled = patterns.map((p) => ({ seg: !p.includes('/'), re: globRe(p.replace(/^\.\//, '').replace(/\/$/, '')) }));
  return (rel) => compiled.some(({ seg, re }) => (seg ? rel.split('/').some((s) => re.test(s)) : re.test(rel)));
}

// --- scanning ------------------------------------------------------------------------------------
function scan(from, { include, exclude, defaultExcludes }) {
  const excluded = matcher([...(defaultExcludes ? DEFAULT_EXCLUDES : []), ...exclude]);
  const included = include.length ? matcher(include) : () => true;
  const files = {};
  const skipped = [];
  const walk = (dir) => {
    for (const name of readdirSync(dir).sort()) {
      const abs = join(dir, name);
      const rel = relative(from, abs).split(sep).join('/');
      const st = lstatSync(abs);
      if (st.isSymbolicLink()) { skipped.push(rel); continue; }
      if (excluded(rel)) continue;
      if (st.isDirectory()) walk(abs);
      else if (st.isFile() && included(rel)) files[rel] = sha256(readFileSync(abs));
    }
  };
  walk(from);
  return { files, skipped };
}
const listHash = (files) => `sha256:${sha256(Object.keys(files).sort().map((f) => `${files[f]}  ${f}\n`).join(''))}`;

// --- git and package -----------------------------------------------------------------------------
function git(from, args) {
  try {
    return execFileSync('git', ['-C', from, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], env: { ...process.env, GIT_OPTIONAL_LOCKS: '0' } }).trim();
  } catch { return null; }
}
function gitInfo(from) {
  const commit = git(from, ['rev-parse', 'HEAD']);
  if (!commit) return { commit: null, dirty: null };
  const status = git(from, ['status', '--porcelain', '--untracked-files=normal', '--', '.']);
  return { commit, dirty: status === null ? null : status.length > 0 };
}
function findPackage(from, explicit) {
  if (explicit) {
    const p = resolve(explicit);
    if (!existsSync(p)) throw new Usage(`--package not found: ${p}`);
    return p;
  }
  for (let d = from; ; d = dirname(d)) {
    if (existsSync(join(d, 'package.json'))) return join(d, 'package.json');
    if (dirname(d) === d) return null;
  }
}
function installedVersion(pkgDir, dep) {
  for (let d = pkgDir; ; d = dirname(d)) {
    const p = join(d, 'node_modules', ...dep.split('/'), 'package.json');
    if (existsSync(p)) {
      try { return { version: JSON.parse(readFileSync(realpathSync(p), 'utf8')).version, via: 'node_modules' }; } catch { /* unreadable: keep looking */ }
    }
    const lock = join(d, 'package-lock.json');
    if (existsSync(lock)) {
      try {
        const l = JSON.parse(readFileSync(lock, 'utf8'));
        const rel = relative(d, pkgDir).split(sep).join('/');
        const hit = (rel && l.packages?.[`${rel}/node_modules/${dep}`]) || l.packages?.[`node_modules/${dep}`] || l.dependencies?.[dep];
        if (hit?.version) return { version: hit.version, via: 'package-lock.json' };
      } catch { /* not JSON: keep looking */ }
    }
    if (dirname(d) === d) return null;
  }
}
const EXACT = /^\d+\.\d+\.\d+(?:[-+][\w.+-]*)?$/;
function dependencyReport(pkgPath) {
  const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
  const pkgDir = dirname(pkgPath);
  const rows = [];
  for (const [kind, field] of [['dependency', 'dependencies'], ['peer', 'peerDependencies'], ['optional', 'optionalDependencies']]) {
    for (const [name, range] of Object.entries(pkg[field] || {})) {
      if (/^(workspace|file|link|portal):/.test(range)) { rows.push({ kind, name, range, exact: null, note: 'local package: vendor it too, or alias it' }); continue; }
      if (EXACT.test(range)) { rows.push({ kind, name, range, exact: range, note: 'exact in package.json' }); continue; }
      const hit = installedVersion(pkgDir, name);
      rows.push(hit ? { kind, name, range, exact: hit.version, note: `${range} resolved from ${hit.via}` } : { kind, name, range, exact: null, note: `${range}: range only, pin by hand` });
    }
  }
  return { pkg, rows };
}
function entryOf(pkg) {
  const pick = (e) => (typeof e === 'string' ? e : e && typeof e === 'object' ? pick(e.import ?? e.module ?? e.default ?? e.types ?? Object.values(e)[0]) : null);
  const dot = pkg.exports && (typeof pkg.exports === 'string' || pkg.exports['.'] === undefined ? pkg.exports : pkg.exports['.']);
  return pick(dot) || pkg.module || pkg.main || null;
}

// --- sync ----------------------------------------------------------------------------------------
function sync(o) {
  const from = resolve(o.from);
  const to = resolve(o.to);
  if (!existsSync(from) || !lstatSync(from).isDirectory()) throw new Usage(`--from is not a folder: ${from}`);
  const inside = (a, b) => { const r = relative(b, a); return r === '' || (!r.startsWith('..') && !isAbsolute(r)); };
  if (inside(to, from) || inside(from, to)) throw new Refuse(`--to and --from overlap (${to} and ${from}); the source must never be written`);

  let previous = null;
  if (existsSync(to)) {
    if (existsSync(join(to, RECORD))) previous = JSON.parse(readFileSync(join(to, RECORD), 'utf8'));
    else if (readdirSync(to).length && !o.force) throw new Refuse(`${to} is not empty and has no ${RECORD}: not a vendored copy. Move it, or pass --force`);
  }

  const settings = { include: o.include, exclude: o.exclude, defaultExcludes: o.defaultExcludes };
  const { files, skipped } = scan(from, settings);
  if (!Object.keys(files).length) throw new Refuse(`no files to vendor under ${from} with these globs`);
  const { commit, dirty } = gitInfo(from);
  const pkgPath = findPackage(from, o.package);
  const report = pkgPath ? dependencyReport(pkgPath) : null;

  mkdirSync(to, { recursive: true });
  let removed = 0;
  for (const f of Object.keys(previous?.files || {})) {
    if (!(f in files) && existsSync(join(to, f))) { rmSync(join(to, f)); removed += 1; }
  }
  for (const f of Object.keys(files)) {
    mkdirSync(dirname(join(to, f)), { recursive: true });
    copyFileSync(join(from, f), join(to, f));
  }
  const record = {
    source: from,
    package: report ? { name: report.pkg.name ?? null, version: report.pkg.version ?? null, packageJson: pkgPath } : null,
    commit, dirty,
    vendoredAt: new Date().toISOString(),
    include: settings.include, exclude: settings.exclude, defaultExcludes: settings.defaultExcludes,
    allow: o.allow ?? previous?.allow ?? [],
    fileCount: Object.keys(files).length,
    hash: listHash(files),
    files,
  };
  writeFileSync(join(to, RECORD), `${JSON.stringify(record, null, 2)}\n`);
  const argsLine = [`--from ${from}`, `--to ${to}`, ...settings.include.map((g) => `--include '${g}'`), ...settings.exclude.map((g) => `--exclude '${g}'`), settings.defaultExcludes ? '' : '--no-default-excludes', ...record.allow.map((g) => `--allow '${g}'`)].filter(Boolean).join(' ');
  writeFileSync(join(to, NOTE), [
    `# Vendored${record.package?.name ? `: ${record.package.name}` : ''}`,
    '',
    'Read only. Do not edit these files: change the library at its source and resync.',
    '',
    `- Source: ${from}`,
    `- Commit: ${commit ?? 'not a git repository'}${dirty ? ' (with uncommitted changes)' : ''}`,
    `- Package: ${record.package ? `${record.package.name ?? '(no name)'} ${record.package.version ?? ''}`.trim() : 'no package.json found'}`,
    `- Vendored: ${record.vendoredAt}`,
    `- Files: ${record.fileCount}, list hash ${record.hash}`,
    '',
    `Resync: \`node scripts/vendor-library.mjs ${argsLine}\``,
    '',
    `Check for drift: \`node scripts/vendor-library.mjs --check --to ${to}\``,
    '',
  ].join('\n'));

  console.log(`vendor-library: ${record.fileCount} files from ${from} to ${to}${removed ? `, ${removed} removed` : ''}`);
  console.log(`  commit ${commit ?? 'none (not a git repository)'}${dirty ? ', source has uncommitted changes' : ''}; list ${record.hash}`);
  for (const s of skipped) console.log(`  skipped symlink: ${s}`);
  if (!report) { console.log('\nno package.json found at or above --from: no dependency or alias lines'); return; }

  const { pkg, rows } = report;
  console.log(`\npackage ${pkg.name ?? '(no name)'} ${pkg.version ?? ''} (${pkgPath})`);
  for (const kind of ['dependency', 'peer', 'optional']) {
    const list = rows.filter((r) => r.kind === kind);
    if (!list.length) continue;
    console.log(`\n${kind === 'dependency' ? 'dependencies' : kind === 'peer' ? 'peer dependencies (the app must have exactly one copy)' : 'optional dependencies'}, to pin exactly in the app's package.json:`);
    for (const r of list) console.log(`  ${r.exact ? `"${r.name}": "${r.exact}",` : `"${r.name}": ?`}  // ${r.note}`);
  }
  if (!pkg.name) return;

  const app = resolve(o.app ?? (to.includes(`${sep}vendor${sep}`) ? to.slice(0, to.lastIndexOf(`${sep}vendor${sep}`)) : process.cwd()));
  const dirRel = `./${relative(app, to).split(sep).join('/')}`;
  const entry = entryOf(pkg);
  const entryAbs = entry ? resolve(dirname(pkgPath), entry) : null;
  const entryRel = entryAbs && inside(entryAbs, from) ? relative(from, entryAbs).split(sep).join('/') : null;
  const esc = pkg.name.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&');
  console.log(`\nvite.config resolve.alias (relative to ${app}):`);
  if (entryRel && entryRel in files) {
    console.log(`  { find: /^${esc}$/, replacement: fileURLToPath(new URL('${dirRel}/${entryRel}', import.meta.url)) },`);
    console.log(`  { find: /^${esc}\\//, replacement: \`\${fileURLToPath(new URL('${dirRel}', import.meta.url))}/\` },`);
  } else {
    if (entry) console.log(`  // the package entry ${entry} was not vendored (build output?): point the bare name at the source entry`);
    console.log(`  '${pkg.name}': fileURLToPath(new URL('${dirRel}', import.meta.url)),`);
  }
  console.log('\ntsconfig compilerOptions.paths:');
  console.log(`  "${pkg.name}": ["${entryRel && entryRel in files ? `${dirRel}/${entryRel}` : dirRel}"],`);
  console.log(`  "${pkg.name}/*": ["${dirRel}/*"]`);
  console.log(`\nKeep the app's linter and formatter out of ${dirRel}.`);
}

// --- check ---------------------------------------------------------------------------------------
function check(o) {
  const to = resolve(o.to);
  const recPath = join(to, RECORD);
  if (!existsSync(recPath)) throw new Refuse(`${recPath} not found: not a vendored copy`);
  const rec = JSON.parse(readFileSync(recPath, 'utf8'));
  const from = resolve(o.from ?? rec.source);
  const lines = [];
  for (const f of Object.keys(rec.files)) {
    const p = join(to, f);
    if (!existsSync(p)) lines.push(`missing in vendor: ${f}`);
    else if (sha256(readFileSync(p)) !== rec.files[f]) lines.push(`edited in vendor: ${f}`);
  }
  // Files in the copy the record does not list: the sync's own two, and the recorded --allow globs, aside.
  const allowed = matcher(rec.allow ?? []);
  const present = [];
  const walkCopy = (dir) => {
    for (const name of readdirSync(dir).sort()) {
      const abs = join(dir, name);
      const st = lstatSync(abs);
      if (st.isDirectory()) walkCopy(abs);
      else present.push(relative(to, abs).split(sep).join('/'));
    }
  };
  walkCopy(to);
  for (const f of present) if (!(f in rec.files) && f !== RECORD && f !== NOTE && !allowed(f)) lines.push(`not in the record: ${f}`);
  let reachable = existsSync(from) && lstatSync(from).isDirectory();
  if (reachable) {
    const { files } = scan(from, { include: rec.include ?? [], exclude: rec.exclude ?? [], defaultExcludes: rec.defaultExcludes ?? true });
    for (const f of Object.keys(files)) {
      if (!(f in rec.files)) lines.push(`added upstream: ${f}`);
      else if (files[f] !== rec.files[f]) lines.push(`changed upstream: ${f}`);
    }
    for (const f of Object.keys(rec.files)) if (!(f in files)) lines.push(`removed upstream: ${f}`);
    const { commit } = gitInfo(from);
    if (commit !== rec.commit) lines.push(`commit: vendored ${rec.commit ?? 'none'}, source now ${commit ?? 'none'}`);
  } else reachable = false;
  console.log(`vendor-library --check: ${to}`);
  if (!reachable) console.log(`  source ${from} not reachable: checked the vendored copy against ${RECORD} only`);
  for (const l of lines) console.log(`  ${l}`);
  console.log(lines.length ? `drift: ${lines.length} difference${lines.length === 1 ? '' : 's'}; resync with the command in ${NOTE}` : `in sync: ${rec.fileCount} files, ${rec.hash}`);
  return lines.length ? 1 : 0;
}

function main() {
  let o;
  try {
    o = readOptions(cli('vendor-library'));
    if (o.check) process.exit(check(o));
    sync(o);
  } catch (e) {
    if (e instanceof Usage) { console.error(`${e.message}\n${usage}`); process.exit(2); }
    if (isCrash(e)) { console.error(`vendor-library: crashed: ${e.stack || e}`); process.exit(2); }
    console.error(`vendor-library: ${e.message}`);
    process.exit(1);
  }
}

main();
