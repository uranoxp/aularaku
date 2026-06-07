#!/bin/sh
set -eu

SOURCE_DIR="/opt/moodle-dist"
TARGET_DIR="/var/www/moodle"

if [ ! -f "${SOURCE_DIR}/lib/setup.php" ]; then
  echo "Moodle source tree not found in image: ${SOURCE_DIR}" >&2
  exit 1
fi

mkdir -p "${TARGET_DIR}"

if [ ! -f "${TARGET_DIR}/lib/setup.php" ]; then
  echo "Seeding persistent Moodle code volume..."
  find "${TARGET_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  cp -a "${SOURCE_DIR}/." "${TARGET_DIR}/"
  chown -R www-data:www-data "${TARGET_DIR}"
else
  echo "Persistent Moodle code already present. Skipping seed."
fi
