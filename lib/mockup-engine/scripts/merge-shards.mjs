#!/usr/bin/env node
/**
 * merge-shards.mjs: merge the output of N shard processes (--shard K/N) into what one serial run
 * prints and writes.
 *
 * Behaviours (check-behaviours.mjs --shard K/N, stdout of shard K in <dir>/beh-K.out, its exit
 * status in <dir>/beh-K.code):
 *   node merge-shards.mjs behaviours --dir <dir> --shards N --mockup <mockup-dir> [--file <behaviours.json>] [--only <prefixes>]
 *   Pass the --mockup, --file and --only the shards ran with: the plan is computed again from them.
 *   The shards' --tz is accepted too (gate-sharded.sh passes BEH_ARGS to the shards and the merge
 *   alike) and changes nothing here.
 *   Prints the rows in file order and `X/Y behaviours ok`, and writes them to <dir>/behaviours.txt.
 *
 * Baseline diff (visual-diff.mjs --baseline ... --shard K/N --out <dir>/diff-K, its exit status in
 * <dir>/diff-K.code):
 *   node merge-shards.mjs diff --dir <dir> --shards N [--out <merged-dir>]
 *   Writes report.json and report.md to --out (default <dir>/diff) and prints the summary line.
 *   The plan comes from the shards' own report.json files, which must agree.
 *   With an expected-diffs file, the entries the merged run did not need are printed as a warning
 *   after the summary and written to the report (as a serial run does; the exit status is unchanged).
 *   A planned no-baseline case fails the merge and is listed, unless the shards ran with
 *   --allow-missing-baseline (recorded in their report.json): then it is listed as a warning.
 *
 * App diff (visual-diff.mjs --app ... --shard K/N --out <dir>/app-K, its exit status in
 * <dir>/app-K.code):
 *   node merge-shards.mjs app --dir <dir> --shards N [--out <merged-dir>]
 *   A subcommand of its own, since an app report has another shape from a baseline one. Writes the
 *   report.json and report.md a serial app run writes to --out (default <dir>/app; case file paths
 *   point into the shard folders), prints any shard problem, then
 *   `X of N planned captures measured, not measured: M`, the unused expected-diffs warning, and
 *   `X/Y passing`. Exit 1 when a case fails or errors, M > 0, or a shard died (no report.json
 *   while it owned cases, or a non-zero exit with no failed row, or no exit status); 2 when the
 *   shards planned no case.
 *
 * Quality check (quality-check.mjs ... --shard K/N --out <dir>/quality-K, its exit status in
 * <dir>/quality-K.code):
 *   node merge-shards.mjs quality --dir <dir> --shards N [--out <merged-dir>] [--mockup <dir>] [--warnings all]
 *   Writes the report a serial quality run writes to --out (default <dir>/quality), prints the
 *   warning summary, `X/Y passing` and `X of N planned cases measured, not measured: M`. Exit 1 when
 *   a case fails, M > 0, or a shard died (lib/quality-merge.mjs).
 *
 * A unit no shard reported is a fail ("no result from shard K"); a shard that exited non-zero with no
 * failed row, or left no exit status, fails the merge, as does a report.json that does not parse
 * ("shard K: report.json unreadable"). Exit 1 on any fail, as the serial run would. Exit 2 when the
 * merge cannot run (lib/args.mjs's rule): a bad argument (an unknown flag or subcommand, no --dir,
 * a --shards that is not an integer >= 1), a behaviours file missing or not JSON, an --only that
 * matches nothing, no readable shard report, shards that planned different runs or another shard
 * count, a plan with no case; and on a crash.
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join, resolve, relative } from 'node:path';
import { pathToFileURL } from 'node:url';
import { exitCodeFor, formatUnused, missingBaselineLines, unusedEntries } from './lib/expected-diffs.mjs';
import { writeAppReport, writeBaselineReport } from './lib/baseline-report.mjs';
import { mergeAppShards, mergeBehaviourShards, mergeDiffShards, planBehaviourShards } from './lib/shard.mjs';
import { selectBehaviours } from './check-behaviours.mjs';
import { mergeQualityShards, warningLines, writeQualityReport } from './lib/quality-merge.mjs';
import { cli, usageError } from './lib/args.mjs';

const readIf = (p) => (existsSync(p) ? readFileSync(p, 'utf8') : null);
/** A shard's report.json: { report } (null when there is none), or { report: null, unreadable: true } when it does not parse (a shard killed mid-write). */
function readReport(p) {
  const t = readIf(p);
  if (t === null) return { report: null };
  try { return { report: JSON.parse(t) }; } catch { return { report: null, unreadable: true }; }
}
const codeOf = (p) => { const t = readIf(p); return t === null || !/^\d+$/.test(t.trim()) ? null : Number(t.trim()); };

function behaviours(a) {
  const mockupDir = resolve(a.mockup || '.');
  const file = resolve(a.file || join(mockupDir, 'docs', 'behaviours.json'));
  const only = (a.only || '').split(',').map((s) => s.trim()).filter(Boolean);
  let entries;
  try { entries = JSON.parse(readFileSync(file, 'utf8')); } catch (e) { console.error(`error: ${file} ${existsSync(file) ? `is not valid JSON: ${e.message}` : 'does not exist'}`); return 2; }
  const sel = selectBehaviours(entries, only, basename(file));
  if (sel.error) { console.error(sel.error); return 2; }
  const shards = planBehaviourShards(sel.list, a.shards).map((list) => list.map((b) => b.id));
  const outputs = shards.map((_, i) => ({ k: i + 1, text: readIf(join(a.dir, `beh-${i + 1}.out`)), code: codeOf(join(a.dir, `beh-${i + 1}.code`)) }));
  const m = mergeBehaviourShards({ shards, order: sel.list.map((b) => b.id), outputs });
  const text = m.lines.join('\n') + '\n';
  writeFileSync(join(a.dir, 'behaviours.txt'), text);
  process.stdout.write(text);
  return m.exitCode;
}

