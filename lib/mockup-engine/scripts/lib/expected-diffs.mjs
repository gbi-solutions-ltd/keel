/**
 * expected-diffs.mjs: the baseline mode's judgement, kept free of the browser so a test can feed it
 * PNGs. visual-diff.mjs --baseline captures; everything that decides pass or fail lives here.
 *
 * Baseline PNGs are named by slugFor (lib/screens.mjs): <name>--<state>--<viewport>.png.
 *
 * expected-diffs.json (default <mockup>/docs/expected-diffs.json):
 *   {
 *     "rules":   [{ "viewport": "mobile", "mask": { "x", "y", "w", "h" }, "reason": "..." }],
 *     "screens": [{ "name": "ap-payments", "viewport": "mobile", "state"?: "default",
 *                   "maxMismatchPercent": 4.45, "size"?: { "w": 390, "h": 2229 }, "reason": "..." }]
 *   }
 *   - viewport: a config viewport name, or "*" for every viewport.
 *   - rules[].mask: painted into both images before the pixel diff. The masks that apply to one
 *     viewport (its own plus the "*" ones) may cover at most MASK_AREA_SHARE of that viewport's
 *     first screen (width x height) in total, so a mask is never an unlimited exemption.
 *   - screens[]: raises one screen's limit above config.diff.maxMismatchPercent, up to
 *     MAX_PERCENT_CAP (5). state is optional; without it the entry covers every state.
 *   - screens[].size: a measured page-size change. Only when it equals the capture exactly are the
 *     two images compared over their common top-left region. A declared size that differs from the
 *     capture, and any size difference with no size declared, is size-mismatch.
 *   - reason: required on every rule and screens entry.
 *
 * Status per case: pass, expected (over the config limit, within its screens entry), fail,
 * size-mismatch.
 *
 * App mode (visual-diff.mjs --app with a named --expected) uses the same file and the same rules and
 * screens entries, judged against the mockup's capture instead of a baseline PNG: validateAppExpected,
 * maskCases and appStatus below. App mode pads a size difference (it counts as mismatch), so a
 * screens[].size declaration is refused there; raise the screen's limit instead.
 *
 * Unused entries (unusedEntries, formatUnused): after a run with an expected-diffs file, a screens
 * entry is listed as not needed when every case it covers was measured in the run at or under the
 * config limit (and, for a size entry, none was resized), or when it matches no case of the
 * mockup's config at all (expectedCover gives an entry's cases over the whole config). An entry is not judged when any case it covers was
 * filtered out, skipped, had no baseline, errored or went unreported, unless a measured case
 * already needs it. rules (masks) are not judged: that would need a second, unmasked diff. The
 * list is a warning; it never changes a run's exit status.
 */
import pixelmatch from 'pixelmatch';
import { PNG } from 'pngjs';

export const MAX_PERCENT_CAP = 5;
export const MASK_AREA_SHARE = 0.1;
const MASK_RGBA = [255, 0, 255, 255];
export const FAILING = new Set(['fail', 'size-mismatch', 'error']);

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);

/** Parse a baseline file name into { name, state, viewport }, or null when it is not a slug PNG. */
export function parseBaselineName(file) {
  if (!file.endsWith('.png')) return null;
  const parts = file.slice(0, -4).split('--');
  if (parts.length < 3 || parts.some((p) => !p)) return null;
  const viewport = parts.pop();
  const state = parts.pop();
  return { name: parts.join('--'), state, viewport };
}

/**
 * Check an expected-diffs object before it is trusted. Returns an array of error strings (empty
 * when valid).
 *   viewports: the config viewports [{ name, width, height }]
 *   baseline:  the baseline PNGs as [{ name, state, viewport }], to catch a screens entry that
 *              matches nothing
 */
