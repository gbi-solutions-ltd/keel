-- The CSRF token is bound to its session: stored by its hash, checked against the header.
DELETE FROM sessions;
ALTER TABLE sessions ADD COLUMN csrf_hash text NOT NULL;
