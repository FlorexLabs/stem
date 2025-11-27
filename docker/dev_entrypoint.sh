#!/bin/bash

set -euo pipefail

# Entry point for Lucky dev container

warnfail () {
  echo "$@" >&2
  exit 1
}

case ${1:-} in
  "") ;;         # no args → run default
  *)  exec "$@" ;;  # args → run as command
esac

if ! [ -d bin ] ; then
  echo 'Creating bin directory'
  mkdir bin
fi

if ! shards check ; then
  echo 'Installing shards...'
  shards install
fi

echo 'Waiting for postgres to be available...'

./docker/wait-for-it.sh -q "${DB_HOST:-db}:${DB_PORT:-5432}"

DB_USER="${DB_USERNAME:-postgres}"
DB_PASS="${DB_PASSWORD:-postgres}"
DB_NAME="${DB_NAME:-stem_development}"
DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-5432}"

PSQL_URL="postgres://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

# Run migrations only if migrations table does not exist
if ! PGPASSWORD="$DB_PASS" psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -c '\d migrations' > /dev/null 2>&1 ; then
  echo 'Finishing database setup (running migrations)...'
  lucky db.migrate
fi

echo 'Starting lucky dev server...'
exec lucky dev
