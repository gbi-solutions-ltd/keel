/**
 * oidc.test.mjs: the sign-in over OpenID Connect (lib/oidc.mjs and the /auth routes of
 * lib/app.mjs), against a small provider run here with its own signing key, so each check the
 * backend owes can be broken one at a time: the browser binding, state, PKCE, nonce, the ID
 * token's signature, issuer, audience and expiry, one use per callback, the user mapping and the
 * sign-out. A real provider (Keycloak, an example's docker-compose.idp.yml) is the staging run's.
 * The engine keeps this file byte-identical in every example backend. Run: npm test
 */
import assert from 'node:assert/strict';
import { createHash, generateKeyPairSync, randomBytes, sign } from 'node:crypto';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { safeReturn } from '../lib/app.mjs';
import { oidcClient } from '../lib/oidc.mjs';
import { testApp } from '../lib/testing.mjs';

const CONTRACT = `openapi: 3.1.0
info: { title: oidc test, version: '1' }
servers: [{ url: /api }]
security: [{ sessionCookie: [] }]
paths:
  /me:
    get:
      operationId: getMe
      responses:
        '200':
          description: who
          content: { application/json: { schema: { type: object, required: [user_id], properties: { user_id: { type: string } } } } }
components:
  securitySchemes:
    sessionCookie: { type: apiKey, in: cookie, name: session }
`;
const CLIENT = { id: 'test-bff', secret: 'test-secret' };
const b64 = (v) => Buffer.from(typeof v === 'string' ? v : JSON.stringify(v)).toString('base64url');

/** A provider: discovery, JWKS, token and end-session endpoints; codes issued by the test. */
async function provider(t) {
  const key = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const other = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const jwk = { ...key.publicKey.export({ format: 'jwk' }), kid: 'k1', alg: 'RS256', use: 'sig' };
  const codes = new Map();
  const seen = { tokenRequests: 0 };
  const server = createServer(async (req, res) => {
    const url = new URL(req.url, iss);
    const json = (status, body) => res.writeHead(status, { 'content-type': 'application/json' }).end(JSON.stringify(body));
    if (url.pathname.endsWith('/.well-known/openid-configuration'))
      return json(200, {
        issuer: iss,
        authorization_endpoint: `${iss}/authorize`,
        token_endpoint: `${iss}/token`,
        jwks_uri: `${iss}/jwks`,
        end_session_endpoint: `${iss}/logout`,
        response_types_supported: ['code'],
        subject_types_supported: ['public'],
        id_token_signing_alg_values_supported: ['RS256'],
        code_challenge_methods_supported: ['S256'],
        token_endpoint_auth_methods_supported: ['client_secret_basic', 'client_secret_post'],
      });
    if (url.pathname.endsWith('/jwks')) return json(200, { keys: [jwk] });
    if (url.pathname.endsWith('/token') && req.method === 'POST') {
      seen.tokenRequests += 1;
      let text = '';
      for await (const c of req) text += c;
      const form = new URLSearchParams(text);
      const basic = (req.headers.authorization ?? '').replace(/^Basic /, '');
      const [id, secret] = basic ? Buffer.from(basic, 'base64').toString().split(':').map(decodeURIComponent) : [form.get('client_id'), form.get('client_secret')];
      if (id !== CLIENT.id || secret !== CLIENT.secret) return json(401, { error: 'invalid_client' });
      const issued = codes.get(form.get('code'));
      codes.delete(form.get('code'));
      if (!issued || form.get('redirect_uri') !== issued.redirectUri) return json(400, { error: 'invalid_grant' });
      if (createHash('sha256').update(form.get('code_verifier') ?? '').digest('base64url') !== issued.challenge) return json(400, { error: 'invalid_grant', error_description: 'PKCE' });
      const now = Math.floor(Date.now() / 1000);
      const claims = { iss, aud: CLIENT.id, sub: issued.sub, iat: now, exp: now + 300, nonce: issued.nonce, email: issued.email, email_verified: true, name: issued.name, ...issued.claims };
      const head = b64({ alg: 'RS256', kid: 'k1', typ: 'JWT' });
      const body = b64(claims);
      const signature = sign('sha256', Buffer.from(`${head}.${body}`), issued.badSignature ? other.privateKey : key.privateKey).toString('base64url');
      return json(200, { access_token: randomBytes(16).toString('hex'), token_type: 'Bearer', expires_in: 300, id_token: `${head}.${body}.${signature}` });
    }
    res.writeHead(404).end();
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const iss = `http://127.0.0.1:${server.address().port}/realms/test`;
  t.after(() => server.close());
  return {
    issuer: iss,
    seen,
    /** What the provider does at its authorize endpoint for this user: a code, back to the app. */
    authorize(location, user = {}) {
      const u = new URL(location);
      assert.equal(u.origin + u.pathname, `${iss}/authorize`);
      const q = Object.fromEntries(u.searchParams);
      const code = randomBytes(12).toString('hex');
      codes.set(code, { sub: 'sub-1', email: 'ada@example.org', name: 'Ada', ...user, nonce: user.nonce ?? q.nonce, challenge: q.code_challenge, redirectUri: q.redirect_uri });
      return { q, callback: `/auth/callback?code=${code}&state=${encodeURIComponent(user.state ?? q.state)}` };
    },
  };
}

const PEOPLE = { 'ada@example.org': { user_id: 'usr_1', name: 'Ada' } };
async function make(t, idp, over = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'oidc-test-'));
  writeFileSync(join(dir, 'openapi.yaml'), CONTRACT);
  mkdirSync(join(dir, 'migrations'));
  const dist = mkdtempSync(join(tmpdir(), 'oidc-dist-'));
  writeFileSync(join(dist, 'index.html'), '<!doctype html><title>app</title>');
  const headersFile = join(dir, 'security-headers.json');
  writeFileSync(headersFile, JSON.stringify({ headers: { 'Content-Security-Policy': "default-src 'self'; form-action 'self'", 'X-Content-Type-Options': 'nosniff' } }));
  const config = {
    contract: join(dir, 'openapi.yaml'),
    migrations: join(dir, 'migrations'),
    seed: async () => {},
    handlers: { getMe: async (ctx) => ({ status: 200, body: { user_id: ctx.user.user_id } }) },
    signIn: 'redirect',
    oidc: { issuer: idp.issuer, clientId: CLIENT.id, clientSecret: CLIENT.secret, redirectUri: 'http://127.0.0.1:4300/auth/callback' },
    userFromClaims: async (claims) => (claims.email_verified ? (PEOPLE[claims.email] ?? null) : null),
    staticDir: dist,
    headersFile,
    dev: false,
  };
  const b = await testApp(config, over);
  t.after(b.close);
  return b;
}
const cookiesOf = (r) => Object.fromEntries(r.cookies.map((c) => [c.name, c]));
/** A page load, through the provider and back: { start, callback, signedIn } responses. */
async function signIn(app, idp, user, path = '/loans?status=open') {
  const page = await app.inject({ method: 'GET', url: path });
  assert.equal(page.statusCode, 302);
  const start = await app.inject({ method: 'GET', url: page.headers.location });
  assert.equal(start.statusCode, 302, start.body);
  const binding = cookiesOf(start).oidc_login;
  const { q, callback } = idp.authorize(start.headers.location, user);
  const back = await app.inject({ method: 'GET', url: callback, headers: binding ? { cookie: `oidc_login=${binding.value}` } : {} });
  const jar = cookiesOf(back);
  return { page, start, binding, q, callback, back, cookie: jar.session ? `session=${jar.session.value}` : null };
}

