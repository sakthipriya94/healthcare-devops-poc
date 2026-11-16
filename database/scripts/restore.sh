#!/usr/bin/env bash
# Restore one tenant's logical backup into a NEW database for verification.
#   restore.sh <tenant-db> <s3-key>      e.g.  restore.sh hospital_a hospital_a/20261116T213000Z.dump
# Restoring into <db>_restore_test (never over the live DB) lets you check the backup
# before deciding to cut over. Requires the DB master credentials (bootstrap_rds.sh shows how).
set -euo pipefail
DB="${1:?tenant db}"; KEY="${2:?s3 key}"
source /opt/healthcare/static.env
TARGET="${DB}_restore_test"
aws s3 cp "s3://$BACKUPS_BUCKET/$KEY" - --region "$AWS_REGION" > /tmp/restore.dump
psql -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"$TARGET\""
pg_restore --no-owner -d "$TARGET" /tmp/restore.dump
psql -d "$TARGET" -c "select count(*) as patients from patients_patient"
rm -f /tmp/restore.dump
echo "Restored into $TARGET. Drop it when finished:  psql -d postgres -c 'DROP DATABASE \"$TARGET\"'"
