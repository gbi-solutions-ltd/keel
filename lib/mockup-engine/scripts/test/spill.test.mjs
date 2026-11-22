/**
 * spill.test.mjs: spill-check.mjs on a fixture mockup (fixtures/spill) with known findings and known
 * non-findings, at one width. The fixture is copied to a temporary folder, since the tool writes into
 * the mockup it checks.
 * Run: node --test test/spill.test.mjs   (from scripts/)
 * SPILL_CHECK=<path to another spill-check.mjs> runs the same test against that version.
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const FIXTURE = fileURLToPath(new URL('./fixtures/spill', import.meta.url));
const TOOL = resolve(process.env.SPILL_CHECK || fileURLToPath(new URL('../spill-check.mjs', import.meta.url)));
const run = (...args) => spawnSync(process.execPath, [TOOL, ...args], { encoding: 'utf8', timeout: 120000 });

// element id: the kind it must be reported as
const FOUND = {
  'real-spill': 'spills', // a line wider than its box
  'carried': 'spills', // a spill past its card's edge: reported once, not again for the card
  'real-clip': 'clipped', // cut off with no ellipsis
  'bad-scroll': 'scrolls', // scrolls sideways, not a tab strip, region or configured selector
  'nest-inner': 'spills', // a spill inside a box ...
  'nest-outer': 'clipped', // ... whose own content runs further than the spill
  'mask-outer': 'spills', // a row past its box, holding an intended ellipsis label
  'locale-proof': 'spills', // exists only when the browser runs in the config's locale (fr-FR)
};
// none of these may be reported
const NOT_FOUND = [
  'spill-card', 'spill-only-card', // a card only carrying its child's spill up
  'ellipsis', 'mask-label', // text-overflow: ellipsis
  'marked-clip', // data-clip
  'tabs', 'region', 'config-scroll', // allowed to scroll: role="tablist", a labelled region, spill.scrollAllowed
  'popover', 'popover-button', 'popover-panel', 'fixed-wrap', 'fixed-bar', // positioned descendants
  'chip', 'who', 'who-role', 'who-role-2', // visually hidden by computed style, no class
];

let dir;
let result;
let rows;
before(() => {
  dir = mkdtempSync(join(tmpdir(), 'spill-fixture-'));
  cpSync(FIXTURE, dir, { recursive: true });
  result = run('--mockup', dir, '--widths', '600');
  rows = JSON.parse(readFileSync(join(dir, '.mockup-engine', 'spill.json'), 'utf8'));
});
after(() => { if (dir) rmSync(dir, { recursive: true, force: true }); });

const idOf = (row) => (row.el.match(/#([\w-]+)/) || [])[1] || row.el;

test('exits 1 with a summary line when it finds something', () => {
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stdout, /\n1 cases, \d+ spills, \d+ distinct\s*$/);
  assert.ok(!rows.some((r) => r.el === 'LOAD'), JSON.stringify(rows.filter((r) => r.el === 'LOAD')));
});

test('reports each known overflow, with its kind', () => {
  const got = Object.fromEntries(rows.map((r) => [idOf(r), r.kind]));
  for (const [id, kind] of Object.entries(FOUND)) assert.equal(got[id], kind, `${id}: ${JSON.stringify(rows)}`);
});

test('reports nothing else (intended truncation, allowed scrolling, popovers, hidden boxes)', () => {
  const ids = rows.map(idOf);
  for (const id of NOT_FOUND) assert.ok(!ids.includes(id), `${id} reported: ${JSON.stringify(rows.filter((r) => idOf(r) === id))}`);
  assert.deepEqual([...ids].sort(), Object.keys(FOUND).sort());
});

test('attributes a finding to a card from spill.cards', () => {
  const row = rows.find((r) => idOf(r) === 'real-spill');
  assert.equal(row?.card, 'section#spill-card.tile');
});

test('a --screen that matches nothing exits 2 (could not run) and says so', () => {
  const r = run('--mockup', dir, '--widths', '600', '--screen', 'no-such-screen');
  assert.equal(r.status, 2, r.stderr);
  assert.match(r.stderr, /no-such-screen.*matches no screen/);
});

test('a mockup it cannot read exits 2 (could not run) and says so', () => {
  const r = run('--mockup', join(dir, 'missing'), '--widths', '600');
  assert.equal(r.status, 2, r.stderr);
  assert.match(r.stderr, /mockup\.config\.json/);
});

test('pages load over HTTP from a local server, not file:// (fetch works as in a browser)', () => {
  const d = mkdtempSync(join(tmpdir(), 'spill-served-'));
  try {
    mkdirSync(join(d, 'pages'));
    mkdirSync(join(d, 'data'));
    writeFileSync(join(d, 'data', 'row.json'), JSON.stringify({ text: 'x'.repeat(400) }));
    // the spilling row exists only when the page is served: under file:// the fetch fails
    writeFileSync(join(d, 'pages', 'p.html'), '<!doctype html><html lang="en"><body><div id="box" style="width:100px;white-space:nowrap"></div><script>fetch("../data/row.json").then((r) => r.json()).then((j) => { document.getElementById("box").textContent = location.protocol + j.text; });</script></body></html>');
    writeFileSync(join(d, 'mockup.config.json'), JSON.stringify({ name: 'served', screens: [{ name: 'p', page: 'pages/p.html', route: '/p' }] }));
    const r = run('--mockup', d, '--widths', '600', '--out', join(d, 'out'));
    const found = JSON.parse(readFileSync(join(d, 'out', 'spill.json'), 'utf8'));
    assert.equal(r.status, 1, r.stderr);
    assert.ok(found.some((f) => f.el.includes('#box') && /^http:/.test(f.text)), JSON.stringify(found));
  } finally { rmSync(d, { recursive: true, force: true }); }
});

test('under another --locale a screen with steps is left out and listed; the run writes its own file', () => {
  const d = mkdtempSync(join(tmpdir(), 'spill-locale-'));
  try {
    cpSync(FIXTURE, d, { recursive: true });
    const cfgFile = join(d, 'mockup.config.json');
    const cfg = JSON.parse(readFileSync(cfgFile, 'utf8'));
    cfg.screens.push({ name: 'stepped', page: 'pages/cases.html', route: '/cases', steps: [{ click: { role: 'button', name: 'Nothing here' } }] });
    writeFileSync(cfgFile, JSON.stringify(cfg));
    const r = run('--mockup', d, '--widths', '600', '--locale', 'pseudo');
    assert.match(r.stdout, /--locale pseudo: 1 screens with steps left out .*: stepped/);
    assert.match(r.stdout, /^1 cases, /m);
    assert.ok(existsSync(join(d, '.mockup-engine', 'spill-locale-pseudo.json')));
    assert.ok(!existsSync(join(d, '.mockup-engine', 'spill.json')), 'the plain run\'s file is not written by a locale run');
  } finally {
    rmSync(d, { recursive: true, force: true });
  }
});
