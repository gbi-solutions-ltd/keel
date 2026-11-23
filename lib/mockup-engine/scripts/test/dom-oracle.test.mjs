/**
 * dom-oracle.test.mjs: the DOM oracle's normaliser and diff (lib/dom-oracle.mjs), the CLI's file
 * mode and refusals, and --reference: its verdicts (pure), its refusals (no browser), and two small
 * case-mode runs against a local app server (the only tests that launch a browser).
 * Run: node --test test/dom-oracle.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { changeCount, compare, compareWithReference, decode, editScript, normalise, optionsFromConfig, route, tokenize, unified } from '../lib/dom-oracle.mjs';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/dom-oracle', import.meta.url));
const cli = (...args) => spawnSync(process.execPath, [join(SCRIPTS, 'dom-oracle.mjs'), ...args], { encoding: 'utf8' });

test('decode handles the serialiser entities and numeric references', () => {
  assert.equal(decode('a&amp;b&lt;c&gt;&quot;&nbsp;&#39;&#x41;&#66;&bogus;'), 'a&b<c>" \'AB&bogus;');
});

test('route maps mockup pages and app paths to the same key, keeps hashes and URLs', () => {
  assert.equal(route('./ledger-journals.html?tab=draft'), 'R:ledger-journals');
  assert.equal(route('home.html'), 'R:home');
  assert.equal(route('../pages/home.html#top'), 'R:home');
  assert.equal(route('/ledger/journals'), 'R:ledger-journals');
  assert.equal(route('/'), 'R:');
  assert.equal(route('#main'), '#main');
  assert.equal(route('https://example.com/x'), 'https://example.com/x');
});

test('tokenize reads quoted, unquoted and boolean attributes, self-closing tags and raw text', () => {
  const t = tokenize(`<div a="1" b='2' c=3 d><br/><svg><path d="M0"/></svg><style>a<b{}</style>x</div>`);
  assert.deepEqual(t[0], { type: 'start', tag: 'div', attrs: [['a', '1'], ['b', '2'], ['c', '3'], ['d', null]], selfClosing: false });
  assert.equal(t[1].tag, 'br');
  assert.equal(t[1].selfClosing, true);
  assert.deepEqual(t.find((x) => x.type === 'text'), { type: 'text', text: 'a<b{}' });
  assert.deepEqual(t.at(-2), { type: 'text', text: 'x' });
});

test('normalise indents by depth, sorts attributes and classes, drops comments and blank text', () => {
  const lines = normalise('<div z="1" class="b  a" a="2"><!--c--> <span>hi  there</span><br><i></i></div>');
  assert.deepEqual(lines, ['<div a="2" class="a b" z="1">', '  <span >', '    T:hi there', '  <br >', '  <i >']);
});

test('normalise lowercases names as html.parser does', () => {
  assert.deepEqual(normalise('<svg viewBox="0 0 1 1"><linearGradient></linearGradient></svg>'), ['<svg viewbox="0 0 1 1">', '  <lineargradient >']);
});

test('normalise drops data-v-*, the default plumbing attributes and an empty class', () => {
  assert.deepEqual(normalise('<a data-v-12ab="" data-action="x" data-group="g" data-on="cancel" class=" ">k</a>'), ['<a data-on="cancel">', '  T:k']);
  assert.deepEqual(normalise('<a data-action="x">k</a>', { dropAttributes: [] }), ['<a data-action="x">', '  T:k']);
});

test('normalise skips a hidden plumbing button and its subtree only when listed', () => {
  const html = '<button hidden="" data-action="closeMenus"><span>x</span></button><button hidden="" id="tour-unavailable">t</button><p>k</p>';
  assert.deepEqual(normalise(html, { skipHiddenActions: ['closeMenus'], skipHiddenIds: ['tour-unavailable'] }), ['<p >', '  T:k']);
  assert.equal(normalise(html).length, 7);
  // not hidden: kept even when its action is listed
  assert.equal(normalise('<button data-action="closeMenus">x</button>', { skipHiddenActions: ['closeMenus'] }).length, 2);
});

test('normalise keeps attributes, not properties: a missing value attribute shows', () => {
  assert.deepEqual(normalise('<input value="5">'), ['<input value="5">']);
  assert.deepEqual(normalise('<input>'), ['<input >']);
});

test('edge strips whitespace at the edges of a text node only', () => {
  assert.deepEqual(normalise('<b> Save  view </b>'), ['<b >', '  T: Save view ']);
  assert.deepEqual(normalise('<b> Save  view </b>', { edge: true }), ['<b >', '  T:Save view']);
});

/** LCS length by dynamic programming, the reference for the edit script's minimality. */
function lcs(a, b) {
  const t = Array.from({ length: a.length + 1 }, () => new Array(b.length + 1).fill(0));
  for (let i = 1; i <= a.length; i++) for (let j = 1; j <= b.length; j++) t[i][j] = a[i - 1] === b[j - 1] ? t[i - 1][j - 1] + 1 : Math.max(t[i - 1][j], t[i][j - 1]);
  return t[a.length][b.length];
}

