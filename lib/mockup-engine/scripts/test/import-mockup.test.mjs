/**
 * import-mockup.test.mjs: import-mockup.mjs on small fixture mockups (fixtures/import-mockup) and on
 * the engine's starter, each into a fresh temporary app folder. No browser.
 * Run: node --test test/import-mockup.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, statSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const FIX = fileURLToPath(new URL('./fixtures/import-mockup', import.meta.url));
const TOOL = fileURLToPath(new URL('../import-mockup.mjs', import.meta.url));
const STARTER = fileURLToPath(new URL('../../templates/mockup-starter', import.meta.url));
const run = (...args) => spawnSync(process.execPath, [TOOL, ...args], { encoding: 'utf8', timeout: 60000 });
const tmpApp = () => mkdtempSync(join(tmpdir(), 'import-mockup-'));
const files = (dir, base = dir) => (existsSync(dir) ? readdirSync(dir).flatMap((f) => {
  const p = join(dir, f);
  return statSync(p).isDirectory() ? files(p, base) : [p.slice(base.length + 1)];
}).sort() : []);
const hashes = (dir) => Object.fromEntries(files(dir).map((f) => [f, createHash('sha256').update(readFileSync(join(dir, f))).digest('hex')]));
// Load a generated .ts module (types stripped by hand: the files are plain literals plus interfaces)
async function load(file) {
  const src = readFileSync(file, 'utf8')
    .replace(/export interface \w+ \{[\s\S]*?\n\}\n/g, '')
    .replace(/export type .*\n/g, '')
    .replace(/: Record<string, [^=]+> =/g, ' =');
  const tmp = join(mkdtempSync(join(tmpdir(), 'import-mockup-load-')), 'm.mjs');
  writeFileSync(tmp, src);
  return import(tmp);
}

test('writes every output for the stack named in the config, and the icons round-trip', async () => {
  const app = tmpApp();
  const r = run('--mockup', join(FIX, 'good'), '--app', app);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /stack vue/);
  assert.deepEqual(files(app), [
    '.import-mockup.json', 'src/lib/icons.ts', 'src/lib/nav.ts', 'src/mocks/fixtures.ts',
    'src/styles/base.css', 'src/styles/components.css', 'src/styles/tokens.css',
  ]); // tours.css (a module sheet) is not copied

  for (const f of ['tokens.css', 'base.css', 'components.css']) {
    assert.ok(readFileSync(join(app, 'src/styles', f)).equals(readFileSync(join(FIX, 'good/assets', f))), `${f} byte copy`);
  }

  const fx = await load(join(app, 'src/mocks/fixtures.ts'));
  assert.equal(fx.default.invoices[1].note, 'Quote "rush" </script>');
  assert.equal(fx.invoices, fx.default.invoices);
  assert.equal(fx.session.role, 'clerk');
  assert.deepEqual(fx.default.default, { kept: 'only in the default export: a reserved word' });
  assert.equal(fx.default['page-size'], 25);
  assert.ok(!('page-size' in fx));

  const { ICONS, ICON_VIEWBOX } = await load(join(app, 'src/lib/icons.ts'));
  assert.deepEqual(Object.keys(ICONS), ['arrow', 'check', 'chevron-down', 'group']);
  assert.deepEqual(ICONS['chevron-down'], [{ tag: 'path', attrs: { d: 'M6 9l6 6 6-6' } }]);
  assert.equal(ICONS.group[0].tag, 'g');
  assert.deepEqual(ICONS.group[0].children.map((c) => c.tag), ['circle', 'path']);
  assert.equal(ICONS.arrow.length, 2);
  assert.deepEqual(ICON_VIEWBOX, { arrow: '0 0 16 16' });

  const { NAV } = await load(join(app, 'src/lib/nav.ts'));
  assert.deepEqual(NAV, [
    { label: 'Invoices', route: '/invoices', permission: 'invoice:read' },
    { label: 'Help', href: './help.html' }, // no route: href is all it has, so it stays
  ]);
});

test('a rerun is byte-identical, and --check passes, then fails on a one-byte edit', () => {
  const app = tmpApp();
  assert.equal(run('--mockup', join(FIX, 'good'), '--app', app).status, 0);
  const first = hashes(app);
  const again = run('--mockup', join(FIX, 'good'), '--app', app);
  assert.equal(again.status, 0, again.stderr);
  assert.match(again.stdout, /wrote 0, unchanged 6/);
  assert.deepEqual(hashes(app), first);

  const ok = run('--mockup', join(FIX, 'good'), '--app', app, '--check');
  assert.equal(ok.status, 0, ok.stdout);
  assert.match(ok.stdout, /all 6 outputs up to date/);

  const css = join(app, 'src/styles/components.css');
  writeFileSync(css, `${readFileSync(css, 'utf8')} `);
  const before = hashes(app);
  const bad = run('--mockup', join(FIX, 'good'), '--app', app, '--check');
  assert.equal(bad.status, 1);
  assert.match(bad.stdout, /would change: src\/styles\/components\.css \(hand-changed\)/, 'not what the last import wrote');
  assert.deepEqual(hashes(app), before, '--check writes nothing');
});

test('--check on an empty app writes nothing and lists every output as new', () => {
  const app = tmpApp();
  const r = run('--mockup', join(FIX, 'good'), '--app', app, '--check');
  assert.equal(r.status, 1);
  assert.equal((r.stdout.match(/\(new\)/g) || []).length, 6);
  assert.deepEqual(files(app), []);
});

test('an icon that does not round-trip fails the run and nothing is written', () => {
  const app = tmpApp();
  const r = run('--mockup', join(FIX, 'bad-icon'), '--app', app);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /icon quoted \(components\/Icon\.js\): markup does not round-trip/);
  assert.match(r.stderr, /nothing written/);
  assert.deepEqual(files(app), []);
});

test('fixtures that are not plain JSON fail with the path instead of vanishing', () => {
  const app = tmpApp();
  const r = run('--mockup', join(FIX, 'bad-fixtures'), '--app', app);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /FIXTURES\.invoices\[0\]\.issued: not plain JSON/);
  assert.deepEqual(files(app), []);
});

test('a hand-written file at a generated path is refused unless --force', () => {
  const app = tmpApp();
  mkdirSync(join(app, 'src/mocks'), { recursive: true });
  writeFileSync(join(app, 'src/mocks/fixtures.ts'), '// typed by hand against the contract\nexport const session = {};\n');
  const r = run('--mockup', join(FIX, 'good'), '--app', app);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /src\/mocks\/fixtures\.ts exists without the GENERATED marker/);
  assert.deepEqual(files(app), ['src/mocks/fixtures.ts'], 'nothing else written');
  const check = run('--mockup', join(FIX, 'good'), '--app', app, '--check');
  assert.match(check.stdout, /fixtures\.ts \(hand-written\)/);
  const forced = run('--mockup', join(FIX, 'good'), '--app', app, '--force');
  assert.equal(forced.status, 0, forced.stderr);
  assert.match(readFileSync(join(app, 'src/mocks/fixtures.ts'), 'utf8'), /^\/\/ GENERATED by import-mockup\.mjs/);
});

test('--only limits the outputs; asking for a part with no source fails', () => {
  const app = tmpApp();
  const r = run('--mockup', join(FIX, 'good'), '--app', app, '--only', 'css', '--stack', 'nextjs');
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual(files(app), ['.import-mockup.json', 'src/styles/base.css', 'src/styles/components.css', 'src/styles/tokens.css']);

  const none = run('--mockup', join(FIX, 'nav-in-fixtures'), '--app', tmpApp(), '--only', 'icons');
  assert.equal(none.status, 1);
  assert.match(none.stderr, /icons: no source/);
});

test('nav falls back to FIXTURES.nav, groups kept and hrefs dropped', async () => {
  const app = tmpApp();
  const r = run('--mockup', join(FIX, 'nav-in-fixtures'), '--app', app);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /icons: no source .*skipped/);
  assert.match(r.stdout, /nav: 1 entries from data\/fixtures\.js \(FIXTURES\.nav\)/);
  const { NAV } = await load(join(app, 'src/lib/nav.ts'));
  assert.deepEqual(NAV, [{ id: 'sales', label: 'Sales', items: [{ label: 'Orders', route: '/orders', permission: 'order:read' }] }]);
});

test('bad arguments exit 2', () => {
  assert.equal(run('--mockup', join(FIX, 'good')).status, 2);
  assert.equal(run('--mockup', join(FIX, 'good'), '--app', tmpApp(), '--stack', 'svelte').status, 2);
  assert.equal(run('--mockup', join(FIX, 'good'), '--app', tmpApp(), '--only', 'fixtures,routes').status, 2);
  assert.equal(run('--mockup', join(FIX, 'missing'), '--app', tmpApp()).status, 2);
  assert.equal(run('--mockup', join(FIX, 'good'), '--app', tmpApp(), '--bogus').status, 2);
});

test('the engine starter imports cleanly and a rerun is byte-identical', () => {
  const app = tmpApp();
  const r = run('--mockup', STARTER, '--app', app);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /nav: 2 entries from components\/AppLayout\.js/);
  const first = hashes(app);
  assert.equal(run('--mockup', STARTER, '--app', app).status, 0);
  assert.deepEqual(hashes(app), first);
  assert.equal(run('--mockup', STARTER, '--app', app, '--check').status, 0);
});

test('run through a symlinked path, the script still runs (a --check that silently passes would hide drift)', () => {
  const link = join(mkdtempSync(join(tmpdir(), 'import-mockup-link-')), 'scripts');
  symlinkSync(dirname(TOOL), link);
  const r = spawnSync(process.execPath, [join(link, 'import-mockup.mjs'), '--mockup', join(FIX, 'good'), '--app', tmpApp(), '--check'], { encoding: 'utf8', timeout: 60000 });
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stdout, /out of date/);
});

test('css: utility-css needs assets/tailwind.css, not components.css; files a sheet names by url() are copied and a missing one fails', () => {
  const m = mkdtempSync(join(tmpdir(), 'import-mockup-uc-'));
  mkdirSync(join(m, 'assets', 'fonts'), { recursive: true });
  writeFileSync(join(m, 'mockup.config.json'), JSON.stringify({ name: 'uc', project: { designFramework: { kind: 'utility-css', name: 'tailwind' } } }));
  writeFileSync(join(m, 'assets', 'tokens.css'), '@font-face { font-family: Body; src: url("fonts/body.woff2") format("woff2"); }\n@theme { --color-ink: #111; }\n');
  writeFileSync(join(m, 'assets', 'fonts', 'body.woff2'), 'font bytes');
  const noInput = run('--mockup', m, '--app', tmpApp(), '--only', 'css');
  assert.equal(noInput.status, 1, 'a refusal: the css part has no input');
  assert.match(noInput.stderr + noInput.stdout, /assets\/tailwind\.css not found \(project\.designFramework is utility-css/);
  writeFileSync(join(m, 'assets', 'tailwind.css'), '@import "tailwindcss" source(none);\n@import "./tokens.css";\n@source "../components";\n');
  const app = tmpApp();
  const ok = run('--mockup', m, '--app', app, '--only', 'css');
  assert.equal(ok.status, 0, ok.stderr);
  assert.deepEqual(files(app), ['.import-mockup.json', 'src/styles/fonts/body.woff2', 'src/styles/tailwind.css', 'src/styles/tokens.css']);
  assert.equal(readFileSync(join(app, 'src/styles/fonts/body.woff2'), 'utf8'), 'font bytes');
  writeFileSync(join(m, 'assets', 'tokens.css'), '@font-face { font-family: Gone; src: url(fonts/gone.woff2); }\n');
  const missing = run('--mockup', m, '--app', tmpApp(), '--only', 'css');
  assert.equal(missing.status, 1, 'a refusal: a font the css names is not there');
  assert.match(missing.stderr + missing.stdout, /tokens\.css: url\(fonts\/gone\.woff2\) is not there/);
});
