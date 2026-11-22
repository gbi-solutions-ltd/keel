/**
 * perf-budget.test.mjs: perf-budget.mjs measures or refuses (sweep A2): a Vite build with a base
 * path is measured, not read as 0 KB; a named file missing from dist and a build whose initial load
 * names no JS exit 2; a budget with no bundle.initialJsKb exits 2; --runs must be a positive integer.
 * No browser (the zero-screen --url check exits before one launches). Run: node --test test/perf-budget.test.mjs
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const PERF = fileURLToPath(new URL('../perf-budget.mjs', import.meta.url));
const run = (args) => new Promise((done) => { const p = spawn(process.execPath, [PERF, ...args]); let out = ''; p.stdout.on('data', (d) => { out += d; }); p.stderr.on('data', (d) => { out += d; }); p.on('close', (code) => done({ code, out })); });
const noise = (n) => Array.from({ length: n }, (_, i) => `const v${i}=${(i * 7919) % 104729};`).join('');

function build(index, files = { 'assets/entry.js': noise(400) }) {
  const dir = mkdtempSync(join(tmpdir(), 'perf-a2-'));
  const dist = join(dir, 'dist');
  mkdirSync(join(dist, 'assets'), { recursive: true });
  writeFileSync(join(dist, 'index.html'), index);
  for (const [f, c] of Object.entries(files)) writeFileSync(join(dist, f), c);
  const budget = (b) => { writeFileSync(join(dir, 'budget.json'), JSON.stringify(b)); return join(dir, 'budget.json'); };
  return { dir, dist, budget };
}
const BUDGET = { bundle: { initialJsKb: 50, initialCssKb: 5, lazyChunkKb: 50 } };

test('a build with a base path (/app/) is measured from the files, not read as 0 KB', async () => {
  const b = build('<!doctype html><script type="module" src="/app/assets/entry.js"></script>');
  try {
    const r = await run(['--budget', b.budget(BUDGET), '--dist', b.dist]);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /bundle: initial JS [1-9][\d.]* KB, initial CSS 0 KB gzip \(1 files\)/);
  } finally { rmSync(b.dir, { recursive: true, force: true }); }
});

test('a named file missing from dist, or an initial load with no JS, exits 2', async () => {
  const missing = build('<!doctype html><script type="module" src="/assets/gone.js"></script>');
  const none = build('<!doctype html><p>no scripts</p>');
  try {
    const m = await run(['--budget', missing.budget(BUDGET), '--dist', missing.dist]);
    assert.equal(m.code, 2, m.out);
    assert.match(m.out, /perf-budget: index\.html names \/assets\/gone\.js, which is not under /);
    const n = await run(['--budget', none.budget(BUDGET), '--dist', none.dist]);
    assert.equal(n.code, 2, n.out);
    assert.match(n.out, /perf-budget: the initial load names no JS file: nothing measured/);
  } finally { for (const b of [missing, none]) rmSync(b.dir, { recursive: true, force: true }); }
});

test('a budget with no bundle.initialJsKb, and a bad --runs, exit 2', async () => {
  const b = build('<!doctype html><script type="module" src="/assets/entry.js"></script>');
  try {
    for (const budget of [{}, { bundle: {} }, { bundle: { initialJsKb: 'lots' } }]) {
      const r = await run(['--budget', b.budget(budget), '--dist', b.dist]);
      assert.equal(r.code, 2, `${JSON.stringify(budget)}: ${r.out}`);
      assert.match(r.out, /perf-budget: .*bundle\.initialJsKb/);
    }
    for (const runs of ['0', '-1', '1.5', 'x']) {
      const r = await run(['--budget', b.budget(BUDGET), '--dist', b.dist, '--url', 'http://127.0.0.1:9', '--mockup', b.dir, '--runs', runs]);
      assert.equal(r.code, 2, `--runs ${runs}: ${r.out}`);
      assert.match(r.out, /perf-budget: --runs .* want a positive integer/);
    }
    const last = await run(['--budget', b.budget(BUDGET), '--dist', b.dist, '--runs']);
    assert.equal(last.code, 2, `--runs with no value: ${last.out}`);
  } finally { rmSync(b.dir, { recursive: true, force: true }); }
});

test('--url with no screen selected exits 2, before a browser', async () => {
  const b = build('<!doctype html><script type="module" src="/assets/entry.js"></script>');
  try {
    writeFileSync(join(b.dir, 'mockup.config.json'), JSON.stringify({ screens: [{ name: 'home', file: 'index.html', route: '/' }] }));
    const r = await run(['--budget', b.budget(BUDGET), '--dist', b.dist, '--url', 'http://127.0.0.1:9', '--mockup', b.dir, '--route', '^/nomatch']);
    assert.equal(r.code, 2, r.out);
    assert.match(r.out, /perf-budget: --url: no screen selected/);
  } finally { rmSync(b.dir, { recursive: true, force: true }); }
});
