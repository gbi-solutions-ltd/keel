/**
 * vendor-library.test.mjs: vendor-library.mjs on two small fixture libraries (fixtures/vendor-library):
 * a package root (`lib`) and a source folder inside a monorepo (`mono/packages/components/src`). Each test copies
 * its fixture to a temporary folder first; node_modules and git repositories are made there at run time.
 * Run: node --test test/vendor-library.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const FIX = fileURLToPath(new URL('./fixtures/vendor-library', import.meta.url));
const TOOL = fileURLToPath(new URL('../vendor-library.mjs', import.meta.url));
const run = (...args) => spawnSync(process.execPath, [TOOL, ...args], { encoding: 'utf8', timeout: 60000 });
const HAS_GIT = spawnSync('git', ['--version']).status === 0;

const files = (dir, base = dir) => readdirSync(dir).flatMap((f) => {
  const p = join(dir, f);
  return statSync(p).isDirectory() ? files(p, base) : [p.slice(base.length + 1)];
}).sort();
const treeHash = (dir) => createHash('sha256').update(files(dir).map((f) => `${f}\0${createHash('sha256').update(readFileSync(join(dir, f))).digest('hex')}\n`).join('')).digest('hex');

// A temp workspace: the library at <ws>/lib (with an installed widget-core 1.2.3) and an app at <ws>/app
function workspace(fixture = 'lib') {
  const ws = mkdtempSync(join(tmpdir(), 'vendor-library-'));
  cpSync(join(FIX, fixture), join(ws, 'lib'), { recursive: true });
  const nm = join(ws, 'lib/node_modules/widget-core');
  mkdirSync(nm, { recursive: true });
  writeFileSync(join(nm, 'package.json'), '{ "name": "widget-core", "version": "1.2.3" }\n');
  mkdirSync(join(ws, 'app'));
  return { ws, lib: join(ws, 'lib'), app: join(ws, 'app'), to: join(ws, 'app/vendor/acme-ui') };
}
const gitInit = (dir) => {
  const g = (...a) => execFileSync('git', ['-C', dir, ...a], { stdio: 'ignore', env: { ...process.env, GIT_AUTHOR_NAME: 't', GIT_AUTHOR_EMAIL: 't@example.com', GIT_COMMITTER_NAME: 't', GIT_COMMITTER_EMAIL: 't@example.com' } });
  g('init', '-q');
  writeFileSync(join(dir, '.gitignore'), 'node_modules\n');
  g('add', '.');
  g('commit', '-q', '-m', 'one');
  return g;
};
const record = (to) => JSON.parse(readFileSync(join(to, '.vendored.json'), 'utf8'));

test('copies the source tree without tests, stories, fonts or build output, and records it', () => {
  const { lib, to } = workspace();
  const before = treeHash(lib);
  const r = run('--from', lib, '--to', to);
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual(files(to), ['.vendored.json', 'README.md', 'VENDORED.md', 'package.json', 'src/Button/Button.vue', 'src/index.ts', 'src/styles/tokens.css']);
  assert.equal(readFileSync(join(to, 'src/Button/Button.vue'), 'utf8'), readFileSync(join(lib, 'src/Button/Button.vue'), 'utf8'));
  const rec = record(to);
  assert.equal(rec.commit, null, 'not a git repository: tolerated');
  assert.equal(rec.fileCount, 5);
  assert.match(rec.hash, /^sha256:[0-9a-f]{64}$/);
  assert.equal(rec.package.name, '@acme/ui');
  assert.match(readFileSync(join(to, 'VENDORED.md'), 'utf8'), /Commit: not a git repository/);
  assert.equal(treeHash(lib), before, 'source unchanged');

  // dependencies at exact versions
  assert.match(r.stdout, /"clsx": "2\.1\.1",\s+\/\/ exact in package\.json/);
  assert.match(r.stdout, /"widget-core": "1\.2\.3",\s+\/\/ \^1\.2\.0 resolved from node_modules/);
  assert.match(r.stdout, /"never-installed": \?\s+\/\/ ~3\.0\.0: range only, pin by hand/);
  assert.match(r.stdout, /peer dependencies[^\n]*\n\s+"vue": \?/);
  // alias lines, the bare name pointing at the vendored entry
  assert.match(r.stdout, /\{ find: \/\^@acme\\\/ui\$\/, replacement: fileURLToPath\(new URL\('\.\/vendor\/acme-ui\/src\/index\.ts', import\.meta\.url\)\) \}/);
  assert.match(r.stdout, /"@acme\/ui": \["\.\/vendor\/acme-ui\/src\/index\.ts"\],/);
  assert.match(r.stdout, /"@acme\/ui\/\*": \["\.\/vendor\/acme-ui\/\*"\]/);
});

test('records the git commit, leaves the repository untouched, and --check sees a new upstream commit', { skip: !HAS_GIT && 'git not installed' }, () => {
  const { lib, to } = workspace();
  const g = gitInit(lib);
  const head = execFileSync('git', ['-C', lib, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
  const before = treeHash(lib); // includes .git
  assert.equal(run('--from', lib, '--to', to).status, 0);
  assert.equal(treeHash(lib), before, 'source and its .git unchanged');
  assert.equal(record(to).commit, head);
  assert.equal(record(to).dirty, false);

  const ok = run('--check', '--to', to);
  assert.equal(ok.status, 0, ok.stdout);
  assert.match(ok.stdout, /in sync: 6 files/); // .gitignore is part of the source now
  assert.equal(treeHash(lib), before, '--check leaves the source alone too');

  writeFileSync(join(lib, 'src/index.ts'), "export const changed = true;\n");
  g('commit', '-q', '-am', 'two');
  const drift = run('--check', '--to', to);
  assert.equal(drift.status, 1);
  assert.match(drift.stdout, /changed upstream: src\/index\.ts/);
  assert.match(drift.stdout, new RegExp(`commit: vendored ${head}, source now [0-9a-f]{40}`));
});

test('--check reports edits, upstream additions and removals, and works without the source', () => {
  const { lib, to } = workspace();
  assert.equal(run('--from', lib, '--to', to).status, 0);
  writeFileSync(join(to, 'src/styles/tokens.css'), ':root { --ui-space: 5px; }\n');
  writeFileSync(join(lib, 'src/New.vue'), '<template><i /></template>\n');
  writeFileSync(join(lib, 'src/New.test.ts'), '// excluded, so not drift\n');
  rmSync(join(lib, 'README.md'));
  const r = run('--check', '--to', to);
  assert.equal(r.status, 1);
  assert.match(r.stdout, /edited in vendor: src\/styles\/tokens\.css/);
  assert.match(r.stdout, /added upstream: src\/New\.vue/);
  assert.match(r.stdout, /removed upstream: README\.md/);
  assert.doesNotMatch(r.stdout, /New\.test\.ts/);
  assert.match(r.stdout, /drift: 3 differences/);

  rmSync(lib, { recursive: true, force: true });
  const offline = run('--check', '--to', to);
  assert.equal(offline.status, 1, 'the local edit is still drift');
  assert.match(offline.stdout, /not reachable: checked the vendored copy against \.vendored\.json only/);
  assert.doesNotMatch(offline.stdout, /upstream/);
});

test('--include and --exclude narrow the copy, and --check reuses the recorded globs', () => {
  const { lib, to } = workspace();
  const r = run('--from', lib, '--to', to, '--include', 'src/**', '--exclude', '*.css,styles');
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual(files(to), ['.vendored.json', 'VENDORED.md', 'src/Button/Button.vue', 'src/index.ts']);
  assert.deepEqual(record(to).include, ['src/**']);
  assert.match(readFileSync(join(to, 'VENDORED.md'), 'utf8'), /--include 'src\/\*\*' --exclude '\*\.css' --exclude 'styles'/);
  assert.equal(run('--check', '--to', to).status, 0);

  const all = join(to, '../all');
  assert.equal(run('--from', lib, '--to', all, '--no-default-excludes', '--exclude', 'node_modules').status, 0);
  assert.ok(existsSync(join(all, 'src/fonts/Sans.woff2')) && existsSync(join(all, 'dist/index.js')));
});

test('a resync removes files the source dropped and keeps files the app added', () => {
  const { lib, to } = workspace();
  assert.equal(run('--from', lib, '--to', to).status, 0);
  writeFileSync(join(to, 'app-overrides.css'), '/* the app\'s own */\n');
  rmSync(join(lib, 'src/styles/tokens.css'));
  const r = run('--from', lib, '--to', to);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /4 files .*, 1 removed/);
  assert.ok(!existsSync(join(to, 'src/styles/tokens.css')));
  assert.ok(existsSync(join(to, 'app-overrides.css')));
});

