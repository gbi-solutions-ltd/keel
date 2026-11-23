/**
 * shard.mjs: split a check run into N shards that run as separate processes, and merge their
 * results back. Used by check-behaviours.mjs and visual-diff.mjs (--shard K/N) and merge-shards.mjs.
 *
 * Planning is deterministic: every shard process computes the same plan from the same inputs and
 * runs only its own share, so no plan file passes between processes. LPT (longest processing time
 * first): the heaviest unit goes to the lightest shard (ties: the earlier unit, the lower shard),
 * and each shard keeps its units in their original order.
 *
 * Weights, in rough seconds of browser time:
 *   behaviour: 1 per load, plus 1 per step, plus wait ms / 700, plus typed chars x 30 / 700
 *              (runSteps types with a 30ms delay per key)
 *   diff, per screen name: per captured case 1, plus its baseline PNG's megapixels (read from the
 *              IHDR, not decoded), plus 0.5 per config step. A name is never split, so one
 *              screen's states and viewports stay in one shard.
 *   app diff, per screen (slug name): the same weights with no baseline PNG (0 megapixels), so a
 *              case is 1 plus 0.5 per config step (planAppShards).
 *
 * Merge rules: a unit no shard reported is a fail ("no result from shard K"), never a silent pass;
 * a shard that exits non-zero with no failed row (a crash after its rows, a browser that would not
 * close) fails the merge too.
 *
 * App mode (visual-diff.mjs --app --shard K/N, merged by mergeAppShards): a planned case is
 * "measured" when its owning shard reported it with a mismatch and no error. The merge states
 * `X of N planned captures measured, not measured: M` (measuredLine) and fails when M > 0.
 */
import { closeSync, openSync, readSync } from 'node:fs';
import { join, relative } from 'node:path';
import { FAILING } from './expected-diffs.mjs';

/** Parses "K/N" (1 <= K <= N). Returns { k, n } or { error }. */
export function parseShard(s) {
  const m = /^(\d+)\/(\d+)$/.exec(String(s ?? ''));
  const k = m ? Number(m[1]) : NaN, n = m ? Number(m[2]) : NaN;
  if (!m || n < 1 || k < 1 || k > n) return { error: `--shard must be K/N with 1 <= K <= N, got ${s}` };
  return { k, n };
}

/**
 * items: [{ key, weight, ... }] in their original order. Returns one bin per shard ({ load, items }),
 * always n bins; a bin is empty when there are fewer items than shards.
 */
export function lpt(items, n) {
  const bins = Array.from({ length: Math.max(1, n) }, () => ({ load: 0, idx: [] }));
  const order = items.map((_, i) => i).sort((a, b) => items[b].weight - items[a].weight || a - b);
  for (const i of order) {
    let best = 0;
    for (let k = 1; k < bins.length; k++) if (bins[k].load < bins[best].load) best = k;
    bins[best].load += items[i].weight;
    bins[best].idx.push(i);
  }
  return bins.map((b) => ({ load: b.load, items: b.idx.sort((x, y) => x - y).map((i) => items[i]) }));
}

/** 1 per load, plus 1 per step, plus wait ms / 700, plus typed chars x 30 / 700. */
export function behaviourWeight(b) {
  let w = 1;
  for (const s of b.steps || []) {
    w += 1;
    if (typeof s.wait === 'number') w += s.wait / 700;
    if (typeof s.type === 'string') w += (s.type.length * 30) / 700;
  }
  return w;
}

/** The behaviour entries of each shard, in file order: an array of n arrays. */
export function planBehaviourShards(list, n) {
  return lpt(list.map((b) => ({ key: b.id, weight: behaviourWeight(b), entry: b })), n).map((bin) => bin.items.map((it) => it.entry));
}

/** Megapixels of a PNG from its IHDR (bytes 16 to 23), without decoding it; 0 when unreadable. */
export function pngMegapixels(file) {
  let fd;
  try {
    fd = openSync(file, 'r');
    const b = Buffer.alloc(24);
    if (readSync(fd, b, 0, 24, 0) < 24) return 0;
    return (b.readUInt32BE(16) * b.readUInt32BE(20)) / 1e6;
  } catch { return 0; } finally { if (fd !== undefined) closeSync(fd); }
}

/**
 * jobs: [{ name, steps, png }] in plan order, one per captured case. Returns the screen names of each
 * shard: an array of n Sets. megapixels(png) is pngMegapixels unless a test passes its own.
 */