test('a page load with no session goes to the provider and comes back signed in, where it was going', async (t) => {
  const idp = await provider(t);
  const { app, pool } = await make(t, idp);
  const s = await signIn(app, idp);
  assert.equal(s.page.headers.location, `/auth/sign-in?return_to=${encodeURIComponent('/loans?status=open')}`);
  // The provider is asked for a code with PKCE (S256), a state and a nonce, for this client.
  assert.deepEqual([s.q.response_type, s.q.client_id, s.q.code_challenge_method, s.q.redirect_uri], ['code', CLIENT.id, 'S256', 'http://127.0.0.1:4300/auth/callback']);
  assert.match(s.q.scope, /\bopenid\b/);
  for (const k of ['state', 'nonce', 'code_challenge']) assert.ok(s.q[k]?.length >= 22, k);
  assert.deepEqual([s.binding.httpOnly, s.binding.path, s.binding.sameSite, s.binding.secure], [true, '/auth', 'Lax', true]);
  assert.equal(s.back.statusCode, 303, s.back.body);
  assert.equal(s.back.headers.location, '/loans?status=open');
  assert.equal(cookiesOf(s.back).session.httpOnly, true);
  assert.equal((await app.inject({ method: 'GET', url: '/api/me', headers: { cookie: s.cookie } })).json().user_id, 'usr_1');
  assert.match((await app.inject({ method: 'GET', url: '/loans', headers: { cookie: s.cookie } })).body, /<title>app<\/title>/);
  assert.ok((await pool.query('SELECT id_token FROM sessions')).rows[0].id_token, 'kept for the sign-out');
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM oidc_logins')).rows[0].n, 0, 'the pending sign-in is used up');
});

