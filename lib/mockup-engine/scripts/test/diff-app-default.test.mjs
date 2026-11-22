/**
 * diff-app-default.test.mjs: the app-mode threshold when the config sets no diff.maxMismatchPercent
 * is 0 (the gate for every design framework kind but js-kit), and 0.2 for a js-kit, whose
 * components render through the kit's own code. A set value always wins. The served fixture is the
 * "app" too, so each run measures 0% and the report records the threshold it judged against.
 * Launches a browser. Run: node --test test/diff-app-default.test.mjs   (from scripts/)
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { serveMockup } from '../lib/serve.mjs';
import * as project from '../lib/project.mjs';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/app-http', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'diff-app-default-'));
let served;
before(async () => { served = await serveMockup(FIXTURE); });
after(() => { served.server.close(); rmSync(TMP, { recursive: true, force: true }); });

function mockupWith(name, edit) {
  const dir = join(TMP, name);
  cpSync(FIXTURE, dir, { recursive: true });
  const config = JSON.parse(readFileSync(join(dir, 'mockup.config.json'), 'utf8'));
  edit(config);
  writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify(config, null, 2));
  return dir;
}

const threshold = (mockup) => new Promise((done) => {
  const out = join(mockup, 'out');
  execFile(process.execPath, [join(SCRIPTS, 'visual-diff.mjs'), '--mockup', mockup, '--app', served.base, '--out', out], { cwd: SCRIPTS, encoding: 'utf8', timeout: 120000 }, (err, stdout, stderr) => {
    assert.equal(err ? err.code : 0, 0, stdout + stderr);
    done(JSON.parse(readFileSync(join(out, 'report.json'), 'utf8')).maxMismatch);
  });
});

test('appMaxMismatchDefault: 0.2 for js-kit only', () => {
  const { appMaxMismatchDefault } = project;
  assert.equal(appMaxMismatchDefault({ project: { designFramework: { kind: 'js-kit', name: 'kit' } } }), 0.2);
  for (const kind of ['utility-css', 'css-library', 'none', undefined]) assert.equal(appMaxMismatchDefault({ project: { designFramework: { kind } } }), 0, String(kind));
  assert.equal(appMaxMismatchDefault({}), 0);
  assert.equal(appMaxMismatchDefault({ project: { designFramework: { deferred: { owner: 'x', by: '2026-12-01' } } } }), 0);
});

test('app mode without diff.maxMismatchPercent: 0 unless the design framework is a js-kit; a set value wins', { timeout: 300000 }, async () => {
  const none = mockupWith('none', (c) => { delete c.diff.maxMismatchPercent; });
  const kit = mockupWith('kit', (c) => { delete c.diff.maxMismatchPercent; c.project = { designFramework: { kind: 'js-kit', name: 'kit' } }; });
  const set = mockupWith('set', (c) => { c.diff.maxMismatchPercent = 0.5; });
  assert.equal(await threshold(none), 0);
  assert.equal(await threshold(kit), 0.2);
  assert.equal(await threshold(set), 0.5);
});