export function validateExpected(expected, { viewports, baseline = [] }) {
  const errors = [];
  if (!isObj(expected)) return ['expected-diffs: not an object'];
  const vpNames = viewports.map((v) => v.name);
  const allowed = [...vpNames, '*'];
  const covers = (vp) => (vp === '*' ? vpNames : [vp]);
  for (const k of Object.keys(expected)) if (!['rules', 'screens'].includes(k)) errors.push(`expected-diffs: unknown key "${k}"`);
  for (const k of ['rules', 'screens']) if (expected[k] !== undefined && !Array.isArray(expected[k])) errors.push(`expected-diffs: "${k}" is not an array`);
  const rules = Array.isArray(expected.rules) ? expected.rules : [];
  const screens = Array.isArray(expected.screens) ? expected.screens : [];
  const reason = (e, where) => { if (typeof e.reason !== 'string' || !e.reason.trim()) errors.push(`${where}: no reason`); };
  const viewport = (e, where) => { if (!allowed.includes(e.viewport)) errors.push(`${where}: viewport ${JSON.stringify(e.viewport)} is not one of ${allowed.join(', ')}`); };

  const area = Object.fromEntries(vpNames.map((v) => [v, 0]));
  rules.forEach((r, i) => {
    const where = `rules[${i}]`;
    if (!isObj(r)) { errors.push(`${where}: not an object`); return; }
    for (const k of Object.keys(r)) if (!['viewport', 'mask', 'reason'].includes(k)) errors.push(`${where}: unknown key "${k}"`);
    viewport(r, where);
    reason(r, where);
    if (r.mask === undefined) { errors.push(`${where}: no mask (a rule without a mask does nothing)`); return; }
    const m = r.mask;
    const ok = isObj(m) && Object.keys(m).length === 4 && ['x', 'y', 'w', 'h'].every((k) => Number.isInteger(m[k]) && m[k] >= 0) && m.w > 0 && m.h > 0;
    if (!ok) { errors.push(`${where}: mask must be { x, y, w, h }, whole pixels, w and h above 0: ${JSON.stringify(m)}`); return; }
    if (allowed.includes(r.viewport)) for (const v of covers(r.viewport)) area[v] += m.w * m.h;
  });
  for (const v of viewports) {
    const cap = Math.floor(v.width * v.height * MASK_AREA_SHARE);
    if (area[v.name] > cap) errors.push(`rules: masks on ${v.name} (its rules plus the "*" rules) cover ${area[v.name]} px², over the cap of ${cap} px² (${MASK_AREA_SHARE * 100}% of ${v.width} x ${v.height})`);
  }

  const known = new Set(baseline.map((b) => `${b.name}|${b.viewport}|${b.state}`));
  const knownAnyState = new Set(baseline.map((b) => `${b.name}|${b.viewport}`));
  const claimed = new Map();
  screens.forEach((e, i) => {
    const where = `screens[${i}]${isObj(e) && typeof e.name === 'string' ? ` (${e.name})` : ''}`;
    if (!isObj(e)) { errors.push(`${where}: not an object`); return; }
    for (const k of Object.keys(e)) if (!['name', 'viewport', 'state', 'maxMismatchPercent', 'size', 'reason'].includes(k)) errors.push(`${where}: unknown key "${k}"`);
    if (typeof e.name !== 'string' || !e.name) errors.push(`${where}: no name`);
    if (e.state !== undefined && (typeof e.state !== 'string' || !e.state)) errors.push(`${where}: state must be a non-empty string`);
    viewport(e, where);
    reason(e, where);
    const p = e.maxMismatchPercent;
    if (typeof p !== 'number' || !Number.isFinite(p) || !(p > 0)) errors.push(`${where}: maxMismatchPercent ${JSON.stringify(p)} is not a number above 0`);
    else if (p > MAX_PERCENT_CAP) errors.push(`${where}: maxMismatchPercent ${p} is over the cap of ${MAX_PERCENT_CAP}`);
    if (e.size !== undefined) {
      const z = e.size;
      const ok = isObj(z) && Object.keys(z).length === 2 && ['w', 'h'].every((k) => Number.isInteger(z[k]) && z[k] > 0);
      if (!ok) errors.push(`${where}: size must be { w, h }, whole pixels above 0: ${JSON.stringify(z)}`);
    }
    if (typeof e.name === 'string' && allowed.includes(e.viewport)) {
      const vps = covers(e.viewport);
      const hit = vps.some((v) => (e.state ? known.has(`${e.name}|${v}|${e.state}`) : knownAnyState.has(`${e.name}|${v}`)));
      if (!hit) errors.push(`${where}: matches no baseline PNG (${e.name}${e.state ? ` ${e.state}` : ''} at ${e.viewport})`);
      // One entry per screen, viewport and state: with two, the first found would win silently.
      // An entry without a state covers every state, so it clashes with any other for that screen.
      for (const v of vps) {
        const prior = (claimed.get(`${e.name}|${v}`) || []).find((c) => c.state === '*' || !e.state || c.state === e.state);
        if (prior) errors.push(`${where}: duplicate of screens[${prior.i}] for ${e.name} at ${v}`);
        else claimed.set(`${e.name}|${v}`, [...(claimed.get(`${e.name}|${v}`) || []), { i, state: e.state ?? '*' }]);
      }
    }
  });
  return errors;
}

