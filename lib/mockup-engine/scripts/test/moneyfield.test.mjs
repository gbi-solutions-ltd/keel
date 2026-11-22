/**
 * moneyfield.test.mjs: the starter's MoneyField (live thousands separators, the caret kept while
 * typing, the plain integer submitted from a hidden input), on a fixture page that uses the
 * starter's own files; then the starter's two pages (the money filter and the ARIA grid's keys).
 * Run: node --test test/moneyfield.test.mjs   (from scripts/)
 */
import { test as baseTest, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { chromium } from 'playwright';

const test = (name, fn) => baseTest(name, { timeout: 20000 }, fn);
const url = (rel) => pathToFileURL(fileURLToPath(new URL(rel, import.meta.url))).href;
const FIXTURE = url('./fixtures/moneyfield/index.html');
const STARTER = url('../../templates/mockup-starter/pages/');

let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

async function open(href) {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (['error', 'warning'].includes(m.type())) errors.push(m.text()); });
  await page.goto(href);
  await page.locator('#app *').first().waitFor({ timeout: 5000 });
  return { page, errors };
}
const caret = (page, sel) => page.locator(sel).evaluate((el) => [el.selectionStart, el.selectionEnd]);

test('typing groups the digits and the hidden input holds minor units', async () => {
  const { page, errors } = await open(FIXTURE);
  await page.locator('#ugx').pressSequentially('1250000', { delay: 5 });
  assert.equal(await page.locator('#ugx').inputValue(), '1,250,000');
  assert.equal(await page.locator('#ugx').getAttribute('name'), null, 'the visible input has no name');
  assert.equal(await page.locator('input[type=hidden][name=ugx_amount]').inputValue(), '1250000');
  await page.locator('#usd').pressSequentially('1234.5', { delay: 5 });
  assert.equal(await page.locator('#usd').inputValue(), '1,234.5');
  await page.click('#send');
  assert.deepEqual(await page.evaluate(() => window.SUBMITTED), { ugx_amount: '1250000', usd_amount: '123450' });
  assert.deepEqual(errors, []);
  await page.close();
});

test('the caret stays after the same digit when typing or deleting in the middle', async () => {
  const { page, errors } = await open(FIXTURE);
  const f = page.locator('#ugx');
  await f.pressSequentially('1250000', { delay: 5 });
  await f.evaluate((el) => el.setSelectionRange(3, 3)); // 1,2|50,000
  await page.keyboard.type('3');
  assert.equal(await f.inputValue(), '12,350,000');
  assert.deepEqual(await caret(page, '#ugx'), [4, 4]); // 12,3|50,000
  await page.keyboard.press('Backspace');
  assert.equal(await f.inputValue(), '1,250,000');
  assert.deepEqual(await caret(page, '#ugx'), [3, 3]); // 1,2|50,000
  await f.evaluate((el) => el.setSelectionRange(0, 0));
  await page.keyboard.type('9');
  assert.equal(await f.inputValue(), '91,250,000');
  assert.deepEqual(await caret(page, '#ugx'), [1, 1]);
  assert.deepEqual(errors, []);
  await page.close();
});

test('a pasted amount keeps only the decimals the currency has, and a stray point changes nothing', async () => {
  const { page, errors } = await open(FIXTURE);
  await page.locator('#ugx').fill('1,250,000.50');
  assert.equal(await page.locator('#ugx').inputValue(), '1,250,000');
  assert.equal(await page.locator('input[name=ugx_amount]').inputValue(), '1250000');
  await page.locator('#ugx').fill('');
  await page.locator('#ugx').pressSequentially('125', { delay: 5 });
  await page.keyboard.type('.');
  assert.equal(await page.locator('#ugx').inputValue(), '125');
  assert.deepEqual(await caret(page, '#ugx'), [3, 3]);
  await page.locator('#usd').fill('USD 12.345');
  assert.equal(await page.locator('#usd').inputValue(), '12.34');
  assert.equal(await page.locator('input[name=usd_amount]').inputValue(), '1234');
  assert.deepEqual(errors, []);
  await page.close();
});

