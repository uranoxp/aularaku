#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: ./scripts/restore-db.sh /path/to/backup.sql.gz"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file not found: $BACKUP_FILE"
  exit 1
fi

DB_NAME="${MOODLE_DB_NAME:-moodle}"
DB_USER="${MOODLE_DB_USER:-moodle_user}"
DB_PASS="${MOODLE_DB_PASSWORD:-change_me}"

echo "Restoring database from: $BACKUP_FILE"

gunzip -c "$BACKUP_FILE" | docker compose exec -T mariadb sh -c \
  "MYSQL_PWD='$DB_PASS' mariadb -u'$DB_USER' '$DB_NAME'"

echo "Database restore completed."
