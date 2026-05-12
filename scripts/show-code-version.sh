#!/usr/bin/env bash
set -euo pipefail

docker compose exec -T php /usr/local/bin/moodle-code-version
