#!/usr/bin/env bash
# Deploys image tag $1 on this host, health-checks it, and rolls back on failure.
#   deploy.sh <image-tag>
# Records state in SSM Parameter Store:
#   /<project>/<env>/image_tag           currently running tag
#   /<project>/<env>/previous_image_tag  tag to roll back to
# Emits CloudWatch metrics Healthcare/DeploymentSucceeded|DeploymentFailed.
set -euo pipefail
NEW_TAG="${1:?usage: deploy.sh <image-tag>}"
cd /opt/healthcare
source /opt/healthcare/static.env
PARAM="/$PROJECT/$APP_ENV"
COMPOSE=(docker compose -f /opt/healthcare/docker-compose.prod.yml)

metric() { aws cloudwatch put-metric-data --region "$AWS_REGION" --namespace Healthcare \
  --metric-name "$1" --dimensions Environment="$APP_ENV" --value 1 --unit Count || true; }
get_param() { aws ssm get-parameter --region "$AWS_REGION" --name "$PARAM/$1" --query Parameter.Value --output text 2>/dev/null || true; }
put_param() { aws ssm put-parameter --region "$AWS_REGION" --name "$PARAM/$1" --value "$2" --type String --overwrite >/dev/null; }

healthy() {  # post-deploy check through nginx on this host: liveness + every tenant DB reachable
  for _ in $(seq 1 30); do
    if curl -fsS -H 'Host: localhost' http://127.0.0.1:80/api/health/ | grep -q '"status": "ok"'; then return 0; fi
    sleep 5
  done
  return 1
}

start() {
  export IMAGE_TAG="$1"
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY" >/dev/null
  /opt/healthcare/scripts/render_env.sh
  "${COMPOSE[@]}" pull
  "${COMPOSE[@]}" up -d --remove-orphans
}

CURRENT_TAG="$(get_param image_tag)"
echo "== deploying $NEW_TAG (currently: ${CURRENT_TAG:-none})"
set -a; source /opt/healthcare/static.env; set +a
start "$NEW_TAG"

if healthy; then
  [ -n "$CURRENT_TAG" ] && [ "$CURRENT_TAG" != "$NEW_TAG" ] && put_param previous_image_tag "$CURRENT_TAG"
  put_param image_tag "$NEW_TAG"
  metric DeploymentSucceeded
  docker image prune -f >/dev/null
  echo "== deploy OK: $NEW_TAG"
  exit 0
fi

echo "!! health check failed for $NEW_TAG" >&2
"${COMPOSE[@]}" logs --tail=50 backend >&2 || true
metric DeploymentFailed
if [ -n "$CURRENT_TAG" ] && [ "$CURRENT_TAG" != "$NEW_TAG" ]; then
  echo "!! rolling back to $CURRENT_TAG" >&2
  start "$CURRENT_TAG"
  healthy && echo "== rollback OK: $CURRENT_TAG" >&2 || echo "!! rollback ALSO unhealthy - investigate" >&2
fi
exit 1
