/**
 * inventory-css-heading.test.mjs: a components.css heading that names a component and then a note
 * (/* Name: note *\/) is not a block, so split-css would fold its rules into the block above it;
 * inventory flags it (css-block-heading) so the heading is written as a bare /* Name *\/.
 * Run: node --test test/inventory-css-heading.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../inventory.mjs', import.meta.url));
const CLEAN = fileURLToPath(new URL('./fixtures/inventory/clean', import.meta.url));

function inventoryWith(css) {
  const dir = mkdtempSync(join(tmpdir(), 'inventory-heading-'));
  try {
    const mockup = join(dir, 'mockup');
    cpSync(CLEAN, mockup, { recursive: true });
    const page = join(mockup, 'pages/home.html');
    writeFileSync(page, readFileSync(page, 'utf8').replace("componentsRegistered: []", "componentsRegistered: ['Home']"));
    mkdirSync(join(mockup, 'assets'), { recursive: true });
    writeFileSync(join(mockup, 'assets/components.css'), css);
    const out = join(dir, 'out');
    spawnSync(process.execPath, [SCRIPT, '--mockup', mockup, '--out', out], { encoding: 'utf8', timeout: 90000 });
    return existsSync(join(out, 'inventory.json')) ? JSON.parse(readFileSync(join(out, 'inventory.json'), 'utf8')).lint : null;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('a heading that names a component and adds a note is flagged', () => {
  const lint = inventoryWith('/* Home: a note about it */\n.home { display: block; }\n');
  assert.ok(lint, 'inventory wrote no report');
  const hit = lint.filter((l) => l.rule === 'css-block-heading');
  assert.equal(hit.length, 1, JSON.stringify(lint));
  assert.match(hit[0].detail, /\/\* Home \*\//);
});

test('a bare heading with the note on its own comment is not flagged', () => {
  const lint = inventoryWith('/* Home */\n/* a note about it */\n.home { display: block; }\n');
  assert.ok(lint, 'inventory wrote no report');
  assert.equal(lint.filter((l) => l.rule === 'css-block-heading').length, 0, JSON.stringify(lint));
});
