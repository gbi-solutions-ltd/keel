/**
 * mk.test.mjs: the runtime's morph, shell keys, role lookup and URL params, in a real browser.
 * Run: node --test test/   (from scripts/)
 */
import { test as baseTest, before, after } from 'node:test';

const test = (name, fn) => baseTest(name, { timeout: 20000 }, fn);
import assert from 'node:assert/strict';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { chromium } from 'playwright';

const PAGE = pathToFileURL(fileURLToPath(new URL('./fixtures/mk/index.html', import.meta.url))).href;
const PARAMS_PAGE = PAGE.replace(/index\.html$/, 'params.html'); // its shell state is a function of params
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

async function open(query = '', url = PAGE) {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(url + query);
  await page.locator('#note').waitFor({ timeout: 5000 });
  return { page, errors };
}

test('morph keeps a textarea value typed between renders (gap 12)', async () => {
  const { page, errors } = await open();
  await page.locator('#note').pressSequentially('hello there', { delay: 5 });
  assert.equal(await page.locator('#note').inputValue(), 'hello there');
  await page.click('#rerender');
  assert.equal(await page.locator('#note').inputValue(), 'hello there');
  assert.deepEqual(errors, []);
  await page.close();
});

test('morph keeps the chosen option when a select grows (gap 13)', async () => {
  const { page } = await open();
  assert.equal(await page.locator('#pick').inputValue(), 'b');
  await page.click('#more'); // adds options c and d and chooses d in the same render
  assert.equal(await page.locator('#pick').inputValue(), 'd');
  await page.selectOption('#pick', 'c');
  await page.click('#rerender');
  assert.equal(await page.locator('#pick').inputValue(), 'c');
  await page.close();
});

test('shell keys accept modifier chords (gap 17)', async () => {
  const { page } = await open();
  const log = () => page.evaluate(() => window.LOG.splice(0));
  await page.focus('#field');
  for (const k of ['Control+Enter', 'Meta+Enter', 'Control+d', 'Control+k', 'Control+Shift+X', 'Alt+n']) await page.keyboard.press(k);
  // inside a text field, chords fire and a bare '/' types instead
  await page.keyboard.press('/');
  assert.equal((await log()).length, 6);
  assert.equal(await page.locator('#field').inputValue(), '/');
  // a chord with an extra modifier is a different chord
  await page.keyboard.press('Control+Shift+d');
  await page.keyboard.press('Control+Alt+Enter');
  assert.equal((await log()).length, 0);
  // outside a field, a bare key fires
  await page.locator('#field').blur();
  await page.keyboard.press('/');
  await page.keyboard.press('Escape');
  assert.equal((await log()).length, 2);
  await page.close();
});

test('?as= resolves only own role names (gap 18)', async () => {
  for (const as of ['__proto__', 'constructor', 'toString', 'hasOwnProperty']) {
    const { page, errors } = await open(`?as=${as}`);
    assert.deepEqual(errors, [], `?as=${as}`);
    assert.equal(await page.evaluate(() => MK.session().role), 'admin', `?as=${as}`);
    await page.close();
  }
  const { page } = await open('?as=clerk');
  assert.equal(await page.evaluate(() => MK.session().role), 'clerk');
  await page.close();
});

test('the shell load, state and layout get the URL params (gap 10)', async () => {
  const { page } = await open('?flag=yes&banner=on', PARAMS_PAGE);
  const layout = page.locator('.test-layout');
  assert.deepEqual(JSON.parse(await layout.getAttribute('data-params')), { flag: 'yes', banner: 'on' });
  assert.deepEqual(JSON.parse(await layout.getAttribute('data-shell')), { flag: 'yes', banner: true });
  await page.close();
});
