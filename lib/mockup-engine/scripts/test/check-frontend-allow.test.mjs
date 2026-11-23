/**
 * check-frontend-allow.test.mjs: a comment `check-frontend-allow <rule>: <reason>` on the line
 * before a finding allows that one finding, listed and counted in the summary. It needs a reason, a
 * known rule, and a finding on the next line to allow; the dash rule cannot be allowed.
 * Run: node --test test/check-frontend-allow.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../check-frontend.mjs', import.meta.url));

function check(text) {
  const app = mkdtempSync(join(tmpdir(), 'check-frontend-allow-'));
  try {
    const path = join(app, 'src/components/primitives/A.tsx');
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, text);
    const r = spawnSync(process.execPath, [SCRIPT], { cwd: app, encoding: 'utf8' });
    return { status: r.status, out: `${r.stdout}${r.stderr}` };
  } finally {
    rmSync(app, { recursive: true, force: true });
  }
}

const styled = 'export const A = () => <span style={CLEAR} />;\n';

test('an allow comment with a reason allows the finding on the next line, and the summary says so', () => {
  const r = check(`// check-frontend-allow inline-style: clears the kit's own inline variable\n${styled}`);
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /1 allowed/);
  assert.match(r.out, /allowed  inline-style  clears the kit's own inline variable/);
});

test('a JSX comment form works too', () => {
  const r = check(`export const A = () => (\n  <>\n    {/* check-frontend-allow inline-style: a reason */}\n    <span style={CLEAR} />\n  </>\n);\n`);
  assert.equal(r.status, 0, r.out);
});

test('without the comment the finding stands', () => {
  const r = check(styled);
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /inline-style/);
});

test('an allow with no reason is a finding and allows nothing', () => {
  const r = check(`// check-frontend-allow inline-style:\n${styled}`);
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /allow .*reason/);
  assert.match(r.out, /inline-style  export/);
});

test('an allow for another rule does not cover this one', () => {
  const r = check(`// check-frontend-allow unsafe-html: wrong rule\n${styled}`);
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /inline-style  export/);
  assert.match(r.out, /allows nothing/);
});

test('an allow with nothing to allow on the next line is a finding', () => {
  const r = check(`// check-frontend-allow inline-style: stale\nexport const A = () => <span />;\n`);
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /allows nothing/);
});

test('an unknown rule, or the dash rule, cannot be allowed', () => {
  const unknown = check(`// check-frontend-allow no-such-rule: x\n${styled}`);
  assert.equal(unknown.status, 1, unknown.out);
  assert.match(unknown.out, /not a rule that can be allowed/);
  const dash = check(`// check-frontend-allow dash: x\nexport const A = () => <span title="a — b" />;\n`);
  assert.equal(dash.status, 1, dash.out);
  assert.match(dash.out, /dash  /);
});
