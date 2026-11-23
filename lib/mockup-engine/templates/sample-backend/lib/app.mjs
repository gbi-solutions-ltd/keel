/**
 * app.mjs: a backend built from the signed-off contract, on Postgres (mockup-engine
 * skills/convert-mockup/references/sample-backend.md). Generic: everything specific to one app is in its
 * backend.config.mjs (migrations, seed, handlers, the stand-in sign-in's identities).
 *
 * What it does, for every app:
 *   - one route per contract operation, under the contract's server URL (/api);
 *   - every request validated against the contract before the handler runs (400 invalid_request),
 *     and every response after (500 contract_violation): both are counted, and a staging run with
 *     any fails;
 *   - one database transaction per request: committed with the answer when it is below 500 (a
 *     refusal keeps what it recorded: a counted attempt, an audit row), rolled back on a 5xx, a
 *     contract violation or a crash; mail queued by the handler is sent only after the commit;
 *   - sessions in the database, stored by the hash of a random token, in an HttpOnly, SameSite=Lax,
 *     Secure cookie named by the contract's cookie security scheme, with an idle and an absolute
 *     lifetime; a fresh token at every sign-in; 401 unauthenticated on every operation that is not
 *     security: [];
 *   - CSRF on every state-changing request: with a session, an X-CSRF-Token header that matches the
 *     token bound to that session (derived from the session token, so it can be given again: set
 *     as a readable csrf_token cookie at sign-in, and sent as an X-CSRF-Token response header on
 *     every answer with a session, for an app on another origin that cannot read the API's
 *     cookies); without one (sign-in and the other public writes), a cross-site Origin or
 *     Sec-Fetch-Site is refused; request bodies are JSON only, so a cross-site form cannot post one;
 *   - CORS only for the origins in allowedOrigins (ALLOWED_ORIGINS), exact matches, with
 *     credentials; none by default, so a same-origin deploy answers no other origin at all;
 *   - permissions read from the database on every request (config.permissionsOf), never trusted
 *     from the browser;
 *   - Idempotency-Key replay for operations that require the header: the key is bound to the
 *     operation, its path and query parameters and its body, held under a lock while the first
 *     request runs, and stored in the same transaction;
 *   - GET /healthz (the database answers) for the container's health check.
 * An app with no sign-in screen (signIn: 'redirect') has a page load with no session sent through
 * the identity provider and back: over OpenID Connect with config.oidc (OIDC_ISSUER; lib/oidc.mjs,
 * the routes under /auth: sign-in, callback, sign-out, signed-out), or to SIGN_IN_URL, or in dev to
 * the stand-in page. /auth/sign-out ends the session (and the provider's, over OIDC) in any of them.
 * With dev: true (never published beyond this machine): a sign-in page standing in for the
 * identity provider (signIn: 'redirect'), POST /__sample/reset (the schema rebuilt and seeded) and
 * GET /__sample/stats. With staticDir: serves the production build with the app's security headers
 * (required: a build is never served without them).
 */
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { extname, join, normalize, resolve, sep } from 'node:path';
import cookie from '@fastify/cookie';
import Fastify from 'fastify';
import { loadContract } from './contract.mjs';
import { grant, handle, migrate, rebuild } from './db.mjs';
import { oidcClient } from './oidc.mjs';

const SAFE = new Set(['GET', 'HEAD', 'OPTIONS']);
// CORS for an allowed origin: what a preflight may ask for, and the response headers the app reads.
const CORS_METHODS = 'GET, POST, PUT, PATCH, DELETE';
const CORS_HEADERS = 'content-type, x-csrf-token, idempotency-key, traceparent';
const CORS_EXPOSE = 'x-csrf-token, retry-after';
const MAX_PROBLEMS = 20; // per answer: enough to fix a request, never a memory sink
const MAX_VIOLATIONS = 50; // kept in stats, newest last
const MAX_SERVED = 1000; // answers kept in stats.servedLog, newest last
const MAX_KEY = 200; // an Idempotency-Key longer than this is refused before any work
const LOGIN_MS = 600_000; // a sign-in started at the identity provider must come back within this
// A build's file types, by lowercased extension. Anything else is application/octet-stream, which
// nosniff keeps the browser from running or styling with: add the type here before shipping one.
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.avif': 'image/avif',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
  '.pdf': 'application/pdf',
  '.mp4': 'video/mp4',
  '.webm': 'video/webm',
};
// Only the bundler's content-hashed output is cached for good (nginx: location /assets/); a root
// file (favicon.ico, robots.txt) keeps its name across releases, so it is revalidated like index.html.
const HASHED = 'assets';
// Fastify's own client errors, answered in the contract's envelope with their real status.
const CLIENT_ERRORS = { 400: 'invalid_request', 404: 'not_found', 413: 'payload_too_large', 415: 'unsupported_media_type' };

/** An error a handler throws: answered as the contract's error envelope. */
export class HttpError extends Error {
  constructor(status, code, message, details, headers) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
    this.headers = headers;
  }
}

