#!/bin/sh
# Backup script — run via cron on EU server
# Requires: DATABASE_URL, BACKUP_DIR

set -e
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-/var/backups/just-clock}"
mkdir -p "$BACKUP_DIR"

pg_dump "$DATABASE_URL" | gzip > "$BACKUP_DIR/justclock_${DATE}.sql.gz"
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +30 -delete

echo "Backup saved: $BACKUP_DIR/justclock_${DATE}.sql.gz"
