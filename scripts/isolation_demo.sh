#!/usr/bin/env bash
# Demonstrates tenant isolation against a running stack.
#   Local:  bash scripts/isolation_demo.sh
#   Cloud:  BASE=http://<alb-dns-name> A_HOST=hospital-a.example.com B_HOST=hospital-b.example.com bash scripts/isolation_demo.sh
set -euo pipefail

BASE="${BASE:-http://localhost}"
A_HOST="${A_HOST:-hospital-a.localhost}"
B_HOST="${B_HOST:-hospital-b.localhost}"
curl_t() { curl -fsS -H "Host: $1" "${@:2}"; }

echo "== 1. Tenant identified from the sub-domain =="
echo -n "$A_HOST -> "; curl_t "$A_HOST" "$BASE/api/tenant/"; echo
echo -n "$B_HOST -> "; curl_t "$B_HOST" "$BASE/api/tenant/"; echo

echo; echo "== 2. Each tenant sees only its own patients =="
echo "Hospital A:"; curl_t "$A_HOST" "$BASE/api/patients/" | python3 -m json.tool | grep -E '"(mrn|last_name)"'
echo "Hospital B:"; curl_t "$B_HOST" "$BASE/api/patients/" | python3 -m json.tool | grep -E '"(mrn|last_name)"'

echo; echo "== 3. Tenant B tries to read a Tenant A record by its id =="
A_ID=$(curl_t "$A_HOST" "$BASE/api/patients/" | python3 -c 'import sys,json; print(json.load(sys.stdin)[0]["id"])')
echo "A's patient id: $A_ID"
echo -n "GET as A: HTTP "; curl -s -o /dev/null -w '%{http_code}' -H "Host: $A_HOST" "$BASE/api/patients/$A_ID/"; echo "  (expected 200)"
echo -n "GET as B: HTTP "; curl -s -o /dev/null -w '%{http_code}' -H "Host: $B_HOST" "$BASE/api/patients/$A_ID/"; echo "  (expected 404)"

echo; echo "== 4. Unknown tenant is rejected =="
echo -n "hospital-c: HTTP "; curl -s -o /dev/null -w '%{http_code}' -H "Host: hospital-c.localhost" "$BASE/api/patients/"; echo "  (expected 404)"

echo; echo "== 5. Database-level isolation (local compose only) =="
if docker compose -f docker/docker-compose.yml --env-file .env ps db >/dev/null 2>&1 && [ -f .env ]; then
  set -a; . ./.env; set +a
  echo "hospital_a_user connecting to hospital_b database (should be denied):"
  docker compose -f docker/docker-compose.yml --env-file .env exec -T -e PGPASSWORD="$HOSPITAL_A_DB_PASSWORD" db \
    psql -h 127.0.0.1 -U hospital_a_user -d hospital_b -c 'select 1' 2>&1 | head -2 || true
fi
