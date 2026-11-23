/**
 * project.test.mjs: mockup.config.json against lib/mockup-engine/mockup-config.schema.json (lib/project.mjs),
 * the readiness rules for a port, the defaults scripts take from the config, and the inventory's use
 * of them (rule "config", the readiness line, --ready-to-port).
 * Run: node --test test/project.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { configLocale, configProblems, configZone, pinDefaults, projectStack, readiness, settledByProject, tiers } from '../lib/project.mjs';

const ENGINE = fileURLToPath(new URL('../..', import.meta.url));
const INVENTORY = fileURLToPath(new URL('../inventory.mjs', import.meta.url));
const CLEAN = fileURLToPath(new URL('./fixtures/inventory/clean', import.meta.url));

/** A project block that answers everything, tier 2 partly deferred. */
const fullProject = () => ({
  people: { signsOff: 'client product owner', technicalOwner: 'lead developer' },
  designFramework: { kind: 'utility-css', name: 'tailwindcss', version: '4.1.0', owner: 'public' },
  i18n: { locales: ['en-GB', 'fr-FR'], defaultLocale: 'en-GB', rtl: false, expansionCheck: true },
  tenancy: 'single',
  browsers: 'evergreen',
  accessibility: 'wcag22-aa',
  currency: 'EUR',
  theming: 'light-and-dark-system',
  auth: { signIn: 'idp-hosted', provider: 'an OIDC provider' },
  contract: { source: 'drafted' },
  target: { kind: 'new-repo' },
  stack: { name: 'vue', decidedBy: 'design-architecture', record: 'docs/architecture/frontend.md' },
  deploy: { deferred: { owner: 'platform team', by: '2026-12-15', reason: 'hosting not chosen' } },
  telemetry: { backend: 'none' },
});
const base = (project) => ({ name: 'x', timezoneId: 'Europe/Paris', screens: [{ name: 'a', page: 'pages/a.html' }], ...(project ? { project } : {}) });

test('every mockup.config.json in the engine validates', () => {
  const found = [];
  const walk = (d) => {
    for (const n of readdirSync(d)) {
      if (n === 'node_modules' || n.startsWith('.')) continue;
      const p = join(d, n);
      if (statSync(p).isDirectory()) walk(p);
      else if (n === 'mockup.config.json') found.push(p);
    }
  };
  walk(ENGINE);
  assert.ok(found.length >= 2, `found ${found.length}`);
  for (const f of found) assert.deepEqual(configProblems(JSON.parse(readFileSync(f, 'utf8'))), [], f);
});

test('a full project block validates and is ready, with its deferral listed', () => {
  const c = base(fullProject());
  assert.deepEqual(configProblems(c), []);
  const r = readiness(c);
  assert.deepEqual(r.open, []);
  assert.deepEqual(r.deferred, [{ field: 'project.deploy', owner: 'platform team', by: '2026-12-15', reason: 'hosting not chosen' }]);
});

test('the schema marks tier 1 and tier 2 fields', () => {
  const t = tiers();
  assert.ok(t[1].includes('designFramework') && t[1].includes('i18n') && t[1].includes('auth'));
  assert.ok(t[2].includes('stack') && t[2].includes('contract') && t[2].includes('target') && t[2].includes('deploy'));
  assert.ok(!t[1].includes('stack'), 'the stack is a port decision');
});

test('unknown keys, wrong enums and wrong types are problems, with their path', () => {
  const p = fullProject();
  p.colour = 'blue';
  p.accessibility = 'wcag3';
  p.i18n.rtl = 'no';
  const problems = configProblems({ ...base(p), extra: 1, viewports: [{ name: 'm', width: 0, height: 10 }] });
  assert.ok(problems.includes('(top): unknown key "extra"'), problems.join('\n'));
  assert.ok(problems.includes('project: unknown key "colour"'));
  assert.ok(problems.some((x) => x.startsWith('project.accessibility: "wcag3" is not one of')));
  assert.ok(problems.includes('project.i18n.rtl: must be a boolean'));
  assert.ok(problems.includes('viewports[0].width: must be at least 1'));
});

test('a deferral needs an owner and a date', () => {
  const p = fullProject();
  p.stack = { deferred: { owner: 'architect' } };
  const problems = configProblems(base(p));
  assert.ok(problems.some((x) => x.includes('by is required')), problems.join('\n'));
  p.stack = { deferred: { owner: 'architect', by: 'soon' } };
  assert.ok(configProblems(base(p)).some((x) => x.includes('does not match')));
});

test('rules the schema cannot say', () => {
  const p = fullProject();
  p.designFramework = { kind: 'css-library' };
  p.i18n.defaultLocale = 'de-DE';
  p.auth = { signIn: 'idp-hosted' };
  p.target = { kind: 'existing-repo' };
  p.contract = { source: 'backend' };
  p.stack = { name: 'vue', decidedBy: 'design-architecture' };
  const problems = configProblems({ ...base(p), targetStack: 'react-vite' });
  for (const want of ['designFramework: name is required', 'defaultLocale de-DE is not in locales', 'provider is required', 'path is required', 'location is required', 'record is required', 'targetStack react-vite disagrees'])
    assert.ok(problems.some((x) => x.includes(want)), `${want}\n${problems.join('\n')}`);
});

