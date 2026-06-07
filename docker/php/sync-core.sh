#!/bin/sh
set -eu

SOURCE_DIR="/opt/moodle-dist"
TARGET_DIR="/var/www/moodle"
STATE_CONFIG="/var/www/moodle-state/config.php"
PROTECT_FILE="$(mktemp)"

cleanup() {
  rm -f "${PROTECT_FILE}"
}
trap cleanup EXIT

if [ ! -f "${SOURCE_DIR}/lib/setup.php" ]; then
  echo "Moodle source tree not found in image: ${SOURCE_DIR}" >&2
  exit 1
fi

if [ ! -f "${TARGET_DIR}/lib/setup.php" ]; then
  echo "Persistent Moodle code volume is empty. Run moodle-seed-code first." >&2
  exit 1
fi

echo "Calculating custom files to preserve..."
(
  cd "${TARGET_DIR}"
  find . -mindepth 1 -print | sed 's#^\./##' | while IFS= read -r relpath; do
    [ "${relpath}" = "config.php" ] && continue
    if [ ! -e "${SOURCE_DIR}/${relpath}" ]; then
      printf 'P /%s\n' "${relpath}" >> "${PROTECT_FILE}"
    fi
  done
)

echo "Synchronizing Moodle core into persistent volume..."
rsync -a --delete \
  --exclude '/config.php' \
  --filter="merge ${PROTECT_FILE}" \
  "${SOURCE_DIR}/" "${TARGET_DIR}/"

if [ -f "${STATE_CONFIG}" ]; then
  ln -sfn "${STATE_CONFIG}" "${TARGET_DIR}/config.php"
  chown -h www-data:www-data "${TARGET_DIR}/config.php"
fi

chown -R www-data:www-data "${TARGET_DIR}"
echo "Core sync completed. Custom files were preserved."
