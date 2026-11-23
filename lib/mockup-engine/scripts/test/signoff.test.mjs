/**
 * signoff.test.mjs: the sign-off package on a copy of the starter. With every decision answered,
 * pins set and a drafted contract that maps the fixtures, signoff.mjs writes round 1 and
 * check-config --ready-to-port passes. Then each break must fail with its own line: no record, a
 * component changed after sign-off, a fixture the contract rejects, the contract deleted, the
 * contract edited, the contract deferred. A second round after a change passes again.
 * No browser. Run: node --test test/signoff.test.mjs   (from scripts/)
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
  const r = spawnSync(process.execPath, [join(SCRIPTS, script), ...args], { encoding: "utf8", timeout: 150000 });
  return { code: r.status, out: r.stdout + r.stderr };
};

/** The starter with its intake answered, pinned, and a drafted contract: ready to sign off. */
function answeredStarter() {
  const dir = join(mkdtempSync(join(tmpdir(), 'signoff-')), 'mockup');
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
  return dir;
}
const gate = (dir) => node('check-config.mjs', dir, '--ready-to-port');
const sign = (dir, ...more) => node('signoff.mjs', dir, '--by', 'client product owner', '--date', '2026-11-20', ...more);
const notReady = (out) => out.split('\n').filter((l) => l.startsWith('not ready: signoff: '));

