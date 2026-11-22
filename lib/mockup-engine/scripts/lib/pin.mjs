/**
 * pin.mjs: a browser context that renders the same way every run, shared by visual-diff.mjs
 * (baseline and app modes) and check-behaviours.mjs.
 *
 *   --clock <iso-instant>  Date is fixed at that instant (Playwright clock.setFixedTime)
 *   --seed <int>           Math.random is replaced by mulberry32 seeded with it, so skeleton widths
 *                          and generated values repeat
 * Pass the values the baseline was captured with. Time zone and locale come from the caller
 * (--tz, else config.timezoneId, else UTC; the locale from lib/project.mjs configLocale).
 */

/** Validates --clock and --seed. Returns { error } or { clock, seed } (seed null when not given). */
export function parsePins(clockArg, seedArg) {
  if (clockArg && Number.isNaN(Date.parse(clockArg))) return { error: `--clock ${clockArg} is not a date` };
  const seed = seedArg === undefined || seedArg === null ? null : Number(seedArg);
  if (seed !== null && (String(seedArg).trim() === '' || !Number.isInteger(seed))) return { error: `--seed must be an integer, got '${seedArg}'` };
  return { clock: clockArg, seed };
}

/**
 * A new context at the viewport's size, scale 1, reduced motion, in that time zone and locale, with
 * the clock and Math.random pinned. The page's CSP is enforced: a port is measured under its own
 * security headers, so a style or script the CSP blocks shows in the diff. Styles the checks inject
 * go through adoptStyle, which a strict CSP allows.
 */
export async function newPinnedContext(browser, vp, { timezoneId, locale, clock, seed }) {
  const ctx = await browser.newContext({ viewport: { width: vp.width, height: vp.height }, deviceScaleFactor: 1, reducedMotion: 'reduce', timezoneId, locale });
  try {
    if (clock) await ctx.clock.setFixedTime(clock);
    if (seed !== null && seed !== undefined) {
      await ctx.addInitScript((s) => {
        let a = s >>> 0;
        Math.random = function () { a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
      }, seed);
    }
  } catch (e) { await ctx.close(); throw e; }
  return ctx;
}

/**
 * Adds css to the page as a constructed stylesheet. A <style> element (page.addStyleTag) is inline
 * style, which a strict style-src blocks and logs as the page's own violation; a constructed sheet
 * is not subject to it. Returns a function that removes the sheet again.
 */
export async function adoptStyle(page, css) {
  const id = `mk-adopted-${Math.random().toString(36).slice(2)}`;
  await page.evaluate(({ css, id }) => {
    const sheet = new CSSStyleSheet();
    sheet.replaceSync(css);
    (window.__mkAdopted ||= {})[id] = sheet;
    document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet];
  }, { css, id });
  return () => page.evaluate((id) => {
    const sheet = window.__mkAdopted?.[id];
    document.adoptedStyleSheets = document.adoptedStyleSheets.filter((x) => x !== sheet);
    delete window.__mkAdopted?.[id];
  }, id);
}
