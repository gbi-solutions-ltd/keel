/**
 * gate-sharded-phases.test.mjs: gate-sharded.sh's app and quality phases (sweep F), beyond
 * gate-sharded.test.mjs. With APP set and QUALITY_SHARDS above 0, the app diff runs in APP_SHARDS
 * shards and the quality check in QUALITY_SHARDS shards against APP (not the mockup), each merged by
 * merge-shards.mjs into app/ and quality/ under OUT, with every shard's .code file 0 and the merges'
 * tallies printed. An app that does not answer fails its merge, so the gate exits 1.
 * The "app" is fixtures/diff-app-shard itself, served on 127.0.0.1 (lib/serve.mjs). Launches
 * browsers (one per shard). Needs zsh. Run: node --test test/gate-sharded-phases.test.mjs
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { serveMockup } from '../lib/serve.mjs';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/diff-app-shard', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'gate-phases-'));
const MOCKUP = join(TMP, 'mockup');
cpSync(FIXTURE, MOCKUP, { recursive: true });
const hasZsh = spawnSync('zsh', ['-c', 'true']).status === 0;
let served;
before(async () => { served = await serveMockup(MOCKUP); });
after(() => { served?.server.close(); rmSync(TMP, { recursive: true, force: true }); });

/** Runs the gate asynchronously (the served app lives in this process) with env on a minimal base. */
function gate(env, out) {
  return new Promise((done) => {
    const base = { PATH: process.env.PATH, HOME: process.env.HOME, MOCKUP, OUT: out };
    const p = spawn('zsh', [join(SCRIPTS, 'gate-sharded.sh')], { env: { ...base, ...env } });
    let stdout = '', stderr = '';
    p.stdout.on('data', (d) => { stdout += d; });
    p.stderr.on('data', (d) => { stderr += d; });
    p.on('close', (status) => done({ status, stdout, stderr }));
  });
}
const json = (f) => JSON.parse(readFileSync(f, 'utf8'));

test('APP and QUALITY phases: shards run against the app, merge into app/ and quality/, exit 0', { skip: !hasZsh && 'no zsh', timeout: 240000 }, async () => {
  const out = join(TMP, 'out');
  // QUALITY_ARGS' --warnings reaches the merge, which writes the report (its --screen does not: the merge has none)
  const r = await gate({ BEH_SHARDS: '0', APP: served.base, APP_SHARDS: '2', QUALITY_SHARDS: '2', QUALITY_ARGS: '--warnings all' }, out);
  const all = `${r.stdout}${r.stderr}`;
  assert.equal(r.status, 0, all);
  for (const k of [1, 2]) {
    assert.equal(readFileSync(join(out, `app-${k}.code`), 'utf8').trim(), '0', `app shard ${k}`);
    assert.equal(readFileSync(join(out, `quality-${k}.code`), 'utf8').trim(), '0', `quality shard ${k}`);
  }
  // no behaviours or baseline phase ran
  assert.equal(existsSync(join(out, 'beh-1.out')), false);
  assert.equal(existsSync(join(out, 'diff')), false);

  const app = json(join(out, 'app', 'report.json'));
  assert.equal(app.appBase, served.base.replace(/\/$/, ''));
  assert.deepEqual(app.cases.map((c) => c.slug).sort(), ['invoices--default--desktop', 'orders--default--desktop']);
  assert.match(r.stdout, /^2 of 2 planned captures measured, not measured: 0$/m);
  assert.match(r.stdout, /^2\/2 passing/m);

  const q = json(join(out, 'quality', 'report.json'));
  assert.equal(q.target, 'app', 'the quality phase checks APP when it is set');
  const md = readFileSync(join(out, 'quality', 'report.md'), 'utf8');
  assert.match(md, /^## Warnings$/m, 'the merged report lists every warning, as --warnings all asks');
  assert.doesNotMatch(md, /^## Warnings, by check$/m);
  assert.equal(q.app.replace(/\/$/, ''), served.base.replace(/\/$/, ''));
  assert.equal(q.cases.length, 4, 'two screens at the desktop viewport and at 320px');
  for (const c of q.cases) assert.ok(c.url.startsWith(served.base.replace(/\/$/, '')), c.url);
  assert.match(r.stdout, /^4 of 4 planned cases measured, not measured: 0$/m);
  assert.match(r.stdout, /^4\/4 passing$/m);
  assert.match(r.stderr, /^# app diff: \d+s$/m);
  assert.match(r.stderr, /^# quality: \d+s$/m);
});

test('an APP that does not answer fails the app merge: the gate exits 1', { skip: !hasZsh && 'no zsh', timeout: 180000 }, async () => {
  const out = join(TMP, 'dead');
  const r = await gate({ BEH_SHARDS: '0', APP: 'http://127.0.0.1:9', APP_SHARDS: '1' }, out);
  assert.equal(r.status, 1, `${r.stdout}${r.stderr}`);
  assert.notEqual(readFileSync(join(out, 'app-1.code'), 'utf8').trim(), '0');
});
