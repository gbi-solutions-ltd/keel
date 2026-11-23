/**
 * config-screens.test.mjs: configProblems (check-config, inventory) also reports the screen and
 * viewport collisions visual-diff refuses, so they surface before a browser run.
 * Run: node --test test/config-screens.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { configProblems } from '../lib/project.mjs';

test('duplicate screen names are a config problem', () => {
  const problems = configProblems({ screens: [{ name: 'a', page: 'pages/a.html' }, { name: 'a', page: 'pages/b.html' }] });
  assert.ok(problems.some((p) => /screens\[1\]/.test(p)), problems.join('\n'));
});

test('duplicate viewport names are a config problem', () => {
  const problems = configProblems({ viewports: [{ name: 'm', width: 390, height: 800 }, { name: 'm', width: 400, height: 800 }], screens: [] });
  assert.ok(problems.some((p) => /viewports\[1\]/.test(p)), problems.join('\n'));
});