test('a source folder inside a monorepo: package.json above it, lockfile versions, workspace deps', () => {
  const ws = mkdtempSync(join(tmpdir(), 'vendor-library-'));
  cpSync(join(FIX, 'mono'), join(ws, 'mono'), { recursive: true });
  const to = join(ws, 'app/vendor/kit');
  const r = run('--from', join(ws, 'mono/packages/components/src'), '--to', to);
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual(files(to), ['.vendored.json', 'Card/Card.ts', 'VENDORED.md', 'index.ts']);
  assert.match(r.stdout, /package @acme\/kit 0\.9\.0/);
  assert.match(r.stdout, /"reka-ui": "2\.0\.3",\s+\/\/ \^2\.0\.0 resolved from package-lock\.json/);
  assert.match(r.stdout, /"tailwind-merge": "3\.1\.0",/);
  assert.match(r.stdout, /"@acme\/icons": \?\s+\/\/ local package: vendor it too, or alias it/);
  assert.match(r.stdout, /the package entry \.\/dist\/index\.js was not vendored/);
  assert.match(r.stdout, /'@acme\/kit': fileURLToPath\(new URL\('\.\/vendor\/kit', import\.meta\.url\)\),/);
});

test('refusals and bad arguments', () => {
  const { lib, app, to } = workspace();
  mkdirSync(to, { recursive: true });
  writeFileSync(join(to, 'mine.txt'), 'not vendored\n');
  const notEmpty = run('--from', lib, '--to', to);
  assert.equal(notEmpty.status, 1);
  assert.match(notEmpty.stderr, /not empty and has no \.vendored\.json/);
  assert.deepEqual(files(to), ['mine.txt']);

  const before = treeHash(lib);
  const overlap = run('--from', lib, '--to', join(lib, 'vendor/self'));
  assert.equal(overlap.status, 1);
  assert.match(overlap.stderr, /overlap/);
  assert.equal(treeHash(lib), before, 'nothing written into the source');
  assert.equal(run('--from', join(lib, 'src'), '--to', lib).status, 1, 'source inside the target');

  const noRecord = run('--check', '--to', app);
  assert.equal(noRecord.status, 1);
  assert.match(noRecord.stderr, /\.vendored\.json not found/);

  assert.equal(run('--to', to).status, 2, '--from missing');
  assert.equal(run('--from', lib).status, 2, '--to missing');
  assert.equal(run('--from', join(lib, 'nope'), '--to', join(app, 'vendor/x')).status, 2);
  assert.equal(run('--from', lib, '--to', join(app, 'vendor/x'), '--frob').status, 2);
  const empty = run('--from', lib, '--to', join(app, 'vendor/y'), '--include', '*.nothing');
  assert.equal(empty.status, 1);
  assert.match(empty.stderr, /no files to vendor/);
});
