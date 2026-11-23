/**
 * diff-app-http.test.mjs: visual-diff.mjs app mode loads the mockup over HTTP (lib/serve.mjs), as
 * baseline mode does, so a page that fetches its data or reads its protocol renders the same on
 * both sides. fixtures/app-http is served as the "app" too, so every case is 0%. Launches a browser.
 * Run: node --test test/diff-app-http.test.mjs   (from scripts/)
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { serveMockup } from '../lib/serve.mjs';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/app-http', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'diff-app-http-'));
let served;
before(async () => { served = await serveMockup(FIXTURE); });
after(() => { served.server.close(); rmSync(TMP, { recursive: true, force: true }); });

const vd = (args) => new Promise((done) => {
  execFile(process.execPath, [join(SCRIPTS, 'visual-diff.mjs'), '--mockup', FIXTURE, '--app', served.base, ...args], { cwd: SCRIPTS, encoding: 'utf8', timeout: 120000 }, (err, stdout, stderr) => {
    done({ status: err ? (typeof err.code === 'number' ? err.code : -1) : 0, stdout, stderr });
  });
});

test('app mode: a mockup page that fetches its data matches the same page served as the app, at 0%', { timeout: 150000 }, async () => {
  const out = join(TMP, 'out');
  const r = await vd(['--out', out]);
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /^✓ loaded--default--desktop {2}0%$/m);
  const rep = JSON.parse(readFileSync(join(out, 'report.json'), 'utf8'));
  // the served port changes every run, so the report records the page relative to the mockup
  assert.equal(rep.cases[0].mockupUrl, 'loaded.html');
});
