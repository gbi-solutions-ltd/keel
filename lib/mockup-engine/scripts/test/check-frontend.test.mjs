/**
 * check-frontend.test.mjs: each Vue form the rules must catch is planted in a throwaway app and
 * caught, a clean component passes, and the React forms still fire.
 * Run: node --test test/check-frontend.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../check-frontend.mjs', import.meta.url));

/** Writes files into a fresh app folder, runs the check from it, returns { status, out }. */
function check(files) {
  const app = mkdtempSync(join(tmpdir(), 'check-frontend-'));
  try {
    for (const [path, text] of Object.entries(files)) {
      mkdirSync(dirname(join(app, path)), { recursive: true });
      writeFileSync(join(app, path), text);
    }
    try {
      const out = execFileSync('node', [SCRIPT, 'src'], { cwd: app, encoding: 'utf8' });
      return { status: 0, out };
    } catch (e) {
      return { status: e.status, out: `${e.stdout}${e.stderr}` };
    }
  } finally {
    rmSync(app, { recursive: true, force: true });
  }
}

const clean = `<template>\n  <span class="badge">{{ label }}</span>\n</template>\n<script setup lang="ts">\ndefineProps<{ label: string }>();\n</script>\n<style>\n.badge { color: var(--text); }\n</style>\n`;

test('a clean Vue component passes', () => {
  const r = check({ 'src/components/primitives/Badge.vue': clean });
  assert.equal(r.status, 0, r.out);
});

const plants = [
  ['raw-value in a .vue <style> block', 'src/components/primitives/A.vue', '<style>\n.a { margin: 0; outline-color: #ff0000; }\n.b { box-shadow: 0 0 1px rgb(0 0 0); }\n</style>\n', 'raw-value'],
  ['v-bind:style', 'src/components/primitives/B.vue', '<template>\n  <div v-bind:style="s"></div>\n</template>\n', 'inline-style'],
  ['style= on its own line', 'src/components/primitives/C.vue', '<template>\n  <div\n    style="color: var(--text)"\n  ></div>\n</template>\n', 'inline-style'],
  [':innerHTML', 'src/components/primitives/D.vue', '<template>\n  <div :innerHTML="html"></div>\n</template>\n', 'unsafe-html'],
  ['v-bind:innerHTML', 'src/components/primitives/E.vue', '<template>\n  <div v-bind:innerHTML="html"></div>\n</template>\n', 'unsafe-html'],
  ['layer-import through the @/ alias', 'src/components/primitives/F.vue', "<script setup lang=\"ts\">\nimport X from '@/components/domain/X.vue';\n</script>\n", 'layer-import'],
  ['layer-import through a dynamic import()', 'src/components/primitives/G.ts', "export const load = () => import('../domain/X.vue');\n", 'layer-import'],
  ['React inline style prop still fires', 'src/components/primitives/H.tsx', 'export const H = () => <div style={{ color: "red" }} />;\n', 'inline-style'],
];

for (const [name, path, text, rule] of plants) {
  test(`catches ${name}`, () => {
    const r = check({ [path]: text });
    assert.equal(r.status, 1, r.out);
    assert.match(r.out, new RegExp(rule), r.out);
  });
}

test('public-secret scans a mode file such as .env.mocked', () => {
  const r = check({ 'src/main.ts': 'export {};\n', '.env.mocked': 'VITE_API_TOKEN=abc\n' });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /public-secret/, r.out);
});

// ---- unknown-layer ----------------------------------------------------------------------------

test('unknown-layer: a folder under components/ that is not a layer is flagged once, by folder', () => {
  const r = check({
    'src/components/adapters/Grid.tsx': 'export {};\n',
    'src/components/adapters/Table.tsx': 'export {};\n',
    'src/pages/orders/components/widgets/Row.tsx': 'export {};\n',
  });
  assert.equal(r.status, 1, r.out);
  const lines = r.out.split('\n').filter((l) => l.includes('unknown-layer'));
  assert.deepEqual(lines.map((l) => l.split('  ')[0]), ['src/components/adapters', 'src/pages/orders/components/widgets']);
  assert.match(lines[0], /adapters\/ is not a layer \(primitives, composites, domain, layout, pages\)/);
});

test('unknown-layer: layer folders, a file directly in components/ and a sub-folder of a layer pass', () => {
  const r = check({
    'src/components/index.ts': 'export {};\n',
    'src/components/primitives/Badge.tsx': 'export {};\n',
    'src/components/domain/invoice/InvoiceRow.tsx': 'export {};\n',
    'src/components/layout/Shell.tsx': 'export {};\n',
  });
  assert.equal(r.status, 0, r.out);
});

// ---- comments spanning lines ------------------------------------------------------------------

test('lines inside a multi-line HTML comment are not code; code after --> is', () => {
  const vue = '<template>\n  <!--\n    <div style="color: red" v-html="x"></div>\n  -->\n  <span>ok</span>\n</template>\n';
  assert.equal(check({ 'src/components/primitives/A.vue': vue }).status, 0);
  const html = '<main>\n<p>a</p> <!-- note:\n  <div style="x"></div>\n--> <div v-html="y"></div>\n</main>\n';
  const r = check({ 'src/index.html': html });
  assert.equal(r.status, 1, r.out);
  assert.deepEqual(r.out.split('\n').filter((l) => /^src/.test(l)).map((l) => l.split('  ').slice(0, 2).join(' ')), ['src/index.html:4 unsafe-html']);
});

