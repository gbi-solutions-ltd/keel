/**
 * fixtures.mjs: a mockup's data/fixtures.js read in a sandbox, as plain JSON, for import-mockup and
 * the contract check. A vm context's objects carry their own Object prototype, so they are
 * rebuilt in this realm first (plain); values JSON would drop or change fail (assertJson).
 */
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { isDeepStrictEqual } from 'node:util';
import vm from 'node:vm';

// Values that JSON would drop or change (functions, undefined, Date, NaN) fail instead
export function assertJson(value, what) {
  if (!isDeepStrictEqual(JSON.parse(JSON.stringify(value)), value)) {
    const bad = findNonJson(value, what);
    throw new Error(`${bad ?? what}: not plain JSON (a function, undefined, Date, NaN or class instance), so it would not survive the import`);
  }
}
function findNonJson(v, path) {
  if (v === null || typeof v === 'string' || typeof v === 'boolean') return null;
  if (typeof v === 'number') return Number.isFinite(v) ? null : path;
  if (Array.isArray(v)) { for (let i = 0; i < v.length; i += 1) { const r = findNonJson(v[i], `${path}[${i}]`); if (r) return r; } return null; }
  if (typeof v === 'object' && Object.getPrototypeOf(v) !== null && Object.getPrototypeOf(v).constructor?.name !== 'Object') return path;
  if (typeof v === 'object') { for (const [k, x] of Object.entries(v)) { const r = findNonJson(x, `${path}.${k}`); if (r) return r; } return null; }
  return path;
}
// A vm context's objects have their own Object prototype; round-trip them into this realm first
export const plain = (v) => (v === undefined ? undefined : structuredCloneSafe(v));
function structuredCloneSafe(v) {
  if (typeof v === 'function') return v;
  if (Array.isArray(v)) return Array.from(v, structuredCloneSafe);
  if (v && typeof v === 'object') {
    const proto = Object.getPrototypeOf(v);
    if (proto && proto.constructor?.name === 'Object') return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, structuredCloneSafe(x)]));
    if (v.constructor?.name === 'Date') return new Date(v.getTime());
    return v;
  }
  return v;
}


/** window.FIXTURES from <mockup>/data/fixtures.js, as plain JSON. Throws when absent or not JSON. */
export function readFixtures(mockup) {
  const file = join(mockup, 'data/fixtures.js');
  if (!existsSync(file)) throw new Error('data/fixtures.js not found');
  const box = { window: {} };
  vm.runInNewContext(readFileSync(file, 'utf8'), box, { filename: 'data/fixtures.js' });
  const fx = plain(box.window.FIXTURES);
  if (!fx || typeof fx !== 'object' || Array.isArray(fx)) throw new Error('data/fixtures.js does not set window.FIXTURES to an object');
  assertJson(fx, 'FIXTURES');
  return fx;
}

