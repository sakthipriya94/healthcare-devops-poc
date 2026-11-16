#!/usr/bin/env bash
# Idempotently create one database + one login role per tenant, and lock each
# database so ONLY its own role can connect (tenant isolation at the DB layer).
#
# Usage:   provision_tenants.sh <db>:<role>:<PASSWORD_ENV_VAR> [...]
# Example: provision_tenants.sh hospital_a:hospital_a_user:HOSPITAL_A_DB_PASSWORD
#
# Connection comes from the standard libpq variables (PGHOST, PGPORT, PGUSER,
# PGPASSWORD, PGSSLMODE...). Used for both the local Postgres container
# (docker-entrypoint-initdb.d) and AWS RDS (bootstrap_rds.sh).
# Safe to re-run; re-running also rotates a role's password to the current value.
set -euo pipefail

[ "$#" -ge 1 ] || { echo "usage: $0 db:role:PASSWORD_ENV [...]" >&2; exit 2; }

for spec in "$@"; do
  IFS=: read -r db role pw_env <<<"$spec"
  pw="${!pw_env:-}"
  [ -n "$pw" ] || { echo "ERROR: env var $pw_env is empty/unset" >&2; exit 1; }

  echo ">> provisioning tenant database '$db' (role '$role')"
  # Password is passed as a psql variable (not interpolated into shell/SQL text)
  psql -v ON_ERROR_STOP=1 -v db="$db" -v usr="$role" -v pw="$pw" --dbname postgres <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'usr', :'pw')
 WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'usr') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'usr', :'pw') \gexec
-- On RDS the master user is not a superuser: it must be a member of the role to own objects for it
SELECT format('GRANT %I TO CURRENT_USER', :'usr')
 WHERE EXISTS (SELECT FROM pg_roles WHERE rolname = current_user AND NOT rolsuper) \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db', :'usr')
 WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db') \gexec
-- Nobody but the tenant's own role may even connect to the database
REVOKE ALL ON DATABASE :"db" FROM PUBLIC;
SELECT format('GRANT CONNECT, TEMPORARY ON DATABASE %I TO %I', :'db', :'usr') \gexec
SQL
done
echo "All tenant databases provisioned."