/**
 * The headers from security-headers.json, filled as the engine's headers.mjs fills them:
 * {origin:VAR} is the origin of the URL in env[VAR], or nothing when it is unset or a path (/api);
 * {nonce} is 'nonce-<nonce>' when one is given, and otherwise dropped (an answer with no page,
 * such as JSON, runs no script). A static build is never served with a {nonce} policy (buildApp).
 */
export function readHeaders(file, { env = {}, nonce } = {}) {
  const spec = JSON.parse(readFileSync(file, 'utf8'));
  const origin = (name) => {
    const v = env[name];
    if (!v || v.startsWith('/')) return '';
    try {
      return new URL(v).origin;
    } catch {
      throw new Error(`${name}=${v} is not a URL, so {origin:${name}} in ${file} has no origin`);
    }
  };
  return Object.fromEntries(
    Object.entries(spec.headers).map(([k, v]) => [
      k,
      (Array.isArray(v) ? v.join('; ') : String(v))
        .replace(/\{origin:([A-Z0-9_]+)\}/g, (_, name) => origin(name))
        .replaceAll('{nonce}', nonce ? `'nonce-${nonce}'` : '')
        .replace(/ {2,}/g, ' ')
        .replace(/ ;/g, ';')
        .trim(),
    ]),
  );
}
const usesNonce = (file) => Object.values(JSON.parse(readFileSync(file, 'utf8')).headers ?? {}).some((v) => (Array.isArray(v) ? v.join('; ') : String(v)).includes('{nonce}'));

/**
 * Where to send the browser back to after a sign-in: a path on this site, or '/': no scheme, no
 * host, no backslash, no control character or space. An absolute URL is kept only when its origin
 * is one of `allowed` exactly (the app on another origin of the site, ALLOWED_ORIGINS).
 */
export function safeReturn(to, allowed = new Set()) {
  if (typeof to === 'string' && allowed.size && /^https?:\/\//.test(to) && !/[\u0000- \u007f\\]/.test(to)) {
    try {
      const u = new URL(to);
      if (allowed.has(u.origin) && !u.username && !u.password) return u.href;
    } catch {}
    return '/';
  }
  if (typeof to !== 'string' || !to.startsWith('/') || /[\u0000- \u007f\\]/.test(to)) return '/';
  try {
    const u = new URL(to, 'http://this.site');
    return u.origin === 'http://this.site' ? `${u.pathname}${u.search}${u.hash}` : '/';
  } catch {
    return '/';
  }
}
const escape = (s) => String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const sha = (s) => createHash('sha256').update(s).digest('hex');
const sameText = (a, b) => {
  if (typeof a !== 'string' || typeof b !== 'string' || !a || !b) return false;
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
};
/** The CSRF token of a session: derived from its token, one way, so the server can give it again. */
const csrfFor = (token) => createHash('sha256').update(`csrf ${token}`).digest('base64url');

/**
 * The allowed origins, each an exact origin (scheme, host, port): no wildcard, no path, never
 * "null". Throws on anything else, so a typo never opens CORS wider than meant.
 */
export function parseOrigins(list) {
  const items = (Array.isArray(list) ? list : String(list ?? '').split(',')).map((o) => o.trim()).filter(Boolean);
  for (const o of items) {
    let ok = false;
    try {
      ok = o !== 'null' && !o.includes('*') && new URL(o).origin === o;
    } catch {}
    if (!ok) throw new Error(`allowed origin ${JSON.stringify(o)} is not an exact origin such as https://app.example.com`);
  }
  return new Set(items);
}

/** A state-changing request a browser made from another site (a form, a fetch with no-cors). */
function crossSite(req, allowed = new Set()) {
  const origin = req.headers.origin;
  // An allowed origin (the app on its own host) is the app, not another site.
  if (origin && allowed.has(origin)) return false;
  if (req.headers['sec-fetch-site'] === 'cross-site') return true;
  if (!origin) return false;
  try {
    return new URL(origin).host !== req.headers.host;
  } catch {
    return true;
  }
}

/**
 * Builds the server. config: { contract (path), pool (lib/db.mjs connect: the application's
 * role), ownerPool? (the role that owns the schema: migrations and reset; default pool), appRole?
 * (the application's role name, granted after migrations when ownerPool is given), migrations
 * (the app's folder), seed(db, now), handlers: { [operationId]: async (ctx) => ({ status, body,
 * headers? }) }, permissionsOf?(user, db) -> string[], onForbidden?(ctx, permission),
 * identities?: [{ id, label, user }], signIn?: 'redirect' | 'none', signInUrl?, oidc? ({ issuer,
 * clientId, clientSecret, redirectUri, postLogoutRedirectUri?, scope? }: lib/oidc.mjs), with
 * userFromClaims(claims, db) -> { user_id, name, ... } | null (null: signed in at the provider, but
 * no access here), mailer? (a
 * nodemailer transport), mailFrom?, errorBody?(...), clock?() -> Date, dev?, staticDir?,
 * headersFile? (required with staticDir), idleSeconds? (default 1800), absoluteSeconds? (default
 * 43200), secureCookies? (default true), trustProxy? (Fastify's), allowedOrigins? (exact origins
 * that may call it with credentials: CORS, and their pre-session writes; default none),
 * headersEnv? (what {origin:VAR} in the headers file reads; server.mjs passes process.env;
 * default none, so every such source is empty) }.
 * Returns { app, contract, stats, reset }.
 */
