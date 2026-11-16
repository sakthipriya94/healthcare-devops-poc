#!/usr/bin/env bash
# Creates/updates the per-tenant databases and roles on RDS. Run ON THE APP HOST
# (the only place that can reach the private RDS endpoint), e.g. via SSM:
#   aws ssm start-session --target <instance-id>   then:   sudo /opt/healthcare/scripts/bootstrap_rds.sh
# Idempotent: re-run it after adding a tenant to tenants.json (see docs/multi-tenant-database.md).
set -euo pipefail
source /opt/healthcare/static.env

fetch() { aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$1" --query SecretString --output text; }

MASTER_JSON="$(fetch "$MASTER_SECRET_ARN")" # ARN written to static.env by Terraform

export PGHOST="$DB_HOST" PGPORT=5432 PGSSLMODE=require
PGUSER="$(jq -r .username <<<"$MASTER_JSON")"
PGPASSWORD="$(jq -r .password <<<"$MASTER_JSON")"
export PGUSER PGPASSWORD

# Export every tenant password (HOSPITAL_A_DB_PASSWORD=...) into this shell only
eval "$(fetch "$PROJECT/$APP_ENV/tenant-db-credentials" | jq -r 'to_entries[] | "export \(.key)=\(.value|@sh)"')"

# Build "<db>:<role>:<PASSWORD_ENV>" for every tenant listed in tenants.json
mapfile -t SPECS < <(python3 - <<'PY'
import json
for t in json.load(open("/opt/healthcare/tenants.json"))["tenants"]:
    d = t["db"]
    print(f'{d["name"]}:{d["user"]}:{d["password_env"]}')
PY
)
bash "$(dirname "$0")/provision_tenants.sh" "${SPECS[@]}"
