/**
 * pin.test.mjs: lib/pin.mjs (sweep F). parsePins accepts a date and an integer seed and names a bad
 * one; newPinnedContext gives a context at the viewport's size in the time zone and locale asked
 * for, with Date fixed at --clock and Math.random repeating per seed; adoptStyle applies a style
 * on a page whose CSP has style-src 'self' with no violation, and its remover takes it off again.
 * Launches a browser; the page is served on 127.0.0.1.
 * Run: node --test test/pin.test.mjs   (from scripts/)
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { chromium } from 'playwright';
import { adoptStyle, newPinnedContext, parsePins } from '../lib/pin.mjs';

const PAGE = '<!doctype html><html><head><title>pin</title></head><body><p id="t">text</p></body></html>';
let server, base, browser;
before(async () => {
  server = createServer((q, res) => {
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'content-security-policy': "default-src 'self'; style-src 'self'; script-src 'self'" }).end(PAGE);
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}/`;
  browser = await chromium.launch();
});
after(async () => { await browser?.close(); server?.close(); });

const VP = { name: 'desktop', width: 640, height: 480 };

test('parsePins: a date and an integer seed pass; a bad clock or seed is an error naming the flag', () => {
  assert.deepEqual(parsePins('2026-01-15T09:30:00Z', '42'), { clock: '2026-01-15T09:30:00Z', seed: 42 });
  assert.deepEqual(parsePins(undefined, undefined), { clock: undefined, seed: null });
  assert.deepEqual(parsePins(undefined, '-3'), { clock: undefined, seed: -3 });
  assert.match(parsePins('not-a-date', undefined).error, /^--clock not-a-date is not a date$/);
  for (const s of ['1.5', 'abc']) assert.match(parsePins(undefined, s).error, /^--seed must be an integer, got /, `seed ${JSON.stringify(s)}`);
});

test('parsePins: an empty --seed is an error, not seed 0', () => {
  assert.match(parsePins(undefined, '').error ?? '', /^--seed must be an integer, got /);
});

test('newPinnedContext: viewport, scale 1, reduced motion, time zone and locale as asked', async () => {
  const ctx = await newPinnedContext(browser, VP, { timezoneId: 'Asia/Tokyo', locale: 'de-DE', clock: undefined, seed: null });
  try {
    const page = await ctx.newPage();
    await page.goto(base);
    const got = await page.evaluate(() => ({
      w: innerWidth, h: innerHeight, dpr: devicePixelRatio,
      reduced: matchMedia('(prefers-reduced-motion: reduce)').matches,
      zone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      lang: navigator.language,
      number: (1234.5).toLocaleString(),
    }));
    assert.deepEqual(got, { w: 640, h: 480, dpr: 1, reduced: true, zone: 'Asia/Tokyo', lang: 'de-DE', number: '1.234,5' });
  } finally { await ctx.close(); }
});

test('newPinnedContext: Date is fixed at the clock, and stays there', async () => {
  const clock = '2026-01-15T09:30:00.000Z';
  const ctx = await newPinnedContext(browser, VP, { timezoneId: 'UTC', locale: 'en-GB', clock, seed: null });
  try {
    const page = await ctx.newPage();
    await page.goto(base);
    const first = await page.evaluate(() => [Date.now(), new Date().toISOString()]);
    await page.waitForTimeout(50);
    const later = await page.evaluate(() => Date.now());
    assert.deepEqual(first, [Date.parse(clock), clock]);
    assert.equal(later, Date.parse(clock));
  } finally { await ctx.close(); }
});

async function randoms(seed) {
  const ctx = await newPinnedContext(browser, VP, { timezoneId: 'UTC', locale: 'en-GB', clock: undefined, seed });
  try {
    const page = await ctx.newPage();
    await page.goto(base);
    return await page.evaluate(() => Array.from({ length: 5 }, () => Math.random()));
  } finally { await ctx.close(); }
}

test('newPinnedContext: one seed repeats Math.random across contexts, another seed differs, no seed is not pinned', async () => {
  const a = await randoms(7);
  const b = await randoms(7);
  const c = await randoms(8);
  assert.deepEqual(a, b);
  assert.notDeepEqual(a, c);
  for (const x of [...a, ...c]) assert.ok(x >= 0 && x < 1, String(x));
  // seed 0 is a seed, not "no seed"
  assert.deepEqual(await randoms(0), await randoms(0));
  assert.notDeepEqual(await randoms(null), await randoms(null));
});

test('adoptStyle applies a style under style-src \'self\' with no CSP violation, and the remover takes it off', async () => {
  const ctx = await newPinnedContext(browser, VP, { timezoneId: 'UTC', locale: 'en-GB', clock: undefined, seed: null });
  try {
    const page = await ctx.newPage();
    const violations = [];
    page.on('console', (m) => { if (/Content.Security.Policy|Refused to apply/i.test(m.text())) violations.push(m.text()); });
    await page.goto(base);
    await page.evaluate(() => { window.__v = []; document.addEventListener('securitypolicyviolation', (e) => window.__v.push(e.violatedDirective)); });
    const color = () => page.evaluate(() => getComputedStyle(document.getElementById('t')).color);
    const before = await color();
    const remove = await adoptStyle(page, '#t { color: rgb(1, 2, 3) }');
    assert.equal(await color(), 'rgb(1, 2, 3)');
    assert.deepEqual(await page.evaluate(() => window.__v), []);
    assert.deepEqual(violations, []);
    await remove();
    assert.equal(await color(), before);
    assert.equal(await page.evaluate(() => document.adoptedStyleSheets.length), 0);
  } finally { await ctx.close(); }
});
