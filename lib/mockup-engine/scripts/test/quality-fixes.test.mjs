/**
 * quality-fixes.test.mjs: the 2026-11-21 sweep's quality-check items. The focus walk tells elements
 * apart by identity, not by tag and text, so two buttons both labelled "Edit" do not end it (A5), and
 * a page with more tab stops than the old fixed cap of 60 is walked to the end; a run that stops
 * early leaves no report.json from an earlier run behind; a screen with no name is matched by its
 * route or page (B12). Runs quality-check.mjs on fixture pages written to a temporary folder.
 * Run: node --test test/quality-fixes.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../quality-check.mjs', import.meta.url));
const run = (args) => new Promise((done) => {
  execFile(process.execPath, [SCRIPT, ...args], { timeout: 110000 }, (err, stdout, stderr) => done({ code: err ? err.code : 0, stdout, stderr }));
});

const CSS = 'body { font: 16px/1.5 sans-serif; margin: 16px; } button { display: block; min-width: 96px; min-height: 32px; margin: 0 0 16px; } .bare:focus { outline: none; box-shadow: none; }';

function mockup(body, screens = [{ name: 'page', page: 'index.html', route: '/' }]) {
  const m = mkdtempSync(join(tmpdir(), 'quality-fixes-'));
  writeFileSync(join(m, 'mockup.config.json'), JSON.stringify({ name: 'fixture', viewports: [{ name: 'desktop', width: 800, height: 600 }], screens }));
  writeFileSync(join(m, 'page.css'), CSS);
  writeFileSync(join(m, 'index.html'), `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Fixture</title><link rel="stylesheet" href="page.css"></head><body><main>${body}</main></body></html>`);
  return m;
}
const focusFailures = (out) => JSON.parse(readFileSync(join(out, 'report.json'), 'utf8')).cases[0].failures.filter((f) => f.check === 'focus').map((f) => f.detail);

test('two buttons with the same label do not end the focus walk: a later bare one still fails (A5)', { timeout: 120000 }, async () => {
  const m = mockup('<h1>Rows</h1><button>Edit</button><button>Edit</button><button class="bare">Save</button>');
  try {
    await run(['--mockup', m, '--out', join(m, 'out')]);
    assert.deepEqual(focusFailures(join(m, 'out')), ['no visible focus indicator on button:Save']);
  } finally { rmSync(m, { recursive: true, force: true }); }
});

test('a page with more than 60 tab stops is walked to the end (A5)', { timeout: 120000 }, async () => {
  const many = Array.from({ length: 70 }, (_, i) => `<button>Row ${i + 1}</button>`).join('');
  const m = mockup(`<h1>Many</h1>${many}<button class="bare">Last</button>`);
  try {
    await run(['--mockup', m, '--out', join(m, 'out')]);
    assert.deepEqual(focusFailures(join(m, 'out')), ['no visible focus indicator on button:Last']);
  } finally { rmSync(m, { recursive: true, force: true }); }
});

test('a run that stops before any case leaves no report.json from an earlier run (B12)', { timeout: 60000 }, async () => {
  const m = mockup('<h1>x</h1>');
  try {
    const out = join(m, 'out');
    mkdirSync(out);
    writeFileSync(join(out, 'report.json'), JSON.stringify({ cases: [{ slug: 'old', pass: true, failures: [] }] }));
    writeFileSync(join(out, 'report.md'), 'old');
    writeFileSync(join(out, 'keep.txt'), 'not a report');
    const r = await run(['--mockup', m, '--out', out, '--screen', 'nosuchscreen']);
    assert.equal(r.code, 2, r.stderr);
    assert.ok(!existsSync(join(out, 'report.json')), 'the stale report.json is gone');
    assert.ok(!existsSync(join(out, 'report.md')), 'the stale report.md is gone');
    assert.ok(existsSync(join(out, 'keep.txt')), 'nothing else in the out folder is removed');
  } finally { rmSync(m, { recursive: true, force: true }); }
});

test('a mockup.config.json that does not parse leaves no report.json from an earlier run (B12)', { timeout: 60000 }, async () => {
  const m = mockup('<h1>x</h1>');
  try {
    const out = join(m, 'out');
    mkdirSync(out);
    writeFileSync(join(out, 'report.json'), JSON.stringify({ cases: [{ slug: 'old', pass: true, failures: [] }] }));
    writeFileSync(join(m, 'mockup.config.json'), '{');
    const r = await run(['--mockup', m, '--out', out]);
    assert.notEqual(r.code, 0, r.stderr);
    assert.ok(!existsSync(join(out, 'report.json')), 'the stale report.json is gone');
  } finally { rmSync(m, { recursive: true, force: true }); }
});

test('a screen with only a page is refused before any case (no slug: exit 2, as visual-diff), not a crash (B12)', { timeout: 60000 }, async () => {
  const m = mockup('<h1>x</h1>', [{ page: 'index.html' }]);
  try {
    const r = await run(['--mockup', m, '--out', join(m, 'out'), '--screen', 'nosuchscreen']);
    assert.equal(r.code, 2, r.stderr);
    assert.doesNotMatch(r.stderr, /TypeError/);
    assert.match(r.stderr, /screens\[0\]: neither name nor route, so it has no slug/);
  } finally { rmSync(m, { recursive: true, force: true }); }
});