test('editScript rebuilds both sides and is minimal (random inputs)', () => {
  let seed = 7;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
  for (let run = 0; run < 300; run++) {
    const gen = () => Array.from({ length: Math.floor(rnd() * 25) }, () => 'abcde'[Math.floor(rnd() * 5)]);
    const a = gen();
    const b = gen();
    const s = editScript(a, b);
    assert.deepEqual(s.filter((e) => e.op !== '+').map((e) => e.line), a);
    assert.deepEqual(s.filter((e) => e.op !== '-').map((e) => e.line), b);
    assert.equal(changeCount(s), a.length + b.length - 2 * lcs(a, b));
  }
});

test('unified prints hunks with context and is empty for no change', () => {
  assert.equal(unified(editScript(['a', 'b'], ['a', 'b'])), '');
  const text = unified(editScript(['1', '2', '3', '4', '5', '6', '7', '8'], ['1', '2', '3', 'X', '5', '6', '7', '8']));
  assert.equal(text, ['--- mockup', '+++ app', '@@ -2,5 +2,5 @@', ' 2', ' 3', '-4', '+X', ' 5', ' 6'].join('\n'));
});

test('compare counts edge whitespace apart from real differences', () => {
  const same = compare('<b> Save </b>', '<b>Save</b>');
  assert.equal(same.diffLines, 0);
  assert.equal(same.edgeLines, 2);
  assert.equal(same.diff, '');
  assert.match(same.strictDiff, /-  T: Save /);
  const real = compare('<b>Save</b>', '<b>Saved</b>');
  assert.equal(real.diffLines, 2);
  assert.equal(real.edgeLines, 0);
});

test('optionsFromConfig validates the domOracle section', () => {
  assert.deepEqual(optionsFromConfig({}), { options: {} });
  assert.deepEqual(optionsFromConfig({ domOracle: { skipHiddenIds: ['x'], root: '#root' } }), { options: { skipHiddenIds: ['x'] }, root: '#root' });
  assert.match(optionsFromConfig({ domOracle: [] }).error, /must be an object/);
  assert.match(optionsFromConfig({ domOracle: { skipHiddenIds: 'x' } }).error, /array of strings/);
  assert.match(optionsFromConfig({ domOracle: { skipHidden: [] } }).error, /unknown keys: skipHidden/);
  assert.match(optionsFromConfig({ domOracle: { root: 1 } }).error, /selector string/);
});

test('CLI file mode: fixture pair differs only by the dropped value attribute, edge lines counted', () => {
  const r = cli('--diff', join(FIXTURE, 'mockup.html'), join(FIXTURE, 'app.html'), '--config', join(FIXTURE, 'mockup.config.json'));
  assert.equal(r.status, 1, r.stderr);
  assert.match(r.stdout, /-  <input type="text" value="5">\n\+  <input type="text">/);
  assert.match(r.stdout, /diff lines 2, edge lines 2$/m);
  // without the config the hidden plumbing button counts too
  const bare = cli('--diff', join(FIXTURE, 'mockup.html'), join(FIXTURE, 'app.html'));
  assert.match(bare.stdout, /diff lines 4, edge lines 2$/m);
});

test('CLI file mode: identical files exit 0', () => {
  const r = cli('--diff', join(FIXTURE, 'app.html'), join(FIXTURE, 'app.html'));
  assert.equal(r.status, 0);
  assert.match(r.stdout, /^IDENTICAL/);
});

test('CLI refuses bad arguments before any browser starts', () => {
  assert.match(cli('--diff', join(FIXTURE, 'app.html')).stderr, /takes two files/);
  assert.match(cli('--diff', join(FIXTURE, 'nope.html'), join(FIXTURE, 'app.html')).stderr, /missing .*nope\.html/);
  assert.match(cli('--mockup', FIXTURE).stderr, /--app <base-url> is required/);
  assert.match(cli('--mockup', FIXTURE, '--app', 'http://localhost:1', '--clock', 'soon').stderr, /--clock soon is not a date/);
  assert.match(cli('--mockup', FIXTURE, '--app', 'http://localhost:1').stderr, /no screen matches/);
  assert.match(cli('--mockup', FIXTURE, '--app', 'http://localhost:1', '--viewport', 'tv').stderr, /no viewport named tv/);
  for (const a of [['--diff', join(FIXTURE, 'app.html')], ['--mockup', FIXTURE]]) assert.equal(cli(...a).status, 2);
});

