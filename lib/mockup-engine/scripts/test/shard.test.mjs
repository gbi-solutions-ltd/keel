/**
 * shard.test.mjs: shard planning and merging (lib/shard.mjs) and the merge-shards.mjs CLI on
 * synthetic shard output. No browser is launched.
 * Run: node --test test/shard.test.mjs   (from scripts/)
 */
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PNG } from 'pngjs';
import { behaviourWeight, lpt, mergeBehaviourShards, mergeDiffShards, parseShard, planBehaviourShards, planDiffShards, pngMegapixels } from '../lib/shard.mjs';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'shard-'));
after(() => rmSync(TMP, { recursive: true, force: true }));

test('parseShard accepts K/N with 1 <= K <= N and refuses the rest', () => {
  assert.deepEqual(parseShard('2/3'), { k: 2, n: 3 });
  assert.deepEqual(parseShard('1/1'), { k: 1, n: 1 });
  for (const bad of ['0/3', '4/3', '3', 'a/b', '1/0', undefined, '']) assert.match(parseShard(bad).error, /--shard must be K\/N/, String(bad));
});

test('lpt: the heaviest item goes to the lightest shard, ties to the earlier item and lower shard, order kept in a shard', () => {
  const items = [{ key: 'a', weight: 1 }, { key: 'b', weight: 5 }, { key: 'c', weight: 3 }, { key: 'd', weight: 3 }, { key: 'e', weight: 2 }];
  const bins = lpt(items, 2);
  // b(5) -> 0; c(3) -> 1; d(3) -> 1 (3 < 5); e(2) -> 0 (5 < 6); a(1) -> 1 (6 < 7): loads 7 and 7
  assert.deepEqual(bins.map((b) => b.items.map((i) => i.key)), [['b', 'e'], ['a', 'c', 'd']]);
  assert.deepEqual(bins.map((b) => b.load), [7, 7]);
  // more shards than items: n bins, the extra ones empty
  assert.deepEqual(lpt(items.slice(0, 2), 4).map((b) => b.items.length), [1, 1, 0, 0]);
});

test('behaviour weight: 1 per load, 1 per step, wait ms / 700, typed chars x 30 / 700', () => {
  assert.equal(behaviourWeight({ id: 'x' }), 1);
  assert.equal(behaviourWeight({ steps: [{ click: {} }, { wait: 700 }] }), 4);
  assert.equal(behaviourWeight({ steps: [{ type: 'abcdefg' }] }), 2 + (7 * 30) / 700);
});

test('planBehaviourShards covers every entry exactly once, in file order within each shard', () => {
  const list = Array.from({ length: 23 }, (_, i) => ({ id: `b${i}`, steps: Array.from({ length: i % 4 }, () => ({ wait: 100 * i })) }));
  const shards = planBehaviourShards(list, 4);
  assert.equal(shards.length, 4);
  const ids = shards.flat().map((b) => b.id);
  assert.deepEqual([...ids].sort(), list.map((b) => b.id).sort());
  for (const s of shards) assert.deepEqual(s.map((b) => b.id), list.filter((b) => s.includes(b)).map((b) => b.id));
  // balanced: no shard over the lightest by more than the heaviest entry
  const loads = shards.map((s) => s.reduce((t, b) => t + behaviourWeight(b), 0));
  assert.ok(Math.max(...loads) - Math.min(...loads) <= Math.max(...list.map(behaviourWeight)));
});

test('pngMegapixels reads the IHDR; an unreadable file is 0', () => {
  const f = join(TMP, 'a.png');
  writeFileSync(f, PNG.sync.write(new PNG({ width: 1000, height: 2000 })));
  assert.equal(pngMegapixels(f), 2);
  assert.equal(pngMegapixels(join(TMP, 'missing.png')), 0);
});

test('planDiffShards weighs per name (1 per case + megapixels + 0.5 per step) and never splits a name', () => {
  const mp = { 'big.png': 10, 'small.png': 0.5 };
  const jobs = [
    { name: 'big', png: 'big.png', steps: [] }, { name: 'big', png: 'big.png', steps: [] }, // 22
    { name: 'mid', png: 'small.png', steps: [{}, {}, {}, {}] }, // 3.5
    { name: 'tiny', png: 'small.png' }, // 1.5
    { name: 'mid2', png: 'small.png', steps: [{}, {}, {}, {}, {}, {}] }, // 4.5
  ];
  const shards = planDiffShards(jobs, 2, (p) => mp[p]);
  assert.deepEqual(shards.map((s) => [...s]), [['big'], ['mid', 'tiny', 'mid2']]);
});