test('the starter invoices page filters by the submitted minor units, with no console errors', async () => {
  const { page, errors } = await open(`${STARTER}invoices.html`);
  const rows = () => page.locator('.data-table tbody tr').count();
  assert.equal(await rows(), 8);
  await page.getByLabel('Minimum amount (USD)', { exact: true }).fill('10000');
  assert.equal(await page.getByLabel('Minimum amount (USD)', { exact: true }).inputValue(), '10,000');
  await page.getByRole('button', { name: 'Apply', exact: true }).click();
  // 10,000.00 USD is 1,000,000 cents: five sample invoices are at least that
  assert.equal(await rows(), 5);
  assert.deepEqual(errors, []);
  await page.close();
});

test('the starter access page grid: one Tab stop, arrows, Home, End, Ctrl+End', async () => {
  const { page, errors } = await open(`${STARTER}access.html`);
  const active = () => page.evaluate(() => [document.activeElement.id, document.querySelectorAll('[role=grid] [tabindex="0"]').length]);
  await page.locator('#access-grid-0-0').click();
  assert.deepEqual(await active(), ['access-grid-0-0', 1]);
  await page.keyboard.press('ArrowRight');
  assert.deepEqual(await active(), ['access-grid-0-1', 1]);
  await page.keyboard.press('ArrowDown');
  assert.deepEqual(await active(), ['access-grid-1-1', 1]);
  await page.keyboard.press('End');
  assert.deepEqual(await active(), ['access-grid-1-2', 1]);
  await page.keyboard.press('ArrowRight'); // the edge: stays
  assert.deepEqual(await active(), ['access-grid-1-2', 1]);
  await page.keyboard.press('Home');
  assert.deepEqual(await active(), ['access-grid-1-0', 1]);
  await page.keyboard.press('Control+End');
  assert.deepEqual(await active(), ['access-grid-3-2', 1]);
  await page.keyboard.press('Control+Home');
  assert.deepEqual(await active(), ['access-grid-0-0', 1]);
  assert.deepEqual(errors, []);
  await page.close();
});

test('money.fromMinor gives the digits a MoneyField keeps, the inverse of minorUnits', async () => {
  const { page, errors } = await open(FIXTURE);
  const r = await page.evaluate(() => {
    const m = window.money;
    if (typeof m.fromMinor !== 'function') return { missing: true };
    const cases = [['UGX', 0], ['UGX', 1250000], ['KES', 0], ['KES', 5], ['KES', 125050], ['KES', 100000], ['USD', 99], ['USD', 123400]];
    return {
      shown: cases.map(([c, n]) => m.fromMinor(n, c)),
      roundTrip: cases.every(([c, n]) => m.minorUnits(m.fromMinor(n, c), c) === n),
      keptAsTyped: cases.every(([c, n]) => m.digits(m.fromMinor(n, c), c) === m.fromMinor(n, c)),
      empty: [m.fromMinor(null, 'USD'), m.fromMinor(undefined, 'UGX')],
      throws: [-5, 1.5, Number.NaN].map((n) => { try { m.fromMinor(n, 'USD'); return false; } catch { return true; } }),
    };
  });
  assert.equal(r.missing, undefined, 'money.fromMinor exists');
  assert.deepEqual(r.shown, ['0', '1250000', '0', '0.05', '1250.50', '1000', '0.99', '1234']);
  assert.equal(r.roundTrip, true, 'minorUnits(fromMinor(n)) is n');
  assert.equal(r.keptAsTyped, true, 'digits() keeps what fromMinor gives unchanged');
  assert.deepEqual(r.empty, ['', '']);
  assert.deepEqual(r.throws, [true, true, true], 'a negative, fractional or non-number amount throws');
  assert.deepEqual(errors, []);
  await page.close();
});
