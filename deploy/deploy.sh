#!/bin/bash
# deploy.sh <image-tag>
# Pulls the given image tag from ECR, proves it works on a spare port,
# then replaces the live container. Rolls back if the live one is unhealthy.
set -euo pipefail

TAG="${1:?usage: deploy.sh <image-tag>}"
REGION="eu-central-1"
REGISTRY="993391629364.dkr.ecr.${REGION}.amazonaws.com"
IMAGE="${REGISTRY}/my-nginx-site:${TAG}"
LIVE="nginx-container"
CANDIDATE="nginx-candidate"
LIVE_PORT=8080
CANDIDATE_PORT=8081

health_check() {   # $1 = port; up to ~20 seconds of retries
  for _ in $(seq 1 10); do
    if curl -fsS -o /dev/null "http://localhost:$1/"; then return 0; fi
    sleep 2
  done
  return 1
}

echo "==> Logging in to ECR and pulling ${IMAGE}"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
docker pull "$IMAGE"

echo "==> Starting candidate on port ${CANDIDATE_PORT}"
docker rm -f "$CANDIDATE" >/dev/null 2>&1 || true
docker run -d --name "$CANDIDATE" -p "${CANDIDATE_PORT}:80" "$IMAGE" >/dev/null

if ! health_check "$CANDIDATE_PORT"; then
  echo "!! Candidate failed its health check. Live container untouched."
  docker logs --tail 20 "$CANDIDATE" || true
  docker rm -f "$CANDIDATE" >/dev/null
  exit 1
fi
echo "==> Candidate is healthy"
docker rm -f "$CANDIDATE" >/dev/null

# Remember the running image by its immutable ID (tags like :latest can move).
OLD_ID="$(docker inspect -f '{{.Image}}' "$LIVE" 2>/dev/null || true)"
echo "==> Replacing live container (previous image ID: ${OLD_ID:-none})"
docker rm -f "$LIVE" >/dev/null 2>&1 || true
docker run -d --name "$LIVE" --restart unless-stopped -p "${LIVE_PORT}:80" "$IMAGE" >/dev/null || true

if health_check "$LIVE_PORT"; then
  echo "==> Deploy succeeded: ${IMAGE}"
  exit 0
fi

echo "!! New live container is unhealthy. Rolling back."
docker rm -f "$LIVE" >/dev/null 2>&1 || true
if [ -n "$OLD_ID" ]; then
  docker run -d --name "$LIVE" --restart unless-stopped -p "${LIVE_PORT}:80" "$OLD_ID" >/dev/null
  echo "==> Rolled back to ${OLD_ID}"
fi
exit 1
