#!/usr/bin/env bash
set -euo pipefail

DATE="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups/aulamirai}"
mkdir -p "$BACKUP_DIR"

OUTPUT_FILE="$BACKUP_DIR/moodle-code-$DATE.tar.gz"

echo "Creating Moodle code backup: $OUTPUT_FILE"

docker compose exec -T php sh -c \
  "tar --exclude=config.php -C /var/www -czf - moodle" > "$OUTPUT_FILE"

echo "Moodle code backup completed: $OUTPUT_FILE"
