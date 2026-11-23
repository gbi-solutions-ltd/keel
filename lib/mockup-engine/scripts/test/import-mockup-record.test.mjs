/**
 * import-mockup-record.test.mjs: what the last import wrote is recorded (.import-mockup.json at the
 * app root, a sha256 per output), so a byte copy changed by hand is refused instead of overwritten;
 * --app must exist; a default --check includes the contract when the app has one; the mockup path
 * in contract-source.json does not make --check machine-dependent; and generated files the mockup no
 * longer produces are reported as orphans.
 * No browser. Run: node --test test/import-mockup-record.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CHECKLIST } from '../lib/project.mjs';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const GOOD = fileURLToPath(new URL('./fixtures/import-mockup/good', import.meta.url));
const STARTER = fileURLToPath(new URL('../../templates/mockup-starter', import.meta.url));
const CONTRACT = fileURLToPath(new URL('./fixtures/signoff/openapi.yaml', import.meta.url));
const RECORD = '.import-mockup.json';
const node = (script, ...args) => {
  const r = spawnSync(process.execPath, [join(SCRIPTS, script), ...args], { encoding: 'utf8', timeout: 150000 });
  return { code: r.status, out: r.stdout + r.stderr };
};
const imp = (...args) => node('import-mockup.mjs', ...args);
const tmpApp = () => mkdtempSync(join(tmpdir(), 'import-record-'));

test('--app must exist: a mistyped one exits 2 and creates nothing', () => {
  const parent = tmpApp();
  const app = join(parent, 'ap');
  const r = imp('--mockup', GOOD, '--app', app);
  assert.equal(r.code, 2, r.out);
  assert.match(r.out, /--app .*not found/);
  assert.ok(!existsSync(app));
});

test('a byte copy changed by hand since the last import is refused unless --force, and --check names it', () => {
  const app = tmpApp();
  assert.equal(imp('--mockup', GOOD, '--app', app).code, 0);
  const rec = JSON.parse(readFileSync(join(app, RECORD), 'utf8'));
  assert.match(rec.files['src/styles/base.css']?.sha256 ?? '', /^[0-9a-f]{64}$/);
  assert.equal(rec.files['src/styles/base.css'].part, 'css');

  const base = join(app, 'src/styles/base.css');
  writeFileSync(base, '/* the app\'s own base sheet */\n');
  const refused = imp('--mockup', GOOD, '--app', app);
  assert.equal(refused.code, 1, refused.out);
  assert.match(refused.out, /src\/styles\/base\.css changed by hand since the last import/);
  assert.equal(readFileSync(base, 'utf8'), '/* the app\'s own base sheet */\n', 'left as it was');

  const check = imp('--mockup', GOOD, '--app', app, '--check');
  assert.equal(check.code, 1);
  assert.match(check.out, /would change: src\/styles\/base\.css \(hand-changed\)/);

  const forced = imp('--mockup', GOOD, '--app', app, '--force');
  assert.equal(forced.code, 0, forced.out);
  assert.ok(readFileSync(base).equals(readFileSync(join(GOOD, 'assets/base.css'))));
});

test('an app imported before the record existed: --check passes without one, and the next import records', () => {
  const app = tmpApp();
  assert.equal(imp('--mockup', GOOD, '--app', app).code, 0);
  rmSync(join(app, RECORD));
  const check = imp('--mockup', GOOD, '--app', app, '--check');
  assert.equal(check.code, 0, check.out);
  assert.ok(!existsSync(join(app, RECORD)), '--check writes nothing');
  const again = imp('--mockup', GOOD, '--app', app);
  assert.equal(again.code, 0, again.out);
  assert.ok(existsSync(join(app, RECORD)));
});

test('an --only run keeps the record entries of the parts it did not run', () => {
  const app = tmpApp();
  assert.equal(imp('--mockup', GOOD, '--app', app).code, 0);
  assert.equal(imp('--mockup', GOOD, '--app', app, '--only', 'fixtures').code, 0);
  const rec = JSON.parse(readFileSync(join(app, RECORD), 'utf8'));
  assert.ok(rec.files['src/styles/base.css'] && rec.files['src/mocks/fixtures.ts']);
  const check = imp('--mockup', GOOD, '--app', app, '--check');
  assert.equal(check.code, 0, check.out);
});

test('a locale the mockup no longer has is reported as an orphan, with or without the record', () => {
  const root = tmpApp();
  const mockup = join(root, 'mockup');
  const app = join(root, 'app');
  mkdirSync(app);
  mkdirSync(join(mockup, 'strings'), { recursive: true });
  writeFileSync(join(mockup, 'strings/en.js'), "MK.strings('en', { 'a.title': 'Title' });\n");
  writeFileSync(join(mockup, 'strings/fr.js'), "MK.strings('fr', { 'a.title': 'Titre' });\n");
  assert.equal(imp('--mockup', mockup, '--app', app, '--only', 'strings').code, 0);
  rmSync(join(mockup, 'strings/fr.js'));

  const check = imp('--mockup', mockup, '--app', app, '--only', 'strings', '--check');
  assert.equal(check.code, 1, check.out);
  assert.match(check.out, /orphan: src\/locales\/fr\.ts/);

  const write = imp('--mockup', mockup, '--app', app, '--only', 'strings');
  assert.equal(write.code, 0, write.out);
  assert.match(write.out, /orphan: src\/locales\/fr\.ts .*delete it/);
  assert.ok(existsSync(join(app, 'src/locales/fr.ts')), 'reported, never deleted');

  rmSync(join(app, RECORD));
  assert.match(imp('--mockup', mockup, '--app', app, '--only', 'strings', '--check').out, /orphan: src\/locales\/fr\.ts/);
});

