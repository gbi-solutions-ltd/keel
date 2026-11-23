/**
 * quality-merge.mjs: shard planning, the report writer and the shard merge for quality-check.mjs.
 * No browser here: quality-check.mjs and merge-shards.mjs both import it.
 *
 * Planning (--shard K/N): the unit is a screen key (the slug base: screen.name, else the route as
 * slugFor makes it), so one screen's states and viewports stay in one shard, and screens sharing a
 * name stay together. Balanced with lpt from lib/shard.mjs. Weight, in rough page loads: per state,
 * 1 per config viewport, plus 0.25 for the 320px overflow pass, plus 0.5 per config step for each
 * of those loads.
 *
 * Merge rules (mergeQualityShards): every shard's report.json carries the whole plan, so the cases
 * of a shard that died are still known; a planned case no shard reported is a fail ("no result from
 * shard K"), never a silent pass; a shard that exits non-zero (or left no exit status) with no failed
 * case fails the merge too.
 */
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { lpt, missingReport, noReportError } from './shard.mjs';
import { screenKey, slugFor } from './screens.mjs';

export const NARROW = { name: 'narrow-320', width: 320, height: 640 };

/** The slug base a screen's cases share, the shard key: lib/screens.mjs's, re-exported. */
export { screenKey };

/** Rough page loads one screen costs: per state, viewports + 0.25, times (1 + 0.5 per step). */
export function screenWeight(screen, viewportCount) {
  const states = (screen.states || ['default']).length;
  return states * (viewportCount + 0.25) * (1 + 0.5 * (screen.steps || []).length);
}

/**
 * screens: the screens this run covers (after --screen), in config order; viewports: the config's.
 * Returns { owner: {screenKey: K}, planned: [{ slug, screen }] } with planned in run order (screen,
 * state, viewport, then narrow-320), the same order a serial run writes its cases.
 */
export function planQualityShards(screens, viewports, n) {
  const byKey = new Map();
  for (const s of screens) {
    const key = screenKey(s);
    const it = byKey.get(key) || { key, weight: 0 };
    it.weight += screenWeight(s, viewports.length);
    byKey.set(key, it);
  }
  const owner = {};
  lpt([...byKey.values()], n).forEach((bin, i) => { for (const it of bin.items) owner[it.key] = i + 1; });
  const planned = [];
  for (const s of screens) {
    for (const state of s.states || ['default']) {
      for (const vp of [...viewports, NARROW]) planned.push({ slug: slugFor(s, state, vp.name), screen: screenKey(s) });
    }
  }
  return { owner, planned };
}

/**
 * Warnings across cases, by check: [{ check, count, distinct, top: [{ detail, count }] }], checks
 * by count (highest first), top the `topN` most frequent details.
 */
export function summariseWarnings(cases, topN = 5) {
  const byCheck = new Map();
  for (const c of cases) {
    for (const w of c.warnings || []) {
      const m = byCheck.get(w.check) || new Map();
      m.set(w.detail, (m.get(w.detail) || 0) + 1);
      byCheck.set(w.check, m);
    }
  }
  return [...byCheck.entries()].map(([check, m]) => {
    const details = [...m.entries()].map(([detail, count]) => ({ detail, count })).sort((a, b) => b.count - a.count);
    return { check, count: details.reduce((s, d) => s + d.count, 0), distinct: details.length, top: details.slice(0, topN) };
  }).sort((a, b) => b.count - a.count || (a.check < b.check ? -1 : 1));
}

/** One line per check: `warnings: target 28000 in 312 cases (40 distinct)`. Empty when none. */
export function warningLines(cases) {
  return summariseWarnings(cases, 0).map((w) => {
    const inCases = cases.filter((c) => (c.warnings || []).some((x) => x.check === w.check)).length;
    return `warnings: ${w.check} ${w.count} in ${inCases} case(s) (${w.distinct} distinct)`;
  });
}