/** The screens entry for one case, or undefined. */
export function entryFor(expected, { name, viewport, state }) {
  return ((expected && expected.screens) || []).find((s) => s.name === name && (s.viewport === viewport || s.viewport === '*') && (s.state === undefined || s.state === state));
}

function paint(img, { x, y, w, h }) {
  const x0 = Math.max(0, x), y0 = Math.max(0, y), x1 = Math.min(img.width, x + w), y1 = Math.min(img.height, y + h);
  for (let yy = y0; yy < y1; yy++) for (let xx = x0; xx < x1; xx++) img.data.set(MASK_RGBA, (yy * img.width + xx) * 4);
}

/**
 * One comparison. baseline and actual are PNG buffers; expected is the expected-diffs object (or
 * null). Returns { mismatchPercent, status, diff?, size?, compared? } where diff is a PNG buffer of
 * the difference (only when the status is not pass).
 */
export function compareImages({ baseline, actual, name, viewport, state = 'default', expected = null, maxMismatchPercent = 0.2, pixelThreshold = 0.1 }) {
  let a = PNG.sync.read(baseline), b = PNG.sync.read(actual);
  const entry = entryFor(expected, { name, viewport, state });
  const size = { baseline: `${a.width}x${a.height}`, actual: `${b.width}x${b.height}` };
  const resized = a.width !== b.width || a.height !== b.height;
  // A declared size must equal the capture exactly: a stale declaration never raises a limit
  if (entry && entry.size && (entry.size.w !== b.width || entry.size.h !== b.height)) {
    return { mismatchPercent: null, status: 'size-mismatch', size: { ...size, declared: `${entry.size.w}x${entry.size.h}` } };
  }
  if (resized) {
    if (!(entry && entry.size)) return { mismatchPercent: null, status: 'size-mismatch', size };
    const w = Math.min(a.width, b.width), h = Math.min(a.height, b.height);
    const crop = (img) => { const o = new PNG({ width: w, height: h }); PNG.bitblt(img, o, 0, 0, w, h, 0, 0); return o; };
    a = crop(a); b = crop(b);
  }
  for (const r of (expected && expected.rules) || []) {
    if (r.mask && (r.viewport === '*' || r.viewport === viewport)) { paint(a, r.mask); paint(b, r.mask); }
  }
  const diff = new PNG({ width: a.width, height: a.height });
  const n = pixelmatch(a.data, b.data, diff.data, a.width, a.height, { threshold: pixelThreshold, includeAA: false });
  const mismatchPercent = +((n / (a.width * a.height)) * 100).toFixed(4);
  let status = 'pass';
  if (mismatchPercent > maxMismatchPercent) status = entry && mismatchPercent <= entry.maxMismatchPercent ? 'expected' : 'fail';
  return { mismatchPercent, status, diff: status === 'pass' ? null : PNG.sync.write(diff), ...(resized ? { size, compared: `${a.width}x${a.height}` } : {}) };
}

