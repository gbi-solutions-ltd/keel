import { test } from 'node:test';
import assert from 'node:assert/strict';
import { appSteps, mockupUrl } from '../lib/screens.mjs';

test('appSteps swaps a click name for its appName on the app side', () => {
  const steps = [
    { click: { role: 'link', name: 'INV-0406', appName: 'INV-000406' } },
    { click: { role: 'button', name: 'Save' } },
    { fill: { label: 'Search', value: 'CC-1' } },
  ];
  assert.deepEqual(appSteps(steps), [
    { click: { role: 'link', name: 'INV-000406' } },
    { click: { role: 'button', name: 'Save' } },
    { fill: { label: 'Search', value: 'CC-1' } },
  ]);
  assert.equal(steps[0].click.name, 'INV-0406', 'the mockup side keeps its steps');
});

test('appSteps takes no steps', () => {
  assert.deepEqual(appSteps(), []);
});

test('a click step reaches a control whose named element does not take the pointer (a kit field around its input)', { timeout: 60000 }, async () => {
  const { chromium } = await import('playwright');
  const { runSteps } = await import('../lib/screens.mjs');
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await page.setContent(`<label id="l">Status</label>
      <div id="field" style="position:relative;width:200px;height:40px;border:1px solid">
        <input role="combobox" aria-labelledby="l" readonly style="position:absolute;inset:0;width:100%;pointer-events:none">
      </div>
      <ul id="menu" role="listbox" hidden><li role="option">Open</li></ul>
      <button id="gone" hidden>Gone</button>
      <script>document.getElementById('field').addEventListener('mousedown', () => { document.getElementById('menu').hidden = false; });</script>`);
    await runSteps(page, [{ click: { role: 'combobox', name: 'Status' } }]);
    assert.equal(await page.isVisible('#menu'), true, 'the field under the pointer opened the menu');
    // A step naming nothing visible still fails as before (no forced click on a hidden element).
    await assert.rejects(runSteps(page, [{ click: { role: 'button', name: 'Nowhere' } }]).then(() => {}), /Timeout|waiting/);
  } finally {
    await browser.close();
  }
});

test('mockupUrl is an http URL from the served base (lib/serve.mjs); there is no file:// form', () => {
  const s = { name: 'tx', page: 'pages/tx.html?id=1', route: '/tx/1', role: 'support' };
  assert.equal(mockupUrl(s, 'empty', { base: 'http://127.0.0.1:1' }), 'http://127.0.0.1:1/pages/tx.html?id=1&state=empty&as=support');
  assert.throws(() => mockupUrl(s, 'default', { dir: '/tmp/m' }), /base/);
});