test('mergeBehaviourShards: rows back in file order, a missing row fails as no result, a crash with no failed row fails', () => {
  const shards = [['a', 'c'], ['b', 'd']];
  const order = ['a', 'b', 'c', 'd'];
  const ok = mergeBehaviourShards({ shards, order, outputs: [
    { k: 1, text: 'a: ok\nc: ok\n2/2 behaviours ok\n', code: 0 },
    { k: 2, text: 'b: ok\nd: fail: text "x" not found\n1/2 behaviours ok\n', code: 1 },
  ] });
  assert.deepEqual(ok.lines, ['a: ok', 'b: ok', 'c: ok', 'd: fail: text "x" not found', '3/4 behaviours ok']);
  assert.equal(ok.exitCode, 1);

  const lost = mergeBehaviourShards({ shards, order, outputs: [{ k: 1, text: 'a: ok\n', code: 1 }, { k: 2, text: 'b: ok\nd: ok\n2/2 behaviours ok', code: 0 }] });
  assert.deepEqual(lost.lines, ['a: ok', 'b: ok', 'c: fail: no result from shard 1', 'd: ok', '3/4 behaviours ok']);
  assert.equal(lost.exitCode, 1);

  const crashed = mergeBehaviourShards({ shards, order, outputs: [{ k: 1, text: 'a: ok\nc: ok\n2/2 behaviours ok', code: 134 }, { k: 2, text: 'b: ok\nd: ok\n', code: 0 }] });
  assert.equal(crashed.lines.at(-1), '4/4 behaviours ok');
  assert.ok(crashed.lines.includes('shard 1: exit 134 with no failed row'));
  assert.equal(crashed.exitCode, 1);

  const clean = mergeBehaviourShards({ shards: [['a:b', 'a'], []], order: ['a', 'a:b'], outputs: [{ k: 1, text: 'a:b: ok\na: ok\n', code: 0 }] });
  assert.deepEqual(clean.lines, ['a: ok', 'a:b: ok', '2/2 behaviours ok']); // an id with ": " lookalikes still matches whole
  assert.equal(clean.exitCode, 0);
});

/**
 * A shard report as visual-diff --baseline --shard K/N writes it. Run with --allow-missing-baseline,
 * so the planned no-baseline row is listed and does not fail (test/diff-guards.test.mjs has the default).
 */
function shardReport(k, n, owner, planned, cases) {
  return { generatedAt: 'x', baseline: '/b', expected: null, maxMismatch: 0.2, clock: null, seed: null, allowMissingBaseline: true, shard: { k, n, owner, planned }, summary: 's', cases };
}
const planned = [
  { slug: 'a--default--desktop', name: 'a', state: 'default', viewport: 'desktop', status: 'compared' },
  { slug: 'b--default--desktop', name: 'b', state: 'default', viewport: 'desktop', status: 'compared' },
  { slug: 'c--default--desktop', name: 'c', state: 'default', viewport: 'desktop', status: 'no-baseline' },
  { slug: 'd-tour--default--desktop', name: 'd-tour', state: 'default', viewport: 'desktop', status: 'skipped' },
];
const owner = { a: 1, b: 2 };
const row = (name, status, mismatchPercent) => ({ slug: `${name}--default--desktop`, name, state: 'default', viewport: 'desktop', mismatchPercent, status });

test('mergeDiffShards: every planned row once, a shard that died is a fail per row, plans must agree', () => {
  const both = mergeDiffShards([
    { k: 1, report: shardReport(1, 2, owner, planned, [row('a', 'pass', 0)]), code: 0 },
    { k: 2, report: shardReport(2, 2, owner, planned, [row('b', 'expected', 1.2)]), code: 0 },
  ]);
  assert.deepEqual(both.rows.map((r) => `${r.name}:${r.status}`), ['a:pass', 'b:expected', 'c:no-baseline', 'd-tour:skipped']);
  assert.deepEqual(both.extra, []);
  assert.equal(both.meta.baseline, '/b');

  const died = mergeDiffShards([{ k: 1, report: shardReport(1, 2, owner, planned, [row('a', 'pass', 0)]), code: 0 }, { k: 2, report: null, code: 1 }]);
  assert.deepEqual(died.rows[1], { ...row('b', 'fail', null), error: 'no result from shard 2' });
  assert.deepEqual(died.extra, ['shard 2: no report.json']);

  const crashed = mergeDiffShards([{ k: 1, report: shardReport(1, 2, owner, planned, [row('a', 'pass', 0)]), code: 139 }, { k: 2, report: shardReport(2, 2, owner, planned, [row('b', 'pass', 0)]), code: 0 }]);
  assert.equal(crashed.failedShards, 1);
  assert.deepEqual(crashed.extra, ['shard 1: exit 139 with no failed row']);

  assert.match(mergeDiffShards([{ k: 1, report: null }, { k: 2, report: null }]).error, /no shard left a report/);
  assert.match(mergeDiffShards([
    { k: 1, report: shardReport(1, 2, owner, planned, []), code: 0 },
    { k: 2, report: shardReport(2, 2, { a: 2, b: 1 }, planned, []), code: 0 },
  ]).error, /planned a different run/);
  assert.match(mergeDiffShards([{ k: 1, report: shardReport(1, 3, owner, planned, []), code: 0 }, { k: 2, report: null, code: 0 }]).error, /planned as 3, 2 given/);
});

