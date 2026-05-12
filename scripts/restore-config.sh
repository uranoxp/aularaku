#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: ./scripts/restore-config.sh /path/to/moodle-config.tar.gz"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "Restoring config.php from: $BACKUP_FILE"

cat "$BACKUP_FILE" | docker compose exec -T php sh -c \
  "mkdir -p /var/www/moodle-state && tar -xzf - -C /var/www && chown -R www-data:www-data /var/www/moodle-state"

echo "Config restore completed."