function diff(a) {
  const reports = Array.from({ length: a.shards }, (_, i) => {
    return { k: i + 1, ...readReport(join(a.dir, `diff-${i + 1}`, 'report.json')), code: codeOf(join(a.dir, `diff-${i + 1}.code`)) };
  });
  const m = mergeDiffShards(reports);
  if (m.error) { console.error(`error: ${m.error}`); return 2; }
  const out = resolve(a.out || join(a.dir, 'diff'));
  mkdirSync(out, { recursive: true });
  const expectedFile = m.meta.expected;
  const expected = expectedFile && existsSync(expectedFile) ? JSON.parse(readFileSync(expectedFile, 'utf8')) : null;
  const cover = reports.find((r) => r.report)?.report.shard.expectedCover;
  const unused = expected && cover ? unusedEntries(expected, m.rows, { maxMismatchPercent: m.meta.maxMismatch, cover }) : null;
  const json = { ...(m.extra.length ? { shardProblems: m.extra } : {}), ...(unused ? { unusedExpected: unused } : {}) };
  const allowMissingBaseline = m.meta.allowMissingBaseline === true;
  const summary = writeBaselineReport(out, m.rows, { baseline: m.meta.baseline, expectedFile, expected, maxMismatchPercent: m.meta.maxMismatch, clock: m.meta.clock, seed: m.meta.seed, allowMissingBaseline }, json);
  for (const l of m.extra) console.log(l);
  console.log(summary);
  for (const l of missingBaselineLines(m.rows, { allowMissingBaseline })) console.log(l);
  for (const l of formatUnused(unused || [], m.meta.maxMismatch)) console.log(l);
  console.log(`-> ${relative(process.cwd(), out)}/report.md`);
  return exitCodeFor(m.rows, { allowMissingBaseline }) || (m.failedShards || m.extra.length ? 1 : 0);
}

function app(a) {
  const reports = Array.from({ length: a.shards }, (_, i) => {
    const dir = join(a.dir, `app-${i + 1}`);
    return { k: i + 1, dir, ...readReport(join(dir, 'report.json')), code: codeOf(join(a.dir, `app-${i + 1}.code`)) };
  });
  const out = resolve(a.out || join(a.dir, 'app'));
  const m = mergeAppShards(reports, { outDir: out });
  if (m.error) { console.error(`error: ${m.error}`); return 2; }
  mkdirSync(out, { recursive: true });
  const expectedFile = m.meta.expectedFile;
  const expected = expectedFile && existsSync(expectedFile) ? JSON.parse(readFileSync(expectedFile, 'utf8')) : null;
  const cover = reports.find((r) => r.report)?.report.shard.expectedCover;
  const unused = expected && cover ? unusedEntries(expected, m.rows, { maxMismatchPercent: m.meta.maxMismatch, cover }) : null;
  const json = { ...(m.extra.length ? { shardProblems: m.extra } : {}), ...(unused ? { unusedExpected: unused } : {}) };
  const r = writeAppReport(out, m.rows, { appBase: m.meta.appBase, maxMismatch: m.meta.maxMismatch, expectedFile }, json);
  for (const l of m.extra) console.log(l);
  console.log(r.measured.line);
  for (const l of formatUnused(unused || [], m.meta.maxMismatch)) console.log(l);
  console.log(`${r.passing} -> ${relative(process.cwd(), out)}/report.md`);
  return r.failed || r.measured.notMeasured || m.failedShards || m.extra.length ? 1 : 0;
}

function quality(a) {
  const reports = Array.from({ length: a.shards }, (_, i) => ({ k: i + 1, ...readReport(join(a.dir, `quality-${i + 1}`, 'report.json')), code: codeOf(join(a.dir, `quality-${i + 1}.code`)) }));
  const m = mergeQualityShards(reports);
  if (m.error) { console.error(`error: ${m.error}`); return 2; }
  const out = resolve(a.out || join(a.dir, 'quality'));
  mkdirSync(out, { recursive: true });
  const source = m.meta.app || (a.mockup ? relative(process.cwd(), resolve(a.mockup)) : 'sharded run');
  writeQualityReport(out, m.rows, { ...m.meta, source, warnings: a.warnings === 'all' ? 'all' : 'summary', summary: m.summary, extra: m.extra });
  for (const l of [...m.extra, ...warningLines(m.rows)]) console.log(l);
  console.log(`${m.rows.filter((row) => row.pass).length}/${m.rows.length} passing\n${m.summary}\n-> ${relative(process.cwd(), out)}/report.md`);
  return m.exitCode;
}

async function main() {
  const { values: a, positional: [cmd] } = cli('merge-shards');
  const bad = (msg) => usageError('merge-shards', msg);
  if (!['behaviours', 'diff', 'app', 'quality'].includes(cmd)) bad(`unknown subcommand ${cmd}: want behaviours, diff, app or quality`);
  if (!a.dir) bad('--dir is required');
  if (a.shards === undefined) bad('--shards is required');
  const n = Number(a.shards);
  if (!/^\d+$/.test(a.shards) || n < 1) bad(`--shards ${a.shards}: want an integer >= 1`);
  a.shards = n;
  return cmd === 'behaviours' ? behaviours(a) : cmd === 'diff' ? diff(a) : cmd === 'app' ? app(a) : quality(a);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) process.exitCode = await main();
