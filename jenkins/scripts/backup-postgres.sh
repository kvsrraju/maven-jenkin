#!/usr/bin/env bash
#
# Dumps an Azure Database for PostgreSQL database to a local custom-format file.
#
# Required environment variables:
#   PG_HOST      Fully qualified server name, e.g. myserver.postgres.database.azure.com
#   PG_DATABASE  Database name to dump
#   PG_USER      Login. Single Server expects 'user@servername'; Flexible Server expects 'user'
#   PGPASSWORD   Password (injected by Jenkins credentials, never logged)
#   BACKUP_DIR   Local directory the dump is written to
#   BACKUP_STAMP Timestamp used in the file name
# Optional:
#   PG_PORT      Defaults to 5432
#   PGSSLMODE    Defaults to 'require'
#
set -euo pipefail

: "${PG_HOST:?PG_HOST is required}"
: "${PG_DATABASE:?PG_DATABASE is required}"
: "${PG_USER:?PG_USER is required}"
: "${PGPASSWORD:?PGPASSWORD is required}"
: "${BACKUP_DIR:?BACKUP_DIR is required}"
: "${BACKUP_STAMP:?BACKUP_STAMP is required}"

PG_PORT="${PG_PORT:-5432}"
export PGSSLMODE="${PGSSLMODE:-require}"

if ! command -v pg_dump >/dev/null 2>&1; then
    echo "ERROR: 'pg_dump' was not found on this agent." >&2
    echo "Install the PostgreSQL client tools matching (or newer than) the server version." >&2
    exit 1
fi

mkdir -p "${BACKUP_DIR}"
TARGET_FILE="${BACKUP_DIR}/postgres-${PG_DATABASE}-${BACKUP_STAMP}.dump"

echo "Dumping PostgreSQL database '${PG_DATABASE}' from '${PG_HOST}' to ${TARGET_FILE}"

pg_dump \
    --host="${PG_HOST}" \
    --port="${PG_PORT}" \
    --username="${PG_USER}" \
    --dbname="${PG_DATABASE}" \
    --format=custom \
    --no-password \
    --verbose \
    --file="${TARGET_FILE}"

if [ ! -s "${TARGET_FILE}" ]; then
    echo "ERROR: ${TARGET_FILE} is missing or empty." >&2
    exit 1
fi

# Cheap integrity check: the archive table of contents must be readable.
if command -v pg_restore >/dev/null 2>&1; then
    pg_restore --list "${TARGET_FILE}" >/dev/null
fi

echo "PostgreSQL backup complete: ${TARGET_FILE} ($(du -h "${TARGET_FILE}" | cut -f1))"