test('lines inside a multi-line JSX or block comment are not code; a glob in a string opens nothing', () => {
  const tsx = 'export const A = () => (\n  <div>\n    {/*\n      <p style={{ color: "red" }} />\n    */}\n  </div>\n);\n/*\n  localStorage.setItem("token", t);\n*/\n';
  assert.equal(check({ 'src/components/primitives/A.tsx': tsx }).status, 0);
  const glob = "const files = '**/*.ts';\nexport const B = () => <div dangerouslySetInnerHTML={x} />;\n";
  const r = check({ 'src/components/primitives/B.tsx': glob });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /B\.tsx:2  unsafe-html/);
});

test('the dash rule still fires inside a multi-line comment', () => {
  const r = check({ 'src/components/primitives/A.vue': '<template>\n  <!--\n    a note \u2014 here\n  -->\n</template>\n' });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /A\.vue:3  dash/);
});

// ---- named colours ----------------------------------------------------------------------------

test('named colours on colour properties in CSS and .vue <style> are raw values', () => {
  const css = [
    '.a { color: red; }',
    '.b {',
    '  border: 1px solid Black;',
    '  box-shadow: 0 0 0 1px white;',
    '}',
    '.c { background-color: var(--x); outline-color: navy; }',
    '.d:hover{fill:green}',
    '.e { text-decoration-color: rebeccapurple; }',
  ].join('\n');
  const r = check({ 'src/styles/app.css': css, 'src/components/primitives/A.vue': '<template><i /></template>\n<style scoped>\n.x { stroke: tomato; }\n</style>\n' });
  assert.equal(r.status, 1, r.out);
  const got = r.out.split('\n').filter((l) => /named colour/.test(l)).map((l) => l.replace(/:\s.*$/, '').replace(/  raw-value  named colour /, ' '));
  assert.deepEqual(got.sort(), ['src/components/primitives/A.vue:3 tomato', 'src/styles/app.css:1 red', 'src/styles/app.css:3 Black', 'src/styles/app.css:4 white', 'src/styles/app.css:6 navy', 'src/styles/app.css:7 green', 'src/styles/app.css:8 rebeccapurple']);
});

test('named colours: keywords, class names, var() fallbacks, url(), strings, prose, tokens and scripts pass', () => {
  const css = [
    '.text-red { color: var(--danger); }',
    '.border.red:hover { border-color: var(--a, var(--b, red)); }',
    '.f { color: transparent; background: currentColor; fill: inherit; stroke: initial; outline-color: unset; }',
    '.g { background: url(red.png) no-repeat; }',
    '.h::after { content: "red"; color: var(--text); }',
    '.i { transition: color 0.2s, background-color 0.2s; }',
    '@media (prefers-color-scheme: dark) { .j { color: var(--text); } }',
    '.k { width: 10px; } /* color: red */',
    '.l { font-weight: bold; }',
  ].join('\n');
  const r = check({
    'src/styles/app.css': css,
    'src/styles/tokens.css': ':root { --danger: red; }\n.x { color: red; }\n',
    'src/components/primitives/A.vue': '<template>\n  <p class="red">Paint it red: color: red</p>\n</template>\n<style>\n.a { color: var(--text); }\n</style>\n',
    'src/components/primitives/B.tsx': "export const tone = { color: 'red' };\n",
  });
  assert.equal(r.status, 0, r.out);
});

const orval = (formatter) => `import { defineConfig } from 'orval';
// formatter: in a comment counts for nothing
export default defineConfig({
  client: {
    input: { target: './api/openapi.yaml' },
    output: { target: './src/api/generated/endpoints.ts', schemas: './src/api/generated/model', client: 'react-query'${formatter ? ", formatter: 'biome'" : ''} },
  },
  zod: { input: { target: './api/openapi.yaml' }, output: { target: './src/api/generated/zod.ts', client: 'zod', formatter: 'biome' } },
});
`;
const biome = (excludes) => JSON.stringify({ files: { includes: ['**', '!dist', ...excludes] } });
const badge = { 'src/components/primitives/Badge.vue': clean };

test('generated-format: an Orval output with no formatter is caught', () => {
  const r = check({ ...badge, 'orval.config.ts': orval(false), 'biome.json': biome([]) });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /generated-format {2}1 of 2 outputs set no formatter/);
});

test('generated-format: biome.json excluding the Orval output folder is caught', () => {
  const r = check({ ...badge, 'orval.config.ts': orval(true), 'biome.json': biome(['!src/api/generated']) });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /excludes src\/api\/generated, Orval's output/);
});

test('generated-format: formatted outputs in scope, and an unrelated excluded generated folder, pass', () => {
  const r = check({ ...badge, 'orval.config.ts': orval(true), 'biome.json': biome(['!src/theme/generated']) });
  assert.equal(r.status, 0, r.out);
});

test('generated-format: vcs.useIgnoreFile with Orval\'s folder in .gitignore is caught', () => {
  const vcs = JSON.stringify({ files: { includes: ['**'] }, vcs: { enabled: true, clientKind: 'git', useIgnoreFile: true } });
  const r = check({ ...badge, 'orval.config.ts': orval(true), 'biome.json': vcs, '.gitignore': 'node_modules/\nsrc/api/generated/\n' });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /vcs.useIgnoreFile skips src\/api\/generated/);
  const off = check({ ...badge, 'orval.config.ts': orval(true), 'biome.json': vcs, '.gitignore': 'node_modules/\n' });
  assert.equal(off.status, 0, off.out);
});