test('readiness lists every missing tier 1 and undecided tier 2 field', () => {
  const r = readiness(base());
  const fields = r.open.map((o) => o.field);
  assert.ok(fields.includes('project.designFramework') && fields.includes('project.stack'));
  assert.equal(r.open.find((o) => o.field === 'project.i18n').tier, 1);
  assert.equal(r.open.find((o) => o.field === 'project.contract').tier, 2);
  const p = fullProject();
  delete p.auth;
  assert.deepEqual(readiness(base(p)).open.map((o) => o.field), ['project.auth']);
  // the business time zone is a tier 1 answer kept at the top level
  const noZone = { ...base(fullProject()) };
  delete noZone.timezoneId;
  assert.deepEqual(readiness(noZone).open.map((o) => [o.field, o.tier]), [['timezoneId', 1]]);
  assert.equal(configZone(noZone), 'UTC', 'never the machine zone');
  assert.equal(configZone(base()), 'Europe/Paris');
});

test('project answers settle checklist items; defaults come from the config', () => {
  assert.deepEqual(settledByProject(base(fullProject())), { localisation: 'designed', 'dark-mode': 'designed' });
  assert.deepEqual(settledByProject(base({ theming: 'light' })), { 'dark-mode': 'not-needed' });
  const c = { ...base(fullProject()), pins: { clock: '2026-10-28T09:00:00Z', seed: 7 } };
  assert.deepEqual(pinDefaults(c, undefined, undefined), { clock: '2026-10-28T09:00:00Z', seed: '7' });
  assert.deepEqual(pinDefaults(c, '2026-01-01T00:00:00Z', '3'), { clock: '2026-01-01T00:00:00Z', seed: '3' });
  assert.deepEqual(pinDefaults(base(), undefined, undefined), { clock: undefined, seed: undefined });
  assert.equal(configLocale(c), 'en-GB');
  assert.equal(configLocale({ ...c, locale: 'fr-FR' }), 'fr-FR');
  assert.equal(configLocale(base()), 'en-GB');
  assert.equal(projectStack(c), 'vue');
  assert.equal(projectStack({ targetStack: 'nextjs' }), 'nextjs');
  assert.equal(projectStack(base({ stack: { deferred: { owner: 'a', by: '2026-12-01' } } })), null);
});

function inventory(dir, extra = []) {
  const out = mkdtempSync(join(tmpdir(), 'project-inv-'));
  return new Promise((done) => {
    execFile(process.execPath, [INVENTORY, dir, '--out', out, ...extra], { timeout: 120000 }, (err, stdout, stderr) => {
      const json = existsSync(join(out, 'inventory.json')) ? JSON.parse(readFileSync(join(out, 'inventory.json'), 'utf8')) : null;
      rmSync(out, { recursive: true, force: true });
      done({ code: err ? err.code : 0, stdout, stderr, json });
    });
  });
}

