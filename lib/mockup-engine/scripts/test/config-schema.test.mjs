/**
 * config-schema.test.mjs: lib/mockup-engine/mockup-config.schema.json is closed. A misspelt key in the
 * gate tuning, a viewport or a screen is a problem, not a silent default; deferral dates are real
 * dates; check-config warns on a deferral past its date. The keys real configs use stay valid.
 * No browser. Run: node --test test/config-schema.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { configProblems } from '../lib/project.mjs';

const CHECK = fileURLToPath(new URL('../check-config.mjs', import.meta.url));
const base = (more = {}) => ({ name: 'x', timezoneId: 'Europe/Paris', screens: [{ name: 'a', page: 'pages/a.html' }], ...more });

test('a misspelt key in the gate tuning, a viewport or a screen is a problem', () => {
  const cases = [
    [{ diff: { maxMismatchPercnt: 1 } }, 'diff: unknown key "maxMismatchPercnt"'],
    [{ viewports: [{ name: 'm', widht: 390, width: 390, height: 844 }] }, 'viewports[0]: unknown key "widht"'],
    [{ screens: [{ name: 'a', page: 'pages/a.html', rote: '/a' }] }, 'screens[0]: unknown key "rote"'],
    [{ quality: { targetMinPixels: 40 } }, 'quality: unknown key "targetMinPixels"'],
    [{ spill: { scrollsAllowed: [] } }, 'spill: unknown key "scrollsAllowed"'],
    [{ domOracle: { dropAttribute: [] } }, 'domOracle: unknown key "dropAttribute"'],
    [{ pins: { clock: '2026-10-28T09:00:00Z', seed: 1, sed: 2 } }, 'pins: unknown key "sed"'],
  ];
  for (const [more, want] of cases) {
    const problems = configProblems(base(more));
    assert.ok(problems.includes(want), `${want}\n--- got\n${problems.join('\n')}`);
  }
});

test('the keys real configs and scripts use stay valid', () => {
  const c = base({
    locale: 'en-GB',
    pins: { clock: '2026-10-28T09:00:00Z', seed: 7 },
    viewports: [{ name: 'mobile', width: 390, height: 844 }],
    screens: [{ name: 'a', page: 'pages/a.html', route: '/a', states: ['default', 'empty'], role: 'admin', theme: 'dark', locale: 'pseudo', expectStatus: [401], expectConsole: ['boom'], appRoute: '/b', steps: [{ click: { role: 'button', name: 'Go', appName: 'Go now' }, settleLayout: true }, { fill: { label: 'Code', totp: 'JBSWY3DP' } }, { press: 'Enter' }, { type: 'x' }, { wait: 100 }, { select: { label: 'S', value: 'v' } }] }],
    diff: { maxMismatchPercent: 0, baselineMaxMismatchPercent: 0.1, pixelThreshold: 0.1, boxTolerancePx: 1 },
    quality: { targetMinPx: 44 },
    spill: { cards: ['.card'], scrollAllowed: ['.table-wrap'] },
    domOracle: { root: '#app', appRoot: '#root', dropAttributes: ['data-x'], skipHiddenActions: ['a'], skipHiddenIds: ['b'], opaqueComponents: ['v-btn'] },
  });
  assert.deepEqual(configProblems(c), []);
});

test('a deferral date must be a real date', () => {
  const problems = configProblems(base({ project: { deploy: { deferred: { owner: 'platform team', by: '2026-02-31' } } } }));
  assert.ok(problems.includes('project.deploy.deferred.by: "2026-02-31" is not a date'), problems.join('\n'));
  assert.deepEqual(configProblems(base({ project: { deploy: { deferred: { owner: 'platform team', by: '2028-02-29' } } } })), []);
});

test('check-config warns on a deferral past its date, without changing the exit code', () => {
  const dir = mkdtempSync(join(tmpdir(), 'config-schema-'));
  try {
    writeFileSync(join(dir, 'mockup.config.json'), JSON.stringify(base({ project: { deploy: { deferred: { owner: 'platform team', by: '2020-01-31' } }, telemetry: { deferred: { owner: 'ops', by: '2999-01-01' } } } })));
    const r = spawnSync(process.execPath, [CHECK, dir], { encoding: 'utf8' });
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.match(r.stdout, /^deferred: project\.deploy: platform team by 2020-01-31$/m);
    assert.match(r.stdout, /^warning: deferred: project\.deploy: overdue since 2020-01-31 \(platform team\); decide it, or defer it again with a new date$/m);
    assert.doesNotMatch(r.stdout, /warning: deferred: project\.telemetry/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