// ---- --reference --------------------------------------------------------------------------------

const row = (slug, diffLines, edgeLines = 0) => ({ slug, status: diffLines === 'error' ? 'error' : diffLines ? 'diff' : 'match', ...(diffLines === 'error' ? {} : { diffLines, edgeLines }) });

test('compareWithReference: worse, better, same, new, missing and not-run, with deltas', () => {
  const now = [row('a', 5, 1), row('b', 1, 3), row('c', 2), row('d', 'error'), row('e', 0), row('f', 'error'), row('g', 4)];
  const ref = [row('a', 2, 0), row('b', 4, 3), row('c', 2), row('d', 0), row('e', 'error'), row('f', 'error'), row('gone', 0), row('skipped', 1)];
  const r = compareWithReference(now, ref, ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'skipped']);
  const by = Object.fromEntries(r.cases.map((c) => [c.slug, c]));
  assert.deepEqual(by.a, { slug: 'a', verdict: 'worse', before: 2, after: 5, diffDelta: 3, edgeDelta: 1 });
  assert.deepEqual(by.b, { slug: 'b', verdict: 'better', before: 4, after: 1, diffDelta: -3, edgeDelta: 0 });
  assert.equal(by.c.verdict, 'same');
  assert.deepEqual(by.d, { slug: 'd', verdict: 'worse', before: 0, after: 'error', diffDelta: null, edgeDelta: null });
  assert.deepEqual(by.e, { slug: 'e', verdict: 'better', before: 'error', after: 0, diffDelta: null, edgeDelta: null });
  assert.equal(by.f.verdict, 'same');
  assert.deepEqual(by.g, { slug: 'g', verdict: 'new', before: null, after: 4, diffDelta: null, edgeDelta: null });
  assert.deepEqual(by.gone, { slug: 'gone', verdict: 'missing', before: 0, after: null, diffDelta: null, edgeDelta: null });
  assert.equal(by.skipped.verdict, 'not-run');
  assert.deepEqual(r.counts, { worse: 2, better: 2, same: 2, new: 1, 'new-error': 0, missing: 1, 'not-run': 1 });
});

test('compareWithReference: a case the reference never had that errors now is new-error, not new', () => {
  const r = compareWithReference([row('fresh', 'error'), row('also-fresh', 3)], []);
  const by = Object.fromEntries(r.cases.map((c) => [c.slug, c]));
  assert.deepEqual(by.fresh, { slug: 'fresh', verdict: 'new-error', before: null, after: 'error', diffDelta: null, edgeDelta: null });
  assert.equal(by['also-fresh'].verdict, 'new');
  assert.deepEqual(r.counts, { worse: 0, better: 0, same: 0, new: 1, 'new-error': 1, missing: 0, 'not-run': 0 });
});

test('compareWithReference: classified on diff lines only, more edge lines alone is the same', () => {
  const r = compareWithReference([row('a', 2, 9)], [row('a', 2, 0)]);
  assert.deepEqual(r.cases[0], { slug: 'a', verdict: 'same', before: 2, after: 2, diffDelta: 0, edgeDelta: 9 });
  assert.deepEqual(r.counts, { worse: 0, better: 0, same: 1, new: 0, 'new-error': 0, missing: 0, 'not-run': 0 });
});

const REF_FIXTURE = join(FIXTURE, 'reference');

test('CLI refuses a bad --reference before any browser starts (exit 2)', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'dom-oracle-ref-'));
  try {
    const base = ['--mockup', REF_FIXTURE, '--app', 'http://localhost:1', '--out', join(tmp, 'out')];
    const bad = (file, text) => { writeFileSync(join(tmp, file), text); return join(tmp, file); };
    const cases = [
      [join(tmp, 'nope.json'), /does not exist/],
      [tmp, /holds no report\.json/],
      [bad('a.json', '{'), /is not valid JSON/],
      [bad('b.json', '{"cases": [{"status": "match"}]}'), /not a dom-oracle report/],
      [bad('c.json', '{"viewport": "mobile", "cases": []}'), /was run at viewport mobile, this run is at desktop/],
    ];
    for (const [ref, msg] of cases) {
      const r = cli(...base, '--reference', ref);
      assert.equal(r.status, 2, r.stderr);
      assert.match(r.stderr, msg);
    }
    assert.match(cli(...base, '--reference').stderr, /--reference needs a value/);
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});

