#!/usr/bin/env bash
set -euo pipefail

cat >> "$PGDATA/pg_hba.conf" <<'HBA'

# Demo-only Docker network access. Do not use trust authentication in production.
host replication replicator 0.0.0.0/0 trust
host replication replicator ::/0 trust
host all all 0.0.0.0/0 trust
host all all ::/0 trust
HBA

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
CREATE ROLE replicator WITH REPLICATION LOGIN;
CREATE ROLE app_user WITH LOGIN;
CREATE ROLE pgpool_health WITH LOGIN;

CREATE TABLE IF NOT EXISTS public.ha_demo (
    id bigserial PRIMARY KEY,
    message text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.ha_demo (message)
VALUES ('created on primary during bootstrap');

GRANT CONNECT ON DATABASE appdb TO app_user, pgpool_health;
GRANT USAGE ON SCHEMA public TO app_user, pgpool_health;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ha_demo TO app_user;
GRANT USAGE, SELECT ON SEQUENCE public.ha_demo_id_seq TO app_user;
SQL
