#!/bin/bash
# Zero-downtime rollout for the `app` service on plain docker-compose (no Swarm).
#
# How it works: bring up a second `app` replica on the newly pulled image
# alongside the running one (Docker's embedded DNS round-robins both under
# the same `app` hostname, and the bundled nginx defers hostname resolution
# per-request via its `resolver` directive, so it picks up the new replica
# automatically). Poll the new replica's healthcheck; once healthy, remove
# the old replica. If the new replica never turns healthy, remove it instead
# and leave the old one serving traffic untouched.
#
# `sidekiq` is restarted (regular recreate, brief pause) only after `app` is
# confirmed healthy on the new image, since sidekiq's entrypoint does not run
# `db:migrate` itself and depends on `app` having already migrated the schema
# on boot.
#
# Incompatible with docker-compose.byo-proxy.yml: it publishes app:3000
# directly on the host, and a second replica cannot bind the same host port.
# Use the simple `docker compose pull && up -d && exec app rails db:migrate`
# rollout from the README instead in that setup.

set -euo pipefail

HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-120}"
POLL_INTERVAL_SECONDS=3

log() { echo "[rollout] $*"; }
fail() { echo "[rollout] ERROR: $*" >&2; exit 1; }

if docker compose port app 3000 >/dev/null 2>&1; then
  fail "app currently publishes port 3000 to the host (docker-compose.byo-proxy.yml is in use). Scaling app to 2 replicas would conflict on that port. Use the simple rollout instead: docker compose pull && docker compose up -d && docker compose exec app rails db:migrate"
fi

old_container="$(docker compose ps -q app)"
[ -n "$old_container" ] || fail "no running app container found — nothing to roll. Use plain docker compose up -d for an initial start."

log "pulling latest images..."
docker compose pull app sidekiq

log "starting a second app replica on the new image (old replica stays up)..."
docker compose up -d --no-deps --no-recreate --scale app=2 app

new_container="$(docker compose ps -q app | grep -v "^${old_container}\$")"
[ -n "$new_container" ] || fail "could not identify the new app replica after scaling."
log "new replica: $new_container (old replica: $old_container)"

log "waiting for the new replica to report healthy (timeout ${HEALTH_TIMEOUT_SECONDS}s)..."
elapsed=0
status=""
while [ "$elapsed" -lt "$HEALTH_TIMEOUT_SECONDS" ]; do
  status="$(docker inspect --format '{{.State.Health.Status}}' "$new_container" 2>/dev/null || echo "unknown")"
  [ "$status" = "healthy" ] && break
  sleep "$POLL_INTERVAL_SECONDS"
  elapsed=$((elapsed + POLL_INTERVAL_SECONDS))
done

if [ "$status" != "healthy" ]; then
  log "new replica did not become healthy (last status: $status) — rolling back."
  docker stop "$new_container" >/dev/null
  docker rm "$new_container" >/dev/null
  fail "rollout aborted, old replica ($old_container) is still serving traffic on the previous image."
fi

log "new replica is healthy — removing the old replica."
docker stop "$old_container" >/dev/null
docker rm "$old_container" >/dev/null

log "app rollout complete. restarting sidekiq on the new image..."
docker compose up -d --no-deps sidekiq

log "done."
