#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/srv/backups/aulamirai}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
DATE="$(date +%Y-%m-%d_%H-%M-%S)"

mkdir -p "$BACKUP_DIR"

echo "Starting full Moodle backup..."

./scripts/backup-code.sh
./scripts/backup-db.sh
./scripts/backup-moodledata.sh
./scripts/backup-config.sh

if [ -f .env ]; then
  cp .env "$BACKUP_DIR/runtime-env-$DATE.env"
  echo "Saved local .env snapshot: $BACKUP_DIR/runtime-env-$DATE.env"
fi

find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -delete

echo "Full backup completed."
echo "Remember to also back up any custom plugins or themes from their build source."
