/**
 * inventory.test.mjs: tour anchors are judged over every config screen (gap 11), a page is
 * described per role (gap 14), a crash, no config or a bad config exits 2 (gap 19), pages are served
 * over HTTP, and lint or no pages exit 1 while
 * undecided checklist items do not; accepted findings (docs/inventory-accepted.json or --accepted)
 * pass, a new finding still fails, a stale entry warns, a bad file is refused (exit 2). Runs inventory.mjs on fixture
 * mockups whose pages stand in for mk.js with a stub MK.inspect().
 * Run: node --test test/inventory.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../inventory.mjs', import.meta.url));
const fixture = (name) => fileURLToPath(new URL(`./fixtures/inventory/${name}`, import.meta.url));

function run(args) {
  return new Promise((done) => {
    execFile(process.execPath, [SCRIPT, ...args], { timeout: 90000 }, (err, stdout, stderr) => done({ code: err ? err.code : 0, stdout, stderr }));
  });
}

async function inventoryOf(name, flag, extra) {
  return inventoryAt(fixture(name), flag, extra);
}

async function inventoryAt(dir, flag, extra = []) {
  const out = mkdtempSync(join(tmpdir(), 'inventory-test-'));
  try {
    const args = [...(flag ? ['--mockup', dir, '--out', out] : [dir, '--out', out]), ...extra];
    const r = await run(args);
    return { ...r, inventory: existsSync(join(out, 'inventory.json')) ? JSON.parse(readFileSync(join(out, 'inventory.json'), 'utf8')) : null };
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
}

test('a tour anchor counts when any screen of its page shows it: a state, a role or a step (gap 11)', { timeout: 120000 }, async () => {
  const { code, inventory } = await inventoryOf('ok');
  // its two lint issues (this tour-anchor and a module-page) make it exit 1
  assert.equal(code, 1);
  const anchors = inventory.lint.filter((l) => l.rule === 'tour-anchor');
  // b shows only in the empty state, c only for role x, d only after the Open step; e never.
  assert.deepEqual(anchors, [{ rule: 'tour-anchor', where: 'tour home', detail: 'no data-tour="e" on any screen of /home' }]);
});

test('a page is described once per distinct role among its screens, as that role (gap 14)', { timeout: 120000 }, async () => {
  const { stdout, inventory } = await inventoryOf('ok', true);
  // five screens: two without a role, one with role x, one with ?as=x in its page query, one as guest
  assert.deepEqual(inventory.pages.map((p) => [p.file, p.role, p.forbidden]), [['pages/home.html', null, false], ['pages/home.html', 'x', false], ['pages/home.html', 'guest', true]]);
  const names = (nodes) => nodes.flatMap((n) => [n.name, ...names(n.children || [])]);
  assert.deepEqual(names(inventory.pages[0].componentTree), ['Home']);
  assert.deepEqual(names(inventory.pages[1].componentTree), ['Home', 'XOnly']);
  assert.match(stdout, /^inventory: 1 pages \(3 views by role\), /m);
  // the guest sees the forbidden page in every state, so its loading and error states are not judged
  assert.deepEqual(inventory.lint.filter((l) => l.rule === 'missing-state'), []);
  // per-page lint is not repeated for each role
  const keys = inventory.lint.map((l) => `${l.rule}|${l.where}|${l.detail}`);
  assert.equal(new Set(keys).size, keys.length);
});

test('a crash exits 2 and prints no summary line (gap 19)', { timeout: 60000 }, async () => {
  const { code, stdout, stderr, inventory } = await inventoryOf('broken');
  assert.equal(code, 2, "a crash is exit 2, apart from 1 for findings");
  assert.match(stderr, /^inventory: failed: .*pages\/missing\.html: HTTP 404/m);
  assert.doesNotMatch(stdout, /^inventory: /m);
  assert.equal(inventory, null);
});

test('a lint-clean mockup exits 0, and undecided checklist items do not fail it', { timeout: 120000 }, async () => {
  const { code, stdout, inventory } = await inventoryOf('clean', true);
  assert.equal(code, 0, stdout);
  assert.match(stdout, /^inventory: 1 pages, 0 components, 0 lint issues /m);
  assert.match(stdout, /^checklist: 18 undecided /m);
  assert.deepEqual(inventory.lint, []);
});

test('lint issues exit 1, after the summary line', { timeout: 120000 }, async () => {
  const { code, stdout } = await inventoryOf('ok', true);
  assert.equal(code, 1);
  assert.match(stdout, /^inventory: 1 pages \(3 views by role\), 0 components, 2 lint issues /m);
});

test('no config, or one that is not a JSON object, exits 2 (could not run) before any page loads, as check-config does', { timeout: 60000 }, async () => {
  const empty = mkdtempSync(join(tmpdir(), 'inventory-empty-'));
  try {
    const none = await inventoryAt(empty, true);
    assert.equal(none.code, 2, none.stderr);
    assert.match(none.stderr, /^inventory: missing .*mockup\.config\.json/m);
    assert.doesNotMatch(none.stdout, /^inventory: /m);
    assert.equal(none.inventory, null);
    for (const [text, msg] of [['{ not json', /is not valid JSON/], ['null', /is not a JSON object/], ['[]', /is not a JSON object/]]) {
      writeFileSync(join(empty, 'mockup.config.json'), text);
      const r = await inventoryAt(empty, true);
      assert.equal(r.code, 2, `${text}: ${r.stderr}`);
      assert.match(r.stderr, msg, text);
      assert.doesNotMatch(r.stderr, /crashed|failed:/, text);
      assert.equal(r.inventory, null, text);
    }
  } finally { rmSync(empty, { recursive: true, force: true }); }
});

test('pages load over HTTP from a local server, not file:// (fetch works as in a browser)', { timeout: 120000 }, async () => {
  const dir = mkdtempSync(join(tmpdir(), 'inventory-served-'));
  try {
    cpSync(fixture('clean'), dir, { recursive: true });
    mkdirSync(join(dir, 'data'), { recursive: true });
    writeFileSync(join(dir, 'data', 'title.json'), JSON.stringify({ title: 'Fetched' }));
    const page = join(dir, 'pages', 'home.html');
    // the page's title comes from a request (synchronous, so it is there by load), which fails under file://
    writeFileSync(page, readFileSync(page, 'utf8').replace("title: 'Home'", 'title: window.FETCHED + location.protocol').replace('<script>', '<script>window.FETCHED = "none"; try { const x = new XMLHttpRequest(); x.open("GET", "../data/title.json", false); x.send(); window.FETCHED = JSON.parse(x.responseText).title; } catch {}</script><script>'));
    const { code, stderr, inventory } = await inventoryAt(dir, true);
    assert.equal(inventory.pages[0].title, 'Fetchedhttp:');
    assert.equal(code, 0, stderr);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('a config with no screens exits 1 on its own (0 pages; no screens listed is the one lint issue)', { timeout: 60000 }, async () => {
  const { code, stdout, stderr } = await inventoryOf('no-pages', true);
  assert.equal(code, 1);
  assert.match(stdout, /^inventory: 0 pages, 0 components, 1 lint issues /m);
  assert.match(stderr, /^inventory: no pages found/m);
});

// ---- accepted findings ----------------------------------------------------------------------

function tmpFile(name, data) {
  const dir = mkdtempSync(join(tmpdir(), 'inventory-accepted-'));
  const path = join(dir, name);
  writeFileSync(path, typeof data === 'string' ? data : JSON.stringify(data));
  return { path, done: () => rmSync(dir, { recursive: true, force: true }) };
}

test('accepted findings pass with their reason, a stale entry warns and does not fail', { timeout: 120000 }, async () => {
  const f = tmpFile('accepted.json', { accepted: [
    { rule: 'module-page', where: 'tours-help', reason: 'the help page is drawn in the next round' },
    { rule: 'tour-anchor', where: 'tour home', detail: 'data-tour="e"', reason: 'step e targets a panel not built yet' },
    { rule: 'dash', where: 'pages/home.html', reason: 'was fixed' },
  ] });
  try {
    const { code, stdout, stderr, inventory } = await inventoryOf('ok', true, ['--accepted', f.path]);
    assert.equal(code, 0, stdout + stderr);
    assert.match(stdout, /^inventory: 1 pages \(3 views by role\), 0 components, 0 lint issues, 2 accepted /m);
    assert.match(stderr, /^inventory: warning: stale accepted entry, matches no finding: dash at pages\/home\.html$/m);
    assert.deepEqual(inventory.lint, []);
    assert.deepEqual(inventory.accepted.map((a) => [a.rule, a.reason]), [['module-page', 'the help page is drawn in the next round'], ['tour-anchor', 'step e targets a panel not built yet']]);
    assert.deepEqual(inventory.acceptedStale, [{ rule: 'dash', where: 'pages/home.html', reason: 'was fixed' }]);
  } finally { f.done(); }
});

test('a finding the default docs/inventory-accepted.json does not cover still fails: where without a line, detail as a filter', { timeout: 120000 }, async () => {
  const dir = mkdtempSync(join(tmpdir(), 'inventory-accepted-mockup-'));
  try {
    cpSync(fixture('clean'), dir, { recursive: true });
    mkdirSync(join(dir, 'assets'));
    writeFileSync(join(dir, 'assets/base.css'), 'body { margin: 0; }\n.a { color: #fff; }\n.b { color: #000; }\n');
    mkdirSync(join(dir, 'docs'));
    writeFileSync(join(dir, 'docs/inventory-accepted.json'), JSON.stringify({ accepted: [
      { rule: 'raw-value', where: 'assets/base.css', detail: '#fff', reason: 'the print sheet white, kept as the client wrote it' },
      { rule: 'raw-value', where: 'assets/base.css:2', reason: 'overlaps the first: matched too, so not stale' },
    ] }));
    const { code, stdout, inventory } = await inventoryAt(dir, true);
    assert.equal(code, 1, stdout);
    assert.match(stdout, /^inventory: 1 pages, 0 components, 1 lint issues, 1 accepted /m);
    assert.deepEqual(inventory.accepted.map((a) => a.where), ['assets/base.css:2']);
    assert.deepEqual(inventory.lint.map((l) => [l.rule, l.where]), [['raw-value', 'assets/base.css:3']]);
    assert.deepEqual(inventory.acceptedStale, []);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('a bad accepted file is refused before any page loads, with no summary line: exit 2 (an invalid input file)', { timeout: 60000 }, async () => {
  const bad = [
    [{ accepted: [{ rule: 'dash', where: 'x' }] }, /accepted\[0\]\.reason is required/],
    [{ accepted: [{ rule: 'dash', where: 'x', reason: '  ' }] }, /accepted\[0\]\.reason is required/],
    [{ accepted: [{ rule: 'dash', where: 'x', reason: 'r', line: 3 }] }, /accepted\[0\] has unknown keys: line/],
    [{ accepted: [{ where: 'x', reason: 'r' }] }, /accepted\[0\]\.rule must be a non-empty string/],
    [{ accepted: [], notes: 'x' }, /unknown keys: notes/],
    [{ accepted: {} }, /"accepted" must be an array/],
    ['{', /not valid JSON/],
  ];
  for (const [data, msg] of bad) {
    const f = tmpFile('accepted.json', data);
    try {
      const { code, stdout, stderr } = await run(['--mockup', fixture('clean'), '--out', join(tmpdir(), 'inventory-never'), '--accepted', f.path]);
      assert.equal(code, 2, stderr);
      assert.match(stderr, msg);
      assert.doesNotMatch(stdout, /^inventory: /m);
    } finally { f.done(); }
  }
  const missing = await run(['--mockup', fixture('clean'), '--accepted', join(tmpdir(), 'no-such-accepted.json')]);
  assert.equal(missing.code, 2);
  assert.match(missing.stderr, /no-such-accepted\.json: missing/);
});
