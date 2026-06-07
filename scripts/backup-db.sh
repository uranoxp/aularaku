#!/usr/bin/env bash
set -euo pipefail

DATE="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups/aularaku}"
mkdir -p "$BACKUP_DIR"

DB_NAME="${MOODLE_DB_NAME:-moodle}"
DB_USER="${MOODLE_DB_USER:-moodle_user}"
DB_PASS="${MOODLE_DB_PASSWORD:-change_me}"

OUTPUT_FILE="$BACKUP_DIR/moodle-db-$DATE.sql.gz"

echo "Creating database backup: $OUTPUT_FILE"

docker compose exec -T mariadb sh -c \
  "MYSQL_PWD='$DB_PASS' mariadb-dump --single-transaction --quick -u'$DB_USER' '$DB_NAME'" \
  | gzip > "$OUTPUT_FILE"

echo "Database backup completed: $OUTPUT_FILE"