/** The report.md text. warnings: 'summary' (by check, counts, top 5) or 'all' (every distinct warning). */
export function qualityMarkdown(cases, { target, source, warnings = 'summary', extra = [], summary } = {}) {
  const failed = cases.filter((c) => !c.pass);
  let md = `# Quality check: ${target}\n\n${source} | ${cases.length - failed.length}/${cases.length} passing\n\n`;
  if (summary) md += `${summary}\n\n`;
  if (extra.length) md += `## Shard problems\n\n${extra.map((l) => `- ${l}`).join('\n')}\n\n`;
  const byCheck = {};
  for (const c of cases) for (const f of c.failures) (byCheck[f.check] ||= new Set()).add(f.detail);
  md += Object.keys(byCheck).length ? '## Failures, deduplicated\n\n' + Object.entries(byCheck).map(([k, v]) => `### ${k}\n\n${[...v].map((d) => `- ${d}`).join('\n')}`).join('\n\n') + '\n\n' : 'No failures.\n\n';
  if (warnings === 'all') {
    const warns = new Set(cases.flatMap((c) => (c.warnings || []).map((w) => `${w.check}: ${w.detail}`)));
    if (warns.size) md += `## Warnings\n\n${[...warns].map((w) => `- ${w}`).join('\n')}\n\n`;
  } else {
    const sum = summariseWarnings(cases);
    if (sum.length) {
      md += '## Warnings, by check\n\nEvery warning is in report.json; `--warnings all` lists them here.\n\n';
      md += sum.map((w) => `### ${w.check}: ${w.count} (${w.distinct} distinct)\n\n${w.top.map((t) => `- ${t.count}x ${t.detail}`).join('\n')}${w.distinct > w.top.length ? `\n- and ${w.distinct - w.top.length} more` : ''}`).join('\n\n') + '\n\n';
    }
  }
  md += `## Cases\n\n| | Case | Failures |\n|---|---|---|\n${cases.map((c) => `| ${c.pass ? '✓' : '✗'} | ${c.slug} | ${c.failures.map((f) => f.check).join(', ')} |`).join('\n')}\n`;
  return md;
}

/** Writes report.json and report.md to outDir. meta: { target, source, app, warnings, shard, extra, summary }. */
export function writeQualityReport(outDir, cases, meta) {
  const { warnings, source, extra, summary, ...head } = meta;
  const json = { generatedAt: new Date().toISOString(), ...head, cases };
  if (summary) json.summary = summary;
  if (extra?.length) json.shardProblems = extra;
  writeFileSync(join(outDir, 'report.json'), JSON.stringify(json, null, 2));
  writeFileSync(join(outDir, 'report.md'), qualityMarkdown(cases, { target: meta.target, source, warnings, extra, summary }));
}

/**
 * The quality rows of N shards (quality-check --shard K/N --out <dir>/quality-K).
 *   reports: [{ k, report, code, unreadable? }]: report is shard K's parsed report.json (null when it
 *            left none, or one that does not parse: then unreadable is true), code its exit status
 *            (null when unknown). Missing and unreadable reports are read as lib/shard.mjs reads them
 *            (missingReport): an unreadable one always fails the merge, a missing one when it owned cases.
 * Returns { error } when no shard left a report, a report was not written by a --shard run, or the
 * shards disagree on the plan; else { rows, extra, summary, exitCode, meta }:
 *   rows     every planned case in run order; one no shard reported is
 *            { slug, url: null, failures: [{ check: 'shard', detail: 'no result from shard K' }], warnings: [], pass: false, measured: false }
 *   extra    a line per shard problem (no report.json, report.json unreadable, exit non-zero with no failed case)
 *   summary  `X of Y planned cases measured, not measured: M`
 *   exitCode 1 when M > 0, a shard died, or any case failed; else 0
 *   meta     { target, app } of the first report
 */
export function mergeQualityShards(reports) {
  const present = reports.filter((r) => r.report);
  if (!present.length) return { error: noReportError(reports) };
  for (const r of present) if (!r.report.shard) return { error: `shard ${r.k}'s report.json was not written by a --shard run` };
  const first = present[0].report;
  const n = first.shard.n;
  const planKey = (rep) => JSON.stringify([rep.target, rep.app ?? null, rep.shard.n, rep.shard.planned, rep.shard.owner]);
  for (const r of present) {
    if (r.report.shard.k !== r.k) return { error: `the report.json read as shard ${r.k} is shard ${r.report.shard.k}'s` };
    if (planKey(r.report) !== planKey(first)) return { error: `shard ${r.k} planned a different run from shard ${present[0].k} (other inputs or flags)` };
  }
  if (reports.length !== n) return { error: `the shards were planned as ${n}, ${reports.length} given` };
  const got = new Map(); // k -> Map(slug -> case)
  for (const r of present) got.set(r.k, new Map(r.report.cases.map((c) => [c.slug, c])));
  const extra = [];
  let died = 0;
  for (const r of reports) {
    if (!r.report) { const p = missingReport(r, first.shard.owner); if (p) { died++; extra.push(p); } continue; }
    const failed = r.report.cases.some((c) => !c.pass);
    if (r.code !== 0 && !failed) { died++; extra.push(`shard ${r.k}: exit ${r.code ?? 'unknown'} with no failed case`); }
  }
  let missing = 0;
  const rows = first.shard.planned.map((p) => {
    const k = first.shard.owner[p.screen];
    const c = got.get(k)?.get(p.slug);
    if (c) return c;
    missing++;
    return { slug: p.slug, url: null, failures: [{ check: 'shard', detail: `no result from shard ${k}` }], warnings: [], pass: false, measured: false };
  });
  const summary = `${rows.length - missing} of ${rows.length} planned cases measured, not measured: ${missing}`;
  const anyFail = rows.some((r) => !r.pass);
  return { rows, extra, summary, exitCode: missing || died || anyFail ? 1 : 0, meta: { target: first.target, app: first.app ?? null } };
}
