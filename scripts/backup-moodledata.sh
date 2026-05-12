#!/usr/bin/env bash
set -euo pipefail

DATE="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups/aulamirai}"
mkdir -p "$BACKUP_DIR"

OUTPUT_FILE="$BACKUP_DIR/moodledata-$DATE.tar.gz"

echo "Creating moodledata backup: $OUTPUT_FILE"

docker compose exec -T php tar -C /var/www -czf - moodledata > "$OUTPUT_FILE"

echo "Moodledata backup completed: $OUTPUT_FILE"
