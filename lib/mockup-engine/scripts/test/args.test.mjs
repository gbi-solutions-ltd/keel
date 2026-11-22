/**
 * args.test.mjs: lib/args.mjs, the one argument parser. Every script refuses an unknown flag, and a
 * value flag with no value or another flag as its value, with exit 2 and a message naming the flag,
 * before it reads anything; an uncaught error exits 2 (a crash), not 1 (checked and failed); --help
 * prints the usage and exits 0. Every script has an npm alias.
 * No browser: every run here stops at the arguments, or at a missing folder.
 * Run: node --test test/args.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPTS = fileURLToPath(new URL('..', import.meta.url));
const NOWHERE = join(tmpdir(), 'args-test-no-such-folder');
const run = (script, ...args) => {
  const r = spawnSync(process.execPath, [join(SCRIPTS, `${script}.mjs`), ...args], { encoding: 'utf8', timeout: 60000 });
  return { code: r.status, out: r.stdout + r.stderr };
};

// The arguments each script needs to get past its own required ones, all pointing nowhere.
const BASE = {
  'visual-diff': ['--mockup', NOWHERE, '--app', 'http://127.0.0.1:9'],
  'quality-check': ['--mockup', NOWHERE],
  'dom-oracle': ['--mockup', NOWHERE, '--app', 'http://127.0.0.1:9'],
  'check-behaviours': ['--mockup', NOWHERE],
  inventory: ['--mockup', NOWHERE],
  'spill-check': ['--mockup', NOWHERE],
  'merge-shards': ['diff', '--dir', NOWHERE, '--shards', '2'],
  'check-config': [NOWHERE],
  headers: [join(NOWHERE, 'headers.json'), '--emit', 'nginx'],
  'contract-diff': [join(NOWHERE, 'a.yaml'), join(NOWHERE, 'b.yaml')],
  'perf-budget': ['--budget', join(NOWHERE, 'b.json'), '--dist', NOWHERE],
  'staging-run': ['--url', 'http://127.0.0.1:9', '--flows', join(NOWHERE, 'f.json'), '--contract', join(NOWHERE, 'a.yaml'), '--live-contract', join(NOWHERE, 'b.yaml')],
  'production-bar': [NOWHERE],
  signoff: [NOWHERE, '--by', 'someone'],
  'import-mockup': ['--mockup', NOWHERE, '--app', NOWHERE],
  'vendor-library': ['--from', NOWHERE, '--to', NOWHERE],
  'split-css': [NOWHERE, NOWHERE],
  'check-links': [NOWHERE],
  toolchain: ['--runtime-only'],
  'check-lock': [NOWHERE],
  'release-age': [NOWHERE],
};
// A value flag each script reads.
const VALUE_FLAG = {
  'visual-diff': '--out', 'quality-check': '--out', 'dom-oracle': '--out', 'check-behaviours': '--file', inventory: '--out',
  'spill-check': '--out', 'merge-shards': '--out', headers: '--record', 'contract-diff': '--record', 'perf-budget': '--record',
  'staging-run': '--record', 'production-bar': '--docs', signoff: '--note', 'import-mockup': '--stack', 'vendor-library': '--package',
  'split-css': '--inventory', 'check-links': '--list', toolchain: '--dir', 'check-lock': '--packages', 'release-age': '--days',
};

test('every script but check-frontend parses through lib/args.mjs', () => {
  const own = readdirSync(SCRIPTS).filter((f) => f.endsWith('.mjs') && f !== 'check-frontend.mjs').map((f) => f.slice(0, -4)).sort();
  assert.deepEqual(own, Object.keys(BASE).sort());
  for (const s of own) {
    const src = readFileSync(join(SCRIPTS, `${s}.mjs`), 'utf8');
    assert.ok(src.includes(`cli('${s}'`) || src.includes(`parseArgs(argv, SPECS['${s}'])`), `${s} does not parse through lib/args.mjs`);
    assert.doesNotMatch(src.replace(/process\.argv\[1\]|process\.argv\.slice\(2\)\)/g, ''), /process\.argv/, `${s} reads process.argv itself`);
  }
});

test('an unknown flag exits 2 and names it, in every script', () => {
  for (const [script, base] of Object.entries(BASE)) {
    const r = run(script, ...base, '--no-such-flag');
    assert.equal(r.code, 2, `${script}: ${r.out}`);
    assert.match(r.out, /unknown flag --no-such-flag/, script);
  }
});

test('a value flag followed by another flag, or by nothing, exits 2 and names it', () => {
  for (const [script, flag] of Object.entries(VALUE_FLAG)) {
    const before = run(script, ...BASE[script], flag, '--no-such-flag');
    assert.equal(before.code, 2, `${script}: ${before.out}`);
    assert.match(before.out, new RegExp(`${flag} needs a value, got the flag --no-such-flag`), script);
    const last = run(script, ...BASE[script], flag);
    assert.equal(last.code, 2, `${script}: ${last.out}`);
    assert.match(last.out, new RegExp(`${flag} needs a value`), script);
  }
  // check-config has no value flag; the visual-diff mode flag takes no flag as its value
  const shard = run('visual-diff', '--mockup', NOWHERE, '--app', '--shard', '1/2');
  assert.equal(shard.code, 2, shard.out);
  assert.match(shard.out, /--app needs a value, got the flag --shard/);
});

test('a stray positional, or a mistyped boolean, exits 2', () => {
  const typo = run('check-config', NOWHERE, '--ready-to-prt');
  assert.equal(typo.code, 2, typo.out);
  assert.match(typo.out, /unknown flag --ready-to-prt/);
  const stray = run('quality-check', '--mockup', NOWHERE, 'extra');
  assert.equal(stray.code, 2, stray.out);
  assert.match(stray.out, /unexpected argument extra/);
});

test('a value may start with a single dash', async () => {
  const { parseArgs, SPECS } = await import('../lib/args.mjs');
  const r = parseArgs(['--mockup', 'm', '--baseline', 'b', '--skip', '-tour$', '--seed', '-1'], SPECS['visual-diff']);
  assert.deepEqual(r.values, { mockup: 'm', baseline: 'b', skip: '-tour$', seed: '-1' });
  assert.deepEqual(parseArgs(['--env', 'A=1', '--env', 'B=2', 'h.json'], SPECS.headers).values.env, ['A=1', 'B=2']);
  assert.throws(() => parseArgs(['--out', 'a', '--out', 'b'], SPECS['quality-check']), /--out given twice/);
});

test('--help prints the usage and exits 0', () => {
  for (const script of Object.keys(BASE)) {
    const r = run(script, '--help');
    assert.equal(r.code, 0, `${script}: ${r.out}`);
    assert.match(r.out, new RegExp(`^usage: ${script}\\.mjs`), script);
  }
});

test('a bad flag value in check-behaviours is a bad argument: exit 2, not 1', () => {
  const r = run('check-behaviours', '--mockup', NOWHERE, '--clock', 'not-a-date');
  assert.equal(r.code, 2, r.out);
});

test('an uncaught error exits 2, not 1: quality-check on a config that does not parse; a missing one is named', () => {
  const dir = mkdtempSync(join(tmpdir(), 'args-test-'));
  const missing = run('quality-check', '--mockup', dir);
  assert.equal(missing.code, 2, missing.out);
  assert.match(missing.out, /quality-check: missing .*mockup\.config\.json/);
  writeFileSync(join(dir, 'mockup.config.json'), '{ not json');
  const r = run('quality-check', '--mockup', dir);
  assert.equal(r.code, 2, r.out);
  assert.match(r.out, /quality-check: crashed: /);
});

test('every script has an npm alias', () => {
  const aliases = Object.values(JSON.parse(readFileSync(join(SCRIPTS, 'package.json'), 'utf8')).scripts);
  for (const f of readdirSync(SCRIPTS).filter((x) => x.endsWith('.mjs'))) assert.ok(aliases.includes(`node ${f}`), `no npm alias runs ${f}`);
});

test('merge-shards behaviours accepts the flags the shards ran with (gate-sharded.sh passes BEH_ARGS to both)', () => {
  const dir = mkdtempSync(join(tmpdir(), 'args-test-'));
  writeFileSync(join(dir, 'x'), '');
  const r = run('merge-shards', 'behaviours', '--dir', dir, '--shards', '1', '--mockup', NOWHERE, '--tz', 'Africa/Kampala', '--only', 'a');
  assert.doesNotMatch(r.out, /unknown flag/);
});

test('a bad --clock, --workers or --shard is a bad argument in every visual-diff mode: exit 2', () => {
  const mockup = fileURLToPath(new URL('./fixtures/diff-app-shard', import.meta.url));
  const tmp = mkdtempSync(join(tmpdir(), 'args-test-'));
  for (const mode of [['--app', 'http://127.0.0.1:9'], ['--baseline', tmp], ['--write-baseline', join(tmp, 'wb')]]) {
    for (const bad of [['--clock', 'not-a-date'], ['--workers', '0'], ...(mode[0] === '--write-baseline' ? [] : [['--shard', '3/2']])]) {
      if (mode[0] === '--app' && bad[0] === '--workers') continue; // app mode has no workers
      const r = run('visual-diff', '--mockup', mockup, ...mode, ...bad, '--out', join(tmp, 'out'));
      assert.equal(r.code, 2, `${mode[0]} ${bad.join(' ')}: ${r.out}`);
    }
  }
});

test('a flag that does not apply is refused, not ignored: headers --emit with --check; dom-oracle --strict, --config or a file outside --diff', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'args-test-'));
  const headersFile = join(tmp, 'headers.json');
  writeFileSync(headersFile, JSON.stringify({ headers: { 'X-Content-Type-Options': 'nosniff' } }));
  const both = run('headers', headersFile, '--emit', 'nginx', '--check', 'http://127.0.0.1:9');
  assert.equal(both.code, 2, both.out);
  assert.match(both.out, /--emit or --check, not both/);
  const mockup = fileURLToPath(new URL('./fixtures/diff-app-shard', import.meta.url));
  for (const extra of [['--strict'], ['--config', join(mockup, 'mockup.config.json')], ['stray.html']]) {
    const r = run('dom-oracle', '--mockup', mockup, '--app', 'http://127.0.0.1:9', '--out', join(tmp, 'out'), ...extra);
    assert.equal(r.code, 2, `${extra.join(' ')}: ${r.out}`);
    assert.match(r.out, /applies to --diff only|unexpected argument stray\.html/, extra.join(' '));
  }
});

test('a flag that does not apply is refused, not ignored: perf-budget --dist with --next, the vitals flags without --url; dom-oracle --diff with a case-mode flag', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'args-test-'));
  const budget = join(tmp, 'b.json');
  writeFileSync(budget, JSON.stringify({ bundle: { initialJsKb: 200 } }));
  const both = run('perf-budget', '--budget', budget, '--dist', tmp, '--next', tmp);
  assert.equal(both.code, 2, both.out);
  assert.match(both.out, /perf-budget: pass --dist or --next, not both/);
  for (const [flag, value] of [['--mockup', tmp], ['--route', 'x'], ['--runs', '2'], ['--session', join(tmp, 's.json')]]) {
    const r = run('perf-budget', '--budget', budget, '--dist', tmp, flag, value);
    assert.equal(r.code, 2, `${flag}: ${r.out}`);
    assert.match(r.out, new RegExp(`perf-budget: ${flag} applies to the vitals, which need --url`), flag);
  }
  const a = join(tmp, 'a.html');
  writeFileSync(a, '<p>x</p>');
  for (const extra of [['--mockup', tmp], ['--app', 'http://127.0.0.1:9'], ['--out', join(tmp, 'out')], ['--reference', tmp], ['--screen', 'x'], ['--viewport', 'desktop'], ['--root', '#app']]) {
    const r = run('dom-oracle', '--diff', a, a, ...extra);
    assert.equal(r.code, 2, `${extra.join(' ')}: ${r.out}`);
    assert.match(r.out, new RegExp(`${extra[0]} applies to case mode, not --diff`), extra.join(' '));
  }
  assert.equal(run('dom-oracle', '--diff', a, a).code, 0, 'two identical files still compare');
});

test('every script\'s usage names every flag in its SPECS entry, so declared and documented cannot drift', async () => {
  const { SPECS } = await import('../lib/args.mjs');
  for (const [script, spec] of Object.entries(SPECS)) {
    for (const flag of Object.keys(spec.flags)) {
      assert.match(spec.usage, new RegExp(`--${flag}(?![\\w-])`), `${script}: --${flag} is declared but its usage does not name it`);
    }
    // and the other way: a flag the usage names is one the parser accepts
    for (const [, named] of spec.usage.matchAll(/--([a-z][\w-]*)/g)) assert.ok(Object.hasOwn(spec.flags, named), `${script}: the usage names --${named}, which is not declared`);
  }
});

test('isCrash, next to crashExits2: a bug or a system error is a crash (exit 2); a plain Error is a script\'s refusal', async () => {
  const { isCrash } = await import('../lib/args.mjs');
  for (const e of [new TypeError('x'), new ReferenceError('x'), new RangeError('x'), new SyntaxError('x'), Object.assign(new Error('ENOENT'), { code: 'ENOENT' })]) assert.equal(isCrash(e), true, String(e));
  assert.equal(isCrash(new Error('refused')), false);
  for (const s of ['import-mockup', 'vendor-library']) assert.match(readFileSync(join(SCRIPTS, `${s}.mjs`), 'utf8'), /isCrash\(e\)/, `${s} uses the shared isCrash`);
});
