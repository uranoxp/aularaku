#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: ./scripts/restore-moodledata.sh /path/to/moodledata.tar.gz"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "Restoring moodledata from: $BACKUP_FILE"

cat "$BACKUP_FILE" | docker compose exec -T php sh -c \
  "find /var/www/moodledata -mindepth 1 -maxdepth 1 -exec rm -rf {} + && tar -xzf - -C /var/www && chown -R www-data:www-data /var/www/moodledata"

echo "Moodledata restore completed."
