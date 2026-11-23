/**
 * check-behaviours.test.mjs: every case writes a behaviours file to a temp dir and runs
 * check-behaviours.mjs on it in a child process, so the exit status is the checker's own. The pages
 * are static fixtures in fixtures/behaviours/mockup (roles from a stand-in MK.inspect()) and
 * fixtures/behaviours/roles-in-config (roles from mockup.config.json).
 * Run: node --test test/check-behaviours.test.mjs   (from scripts/)
 */
import { describe, test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mergeBehaviourShards, planBehaviourShards } from '../lib/shard.mjs';

const CHECKER = fileURLToPath(new URL('../check-behaviours.mjs', import.meta.url));
const MOCKUP = fileURLToPath(new URL('./fixtures/behaviours/mockup', import.meta.url));
const ROLES_MOCKUP = fileURLToPath(new URL('./fixtures/behaviours/roles-in-config', import.meta.url));
const TMP = mkdtempSync(join(tmpdir(), 'check-behaviours-'));
after(() => rmSync(TMP, { recursive: true, force: true }));

let n = 0;
function run(entries, args = [], mockup = MOCKUP) {
  const file = join(TMP, `behaviours-${++n}.json`);
  writeFileSync(file, JSON.stringify(entries, null, 1));
  return new Promise((done) => {
    execFile(process.execPath, [CHECKER, '--mockup', mockup, '--file', file, ...args], { encoding: 'utf8', timeout: 60000 }, (err, stdout, stderr) => {
      done({ status: err ? (typeof err.code === 'number' ? err.code : -1) : 0, out: `${stdout}${stderr}`.trim() });
    });
  });
}
const line = (out, id) => out.split('\n').find((l) => l.startsWith(`${id}: `)) || '(no line)';

/** Each case returns true, or what it saw (shown when it fails). */
function check(label, fn) {
  test(label, { timeout: 90000 }, async () => {
    const r = await fn();
    assert.equal(r, true, typeof r === 'string' ? r : JSON.stringify(r));
  });
}

const okPage = 'pages/ok.html';
const P = 'pages/';