/**
 * validateExpected for app mode: `cases` are the config's screen x state x viewport cases as
 * [{ name, state, viewport }] (they play the baseline PNGs' part), and size declarations are refused.
 */
export function validateAppExpected(expected, { viewports, cases }) {
  const errors = validateExpected(expected, { viewports, baseline: cases });
  ((isObj(expected) && Array.isArray(expected.screens) && expected.screens) || []).forEach((e, i) => {
    if (isObj(e) && e.size !== undefined) errors.push(`screens[${i}]${typeof e.name === 'string' ? ` (${e.name})` : ''}: size applies to --baseline mode only (app mode pads a size difference; raise maxMismatchPercent instead)`);
  });
  return errors;
}

/** Paint the masks that apply to `viewport` into both decoded images (app mode), in place. */
export function maskCases(a, b, expected, viewport) {
  for (const r of (expected && expected.rules) || []) {
    if (r.mask && (r.viewport === '*' || r.viewport === viewport)) { paint(a, r.mask); paint(b, r.mask); }
  }
}

/** App mode status: pass under the config limit, expected within the case's screens entry, else fail. */
export function appStatus(mismatchPercent, { expected = null, name, viewport, state = 'default', maxMismatchPercent = 0.2 }) {
  if (mismatchPercent <= maxMismatchPercent) return 'pass';
  const entry = entryFor(expected, { name, viewport, state });
  return entry && mismatchPercent <= entry.maxMismatchPercent ? 'expected' : 'fail';
}

/**
 * Exit code for a finished baseline run: 1 when anything failed, nothing was compared, or a case
 * has no baseline PNG (a screen added after the baseline was written would otherwise never be
 * compared) unless allowMissingBaseline (visual-diff.mjs --allow-missing-baseline).
 */
export function exitCodeFor(rows, { allowMissingBaseline = false } = {}) {
  if (!rows.some((r) => r.mismatchPercent !== null || r.status === 'size-mismatch')) return 1;
  if (!allowMissingBaseline && rows.some((r) => r.status === 'no-baseline')) return 1;
  return rows.some((r) => FAILING.has(r.status)) ? 1 : 0;
}

/**
 * The no-baseline cases, listed: an error line (they fail the run) or, with allowMissingBaseline,
 * a warning line, then one indented slug per case. Empty when every case had a PNG.
 */
export function missingBaselineLines(rows, { allowMissingBaseline = false } = {}) {
  const slugs = rows.filter((r) => r.status === 'no-baseline').map((r) => r.slug).sort();
  if (!slugs.length) return [];
  const n = slugs.length === 1 ? '1 case has' : `${slugs.length} cases have`;
  const head = allowMissingBaseline
    ? `warning: ${n} no baseline PNG and ${slugs.length === 1 ? 'was' : 'were'} not compared (--allow-missing-baseline):`
    : `error: ${n} no baseline PNG (write ${slugs.length === 1 ? 'it' : 'them'} with --write-baseline, or pass --allow-missing-baseline to list ${slugs.length === 1 ? 'it' : 'them'} without failing):`;
  return [head, ...slugs.map((s) => `  ${s}`)];
}

/**
 * One line per non-pass case, then a tally line. The tally names the worst case only when its
 * mismatch is above 0 (`max mismatch 0%` names none). merge-shards.mjs prints the same line.
 */