const merge = (...args) => spawnSync(process.execPath, ['merge-shards.mjs', ...args], { cwd: SCRIPTS, encoding: 'utf8', timeout: 20000 });

test('cli: merge-shards behaviours plans again from the file and writes behaviours.txt', () => {
  const dir = join(TMP, 'beh');
  mkdirSync(join(dir, 'm', 'docs'), { recursive: true });
  const entries = ['x1', 'x2', 'x3'].map((id) => ({ id, page: 'p.html', expect: [{ text: 'y' }] }));
  writeFileSync(join(dir, 'm', 'docs', 'behaviours.json'), JSON.stringify(entries));
  const plan = planBehaviourShards(entries, 2);
  plan.forEach((list, i) => {
    writeFileSync(join(dir, `beh-${i + 1}.out`), list.map((b) => `${b.id}: ok`).join('\n') + `\n${list.length}/${list.length} behaviours ok\n`);
    writeFileSync(join(dir, `beh-${i + 1}.code`), '0\n');
  });
  let r = merge('behaviours', '--dir', dir, '--shards', '2', '--mockup', join(dir, 'm'));
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.equal(r.stdout, 'x1: ok\nx2: ok\nx3: ok\n3/3 behaviours ok\n');
  assert.equal(readFileSync(join(dir, 'behaviours.txt'), 'utf8'), r.stdout);
  rmSync(join(dir, 'beh-2.out'));
  r = merge('behaviours', '--dir', dir, '--shards', '2', '--mockup', join(dir, 'm'));
  assert.equal(r.status, 1);
  assert.match(r.stdout, /: fail: no result from shard 2/);
  r = merge('behaviours', '--dir', dir, '--shards', '2', '--mockup', join(dir, 'm'), '--only', 'zzz');
  assert.equal(r.status, 2, 'a selection that matches nothing: could not run');
  assert.match(r.stderr, /matches nothing/);
});

test('cli: merge-shards diff writes the serial report and summary line from shard reports', () => {
  const dir = join(TMP, 'diff');
  for (const [k, cases] of [[1, [row('a', 'pass', 0.01)]], [2, [row('b', 'expected', 1.5)]]]) {
    mkdirSync(join(dir, `diff-${k}`), { recursive: true });
    writeFileSync(join(dir, `diff-${k}`, 'report.json'), JSON.stringify(shardReport(k, 2, owner, planned, cases)));
    writeFileSync(join(dir, `diff-${k}.code`), '0');
  }
  let r = merge('diff', '--dir', dir, '--shards', '2');
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /baseline diff: 2 compared \(2 screens\), max mismatch 1\.5% \(b--default--desktop\); 1 pass, 1 expected, 1 skipped, 1 no-baseline/);
  const rep = JSON.parse(readFileSync(join(dir, 'diff', 'report.json'), 'utf8'));
  assert.deepEqual(rep.cases.map((c) => c.status), ['expected', 'pass', 'skipped', 'no-baseline']);
  writeFileSync(join(dir, 'diff-2.code'), '1');
  r = merge('diff', '--dir', dir, '--shards', '2');
  assert.equal(r.status, 1);
  assert.match(r.stdout, /shard 2: exit 1 with no failed row/);
  assert.equal(merge('nope', '--dir', dir).status, 2);
});

test('cli: merge-shards diff names no case when every compared case is at 0%, as summarise does for a serial run', () => {
  const dir = join(TMP, 'diff-zero');
  for (const [k, cases] of [[1, [row('a', 'pass', 0)]], [2, [row('b', 'pass', 0)]]]) {
    mkdirSync(join(dir, `diff-${k}`), { recursive: true });
    writeFileSync(join(dir, `diff-${k}`, 'report.json'), JSON.stringify(shardReport(k, 2, owner, planned, cases)));
    writeFileSync(join(dir, `diff-${k}.code`), '0');
  }
  const r = merge('diff', '--dir', dir, '--shards', '2');
  assert.equal(r.status, 0, r.stdout + r.stderr);
  const line = 'baseline diff: 2 compared (2 screens), max mismatch 0%; 2 pass, 1 skipped, 1 no-baseline';
  assert.equal(r.stdout.split('\n')[0], line);
  assert.equal(JSON.parse(readFileSync(join(dir, 'diff', 'report.json'), 'utf8')).summary, line);
});
