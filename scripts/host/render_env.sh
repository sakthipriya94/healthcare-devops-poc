#!/usr/bin/env bash
# Builds /opt/healthcare/.env on the server from:
#   * /opt/healthcare/static.env       (non-secret, written by Terraform user_data)
#   * AWS Secrets Manager              (Django key + per-tenant DB passwords)
# using the instance's IAM role. The file is root-only (0600) and never leaves the host.
set -euo pipefail
source /opt/healthcare/static.env

fetch() { aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$1" --query SecretString --output text; }
to_env() { jq -r 'to_entries[] | "\(.key)=\(.value)"'; }

umask 077
TMP="$(mktemp /opt/healthcare/.env.XXXXXX)"
{
  grep -Ev '^(AWS_DEFAULT_REGION|DJANGO_ALLOWED_HOSTS)=' /opt/healthcare/static.env
  printf 'DJANGO_ALLOWED_HOSTS=%s\n' "${DJANGO_ALLOWED_HOSTS:-localhost,127.0.0.1,.localhost},hospital-a.local,hospital-b.local"
  fetch "$PROJECT/$APP_ENV/django" | to_env
  fetch "$PROJECT/$APP_ENV/tenant-db-credentials" | to_env
} > "$TMP"
mv "$TMP" /opt/healthcare/.env
chmod 600 /opt/healthcare/.env
echo "rendered /opt/healthcare/.env ($(wc -l < /opt/healthcare/.env) variables)"
