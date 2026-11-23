/**
 * check-behaviours-keys.test.mjs: the 2026-11-21 sweep's check-behaviours items (B6). A key the
 * checker does not know, on an entry, an expectation or inside attr/box/inside, fails that entry
 * instead of being ignored; an expectation with several assertions checks every one; the config's
 * pins go through the same validation as --clock and --seed, so a bad one is an error line, not a
 * stack trace. Runs check-behaviours.mjs on the fixture mockup in a real browser.
 * Run: node --test test/check-behaviours-keys.test.mjs   (from scripts/)
 */
import { describe, test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as cb from '../check-behaviours.mjs';

const CHECKER = fileURLToPath(new URL('../check-behaviours.mjs', import.meta.url));
const MOCKUP = fileURLToPath(new URL('./fixtures/behaviours/mockup', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'check-behaviours-keys-'));
after(() => rmSync(TMP, { recursive: true, force: true }));

let n = 0;
function run(entries, args = [], mockup = MOCKUP) {
  const file = join(TMP, `b-${++n}.json`);
  writeFileSync(file, JSON.stringify(entries));
  return new Promise((done) => {
    execFile(process.execPath, [CHECKER, '--mockup', mockup, '--file', file, ...args], { encoding: 'utf8', timeout: 60000 }, (err, stdout, stderr) => {
      done({ status: err ? (typeof err.code === 'number' ? err.code : -1) : 0, out: `${stdout}${stderr}`.trim() });
    });
  });
}
const line = (out, id) => out.split('\n').find((l) => l.startsWith(`${id}: `)) || `(no line) ${out}`;
const ok = 'pages/ok.html';

test('entryProblem names unknown keys on the entry, the expectation and inside attr, box and inside', () => {
  const p = (b) => (typeof cb.entryProblem === 'function' ? cb.entryProblem(b) : 'no entryProblem export');
  assert.equal(p({ id: 'a', page: ok, role: 'r', viewport: 'mobile', steps: [], expect: [{ text: 'x' }] }), null);
  assert.match(p({ id: 'a', page: ok, step: [], expect: [{ text: 'x' }] }), /unknown key "step"/);
  assert.match(p({ id: 'a', page: ok, expect: [{ text: 'x', colour: 'red' }] }), /unknown key "colour"/);
  assert.match(p({ id: 'a', page: ok, expect: [{ attr: { selector: 'a', name: 'b', valeu: 'c' } }] }), /attr has an unknown key "valeu"/);
  assert.match(p({ id: 'a', page: ok, expect: [{ box: { selector: 'a', widht: 3 } }] }), /box has an unknown key "widht"/);
  assert.match(p({ id: 'a', page: ok, expect: [{ inside: { selector: 'a', contianer: 'b' } }] }), /inside has an unknown key "contianer"/);
  assert.match(p({ id: 'a', page: ok, expect: [{ selector: '.x' }] }), /selector needs count/);
  assert.match(p({ id: 'a', page: ok, expect: [{ count: 2 }] }), /count needs selector/);
  assert.match(p({ id: 'a', page: ok, expect: [{}] }), /empty expectation/);
  assert.match(p({ id: 'a', page: ok, expect: ['text'] }), /not an object/);
  // every key the conventions and the examples use stays valid
  const all = { id: 'a', page: ok, role: 'r', viewport: { width: 1, height: 1 }, steps: [], expect: [
    { text: 'x' }, { noText: 'y' }, { selector: 'a', count: 1 }, { attr: { selector: 'a', name: 'b', value: null } }, { visible: 'a' },
    { box: { selector: 'a', width: 1, height: 1, minWidth: 1 } }, { inside: { selector: 'a', container: 'b' } }, { onTop: 'a' }, { fits: 'a' },
  ] };
  assert.equal(p(all), null);
});

describe('check-behaviours keys and pins', { concurrency: 4 }, () => {
  test('a misspelt entry key fails the entry instead of running no steps', { timeout: 90000 }, async () => {
    const r = await run([{ id: 'typo', page: ok, step: [{ click: { role: 'button', name: 'Nope' } }], expect: [{ text: 'Fixture page' }] }]);
    assert.equal(r.status, 1, r.out);
    assert.match(line(r.out, 'typo'), /^typo: fail: unknown key "step"/);
  });
  test('an unknown expectation key beside a known one fails', { timeout: 90000 }, async () => {
    const r = await run([{ id: 'extra', page: ok, expect: [{ text: 'Fixture page', colour: 'red' }] }]);
    assert.equal(r.status, 1, r.out);
    assert.match(line(r.out, 'extra'), /^extra: fail: .*unknown key "colour"/);
  });
  test('every assertion of a multi-key expectation is checked, not only the first', { timeout: 90000 }, async () => {
    const r = await run([{ id: 'both', page: ok, expect: [{ text: 'Fixture page', visible: '#no-such-element' }] }]);
    assert.equal(r.status, 1, r.out);
    assert.match(line(r.out, 'both'), /^both: fail: #no-such-element is not visible/);
  });
  test('a bad pins.clock in the config is an error line, not a stack trace (an invalid config: exit 2)', { timeout: 90000 }, async () => {
    const m = join(TMP, 'pins-mockup');
    cpSync(MOCKUP, m, { recursive: true });
    const config = JSON.parse(readFileSync(join(m, 'mockup.config.json'), 'utf8'));
    writeFileSync(join(m, 'mockup.config.json'), JSON.stringify({ ...config, pins: { clock: 'garbage' } }));
    const r = await run([{ id: 'x', page: ok, expect: [{ text: 'Fixture page' }] }], [], m);
    assert.equal(r.status, 2, r.out);
    assert.match(r.out, /^error: .*clock garbage is not a date/m);
    assert.doesNotMatch(r.out, /\n\s+at /, 'no stack trace');
  });
  test('the config pins still apply when no flag is given', { timeout: 90000 }, async () => {
    const m = join(TMP, 'pins-ok');
    cpSync(MOCKUP, m, { recursive: true });
    const config = JSON.parse(readFileSync(join(m, 'mockup.config.json'), 'utf8'));
    writeFileSync(join(m, 'mockup.config.json'), JSON.stringify({ ...config, pins: { clock: '2026-10-28T09:00:00Z', seed: 7 } }));
    const r = await run([{ id: 'p', page: 'pages/pins.html', expect: [{ text: 'now 2026-10-28T09:00:00.000Z' }] }], [], m);
    assert.equal(r.status, 0, r.out);
  });
});
