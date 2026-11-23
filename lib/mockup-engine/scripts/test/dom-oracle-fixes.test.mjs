/**
 * dom-oracle-fixes.test.mjs: the 2026-11-21 sweep's DOM oracle items. A skipped hidden button
 * holding an svg no longer breaks the indentation (A10); --reference tells a changed difference of
 * the same size from the same one, by a hash of each case's diff (A12); --out refuses a folder whose
 * removal would lose work (B8); the mockup side loads over HTTP, as the other modes do (B12).
 * Run: node --test test/dom-oracle-fixes.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as lib from '../lib/dom-oracle.mjs';
import * as report from '../lib/baseline-report.mjs';

// A namespace import, so a missing export fails its own tests rather than the whole file.
const { compare, compareWithReference, normalise } = lib;
// One out-dir guard for every script that empties its --out (lib/baseline-report.mjs outDirRefusal)
const outDirProblem = (...a) => report.outDirRefusal(...a);

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));

// ---- A10 ----------------------------------------------------------------------------------------

test('a skipped hidden button holding an svg does not throw or shift what follows (A10)', () => {
  const html = '<button hidden data-action="x"><svg><path></path></svg></button><p>after</p>';
  assert.deepEqual(normalise(html, { skipHiddenActions: ['x'] }), ['<p >', '  T:after']);
});

test('nested: the lines after a skipped svg button keep their depth (A10)', () => {
  const html = '<div><button hidden data-action="x"><svg><path></path><circle></circle></svg></button><p>after</p></div><span>end</span>';
  assert.deepEqual(normalise(html, { skipHiddenActions: ['x'] }), ['<div >', '  <p >', '    T:after', '<span >', '  T:end']);
});

test('a stray end tag cannot take the depth below zero (A10)', () => {
  assert.deepEqual(normalise('</div></div><p>x</p>'), ['<p >', '  T:x']);
});

// ---- A12 ----------------------------------------------------------------------------------------

test('compare gives a hash of the diff: equal for the same difference, different for another (A12)', () => {
  const a = compare('<p>one</p><p>two</p>', '<p>one</p><p>2</p>');
  const b = compare('<h1>x</h1><p>one</p><p>two</p>', '<h1>x</h1><p>one</p><p>2</p>');
  const c = compare('<p>one</p><p>two</p>', '<p>1</p><p>two</p>');
  assert.equal(typeof a.diffHash, 'string');
  assert.equal(a.diffLines, c.diffLines);
  assert.equal(a.diffHash, b.diffHash, 'a line added above both sides moves the hunk, not the hash');
  assert.notEqual(a.diffHash, c.diffHash);
  assert.equal(compare('<p>x</p>', '<p>x</p>').diffHash, compare('<b>y</b>', '<b>y</b>').diffHash, 'no difference hashes alike');
});

const hrow = (slug, diffLines, diffHash) => ({ slug, status: diffLines ? 'diff' : 'match', diffLines, edgeLines: 0, ...(diffHash ? { diffHash } : {}) });

test('--reference: a changed difference at the same or a higher count is worse, at a lower count better (A12)', () => {
  const now = [hrow('same', 2, 'h1'), hrow('swapped', 2, 'h9'), hrow('more', 3, 'h9'), hrow('fewer', 1, 'h9')];
  const ref = [hrow('same', 2, 'h1'), hrow('swapped', 2, 'h2'), hrow('more', 2, 'h2'), hrow('fewer', 2, 'h2')];
  const r = compareWithReference(now, ref);
  const by = Object.fromEntries(r.cases.map((c) => [c.slug, c]));
  assert.equal(by.same.verdict, 'same');
  assert.deepEqual(by.swapped, { slug: 'swapped', verdict: 'worse', before: 2, after: 2, diffDelta: 0, edgeDelta: 0, contentChanged: true });
  assert.equal(by.more.verdict, 'worse');
  assert.equal(by.fewer.verdict, 'better');
  assert.equal(r.unhashed, 0);
});

test('--reference: a reference with no hashes falls back to counts and says how many (A12)', () => {
  const r = compareWithReference([hrow('a', 2, 'h9'), hrow('b', 0, 'h0')], [hrow('a', 2), hrow('b', 0)]);
  assert.equal(r.cases[0].verdict, 'same');
  assert.equal(r.cases[0].contentChanged, undefined);
  assert.equal(r.unhashed, 2);
});

// ---- B8 -----------------------------------------------------------------------------------------

test('the shared out-dir guard refuses the mockup, the cwd, home, a git root and any folder holding one; allows a sibling (B8)', () => {
  assert.equal(lib.outDirProblem, undefined, 'lib/dom-oracle.mjs keeps no guard of its own');
  const tmp = realpathSync(mkdtempSync(join(tmpdir(), 'dom-oracle-out-')));
  try {
    const repo = join(tmp, 'repo');
    const m = join(repo, 'mockup');
    mkdirSync(join(repo, '.git'), { recursive: true });
    mkdirSync(m);
    const ctx = { mockupDir: m, cwd: join(repo, 'work'), home: join(tmp, 'home') };
    mkdirSync(ctx.cwd);
    mkdirSync(ctx.home);
    assert.match(outDirProblem(m, ctx), /mockup/);
    assert.match(outDirProblem(repo, ctx), /git|mockup/);
    assert.match(outDirProblem(tmp, ctx), /mockup|git|home/);
    assert.match(outDirProblem(ctx.cwd, ctx), /current folder/);
    assert.match(outDirProblem(ctx.home, ctx), /home/);
    mkdirSync(join(tmp, 'other-repo'));
    assert.equal(outDirProblem(join(tmp, 'other-repo'), ctx), null, 'a sibling folder is fine');
    mkdirSync(join(tmp, 'other-repo/.git'), { recursive: true });
    assert.match(outDirProblem(join(tmp, 'other-repo'), ctx), /git/);
    assert.equal(outDirProblem(join(m, '.mockup-engine/dom-oracle'), ctx), null, 'the default out is fine');
    assert.equal(outDirProblem(join(repo, 'work', 'out'), ctx), null, 'a folder under the cwd is fine');
    // a non-empty folder in general is still allowed
    mkdirSync(join(tmp, 'full'));
    writeFileSync(join(tmp, 'full/keep.txt'), 'x');
    assert.equal(outDirProblem(join(tmp, 'full'), ctx), null);
    assert.match(outDirProblem(homedir(), { mockupDir: m, cwd: ctx.cwd }), /home/, 'home defaults to os.homedir()');
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('the CLI refuses --out <mockup> and --out <cwd> before anything is removed (B8)', () => {
  const tmp = realpathSync(mkdtempSync(join(tmpdir(), 'dom-oracle-out-')));
  try {
    const m = join(tmp, 'm');
    mkdirSync(join(m, 'pages'), { recursive: true });
    writeFileSync(join(m, 'mockup.config.json'), JSON.stringify({ viewports: [{ name: 'desktop', width: 800, height: 600 }], screens: [{ name: 'a', page: 'pages/a.html', route: '/a' }] }));
    writeFileSync(join(m, 'pages/a.html'), '<div id="app">a</div>');
    // a folder holding a git repository two levels down is refused too (the stricter rule set)
    const nested = join(tmp, 'work');
    mkdirSync(join(nested, 'a', 'repo', '.git'), { recursive: true });
    for (const [out, cwd] of [[m, tmp], ['.', m], [tmp, tmp], [nested, tmp]]) {
      const r = spawnSync(process.execPath, [join(SCRIPTS, 'dom-oracle.mjs'), '--mockup', m, '--app', 'http://localhost:1', '--out', out], { encoding: 'utf8', cwd });
      assert.equal(r.status, 2, `--out ${out}: ${r.stdout}${r.stderr}`);
      assert.match(r.stderr, /--out .* (is|contains) .*; it would be deleted/);
      assert.ok(existsSync(join(nested, 'a', 'repo', '.git')), `--out ${out} removed the nested repository`);
      assert.ok(existsSync(join(m, 'pages/a.html')), `--out ${out} removed the mockup`);
    }
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

// ---- B12: the mockup over HTTP ------------------------------------------------------------------

const cliAsync = (...args) => new Promise((done) => {
  const p = spawn(process.execPath, [join(SCRIPTS, 'dom-oracle.mjs'), ...args]);
  let stdout = '';
  let stderr = '';
  p.stdout.on('data', (d) => { stdout += d; });
  p.stderr.on('data', (d) => { stderr += d; });
  p.on('close', (status) => done({ status, stdout, stderr }));
});

test('case mode loads the mockup over HTTP, as visual-diff and the other checks do (B12)', { timeout: 120000 }, async () => {
  const server = createServer((req, res) => { res.writeHead(200, { 'content-type': 'text/html' }); res.end('<!doctype html><html><body><div id="app">http:</div></body></html>'); });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const tmp = mkdtempSync(join(tmpdir(), 'dom-oracle-http-'));
  try {
    const m = join(tmp, 'm');
    mkdirSync(join(m, 'pages'), { recursive: true });
    writeFileSync(join(m, 'mockup.config.json'), JSON.stringify({ viewports: [{ name: 'desktop', width: 800, height: 600 }], screens: [{ name: 'proto', page: 'pages/proto.html', route: '/proto' }] }));
    writeFileSync(join(m, 'pages/proto.html'), '<!doctype html><html><body><div id="app"></div><script>document.getElementById("app").textContent = location.protocol;</script></body></html>');
    const out = join(tmp, 'out');
    const r = await cliAsync('--mockup', m, '--app', `http://127.0.0.1:${server.address().port}`, '--out', out);
    assert.equal(r.status, 0, r.stdout + r.stderr);
    const report = JSON.parse(readFileSync(join(out, 'report.json'), 'utf8'));
    assert.match(report.cases[0].mockupUrl, /^http:\/\/127\.0\.0\.1:\d+\/pages\/proto\.html/);
    assert.equal(typeof report.cases[0].diffHash, 'string', 'each case stores its diff hash (A12)');
  } finally {
    server.close();
    rmSync(tmp, { recursive: true, force: true });
  }
});