/** The starter with its intake answered, pinned, and a drafted contract, signed off. */
function signedStarter() {
  const dir = join(mkdtempSync(join(tmpdir(), 'import-record-signed-')), 'mockup');
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
    tenancy: 'single',
    browsers: 'last 2 versions, not dead',
    accessibility: 'wcag22-aa',
    currency: 'USD',
    theming: 'light',
    auth: { signIn: 'in-app' },
    contract: { source: 'drafted' },
    target: { kind: 'new-repo' },
    stack: { name: 'react-vite', decidedBy: 'user' },
    deploy: { deferred: { owner: 'platform team', by: '2026-12-15', reason: 'hosting not chosen' } },
    telemetry: { backend: 'none' },
  };
  writeFileSync(file, JSON.stringify(c, null, 2));
  mkdirSync(join(dir, 'api'));
  cpSync(CONTRACT, join(dir, 'api/openapi.yaml'));
  const s = node('signoff.mjs', dir, '--by', 'client product owner', '--date', '2026-11-20');
  assert.equal(s.code, 0, s.out);
  return dir;
}

test('the contract: a default --check includes it, a hand edit is refused, the mockup path is not compared', () => {
  const dir = signedStarter();
  const app = join(dirname(dir), 'app');
  mkdirSync(app);
  try {
    assert.equal(imp('--mockup', dir, '--app', app).code, 0);
    assert.equal(imp('--mockup', dir, '--app', app, '--only', 'contract', '--contract-out', 'contracts/api.yaml').code, 0);
    assert.equal(imp('--mockup', dir, '--app', app, '--check').code, 0);

    // A default --check (no --only) sees a hand edit of the contract copy, where the record puts it.
    const yaml = join(app, 'contracts/api.yaml');
    writeFileSync(yaml, `${readFileSync(yaml, 'utf8')}# edited\n`);
    const check = imp('--mockup', dir, '--app', app, '--check');
    assert.equal(check.code, 1, check.out);
    assert.match(check.out, /would change: contracts\/api\.yaml \(hand-changed\)/);
    const refused = imp('--mockup', dir, '--app', app, '--only', 'contract', '--contract-out', 'contracts/api.yaml');
    assert.equal(refused.code, 1, refused.out);
    assert.match(refused.out, /contracts\/api\.yaml changed by hand/);
    assert.equal(imp('--mockup', dir, '--app', app, '--only', 'contract', '--contract-out', 'contracts/api.yaml', '--force').code, 0);

    // Another machine, another relative path to the mockup: not a difference.
    const srcFile = join(app, 'contracts/contract-source.json');
    const src = JSON.parse(readFileSync(srcFile, 'utf8'));
    writeFileSync(srcFile, `${JSON.stringify({ ...src, mockup: '../../elsewhere/mockup' }, null, 2)}\n`);
    const moved = imp('--mockup', dir, '--app', app, '--check');
    assert.equal(moved.code, 0, moved.out);
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});

test('a default --check includes the contract from api/contract-source.json without a record', () => {
  const dir = signedStarter();
  const app = join(dirname(dir), 'app');
  mkdirSync(app);
  try {
    assert.equal(imp('--mockup', dir, '--app', app, '--only', 'contract').code, 0);
    rmSync(join(app, RECORD));
    const yaml = join(app, 'api/openapi.yaml');
    writeFileSync(yaml, `${readFileSync(yaml, 'utf8')}# edited\n`);
    const check = imp('--mockup', dir, '--app', app, '--check');
    assert.equal(check.code, 1, check.out);
    assert.match(check.out, /would change: api\/openapi\.yaml \(unrecorded\)/);
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});

test('a contract moved with --contract-out: the old copy is an orphan and a default --check reads the new place', () => {
  const dir = signedStarter();
  const app = join(dirname(dir), 'app');
  mkdirSync(app);
  try {
    assert.equal(imp('--mockup', dir, '--app', app, '--only', 'contract').code, 0);
    assert.equal(imp('--mockup', dir, '--app', app, '--only', 'contract', '--contract-out', 'contracts/api.yaml').code, 0);
    const check = imp('--mockup', dir, '--app', app, '--check');
    assert.match(check.out, /contract: .* -> contracts\/api\.yaml/);
    assert.match(check.out, /orphan: api\/openapi\.yaml/);
    assert.match(check.out, /orphan: api\/contract-source\.json/);
    assert.equal(JSON.parse(readFileSync(join(app, RECORD), 'utf8')).contract, 'contracts/api.yaml');
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});
