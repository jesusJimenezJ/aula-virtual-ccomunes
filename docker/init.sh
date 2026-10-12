#!/usr/bin/env bash
set -euo pipefail
: "${MARIADB_ROOT_PASSWORD:?Falta MARIADB_ROOT_PASSWORD en .env}"
: "${SITE_ADMIN_PASSWORD:?Falta SITE_ADMIN_PASSWORD en .env}"
: "${SITE_NAME:?Falta SITE_NAME en .env}"
: "${FRAPPE_BRANCH:?Falta FRAPPE_BRANCH en .env}"

BENCH_DIR=/home/frappe/frappe-bench

if [ ! -d "$BENCH_DIR/apps/frappe" ]; then
    echo "Preparando Frappe Bench; la primera instalación puede tardar varios minutos..."
    bench init --skip-redis-config-generation --frappe-branch "$FRAPPE_BRANCH" "$BENCH_DIR"
fi

cd "$BENCH_DIR"
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379
sed -i '/^redis/d' Procfile
sed -i '/^watch/d' Procfile

if [ ! -d apps/payments ]; then bench get-app payments; fi
if [ ! -e apps/lms ]; then bench get-app --soft-link lms /workspace; fi

if [ ! -f "sites/$SITE_NAME/site_config.json" ]; then
    bench new-site "$SITE_NAME" \
        --mariadb-root-password "$MARIADB_ROOT_PASSWORD" \
        --admin-password "$SITE_ADMIN_PASSWORD" \
        --no-mariadb-socket
fi

if ! bench --site "$SITE_NAME" list-apps | grep -Fxq payments; then
    bench --site "$SITE_NAME" install-app payments
fi
if ! bench --site "$SITE_NAME" list-apps | grep -Fxq lms; then
    bench --site "$SITE_NAME" install-app lms
fi

bench --site "$SITE_NAME" set-config developer_mode 1
bench --site "$SITE_NAME" clear-cache
bench use "$SITE_NAME"

if [ ! -f sites/.ccomunes-assets-built ]; then
    bench build --app lms
    touch sites/.ccomunes-assets-built
fi

exec bench start
