/**
 * target.test.mjs: check-config on an existing-repo target (lib/target.mjs), on fixture repos. A
 * repo that agrees with the package and has been read (snapshot, standards, its own docs_root)
 * leaves nothing open; a repo on another stack and framework, with no snapshot, opens one line
 * each; two locales and no i18n library in the repo is open too. No browser.
 * Run: node --test test/target.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { detect, targetStatus } from '../lib/target.mjs';

const CHECK = fileURLToPath(new URL('../check-config.mjs', import.meta.url));
const REPOS = fileURLToPath(new URL('./fixtures/target', import.meta.url));

const project = (path) => ({
  people: { signsOff: 'client product owner', technicalOwner: 'lead developer' },
  designFramework: { kind: 'utility-css', name: 'tailwindcss', version: '4.3.4', owner: 'public' },
  i18n: { locales: ['en-GB', 'fr-FR'], defaultLocale: 'en-GB', rtl: false, expansionCheck: true },
  tenancy: 'single', browsers: 'last 2 versions, not dead', accessibility: 'wcag22-aa', currency: 'EUR', theming: 'light',
  auth: { signIn: 'in-app' }, contract: { source: 'drafted' },
  target: { kind: 'existing-repo', path },
  stack: { name: 'react-vite', decidedBy: 'user' },
  deploy: { deferred: { owner: 'platform team', by: '2026-12-15', reason: 'not chosen' } }, telemetry: { backend: 'none' },
});
function check(path) {
  const dir = mkdtempSync(join(tmpdir(), 'target-'));
  writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify({ name: 'x', timezoneId: 'Europe/Paris', screens: [{ name: 'a', page: 'pages/a.html' }], project: project(path) }));
  const r = spawnSync(process.execPath, [CHECK, dir, '--ready-to-port'], { encoding: 'utf8' });
  rmSync(dir, { recursive: true, force: true });
  const lines = r.stdout.split('\n');
  return { out: r.stdout, target: lines.find((l) => l.startsWith('target:')), open: lines.filter((l) => /^not ready: (target|project\.)/.test(l)), notes: lines.filter((l) => l.startsWith('note:')) };
}

test('detect reads the stack, the frameworks and the i18n library from package.json', () => {
  assert.deepEqual(detect({ dependencies: { next: '16', react: '19' } }).stack, 'nextjs');
  assert.deepEqual(detect({ dependencies: { react: '19' }, devDependencies: { vite: '8' } }).stack, 'react-vite');
  assert.deepEqual(detect({ dependencies: { react: '19' } }).stack, 'react (not vite)');
  const v = detect({ dependencies: { vue: '3', vuetify: '3', 'vue-i18n': '11' } });
  assert.deepEqual([v.stack, v.frameworks, v.i18n], ['vue', [{ name: 'vuetify', kind: 'js-kit' }], ['vue-i18n']]);
});

test('a repo that agrees with the package and has been read leaves nothing open', () => {
  const r = check(join(REPOS, 'react-repo'));
  assert.match(r.target, /^target: existing repo .*react-repo, read: documentation\/snapshot\.md, documentation\/standards\.md, react-vite$/);
  assert.deepEqual(r.open, [], r.out);
  assert.deepEqual(r.notes, [`note: existing repo ${join(REPOS, 'react-repo')} uses i18next: import strings with import-mockup --i18n i18next`]);
});

test('another stack, another framework and no snapshot: one open line each, nothing overridden', () => {
  const r = check(join(REPOS, 'vue-repo'));
  const fields = r.open.map((l) => l.split(': ')[1]);
  assert.deepEqual(fields.sort(), ['project.designFramework', 'project.i18n', 'project.stack', 'target'], r.out);
  assert.ok(r.open.some((l) => /project\.stack: the package says react-vite, .* is vue: the repo's stack decides/.test(l)));
  assert.ok(r.open.some((l) => /project\.designFramework: the package names tailwindcss, .* does not depend on it \(it has vuetify\)/.test(l)));
  assert.ok(r.open.some((l) => /target: .* has no docs\/snapshot\.md: run keel repo-snapshot/.test(l)));
  assert.ok(r.open.some((l) => /project\.i18n: the package has 2 locales, .* has no i18n library/.test(l)));
  assert.ok(r.notes.some((l) => /no docs\/standards\.md: Convert Step 5 runs keel coding-standards/.test(l)));
});

test('a missing repo or one without package.json is open', () => {
  assert.ok(check(join(REPOS, 'nowhere')).open.some((l) => /is not there \(paths are relative to the mockup\)/.test(l)));
  assert.ok(check(REPOS).open.some((l) => /has no package\.json; in a monorepo, point project\.target\.path at the app's package/.test(l)));
});

test('the design framework version is compared by its major, not by a prefix', () => {
  const repo = mkdtempSync(join(tmpdir(), 'target-major-'));
  const note = (range, pinned) => {
    writeFileSync(join(repo, 'package.json'), JSON.stringify({ dependencies: { react: '19', vite: '8', tailwindcss: range } }));
    const config = { project: { ...project(repo), designFramework: { kind: 'utility-css', name: 'tailwindcss', version: pinned, owner: 'public' } } };
    return targetStatus(config, repo).notes.filter((n) => /the package pinned/.test(n));
  };
  try {
    assert.equal(note('^10.2.0', '1.4.0').length, 1, 'a 1.x pin does not match a repo on 10');
    assert.equal(note('^1.9.0', '10.0.0').length, 1, 'a 10.x pin does not match a repo on 1');
    assert.equal(note('^4.1.0', '4.3.4').length, 0);
    assert.equal(note('~4.1.0', '4').length, 0);
    assert.equal(note('>=4.0.0 <5', '4.3.4').length, 0);
    assert.equal(note('v4.1.0', '4.3.4').length, 0);
    assert.equal(note('4.x', '4.3.4').length, 0);
  } finally { rmSync(repo, { recursive: true, force: true }); }
});
