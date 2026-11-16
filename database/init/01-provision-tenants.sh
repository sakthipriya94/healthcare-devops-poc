#!/usr/bin/env bash
# Runs once, the first time the local Postgres container initialises its data
# volume (docker-entrypoint-initdb.d). Passwords arrive via container env vars.
set -euo pipefail
export PGUSER="$POSTGRES_USER" PGPASSWORD="$POSTGRES_PASSWORD"
bash /opt/db-scripts/provision_tenants.sh \
  "hospital_a:hospital_a_user:HOSPITAL_A_DB_PASSWORD" \
  "hospital_b:hospital_b_user:HOSPITAL_B_DB_PASSWORD"
