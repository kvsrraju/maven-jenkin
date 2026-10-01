#!/usr/bin/env bash
#
# Deletes local database backups older than RETENTION_DAYS.
#
# Required environment variables:
#   BACKUP_ROOT     Directory holding the backup files
#   RETENTION_DAYS  Number of days to keep. 0 disables cleanup.
#
set -euo pipefail

: "${BACKUP_ROOT:?BACKUP_ROOT is required}"
: "${RETENTION_DAYS:?RETENTION_DAYS is required}"

if ! [[ "${RETENTION_DAYS}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: RETENTION_DAYS must be a non-negative integer, got '${RETENTION_DAYS}'." >&2
    exit 1
fi

if [ "${RETENTION_DAYS}" -eq 0 ]; then
    echo "RETENTION_DAYS is 0, skipping cleanup."
    exit 0
fi

if [ ! -d "${BACKUP_ROOT}" ]; then
    echo "Backup root '${BACKUP_ROOT}' does not exist yet, nothing to clean up."
    exit 0
fi

echo "Removing backups in ${BACKUP_ROOT} older than ${RETENTION_DAYS} day(s)"

find "${BACKUP_ROOT}" \
    -maxdepth 2 -type f \
    \( -name '*.bacpac' -o -name '*.dump' \) \
    -mtime "+${RETENTION_DAYS}" \
    -print -delete

# Drop any per-run directories left empty after the deletions above.
find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -empty -print -delete

echo "Cleanup complete."