export function planDiffShards(jobs, n, megapixels = pngMegapixels) {
  const byName = new Map();
  for (const j of jobs) {
    const it = byName.get(j.name) || { key: j.name, weight: 0 };
    it.weight += 1 + megapixels(j.png) + 0.5 * (j.steps || []).length;
    byName.set(j.name, it);
  }
  return lpt([...byName.values()], n).map((bin) => new Set(bin.items.map((it) => it.key)));
}

/**
 * App mode: jobs are [{ key, steps }] in plan order, one per case (key: the slug name, screenKey).
 * Returns the keys of each shard: an array of n Sets.
 */
export function planAppShards(jobs, n) {
  return planDiffShards(jobs.map((j) => ({ name: j.key, steps: j.steps, png: null })), n, () => 0);
}

/**
 * Behaviour rows back in file order.
 *   shards:  the ids of each shard (planBehaviourShards), index K-1
 *   order:   every id in file order
 *   outputs: [{ k, text, code }]: shard K's stdout (null when it left none) and exit status (null
 *            when unknown)
 * Returns { lines, failed, exitCode }: lines are `<id>: <result>` in file order, then a line per
 * shard problem, then `X/Y behaviours ok`, the form a serial run prints.
 */
export function mergeBehaviourShards({ shards, order, outputs }) {
  const result = new Map(); // id -> result text
  const extra = [];
  let crashed = 0;
  shards.forEach((ids, i) => {
    const k = i + 1;
    if (!ids.length) return;
    const out = outputs.find((o) => o.k === k) || { text: null, code: null };
    let failed = 0;
    for (const l of (out.text || '').split('\n').filter(Boolean)) {
      if (/^\d+\/\d+ behaviours ok$/.test(l)) continue;
      const id = ids.find((x) => l.startsWith(`${x}: `) && !result.has(x));
      if (id === undefined) { extra.push(`shard ${k}: ${l}`); continue; }
      const r = l.slice(id.length + 2);
      result.set(id, r);
      if (r !== 'ok') failed++;
    }
    if (out.code !== 0 && !failed && ids.every((id) => result.has(id))) {
      crashed++;
      extra.push(`shard ${k}: exit ${out.code ?? 'unknown'} with no failed row`);
    }
  });
  const shardOf = new Map();
  shards.forEach((ids, i) => ids.forEach((id) => shardOf.set(id, i + 1)));
  const rows = order.map((id) => `${id}: ${result.has(id) ? result.get(id) : `fail: no result from shard ${shardOf.get(id)}`}`);
  const failed = rows.filter((r) => !r.endsWith(': ok')).length;
  return { lines: [...rows, ...extra, `${rows.length - failed}/${rows.length} behaviours ok`], failed, exitCode: failed || crashed ? 1 : 0 };
}

/** The error when no shard left a report: naming the unreadable ones, when there are. */
export function noReportError(reports) {
  const unreadable = reports.filter((r) => r.unreadable).map((r) => `shard ${r.k}: report.json unreadable`);
  return unreadable.length ? `no shard left a readable report.json (${unreadable.join('; ')})` : 'no shard left a report.json';
}

/** The shard reports agree on one plan: returns { error } or { first, n }. extraKey adds header fields to compare. */
function checkPlans(reports, extraKey = () => null) {
  const present = reports.filter((r) => r.report);
  if (!present.length) return { error: noReportError(reports) };
  const first = present[0].report;
  if (!first.shard) return { error: `shard ${present[0].k}'s report.json was not written by a --shard run` };
  const n = first.shard.n;
  const planKey = (rep) => JSON.stringify([rep.shard.n, rep.shard.planned, rep.shard.owner, extraKey(rep)]);
  for (const r of present) {
    if (!r.report.shard) return { error: `shard ${r.k}'s report.json was not written by a --shard run` };
    if (r.report.shard.k !== r.k) return { error: `the report.json read as shard ${r.k} is shard ${r.report.shard.k}'s` };
    if (planKey(r.report) !== planKey(first)) return { error: `shard ${r.k} planned a different run from shard ${present[0].k} (other inputs or flags)` };
  }
  if (reports.length !== n) return { error: `the shards were planned as ${n}, ${reports.length} given` };
  return { first, n, present };
}

/** One shard's report problem, or null: an unreadable report always, a missing one when it owned cases. */
export function missingReport(r, owner) {
  if (r.unreadable) return `shard ${r.k}: report.json unreadable`;
  return Object.values(owner).includes(r.k) ? `shard ${r.k}: no report.json` : null;
}

