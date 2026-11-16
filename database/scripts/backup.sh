#!/usr/bin/env bash
# Logical backup of every tenant database -> S3 (encrypted, versioned, lifecycle-managed).
# Complements RDS automated snapshots / point-in-time recovery. Runs nightly from cron
# (see Terraform user_data) and can be run by hand:  sudo /opt/healthcare/scripts/backup.sh
set -euo pipefail
source /opt/healthcare/static.env

fetch() { aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$1" --query SecretString --output text; }
eval "$(fetch "$PROJECT/$APP_ENV/tenant-db-credentials" | jq -r 'to_entries[] | "export \(.key)=\(.value|@sh)"')"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
export PGHOST="$DB_HOST" PGPORT=5432 PGSSLMODE=require

python3 - <<'PY' | while IFS=: read -r db role pw_env; do
import json
for t in json.load(open("/opt/healthcare/tenants.json"))["tenants"]:
    d = t["db"]; print(f'{d["name"]}:{d["user"]}:{d["password_env"]}')
PY
  # each tenant is dumped with ITS OWN credentials - a backup job can never read another tenant's data by mistake
  PGPASSWORD="${!pw_env}" pg_dump -U "$role" -d "$db" -Fc --no-owner \
    | aws s3 cp - "s3://$BACKUPS_BUCKET/$db/$STAMP.dump" --region "$AWS_REGION" --sse AES256
  echo "backed up $db -> s3://$BACKUPS_BUCKET/$db/$STAMP.dump"
done
