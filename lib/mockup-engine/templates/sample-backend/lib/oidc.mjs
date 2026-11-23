/**
 * oidc.mjs: the backend for frontend's sign-in through an OpenID Connect provider (the
 * authorization code flow, a confidential client, with PKCE, state and nonce), built on
 * openid-client. lib/app.mjs mounts it under /auth when an app with no sign-in screen
 * (signIn: 'redirect') is given an issuer (OIDC_ISSUER).
 *
 * What it checks, through openid-client: the provider's metadata is for the issuer named (its
 * `issuer` equals the URL discovered); the callback's state is the one this browser was given; the
 * code is exchanged with the PKCE verifier and the client secret; the ID token is signed by a key
 * in the provider's JWKS, its `iss` is the issuer, its `aud` holds this client, it has not expired,
 * and its nonce is the one sent. The provider is discovered on first use and cached, so a provider
 * that is down when the backend starts does not stop it (the sign-in answers 503 until it is up).
 *
 * Plain http is refused for an issuer, except on a loopback or .localhost host (a local run).
 */
import * as client from 'openid-client';

const LOCAL = /^(127\.\d+\.\d+\.\d+|localhost|\[::1\]|.+\.localhost)$/;

/**
 * options: { issuer, clientId, clientSecret, redirectUri (this backend's /auth/callback, as the
 * provider has it registered), postLogoutRedirectUri? (where the provider sends the browser after
 * sign-out; default the redirect URI's origin + /auth/signed-out), scope? (default 'openid profile
 * email') }.
 */
export function oidcClient(options) {
  for (const k of ['issuer', 'clientId', 'clientSecret', 'redirectUri'])
    if (!options?.[k]) throw new Error(`oidc: ${k} is required (OIDC_ISSUER, OIDC_CLIENT_ID, OIDC_CLIENT_SECRET, OIDC_REDIRECT_URI)`);
  const issuer = new URL(options.issuer);
  const redirectUri = new URL(options.redirectUri);
  for (const [name, u] of [['issuer', issuer], ['redirect URI', redirectUri]])
    if (u.protocol !== 'https:' && !(u.protocol === 'http:' && LOCAL.test(u.hostname)))
      throw new Error(`oidc: the ${name} ${u.href} is not https (plain http only on a loopback or .localhost host)`);
  const insecure = issuer.protocol === 'http:';
  const postLogout = options.postLogoutRedirectUri ?? new URL('/auth/signed-out', redirectUri).href;
  const scope = options.scope ?? 'openid profile email';
  let found = null;

  async function config() {
    if (!found)
      found = client
        // enableNonRepudiationChecks: the ID token's signature is checked against the provider's
        // JWKS too (openid-client trusts the token endpoint's TLS alone by default).
        .discovery(issuer, options.clientId, options.clientSecret, undefined, { execute: [...(insecure ? [client.allowInsecureRequests] : []), client.enableNonRepudiationChecks] })
        .catch((e) => {
          found = null;
          throw e;
        });
    return found;
  }

  return {
    redirectUri: redirectUri.href,
    /** Where to send the browser to sign in, and what the callback must match (kept server side). */
    async start() {
      const c = await config();
      const verifier = client.randomPKCECodeVerifier();
      const state = client.randomState();
      const nonce = client.randomNonce();
      const url = client.buildAuthorizationUrl(c, {
        redirect_uri: redirectUri.href,
        scope,
        state,
        nonce,
        code_challenge: await client.calculatePKCECodeChallenge(verifier),
        code_challenge_method: 'S256',
      });
      return { url: url.href, state, nonce, verifier };
    },
    /** The callback's query, checked against what start() gave; returns the ID token's claims. */
    async finish(search, { state, nonce, verifier }) {
      const c = await config();
      const current = new URL(redirectUri.href);
      current.search = search;
      const tokens = await client.authorizationCodeGrant(c, current, { pkceCodeVerifier: verifier, expectedState: state, expectedNonce: nonce, idTokenExpected: true });
      return { claims: tokens.claims(), idToken: tokens.id_token };
    },
    /** The provider's end-session URL (RP-initiated logout), or null when it has none. */
    async endSession(idToken) {
      const c = await config();
      if (!c.serverMetadata().end_session_endpoint) return null;
      return client.buildEndSessionUrl(c, { post_logout_redirect_uri: postLogout, ...(idToken ? { id_token_hint: idToken } : { client_id: options.clientId }) }).href;
    },
  };
}
