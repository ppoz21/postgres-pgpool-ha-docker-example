#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" = "0" ]; then
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$(dirname "$PGDATA")"
    exec gosu postgres "$0" "$@"
fi

if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "Initializing standby from ${PRIMARY_HOST}:${PRIMARY_PORT}..."
    rm -rf "$PGDATA"/*

    until pg_isready -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U postgres >/dev/null 2>&1; do
        echo "Waiting for primary to accept connections..."
        sleep 2
    done

    pg_basebackup \
        -h "$PRIMARY_HOST" \
        -p "$PRIMARY_PORT" \
        -D "$PGDATA" \
        -U "$REPLICATION_USER" \
        -Fp \
        -Xs \
        -P \
        -R
fi

exec docker-entrypoint.sh "$@"