test('inventory: config problems are lint, readiness is reported, --ready-to-port gates on it', { timeout: 300000 }, async () => {
  const tmp = mkdtempSync(join(tmpdir(), 'project-fixture-'));
  try {
    const dir = join(tmp, 'm');
    cpSync(CLEAN, dir, { recursive: true });
    const cfg = JSON.parse(readFileSync(join(dir, 'mockup.config.json'), 'utf8'));

    // not ready: passes without the flag, fails with it, and names what is open
    const plain = await inventory(dir);
    assert.equal(plain.code, 0, plain.stdout + plain.stderr);
    assert.match(plain.stdout, /^ready to port \(decisions only\): no, \d+ open$/m);
    assert.equal(plain.json.readiness.ready, false);
    const gated = await inventory(dir, ['--ready-to-port']);
    assert.equal(gated.code, 1);
    assert.match(gated.stdout, /^not ready: project\.designFramework: tier 1 /m);
    assert.match(gated.stdout, /^not ready: checklist audit-log: undecided/m);

    // ready: every answer given and the checklist decided (localisation and dark-mode settled by the project)
    const items = ['user-management', 'roles-admin', 'audit-log', 'notifications', 'settings', 'developer-access', 'session-timeout', 'password-reset', 'approvals', 'onboarding', 'system-pages', 'bulk-actions', 'saved-views', 'file-upload', 'print', 'privacy'];
    writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify({ ...cfg, timezoneId: 'Europe/Paris', project: { ...fullProject(), designFramework: { kind: 'none' } }, checklist: Object.fromEntries(items.map((k) => [k, 'later'])) }));
    // the fixture's stub page loads no strings, which a project with languages makes lint; accepted here
    mkdirSync(join(dir, 'docs'), { recursive: true });
    writeFileSync(join(dir, 'docs/inventory-accepted.json'), JSON.stringify({ accepted: [
      { rule: 'i18n-strings', where: 'pages/home.html', reason: 'a stub page with no mk.js strings' },
    ] }));
    // decisions all answered: the only thing left open is the sign-off (test/signoff.test.mjs)
    const ready = await inventory(dir, ['--ready-to-port']);
    assert.equal(ready.code, 1, ready.stdout + ready.stderr);
    assert.match(ready.stdout, /^ready to port \(decisions only\): yes \(1 deferred\)$/m);
    assert.deepEqual(ready.stdout.split('\n').filter((l) => l.startsWith('not ready:')), ['not ready: signoff: no sign-off: docs/signoff.json is missing (run signoff.mjs once the client signs off)']);
    assert.equal(ready.json.signoff.signed, false);
    assert.equal(ready.json.checklist.localisation, 'designed');

    // a config problem is lint, rule config, and fails the run with or without the flag
    writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify({ ...cfg, project: { ...fullProject(), accessibility: 'wcag3' } }));
    const bad = await inventory(dir);
    assert.equal(bad.code, 1);
    assert.ok(bad.json.lint.some((l) => l.rule === 'config' && l.where === 'mockup.config.json project.accessibility'), JSON.stringify(bad.json.lint));
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test('config pins are the default clock and seed; a flag still wins', { timeout: 180000 }, async () => {
  const CHECKER = fileURLToPath(new URL('../check-behaviours.mjs', import.meta.url));
  const tmp = mkdtempSync(join(tmpdir(), 'project-pins-'));
  try {
    const dir = join(tmp, 'm');
    cpSync(fileURLToPath(new URL('./fixtures/behaviours/mockup', import.meta.url)), dir, { recursive: true });
    const cfgPath = join(dir, 'mockup.config.json');
    const cfg = JSON.parse(readFileSync(cfgPath, 'utf8'));
    writeFileSync(cfgPath, JSON.stringify({ ...cfg, pins: { clock: '2026-10-28T09:00:00Z', seed: 20261028 } }));
    const file = join(tmp, 'b.json');
    const runWith = (expectText, args = []) => {
      writeFileSync(file, JSON.stringify([{ id: 'pins', page: 'pages/pins.html', expect: [{ text: expectText }] }]));
      return new Promise((done) => execFile(process.execPath, [CHECKER, '--mockup', dir, '--file', file, ...args], { timeout: 60000 }, (err, stdout, stderr) => done({ code: err ? err.code : 0, out: stdout + stderr })));
    };
    const fromConfig = await runWith('now 2026-10-28T09:00:00.000Z');
    assert.equal(fromConfig.code, 0, fromConfig.out);
    const flagWins = await runWith('now 2026-01-01T00:00:00.000Z', ['--clock', '2026-01-01T00:00:00Z']);
    assert.equal(flagWins.code, 0, flagWins.out);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test('check-config: no browser; problems fail, readiness gates only with --ready-to-port', async () => {
  const CHECK = fileURLToPath(new URL('../check-config.mjs', import.meta.url));
  const tmp = mkdtempSync(join(tmpdir(), 'check-config-'));
  const run = (args) => new Promise((done) => execFile(process.execPath, [CHECK, tmp, ...args], { timeout: 30000 }, (err, stdout, stderr) => done({ code: err ? err.code : 0, out: stdout + stderr })));
  try {
    const missing = await run([]);
    assert.equal(missing.code, 2, missing.out);
    const items = ['user-management', 'roles-admin', 'audit-log', 'notifications', 'settings', 'developer-access', 'session-timeout', 'password-reset', 'approvals', 'onboarding', 'bulk-actions', 'saved-views', 'file-upload', 'print', 'privacy'];
    // modules settle their checklist items (system-pages here), as in the inventory
    writeFileSync(join(tmp, 'mockup.config.json'), JSON.stringify({ ...base(fullProject()), modules: ['system-pages'], checklist: Object.fromEntries(items.map((k) => [k, 'later'])) }));
    const ready = await run(['--ready-to-port']);
    assert.equal(ready.code, 1, 'no sign-off yet');
    assert.match(ready.out, /^ready to port \(decisions only\): yes \(1 deferred\)$/m);
    assert.deepEqual(ready.out.split('\n').filter((l) => l.startsWith('not ready:')).map((l) => l.split(':').slice(0, 2).join(':')), ['not ready: signoff']);
    assert.match(ready.out, /^deferred: project\.deploy: platform team by 2026-12-15$/m);
    writeFileSync(join(tmp, 'mockup.config.json'), JSON.stringify(base()));
    const open = await run([]);
    assert.equal(open.code, 0, 'open decisions alone do not fail without the flag');
    const gated = await run(['--ready-to-port']);
    assert.equal(gated.code, 1);
    assert.match(gated.out, /^not ready: project\.people: tier 1 /m);
    writeFileSync(join(tmp, 'mockup.config.json'), JSON.stringify({ ...base(), project: { accessibility: 'wcag3' } }));
    const bad = await run([]);
    assert.equal(bad.code, 1);
    assert.match(bad.out, /^config: project\.accessibility: "wcag3" is not one of/m);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