test('login CSRF: a callback this browser did not start is refused, and signs nobody in', async (t) => {
  const idp = await provider(t);
  const { app } = await make(t, idp);
  const start = await app.inject({ method: 'GET', url: '/auth/sign-in?return_to=/' });
  const { callback } = idp.authorize(start.headers.location);
  // The attacker's own callback link, opened in the victim's browser: no binding cookie.
  const r = await app.inject({ method: 'GET', url: callback });
  assert.equal(r.statusCode, 400);
  assert.match(r.body, /Sign-in did not complete/);
  assert.equal(cookiesOf(r).session, undefined);
  assert.equal(idp.seen.tokenRequests, 0, 'the code is never even exchanged');
  // Another browser's binding cookie does not fit this pending sign-in either.
  const wrong = await app.inject({ method: 'GET', url: callback, headers: { cookie: 'oidc_login=not-the-one' } });
  assert.equal(wrong.statusCode, 400);
});

test('state, nonce and PKCE: each one wrong fails the sign-in', async (t) => {
  const idp = await provider(t);
  const { app } = await make(t, idp);
  for (const user of [{ state: 'forged-state' }, { nonce: 'another-nonce' }]) {
    const s = await signIn(app, idp, user);
    assert.equal(s.back.statusCode, 400, JSON.stringify(user));
    assert.equal(s.cookie, null);
  }
  // A code whose challenge is not this sign-in's verifier: the provider refuses the exchange.
  const start = await app.inject({ method: 'GET', url: '/auth/sign-in?return_to=/' });
  const tampered = new URL(start.headers.location);
  tampered.searchParams.set('code_challenge', createHash('sha256').update('another verifier').digest('base64url'));
  const { callback } = idp.authorize(tampered.href);
  const r = await app.inject({ method: 'GET', url: callback, headers: { cookie: `oidc_login=${cookiesOf(start).oidc_login.value}` } });
  assert.equal(r.statusCode, 400);
});

test('the ID token: a bad signature, another issuer, another audience or an expired one is refused', async (t) => {
  const idp = await provider(t);
  const { app } = await make(t, idp);
  const now = Math.floor(Date.now() / 1000);
  for (const user of [{ badSignature: true }, { claims: { iss: 'http://127.0.0.1:1/realms/other' } }, { claims: { aud: 'another-client' } }, { claims: { exp: now - 600, iat: now - 900 } }]) {
    const s = await signIn(app, idp, user);
    assert.equal(s.back.statusCode, 400, JSON.stringify(user));
    assert.equal(s.cookie, null, JSON.stringify(user));
  }
});

test('a callback is used once, and a pending sign-in expires', async (t) => {
  const idp = await provider(t);
  let now = Date.now();
  const { app } = await make(t, idp, { clock: () => new Date(now) });
  const s = await signIn(app, idp);
  assert.equal(s.back.statusCode, 303);
  const again = await app.inject({ method: 'GET', url: s.callback, headers: { cookie: `oidc_login=${s.binding.value}` } });
  assert.equal(again.statusCode, 400, 'replayed');
  const start = await app.inject({ method: 'GET', url: '/auth/sign-in?return_to=/' });
  const { callback } = idp.authorize(start.headers.location);
  now += 11 * 60_000;
  const late = await app.inject({ method: 'GET', url: callback, headers: { cookie: `oidc_login=${cookiesOf(start).oidc_login.value}` } });
  assert.equal(late.statusCode, 400);
});

test('a second sign-in from the same browser replaces its pending one', async (t) => {
  const idp = await provider(t);
  const { app, pool } = await make(t, idp);
  const first = await app.inject({ method: 'GET', url: '/auth/sign-in?return_to=/' });
  const second = await app.inject({ method: 'GET', url: '/auth/sign-in?return_to=/x', headers: { cookie: `oidc_login=${cookiesOf(first).oidc_login.value}` } });
  assert.equal(second.statusCode, 302);
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM oidc_logins')).rows[0].n, 1);
});

test('signed in at the provider but unknown here: 403, no session, and a way to switch account', async (t) => {
  const idp = await provider(t);
  const { app, pool } = await make(t, idp);
  const s = await signIn(app, idp, { email: 'mallory@example.org' });
  assert.equal(s.back.statusCode, 403);
  assert.equal(s.cookie, null);
  assert.match(s.back.body, /no access here/);
  assert.match(s.back.body, new RegExp(`href="${idp.issuer}/logout\\?`));
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM sessions')).rows[0].n, 0);
});

test('return_to stays on this site', async (t) => {
  const idp = await provider(t);
  const { app } = await make(t, idp);
  for (const to of ['//evil.example/x', 'https://evil.example', '/\\evil.example']) {
    const start = await app.inject({ method: 'GET', url: `/auth/sign-in?return_to=${encodeURIComponent(to)}` });
    const { callback } = idp.authorize(start.headers.location);
    const back = await app.inject({ method: 'GET', url: callback, headers: { cookie: `oidc_login=${cookiesOf(start).oidc_login.value}` } });
    assert.equal(back.headers.location, '/', to);
  }
});

