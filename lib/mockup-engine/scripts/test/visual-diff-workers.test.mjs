/**
 * visual-diff-workers.test.mjs: visual-diff.mjs --workers, a baseline and write-baseline flag (sweep
 * F; the audit lists it under spill-check, which has no such flag). A value that is not an integer
 * of 1 or more exits 2 in both modes; --workers 1 captures one page at a time and --workers 2 two at
 * once, and the baseline written with one is passed at 0% with the other. Each page of the made-up
 * mockup loads a script from a server on 127.0.0.1 that holds it 400ms and counts the loads in
 * flight. Launches a browser. Run: node --test test/visual-diff-workers.test.mjs   (from scripts/)
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const VD = fileURLToPath(new URL('../visual-diff.mjs', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'vd-workers-'));
const MOCKUP = join(TMP, 'mockup');
const PNGS = join(TMP, 'pngs');
const run = (args) => new Promise((done) => {
  const p = spawn(process.execPath, [VD, ...args]);
  let out = '';
  p.stdout.on('data', (d) => { out += d; });
  p.stderr.on('data', (d) => { out += d; });
  p.on('close', (code) => done({ code, out }));
});

let server, inFlight = 0, peak = 0;
const NAMES = ['alpha', 'beta', 'gamma'];
before(async () => {
  server = createServer((q, res) => {
    inFlight++;
    peak = Math.max(peak, inFlight);
    setTimeout(() => { inFlight--; res.writeHead(200, { 'content-type': 'text/javascript' }).end('window.loaded = true;'); }, 400);
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const slow = `http://127.0.0.1:${server.address().port}/slow.js`;
  mkdirSync(MOCKUP, { recursive: true });
  writeFileSync(join(MOCKUP, 'mockup.config.json'), JSON.stringify({
    viewports: [{ name: 'desktop', width: 400, height: 300 }],
    screens: NAMES.map((n) => ({ name: n, page: `${n}.html` })),
  }));
  for (const n of NAMES) writeFileSync(join(MOCKUP, `${n}.html`), `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>${n}</title><script src="${slow}?p=${n}"></script></head><body><h1>${n}</h1></body></html>`);
});
after(() => { server.close(); rmSync(TMP, { recursive: true, force: true }); });

test('--workers that is not an integer of 1 or more exits 2, in baseline and write-baseline modes', async () => {
  mkdirSync(join(TMP, 'empty'), { recursive: true });
  for (const w of ['0', '-1', '1.5', 'abc']) {
    const b = await run(['--mockup', MOCKUP, '--baseline', join(TMP, 'empty'), '--workers', w, '--out', join(TMP, 'bad')]);
    assert.equal(b.code, 2, `--baseline --workers ${w}: ${b.out}`);
    assert.match(b.out, /--workers must be an integer >= 1, got /);
    const wb = await run(['--mockup', MOCKUP, '--write-baseline', join(TMP, 'bad-pngs'), '--workers', w]);
    assert.equal(wb.code, 2, `--write-baseline --workers ${w}: ${wb.out}`);
  }
});

test('--workers 1 captures one page at a time, --workers 2 two at once; both pass the same baseline', { timeout: 240000 }, async () => {
  peak = 0;
  const w = await run(['--mockup', MOCKUP, '--write-baseline', PNGS, '--workers', '1']);
  assert.equal(w.code, 0, w.out);
  assert.match(w.out, /^baseline written: 3 cases \(3 screens\)/m);
  assert.equal(readdirSync(PNGS).filter((f) => f.endsWith('.png')).length, 3);
  assert.equal(peak, 1, 'one capture at a time');

  peak = 0;
  const out = join(TMP, 'diff');
  const b = await run(['--mockup', MOCKUP, '--baseline', PNGS, '--workers', '2', '--out', out]);
  assert.equal(b.code, 0, b.out);
  assert.equal(peak, 2, 'two captures at once');
  const rep = JSON.parse(readFileSync(join(out, 'report.json'), 'utf8'));
  assert.equal(rep.cases.length, 3);
  for (const c of rep.cases) assert.equal(c.status, 'pass', JSON.stringify(c));
});
