#!/usr/bin/env bash
# Usage: deploy.sh <image:tag>
# Env:   NODES="node1 node2 node3" (optional), FAIL_HEALTH=1 (optional, demo of rollback)
set -uo pipefail

IMAGE="${1:?usage: deploy.sh <image:tag>}"
NODES="${NODES:-node1 node2 node3}"
NAME=csn-app
PORT=8000

declare -A PREV
UPDATED=()

remote() { local node=$1; shift; ssh -o BatchMode=yes "ubuntu@$node" "$@"; }

run_container() {  # node image [extra docker args]
  local node=$1 image=$2
  shift 2
  remote "$node" "docker rm -f $NAME >/dev/null 2>&1; docker run -d --name $NAME --restart unless-stopped -p $PORT:8000 -e NODE_NAME=$node $* $image" >/dev/null
}

healthy() {  # node
  for _ in $(seq 1 10); do
    if curl -fsS --max-time 3 "http://$1:$PORT/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

rollback() {
  echo "!!! Rolling back updated nodes"
  for node in "${UPDATED[@]}"; do
    prev="${PREV[$node]}"
    if [ -n "$prev" ]; then
      echo "[$node] restoring $prev"
      run_container "$node" "$prev"
    else
      echo "[$node] no previous version, removing container"
      remote "$node" "docker rm -f $NAME" >/dev/null 2>&1
    fi
  done
}

EXTRA=""
if [ "${FAIL_HEALTH:-}" = "1" ]; then
  EXTRA="-e FAIL_HEALTH=1"
fi

for node in $NODES; do
  echo "=== [$node] deploying $IMAGE"
  PREV[$node]=$(remote "$node" "docker inspect -f '{{.Config.Image}}' $NAME 2>/dev/null" || true)
  UPDATED+=("$node")

  if ! remote "$node" "docker pull -q $IMAGE" >/dev/null; then
    echo "[$node] image pull FAILED"
    rollback
    exit 1
  fi

  run_container "$node" "$IMAGE" $EXTRA

  if healthy "$node"; then
    echo "[$node] healthy"
  else
    echo "[$node] health check FAILED"
    rollback
    exit 1
  fi
done

echo "Deploy finished OK: $IMAGE"
