/**
 * baseline-report.mjs: the sorted rows, report.json and report.md of a baseline-mode run
 * (writeBaselineReport) and of an app-mode run (writeAppReport), shared by visual-diff.mjs and
 * merge-shards.mjs so a merged sharded run writes what a serial run writes.
 *
 * Both take the run's unused expected-diffs entries (lib/expected-diffs.mjs unusedEntries) as
 * json.unusedExpected: written to report.json under that key and to report.md as a warning section.
 */
import { existsSync, readdirSync, realpathSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, dirname, join, relative, resolve, sep } from 'node:path';
import { formatUnused, missingBaselineLines, summarise } from './expected-diffs.mjs';
import { measuredLine } from './shard.mjs';

function unusedSection(unused, maxMismatchPercent) {
  if (!unused || !unused.length) return '';
  return `\n## Expected-diffs entries not needed\n\nA warning only: the exit status is unchanged. Drop or tighten these entries.\n\n${formatUnused(unused, maxMismatchPercent).slice(1).map((l) => `- ${l.trim()}`).join('\n')}\n`;
}

/** The real path of p, or of its nearest existing parent with the rest appended (p may not exist yet). */
function real(p) {
  let head = resolve(p), tail = '';
  while (!existsSync(head) && dirname(head) !== head) { tail = join(basename(head), tail); head = dirname(head); }
  try { return join(realpathSync(head), tail); } catch { return resolve(p); }
}
const within = (dir, parent) => dir === parent || dir.startsWith(parent.endsWith(sep) ? parent : parent + sep);

/** True when dir, or a folder up to depth levels below it, holds a .git entry. */
function holdsGit(dir, depth) {
  if (existsSync(join(dir, '.git'))) return true;
  if (depth <= 0) return false;
  let names;
  try { names = readdirSync(dir, { withFileTypes: true }); } catch { return false; }
  return names.some((d) => d.isDirectory() && d.name !== 'node_modules' && holdsGit(join(dir, d.name), depth - 1));
}

/**
 * Why outDir must not be emptied, or null: the one guard for every --out a run empties first
 * (visual-diff.mjs baseline mode, dom-oracle.mjs, gate-sharded.sh's OUT): it is, or contains, the mockup folder, the current folder or the home folder, or it is a
 * git root or holds one up to two levels down. Any other folder, an earlier run's included, is fine.
 */
export function outDirRefusal(outDir, { mockupDir, cwd = process.cwd(), home = homedir() } = {}) {
  const out = real(outDir);
  const named = [['the mockup folder', mockupDir], ['the current folder', cwd], ['the home folder', home]].filter(([, p]) => p).map(([what, p]) => [what, real(p)]);
  for (const [what, p] of named) if (out === p) return `--out ${out} is ${what}; it would be deleted`;
  if (existsSync(join(out, '.git'))) return `--out ${out} is a git root; it would be deleted`;
  for (const [what, p] of named) if (within(p, out)) return `--out ${out} contains ${what} (${p}); it would be deleted`;
  if (existsSync(out) && holdsGit(out, 2)) return `--out ${out} contains a git repository; it would be deleted`;
  return null;
}

const RANK = { error: 0, fail: 1, 'size-mismatch': 2, expected: 3, pass: 4, skipped: 5, 'no-baseline': 6 };

/** Worst first, then by mismatch, then by slug (in place; returns rows). */
export function sortRows(rows) {
  return rows.sort((x, y) => RANK[x.status] - RANK[y.status] || (y.mismatchPercent ?? 0) - (x.mismatchPercent ?? 0) || (x.slug < y.slug ? -1 : 1));
}

/**
 * Sorts rows, writes <outDir>/report.json and report.md, and returns the summary's last line.
 * meta: { baseline, expectedFile, expected, maxMismatchPercent, clock, seed, allowMissingBaseline };
 * extra fields of report.json (a shard's plan) go in json. The no-baseline cases get a section of
 * their own in report.md (lib/expected-diffs.mjs missingBaselineLines).
 */