test('an answered starter with a drafted contract signs off, and the gate then passes', () => {
  const dir = answeredStarter();
  try {
    const before = gate(dir);
    assert.equal(before.code, 1, before.out);
    assert.match(before.out, /^ready to port \(decisions only\): yes \(1 deferred\)$/m);
    assert.match(before.out, /not ready: signoff: no sign-off: docs\/signoff\.json is missing/);
    const docs = join(dirname(dir), 'docs/mockups/starter');
    const s = sign(dir, '--docs', docs, '--note', 'first review round');
    assert.equal(s.code, 0, s.out);
    assert.match(s.out, /^signed off: round 1 \(2026-11-20, client product owner\): \d+ screens and states at 2 viewports, \d+ files frozen, contract api\/openapi\.yaml 0\.1\.0-draft$/m);
    assert.match(s.out, /warning: FIXTURES\.session: no schema names it/);
    const after = gate(dir);
    assert.equal(after.code, 0, after.out);
    assert.match(after.out, /^signed off: yes, round 1 \(2026-11-20, client product owner\)$/m);
    const record = JSON.parse(readFileSync(join(dir, 'docs/signoff.json'), 'utf8'));
    const r1 = record.rounds[0];
    assert.equal(r1.pins.timezoneId, 'Africa/Kampala');
    assert.ok(r1.files['components/Badge.js'] && !r1.files['api/openapi.yaml'] && !r1.files['docs/signoff.json'] && !r1.files['mockup.config.json']);
    assert.ok(r1.config.screens && r1.config.project.i18n && !r1.config.project.deploy && !r1.config.diff, 'the design part of the config, not port answers or tuning');
    assert.deepEqual(r1.contract.mapped.map((m) => m.fixture).sort(), ['invoices', 'organisation', 'roles.*']);
    const page = readFileSync(join(docs, 'signoff.md'), 'utf8');
    assert.match(page, /\| Signed off by \| client product owner \|/);
    assert.match(page, /\| Invoice \| `invoices` \| 12 \|/);
    // Records kept inside the mockup (a standalone mockup's docs) are not design: the brief and the
    // sign-off page can change without a new round.
    const inside = join(dir, 'docs/mockups/starter');
    mkdirSync(inside, { recursive: true });
    writeFileSync(join(inside, 'brief.md'), '# Brief\n\nStatus: converting\n');
    assert.equal(sign(dir, '--docs', inside).code, 0);
    assert.equal(gate(dir).code, 0, gate(dir).out);
    // Signing again with nothing changed writes nothing.
    assert.match(sign(dir).out, /unchanged since round 1/);
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});

test('each break fails the gate with its own line; a new round after a change passes again', () => {
  const dir = answeredStarter();
  try {
    assert.equal(sign(dir).code, 0);
    const record = join(dir, 'docs/signoff.json');
    const saved = readFileSync(record);

    // 1. No record.
    rmSync(record);
    assert.deepEqual(notReady(gate(dir).out), ['not ready: signoff: no sign-off: docs/signoff.json is missing (run signoff.mjs once the client signs off)']);
    writeFileSync(record, saved);

    // Port-only changes are not design changes: answering the deferred deploy, tuning the gate.
    const cfgFile = join(dir, 'mockup.config.json');
    const cfgSrc = readFileSync(cfgFile, 'utf8');
    const cfg = JSON.parse(cfgSrc);
    writeFileSync(cfgFile, JSON.stringify({ ...cfg, diff: { ...cfg.diff, maxMismatchPercent: 0 }, project: { ...cfg.project, deploy: { target: 'container', ci: 'pipeline' } } }));
    let port = gate(dir);
    assert.deepEqual(notReady(port.out), [], port.out);
    assert.match(port.out, /^signed off: yes, round 1/m);
    // Nor is the quality check's tuning on a screen: expectStatus for a status only the port provokes.
    writeFileSync(cfgFile, JSON.stringify({ ...cfg, screens: cfg.screens.map((x, i) => (i === 0 ? { ...x, expectStatus: [409] } : x)) }));
    assert.deepEqual(notReady(gate(dir).out), [], 'expectStatus is gate tuning, not design');
    // A design answer is: the locales.
    writeFileSync(cfgFile, JSON.stringify({ ...cfg, project: { ...cfg.project, i18n: { ...cfg.project.i18n, locales: ['en-GB', 'fr-FR'] } } }));
    assert.ok(notReady(gate(dir).out).some((l) => /mockup changed since sign-off round 1: mockup\.config\.json project\.i18n \(sign the change off as round 2\)/.test(l)), gate(dir).out);
    writeFileSync(cfgFile, cfgSrc);

    // 2. A component changed after sign-off.
    const badge = join(dir, 'components/Badge.js');
    const badgeSrc = readFileSync(badge, 'utf8');
    writeFileSync(badge, `${badgeSrc}\n// changed\n`);
    let lines = notReady(gate(dir).out);
    assert.equal(lines.length, 1, lines.join('\n'));
    assert.match(lines[0], /mockup changed since sign-off round 1: components\/Badge\.js changed \(sign the change off as round 2\)/);
    writeFileSync(badge, badgeSrc);

    // 3. A fixture the contract rejects (a required field removed). It is also a mockup change.
    const fxFile = join(dir, 'data/fixtures.js');
    const fxSrc = readFileSync(fxFile, 'utf8');
    writeFileSync(fxFile, fxSrc.replace(/"customer_name": "[^"]*", /, ''));
    lines = notReady(gate(dir).out);
    assert.ok(lines.some((l) => /contract: Invoice: FIXTURES\.invoices\[0\]: customer_name is required/.test(l)), lines.join('\n'));
    assert.ok(lines.some((l) => /data\/fixtures\.js changed/.test(l)), lines.join('\n'));
    writeFileSync(fxFile, fxSrc);

    // 4. The contract deleted.
    const contract = join(dir, 'api/openapi.yaml');
    const contractSrc = readFileSync(contract, 'utf8');
    rmSync(contract);
    assert.deepEqual(notReady(gate(dir).out), ['not ready: signoff: contract: api/openapi.yaml is not there: draft it from needs.api and the fixtures (skills/convert-mockup/references/api-integration.md)']);

    // 5. The contract edited: a contract change, not a mockup change.
    writeFileSync(contract, contractSrc.replace('0.1.0-draft', '0.1.1-draft'));
    lines = notReady(gate(dir).out);
    assert.equal(lines.length, 1, lines.join('\n'));
    assert.match(lines[0], /contract changed since sign-off round 1: api\/openapi\.yaml/);

    // A second round signs the agreed change off; the gate passes again.
    const s2 = sign(dir, '--note', 'contract agreed with the backend');
    assert.equal(s2.code, 0, s2.out);
    assert.match(s2.out, /signed off: round 2 /);
    assert.match(s2.out, /since round 1: 0 changed, 0 added, 0 removed, the contract changed/);
    assert.equal(gate(dir).code, 0);
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});

test('sign-off is refused, with nothing written, while the contract is deferred, pins are unset or a fixture fails', () => {
  const dir = answeredStarter();
  try {
    const file = join(dir, 'mockup.config.json');
    const c = JSON.parse(readFileSync(file, 'utf8'));
    writeFileSync(file, JSON.stringify({ ...c, pins: undefined, project: { ...c.project, contract: { deferred: { owner: 'backend lead', by: '2026-12-01', reason: 'not agreed' } } } }));
    const r = sign(dir);
    assert.equal(r.code, 1, r.out);
    assert.match(r.out, /refused: pins: set pins\.clock and pins\.seed/);
    assert.match(r.out, /refused: contract: project\.contract is deferred \(backend lead by 2026-12-01\); sign-off needs the contract/);
    assert.ok(!existsSync(join(dir, 'docs/signoff.json')));
    writeFileSync(file, JSON.stringify(c));
    const fxFile = join(dir, 'data/fixtures.js');
    writeFileSync(fxFile, readFileSync(fxFile, 'utf8').replace('"status": "paid"', '"status": "settled"'));
    const f = sign(dir);
    assert.equal(f.code, 1);
    assert.match(f.out, /refused: contract: Invoice: FIXTURES\.invoices\[\d+\]\.status: "settled" is not one of open, paid, overdue, void/);
    assert.equal(sign(dir, '--freeze', dir).code, 1, 'a frozen copy is never written over');
    assert.match(sign(dir, '--freeze', join(dir, 'frozen')).out, /refused: --freeze .* is inside the mockup/);
    writeFileSync(file, JSON.stringify({ ...c, project: { ...c.project, contract: { source: 'backend', location: '../api/openapi.yaml' } } }));
    assert.match(sign(dir).out, /refused: contract: project\.contract\.location \.\.\/api\/openapi\.yaml is outside the mockup/);
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});

test('--freeze copies the frozen files, the contract and the record', () => {
  const dir = answeredStarter();
  try {
    const frozen = join(dirname(dir), 'frozen');
    assert.equal(sign(dir, '--freeze', frozen).code, 0);
    for (const f of ['components/Badge.js', 'api/openapi.yaml', 'docs/signoff.json', 'mockup.config.json']) assert.ok(existsSync(join(frozen, f)), f);
    assert.equal(gate(frozen).code, 0, 'the frozen copy is itself signed off');
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});

test('the inventory gates on the same sign-off: a signed starter is ready to port, a changed page is not', { timeout: 200000 }, () => {
  const dir = answeredStarter();
  try {
    assert.equal(sign(dir).code, 0);
    const inv = node('inventory.mjs', dir, '--ready-to-port');
    assert.equal(inv.code, 0, inv.out);
    assert.match(inv.out, /^signed off: yes, round 1 \(2026-11-20, client product owner\)$/m);
    const page = join(dir, 'pages/invoices.html');
    writeFileSync(page, readFileSync(page, 'utf8').replace('</body>', '<!-- moved -->\n</body>'));
    const changed = node('inventory.mjs', dir, '--ready-to-port');
    assert.equal(changed.code, 1);
    assert.match(changed.out, /not ready: signoff: mockup changed since sign-off round 1: pages\/invoices\.html changed/);
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});

test('import-mockup --only contract copies the signed-off contract with its source, refuses an unsigned one, and --check sees drift', () => {
  const dir = answeredStarter();
  const app = join(dirname(dir), 'app');
  mkdirSync(app); // import-mockup refuses an --app that does not exist
  const imp = (...more) => node('import-mockup.mjs', '--mockup', dir, '--app', app, ...more);
  try {
    // Not signed off yet: refused, nothing written.
    const unsigned = imp('--only', 'contract');
    assert.equal(unsigned.code, 1, unsigned.out);
    assert.match(unsigned.out, /contract: the mockup's sign-off is not valid \(no sign-off: docs\/signoff\.json is missing/);
    assert.ok(!existsSync(join(app, 'api/openapi.yaml')));
    // A default run leaves the contract out, so an unsigned mockup still imports its other parts.
    const plain = imp('--check');
    assert.doesNotMatch(plain.out, /contract/);

    assert.equal(sign(dir).code, 0);
    const ok = imp('--only', 'contract');
    assert.equal(ok.code, 0, ok.out);
    assert.match(ok.out, /contract: api\/openapi\.yaml 0\.1\.0-draft, sign-off round 1 \(2026-11-20\) -> api\/openapi\.yaml, api\/contract-source\.json/);
    assert.ok(readFileSync(join(app, 'api/openapi.yaml')).equals(readFileSync(join(dir, 'api/openapi.yaml'))), 'a byte copy');
    const src = JSON.parse(readFileSync(join(app, 'api/contract-source.json'), 'utf8'));
    assert.deepEqual({ ...src, sha256: undefined }, { mockup: '../mockup', contract: 'api/openapi.yaml', round: 1, signedOffBy: 'client product owner', date: '2026-11-20', version: '0.1.0-draft', sha256: undefined });
    assert.equal(imp('--only', 'contract', '--check').code, 0);

    // The app's copy edited by hand: --check fails, and a rerun refuses it unless --force.
    writeFileSync(join(app, 'api/openapi.yaml'), `${readFileSync(join(app, 'api/openapi.yaml'), 'utf8')}# edited\n`);
    assert.match(imp('--only', 'contract', '--check').out, /would change: api\/openapi\.yaml \(hand-changed\)/);
    assert.equal(imp('--only', 'contract').code, 1);
    assert.equal(imp('--only', 'contract', '--force').code, 0);

    // The mockup's contract moves on in round 2: the app built from round 1 is out of date.
    const c = join(dir, 'api/openapi.yaml');
    writeFileSync(c, readFileSync(c, 'utf8').replace('0.1.0-draft', '0.2.0-draft'));
    assert.equal(sign(dir, '--note', 'contract 0.2').code, 0);
    const stale = imp('--only', 'contract', '--check');
    assert.equal(stale.code, 1);
    assert.match(stale.out, /would change: api\/contract-source\.json \(changed\)/);

    // An existing repo keeps its contract elsewhere.
    const moved = imp('--only', 'contract', '--contract-out', 'contracts/api.yaml');
    assert.equal(moved.code, 0, moved.out);
    assert.ok(existsSync(join(app, 'contracts/api.yaml')) && existsSync(join(app, 'contracts/contract-source.json')));
    assert.equal(imp('--only', 'contract', '--contract-out', '../out.yaml').code, 2);
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});

test('before sign-off check-config shows the contract check; a stray YAML key refuses sign-off', () => {
  const dir = answeredStarter();
  try {
    const pre = gate(dir);
    assert.match(pre.out, /^contract: api\/openapi\.yaml 0\.1\.0-draft: 3 fixture mappings, 0 problems$/m);
    const c = join(dir, 'api/openapi.yaml');
    // An unquoted comma inside a flow mapping turns the rest of a description into a key.
    writeFileSync(c, readFileSync(c, 'utf8').replace("number: { type: string }", "number: { type: string, description: The invoice number, as printed }"));
    const r = sign(dir);
    assert.equal(r.code, 1, r.out);
    assert.match(r.out, /refused: contract: Invoice\.number: "as printed" is not a schema keyword \(an unquoted comma in YAML\?\); a code generator will refuse the document/);
    assert.match(gate(dir).out, /warning: contract: Invoice\.number: "as printed" is not a schema keyword/);
    // The same slip on a query parameter.
    writeFileSync(c, readFileSync(c, 'utf8').replace('number: { type: string, description: The invoice number, as printed }', 'number: { type: string }').replace("      operationId: listInvoices\n", "      operationId: listInvoices\n      parameters:\n        - { name: limit, in: query, description: Items per page, capped at 100., schema: { type: integer } }\n"));
    assert.match(sign(dir).out, /refused: contract: GET \/v1\/invoices parameter limit: "capped at 100\." is not a parameter field/);
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});
