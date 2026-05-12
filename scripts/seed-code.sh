#!/usr/bin/env bash
set -euo pipefail

echo "Seeding persistent Moodle code volume from the image..."
docker compose exec -T php /usr/local/bin/moodle-seed-code
echo "Seed completed."