export function writeBaselineReport(outDir, rows, { baseline, expectedFile, expected, maxMismatchPercent, clock, seed, allowMissingBaseline = false }, json = {}) {
  sortRows(rows);
  const summary = summarise(rows);
  writeFileSync(join(outDir, 'report.json'), JSON.stringify({ generatedAt: new Date().toISOString(), baseline, expected: expectedFile, maxMismatch: maxMismatchPercent, clock: clock ?? null, seed, allowMissingBaseline, ...json, summary: summary.split('\n').pop(), cases: rows }, null, 1));
  let md = `# Baseline diff report\n\nBaseline: ${baseline} · expected-diffs: ${expectedFile ?? 'none'} · threshold: ${maxMismatchPercent}%\n\n${summary.split('\n').pop()}\n\n`;
  md += `| | Case | Status | Mismatch | Size (baseline → capture) | Reason |\n|---|---|---|---|---|---|\n`;
  for (const c of rows.filter((x) => !['pass', 'skipped', 'no-baseline'].includes(x.status))) {
    const entry = c.status === 'expected' ? ((expected && expected.screens) || []).find((s) => s.name === c.name && (s.viewport === c.viewport || s.viewport === '*') && (s.state === undefined || s.state === c.state)) : null;
    const reason = (entry ? entry.reason : c.error || '').replace(/\|/g, '\\|');
    md += `| ${c.status === 'expected' ? '~' : '✗'} | ${c.slug} | ${c.status} | ${c.mismatchPercent !== null ? `${c.mismatchPercent}%` : 'n/a'} | ${c.size ? `${c.size.baseline} → ${c.size.actual}${c.size.declared ? ` (declared ${c.size.declared})` : ''}` : ''} | ${reason} |\n`;
  }
  const missing = missingBaselineLines(rows, { allowMissingBaseline });
  if (missing.length) md += `\n## No baseline PNG\n\n${missing[0].replace(/^\w+: /, '')}\n\n${missing.slice(1).map((l) => `- ${l.trim()}`).join('\n')}\n`;
  md += unusedSection(json.unusedExpected, maxMismatchPercent);
  writeFileSync(join(outDir, 'report.md'), md);
  return summary.split('\n').pop();
}

/**
 * App mode: sorts cases (worst mismatch first, stable, so pass plan order in), writes
 * <outDir>/report.json and report.md, and returns { failed, passing, measured }: passing is the
 * `X/Y passing (...)` text of the serial run's last line, measured the measuredLine result.
 * meta: { appBase, maxMismatch, expectedFile }; json: extra report.json fields (a shard's plan,
 * unusedExpected, shardProblems).
 */
export function writeAppReport(outDir, cases, { appBase, maxMismatch, expectedFile }, json = {}) {
  cases.sort((x, y) => y.mismatchPercent - x.mismatchPercent);
  const failed = cases.filter((c) => !c.pass);
  const expectedCount = cases.filter((c) => c.status === 'expected').length;
  const expectedNote = expectedFile ? ` (${expectedCount} expected, ${relative(outDir, expectedFile)})` : '';
  const measured = measuredLine(cases);
  writeFileSync(join(outDir, 'report.json'), JSON.stringify({ generatedAt: new Date().toISOString(), appBase, maxMismatch, expectedFile, ...json, measured: measured.line, cases }, null, 2));

  let md = `# Visual diff report\n\nApp: ${appBase} · threshold: ${maxMismatch}% · ${cases.length - failed.length}/${cases.length} passing${expectedNote}\n\n${measured.line}\n\n`;
  for (const l of json.shardProblems || []) md += `- ${l}\n`;
  if ((json.shardProblems || []).length) md += '\n';
  md += `| | Case | Mismatch | Size (mockup → app) | Component issues |\n|---|---|---|---|---|\n`;
  for (const c of cases) {
    md += `| ${c.status === 'expected' ? '~' : c.pass ? '✓' : '✗'} | ${c.slug} | ${c.error ? 'ERROR' : `${c.mismatchPercent}%`} | ${c.size ? `${c.size.mockup} → ${c.size.app}` : 'n/a'} | ${c.error ? c.error : c.componentIssues.length} |\n`;
  }
  for (const c of failed.filter((x) => !x.error)) {
    md += `\n## ${c.slug}: ${c.mismatchPercent}%\n\nDiff: \`${c.files.diff}\` · mockup: \`${c.files.mockup}\` · app: \`${c.files.app}\`\n\n`;
    if (c.componentIssues.length > 1) md += `Issues are in DOM order. Fix the first one with a size (w/h) change first: later y-only shifts usually cascade from it.\n\n`;
    md += c.componentIssues.length ? c.componentIssues.map((i) => `- **${i.component}**: ${i.issue}`).join('\n') + '\n' : '- No component box differences; look at colour, typography or content in diff.png\n';
  }
  md += unusedSection(json.unusedExpected, maxMismatch);
  writeFileSync(join(outDir, 'report.md'), md);
  return { failed: failed.length, passing: `${cases.length - failed.length}/${cases.length} passing${expectedNote}`, measured };
}
