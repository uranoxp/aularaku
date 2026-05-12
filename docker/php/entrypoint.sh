#!/bin/sh
set -eu

require_env() {
  name="$1"
  eval "value=\${$name:-}"
  if [ -z "$value" ]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

php_escape() {
  printf "%s" "$1" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g"
}

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

render_php_ini() {
  cat > /usr/local/etc/php/conf.d/99-runtime.ini <<EOF
memory_limit=${PHP_MEMORY_LIMIT:-512M}
upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE:-256M}
post_max_size=${PHP_POST_MAX_SIZE:-256M}
max_input_vars=${PHP_MAX_INPUT_VARS:-5000}
max_execution_time=${PHP_MAX_EXECUTION_TIME:-300}
max_input_time=${PHP_MAX_INPUT_TIME:-300}
date.timezone=${TZ:-UTC}
display_errors=Off
log_errors=On
error_reporting=E_ALL & ~E_DEPRECATED & ~E_STRICT
file_uploads=On
allow_url_fopen=On
session.cookie_httponly=1
session.use_strict_mode=1
EOF
}

seed_code() {
  /usr/local/bin/moodle-seed-code
}

render_config() {
  mkdir -p /var/www/moodle-state /var/www/moodledata /var/www/moodledata/localcache

  config_file="/var/www/moodle-state/config.php"
  moodle_url="$(php_escape "${MOODLE_URL}")"
  moodle_db_host="$(php_escape "${MOODLE_DB_HOST}")"
  moodle_db_port="$(php_escape "${MOODLE_DB_PORT}")"
  moodle_db_name="$(php_escape "${MOODLE_DB_NAME}")"
  moodle_db_user="$(php_escape "${MOODLE_DB_USER}")"
  moodle_db_password="$(php_escape "${MOODLE_DB_PASSWORD}")"
  moodle_db_prefix="$(php_escape "${MOODLE_DB_PREFIX}")"
  timezone_value="$(php_escape "${TZ}")"

  cat > "${config_file}" <<EOF
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype = 'mariadb';
\$CFG->dblibrary = 'native';
\$CFG->dbhost = '${moodle_db_host}';
\$CFG->dbname = '${moodle_db_name}';
\$CFG->dbuser = '${moodle_db_user}';
\$CFG->dbpass = '${moodle_db_password}';
\$CFG->prefix = '${moodle_db_prefix}';
\$CFG->dboptions = array(
  'dbpersist' => 0,
  'dbsocket' => 0,
  'dbport' => '${moodle_db_port}',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot = '${moodle_url}';
\$CFG->dataroot = '/var/www/moodledata';
\$CFG->dirroot = '/var/www/moodle';
\$CFG->libdir = '/var/www/moodle/public';
\$CFG->routerconfigured = false;
\$CFG->admin = 'admin';
\$CFG->directorypermissions = 02775;
\$CFG->localcachedir = '/var/www/moodledata/localcache';
\$CFG->timezone = '${timezone_value}';
EOF

  if is_true "${MOODLE_REVERSE_PROXY:-1}"; then
    cat >> "${config_file}" <<'EOF'
$CFG->reverseproxy = true;
EOF
  fi

  if is_true "${MOODLE_SSL_PROXY:-1}"; then
    cat >> "${config_file}" <<'EOF'
$CFG->sslproxy = true;
EOF
  fi

  if is_true "${MOODLE_USE_REDIS_SESSIONS:-1}"; then
    redis_host="$(php_escape "${REDIS_HOST}")"
    redis_port="$(php_escape "${REDIS_PORT}")"
    redis_db="$(php_escape "${REDIS_DATABASE}")"
    redis_password="$(php_escape "${REDIS_PASSWORD:-}")"
    redis_prefix="$(php_escape "${REDIS_SESSION_PREFIX:-}")"
    redis_lock_timeout="$(php_escape "${REDIS_SESSION_LOCK_TIMEOUT:-120}")"
    redis_lock_retry="$(php_escape "${REDIS_SESSION_LOCK_RETRY:-100}")"
    cat >> "${config_file}" <<EOF
\$CFG->session_handler_class = '\\core\\session\\redis';
\$CFG->session_redis_host = '${redis_host}';
\$CFG->session_redis_port = ${redis_port};
\$CFG->session_redis_database = ${redis_db};
\$CFG->session_redis_auth = '${redis_password}';
\$CFG->session_redis_prefix = '${redis_prefix}';
\$CFG->session_redis_acquire_lock_timeout = ${redis_lock_timeout};
\$CFG->session_redis_acquire_lock_retry = ${redis_lock_retry};
EOF
  fi

  cat >> "${config_file}" <<'EOF'
require_once('/var/www/moodle/lib/setup.php');
EOF

  chmod 0640 "${config_file}"
  chown www-data:www-data "${config_file}"
  ln -sfn /var/www/moodle-state/config.php /var/www/moodle/config.php
  chown -h www-data:www-data /var/www/moodle/config.php
  chown -R www-data:www-data /var/www/moodle-state /var/www/moodledata /var/www/moodle
}

wait_for_db() {
  echo "Waiting for MariaDB at ${MOODLE_DB_HOST}:${MOODLE_DB_PORT}..."
  until MYSQL_PWD="${MOODLE_DB_PASSWORD}" mariadb-admin ping \
    --host="${MOODLE_DB_HOST}" \
    --port="${MOODLE_DB_PORT}" \
    --user="${MOODLE_DB_USER}" \
    --silent >/dev/null 2>&1; do
    sleep 3
  done
}

wait_for_redis() {
  if ! is_true "${MOODLE_USE_REDIS_SESSIONS:-1}"; then
    return 0
  fi

  echo "Waiting for Redis at ${REDIS_HOST}:${REDIS_PORT}..."
  if [ -n "${REDIS_PASSWORD:-}" ]; then
    until redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" ping | grep -q PONG; do
      sleep 3
    done
  else
    until redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" ping | grep -q PONG; do
      sleep 3
    done
  fi
}

table_exists() {
  escaped_prefix="$(printf "%s" "${MOODLE_DB_PREFIX}" | sed 's/[\\%_]/\\&/g')"
  table_name="$(MYSQL_PWD="${MOODLE_DB_PASSWORD}" mariadb \
    --host="${MOODLE_DB_HOST}" \
    --port="${MOODLE_DB_PORT}" \
    --user="${MOODLE_DB_USER}" \
    --database="${MOODLE_DB_NAME}" \
    --skip-column-names \
    --batch \
    --execute="SHOW TABLES LIKE '${escaped_prefix}config';" 2>/dev/null || true)"
  [ -n "${table_name}" ]
}

run_install() {
  if table_exists; then
    echo "Moodle database already exists. Skipping installation."
    return 0
  fi

  if ! is_true "${MOODLE_AUTO_INSTALL:-1}"; then
    echo "MOODLE_AUTO_INSTALL is disabled. Skipping initial install."
    return 0
  fi

  echo "Running Moodle CLI installation..."
  support_flag=""
  if [ -n "${MOODLE_SUPPORT_EMAIL:-}" ]; then
    support_flag="--supportemail=${MOODLE_SUPPORT_EMAIL}"
  fi

  su-exec www-data php /var/www/moodle/admin/cli/install_database.php \
    --agree-license \
    --adminuser="${MOODLE_ADMIN_USER}" \
    --adminpass="${MOODLE_ADMIN_PASSWORD}" \
    --adminemail="${MOODLE_ADMIN_EMAIL}" \
    --fullname="${MOODLE_SITE_FULLNAME}" \
    --shortname="${MOODLE_SITE_SHORTNAME}" \
    --summary="${MOODLE_SITE_SUMMARY}" \
    --lang="${MOODLE_INSTALL_LANG:-en}" \
    ${support_flag}

  su-exec www-data php /var/www/moodle/admin/cli/cfg.php --name=timezone --set="${TZ}"

  MYSQL_PWD="${MOODLE_DB_PASSWORD}" mariadb \
    --host="${MOODLE_DB_HOST}" \
    --port="${MOODLE_DB_PORT}" \
    --user="${MOODLE_DB_USER}" \
    --database="${MOODLE_DB_NAME}" \
    --execute="UPDATE ${MOODLE_DB_PREFIX}user SET lastip='' WHERE username='${MOODLE_ADMIN_USER}';" >/dev/null 2>&1 || true
}

wait_until_installed() {
  echo "Waiting for Moodle installation to finish..."
  until table_exists; do
    sleep 5
  done
}

bootstrap() {
  require_env MOODLE_URL
  require_env TZ
  require_env MOODLE_DB_HOST
  require_env MOODLE_DB_PORT
  require_env MOODLE_DB_NAME
  require_env MOODLE_DB_USER
  require_env MOODLE_DB_PASSWORD
  require_env MOODLE_DB_PREFIX

  if is_true "${MOODLE_AUTO_INSTALL:-1}"; then
    require_env MOODLE_ADMIN_USER
    require_env MOODLE_ADMIN_PASSWORD
    require_env MOODLE_ADMIN_EMAIL
    require_env MOODLE_SITE_FULLNAME
    require_env MOODLE_SITE_SHORTNAME
    require_env MOODLE_SITE_SUMMARY
  fi

  if is_true "${MOODLE_USE_REDIS_SESSIONS:-1}"; then
    require_env REDIS_HOST
    require_env REDIS_PORT
    require_env REDIS_DATABASE
  fi

  render_php_ini
  seed_code
  render_config
  wait_for_db
  wait_for_redis

  case "${MOODLE_RUNTIME_ROLE:-web}" in
    web)
      run_install
      ;;
    cron)
      wait_until_installed
      ;;
  esac
}

bootstrap
exec "$@"