export async function buildApp(config) {
  const contract = loadContract(config.contract);
  const { pool } = config;
  if (!pool) throw new Error('buildApp: config.pool is required (lib/db.mjs connect)');
  const ownerPool = config.ownerPool ?? pool;
  const errorBody =
    config.errorBody ??
    ((status, code, message, details, requestId) => ({ error: { code, message, request_id: requestId, ...(details ? { details } : {}) } }));
  const staticDir = config.staticDir ? resolve(config.staticDir) : null;
  const allowedOrigins = parseOrigins(config.allowedOrigins);
  if (staticDir && !config.headersFile) throw new Error('buildApp: staticDir needs headersFile: the build is never served without its security headers');
  // A static page carries no per-response nonce, so a {nonce} policy would block its scripts
  // whatever this server put in the header: such an app needs its own server (headers.mjs
  // --emit nginx refuses it for the same reason).
  if (staticDir && usesNonce(config.headersFile))
    throw new Error(`buildApp: ${config.headersFile} uses {nonce}, which a static build cannot carry; serve that app from its own server (docker-compose.api-only.yml)`);
  const headers = config.headersFile ? readHeaders(config.headersFile, { env: config.headersEnv ?? {} }) : {};
  const clock = config.clock ?? (() => new Date());
  if (config.oidc && config.signIn !== 'redirect') throw new Error("buildApp: oidc is for an app with no sign-in screen (signIn: 'redirect')");
  if (config.oidc && config.signInUrl) throw new Error('buildApp: set OIDC_ISSUER or SIGN_IN_URL, not both');
  if (config.oidc && typeof config.userFromClaims !== 'function') throw new Error('buildApp: oidc needs userFromClaims(claims, db) in backend.config.mjs: who a signed-in person is here');
  const oidc = config.oidc ? oidcClient(config.oidc) : null;
  const idleMs = (config.idleSeconds ?? 1800) * 1000;
  const absoluteMs = (config.absoluteSeconds ?? 43_200) * 1000;
  if (staticDir && !existsSync(join(staticDir, 'index.html'))) throw new Error(`${staticDir}/index.html not found: build the app first`);
  if (staticDir && existsSync(join(staticDir, 'mockServiceWorker.js')))
    throw new Error(`${staticDir} holds the mock worker: serve the production build, never the mocked one`);

  // Migrations run here unless something else ran them (a one-shot migrate service: migrate false).
  if (config.migrate !== false) {
    await migrate(ownerPool, config.migrations);
    if (ownerPool !== pool) await grant(ownerPool, config.appRole, config.migrations);
  }
  // Outside dev, the owner's connection is not kept: the serving process holds the application's
  // role only, so whoever reads it cannot change what that role may not.
  let ownerOpen = ownerPool !== pool;
  if (ownerOpen && !config.dev) {
    await ownerPool.end();
    ownerOpen = false;
  }
  const stats = {};
  const zero = () =>
    Object.assign(stats, { requests: 0, noSession: 0, csrfChecked: 0, csrfRefused: 0, forbidden: 0, invalidRequests: 0, contractViolations: 0, notImplemented: 0, signIns: 0, violations: [], served: 0, servedLog: [] });
  zero();
  const keepViolation = (v) => {
    stats.violations.push(v);
    if (stats.violations.length > MAX_VIOLATIONS) stats.violations.splice(0, stats.violations.length - MAX_VIOLATIONS);
  };
  async function reset() {
    await rebuild(ownerPool, config.migrations, config.seed, clock());
    if (ownerPool !== pool) await grant(ownerPool, config.appRole, config.migrations);
    zero();
  }
  // Expired sessions nobody presents again, and old replays, are removed now and then.
  async function sweep() {
    const now = clock();
    await pool.query('DELETE FROM sessions WHERE seen_at < $1 OR created_at < $2', [new Date(now - idleMs), new Date(now - absoluteMs)]).catch(() => {});
    await pool.query('DELETE FROM idempotency WHERE created_at < $1', [new Date(now - 86_400_000)]).catch(() => {});
    await pool.query('DELETE FROM oidc_logins WHERE created_at < $1', [new Date(now - LOGIN_MS)]).catch(() => {});
  }
  await sweep();
  const sweeper = setInterval(sweep, 3_600_000);
  sweeper.unref();

  const app = Fastify({ logger: false, trustProxy: config.trustProxy ?? false });
  // Every answer under /api, numbered, newest last (the last MAX_SERVED): a staging run reads which
  // requests a flow caused, including the ones an app's own server made, which the browser never sees.
  app.addHook('onResponse', async (req, reply) => {
    if (!req.url.startsWith('/api/')) return;
    stats.served += 1;
    stats.servedLog.push({ n: stats.served, method: req.method, path: req.url.split('?')[0], status: reply.statusCode });
    if (stats.servedLog.length > MAX_SERVED) stats.servedLog.splice(0, stats.servedLog.length - MAX_SERVED);
  });
  await app.register(cookie);
  app.addHook('onClose', async () => {
    clearInterval(sweeper);
    await pool.end();
    if (ownerOpen) await ownerPool.end();
  });
  // JSON only: a cross-site HTML form cannot send it without a preflight the server never allows.
  // An empty body (a POST with no payload) is no body, not a parse error.
  app.addContentTypeParser('application/json', { parseAs: 'string' }, (req, text, done) => {
    if (!text) return done(null, undefined);
    try {
      done(null, JSON.parse(text));
    } catch {
      done(new HttpError(400, 'invalid_request', 'The body is not valid JSON'));
    }
  });
  app.addHook('onRequest', async (req) => {
    req.requestId = `req_${randomBytes(6).toString('hex')}`;
  });
  // CORS, only for an allowed origin and only when some are configured: every answer to it says
  // so with credentials; a preflight is answered here, before any session or route. Any other
  // origin gets no CORS header, so its browser keeps the answer from it.
  if (allowedOrigins.size)
    app.addHook('onRequest', async (req, reply) => {
      reply.header('vary', 'Origin');
      const origin = req.headers.origin;
      const allowed = origin !== undefined && allowedOrigins.has(origin);
      if (allowed) reply.headers({ 'access-control-allow-origin': origin, 'access-control-allow-credentials': 'true', 'access-control-expose-headers': CORS_EXPOSE });
      if (req.method === 'OPTIONS' && req.headers['access-control-request-method']) {
        if (!allowed) return reply.code(403).headers(headers).type('text/plain').send('origin not allowed');
        return reply
          .code(204)
          .headers({ ...headers, 'access-control-allow-methods': CORS_METHODS, 'access-control-allow-headers': CORS_HEADERS, 'access-control-max-age': '600' })
          .send();
      }
    });

  const send = (reply, status, payload) => {
    reply.headers({ ...headers, 'cache-control': 'no-store' });
    if (payload === undefined || payload === null) return reply.code(status).send();
    return reply.code(status).type('application/json').send(JSON.stringify(payload));
  };
  const fail = (req, reply, status, code, message, details) => send(reply, status, errorBody(status, code, message, details, req.requestId));
  const secure = config.secureCookies ?? true;
  const cookieOptions = { path: '/', sameSite: 'lax', secure };

  /** The live session for this request's cookie, its idle clock restarted; null when none. */
  async function sessionOf(db, req) {
    const token = req.cookies[contract.cookieName];
    if (!token) return null;
    const now = clock();
    const row = await db.one('SELECT * FROM sessions WHERE token_hash = $1 FOR UPDATE', [sha(token)]);
    if (!row) return null;
    if (now - row.seen_at > idleMs || now - row.created_at > absoluteMs) {
      await db.query('DELETE FROM sessions WHERE token_hash = $1', [row.token_hash]);
      return null;
    }
    await db.query('UPDATE sessions SET seen_at = $2 WHERE token_hash = $1', [row.token_hash, now]);
    return row;
  }
  // A fresh token at every sign-in (and the old one dropped), so a planted id never becomes a
  // session; the CSRF token is new too, and bound to this session.
  async function startSession(db, req, reply, user, idToken = null) {
    const old = req.cookies[contract.cookieName];
    if (old) await db.query('DELETE FROM sessions WHERE token_hash = $1', [sha(old)]);
    const token = randomBytes(32).toString('base64url');
    const csrf = csrfFor(token);
    const now = clock();
    await db.query('INSERT INTO sessions (token_hash, user_id, "user", csrf_hash, created_at, seen_at, id_token) VALUES ($1, $2, $3, $4, $5, $5, $6)', [
      sha(token),
      user.user_id,
      user,
      sha(csrf),
      now,
      idToken,
    ]);
    stats.signIns += 1;
    reply.setCookie(contract.cookieName, token, { ...cookieOptions, httpOnly: true });
    reply.setCookie('csrf_token', csrf, cookieOptions);
    reply.header('x-csrf-token', csrf);
  }
  const clearCookies = (reply) => {
    reply.clearCookie(contract.cookieName, { path: '/' });
    reply.clearCookie('csrf_token', { path: '/' });
  };

  /** Runs fn(db) in one transaction: committed when keep(result) holds, rolled back otherwise. */
  async function transaction(fn, keep) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const out = await fn(handle(client));
      const committed = keep(out);
      await client.query(committed ? 'COMMIT' : 'ROLLBACK');
      return { out, committed };
    } catch (e) {
      await client.query('ROLLBACK').catch(() => {});
      throw e;
    } finally {
      client.release();
    }
  }
  /**
   * Starts sending what a committed request queued, and does not wait: the answer never depends
   * on the mail server, in time or in outcome (no oracle). A failure is logged.
   */
  function deliver(mail) {
    const failed = (m) => (e) => console.error(`backend: mail to ${m.to} failed: ${e.message}`);
    for (const m of mail) {
      try {
        Promise.resolve(config.mailer.sendMail({ from: config.mailFrom ?? 'no-reply@sample.invalid', ...m })).catch(failed(m));
      } catch (e) {
        failed(m)(e);
      }
    }
  }

  for (const op of contract.operations) {
    app.route({
      method: op.method,
      url: op.route,
      handler: async (req, reply) => {
        stats.requests += 1;
        const mail = [];
        let savepoints = 0; // ctx.savepoint's names, unique within the request
        let live = null; // the session this request ran under, if it still stands at the end
        let ended = false;
        const { out, committed } = await transaction(
          async (db) => {
            const session = await sessionOf(db, req);
            live = session;
            if (!op.public && !session) {
              stats.noSession += 1;
              return { status: 401, error: ['unauthenticated', 'Sign in first'] };
            }
            if (!SAFE.has(op.method)) {
              stats.csrfChecked += 1;
              const token = req.headers['x-csrf-token'];
              const ok = session ? typeof token === 'string' && token !== '' && sameText(sha(token), session.csrf_hash) : !crossSite(req, allowedOrigins);
              if (!ok) {
                stats.csrfRefused += 1;
                return { status: 403, error: ['csrf_failed', 'The CSRF token is missing or does not match'] };
              }
            }
            const problems = op.validateRequest(req);
            if (problems.length) {
              stats.invalidRequests += 1;
              const shown = problems.slice(0, MAX_PROBLEMS);
              keepViolation({ operationId: op.operationId, side: 'request', problems: shown, more: problems.length - shown.length });
              console.error(`backend: ${op.operationId}: the request breaks the contract: ${shown.join('; ')}${problems.length > shown.length ? ` (and ${problems.length - shown.length} more)` : ''}`);
              return { status: 400, error: ['invalid_request', 'The request does not match the contract', { problems: shown }] };
            }
            const handler = config.handlers[op.operationId];
            if (!handler) {
              stats.notImplemented += 1;
              return { status: 501, error: ['not_implemented', `${op.operationId} has no handler in this backend`] };
            }
            let replayKey = null;
            let bodyHash = null;
            if (op.idempotent) {
              const key = String(req.headers['idempotency-key']);
              if (key.length > MAX_KEY) return { status: 400, error: ['invalid_request', `The Idempotency-Key is longer than ${MAX_KEY} characters`] };
              replayKey = sha(`${session?.user_id ?? 'anonymous'} ${op.operationId} ${key}`);
              // The key stands for one request: the same path, query and body. Another one under
              // it is refused, never answered with the first one's result.
              bodyHash = sha(JSON.stringify({ params: req.params ?? {}, query: req.query ?? {}, body: req.body ?? null }));
              // A second request with the key waits here until the first commits, then replays it.
              await db.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [replayKey]);
              const seen = await db.one('SELECT body_hash, status, body FROM idempotency WHERE key = $1', [replayKey]);
              if (seen && seen.body_hash !== bodyHash) return { status: 422, error: ['idempotency_key_reused', 'This key was used for another request'] };
              if (seen) return { status: seen.status, body: seen.body };
            }
            const permissions = async () => (session ? (config.permissionsOf ? await config.permissionsOf(session.user, db) : (session.user.permissions ?? [])) : []);
            const ctx = {
              params: req.params,
              query: req.query,
              headers: req.headers,
              body: req.body,
              ip: req.ip,
              // The caller's own address, only when a trusted proxy reports it (TRUST_PROXY):
              // otherwise every request comes from the proxy or the container's gateway.
              clientIp: config.trustProxy ? req.ip : null,
              requestId: req.requestId,
              user: session?.user ?? null,
              session: session ? { marks: session.marks } : null,
              db,
              now: clock,
              async can(permission) {
                return (await permissions()).includes(permission);
              },
              async need(permission) {
                if (!(await permissions()).includes(permission)) {
                  stats.forbidden += 1;
                  if (config.onForbidden) await config.onForbidden(ctx, permission);
                  throw new HttpError(403, 'forbidden', `This needs ${permission}`);
                }
              },
              fail(status, code, message, details, extraHeaders) {
                throw new HttpError(status, code, message, details, extraHeaders);
              },
              /** Keeps a mark on this session (a step-up time, say). */
              async mark(key, value) {
                session.marks = { ...session.marks, [key]: value };
                await db.query('UPDATE sessions SET marks = $2 WHERE token_hash = $1', [session.token_hash, session.marks]);
                ctx.session.marks = session.marks;
              },
              startSession: (user) => startSession(db, req, reply, user),
              async endSession() {
                if (session) await db.query('DELETE FROM sessions WHERE token_hash = $1', [session.token_hash]);
                clearCookies(reply);
                ended = true;
              },
              /** Signs a user out everywhere (a deactivation, a password change), keeping this session if asked. */
              async endSessions(userId, { keepCurrent = false } = {}) {
                await db.query('DELETE FROM sessions WHERE user_id = $1 AND NOT ($2 AND token_hash = $3)', [userId, keepCurrent, session?.token_hash ?? '']);
              },
              /** Queues a message, sent once the request has committed (never from inside it). */
              async sendMail(message) {
                if (!config.mailer) throw new Error('no mailer configured (SMTP_URL)');
                mail.push(message);
              },
              /**
               * Opt in: runs fn() so that, if it throws (ctx.fail, an SQL error), what it wrote and
               * the mail it queued are undone and the error goes on; the request's own transaction
               * stays usable. For a handler that writes, then may refuse, and must not keep the
               * write. Everything outside it keeps the default: a refusal below 500 commits (a
               * counted attempt, an audit row). Cookies set inside it (startSession) are not undone.
               */
              async savepoint(fn) {
                const name = `sp_${(savepoints += 1)}`;
                const queued = mail.length;
                await db.query(`SAVEPOINT ${name}`);
                try {
                  const value = await fn();
                  await db.query(`RELEASE SAVEPOINT ${name}`);
                  return value;
                } catch (e) {
                  await db.query(`ROLLBACK TO SAVEPOINT ${name}`);
                  await db.query(`RELEASE SAVEPOINT ${name}`);
                  mail.length = queued;
                  throw e;
                }
              },
            };
            let result;
            try {
              result = await handler(ctx);
            } catch (e) {
              if (!(e instanceof HttpError)) throw e;
              return { status: e.status, error: [e.code, e.message, e.details], headers: e.headers };
            }
            const violation = op.validateResponse(result.status, result.body);
            if (violation.length) {
              stats.contractViolations += 1;
              keepViolation({ operationId: op.operationId, side: 'response', status: result.status, problems: violation.slice(0, MAX_PROBLEMS) });
              console.error(`backend: ${op.operationId}: the response breaks the contract: ${violation.slice(0, MAX_PROBLEMS).join('; ')}`);
              return { status: 500, error: ['contract_violation', 'The backend answered outside the contract'] };
            }
            if (replayKey && result.status < 500)
              await db.query('INSERT INTO idempotency (key, body_hash, status, body, created_at) VALUES ($1, $2, $3, $4, $5)', [replayKey, bodyHash, result.status, JSON.stringify(result.body ?? null), clock()]);
            return result;
          },
          (o) => o.status < 500,
        );
        if (committed && mail.length) deliver(mail);
        if (out.headers) reply.headers(out.headers);
        // The session's CSRF token, for an app that cannot read the API's cookies (another origin).
        // A sign-in has set the new one already; a sign-out sends none.
        if (live && !ended && committed && !reply.hasHeader('x-csrf-token')) reply.header('x-csrf-token', csrfFor(req.cookies[contract.cookieName]));
        if (out.error) {
          const [code, message, details] = out.error;
          return fail(req, reply, out.status, code, message, details);
        }
        return send(reply, out.status, out.body);
      },
    });
  }

  app.get(`${contract.prefix}/openapi.yaml`, (req, reply) => reply.headers(headers).type('application/yaml').send(contract.text));
  app.get('/healthz', async (req, reply) => {
    reply.headers({ ...headers, 'cache-control': 'no-store' });
    try {
      await pool.query('SELECT 1');
      return reply.type('application/json').send('{"ok":true}');
    } catch {
      return reply.code(503).type('application/json').send('{"ok":false}');
    }
  });

  // The backend's own pages under /auth (not the app's): a policy of their own that runs no script
  // and lets a form go only here and to the identity provider, plus the app's other headers.
  const authHeaders = {
    ...headers,
    'content-security-policy': `default-src 'none'; form-action 'self'${oidc ? ` ${new URL(config.oidc.issuer).origin}` : ''}; frame-ancestors 'none'; base-uri 'none'`,
    'cache-control': 'no-store',
  };
  const page = (reply, status, title, body) =>
    reply
      .code(status)
      .headers(authHeaders)
      .type('text/html; charset=utf-8')
      .send(`<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${escape(title)}</title></head>
  <body>
    <main>
      <h1>${escape(title)}</h1>
      ${body}
    </main>
  </body>
</html>`);
  const again = (to) => `<p><a href="/auth/sign-in?return_to=${escape(encodeURIComponent(to))}">Sign in again</a></p>`;

  async function authRoutes(auth) {
    auth.addContentTypeParser('application/x-www-form-urlencoded', { parseAs: 'string' }, (req, text, done) => done(null, Object.fromEntries(new URLSearchParams(text))));
    // Start: a pending sign-in bound to this browser by a cookie only /auth sees, then the provider.
    auth.get('/auth/sign-in', async (req, reply) => {
      const to = safeReturn(req.query.return_to, allowedOrigins);
      if (!oidc) {
        const url = config.signInUrl ?? (config.dev ? '/__sample/sign-in' : null);
        if (!url) return reply.code(503).headers(authHeaders).type('text/plain').send('Sign-in is not configured: set OIDC_ISSUER (or SIGN_IN_URL) to the identity provider.');
        return reply.headers(authHeaders).redirect(`${url}${url.includes('?') ? '&' : '?'}return_to=${encodeURIComponent(to)}`, 302);
      }
      let started;
      try {
        started = await oidc.start();
      } catch (e) {
        console.error(`backend: the identity provider is unreachable: ${e.message}`);
        return page(reply, 503, 'Sign-in is unavailable', `<p>The identity provider did not answer. Try again in a moment.</p>${again(to)}`);
      }
      // This browser's earlier pending sign-in, if any, is replaced rather than left to the sweep.
      if (req.cookies.oidc_login) await pool.query('DELETE FROM oidc_logins WHERE binding_hash = $1', [sha(req.cookies.oidc_login)]);
      const binding = randomBytes(32).toString('base64url');
      await pool.query('INSERT INTO oidc_logins (binding_hash, state, nonce, verifier, return_to, created_at) VALUES ($1, $2, $3, $4, $5, $6)', [
        sha(binding),
        started.state,
        started.nonce,
        started.verifier,
        to,
        clock(),
      ]);
      reply.setCookie('oidc_login', binding, { ...cookieOptions, path: '/auth', httpOnly: true, maxAge: LOGIN_MS / 1000 });
      return reply.headers(authHeaders).redirect(started.url, 302);
    });
    // Back from the provider: the pending sign-in this browser started, used once.
    auth.get('/auth/callback', async (req, reply) => {
      const binding = req.cookies.oidc_login;
      reply.clearCookie('oidc_login', { path: '/auth' });
      const row = binding ? (await pool.query('DELETE FROM oidc_logins WHERE binding_hash = $1 RETURNING *', [sha(binding)])).rows[0] : null;
      if (!oidc || !row || clock() - row.created_at > LOGIN_MS)
        return page(reply, 400, 'Sign-in did not complete', `<p>This sign-in expired, or was started in another browser.</p>${again(row?.return_to ?? '/')}`);
      const search = req.url.includes('?') ? req.url.slice(req.url.indexOf('?')) : '';
      let claims, idToken;
      try {
        ({ claims, idToken } = await oidc.finish(search, row));
      } catch (e) {
        console.error(`backend: sign-in refused: ${e.code ?? ''} ${e.message}`);
        return page(reply, 400, 'Sign-in did not complete', `<p>The identity provider did not sign you in.</p>${again(row.return_to)}`);
      }
      const { out } = await transaction(async (db) => {
        const user = await config.userFromClaims(claims, db);
        if (user) await startSession(db, req, reply, user, idToken);
        return user;
      }, () => true);
      if (!out) {
        const away = await oidc.endSession(idToken).catch(() => null);
        return page(reply, 403, 'No access', `<p>You are signed in at the identity provider, but this account has no access here.</p>${away ? `<p><a href="${escape(away)}">Sign in as someone else</a></p>` : ''}`);
      }
      return reply.headers(authHeaders).redirect(row.return_to, 303);
    });
    auth.get('/auth/sign-out', (req, reply) =>
      page(reply, 200, 'Sign out', '<form method="post" action="/auth/sign-out"><button type="submit">Sign out</button></form>'),
    );
    // A plain form post with no token: refused from another site, and a Lax session cookie never
    // comes with a cross-site post anyway.
    auth.post('/auth/sign-out', async (req, reply) => {
      if (crossSite(req, allowedOrigins)) return reply.code(403).headers(authHeaders).type('text/plain').send('cross-site request refused');
      const token = req.cookies[contract.cookieName];
      const row = token ? (await pool.query('DELETE FROM sessions WHERE token_hash = $1 RETURNING id_token', [sha(token)])).rows[0] : null;
      clearCookies(reply);
      const away = oidc ? await oidc.endSession(row?.id_token).catch(() => null) : null;
      return reply.headers(authHeaders).redirect(away ?? '/auth/signed-out', 303);
    });
    auth.get('/auth/signed-out', (req, reply) => page(reply, 200, 'Signed out', '<p>You are signed out.</p><p><a href="/">Sign in again</a></p>'));
  }

  if (config.dev)
    // The dev routes in their own scope: only here is a form body parsed (the stand-in sign-in is
    // a plain HTML form), and a cross-site post is refused on all of them.
    await app.register(async (dev) => {
      dev.addContentTypeParser('application/x-www-form-urlencoded', { parseAs: 'string' }, (req, text, done) =>
        done(null, Object.fromEntries(new URLSearchParams(text))),
      );
      dev.addHook('onRequest', async (req, reply) => {
        if (!SAFE.has(req.method) && crossSite(req, allowedOrigins)) return reply.code(403).headers(headers).type('text/plain').send('cross-site request refused');
      });
      dev.post('/__sample/reset', async (req, reply) => {
        await reset();
        return reply.code(204).headers(headers).send();
      });
      dev.get('/__sample/stats', (req, reply) => reply.headers(headers).type('application/json').send(JSON.stringify(stats)));
      // Stands in for the identity provider: a plain form, no script, so the app's CSP holds.
      dev.get('/__sample/sign-in', (req, reply) => {
        const to = safeReturn(req.query.return_to, allowedOrigins);
        const buttons = (config.identities ?? [])
          .map((i) => `<button type="submit" name="identity" value="${escape(i.id)}">Sign in as ${escape(i.label)}</button>`)
          .join('\n      ');
        const page = `<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Sign in (sample identity provider)</title></head>
  <body>
    <main>
      <h1>Sign in</h1>
      <p>A stand-in for the identity provider, for a local run. It is not the real sign-in.</p>
      <form method="post" action="/__sample/sign-in">
      <input type="hidden" name="return_to" value="${escape(to)}">
      ${buttons}
      </form>
    </main>
  </body>
</html>`;
        return reply.headers(headers).type('text/html; charset=utf-8').send(page);
      });
      dev.post('/__sample/sign-in', async (req, reply) => {
        const identity = (config.identities ?? []).find((i) => i.id === req.body?.identity);
        if (!identity) return reply.code(400).headers(headers).type('text/plain').send('unknown identity');
        await transaction((db) => startSession(db, req, reply, identity.user), () => true);
        return reply.headers(headers).redirect(safeReturn(req.body?.return_to, allowedOrigins), 303);
      });
    });

  if (config.signIn === 'redirect') await app.register(authRoutes);

  app.setNotFoundHandler(async (req, reply) => {
    const path = req.url.split('?')[0];
    if (path.startsWith(`${contract.prefix}/`) || path.startsWith('/__sample/') || (config.signIn === 'redirect' && path.startsWith('/auth/')) || !staticDir || !['GET', 'HEAD'].includes(req.method))
      return fail(req, reply, 404, 'not_found', 'No such operation');
    let decoded;
    try {
      decoded = decodeURIComponent(path);
    } catch {
      return fail(req, reply, 400, 'invalid_request', 'The path is not valid');
    }
    const abs = join(staticDir, normalize(decoded).replace(/^(\.\.[/\\])+/, ''));
    const asset = (abs === staticDir || abs.startsWith(staticDir + sep)) && existsSync(abs) && !statSync(abs).isDirectory();
    const hashed = abs.startsWith(join(staticDir, HASHED) + sep);
    // A hashed name that is not there (an older release's) is a 404, as nginx answers it: never
    // the app's page under a name a cache keeps for a year.
    if (hashed && !asset) return reply.code(404).headers({ ...headers, 'cache-control': 'no-store' }).type('text/plain; charset=utf-8').send('not found');
    if (!asset && config.signIn === 'redirect' && !(await transaction((db) => sessionOf(db, req), () => true)).out) {
      // The identity provider's sign-in (SIGN_IN_URL), or the stand-in in dev; never a loop to a
      // page that is not there.
      const signInUrl = config.signInUrl ?? (oidc ? '/auth/sign-in' : config.dev ? '/__sample/sign-in' : null);
      if (!signInUrl) return reply.code(503).headers(headers).type('text/plain').send('Sign-in is not configured: set OIDC_ISSUER (or SIGN_IN_URL) to the identity provider.');
      return reply.headers(headers).redirect(`${signInUrl}${signInUrl.includes('?') ? '&' : '?'}return_to=${encodeURIComponent(safeReturn(req.url))}`, 302);
    }
    const file = asset ? abs : join(staticDir, 'index.html');
    return reply
      .headers({ ...headers, 'cache-control': asset && hashed ? 'public, max-age=31536000, immutable' : 'no-cache' })
      .type(TYPES[extname(file).toLowerCase()] ?? 'application/octet-stream')
      .send(readFileSync(file));
  });

  app.setErrorHandler((err, req, reply) => {
    if (err instanceof HttpError) return fail(req, reply, err.status, err.code, err.message, err.details);
    // Fastify's own refusals (a wrong content type, a body too large) keep their status.
    if (err.statusCode >= 400 && err.statusCode < 500)
      return fail(req, reply, err.statusCode, CLIENT_ERRORS[err.statusCode] ?? 'invalid_request', 'The request was refused');
    console.error(`backend: ${req.method} ${req.url.split('?')[0]} ${req.requestId}: ${err.stack ?? err}`);
    return fail(req, reply, 500, 'internal_error', 'The backend failed');
  });

  return { app, contract, stats, reset };
}
