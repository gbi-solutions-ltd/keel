/**
 * quality-merge.test.mjs: quality-check shard planning, the warning summary and the shard merge
 * (lib/quality-merge.mjs) on synthetic reports. No browser is launched.
 * Run: node --test test/quality-merge.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mergeQualityShards, planQualityShards, qualityMarkdown, screenKey, summariseWarnings, warningLines } from '../lib/quality-merge.mjs';

const VP = [{ name: 'desktop', width: 1440, height: 900 }, { name: 'mobile', width: 390, height: 844 }];
const SCREENS = [
  { name: 'invoices', states: ['default', 'empty', 'error'] },
  { name: 'orders' },
  { name: 'invoice', route: '/invoices/INV-0412', steps: [{ click: 'x' }, { click: 'y' }] },
  { route: '/settings/profile' },
  { name: 'orders', states: ['loading'] },
];

test('plan: deterministic, every case once, screens whole (same key together), cases in run order', () => {
  const a = planQualityShards(SCREENS, VP, 3);
  assert.deepEqual(a, planQualityShards(SCREENS, VP, 3));
  assert.equal(screenKey({ route: '/settings/profile' }), 'settings_profile');
  // 3 + 1 + 1 + 1 + 1 states, 3 cases each (2 viewports and narrow-320)
  assert.equal(a.planned.length, 21);
  assert.equal(new Set(a.planned.map((p) => p.slug)).size, 21);
  assert.deepEqual(a.planned.slice(0, 3).map((p) => p.slug), ['invoices--default--desktop', 'invoices--default--mobile', 'invoices--default--narrow-320']);
  assert.deepEqual(Object.keys(a.owner).sort(), ['invoice', 'invoices', 'orders', 'settings_profile']);
  for (const p of a.planned) assert.ok(a.owner[p.screen] >= 1 && a.owner[p.screen] <= 3);
  // invoices (3 states) and invoice (2 steps, x2 per load) are the heaviest: they land apart
  assert.notEqual(a.owner.invoices, a.owner.invoice);
});

test('plan: more shards than screens leaves shards empty; 1 shard owns all', () => {
  const p = planQualityShards([{ name: 'a' }, { name: 'b' }], VP, 4);
  assert.deepEqual(Object.values(p.owner).sort(), [1, 2]);
  assert.deepEqual(new Set(Object.values(planQualityShards(SCREENS, VP, 1).owner)), new Set([1]));
});

// Synthetic shard reports for a 2-shard plan of SCREENS.
const PLAN = { n: 2, ...planQualityShards(SCREENS, VP, 2) };
const caseFor = (slug, extra = {}) => ({ slug, url: `http://x/${slug}`, failures: [], warnings: [], pass: true, ...extra });
function reportsFor(mutate = () => {}) {
  const reps = [1, 2].map((k) => ({
    k,
    code: 0,
    report: {
      target: 'mockup', app: null, shard: { k, ...PLAN },
      cases: PLAN.planned.filter((p) => PLAN.owner[p.screen] === k).map((p) => caseFor(p.slug)),
    },
  }));
  mutate(reps);
  return reps;
}

test('merge: all present and passing, rows in plan order, measured line, exit 0', () => {
  const m = mergeQualityShards(reportsFor());
  assert.equal(m.error, undefined);
  assert.deepEqual(m.rows.map((r) => r.slug), PLAN.planned.map((p) => p.slug));
  assert.equal(m.summary, '21 of 21 planned cases measured, not measured: 0');
  assert.deepEqual(m.extra, []);
  assert.equal(m.exitCode, 0);
  assert.deepEqual(m.meta, { target: 'mockup', app: null });
});

test('merge: a shard with no report.json leaves its cases not measured, named by shard, exit 1', () => {
  const m = mergeQualityShards(reportsFor((r) => { r[1].report = null; r[1].code = null; }));
  const lost = PLAN.planned.filter((p) => PLAN.owner[p.screen] === 2).length;
  assert.equal(m.summary, `${21 - lost} of 21 planned cases measured, not measured: ${lost}`);
  const row = m.rows.find((r) => r.measured === false);
  assert.deepEqual(row.failures, [{ check: 'shard', detail: 'no result from shard 2' }]);
  assert.equal(row.pass, false);
  assert.deepEqual(m.extra, ['shard 2: no report.json']);
  assert.equal(m.exitCode, 1);
});

test('merge: a shard that exited non-zero with no failed case fails the merge; so does an unknown exit', () => {
  for (const code of [137, null]) {
    const m = mergeQualityShards(reportsFor((r) => { r[0].code = code; }));
    assert.equal(m.summary, '21 of 21 planned cases measured, not measured: 0');
    assert.deepEqual(m.extra, [`shard 1: exit ${code ?? 'unknown'} with no failed case`]);
    assert.equal(m.exitCode, 1);
  }
});

test('merge: a failed case fails the merge; its non-zero shard is not reported as dead', () => {
  const m = mergeQualityShards(reportsFor((r) => {
    r[0].code = 1;
    r[0].report.cases[0] = caseFor(r[0].report.cases[0].slug, { pass: false, failures: [{ check: 'axe', detail: 'color-contrast' }] });
  }));
  assert.equal(m.summary, '21 of 21 planned cases measured, not measured: 0');
  assert.deepEqual(m.extra, []);
  assert.equal(m.exitCode, 1);
});

test('merge: refuses reports of different plans, a non-shard report, a misfiled shard, a wrong count, none at all', () => {
  assert.match(mergeQualityShards(reportsFor((r) => { r[1].report.shard.planned = r[1].report.shard.planned.slice(1); })).error, /planned a different run/);
  assert.match(mergeQualityShards(reportsFor((r) => { r[1].report.app = 'http://localhost:4173'; })).error, /planned a different run/);
  assert.match(mergeQualityShards(reportsFor((r) => { delete r[0].report.shard; })).error, /not written by a --shard run/);
  assert.match(mergeQualityShards(reportsFor((r) => { r[1].report.shard.k = 1; })).error, /read as shard 2 is shard 1's/);
  assert.match(mergeQualityShards(reportsFor((r) => r.pop())).error, /planned as 2, 1 given/);
  assert.match(mergeQualityShards([{ k: 1, report: null, code: null }]).error, /no shard left a report/);
});

test('merge: a shard that owns nothing and left no report is not a problem', () => {
  const plan = { n: 3, ...planQualityShards([{ name: 'a' }, { name: 'b' }], VP, 3) };
  const reps = [1, 2, 3].map((k) => ({ k, code: 0, report: { target: 'mockup', app: null, shard: { k, ...plan }, cases: plan.planned.filter((p) => plan.owner[p.screen] === k).map((p) => caseFor(p.slug)) } }));
  reps[2].report = null;
  const m = mergeQualityShards(reps);
  assert.equal(m.summary, '6 of 6 planned cases measured, not measured: 0');
  assert.equal(m.exitCode, 0);
});

test('merge: an unreadable report.json fails the merge as lib/shard.mjs reads it, owned or not; none readable is an error that says so', () => {
  const m = mergeQualityShards(reportsFor((r) => { r[1].report = null; r[1].unreadable = true; }));
  assert.deepEqual(m.extra, ['shard 2: report.json unreadable']);
  assert.equal(m.exitCode, 1);
  const plan = { n: 3, ...planQualityShards([{ name: 'a' }, { name: 'b' }], VP, 3) };
  const reps = [1, 2, 3].map((k) => ({ k, code: 0, report: { target: 'mockup', app: null, shard: { k, ...plan }, cases: plan.planned.filter((p) => plan.owner[p.screen] === k).map((p) => caseFor(p.slug)) } }));
  Object.assign(reps[2], { report: null, unreadable: true });
  const idle = mergeQualityShards(reps);
  assert.deepEqual(idle.extra, ['shard 3: report.json unreadable'], 'an unreadable report fails even from a shard that owned nothing');
  assert.equal(idle.exitCode, 1);
  assert.match(mergeQualityShards([{ k: 1, report: null, unreadable: true, code: 1 }]).error, /no shard left a readable report\.json \(shard 1: report\.json unreadable\)/);
});

const W = (detail) => ({ check: 'target', detail });
const WCASES = [
  caseFor('a', { warnings: [W('button "Pay" is 32x32'), W('button "Pay" is 32x32'), W('select "Status" is 40x30')] }),
  caseFor('b', { warnings: [W('button "Pay" is 32x32'), { check: 'other', detail: 'x' }] }),
  caseFor('c', { pass: false, failures: [{ check: 'axe', detail: 'image-alt: Images must have alternate text' }] }),
];

test('warnings: summarised by check with counts and the most frequent details', () => {
  assert.deepEqual(summariseWarnings(WCASES), [
    { check: 'target', count: 4, distinct: 2, top: [{ detail: 'button "Pay" is 32x32', count: 3 }, { detail: 'select "Status" is 40x30', count: 1 }] },
    { check: 'other', count: 1, distinct: 1, top: [{ detail: 'x', count: 1 }] },
  ]);
  assert.deepEqual(warningLines(WCASES), ['warnings: target 4 in 2 case(s) (2 distinct)', 'warnings: other 1 in 1 case(s) (1 distinct)']);
  assert.deepEqual(warningLines([caseFor('a')]), []);
});

test('report.md: the summary lists counts and caps details; all lists every distinct warning; failures in full either way', () => {
  const many = [caseFor('a', { warnings: Array.from({ length: 8 }, (_, i) => W(`button "B${i}" is 30x30`)) }), ...WCASES];
  const sum = qualityMarkdown(many, { target: 'mockup', source: 'm' });
  assert.match(sum, /## Warnings, by check/);
  assert.match(sum, /### target: 12 \(10 distinct\)/);
  assert.match(sum, /- 3x button "Pay" is 32x32/);
  assert.match(sum, /- and 5 more/);
  assert.doesNotMatch(sum, /B7/);
  assert.match(sum, /- image-alt: Images must have alternate text/);
  const all = qualityMarkdown(many, { target: 'mockup', source: 'm', warnings: 'all' });
  assert.match(all, /## Warnings\n/);
  for (let i = 0; i < 8; i++) assert.match(all, new RegExp(`- target: button "B${i}" is 30x30`));
  assert.match(all, /- image-alt: Images must have alternate text/);
  assert.doesNotMatch(qualityMarkdown([caseFor('a')], { target: 'mockup', source: 'm' }), /Warnings/);
  // no long dashes in the generated text
  assert.doesNotMatch(sum + all, /[\u2013\u2014]/);
});
