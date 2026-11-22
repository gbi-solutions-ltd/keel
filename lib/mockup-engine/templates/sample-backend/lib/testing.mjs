/**
 * testing.mjs: a backend under test on a real Postgres, one schema per test (dropped after), so
 * tests run in parallel and leave nothing behind. TEST_DATABASE_URL names the server: the
 * backend's own `docker compose up -d db` answers on it (see .env.example).
 */
import { randomBytes } from 'node:crypto';
import pg from 'pg';
import { buildApp } from './app.mjs';
import { connect } from './db.mjs';

export const TEST_DATABASE_URL = process.env.TEST_DATABASE_URL;

/** Builds the app on a fresh schema, seeded; returns { app, stats, pool, mail, close }. */
export async function testApp(config, over = {}) {
  if (!TEST_DATABASE_URL) throw new Error('TEST_DATABASE_URL is not set: docker compose up -d db, then see .env.example');
  const schema = `t_${randomBytes(6).toString('hex')}`;
  const pool = await connect(TEST_DATABASE_URL, schema);
  const mail = [];
  // A transport that keeps each message, so a test reads what was sent (codes, links).
  const mailer = { sendMail: async (m) => void mail.push(m) };
  const built = await buildApp({ ...config, pool, mailer, dev: true, ...over });
  await built.reset();
  const close = async () => {
    await built.app.close();
    const admin = new pg.Client({ connectionString: TEST_DATABASE_URL });
    await admin.connect();
    await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
    await admin.end();
  };
  return { ...built, pool, mail, close };
}
