-- The template's own tables: sessions and idempotency replays. The app's tables come after, from
-- its migrations/ folder.

-- A session is stored by the hash of its token: a leaked table holds no usable cookie.
CREATE TABLE sessions (
  token_hash text PRIMARY KEY,
  user_id text NOT NULL,
  "user" jsonb NOT NULL,
  marks jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL,
  seen_at timestamptz NOT NULL
);
CREATE INDEX sessions_user ON sessions (user_id);

-- One row per (user, operation, key): the first answer, replayed for the same body.
CREATE TABLE idempotency (
  key text PRIMARY KEY,
  body_hash text NOT NULL,
  status integer NOT NULL,
  body jsonb,
  created_at timestamptz NOT NULL
);
