/**
 * csp-diff.test.mjs: visual-diff.mjs --app enforces the app's CSP. The app's page is the mockup's
 * page plus a CSP: one that blocks its inline <style> must show as a difference (with the CSP
 * bypassed it read 0%), and one that allows it must still be 0%, so the freeze styles the check adds
 * get past a strict CSP. Launches a browser.
 * Run: node --test test/csp-diff.test.mjs   (from scripts/)
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { serveMockup } from '../lib/serve.mjs';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const MOCKUP = fileURLToPath(new URL('./fixtures/csp-diff/mockup', import.meta.url));
const APP = fileURLToPath(new URL('./fixtures/csp-diff/app', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'csp-diff-'));
let served;
before(async () => { served = await serveMockup(APP); });
after(() => { served.server.close(); rmSync(TMP, { recursive: true, force: true }); });

function vd(mockup, out) {
  return new Promise((done) => {
    execFile(process.execPath, ['visual-diff.mjs', '--mockup', mockup, '--app', served.base, '--out', out], { cwd: SCRIPTS, encoding: 'utf8', timeout: 120000 }, (err, stdout, stderr) => {
      done({ status: err ? (typeof err.code === 'number' ? err.code : -1) : 0, stdout, stderr });
    });
  });
}

test('a style the app\'s CSP blocks is a difference; the same page with the style allowed is 0%', { timeout: 150000 }, async () => {
  const blocked = await vd(MOCKUP, join(TMP, 'blocked'));
  assert.equal(blocked.status, 1, blocked.stdout + blocked.stderr);
  const report = JSON.parse(readFileSync(join(TMP, 'blocked', 'report.json'), 'utf8'));
  assert.ok(report.cases[0].mismatchPercent > 10, `expected a large mismatch, got ${report.cases[0].mismatchPercent}`);

  const mockup = join(TMP, 'mockup-ok');
  cpSync(MOCKUP, mockup, { recursive: true });
  const config = JSON.parse(readFileSync(join(mockup, 'mockup.config.json'), 'utf8'));
  config.screens[0].route = '/ok.html';
  writeFileSync(join(mockup, 'mockup.config.json'), JSON.stringify(config));
  const ok = await vd(mockup, join(TMP, 'ok'));
  assert.equal(ok.status, 0, ok.stdout + ok.stderr);
});
