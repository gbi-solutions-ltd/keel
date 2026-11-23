/**
 * db.mjs: Postgres for the sample backend. A pool (one schema per backend, or per test), the
 * migrations (the template's own, then the app's, each applied once, in name order), and the
 * per-request handle the handlers use.
 *
 * Dates: a DATE column comes back as 'YYYY-MM-DD' text (a business day, never shifted by a zone);
 * timestamps come back as Date. Never call now() in SQL: pass ctx.now(), so a pinned clock holds.
 */
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

pg.types.setTypeParser(1082, (v) => v); // DATE as text

const TEMPLATE_MIGRATIONS = fileURLToPath(new URL('./migrations', import.meta.url));

const NAME = /^[a-z_][a-z0-9_]*$/;
// Every connection: a statement may run 10 s, a transaction may sit idle 15 s, and waiting for a
// free connection gives up after 5 s, so a slow request or a stuck mail server cannot hold the
// pool for ever.
const LIMITS = '-c statement_timeout=10000 -c idle_in_transaction_session_timeout=15000';

/** A pool on one schema (created if missing, when the role may). */
export async function connect(url, schema = 'app', { create = true } = {}) {
  if (!NAME.test(schema)) throw new Error(`bad schema name ${schema}`);
  if (create) {
    const admin = new pg.Client({ connectionString: url });
    await admin.connect();
    await admin.query(`CREATE SCHEMA IF NOT EXISTS ${schema}`);
    await admin.end();
  }
  const pool = new pg.Pool({ connectionString: url, options: `-c search_path=${schema},public ${LIMITS}`, max: 10, connectionTimeoutMillis: 5000 });
  // An idle connection the server drops (a restart) is an 'error' event: logged, never a crash.
  pool.on('error', (e) => console.error(`backend: database connection lost: ${e.message}`));
  pool.schema = schema;
  return pool;
}

/**
 * Gives the application's role what it needs and nothing more: the schema's tables for reading
 * and writing, its sequences. Then the app's own migrations/grants.sql, with {{app_role}} filled,
 * takes away what its rules forbid (an append-only table loses UPDATE, DELETE and TRUNCATE).
 */
export async function grant(ownerPool, appRole, appDir) {
  if (!appRole || !NAME.test(appRole)) throw new Error(`grant: bad application role ${appRole}`);
  const s = ownerPool.schema;
  await ownerPool.query(`GRANT USAGE ON SCHEMA ${s} TO ${appRole};
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ${s} TO ${appRole};
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA ${s} TO ${appRole};`);
  const extra = appDir && join(appDir, 'grants.sql');
  if (extra && existsSync(extra)) await ownerPool.query(readFileSync(extra, 'utf8').replaceAll('{{app_role}}', appRole));
}

/** Applies the template's migrations, then the app's, each once. Returns the names applied now. */
export async function migrate(pool, appDir) {
  const client = await pool.connect();
  try {
    await client.query('CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL)');
    const done = new Set((await client.query('SELECT name FROM schema_migrations')).rows.map((r) => r.name));
    const files = [
      ...readdirSync(TEMPLATE_MIGRATIONS).map((f) => ({ name: `template/${f}`, path: join(TEMPLATE_MIGRATIONS, f) })),
      ...(appDir ? readdirSync(appDir).map((f) => ({ name: f, path: join(appDir, f) })) : []),
    ]
      .filter((f) => f.name.endsWith('.sql') && f.name !== 'grants.sql')
      .sort((a, b) => (a.name.startsWith('template/') === b.name.startsWith('template/') ? a.name.localeCompare(b.name) : a.name.startsWith('template/') ? -1 : 1));
    const applied = [];
    for (const f of files) {
      if (done.has(f.name)) continue;
      await client.query('BEGIN');
      try {
        await client.query(readFileSync(f.path, 'utf8'));
        await client.query('INSERT INTO schema_migrations (name, applied_at) VALUES ($1, $2)', [f.name, new Date()]);
        await client.query('COMMIT');
        applied.push(f.name);
      } catch (e) {
        await client.query('ROLLBACK');
        throw new Error(`migration ${f.name}: ${e.message}`);
      }
    }
    return applied;
  } finally {
    client.release();
  }
}

/** Drops everything in the pool's schema and builds it again: migrations, then the seed. */
export async function rebuild(pool, appDir, seed, now) {
  // Never the shared schema: other applications' tables and extensions live there.
  if (pool.schema === 'public') throw new Error('rebuild: refused on the public schema; give the backend its own (DB_SCHEMA)');
  await pool.query(`DROP SCHEMA IF EXISTS ${pool.schema} CASCADE`);
  await pool.query(`CREATE SCHEMA ${pool.schema}`);
  await migrate(pool, appDir);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await seed(handle(client), now);
    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

/** What a handler gets as ctx.db: query (rows), one (first row or null), and the raw client. */
export function handle(client) {
  return {
    client,
    async query(text, params) {
      return (await client.query(text, params)).rows;
    },
    async one(text, params) {
      return (await client.query(text, params)).rows[0] ?? null;
    },
  };
}
