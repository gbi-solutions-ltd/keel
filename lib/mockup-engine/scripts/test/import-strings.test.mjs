/**
 * import-strings.test.mjs: import-mockup.mjs --only strings writes each strings/<locale>.js as the
 * target i18n library's messages (vue-i18n, i18next, icu), nested by key, with an index; a rerun is
 * byte-identical; plurals a library cannot express and keys that clash fail with nothing written.
 * Run: node --test test/import-strings.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../import-mockup.mjs', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/mk-i18n', import.meta.url));
// --app must exist (import-mockup refuses a missing one): each test's app folder is made here.
const run = (args) => {
  const at = args.indexOf('--app');
  if (at >= 0) mkdirSync(args[at + 1], { recursive: true });
  try { return { code: 0, out: execFileSync('node', [SCRIPT, ...args], { encoding: 'utf8' }) }; } catch (e) { return { code: e.status, out: `${e.stdout}${e.stderr}` }; }
};
const messages = (file) => JSON.parse(readFileSync(file, 'utf8').replace(/^\/\/.*\n/gm, '').replace(/^export default /m, '').replace(/ as const;\s*$/, ''));

test('each library gets its own placeholder and plural syntax, nested by key', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'imp-strings-'));
  try {
    for (const lib of ['vue-i18n', 'i18next', 'icu']) assert.equal(run(['--mockup', FIXTURE, '--app', join(tmp, lib), '--only', 'strings', '--i18n', lib]).code, 0);
    assert.deepEqual(messages(join(tmp, 'vue-i18n/src/locales/en-GB.ts')).orders, { count: '{count} order | {count} orders', greeting: 'Hello, {name}', 'only-here': 'Only in English', title: 'Orders' });
    assert.deepEqual(messages(join(tmp, 'i18next/src/locales/en-GB.ts')).orders, { count_one: '{{count}} order', count_other: '{{count}} orders', greeting: 'Hello, {{name}}', 'only-here': 'Only in English', title: 'Orders' });
    assert.equal(messages(join(tmp, 'icu/src/locales/fr-FR.ts')).orders.count, '{count, plural, one {{count} commande} other {{count} commandes}}');
    const index = readFileSync(join(tmp, 'icu/src/locales/index.ts'), 'utf8');
    assert.match(index, /export const DEFAULT_LOCALE = "en-GB";/);
    assert.match(index, /export const LOCALES = \["en-GB","ar","fr-FR"\]/);
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('the stack picks the library; a rerun is byte-identical and --check agrees', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'imp-strings-'));
  try {
    const app = join(tmp, 'app');
    assert.equal(run(['--mockup', FIXTURE, '--app', app, '--only', 'strings', '--stack', 'react-vite']).code, 0);
    const first = readFileSync(join(app, 'src/locales/en-GB.ts'), 'utf8');
    assert.match(first, /i18next syntax/);
    assert.match(run(['--mockup', FIXTURE, '--app', app, '--only', 'strings', '--stack', 'react-vite']).out, /wrote 0, unchanged 4/);
    assert.equal(readFileSync(join(app, 'src/locales/en-GB.ts'), 'utf8'), first);
    assert.equal(run(['--mockup', FIXTURE, '--app', app, '--only', 'strings', '--stack', 'react-vite', '--check']).code, 0);
    assert.equal(run(['--mockup', FIXTURE, '--app', app, '--only', 'strings', '--stack', 'vue', '--check']).code, 1, 'another library would change the files');
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('escapes: vue-i18n @ and |, icu apostrophes and #', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'imp-strings-'));
  try {
    const m = join(tmp, 'm');
    cpSync(FIXTURE, m, { recursive: true });
    writeFileSync(join(m, 'strings/en-GB.js'), "MK.strings('en-GB', { 'a.mail': 'Write to help@example.com | any time', 'a.own': { one: \"it's #{count}\", other: \"they're #{count}\" } });");
    writeFileSync(join(m, 'strings/fr-FR.js'), "MK.strings('fr-FR', {});");
    writeFileSync(join(m, 'strings/ar.js'), "MK.strings('ar', {});");
    assert.equal(run(['--mockup', m, '--app', join(tmp, 'v'), '--only', 'strings', '--i18n', 'vue-i18n']).code, 0);
    assert.equal(messages(join(tmp, 'v/src/locales/en-GB.ts')).a.mail, "Write to help{'@'}example.com {'|'} any time");
    assert.equal(run(['--mockup', m, '--app', join(tmp, 'i'), '--only', 'strings', '--i18n', 'icu']).code, 0);
    assert.equal(messages(join(tmp, 'i/src/locales/en-GB.ts')).a.own, "{count, plural, one {it''s '#'{count}} other {they''re '#'{count}}}");
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('a plural vue-i18n cannot express, and a key that is also a prefix, fail with nothing written', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'imp-strings-'));
  try {
    const m = join(tmp, 'm');
    cpSync(FIXTURE, m, { recursive: true });
    writeFileSync(join(m, 'strings/fr-FR.js'), "MK.strings('fr-FR', { 'orders.count': { one: 'a', few: 'b', other: 'c' } });");
    const few = run(['--mockup', m, '--app', join(tmp, 'a'), '--only', 'strings', '--i18n', 'vue-i18n']);
    assert.equal(few.code, 1);
    assert.match(few.out, /orders\.count uses few/);
    assert.equal(existsSync(join(tmp, 'a/src/locales')), false);
    assert.equal(run(['--mockup', m, '--app', join(tmp, 'b'), '--only', 'strings', '--i18n', 'i18next']).code, 0, 'i18next has every CLDR category');
    writeFileSync(join(m, 'strings/fr-FR.js'), "MK.strings('fr-FR', { 'orders': 'x', 'orders.title': 'y' });");
    const clash = run(['--mockup', m, '--app', join(tmp, 'c'), '--only', 'strings']);
    assert.equal(clash.code, 1);
    assert.match(clash.out, /orders\.title nests under orders, which is a message/);
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('--flat (i18next, vue-i18n) writes keys as they are, so a key that is also a prefix of another imports', async () => {
  const { mkdtempSync, mkdirSync, writeFileSync, readFileSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const { spawnSync } = await import('node:child_process');
  const { fileURLToPath } = await import('node:url');
  const TOOL = fileURLToPath(new URL('../import-mockup.mjs', import.meta.url));
  const m = mkdtempSync(join(tmpdir(), 'flat-'));
  mkdirSync(join(m, 'strings'));
  for (const a of ['app', 'vue', 'vue2', 'icu']) mkdirSync(join(m, a));
  writeFileSync(join(m, 'strings/en-GB.js'), "MK.strings('en-GB', { 'loan.status': 'Status', 'loan.status.approved': 'Approved', 'loan.count': { one: '{count} loan', other: '{count} loans' } });\n");
  const nested = spawnSync(process.execPath, [TOOL, '--mockup', m, '--app', join(m, 'app'), '--only', 'strings', '--i18n', 'i18next'], { encoding: 'utf8' });
  assert.equal(nested.status, 1, 'a refusal: the strings were read and cannot nest');
  assert.match(nested.stderr + nested.stdout, /loan\.status\.approved nests under loan\.status, which is a message|is both a message and a prefix/);
  const flat = spawnSync(process.execPath, [TOOL, '--mockup', m, '--app', join(m, 'app'), '--only', 'strings', '--i18n', 'i18next', '--flat'], { encoding: 'utf8' });
  assert.equal(flat.status, 0, flat.stderr);
  const out = readFileSync(join(m, 'app/src/locales/en-GB.ts'), 'utf8');
  assert.match(out, /"loan\.status": "Status"/);
  assert.match(out, /"loan\.status\.approved": "Approved"/);
  assert.match(out, /"loan\.count_one": "\{\{count\}\} loan"/);
  const vue = spawnSync(process.execPath, [TOOL, '--mockup', m, '--app', join(m, 'vue'), '--only', 'strings', '--i18n', 'vue-i18n', '--flat'], { encoding: 'utf8' });
  assert.equal(vue.status, 0, vue.stderr);
  const vueOut = readFileSync(join(m, 'vue/src/locales/en-GB.ts'), 'utf8');
  assert.match(vueOut, /"loan\.status": "Status"/);
  assert.match(vueOut, /"loan\.status\.approved": "Approved"/);
  assert.match(vueOut, /"loan\.count": "\{count\} loan \| \{count\} loans"/, 'vue-i18n syntax, flat');
  const nestedVue = spawnSync(process.execPath, [TOOL, '--mockup', m, '--app', join(m, 'vue2'), '--only', 'strings', '--i18n', 'vue-i18n'], { encoding: 'utf8' });
  assert.equal(nestedVue.status, 1, 'a refusal, as with i18next');
  const icu = spawnSync(process.execPath, [TOOL, '--mockup', m, '--app', join(m, 'icu'), '--only', 'strings', '--i18n', 'icu', '--flat'], { encoding: 'utf8' });
  assert.equal(icu.status, 2);
});