export function summarise(rows) {
  const counts = {};
  for (const r of rows) counts[r.status] = (counts[r.status] || 0) + 1;
  const compared = rows.filter((r) => r.mismatchPercent !== null);
  const max = compared.reduce((m, r) => (r.mismatchPercent > m.mismatchPercent ? r : m), compared[0] || { mismatchPercent: 0 });
  const lines = rows.filter((r) => ['fail', 'size-mismatch', 'expected', 'error'].includes(r.status))
    .map((r) => `  ${r.status.padEnd(13)} ${r.slug}${r.mismatchPercent !== null && r.mismatchPercent !== undefined ? ` ${r.mismatchPercent}%` : ''}${r.size ? ` baseline ${r.size.baseline}, capture ${r.size.actual}${r.size.declared ? `, declared ${r.size.declared}` : ''}` : ''}${r.error ? ` ${r.error}` : ''}`);
  const names = new Set(compared.map((r) => r.name)).size;
  const order = ['pass', 'expected', 'fail', 'size-mismatch', 'error', 'skipped', 'no-baseline'];
  const tally = order.filter((k) => counts[k]).map((k) => `${counts[k]} ${k}`).join(', ') || 'nothing to report';
  return [...lines, `baseline diff: ${compared.length} compared (${names} screens), max mismatch ${max.mismatchPercent}%${max.mismatchPercent > 0 ? ` (${max.slug})` : ''}; ${tally}`].join('\n');
}

const covers = (e, r) => e.name === r.name && (e.viewport === '*' || e.viewport === r.viewport) && (e.state === undefined || e.state === r.state);

/**
 * For each screens entry, the slugs of the config cases it covers. cases: every case of the
 * mockup's config, unfiltered ([{ slug, name, state, viewport }]). An empty list: the entry
 * matches no case.
 */
export function expectedCover(expected, cases) {
  return ((expected && expected.screens) || []).map((e) => cases.filter((c) => covers(e, c)).map((c) => c.slug));
}

/**
 * The screens entries a finished run did not need. rows: the run's rows by slug ({ slug,
 * mismatchPercent, status?, error?, compared? }); cover: expectedCover over the whole config.
 * Returns [{ index, name, viewport, state?, why: 'at-or-under-limit' | 'no-case', maxMeasured?,
 * cases? }] in file order.
 */
export function unusedEntries(expected, rows, { maxMismatchPercent = 0.2, cover = [] } = {}) {
  const bySlug = new Map(rows.map((r) => [r.slug, r]));
  const isMeasured = (r) => r && typeof r.mismatchPercent === 'number' && !r.error && !['skipped', 'no-baseline', 'size-mismatch', 'error'].includes(r.status);
  const out = [];
  ((expected && expected.screens) || []).forEach((e, index) => {
    const base = { index, name: e.name, viewport: e.viewport, ...(e.state !== undefined ? { state: e.state } : {}) };
    const slugs = cover[index] || [];
    if (!slugs.length) { out.push({ ...base, why: 'no-case' }); return; }
    const measured = slugs.map((s) => bySlug.get(s)).filter(isMeasured);
    // Needed by a measured case, or not judged because a case it covers went unmeasured
    if (measured.some((r) => r.mismatchPercent > maxMismatchPercent || (e.size && r.compared))) return;
    if (measured.length < slugs.length) return;
    out.push({ ...base, why: 'at-or-under-limit', maxMeasured: Math.max(...measured.map((r) => r.mismatchPercent)), cases: measured.length });
  });
  return out;
}

/** The warning lines for unusedEntries' list (none when it is empty). */
export function formatUnused(unused, maxMismatchPercent) {
  if (!unused.length) return [];
  return [
    `warning: ${unused.length} expected-diffs ${unused.length === 1 ? 'entry' : 'entries'} not needed (the exit status is unchanged):`,
    ...unused.map((u) => `  screens[${u.index}] ${u.name} at ${u.viewport}${u.state !== undefined ? ` ${u.state}` : ' (every state)'}: ${u.why === 'no-case' ? 'matches no case in mockup.config.json' : `measured at most ${u.maxMeasured}% over ${u.cases} ${u.cases === 1 ? 'case' : 'cases'}, at or under the ${maxMismatchPercent}% limit`}`),
  ];
}
