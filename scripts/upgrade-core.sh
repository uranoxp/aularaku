#!/usr/bin/env bash
set -euo pipefail

echo "Synchronizing Moodle core from the current image into the persistent volume..."
docker compose exec -T php /usr/local/bin/moodle-sync-core

echo "Running Moodle upgrade.php..."
docker compose exec -T php php /var/www/moodle/admin/cli/upgrade.php --non-interactive

echo "Core upgrade flow completed."
