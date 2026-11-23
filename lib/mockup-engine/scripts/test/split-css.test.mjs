/**
 * split-css.test.mjs: split-css.mjs as documented (`node split-css.mjs <mockup> <out>`, the inventory
 * in the mockup), and how it cuts components.css: by the block comments inventory.mjs counts, CRLF
 * or not, a first block kept, a `/* A / B *\/` block written for each name, and a run that loses a
 * block or writes nothing exits 1. No browser.
 * Run: node --test test/split-css.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const TOOL = fileURLToPath(new URL('../split-css.mjs', import.meta.url));
const run = (...a) => spawnSync(process.execPath, [TOOL, ...a], { encoding: 'utf8' });

const HEADER = '/*\n * One block per component, headed with its exact name.\n */\n\n';

/** A mockup with that components.css and an inventory (in the mockup) giving each name a layer. */
function mockup(css, layers) {
  const tmp = mkdtempSync(join(tmpdir(), 'split-css-'));
  const m = join(tmp, 'm');
  mkdirSync(join(m, 'assets'), { recursive: true });
  mkdirSync(join(m, '.mockup-engine'));
  writeFileSync(join(m, 'assets/base.css'), '.muted { color: var(--ink-2); }\n');
  writeFileSync(join(m, 'assets/components.css'), css);
  writeFileSync(join(m, '.mockup-engine/inventory.json'), JSON.stringify({ componentLayers: Object.fromEntries(Object.entries(layers).map(([k, layer]) => [k, { layer }])) }));
  return { tmp, m, out: join(tmp, 'out'), inv: ['--inventory', join(m, '.mockup-engine/inventory.json')] };
}

test('the documented call, <mockup> <out> with the inventory in the mockup, works (B1)', () => {
  const { tmp, m, out } = mockup(`${HEADER}/* Badge */\n.badge { padding: var(--s-1); }\n`, { Badge: 'primitive' });
  try {
    const r = run(m, out);
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.match(readFileSync(join(out, 'primitives/Badge/Badge.module.css'), 'utf8'), /\.badge \{/);
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('a file whose first line is a block comment keeps that block (B2)', () => {
  const { tmp, m, out, inv } = mockup('/* Badge */\n.badge { padding: 1px; }\n\n/* Card */\n.card { margin: 0; }\n', { Badge: 'primitive', Card: 'composite' });
  try {
    const r = run(m, out, ...inv);
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.ok(existsSync(join(out, 'primitives/Badge/Badge.module.css')), 'Badge is not swallowed as a header');
    assert.ok(existsSync(join(out, 'composites/Card/Card.module.css')));
    assert.match(r.stdout, /split-css: 2 modules/);
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('CRLF line ends split as LF does (B2)', () => {
  const { tmp, m, out, inv } = mockup(`${HEADER}/* Badge */\n.badge { padding: 1px; }\n/* Card */\n.card { margin: 0; }\n`.replace(/\n/g, '\r\n'), { Badge: 'primitive', Card: 'composite' });
  try {
    const r = run(m, out, ...inv);
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.equal(readFileSync(join(out, 'primitives/Badge/Badge.module.css'), 'utf8'), '.badge { padding: 1px; }\n');
    assert.ok(existsSync(join(out, 'composites/Card/Card.module.css')));
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('a /* A / B */ block, which inventory counts for both names, is written for each (B2)', () => {
  const { tmp, m, out, inv } = mockup(`${HEADER}/* Tabs / TabPanel */\n.tabs { display: flex; }\n`, { Tabs: 'composite', TabPanel: 'composite' });
  try {
    const r = run(m, out, ...inv);
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.match(readFileSync(join(out, 'composites/Tabs/Tabs.module.css'), 'utf8'), /\.tabs/);
    assert.match(readFileSync(join(out, 'composites/TabPanel/TabPanel.module.css'), 'utf8'), /\.tabs/);
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('a block with no layer in the inventory is lost: exit 1, naming it (B2)', () => {
  const { tmp, m, out, inv } = mockup(`${HEADER}/* Badge */\n.badge { padding: 1px; }\n/* Ghost */\n.ghost { margin: 0; }\n`, { Badge: 'primitive' });
  try {
    const r = run(m, out, ...inv);
    assert.equal(r.status, 1, r.stdout + r.stderr);
    assert.match(r.stdout + r.stderr, /1 of 2 blocks written/);
    assert.match(r.stdout + r.stderr, /Ghost/);
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('no block at all writes nothing and exits 1 (B2)', () => {
  const { tmp, m, out, inv } = mockup(`${HEADER}.badge { padding: 1px; }\n`, { Badge: 'primitive' });
  try {
    const r = run(m, out, ...inv);
    assert.equal(r.status, 1, r.stdout + r.stderr);
    assert.match(r.stdout + r.stderr, /0 modules/);
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

test('rules before the first block would be lost: exit 1 (B2)', () => {
  const { tmp, m, out, inv } = mockup(`${HEADER}.stray { color: red; }\n/* Badge */\n.badge { padding: 1px; }\n`, { Badge: 'primitive' });
  try {
    const r = run(m, out, ...inv);
    assert.equal(r.status, 1, r.stdout + r.stderr);
    assert.match(r.stdout + r.stderr, /before the first block/);
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});
