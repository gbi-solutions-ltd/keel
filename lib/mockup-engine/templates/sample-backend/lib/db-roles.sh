#!/bin/sh
# Run once by the postgres image on an empty data directory (/docker-entrypoint-initdb.d): two
# roles besides the superuser, which the backend never uses. backend_owner owns the backend's
# schema and runs its migrations; backend_app is what the server runs as, granted only what the
# application needs (lib/db.mjs grant), so a bug or a stolen connection string cannot rewrite an
# append-only table or run commands as the superuser.
set -eu
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v owner_pw="$POSTGRES_OWNER_PASSWORD" -v app_pw="$POSTGRES_APP_PASSWORD" <<'SQL'
CREATE ROLE backend_owner LOGIN PASSWORD :'owner_pw';
CREATE ROLE backend_app LOGIN PASSWORD :'app_pw';
GRANT CREATE, CONNECT ON DATABASE postgres TO backend_owner;
GRANT CONNECT ON DATABASE postgres TO backend_app;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
SQL
