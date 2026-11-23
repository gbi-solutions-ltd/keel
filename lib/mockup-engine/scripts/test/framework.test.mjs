/**
 * framework.test.mjs: the inventory's design framework rules: a css-library or utility-css mockup loads
 * the framework's CSS from assets/vendor/ on every page and the file exists (framework-css); a js-kit
 * mockup declares diff.maxMismatchPercent, domOracle.opaqueComponents and has docs/behaviours.json
 * (framework-gate); a utility-css mockup needs no components.css block per component (no-css-block).
 * Run: node --test test/framework.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const INVENTORY = fileURLToPath(new URL('../inventory.mjs', import.meta.url));
const FIXTURE = fileURLToPath(new URL('./fixtures/framework', import.meta.url));
const MK_JS = fileURLToPath(new URL('../../templates/mockup-starter/assets/mk.js', import.meta.url));

function inventory(dir) {
  const out = mkdtempSync(join(tmpdir(), 'framework-inv-'));
  return new Promise((done) => {
    execFile(process.execPath, [INVENTORY, dir, '--out', out], { timeout: 120000 }, (err, stdout, stderr) => {
      const json = existsSync(join(out, 'inventory.json')) ? JSON.parse(readFileSync(join(out, 'inventory.json'), 'utf8')) : null;
      rmSync(out, { recursive: true, force: true });
      done({ code: err ? err.code : 0, out: stdout + stderr, json });
    });
  });
}
// The inventory serves the mockup over HTTP from its own folder (lib/serve.mjs), so mk.js must be
// inside it: a copy of the fixture gets assets/mk.js, and its pages point there.
function served(dir, pages) {
  mkdirSync(join(dir, 'assets'), { recursive: true });
  cpSync(MK_JS, join(dir, 'assets', 'mk.js'));
  for (const f of pages) {
    const p = join(dir, 'pages', f);
    writeFileSync(p, readFileSync(p, 'utf8').replace('../../../../../templates/mockup-starter/assets/mk.js', '../assets/mk.js'));
  }
}
const rules = (json, rule) => json.lint.filter((l) => l.rule === rule).map((l) => `${l.where}: ${l.detail}`);

test('css-library: a page without the vendor CSS, or linking a file that is not there, is lint', { timeout: 150000 }, async () => {
  const tmp = mkdtempSync(join(tmpdir(), 'framework-css-'));
  try {
    const dir = join(tmp, 'm');
    cpSync(FIXTURE, dir, { recursive: true });
    served(dir, ['with.html', 'without.html', 'missing.html']);
    const r = await inventory(dir);
    const css = rules(r.json, 'framework-css');
    assert.equal(css.length, 2, css.join('\n'));
    assert.ok(css.some((l) => l.startsWith('pages/without.html: project.designFramework is css-library (kit)')), css.join('\n'));
    assert.ok(css.some((l) => l.startsWith('pages/missing.html: ../assets/vendor/kit/gone.css is not there')), css.join('\n'));
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test('js-kit: the tolerance and the behaviours must be declared; with both, no framework lint', { timeout: 200000 }, async () => {
  const tmp = mkdtempSync(join(tmpdir(), 'framework-fix-'));
  try {
    const dir = join(tmp, 'm');
    cpSync(FIXTURE, dir, { recursive: true });
    served(dir, ['with.html', 'without.html', 'missing.html']);
    const cfg = JSON.parse(readFileSync(join(dir, 'mockup.config.json'), 'utf8'));
    cfg.project.designFramework = { kind: 'js-kit', name: 'a component kit' };
    cfg.screens = [cfg.screens[1]];
    writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify(cfg));
    const bare = await inventory(dir);
    assert.deepEqual(rules(bare.json, 'framework-css'), [], 'a js-kit loads no vendor CSS');
    assert.equal(rules(bare.json, 'framework-gate').length, 3, rules(bare.json, 'framework-gate').join('\n'));
    writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify({ ...cfg, diff: { maxMismatchPercent: 2 }, domOracle: { opaqueComponents: ['Button'] } }));
    mkdirSync(join(dir, 'docs'), { recursive: true });
    writeFileSync(join(dir, 'docs/behaviours.json'), '[]');
    const declared = await inventory(dir);
    assert.deepEqual(rules(declared.json, 'framework-gate'), []);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test('utility-css: components styled by classes need no components.css block', { timeout: 150000 }, async () => {
  const tmp = mkdtempSync(join(tmpdir(), 'framework-uc-'));
  try {
    const dir = join(tmp, 'm');
    cpSync(FIXTURE, dir, { recursive: true });
    served(dir, ['with.html', 'without.html', 'missing.html']);
    // A component of our own, styled by utility classes in its template, with no components.css.
    const page = join(dir, 'pages', 'with.html');
    writeFileSync(page, readFileSync(page, 'utf8').replace("<script>MK.page(", "<script>MK.component('GoButton', () => MK.html`<button class=\"kit-button px-2\" type=\"button\">Go</button>`, { layer: 'primitive' });</script>\n<script>MK.page(").replace("render: () => MK.html`<button class=\"kit-button\" type=\"button\">Go</button>`", "render: () => MK.components.GoButton()"));
    const cfg = JSON.parse(readFileSync(join(dir, 'mockup.config.json'), 'utf8'));
    const before = await inventory(dir);
    const blocks = rules(before.json, 'no-css-block');
    assert.ok(blocks.length > 0, 'the fixture has a component with no block, as css-library');
    cfg.project.designFramework = { ...cfg.project.designFramework, kind: 'utility-css' };
    writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify(cfg));
    const after = await inventory(dir);
    assert.deepEqual(rules(after.json, 'no-css-block'), []);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
