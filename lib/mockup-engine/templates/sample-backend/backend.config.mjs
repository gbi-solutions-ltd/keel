/**
 * backend.config.mjs: everything in the backend that is this app's own. lib/, server.mjs and the
 * Docker files are the engine's template, copied unchanged (skills/convert-mockup/references/sample-backend.md).
 *
 * Write the tables (migrations/*.sql) and the handlers from the contract (api/openapi.yaml) and
 * the brief's rules, never from the app's mock handlers: a backend that runs the frontend's own
 * mocks cannot disagree with them, which is the point of running one.
 */
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const here = (p) => new URL(p, import.meta.url).pathname;
// A byte copy of the signed-off mockup's data/fixtures.js (seed/source.json says from where): the
// design data, seeded as the first state. Only data comes from the mockup; every rule is written here.
function fixtures() {
  const sandbox = { window: {} };
  runInNewContext(readFileSync(here('./seed/fixtures.js'), 'utf8'), sandbox, { filename: 'seed/fixtures.js' });
  return sandbox.window.FIXTURES;
}

export default {
  contract: here('./api/openapi.yaml'),
  migrations: here('./migrations'),
  /** Fills the empty tables from the fixtures (db.query; pass `now` for any timestamp). */
  async seed(db, now) {
    const F = fixtures();
    // await db.query('INSERT INTO ...', [...]);
  },
  /** Whether the database already holds the seed (the server seeds an empty one at start). */
  async isSeeded(pool) {
    // return (await pool.query("SELECT to_regclass('some_table') IS NOT NULL AS ok")).rows[0].ok;
    return false;
  },
  /** The permissions a session's user has now, read on every request. */
  async permissionsOf(user, db) {
    return [];
  },
  // Who the stand-in sign-in offers, when the app has no sign-in screen (signIn: 'redirect').
  identities: [],
  signIn: 'redirect',
  handlers: {
    // async operationId(ctx) { await ctx.need('perm'); return { status: 200, body: { ... } }; },
  },
};
