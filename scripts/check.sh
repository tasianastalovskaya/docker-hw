#!/bin/bash
set -e

cd "$(dirname "$0")/.."

PROJECT="redis-check-$$"
PORT=$((20000 + $$ % 20000))
export APP_PORT="$PORT"

cleanup() {
    docker compose -p "$PROJECT" down -v --remove-orphans >/dev/null 2>&1 || true
}

trap cleanup EXIT

wait_ready() {
    for i in {1..60}; do
        if curl --max-time 3 -fsS "http://localhost:$PORT/readyz" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    exit 1
}

docker compose -p "$PROJECT" up -d --build
wait_ready

COUNT=$(curl --max-time 3 -fsS "http://localhost:$PORT/")
[ "$COUNT" = "0" ] || exit 1

N=3
for i in $(seq 1 "$N"); do
    curl --max-time 3 -fsS -X POST "http://localhost:$PORT/increment" >/dev/null
done

COUNT=$(curl --max-time 3 -fsS "http://localhost:$PORT/")
[ "$COUNT" = "$N" ] || exit 1

docker compose -p "$PROJECT" up -d --no-deps --force-recreate app
wait_ready

COUNT=$(curl --max-time 3 -fsS "http://localhost:$PORT/")
[ "$COUNT" = "$N" ] || exit 1

docker compose -p "$PROJECT" stop redis

HEALTH=$(curl --max-time 3 -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/healthz")
READY=$(curl --max-time 3 -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/readyz")
POST=$(curl --max-time 3 -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:$PORT/increment")

[ "$HEALTH" = "200" ] || exit 1
[ "$READY" = "503" ] || exit 1
[ "$POST" = "503" ] || exit 1

docker compose -p "$PROJECT" start redis
wait_ready

COUNT=$(curl --max-time 3 -fsS "http://localhost:$PORT/")
[ "$COUNT" = "$N" ] || exit 1

docker compose -p "$PROJECT" stop app redis

docker run --rm \
    -v "${PROJECT}_redis-data:/data:ro" \
    -v "$PWD/backups:/backup" \
    alpine:3.20 \
    sh -c "cd /data && tar czpf /backup/redis-backup.tar.gz ."

docker compose -p "$PROJECT" down -v

echo "OK"
