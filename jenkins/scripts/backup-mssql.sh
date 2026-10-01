#!/usr/bin/env bash
#
# Exports an Azure SQL (MSSQL) database to a local .bacpac file using sqlpackage.
#
# Required environment variables:
#   MSSQL_SERVER    Fully qualified server name, e.g. myserver.database.windows.net
#   MSSQL_DATABASE  Database name to export
#   MSSQL_USER      SQL login
#   MSSQL_PASSWORD  SQL password (injected by Jenkins credentials, never logged)
#   BACKUP_DIR      Local directory the .bacpac is written to
#   BACKUP_STAMP    Timestamp used in the file name
#
set -euo pipefail

: "${MSSQL_SERVER:?MSSQL_SERVER is required}"
: "${MSSQL_DATABASE:?MSSQL_DATABASE is required}"
: "${MSSQL_USER:?MSSQL_USER is required}"
: "${MSSQL_PASSWORD:?MSSQL_PASSWORD is required}"
: "${BACKUP_DIR:?BACKUP_DIR is required}"
: "${BACKUP_STAMP:?BACKUP_STAMP is required}"

if ! command -v sqlpackage >/dev/null 2>&1; then
    echo "ERROR: 'sqlpackage' was not found on this agent." >&2
    echo "Install it from https://learn.microsoft.com/sql/tools/sqlpackage/sqlpackage-download" >&2
    exit 1
fi

mkdir -p "${BACKUP_DIR}"
TARGET_FILE="${BACKUP_DIR}/mssql-${MSSQL_DATABASE}-${BACKUP_STAMP}.bacpac"

echo "Exporting MSSQL database '${MSSQL_DATABASE}' from '${MSSQL_SERVER}' to ${TARGET_FILE}"

# Secrets are passed as arguments, so keep shell tracing off for this command.
sqlpackage \
    /Action:Export \
    /SourceServerName:"${MSSQL_SERVER}" \
    /SourceDatabaseName:"${MSSQL_DATABASE}" \
    /SourceUser:"${MSSQL_USER}" \
    /SourcePassword:"${MSSQL_PASSWORD}" \
    /SourceEncryptConnection:True \
    /TargetFile:"${TARGET_FILE}"

if [ ! -s "${TARGET_FILE}" ]; then
    echo "ERROR: ${TARGET_FILE} is missing or empty." >&2
    exit 1
fi

echo "MSSQL backup complete: ${TARGET_FILE} ($(du -h "${TARGET_FILE}" | cut -f1))"
