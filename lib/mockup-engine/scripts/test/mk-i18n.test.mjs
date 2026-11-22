/**
 * mk-i18n.test.mjs: mk.js strings and locales in a real browser: MK.t with placeholders and plurals,
 * ?locale= previews, the pseudo-locale, fallback to the default locale, a missing key, lang and dir,
 * formatting that follows the locale, links that keep ?locale=, and no change without strings.
 * Run: node --test test/mk-i18n.test.mjs   (from scripts/)
 */
import { test as baseTest, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { chromium } from 'playwright';

const test = (name, fn) => baseTest(name, { timeout: 30000 }, fn);
const url = (p) => pathToFileURL(fileURLToPath(new URL(`./fixtures/mk-i18n/pages/${p}`, import.meta.url))).href;
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

async function open(file, query = '') {
  const page = await browser.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(url(file) + query);
  await page.locator('#app > *').first().waitFor({ timeout: 5000 });
  const text = (id) => page.locator(`#${id}`).textContent();
  return { page, errors, text };
}

test('the default locale is the first strings file; placeholders and plurals resolve', async () => {
  const { page, errors, text } = await open('orders.html');
  assert.equal(await text('title'), 'Orders');
  assert.equal(await text('one'), '1 order');
  assert.equal(await text('many'), '3 orders');
  assert.equal(await text('greet'), 'Hello, Ada');
  assert.equal(await page.evaluate(() => [document.documentElement.lang, document.documentElement.dir].join(' ')), 'en-GB ltr');
  assert.equal(await text('date'), '05 Mar 2026');
  assert.deepEqual(errors, []);
  await page.close();
});

test('?locale= switches strings and formats; a missing key falls back to the default; links keep it', async () => {
  const { page, errors, text } = await open('orders.html', '?locale=fr-FR');
  assert.equal(await text('title'), 'Commandes');
  assert.equal(await text('many'), '3 commandes');
  assert.equal(await text('greet'), 'Bonjour, Ada');
  assert.equal(await text('fallback'), 'Only in English');
  assert.equal(await text('date'), '05 mars 2026');
  assert.match(await text('count'), /^1\s234\s567$/u);
  assert.equal(await page.evaluate(() => document.documentElement.lang), 'fr-FR');
  assert.match(await page.locator('#link').getAttribute('href'), /locale=fr-FR/);
  assert.deepEqual(errors, []);
  await page.close();
});

test('a right-to-left locale sets dir=rtl', async () => {
  const { page } = await open('orders.html', '?locale=ar');
  assert.equal(await page.evaluate(() => document.documentElement.dir), 'rtl');
  await page.close();
});

test('?locale=pseudo accents and lengthens the default strings, keeps placeholders, formats in the default', async () => {
  const { page, errors, text } = await open('orders.html', '?locale=pseudo');
  const title = await text('title');
  assert.match(title, /^\[Órdérs~+\]$/u);
  assert.ok(title.length >= 'Orders'.length * 1.4, title);
  assert.match(await text('greet'), /Ada/);
  assert.equal(await text('date'), '05 Mar 2026');
  assert.equal(await page.evaluate(() => MK.inspect().i18n.pseudo), true);
  assert.deepEqual(errors, []);
  await page.close();
});

test('a missing key logs a console error and shows the key in double brackets', async () => {
  const { page, errors, text } = await open('missing.html');
  assert.equal(await text('m'), '[[orders.nope]]');
  assert.ok(errors.some((e) => e.includes('no string "orders.nope" in en-GB')), errors.join('\n'));
  await page.close();
});

test('without a strings file, formatting keeps its original fixed locales and lang is untouched', async () => {
  const { page, text } = await open('nostrings.html', '?locale=fr-FR');
  assert.equal(await text('date'), '05 Mar 2026');
  assert.equal(await page.evaluate(() => document.documentElement.lang), 'en');
  assert.equal(await page.evaluate(() => MK.inspect().i18n.locale), null);
  await page.close();
});

test('inspect lists the locales and their keys', async () => {
  const { page } = await open('orders.html');
  const i18n = await page.evaluate(() => MK.inspect().i18n);
  assert.equal(i18n.defaultLocale, 'en-GB');
  assert.deepEqual(Object.keys(i18n.keys), ['en-GB', 'fr-FR', 'ar']);
  assert.ok(!i18n.keys['fr-FR'].includes('orders.only-here'));
  await page.close();
});
