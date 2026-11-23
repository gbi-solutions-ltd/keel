/**
 * i18n-inventory.test.mjs: the inventory's string rules (i18n-keys, i18n-locale, i18n-strings,
 * i18n-default) on the mk-i18n fixture, and a screen's locale reaching the URL.
 * Run: node --test test/i18n-inventory.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { appUrl, mockupUrl } from '../lib/screens.mjs';

const INVENTORY = fileURLToPath(new URL('../inventory.mjs', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/mk-i18n', import.meta.url));
const MK_JS = fileURLToPath(new URL('../../templates/mockup-starter/assets/mk.js', import.meta.url));

// The inventory serves the mockup over HTTP from its own folder (lib/serve.mjs), so mk.js must be
// inside it: a copy of the fixture gets assets/mk.js, and its pages point there.
function served(dir, pages) {
  mkdirSync(join(dir, 'assets'), { recursive: true });
  cpSync(MK_JS, join(dir, 'assets', 'mk.js'));
  for (const f of pages) {
    const p = join(dir, 'pages', f);
    writeFileSync(p, readFileSync(p, 'utf8').replace('../../../../../templates/mockup-starter/assets/mk.js', '../assets/mk.js'));
  }
}

function inventory(dir) {
  const out = mkdtempSync(join(tmpdir(), 'i18n-inv-'));
  return new Promise((done) => {
    execFile(process.execPath, [INVENTORY, dir, '--out', out], { timeout: 120000 }, (err, stdout, stderr) => {
      const json = existsSync(join(out, 'inventory.json')) ? JSON.parse(readFileSync(join(out, 'inventory.json'), 'utf8')) : null;
      rmSync(out, { recursive: true, force: true });
      done({ code: err ? err.code : 0, stdout, stderr, json });
    });
  });
}

test('a screen locale is a ?locale= preview on both sides', () => {
  const s = { name: 'x', page: 'pages/orders.html', route: '/orders', locale: 'fr-FR' };
  assert.match(mockupUrl(s, 'default', { base: 'http://m' }), /\?locale=fr-FR$/);
  assert.equal(appUrl(s, 'empty', 'http://a'), 'http://a/orders?state=empty&locale=fr-FR');
});

test('missing keys per locale are lint; extra locales and pages are judged against the default', { timeout: 150000 }, async () => {
  const tmp = mkdtempSync(join(tmpdir(), 'i18n-keys-'));
  const dir = join(tmp, 'm');
  cpSync(FIXTURE, dir, { recursive: true });
  served(dir, ['orders.html', 'nostrings.html', 'missing.html']);
  const r = await inventory(dir);
  rmSync(tmp, { recursive: true, force: true });
  assert.equal(r.code, 1, r.stdout + r.stderr);
  const lint = r.json.lint.filter((l) => l.rule.startsWith('i18n'));
  const fr = lint.find((l) => l.where === 'strings/fr-FR.js');
  assert.ok(fr && /1 key missing: orders\.only-here/.test(fr.detail), JSON.stringify(lint));
  const ar = lint.find((l) => l.where === 'strings/ar.js');
  assert.ok(ar && /3 keys missing/.test(ar.detail), JSON.stringify(lint));
  assert.ok(!lint.some((l) => l.rule === 'i18n-strings' || l.rule === 'i18n-default'), JSON.stringify(lint));
});

test('strings with no project.i18n raise no string lint; project.i18n with a page that loads none is i18n-strings', { timeout: 150000 }, async () => {
  const tmp = mkdtempSync(join(tmpdir(), 'i18n-fix-'));
  try {
    const dir = join(tmp, 'm');
    cpSync(FIXTURE, dir, { recursive: true });
    served(dir, ['orders.html', 'nostrings.html']);
    const cfg = JSON.parse(readFileSync(join(dir, 'mockup.config.json'), 'utf8'));
    writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify({ ...cfg, project: undefined, screens: [cfg.screens[0]] }));
    const undeclared = await inventory(dir);
    assert.ok(!undeclared.json.lint.some((l) => l.rule.startsWith('i18n')), JSON.stringify(undeclared.json.lint));
    assert.equal(undeclared.json.readiness.open.some((o) => o.field === 'project.i18n'), true);

    writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify({ ...cfg, project: { i18n: { locales: ['fr-FR', 'en-GB'], defaultLocale: 'fr-FR' } }, screens: [cfg.screens[0], { name: 'plain', page: 'pages/nostrings.html', route: '/plain' }] }));
    const r = await inventory(dir);
    const rules = r.json.lint.map((l) => `${l.rule} ${l.where}`);
    assert.ok(rules.includes('i18n-strings pages/nostrings.html'), rules.join('\n'));
    assert.ok(rules.includes('i18n-default pages/orders.html'), rules.join('\n'));
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
