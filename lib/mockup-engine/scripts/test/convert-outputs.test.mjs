/**
 * convert-outputs.test.mjs: at Convert nothing is written into a signed-off package. spill-check
 * --out writes its result outside the mockup; split-css --inventory reads an inventory written
 * elsewhere when the mockup has none; the DOM oracle's appRoot is validated and read for the app
 * side. Run: node --test test/convert-outputs.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { optionsFromConfig } from '../lib/dom-oracle.mjs';

const S = (f) => fileURLToPath(new URL(`../${f}`, import.meta.url));
const run = (script, ...a) => spawnSync(process.execPath, [S(script), ...a], { encoding: 'utf8', timeout: 120000 });

test('spill-check --out writes the result there and nothing under the mockup', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'spill-out-'));
  try {
    const m = join(tmp, 'm');
    cpSync(S('test/fixtures/spill'), m, { recursive: true });
    const out = join(tmp, 'app-cache');
    run('spill-check.mjs', '--mockup', m, '--widths', '600', '--out', out);
    assert.ok(existsSync(join(out, 'spill.json')));
    assert.ok(!existsSync(join(m, '.mockup-engine')), 'the mockup gets no .mockup-engine folder');
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('split-css --inventory reads an inventory written outside the mockup', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'split-'));
  try {
    const m = join(tmp, 'm');
    mkdirSync(join(m, 'assets'), { recursive: true });
    writeFileSync(join(m, 'assets/base.css'), '.muted { color: var(--ink-2); }\n');
    writeFileSync(join(m, 'assets/components.css'), '/* components */\n/* Badge */\n.badge { padding: var(--s-1); }\n.badge .muted { opacity: 1; }\n');
    const inv = join(tmp, 'elsewhere/inventory.json');
    mkdirSync(join(tmp, 'elsewhere'));
    writeFileSync(inv, JSON.stringify({ componentLayers: { Badge: { layer: 'primitive' } } }));
    const without = run('split-css.mjs', m, join(tmp, 'out'));
    assert.equal(without.status, 2, 'no inventory in the mockup and none named');
    assert.match(without.stderr, /missing .*inventory\.json: run inventory\.mjs first/);
    const r = run('split-css.mjs', m, join(tmp, 'out'), '--inventory', inv);
    assert.equal(r.status, 0, r.stderr);
    assert.match(readFileSync(join(tmp, 'out/primitives/Badge/Badge.module.css'), 'utf8'), /\.badge :global\(\.muted\)/);
    assert.ok(!existsSync(join(m, '.mockup-engine')));
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('domOracle.appRoot is validated and kept apart from root', () => {
  assert.deepEqual(optionsFromConfig({ domOracle: { root: '#app', appRoot: '#root' } }), { options: {}, root: '#app', appRoot: '#root' });
  assert.match(optionsFromConfig({ domOracle: { appRoot: 1 } }).error, /domOracle\.appRoot must be a selector string/);
  assert.deepEqual(optionsFromConfig({ domOracle: { root: '#app' } }), { options: {}, root: '#app' });
  // The CLI reads the app side from appRoot: the source says so, checked here without a browser.
  const src = readFileSync(S('dom-oracle.mjs'), 'utf8');
  assert.match(src, /const appRoot = opt\('app-root'\) \?\? cfg\.appRoot \?\? root;/);
  assert.match(src, /dump\(browser, aUrl, appSteps\(c\.screen\.steps\), appRoot\)/);
});
