/**
 * target.mjs: the existing-repo target (project.target.kind "existing-repo", references/
 * existing-repo.md), read-only. Convert builds into that repo from the first file, to its
 * conventions, so before it starts the engine checks that the repo has been read and that it agrees
 * with the package:
 *
 *   - the repo's docs_root (its .keel/profile.json, default docs) holds keel repo-snapshot's
 *     snapshot.md (or snapshot-<unit>.md); without it, run repo-snapshot first. standards.md is
 *     read when it is there; without it, Convert Step 5 seeds it (keel coding-standards).
 *   - package.json's dependencies against the package's answers: the stack (next, vue, react with
 *     vite), the design framework (tailwindcss, a component kit) and the i18n library. A mismatch is
 *     an open question for the repo's owners and the technical owner, never a silent override.
 *
 * targetStatus(config, mockupDir) returns { kind, path, docsRoot, snapshot, standards, detected,
 * open: [{ field, detail }], notes: [] }; open is empty for a new repo or an undecided target.
 * Paths in the config are relative to the mockup folder.
 */
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

// Package name -> what it tells about the repo. Order matters for the stack: next before react.
const KITS = {
  '@mui/material': 'js-kit', vuetify: 'js-kit', quasar: 'js-kit', primevue: 'js-kit', antd: 'js-kit',
  '@chakra-ui/react': 'js-kit', '@mantine/core': 'js-kit', 'element-plus': 'js-kit', 'naive-ui': 'js-kit',
  tailwindcss: 'utility-css', unocss: 'utility-css', bootstrap: 'css-library', bulma: 'css-library',
};
const I18N_LIBS = { 'react-i18next': 'i18next', i18next: 'i18next', 'vue-i18n': 'vue-i18n', 'next-intl': 'icu', 'react-intl': 'icu' };

/** What a package.json says: { stack, frameworks: [{ name, kind }], i18n: [lib] }. */
export function detect(pkg) {
  const deps = { ...(pkg.dependencies || {}), ...(pkg.devDependencies || {}) };
  const has = (n) => n in deps;
  const stack = has('next') ? 'nextjs' : has('vue') || has('nuxt') ? 'vue' : has('react') && has('vite') ? 'react-vite' : has('react') ? 'react (not vite)' : null;
  const frameworks = Object.keys(KITS).filter(has).map((name) => ({ name, kind: KITS[name] }));
  const i18n = [...new Set(Object.keys(I18N_LIBS).filter(has).map((n) => I18N_LIBS[n]))];
  return { stack, frameworks, i18n, versions: Object.fromEntries(['next', 'vue', 'react', 'vite', ...frameworks.map((f) => f.name)].filter(has).map((n) => [n, deps[n]])) };
}

/** The major version a version or range starts from ("^10.2.0", ">=4 <5", "v4.x" give 10, 4, 4), or null. */
export function majorOf(version) {
  const m = /^\s*(?:[\^~]|[<>]=?|=)?\s*v?(\d+)/.exec(String(version));
  return m ? Number(m[1]) : null;
}

export function targetStatus(config, mockupDir) {
  const t = config?.project?.target;
  const out = { kind: t?.kind ?? null, open: [], notes: [] };
  if (!t || t.deferred || t.kind !== 'existing-repo' || !t.path) return out;
  const repo = resolve(mockupDir, t.path);
  out.path = repo;
  const where = `existing repo ${t.path}`;
  if (!existsSync(repo)) { out.open.push({ field: 'target', detail: `${where} is not there (paths are relative to the mockup)` }); return out; }
  let docsRoot = 'docs';
  const profile = join(repo, '.keel/profile.json');
  if (existsSync(profile)) {
    try { docsRoot = JSON.parse(readFileSync(profile, 'utf8')).docs_root || 'docs'; } catch { out.notes.push(`${where}: .keel/profile.json is not valid JSON; docs_root taken as docs`); }
  }
  out.docsRoot = docsRoot;
  const docs = join(repo, docsRoot);
  const snaps = existsSync(docs) ? readdirSync(docs).filter((f) => /^snapshot(-[\w.-]+)?\.md$/.test(f)) : [];
  out.snapshot = snaps.length ? snaps.map((f) => `${docsRoot}/${f}`) : null;
  if (!snaps.length) out.open.push({ field: 'target', detail: `${where} has no ${docsRoot}/snapshot.md: run keel repo-snapshot on it, so Convert builds to what the repo is` });
  out.standards = existsSync(join(docs, 'standards.md')) ? `${docsRoot}/standards.md` : null;
  if (!out.standards) out.notes.push(`${where} has no ${docsRoot}/standards.md: Convert Step 5 runs keel coding-standards on the repo before porting`);

  const pkgFile = join(repo, 'package.json');
  if (!existsSync(pkgFile)) { out.open.push({ field: 'target', detail: `${where} has no package.json; in a monorepo, point project.target.path at the app's package` }); return out; }
  let pkg;
  try { pkg = JSON.parse(readFileSync(pkgFile, 'utf8')); } catch (e) { out.open.push({ field: 'target', detail: `${where}: package.json is not valid JSON (${e.message})` }); return out; }
  const d = detect(pkg);
  out.detected = d;

  const stack = config.project.stack;
  if (stack && !stack.deferred && d.stack && d.stack !== stack.name) out.open.push({ field: 'project.stack', detail: `the package says ${stack.name}, ${where} is ${d.stack}: the repo's stack decides unless its owners agree a change (an ADR, keel design-architecture)` });
  if (!d.stack) out.notes.push(`${where}: no react, vue or next dependency found; the stack is not confirmed from package.json`);

  const df = config.project.designFramework;
  if (df && !df.deferred) {
    const named = df.name && d.frameworks.find((f) => f.name === df.name);
    if (df.kind === 'none' && d.frameworks.length) out.open.push({ field: 'project.designFramework', detail: `the package says none, ${where} uses ${d.frameworks.map((f) => f.name).join(', ')}: a mockup in its own CSS would be ported onto the repo's framework later (the fallback route)` });
    else if (df.kind !== 'none' && df.name && !named) out.open.push({ field: 'project.designFramework', detail: `the package names ${df.name}, ${where} does not depend on it${d.frameworks.length ? ` (it has ${d.frameworks.map((f) => f.name).join(', ')})` : ''}: adding a framework to an existing repo is its owners' decision` });
    else if (named && df.version && d.versions[df.name] && majorOf(d.versions[df.name]) !== majorOf(df.version)) out.notes.push(`${where} has ${df.name} ${d.versions[df.name]}, the package pinned ${df.version}: build the mockup's vendor CSS from the repo's version`);
  }

  const i18n = config.project.i18n;
  if (i18n && !i18n.deferred) {
    if (d.i18n.length > 1) out.notes.push(`${where} depends on several i18n libraries (${d.i18n.join(', ')}); import strings with the one the app uses (import-mockup --i18n)`);
    else if (d.i18n.length === 1) out.notes.push(`${where} uses ${d.i18n[0]}: import strings with import-mockup --i18n ${d.i18n[0]}`);
    else if ((i18n.locales || []).length > 1) out.open.push({ field: 'project.i18n', detail: `the package has ${i18n.locales.length} locales, ${where} has no i18n library: which one is the repo owners' decision` });
  }
  return out;
}
