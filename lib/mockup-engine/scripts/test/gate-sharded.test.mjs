/**
 * gate-sharded.test.mjs: gate-sharded.sh refuses shard counts that are not non-negative integers
 * and a run with no phase enabled (exit 2, before anything runs), and shows the failing rows of the
 * behaviours merge, not only its last line. The last test launches a browser (one behaviours shard).
 * Needs zsh. Run: node --test test/gate-sharded.test.mjs   (from scripts/)
 */
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/diff-app-shard', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'gate-sharded-'));
after(() => rmSync(TMP, { recursive: true, force: true }));
const hasZsh = spawnSync('zsh', ['-c', 'true']).status === 0;

const MOCKUP = join(TMP, 'mockup');
cpSync(FIXTURE, MOCKUP, { recursive: true });
mkdirSync(join(MOCKUP, 'docs'), { recursive: true });
writeFileSync(join(MOCKUP, 'docs', 'behaviours.json'), JSON.stringify([
  { id: 'invoices-number', page: 'invoices.html', expect: [{ text: 'INV-0412' }] },
  { id: 'invoices-missing', page: 'invoices.html', expect: [{ text: 'a line the page never shows' }] },
]));

/** Runs the gate with env on top of a minimal environment (no phase variable inherited). */
function gate(env, timeout = 20000) {
  const base = { PATH: process.env.PATH, HOME: process.env.HOME, MOCKUP, OUT: join(TMP, 'out') };
  return spawnSync('zsh', [join(SCRIPTS, 'gate-sharded.sh')], { encoding: 'utf8', timeout, env: { ...base, ...env } });
}

test('a shard count that is not a non-negative integer exits 2 before anything runs', { skip: !hasZsh && 'no zsh' }, () => {
  for (const env of [{ BEH_SHARDS: '4x' }, { BEH_SHARDS: '-1' }, { QUALITY_SHARDS: '1.5' }, { BEH_SHARDS: '0', BASELINE: TMP, DIFF_SHARDS: '0' },
    { BEH_SHARDS: '0', BASELINE: TMP, DIFF_WORKERS: '0' }, { BEH_SHARDS: '0', APP: 'http://127.0.0.1:9', APP_SHARDS: 'two' }, { BEH_SHARDS: '0', APP: 'http://127.0.0.1:9', APP_SHARDS: '0' }]) {
    rmSync(join(TMP, 'out'), { recursive: true, force: true });
    const r = gate(env);
    const label = JSON.stringify(env);
    assert.equal(r.status, 2, `${label}: ${r.stdout}${r.stderr}`);
    assert.match(r.stderr, /must be/, label);
    assert.doesNotMatch(r.stderr, /bad math expression/, label);
    assert.equal(existsSync(join(TMP, 'out')), false, `${label}: nothing ran`);
  }
});

test('no phase enabled exits 2', { skip: !hasZsh && 'no zsh' }, () => {
  const r = gate({ BEH_SHARDS: '0' });
  assert.equal(r.status, 2, r.stdout + r.stderr);
  assert.match(r.stderr, /no phase is enabled/);
});

test('the behaviours phase shows the failing rows of its merge, then the tally', { skip: !hasZsh && 'no zsh', timeout: 120000 }, () => {
  const r = gate({ BEH_SHARDS: '1' }, 110000);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stdout, /^invoices-missing: fail/m);
  assert.doesNotMatch(r.stdout, /^invoices-number: ok$/m, 'passing rows stay in the log');
  assert.match(r.stdout, /^1\/2 behaviours ok$/m);
});

test('an OUT that is the mockup folder is refused before anything is deleted', { skip: !hasZsh }, () => {
  const r = gate({ OUT: MOCKUP, BEH_SHARDS: '1' });
  assert.equal(r.status, 2, `${r.stdout}${r.stderr}`);
  assert.match(`${r.stdout}${r.stderr}`, /mockup folder/);
  assert.ok(existsSync(join(MOCKUP, 'docs', 'behaviours.json')), 'the mockup must survive');
});

test('a merge that could not run (exit 2) makes the gate exit 2, not 1: the highest code is kept', { skip: !hasZsh && 'no zsh', timeout: 60000 }, () => {
  const bare = join(TMP, 'bare');
  cpSync(FIXTURE, bare, { recursive: true }); // no docs/behaviours.json: the shard and its merge cannot run
  const r = gate({ MOCKUP: bare, OUT: join(TMP, 'bare-out'), BEH_SHARDS: '1' }, 50000);
  assert.equal(r.status, 2, r.stdout + r.stderr);
  assert.match(`${r.stdout}${r.stderr}`, /behaviours\.json does not exist/);
});