describe('check-behaviours', { concurrency: 4 }, () => {
  check('a passing entry is ok and exits 0', async () => {
    const r = await run([{ id: 'pass', page: okPage, expect: [{ text: 'Fixture page' }] }]);
    return (r.status === 0 && line(r.out, 'pass') === 'pass: ok') || JSON.stringify(r);
  });
  check('an entry with an empty expect fails (it would pass vacuously)', async () => {
    const r = await run([{ id: 'empty', page: okPage, expect: [] }]);
    return (r.status === 1 && /^empty: fail: no expectations/.test(line(r.out, 'empty'))) || JSON.stringify(r);
  });
  check('an entry with no expect fails', async () => {
    const r = await run([{ id: 'none', page: okPage }]);
    return (r.status === 1 && /^none: fail: no expectations/.test(line(r.out, 'none'))) || JSON.stringify(r);
  });
  check('a pageerror during load fails, even when every expectation holds (noText passes on a page that throws)', async () => {
    const r = await run([{ id: 'load-throws', page: `${P}throws-on-load.html`, expect: [{ text: 'Fixture page' }, { noText: 'Nothing like this' }] }]);
    return (r.status === 1 && /^load-throws: fail: pageerror: .*thrown during load/.test(line(r.out, 'load-throws'))) || JSON.stringify(r);
  });
  check('a pageerror during the steps fails', async () => {
    const r = await run([{ id: 'step-throws', page: `${P}throws-on-click.html`, steps: [{ click: { role: 'button', name: 'Press' } }], expect: [{ text: 'Fixture page' }] }]);
    return (r.status === 1 && /^step-throws: fail: pageerror: .*thrown by a step/.test(line(r.out, 'step-throws'))) || JSON.stringify(r);
  });
  check('duplicate ids are rejected before anything runs: an invalid file, exit 2', async () => {
    const r = await run([{ id: 'twice', page: okPage, expect: [{ text: 'Fixture page' }] }, { id: 'twice', page: okPage, expect: [{ text: 'Fixture page' }] }]);
    return (r.status === 2 && /duplicate id.*twice/.test(r.out) && !/^twice: ok/m.test(r.out)) || JSON.stringify(r);
  });
  check('--only that matches nothing exits 2 (could not run)', async () => {
    const r = await run([{ id: 'pass', page: okPage, expect: [{ text: 'Fixture page' }] }], ['--only', 'zzz']);
    return (r.status === 2 && /matches nothing/.test(r.out)) || JSON.stringify(r);
  });
  check('a missing config, a missing or non-JSON or non-array file exits 2, each named on stderr', async () => {
    const cli = (args) => new Promise((done) => execFile(process.execPath, [CHECKER, ...args], { encoding: 'utf8', timeout: 60000 }, (err, stdout, stderr) => done({ status: err ? err.code : 0, stdout, stderr })));
    const seen = [];
    const noConfig = await cli(['--mockup', TMP, '--file', join(TMP, 'x.json')]);
    seen.push(noConfig.status === 2 && /error: missing .*mockup\.config\.json/.test(noConfig.stderr) && !noConfig.stdout);
    const noFile = await cli(['--mockup', MOCKUP, '--file', join(TMP, 'none.json')]);
    seen.push(noFile.status === 2 && /error: missing .*none\.json/.test(noFile.stderr) && !noFile.stdout);
    writeFileSync(join(TMP, 'bad.json'), '[{ "id": ');
    const bad = await cli(['--mockup', MOCKUP, '--file', join(TMP, 'bad.json')]);
    seen.push(bad.status === 2 && /bad\.json is not valid JSON/.test(bad.stderr) && !/crashed/.test(bad.stderr));
    writeFileSync(join(TMP, 'obj.json'), '{}');
    const obj = await cli(['--mockup', MOCKUP, '--file', join(TMP, 'obj.json')]);
    seen.push(obj.status === 2 && /obj\.json is not an array of entries/.test(obj.stderr));
    return seen.every(Boolean) || JSON.stringify({ seen, noConfig, noFile, bad, obj });
  });
  check('--only that matches an entry runs only it', async () => {
    const r = await run([{ id: 'a-one', page: okPage, expect: [{ text: 'Fixture page' }] }, { id: 'b-two', page: okPage, expect: [{ text: 'Nope' }] }], ['--only', 'a-']);
    return (r.status === 0 && /1\/1 behaviours ok/.test(r.out)) || JSON.stringify(r);
  });
  check('visible: an element on screen passes', async () => {
    const r = await run([{ id: 'vis', page: okPage, expect: [{ visible: '#panel' }] }]);
    return (r.status === 0) || JSON.stringify(r);
  });
  check('visible: an element translated off canvas fails', async () => {
    const r = await run([{ id: 'off', page: okPage, expect: [{ visible: '#offscreen' }] }]);
    return (r.status === 1 && /^off: fail: #offscreen is not visible/.test(line(r.out, 'off'))) || JSON.stringify(r);
  });
  check('visible: a display:none element fails', async () => {
    const r = await run([{ id: 'hid', page: okPage, expect: [{ visible: '#hidden' }] }]);
    return (r.status === 1 && /^hid: fail: #hidden is not visible/.test(line(r.out, 'hid'))) || JSON.stringify(r);
  });
  check('box: the width at the default (desktop) viewport is checked', async () => {
    const r = await run([{ id: 'box-desk', page: okPage, expect: [{ box: { selector: '#panel', width: 400 } }] }, { id: 'box-desk-bad', page: okPage, expect: [{ box: { selector: '#panel', width: 272 } }] }]);
    return (r.status === 1 && line(r.out, 'box-desk') === 'box-desk: ok' && /^box-desk-bad: fail: #panel is 400px wide, expected 272/.test(line(r.out, 'box-desk-bad'))) || JSON.stringify(r);
  });
  check('viewport: mobile loads the page at 390px, so the mobile width holds', async () => {
    const r = await run([{ id: 'box-mob', page: okPage, viewport: 'mobile', expect: [{ box: { selector: '#panel', width: 272 } }] }]);
    return (r.status === 0) || JSON.stringify(r);
  });
  check('viewport: an unknown viewport name fails', async () => {
    const r = await run([{ id: 'bad-vp', page: okPage, viewport: 'watch', expect: [{ text: 'Fixture page' }] }]);
    return (r.status === 1 && /^bad-vp: fail: unknown viewport watch/.test(line(r.out, 'bad-vp'))) || JSON.stringify(r);
  });
  check('box: height is checked too when given (#panel is 100px high)', async () => {
    const r = await run([{ id: 'box-h', page: okPage, expect: [{ box: { selector: '#panel', height: 100 } }] }, { id: 'box-h-bad', page: okPage, expect: [{ box: { selector: '#panel', width: 400, height: 56 } }] }]);
    return (r.status === 1 && line(r.out, 'box-h') === 'box-h: ok' && /^box-h-bad: fail: #panel is 100px high, expected 56/.test(line(r.out, 'box-h-bad'))) || JSON.stringify(r);
  });
  check('visible: an element that sticks out past the right edge of the viewport is not visible', async () => {
    const r = await run([{ id: 'past-edge', page: okPage, viewport: 'mobile', expect: [{ visible: '#wide' }] }]);
    return (r.status === 1 && /^past-edge: fail: #wide is not visible/.test(line(r.out, 'past-edge'))) || JSON.stringify(r);
  });
  check('box: a selector that matches nothing fails', async () => {
    const r = await run([{ id: 'box-none', page: okPage, expect: [{ box: { selector: '#missing', width: 10 } }] }]);
    return (r.status === 1 && /^box-none: fail: #missing matched nothing/.test(line(r.out, 'box-none'))) || JSON.stringify(r);
  });

  // An entry of negatives only passes on a blank or forbidden render, and an empty text is in every page
  check('an entry whose expectations are all negative (noText, count 0) fails: it would pass on a blank page', async () => {
    const r = await run([{ id: 'neg-only', page: okPage, expect: [{ noText: 'Nothing like this' }, { selector: '#missing', count: 0 }] }]);
    return (r.status === 1 && /^neg-only: fail: no positive expectation/.test(line(r.out, 'neg-only'))) || JSON.stringify(r);
  });
  check('a count of 0 alone is not a positive expectation', async () => {
    const r = await run([{ id: 'zero-only', page: okPage, expect: [{ selector: '#missing', count: 0 }] }]);
    return (r.status === 1 && /^zero-only: fail: no positive expectation/.test(line(r.out, 'zero-only'))) || JSON.stringify(r);
  });
  check('an empty text is rejected (every page includes "")', async () => {
    const r = await run([{ id: 'empty-text', page: okPage, expect: [{ text: '' }] }, { id: 'empty-text-2', page: okPage, expect: [{ text: 'Fixture page' }, { text: '' }] }]);
    return (r.status === 1 && /^empty-text: fail: empty text/.test(line(r.out, 'empty-text')) && /^empty-text-2: fail: empty text/.test(line(r.out, 'empty-text-2'))) || JSON.stringify(r);
  });
  check('negatives beside one positive expectation still run (noText present fails)', async () => {
    const r = await run([{ id: 'mixed', page: okPage, expect: [{ text: 'Fixture page' }, { selector: '#missing', count: 0 }] }, { id: 'mixed-bad', page: okPage, expect: [{ text: 'Fixture page' }, { noText: 'Fixture page' }] }]);
    return (r.status === 1 && line(r.out, 'mixed') === 'mixed: ok' && /^mixed-bad: fail: text "Fixture page" present/.test(line(r.out, 'mixed-bad'))) || JSON.stringify(r);
  });

  // Roles: mk.js falls back to the session role for a name it does not know, so a misspelt role must fail
  check('role: an unknown role fails (MK.inspect().roles, read from the page, when the config lists none)', async () => {
    const r = await run([{ id: 'bad-role', page: okPage, role: 'acountant', expect: [{ text: 'Fixture page' }] }]);
    return (r.status === 1 && /^bad-role: fail: unknown role acountant \(MK\.inspect\(\)\.roles: accountant, finmgr\)/.test(line(r.out, 'bad-role'))) || JSON.stringify(r);
  });
  check('role: a role in MK.inspect().roles is accepted', async () => {
    const r = await run([{ id: 'good-role', page: okPage, role: 'finmgr', expect: [{ text: 'Fixture page' }] }]);
    return (r.status === 0 && line(r.out, 'good-role') === 'good-role: ok') || JSON.stringify(r);
  });
  check('a text of spaces only is rejected as empty (every page with a space includes " ")', async () => {
    const r = await run([{ id: 'blank-text', page: okPage, expect: [{ text: 'Fixture page' }, { text: ' ' }] }]);
    return (r.status === 1 && /^blank-text: fail: empty text/.test(line(r.out, 'blank-text'))) || JSON.stringify(r);
  });
  check('attr with value null (the attribute is absent) is not a positive expectation on its own', async () => {
    const r = await run([{ id: 'attr-null', page: okPage, expect: [{ attr: { selector: '#panel', name: 'data-missing', value: null } }] }]);
    return (r.status === 1 && /^attr-null: fail: no positive expectation/.test(line(r.out, 'attr-null'))) || JSON.stringify(r);
  });
  check('attr with value null still runs beside a positive expectation (absent passes, present fails)', async () => {
    const r = await run([
      { id: 'attr-null-ok', page: okPage, expect: [{ text: 'Fixture page' }, { attr: { selector: '#panel', name: 'data-missing', value: null } }] },
      { id: 'attr-null-bad', page: okPage, expect: [{ text: 'Fixture page' }, { attr: { selector: '#panel', name: 'id', value: null } }] },
    ]);
    return (r.status === 1 && line(r.out, 'attr-null-ok') === 'attr-null-ok: ok' && /^attr-null-bad: fail: #panel \[id\] is "panel", expected null/.test(line(r.out, 'attr-null-bad'))) || JSON.stringify(r);
  });
  check('viewport: { width, height } loads the page at that window size (600px: the narrow #panel width)', async () => {
    const r = await run([{ id: 'vp-obj', page: okPage, viewport: { width: 600, height: 400 }, expect: [{ box: { selector: '#panel', width: 272 } }] }]);
    return (r.status === 0 && line(r.out, 'vp-obj') === 'vp-obj: ok') || JSON.stringify(r);
  });
  check('viewport: an object without a whole positive width and height fails', async () => {
    const r = await run([{ id: 'vp-bad', page: okPage, viewport: { width: 600 }, expect: [{ text: 'Fixture page' }] }]);
    return (r.status === 1 && /^vp-bad: fail: unknown viewport/.test(line(r.out, 'vp-bad'))) || JSON.stringify(r);
  });
  check('inside: a box within its container passes, one that sticks out fails, a hidden one passes (nothing painted outside)', async () => {
    const r = await run([
      { id: 'in-ok', page: okPage, expect: [{ inside: { selector: '#box-in', container: '#box' } }] },
      { id: 'in-spill', page: okPage, expect: [{ inside: { selector: '#box-spill', container: '#box' } }] },
      { id: 'in-gone', page: okPage, expect: [{ inside: { selector: '#box-gone', container: '#box' } }] },
    ]);
    return (r.status === 1 && line(r.out, 'in-ok') === 'in-ok: ok' && line(r.out, 'in-gone') === 'in-gone: ok'
      && /^in-spill: fail: #box-spill sticks out of #box by 30px/.test(line(r.out, 'in-spill'))) || JSON.stringify(r);
  });
  check('inside: a selector or container that matches nothing fails', async () => {
    const r = await run([
      { id: 'in-none', page: okPage, expect: [{ inside: { selector: '#missing', container: '#box' } }] },
      { id: 'in-nobox', page: okPage, expect: [{ inside: { selector: '#box-in', container: '#missing' } }] },
    ]);
    return (r.status === 1 && /^in-none: fail: #missing matched nothing/.test(line(r.out, 'in-none')) && /^in-nobox: fail: #missing matched nothing/.test(line(r.out, 'in-nobox'))) || JSON.stringify(r);
  });

  // `visible` passes a 2px label, so a floor on width
  check('box: minWidth passes at or above the floor and fails below it (#panel is 400px wide)', async () => {
    const r = await run([
      { id: 'min-ok', page: okPage, expect: [{ box: { selector: '#panel', minWidth: 400 } }] },
      { id: 'min-bad', page: okPage, expect: [{ box: { selector: '#panel', minWidth: 401 } }] },
    ]);
    return (r.status === 1 && line(r.out, 'min-ok') === 'min-ok: ok' && /^min-bad: fail: #panel is 400px wide, expected at least 401/.test(line(r.out, 'min-bad'))) || JSON.stringify(r);
  });
  check('box: minWidth fails on an element that is not rendered (display none has no width to measure)', async () => {
    const r = await run([{ id: 'min-hidden', page: okPage, expect: [{ box: { selector: '#hidden', minWidth: 1 } }] }]);
    return (r.status === 1 && /^min-hidden: fail: #hidden has no box \(not rendered\)/.test(line(r.out, 'min-hidden'))) || JSON.stringify(r);
  });
  check('box: minWidth that is not a number fails', async () => {
    const r = await run([{ id: 'min-nan', page: okPage, expect: [{ box: { selector: '#panel', minWidth: '40' } }] }]);
    return (r.status === 1 && /^min-nan: fail: box #panel minWidth "40" is not a number/.test(line(r.out, 'min-nan'))) || JSON.stringify(r);
  });

  // ?as= in the page query would skip the role check (mockupUrl keeps it when the entry has no role)
  check('page: ?as= in the page query fails (the role goes in role, where it is checked)', async () => {
    const r = await run([
      { id: 'as-bad', page: `${okPage}?as=acountant`, expect: [{ text: 'Fixture page' }] },
      { id: 'as-good', page: `${okPage}?x=1&as=finmgr`, expect: [{ text: 'Fixture page' }] },
    ]);
    return (r.status === 1 && /^as-bad: fail: page query sets \?as=/.test(line(r.out, 'as-bad')) && /^as-good: fail: page query sets \?as=/.test(line(r.out, 'as-good'))) || JSON.stringify(r);
  });

  // onTop: what the user sees at an element's centre (a toast under a modal dialog)
  check('onTop: an element on top passes, one covered by another fails naming the cover, one not rendered fails', async () => {
    const r = await run([
      { id: 'top-alone', page: okPage, expect: [{ onTop: '#alone' }] },
      { id: 'top-over', page: okPage, expect: [{ onTop: '#over' }] },
      { id: 'top-under', page: okPage, expect: [{ onTop: '#under' }] },
      { id: 'top-hidden', page: okPage, expect: [{ onTop: '#hidden' }] },
      { id: 'top-none', page: okPage, expect: [{ onTop: '#missing' }] },
    ]);
    return (r.status === 1 && line(r.out, 'top-alone') === 'top-alone: ok' && line(r.out, 'top-over') === 'top-over: ok'
      && /^top-under: fail: #under is covered at its centre by div#over/.test(line(r.out, 'top-under'))
      && /^top-hidden: fail: #hidden is not rendered/.test(line(r.out, 'top-hidden'))
      && /^top-none: fail: #missing matched nothing/.test(line(r.out, 'top-none'))) || JSON.stringify(r);
  });
  check('onTop: while a modal dialog is open, an element outside it fails (inert, under the top layer) and one inside it passes', async () => {
    const r = await run([
      { id: 'modal-out', page: `${P}modal.html`, expect: [{ onTop: '#note-out' }] },
      { id: 'modal-in', page: `${P}modal.html`, expect: [{ onTop: '#note-in' }] },
    ]);
    return (r.status === 1 && /^modal-out: fail: #note-out is covered at its centre by /.test(line(r.out, 'modal-out')) && line(r.out, 'modal-in') === 'modal-in: ok') || JSON.stringify(r);
  });
  check('onTop alone is a positive expectation', async () => {
    const r = await run([{ id: 'top-pos', page: okPage, expect: [{ onTop: '#alone' }, { noText: 'Nothing like this' }] }]);
    return (r.status === 0 && line(r.out, 'top-pos') === 'top-pos: ok') || JSON.stringify(r);
  });

  // fits: spill-check's own measure, scrollWidth - clientWidth at most 1px, on every rendered match
  check('fits: a box that holds its text passes, one whose text runs past it fails with the px over, a hidden match is skipped', async () => {
    const r = await run([
      { id: 'fit-ok', page: okPage, expect: [{ fits: '#fit-ok' }] },
      { id: 'fit-over', page: okPage, expect: [{ fits: '#fit-over' }] },
      { id: 'fit-all', page: okPage, expect: [{ fits: '.fit' }] },
      { id: 'fit-skip', page: okPage, expect: [{ fits: '#fit-ok, #fit-gone' }] },
    ]);
    return (r.status === 1 && line(r.out, 'fit-ok') === 'fit-ok: ok' && line(r.out, 'fit-skip') === 'fit-skip: ok'
      && /^fit-over: fail: #fit-over is \d+px wider than its box \(scrollWidth \d+, clientWidth 100\): "A line far wider/.test(line(r.out, 'fit-over'))
      && /^fit-all: fail: \.fit is \d+px wider than its box/.test(line(r.out, 'fit-all'))) || JSON.stringify(r);
  });
  check('fits: a selector that matches nothing, or only a match that is not rendered, fails; fits alone is positive', async () => {
    const r = await run([
      { id: 'fit-none', page: okPage, expect: [{ fits: '#missing' }] },
      { id: 'fit-hidden', page: okPage, expect: [{ fits: '#fit-gone' }] },
      { id: 'fit-pos', page: okPage, expect: [{ fits: '#fit-ok' }, { noText: 'Nothing like this' }] },
    ]);
    return (r.status === 1 && /^fit-none: fail: #missing matched nothing/.test(line(r.out, 'fit-none')) && /^fit-hidden: fail: #fit-gone is not rendered/.test(line(r.out, 'fit-hidden'))
      && line(r.out, 'fit-pos') === 'fit-pos: ok') || JSON.stringify(r);
  });
  check('fits on a select: one as wide as its chosen option passes, one narrower fails as cutting that option', async () => {
    const r = await run([
      { id: 'fit-sel-ok', page: okPage, expect: [{ fits: '#fit-sel-ok' }] },
      { id: 'fit-sel-cut', page: okPage, expect: [{ fits: '#fit-sel-cut' }] },
      { id: 'fit-sel-all', page: okPage, expect: [{ fits: 'select' }] },
    ]);
    return (r.status === 1 && line(r.out, 'fit-sel-ok') === 'fit-sel-ok: ok'
      && /^fit-sel-cut: fail: #fit-sel-cut cuts its chosen option "A long chosen option": 60px wide, its text needs \d+px$/.test(line(r.out, 'fit-sel-cut'))
      && /^fit-sel-all: fail: select cuts its chosen option "A long chosen option": 60px wide/.test(line(r.out, 'fit-sel-all'))) || JSON.stringify(r);
  });

  // New in the engine: roles from the config, a page with no roles, the pins, a missing page, sharding
  check('role: with roles in mockup.config.json, a listed role passes and an unknown one fails', async () => {
    const r = await run([
      { id: 'cfg-good', page: 'pages/plain.html', role: 'clerk', expect: [{ text: 'Fixture page' }] },
      { id: 'cfg-bad', page: 'pages/plain.html', role: 'accountant', expect: [{ text: 'Fixture page' }] },
    ], [], ROLES_MOCKUP);
    return (r.status === 1 && line(r.out, 'cfg-good') === 'cfg-good: ok' && /^cfg-bad: fail: unknown role accountant \(mockup\.config\.json roles: clerk, finmgr\)/.test(line(r.out, 'cfg-bad'))) || JSON.stringify(r);
  });
  check('role: a role on a page with no MK.inspect(), and no roles in the config, fails (it cannot be checked)', async () => {
    const r = await run([{ id: 'no-mk', page: `${P}no-mk.html`, role: 'finmgr', expect: [{ text: 'Fixture page' }] }]);
    return (r.status === 1 && /^no-mk: fail: cannot check role finmgr/.test(line(r.out, 'no-mk'))) || JSON.stringify(r);
  });
  check('--clock, --seed and --tz pin Date, Math.random and the time zone; the zone defaults to config timezoneId', async () => {
    const pinned = await run([{ id: 'pins', page: `${P}pins.html`, expect: [{ text: 'now 2026-10-28T09:00:00.000Z' }, { text: 'random 0.' }, { text: 'zone Africa/Kampala' }] }],
      ['--clock', '2026-10-28T09:00:00Z', '--seed', '20261028', '--tz', 'Africa/Kampala']);
    const rnd = (await run([{ id: 'rnd', page: `${P}pins.html`, expect: [{ text: 'random 0.' }, { text: 'zone UTC' }] }], ['--seed', '20261028'])).status;
    // mulberry32(20261028)'s first value, the one visual-diff --seed gives
    let a = 20261028 >>> 0; a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    const first = ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    const seeded = await run([{ id: 'seeded', page: `${P}pins.html`, expect: [{ text: `random ${first}` }] }], ['--seed', '20261028']);
    const bad = await run([{ id: 'x', page: okPage, expect: [{ text: 'Fixture page' }] }], ['--clock', 'not a date']);
    return (pinned.status === 0 && rnd === 0 && seeded.status === 0 && bad.status === 2 && /--clock not a date is not a date/.test(bad.out)) || JSON.stringify({ pinned, rnd, seeded, bad });
  });
  // Intl output carries U+00A0 and U+202F; a behaviours file is typed with plain spaces
  check('text and noText: whitespace is normalised on both sides (U+00A0, U+202F, runs, line breaks)', async () => {
    const page = `${P}spaces.html`;
    const r = await run([
      { id: 'sp-intl', page, expect: [{ text: 'UGX 1,250,000' }] },
      { id: 'sp-narrow', page, expect: [{ text: 'Due 9:00 AM' }] },
      { id: 'sp-runs', page, expect: [{ text: '  Total due\ntoday ' }] },
      { id: 'sp-absent', page, expect: [{ text: 'Spaces' }, { noText: 'UGX 1,250,000' }] },
      { id: 'sp-miss', page, expect: [{ text: 'UGX 1,250,001' }] },
    ]);
    return (r.status === 1 && ['sp-intl', 'sp-narrow', 'sp-runs'].every((id) => line(r.out, id) === `${id}: ok`)
      && line(r.out, 'sp-absent') === 'sp-absent: fail: text "UGX 1,250,000" present'
      && line(r.out, 'sp-miss') === 'sp-miss: fail: text "UGX 1,250,001" not found') || JSON.stringify(r);
  });
  check('a page file that does not exist fails', async () => {
    const r = await run([{ id: 'gone', page: 'pages/nope.html', expect: [{ text: 'Fixture page' }] }]);
    return (r.status === 1 && /^gone: fail: page not found \(pages\/nope\.html\)/.test(line(r.out, 'gone'))) || JSON.stringify(r);
  });
  check('--shard K/N: the shards run every entry once, and their merge equals the serial run', async () => {
    const entries = [
      { id: 's-1', page: okPage, expect: [{ text: 'Fixture page' }] },
      { id: 's-2', page: okPage, steps: [{ wait: 1400 }], expect: [{ visible: '#panel' }] },
      { id: 's-3', page: okPage, expect: [{ text: 'Nope' }] },
      { id: 's-4', page: okPage, expect: [{ fits: '#fit-ok' }] },
      { id: 's-5', page: okPage, expect: [{ box: { selector: '#panel', width: 400 } }] },
    ];
    const serial = await run(entries);
    const shards = await Promise.all([1, 2, 3].map((k) => run(entries, ['--shard', `${k}/3`])));
    const plan = planBehaviourShards(entries, 3).map((l) => l.map((b) => b.id));
    const merged = mergeBehaviourShards({ shards: plan, order: entries.map((b) => b.id), outputs: shards.map((s, i) => ({ k: i + 1, text: s.out, code: s.status })) });
    const ran = shards.flatMap((s) => s.out.split('\n').filter((l) => /^s-\d: /.test(l)).map((l) => l.split(':')[0])).sort();
    return (serial.status === 1 && merged.exitCode === 1 && merged.lines.join('\n') === serial.out && ran.join() === 's-1,s-2,s-3,s-4,s-5') || JSON.stringify({ serial, shards, merged });
  });
});