test('the app on another origin: return_to may name it exactly, and nothing else', async (t) => {
  const idp = await provider(t);
  const app0 = 'http://app.test:4190';
  const { app } = await make(t, idp, { allowedOrigins: app0 });
  const start = await app.inject({ method: 'GET', url: `/auth/sign-in?return_to=${encodeURIComponent(`${app0}/requests?status=requested`)}` });
  const { callback } = idp.authorize(start.headers.location);
  const back = await app.inject({ method: 'GET', url: callback, headers: { cookie: `oidc_login=${cookiesOf(start).oidc_login.value}` } });
  assert.equal(back.statusCode, 303);
  assert.equal(back.headers.location, `${app0}/requests?status=requested`);
  const allowed = new Set([app0]);
  for (const to of ['http://evil.test/', 'http://app.test:4190.evil.test/', 'https://app.test:4190/', 'http://app.test:4191/', 'http://user:pw@app.test:4190/', 'http://app.test:4190/ x', 'javascript:alert(1)', 'http:\\\\app.test:4190/', '//app.test:4190/'])
    assert.equal(safeReturn(to, allowed), '/', to);
  assert.equal(safeReturn(`${app0}/x#y`, allowed), `${app0}/x#y`);
  assert.equal(safeReturn(`${app0}/x`), '/', 'no allowed origins: paths only');
});

test('sign-out ends the session here and at the provider; a cross-site post is refused', async (t) => {
  const idp = await provider(t);
  const { app, pool } = await make(t, idp);
  const s = await signIn(app, idp);
  const form = { 'content-type': 'application/x-www-form-urlencoded', cookie: s.cookie };
  const evil = await app.inject({ method: 'POST', url: '/auth/sign-out', headers: { ...form, origin: 'https://evil.example' } });
  assert.equal(evil.statusCode, 403);
  assert.equal((await app.inject({ method: 'GET', url: '/api/me', headers: { cookie: s.cookie } })).statusCode, 200, 'still signed in');
  const page = await app.inject({ method: 'GET', url: '/auth/sign-out' });
  assert.match(page.body, /<form method="post" action="\/auth\/sign-out">/);
  assert.match(page.headers['content-security-policy'], new RegExp(`form-action 'self' ${new URL(idp.issuer).origin}`), 'the post may go on to the provider');
  const out = await app.inject({ method: 'POST', url: '/auth/sign-out', headers: { ...form, origin: 'http://127.0.0.1:4300', host: '127.0.0.1:4300' }, payload: '' });
  assert.equal(out.statusCode, 303);
  const away = new URL(out.headers.location);
  assert.equal(away.origin + away.pathname, `${idp.issuer}/logout`);
  assert.ok(away.searchParams.get('id_token_hint'));
  assert.equal(away.searchParams.get('post_logout_redirect_uri'), 'http://127.0.0.1:4300/auth/signed-out');
  assert.equal((await app.inject({ method: 'GET', url: '/api/me', headers: { cookie: s.cookie } })).statusCode, 401);
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM sessions')).rows[0].n, 0);
  assert.match((await app.inject({ method: 'GET', url: '/auth/signed-out' })).body, /You are signed out/);
});

test('the provider down: the sign-in answers 503 with a way back', async (t) => {
  const { app } = await make(t, { issuer: 'http://127.0.0.1:9/realms/test' });
  const r = await app.inject({ method: 'GET', url: '/auth/sign-in?return_to=/x' });
  assert.equal(r.statusCode, 503);
  assert.match(r.body, /href="\/auth\/sign-in\?return_to=%2Fx"/);
});

test('refused at build: an issuer on plain http off this machine, oidc with SIGN_IN_URL, no user mapping', async (t) => {
  assert.throws(() => oidcClient({ issuer: 'http://idp.example/realms/x', clientId: 'a', clientSecret: 'b', redirectUri: 'https://app.example/auth/callback' }), /not https/);
  assert.throws(() => oidcClient({ issuer: 'https://idp.example/realms/x', clientId: 'a', clientSecret: 'b', redirectUri: 'http://app.example/auth/callback' }), /not https/);
  assert.throws(() => oidcClient({ issuer: 'https://idp.example/realms/x', clientId: 'a', redirectUri: 'https://app.example/auth/callback' }), /clientSecret is required/);
  oidcClient({ issuer: 'http://idp.localhost:4380/realms/x', clientId: 'a', clientSecret: 'b', redirectUri: 'http://127.0.0.1:4300/auth/callback' });
  const idp = await provider(t);
  await assert.rejects(make(t, idp, { signInUrl: 'https://idp.example/authorize' }), /not both/);
  await assert.rejects(make(t, idp, { userFromClaims: undefined }), /userFromClaims/);
});
