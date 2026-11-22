/**
 * signoff-lib.test.mjs: lib/signoff.mjs on a minimal mockup, called directly. The contract must be
 * OpenAPI 3.1 (the sample backend refuses 3.0); a fixture mapping that checks no value fails; the
 * manifest freezes dotfiles from manifest version 2 on, while a round recorded under version 1 is
 * still verified under version 1, so an old sign-off stays valid.
 * No browser. Run: node --test test/signoff-lib.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { MANIFEST_VERSION, checkContract, designConfig, manifest, signoffStatus } from '../lib/signoff.mjs';

const CONFIG = { name: 'x', timezoneId: 'Europe/Paris', screens: [{ name: 'a', page: 'pages/a.html' }], project: { contract: { source: 'drafted' } } };
const contract = (version = '3.1.0', fixture = 'items') => `openapi: ${version}
info: { title: t, version: 1.0.0 }
paths: {}
components:
  schemas:
    Item:
      x-mockup-fixture: ${fixture}
      type: object
      required: [id]
      properties:
        id: { type: string }
`;

function mockup({ fixtures = { items: [{ id: 'a' }] }, version, fixture } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'signoff-lib-'));
  for (const d of ['pages', 'data', 'api', 'docs']) mkdirSync(join(dir, d));
  writeFileSync(join(dir, 'pages/a.html'), '<p>a</p>');
  writeFileSync(join(dir, 'data/fixtures.js'), `window.FIXTURES = ${JSON.stringify(fixtures)};`);
  writeFileSync(join(dir, 'api/openapi.yaml'), contract(version, fixture));
  writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify(CONFIG));
  return dir;
}
const record = (dir, round) => writeFileSync(join(dir, 'docs/signoff.json'), JSON.stringify({ rounds: [{ round: 1, by: 'x', date: '2026-11-20', contract: { path: 'api/openapi.yaml', sha256: checkContract(dir, CONFIG).sha256 }, config: designConfig(CONFIG), ...round }] }));

test('the contract must be OpenAPI 3.1, as the sample backend reads it', () => {
  const dir = mockup({ version: '3.0.3' });
  try {
    const c = checkContract(dir, CONFIG);
    assert.ok(c.problems.some((p) => /openapi 3\.0\.3: sign-off needs OpenAPI 3\.1/.test(p)), c.problems.join('\n'));
    assert.deepEqual(checkContract(mockup(), CONFIG).problems, []);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('a fixture mapping that checks no value is a problem', () => {
  const empty = mockup({ fixtures: { items: [] } });
  const emptyMap = mockup({ fixtures: { items: {} }, fixture: "'items.*'" });
  try {
    const a = checkContract(empty, CONFIG);
    assert.ok(a.problems.includes('Item: x-mockup-fixture items: FIXTURES.items is empty, so the mapping checks nothing'), a.problems.join('\n'));
    assert.deepEqual(a.warnings, [], 'the key is named, only empty');
    const b = checkContract(emptyMap, CONFIG);
    assert.ok(b.problems.includes('Item: x-mockup-fixture items.*: FIXTURES.items is empty, so the mapping checks nothing'), b.problems.join('\n'));
  } finally { for (const d of [empty, emptyMap]) rmSync(d, { recursive: true, force: true }); }
});

test('the manifest freezes dotfiles, never .git or .DS_Store; version 1 is kept for old rounds', () => {
  const dir = mockup();
  try {
    writeFileSync(join(dir, '.hidden.js'), 'x');
    writeFileSync(join(dir, 'pages/.fragment.html'), 'x');
    writeFileSync(join(dir, '.DS_Store'), 'x');
    writeFileSync(join(dir, 'pages/.DS_Store'), 'x');
    mkdirSync(join(dir, '.git'));
    writeFileSync(join(dir, '.git/HEAD'), 'x');
    mkdirSync(join(dir, '.mockup-engine'));
    writeFileSync(join(dir, '.mockup-engine/a.png'), 'x');
    assert.equal(MANIFEST_VERSION, 2);
    const now = Object.keys(manifest(dir, { exclude: ['api/openapi.yaml'] }));
    assert.deepEqual(now, ['.hidden.js', 'data/fixtures.js', 'pages/.fragment.html', 'pages/a.html']);
    assert.deepEqual(Object.keys(manifest(dir, { exclude: ['api/openapi.yaml'], version: 1 })), ['data/fixtures.js', 'pages/a.html']);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('a dotfile added after sign-off unsigns a version 2 round; a version 1 round is verified as before', () => {
  const dir = mockup();
  try {
    record(dir, { manifestVersion: 2, files: manifest(dir, { exclude: ['api/openapi.yaml'] }) });
    assert.equal(signoffStatus(dir, CONFIG).signed, true, signoffStatus(dir, CONFIG).problems.join('\n'));
    writeFileSync(join(dir, '.hidden.js'), 'x');
    const s = signoffStatus(dir, CONFIG);
    assert.equal(s.signed, false);
    assert.match(s.problems.join('\n'), /\.hidden\.js added/);
    record(dir, { files: manifest(dir, { exclude: ['api/openapi.yaml'], version: 1 }) });
    assert.equal(signoffStatus(dir, CONFIG).signed, true, 'a round with no manifestVersion is checked under version 1');
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
