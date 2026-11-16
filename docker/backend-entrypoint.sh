#!/bin/sh
set -eu

# Apply migrations to every tenant database. Safe to repeat; with more than one
# backend replica run this as a separate one-off job instead (see docs).
if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  python manage.py migrate_tenants
fi

# Optional fictional demo data for the two sample tenants
if [ "${SEED_DEMO_DATA:-false}" = "true" ]; then
  python manage.py seed_demo
fi

exec "$@"
