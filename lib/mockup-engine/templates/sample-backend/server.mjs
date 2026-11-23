#!/usr/bin/env node
/**
 * server.mjs: runs the backend (lib/app.mjs) with this app's backend.config.mjs.
 *
 *   DATABASE_URL=postgres://<the application's role>... [MIGRATE_DATABASE_URL=postgres://<the owner>...]
 *   [APP_DB_ROLE=<the application's role, granted after migrations>] [DB_SCHEMA=app]
 *   [SMTP_URL=smtp://host:1025] [SECURE_COOKIES=0 for plain-HTTP local runs only] [TRUST_PROXY=<hops>]
 *   [SIGN_IN_URL=<the identity provider's sign-in, for an app with no sign-in screen>]
 *   [ALLOWED_ORIGINS=<the app's origin, when it is served from another one: exact, comma-separated>]
 *   node server.mjs [--migrate-only] [--port 4300] [--host 127.0.0.1] [--dev] [--reset] [--static <dist>]
 *                   [--headers <file>] [--clock <ISO instant>]
 *
 * Migrations run at every start, as MIGRATE_DATABASE_URL's role when it is set (then APP_DB_ROLE
 * is granted what the application needs, and no more). With --dev, the seed runs when the database
 * is empty, and --reset rebuilds and seeds; --reset without --dev is refused. Without --dev,
 * nothing is seeded: a production database starts empty. The schema is DB_SCHEMA (default app),
 * never public: a rebuild drops the backend's own schema only.
 * --dev turns on the stand-in sign-in, POST /__sample/reset and GET /__sample/stats. It is refused
 * on any host but a loopback one, unless DEV_PUBLISHED_ON_LOOPBACK=1 says the port is published on
 * 127.0.0.1 only (a container listens on 0.0.0.0 behind such a port): those routes sign anyone in
 * and wipe the data.
 * --static serves the app's production build from the same origin, with --headers (the app's
 * security-headers.json) on every response, as the backend for frontend does.
 * --clock pins "now" (the mockup's pins.clock, say), so date rules answer as they did at sign-off.
 */
import nodemailer from 'nodemailer';
import config from './backend.config.mjs';
import { buildApp } from './lib/app.mjs';
import { connect, grant, migrate } from './lib/db.mjs';

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : fallback;
};
const env = process.env;
const port = Number(opt('port', env.PORT ?? 4300));
const host = opt('host', env.HOST ?? '127.0.0.1');
const dev = args.includes('--dev') || env.DEV === '1';
if (dev && !['127.0.0.1', '::1', 'localhost'].includes(host) && env.DEV_PUBLISHED_ON_LOOPBACK !== '1') {
  console.error(`backend: --dev on ${host} refused: its sign-in and reset are for this machine only`);
  process.exit(2);
}
if (!env.DATABASE_URL && !(args.includes('--migrate-only') && env.MIGRATE_DATABASE_URL)) {
  console.error('backend: DATABASE_URL is not set (docker compose up db, or see .env.example)');
  process.exit(2);
}
const pinned = opt('clock', env.CLOCK);
const start = Date.now();
const clock = pinned ? () => new Date(new Date(pinned).getTime() + (Date.now() - start)) : undefined;
const mailer = env.SMTP_URL ? nodemailer.createTransport(env.SMTP_URL) : undefined;

if (args.includes('--reset') && !dev) {
  console.error('backend: --reset is for a dev database only (with --dev): it drops the schema and loads the seed');
  process.exit(2);
}
const schema = env.DB_SCHEMA || 'app';
// --migrate-only: the one-shot migrate service. It alone holds the owner's URL; the server that
// answers requests runs with MIGRATIONS=external and the application's role only.
if (args.includes('--migrate-only')) {
  const owner = await connect(env.MIGRATE_DATABASE_URL || env.DATABASE_URL, schema);
  const applied = await migrate(owner, config.migrations);
  if (env.APP_DB_ROLE) await grant(owner, env.APP_DB_ROLE, config.migrations);
  await owner.end();
  console.log(`backend: migrations ${applied.length ? applied.join(', ') : 'up to date'}${env.APP_DB_ROLE ? `, ${env.APP_DB_ROLE} granted` : ''}`);
  process.exit(0);
}
const owned = Boolean(env.MIGRATE_DATABASE_URL);
const ownerPool = owned ? await connect(env.MIGRATE_DATABASE_URL, schema) : undefined;
const pool = await connect(env.DATABASE_URL, schema, { create: !owned && env.MIGRATIONS !== 'external' });
const { app, contract, reset } = await buildApp({
  ...config,
  pool,
  ownerPool,
  appRole: env.APP_DB_ROLE,
  migrate: env.MIGRATIONS !== 'external',
  mailer,
  dev,
  clock,
  secureCookies: env.SECURE_COOKIES !== '0',
  trustProxy: env.TRUST_PROXY ? Number(env.TRUST_PROXY) : false,
  signInUrl: env.SIGN_IN_URL || undefined,
  // Sign-in over OpenID Connect (lib/oidc.mjs), for an app with no sign-in screen.
  oidc: env.OIDC_ISSUER
    ? { issuer: env.OIDC_ISSUER, clientId: env.OIDC_CLIENT_ID, clientSecret: env.OIDC_CLIENT_SECRET, redirectUri: env.OIDC_REDIRECT_URI, postLogoutRedirectUri: env.OIDC_POST_LOGOUT_REDIRECT_URI || undefined }
    : undefined,
  // An app on another origin (comma-separated exact origins): CORS with credentials for them only.
  allowedOrigins: env.ALLOWED_ORIGINS || undefined,
  staticDir: opt('static', env.STATIC_DIR),
  headersFile: opt('headers', env.HEADERS_FILE),
  // {origin:VAR} in the headers file: the build's own variables, set for this server too (.env.api).
  headersEnv: env,
});
// The seed (the design's data, a known password) only ever goes into a dev database.
if (args.includes('--reset') || (dev && !(await config.isSeeded(pool)))) {
  await reset();
  console.log('backend: seeded');
}
await app.listen({ port, host });
const handled = contract.operations.filter((o) => config.handlers[o.operationId]).length;
console.log(
  `backend: http://${host}:${port}, contract ${contract.version}, ${handled} of ${contract.operations.length} operations handled, Postgres schema ${pool.schema}${mailer ? ', SMTP on' : ''}${dev ? ', dev routes on' : ''}`,
);
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => app.close().then(() => process.exit(0)));
