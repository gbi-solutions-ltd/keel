-- Sign-in through an OpenID Connect provider: one pending sign-in per browser, found by the hash
-- of a random binding cookie (so a callback another browser started is refused), used once, and
-- the session's ID token, sent back to the provider at sign-out.
CREATE TABLE oidc_logins (
  binding_hash text PRIMARY KEY,
  state text NOT NULL,
  nonce text NOT NULL,
  verifier text NOT NULL,
  return_to text NOT NULL,
  created_at timestamptz NOT NULL
);
ALTER TABLE sessions ADD COLUMN id_token text;
