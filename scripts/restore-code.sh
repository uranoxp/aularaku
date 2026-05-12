#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: ./scripts/restore-code.sh /path/to/moodle-code.tar.gz"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "Restoring persistent Moodle code from: $BACKUP_FILE"

cat "$BACKUP_FILE" | docker compose exec -T php sh -c \
  "find /var/www/moodle -mindepth 1 -maxdepth 1 ! -name config.php -exec rm -rf {} + && tar -xzf - -C /var/www && if [ -f /var/www/moodle-state/config.php ]; then ln -sfn /var/www/moodle-state/config.php /var/www/moodle/config.php; fi && chown -R www-data:www-data /var/www/moodle && chown -h www-data:www-data /var/www/moodle/config.php 2>/dev/null || true"

echo "Persistent Moodle code restore completed."