/**
 * Baseline-diff rows from the report.json of each shard (visual-diff --baseline --shard K/N).
 *   reports: [{ k, report, code, unreadable? }]: report is the parsed report.json (null when the
 *            shard left none, or left one that does not parse: then unreadable is true), code its
 *            exit status (null when unknown)
 * Every shard's report carries the whole plan (shard.planned: every row with status compared,
 * skipped or no-baseline; shard.owner: screen name -> K), so the rows of a shard that died are
 * still known. Returns { error } when no shard left a report or the shards disagree on the plan
 * (allowMissingBaseline included), else { rows, extra, meta, failedShards }: rows unsorted, extra a
 * line per shard problem, meta the first report's header fields, failedShards the shards that died
 * (no report while owning cases, an unreadable report, or a non-zero exit with no failed row).
 */
export function mergeDiffShards(reports) {
  const plan = checkPlans(reports, (rep) => rep.allowMissingBaseline ?? false);
  if (plan.error) return plan;
  const { first, present } = plan;
  const cases = new Map(); // k -> Map(slug -> row)
  for (const r of present) cases.set(r.k, new Map(r.report.cases.map((c) => [c.slug, c])));
  const extra = [];
  let failedShards = 0;
  for (const r of reports) {
    if (!r.report) { const p = missingReport(r, first.shard.owner); if (p) { failedShards++; extra.push(p); } continue; }
    const failed = r.report.cases.some((c) => FAILING.has(c.status));
    if (r.code !== 0 && !failed) { failedShards++; extra.push(`shard ${r.k}: exit ${r.code ?? 'unknown'} with no failed row`); }
  }
  const rows = first.shard.planned.map((p) => {
    const row = { slug: p.slug, name: p.name, state: p.state, viewport: p.viewport, mismatchPercent: null };
    if (p.status !== 'compared') return { ...row, status: p.status };
    const k = first.shard.owner[p.name];
    const got = cases.get(k)?.get(p.slug);
    return got || { ...row, status: 'fail', error: `no result from shard ${k}` };
  });
  const { shard, cases: _cases, summary: _summary, generatedAt: _at, ...meta } = first;
  return { rows, extra, meta, failedShards };
}

/** `X of N planned captures measured, not measured: M` for app-mode rows (measured: no error). */
export function measuredLine(rows) {
  const measured = rows.filter((r) => !r.error && typeof r.mismatchPercent === 'number').length;
  return { measured, notMeasured: rows.length - measured, line: `${measured} of ${rows.length} planned captures measured, not measured: ${rows.length - measured}` };
}

/**
 * App-mode rows from the report.json of each shard (visual-diff --app --shard K/N).
 *   reports: [{ k, report, code, dir? }]: as mergeDiffShards; dir is the shard's out folder, used
 *            to make each case's files paths relative to opts.outDir (the merged folder) when both
 *            are given
 * Every shard's report carries the whole plan (shard.planned: { slug, key, name, route, role,
 * state, viewport } per case in config order; shard.owner: key -> K) and the shards must agree on
 * it and on appBase. Returns { error } (also when the plan has no case) or { rows, extra, meta,
 * failedShards }: rows in plan order, a case no shard reported is an error row "no result from
 * shard K".
 */
export function mergeAppShards(reports, { outDir = null } = {}) {
  const plan = checkPlans(reports, (rep) => rep.appBase ?? null);
  if (plan.error) return plan;
  const { first, present } = plan;
  // A run that selected nothing must never merge as 0/0 passing
  if (!first.shard.planned.length) return { error: 'the shards planned no case (the filters select nothing); nothing was measured' };
  const cases = new Map();
  for (const r of present) cases.set(r.k, new Map(r.report.cases.map((c) => [c.slug, c])));
  const extra = [];
  let failedShards = 0;
  for (const r of reports) {
    if (!r.report) { const p = missingReport(r, first.shard.owner); if (p) { failedShards++; extra.push(p); } continue; }
    const failed = r.report.cases.some((c) => c.pass === false);
    if (r.code !== 0 && !failed) { failedShards++; extra.push(`shard ${r.k}: exit ${r.code ?? 'unknown'} with no failed row`); }
  }
  const dirOf = Object.fromEntries(reports.map((r) => [r.k, r.dir]));
  const rows = first.shard.planned.map((p) => {
    const k = first.shard.owner[p.key];
    const got = cases.get(k)?.get(p.slug);
    if (!got) {
      const { key: _key, ...rest } = p;
      return { ...rest, error: `no result from shard ${k}`, status: 'error', mismatchPercent: 100, pass: false };
    }
    if (!got.files || !outDir || !dirOf[k]) return got;
    return { ...got, files: Object.fromEntries(Object.entries(got.files).map(([n, f]) => [n, relative(outDir, join(dirOf[k], f))])) };
  });
  const { shard: _shard, cases: _cases, generatedAt: _at, ...meta } = first;
  return { rows, extra, meta, failedShards };
}
