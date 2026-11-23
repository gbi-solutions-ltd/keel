/**
 * shared-helpers.test.mjs: the quality shard key is lib/screens.mjs's screenKey (one definition, so
 * quality shards and app shards key screens alike), and gives the keys the old slug-derived copy
 * gave: a name, a route only, a page with a query and a route, a role.
 * No browser. Run: node --test test/shared-helpers.test.mjs   (from scripts/)
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { screenKey as qualityKey } from '../lib/quality-merge.mjs';
import { screenKey, slugFor } from '../lib/screens.mjs';

test('quality-merge screenKey is screens.mjs screenKey, with the keys the slug-derived copy gave', () => {
  assert.equal(qualityKey, screenKey);
  const old = (s) => slugFor(s, 'x', 'x').slice(0, -6);
  const screens = [
    { name: 'invoices', page: 'pages/invoices.html', route: '/invoices' },
    { route: '/invoices/:id/edit' },
    { page: 'pages/request-new.html?item=itm_08', route: '/equipment/itm_08/request' },
    { name: 'admin-users', page: 'pages/users.html', route: '/users', role: 'admin' },
    { route: '/' },
  ];
  for (const s of screens) assert.equal(qualityKey(s), old(s), JSON.stringify(s));
  assert.deepEqual(screens.map(qualityKey), ['invoices', 'invoices_id_edit', 'equipment_itm_08_request', 'admin-users', 'root']);
});
