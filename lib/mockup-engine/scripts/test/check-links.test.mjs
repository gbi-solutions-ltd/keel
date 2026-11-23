/**
 * check-links.test.mjs: check-links.mjs resolves every markdown link in SKILL.md, README.md,
 * references/** and templates/**: a missing file or a missing #anchor (GitHub's slug rules) fails
 * (exit 1), links inside code are skipped, and the engine's own docs resolve.
 * Run: node --test test/check-links.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../check-links.mjs', import.meta.url));
const ENGINE = fileURLToPath(new URL('../../../..', import.meta.url));
const run = (args) => {
  const r = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: 'utf8' });
  return { code: r.status, out: r.stdout + r.stderr };
};

function tree(files) {
  const root = mkdtempSync(join(tmpdir(), 'check-links-'));
  for (const [p, text] of Object.entries(files)) {
    mkdirSync(join(root, p, '..'), { recursive: true });
    writeFileSync(join(root, p), text);
  }
  return root;
}

test('links that resolve, anchors included, pass; code is skipped', () => {
  const root = tree({
    'skills/mockup/SKILL.md': '# Skill\n\nSee [the ref](references/a.md#step-1-inputs) and [b](references/a.md).\n\n```\n[not a link](nowhere.md)\n```\n\n`[inline](nowhere.md)`\n',
    'skills/mockup/references/a.md': '# A\n\n## Step 1: Inputs\n',
  });
  try {
    const r = run([root]);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /checked 2 links in 2 files, 0 broken/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('a missing file and a missing anchor each fail, named', () => {
  const root = tree({
    'lib/mockup-engine/README.md': '[gone](references/gone.md) and [bad](references/a.md#no-such-heading)\n',
    'lib/mockup-engine/references/a.md': '# A\n',
  });
  try {
    const r = run([root]);
    assert.equal(r.code, 1, r.out);
    assert.match(r.out, /BROKEN-FILE lib\/mockup-engine\/README\.md:1 -> references\/gone\.md/);
    assert.match(r.out, /BROKEN-ANCHOR lib\/mockup-engine\/README\.md:1 -> references\/a\.md#no-such-heading/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("a root's own README is not judged (keel's is keel's), and --file adds one", () => {
  const root = tree({
    'README.md': '[gone](nowhere.md)\n',
    'agents/keel-port-worker.md': '# Worker\n',
  });
  try {
    const r = run([root]);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /checked 0 links in 1 files, 0 broken/);
    const withReadme = run([root, '--file', join(root, 'README.md')]);
    assert.equal(withReadme.code, 1, withReadme.out);
    assert.match(withReadme.out, /BROKEN-FILE README\.md:1 -> nowhere\.md/);
    assert.equal(run([root, '--file', join(root, 'no-such.md')]).code, 2);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('a root with no docs is a usage error (exit 2), not a pass', () => {
  const root = mkdtempSync(join(tmpdir(), 'check-links-empty-'));
  try {
    assert.equal(run([root]).code, 2);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("the engine's own docs resolve", () => {
  const r = run([ENGINE]);
  assert.equal(r.code, 0, r.out);
});
