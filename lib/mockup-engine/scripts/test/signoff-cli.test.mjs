/**
 * signoff-cli.test.mjs: signoff.mjs re-run on a mockup unchanged since its last round. Nothing new
 * is recorded, but --docs and --freeze are still honoured: the page is written and the frozen copy
 * made, so a re-run asked for a copy never exits 0 without one.
 * No browser. Run: node --test test/signoff-cli.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CHECKLIST } from '../lib/project.mjs';

const STARTER = fileURLToPath(new URL('../../templates/mockup-starter', import.meta.url));
const CONTRACT = fileURLToPath(new URL('./fixtures/signoff/openapi.yaml', import.meta.url));
const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const node = (script, ...args) => {
  const r = spawnSync(process.execPath, [join(SCRIPTS, script), ...args], { encoding: 'utf8', timeout: 150000 });
  return { code: r.status, out: r.stdout + r.stderr };
};

/** The starter with its intake answered, pinned, and a drafted contract: ready to sign off. */
function answeredStarter() {
  const dir = join(mkdtempSync(join(tmpdir(), 'signoff-cli-')), 'mockup');
  cpSync(STARTER, dir, { recursive: true });
  const file = join(dir, 'mockup.config.json');
  const c = JSON.parse(readFileSync(file, 'utf8'));
  c.timezoneId = 'Africa/Kampala';
  c.pins = { clock: '2026-10-28T09:00:00Z', seed: 20261028 };
  c.checklist = Object.fromEntries(CHECKLIST.map((k) => [k, c.checklist?.[k] ?? 'not-needed']));
  c.project = {
    people: { signsOff: 'client product owner', technicalOwner: 'lead developer' },
    designFramework: { kind: 'none' },
    i18n: { locales: ['en-GB'], defaultLocale: 'en-GB', rtl: false, expansionCheck: false },
    tenancy: 'single', browsers: 'last 2 versions, not dead', accessibility: 'wcag22-aa', currency: 'USD', theming: 'light',
    auth: { signIn: 'in-app' }, contract: { source: 'drafted' }, target: { kind: 'new-repo' },
    stack: { name: 'react-vite', decidedBy: 'user' },
    deploy: { deferred: { owner: 'platform team', by: '2026-12-15', reason: 'hosting not chosen' } },
    telemetry: { backend: 'none' },
  };
  writeFileSync(file, JSON.stringify(c, null, 2));
  mkdirSync(join(dir, 'api'));
  cpSync(CONTRACT, join(dir, 'api/openapi.yaml'));
  return dir;
}
const sign = (dir, ...more) => node('signoff.mjs', dir, '--by', 'client product owner', '--date', '2026-11-20', ...more);

test('an unchanged re-run still writes --docs and makes the --freeze copy, and records no round', () => {
  const dir = answeredStarter();
  try {
    assert.equal(sign(dir).code, 0);
    const record = readFileSync(join(dir, 'docs/signoff.json'), 'utf8');
    const docs = join(dirname(dir), 'docs/mockups/starter');
    const frozen = join(dirname(dir), 'frozen');
    const r = sign(dir, '--docs', docs, '--freeze', frozen);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /^unchanged since round 1 \(2026-11-20, client product owner\); no new round$/m);
    assert.equal(readFileSync(join(dir, 'docs/signoff.json'), 'utf8'), record, 'no round is added');
    assert.match(readFileSync(join(docs, 'signoff.md'), 'utf8'), /^# Sign-off: starter$/m);
    for (const f of ['components/Badge.js', 'api/openapi.yaml', 'docs/signoff.json', 'mockup.config.json']) assert.ok(existsSync(join(frozen, f)), f);
    assert.equal(node('check-config.mjs', frozen, '--ready-to-port').code, 0, 'the frozen copy is itself signed off');
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});

test('no screens cannot be signed off: none, or an empty list, is refused, and the gate never says signed off: yes', () => {
  const dir = answeredStarter();
  try {
    const file = join(dir, 'mockup.config.json');
    const c = JSON.parse(readFileSync(file, 'utf8'));
    for (const screens of [[], undefined]) {
      writeFileSync(file, JSON.stringify({ ...c, screens }));
      const r = sign(dir);
      assert.equal(r.code, 1, r.out);
      assert.match(r.out, /refused: screens: the config lists no screen, so nothing would be signed off/);
      assert.ok(!existsSync(join(dir, 'docs/signoff.json')), 'nothing written');
    }
    // the schema refuses an empty list itself
    writeFileSync(file, JSON.stringify({ ...c, screens: [] }));
    assert.match(sign(dir).out, /refused: config: screens: needs at least 1 item/);
    // a record with no screens (written by hand, or before this rule) is not a sign-off either
    writeFileSync(file, JSON.stringify(c));
    assert.equal(sign(dir).code, 0);
    const { screens: _gone, ...none } = c;
    writeFileSync(file, JSON.stringify(none));
    const rec = JSON.parse(readFileSync(join(dir, 'docs/signoff.json'), 'utf8'));
    const { screens: _s, ...design } = rec.rounds[0].config;
    rec.rounds[0].config = design;
    writeFileSync(join(dir, 'docs/signoff.json'), JSON.stringify(rec));
    const gate = node('check-config.mjs', dir, '--ready-to-port');
    assert.equal(gate.code, 1, gate.out);
    assert.match(gate.out, /^signed off: no/m);
    assert.match(gate.out, /^not ready: signoff: the config lists no screen/m);
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});

test('--date must be a real calendar date: 2026-02-30 is refused (exit 2)', () => {
  const dir = answeredStarter();
  try {
    for (const date of ['2026-02-30', '2026-13-01', '2025-02-29']) {
      const r = node('signoff.mjs', dir, '--by', 'client product owner', '--date', date);
      assert.equal(r.code, 2, `${date}: ${r.out}`);
      assert.match(r.out, new RegExp(`--date ${date} is not a calendar date`));
    }
    assert.equal(node('signoff.mjs', dir, '--by', 'client product owner', '--date', '2028-02-29').code, 0, 'a leap day is a date');
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});

test('check-config on a config that is JSON but not an object (null, an array, a number) is an invalid config: exit 2, no crash', () => {
  const dir = answeredStarter();
  try {
    for (const text of ['null', '[]', '3']) {
      writeFileSync(join(dir, 'mockup.config.json'), text);
      const r = node('check-config.mjs', dir, '--ready-to-port');
      assert.equal(r.code, 2, `${text}: ${r.out}`);
      assert.match(r.out, /check-config: .*mockup\.config\.json is not a JSON object/);
      assert.doesNotMatch(r.out, /crashed|TypeError/);
      const s = node('signoff.mjs', dir, '--by', 'x');
      assert.equal(s.code, 2, `signoff ${text}: ${s.out}`);
      assert.match(s.out, /mockup\.config\.json is not a JSON object/);
    }
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});