/** The app side for the reference fixture: /orders as the mockup draws it, /invoices one text off, /broken no #app. */
function appServer() {
  const pages = {
    '/orders': '<div id="app"><h1>Orders</h1><p>INV-0412</p></div>',
    '/invoices': '<div id="app"><h1>Invoices</h1><p>Total 13.00</p></div>',
    '/broken': '<main>no app root</main>',
  };
  const server = createServer((req, res) => {
    const body = pages[req.url.split('?')[0]];
    res.writeHead(body ? 200 : 404, { 'content-type': 'text/html' });
    res.end(`<!doctype html><html><body>${body ?? 'not found'}</body></html>`);
  });
  return new Promise((done) => server.listen(0, '127.0.0.1', () => done(server)));
}

const cliAsync = (...args) => new Promise((done) => {
  const p = spawn(process.execPath, [join(SCRIPTS, 'dom-oracle.mjs'), ...args]);
  let stdout = '';
  let stderr = '';
  p.stdout.on('data', (d) => { stdout += d; });
  p.stderr.on('data', (d) => { stderr += d; });
  p.on('close', (status) => done({ status, stdout, stderr }));
});

test('CLI case mode --reference: worse and missing fail, the summary is printed and written', { timeout: 120000 }, async () => {
  const server = await appServer();
  const tmp = mkdtempSync(join(tmpdir(), 'dom-oracle-ref-'));
  try {
    const app = `http://127.0.0.1:${server.address().port}`;
    // the default out dir passed as its own reference: it is read before this run replaces it
    const out = join(tmp, 'out');
    cpSync(REF_FIXTURE, join(tmp, 'm'), { recursive: true });
    writeFileSync(join(tmp, 'ref.json'), JSON.stringify({ viewport: 'desktop', cases: [
      row('orders--default--desktop', 2), row('invoices--default--desktop', 0), row('broken--default--desktop', 'error'), row('gone--default--desktop', 0),
    ] }));
    const outRef = join(out, 'report.json');
    cpSync(join(tmp, 'ref.json'), outRef, { recursive: true });
    const r = await cliAsync('--mockup', join(tmp, 'm'), '--app', app, '--out', out, '--reference', out);
    assert.equal(r.status, 1, r.stdout + r.stderr);
    assert.match(r.stdout, /^against the reference: 1 worse, 1 better, 1 same, 1 new, 1 missing$/m);
    assert.match(r.stdout, /^worse   invoices--default--desktop  0 -> 2 \(diff \+2, edge 0\)$/m);
    assert.match(r.stdout, /^better  orders--default--desktop  2 -> 0 \(diff -2, edge 0\)$/m);
    assert.match(r.stdout, /^missing gone--default--desktop  0 -> -$/m);
    assert.match(r.stdout, /^new     fresh--default--desktop  - -> 0$/m);
    const report = JSON.parse(readFileSync(join(out, 'report.json'), 'utf8'));
    assert.equal(report.reference.path, join(out, 'report.json'));
    assert.deepEqual(report.reference.counts, { worse: 1, better: 1, same: 1, new: 1, 'new-error': 0, missing: 1, 'not-run': 0 });
    assert.equal(report.reference.cases.find((c) => c.slug === 'broken--default--desktop').verdict, 'same');
    const md = readFileSync(join(out, 'report.md'), 'utf8');
    assert.match(md, /## Against the reference/);
    assert.match(md, /\| invoices--default--desktop \| worse \| 0 \| 2 \| \+2 \| 0 \|/);

    // filtered to one screen, now better: the others in the reference are not run, not missing; exit 0
    writeFileSync(join(tmp, 'ref2.json'), JSON.stringify({ viewport: 'desktop', cases: [row('orders--default--desktop', 2), row('invoices--default--desktop', 0), row('broken--default--desktop', 'error')] }));
    const r2 = await cliAsync('--mockup', join(tmp, 'm'), '--app', app, '--out', join(tmp, 'out2'), '--screen', 'orders', '--reference', join(tmp, 'ref2.json'));
    assert.equal(r2.status, 0, r2.stdout + r2.stderr);
    assert.match(r2.stdout, /^against the reference: 0 worse, 1 better, 0 same, 0 new, 0 missing, 2 not run$/m);
    assert.match(r2.stdout, /^not-run invoices--default--desktop  0 -> -$/m);

    // a case the reference never had that errors now fails the run: there is nothing to excuse it
    writeFileSync(join(tmp, 'ref3.json'), JSON.stringify({ viewport: 'desktop', cases: [row('orders--default--desktop', 0)] }));
    const r3 = await cliAsync('--mockup', join(tmp, 'm'), '--app', app, '--out', join(tmp, 'out3'), '--screen', 'broken', '--reference', join(tmp, 'ref3.json'));
    assert.equal(r3.status, 1, r3.stdout + r3.stderr);
    assert.match(r3.stdout, /^against the reference: 0 worse, 0 better, 0 same, 0 new, 0 missing, 1 new with an error, 1 not run$/m);
    assert.match(r3.stdout, /^new-error broken--default--desktop  - -> error$/m);
  } finally {
    server.close();
    rmSync(tmp, { recursive: true, force: true });
  }
});

test('opaqueComponents: a kit component is compared by place, name and copy, not by its inner DOM', () => {
  const opts = { opaqueComponents: ['Button', 'TextField'] };
  const mockup = '<section data-component="Panel"><button class="btn" data-component="Button"><span aria-hidden="true">+</span> Add</button><div data-component="TextField"><label>Subject <span aria-hidden="true">*</span></label><input></div></section>';
  const app = '<section data-component="Panel"><button class="MuiButton-root css-1x" data-component="Button" tabindex="0"><span class="MuiButton-startIcon"><svg><path d="M0"></path></svg></span>Add<span class="MuiTouchRipple-root"></span></button><div data-component="TextField" class="MuiFormControl-root"><label class="MuiInputLabel-root">Subject<span aria-hidden="true" class="MuiFormLabel-asterisk"> *</span></label><div class="MuiInputBase-root"><input class="MuiInputBase-input"><fieldset aria-hidden="true"><legend><span>Subject</span></legend></fieldset></div></div></section>';
  const lines = normalise(app, opts);
  assert.deepEqual(lines, normalise(mockup, opts));
  assert.deepEqual(lines, ['<section data-component="Panel">', '  <kit data-component="Button">', '    T:Add', '  <kit data-component="TextField">', '    T:Subject', ]);
  // Our own parts around a kit component are still compared, and so is a kit component's copy.
  assert.notDeepEqual(normalise(app.replace('Add<', 'Create<'), opts), normalise(mockup, opts));
  assert.notDeepEqual(normalise(app.replace('section', 'article').replace('/section', '/article'), opts), normalise(mockup, opts));
  // Without the option the same pair differs.
  assert.notDeepEqual(normalise(app), normalise(mockup));
});

test('the config\'s dropAttributes add to the defaults, and opaqueComponents is validated', () => {
  assert.deepEqual(optionsFromConfig({ domOracle: { dropAttributes: ['data-on'] } }).options.dropAttributes, ['data-action', 'data-group', 'data-on']);
  assert.deepEqual(optionsFromConfig({ domOracle: { opaqueComponents: ['Button'] } }).options, { opaqueComponents: ['Button'] });
  assert.match(optionsFromConfig({ domOracle: { opaqueComponents: 'Button' } }).error, /opaqueComponents must be an array/);
});

test('a mockup page link compares equal to the route the config declares for that page', () => {
  const pageRoutes = { 'my-requests': '/loans/mine', 'request-new': '/equipment/:item/request' };
  assert.equal(route('./request-new.html?item=itm_08', pageRoutes), route('/equipment/itm_08/request'));
  assert.equal(route('./request-new.html', pageRoutes), 'R:request-new', 'a param the link does not give leaves the file name');
  assert.equal(route('./my-requests.html', pageRoutes), route('/loans/mine'));
  assert.equal(route('my-requests.html?state=empty', pageRoutes), 'R:loans-mine');
  assert.equal(route('./other.html', pageRoutes), 'R:other', 'a page with no declared route keeps its file name');
  assert.deepEqual(normalise('<a href="./my-requests.html">x</a>', { pageRoutes }), normalise('<a href="/loans/mine">x</a>'));
});

test('--drop-attributes adds to the config\'s list in either mode, without editing the signed-off config', () => {
  const dir = mkdtempSync(join(tmpdir(), 'dom-oracle-drop-'));
  try {
    const a = join(dir, 'mockup.html');
    const b = join(dir, 'app.html');
    writeFileSync(a, '<div class="field" data-field="q" data-cursor="c1"><input name="q"></div>');
    writeFileSync(b, '<div class="field"><input name="q"></div>');
    assert.equal(cli('--diff', a, b).status, 1);
    const r = cli('--diff', a, b, '--drop-attributes', 'data-field, data-cursor');
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.match(r.stdout, /IDENTICAL/);
    const bad = cli('--diff', a, b, '--drop-attributes', '');
    assert.equal(bad.status, 2, bad.stdout + bad.stderr);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
