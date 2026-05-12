#!/usr/bin/env bash
set -euo pipefail

DATE="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups/aulamirai}"
mkdir -p "$BACKUP_DIR"

OUTPUT_FILE="$BACKUP_DIR/moodle-config-$DATE.tar.gz"

echo "Creating config backup: $OUTPUT_FILE"

docker compose exec -T php tar -C /var/www -czf - moodle-state/config.php > "$OUTPUT_FILE"

echo "Config backup completed: $OUTPUT_FILE"
