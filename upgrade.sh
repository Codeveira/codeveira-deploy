#!/bin/bash
# One-command upgrade: backup first, then update every service with as
# little downtime as this compose setup can give.
#
# 1. Runs backup.sh (Postgres dump + Redis snapshot). Aborts here on failure
#    -- an upgrade is never worth risking data for.
# 2. Updates `app`/`sidekiq`: zero-downtime via rollout.sh when the bundled
#    nginx is in front, or the plain pull/recreate/migrate path when
#    docker-compose.byo-proxy.yml is detected (rollout.sh isn't compatible
#    with it -- see rollout.sh's own check).
# 3. Recreates every other service (indexer, lint-runner, lsp, the
#    semantic-analysis-* pairs, nginx) with a plain `docker compose up -d`.
#    These aren't zero-downtime: each briefly restarts if its image changed.
#    Most of that is invisible to users (indexer/lint-runner/semantic-analysis
#    just delay in-flight background jobs a few seconds); `nginx` is the one
#    real exception, since it's this deployment's sole ingress and only ever
#    runs as a single instance -- recreating it is a genuine few-second gap
#    that nothing here works around (that would need a second host/replica,
#    i.e. actual HA, not something a single-node compose file can give you).
#
# `db` and `redis` are deliberately never touched here -- their images are
# pinned directly in docker-compose.yml (not via ${IMAGE_TAG}), so a routine
# app-version upgrade never bumps them. A Postgres/Redis engine upgrade is
# its own separate, deliberate migration, not something to fold in here.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

log() { echo "[upgrade] $*"; }
fail() { echo "[upgrade] ERROR: $*" >&2; exit 1; }

# Same lock rollout.sh takes on its own -- acquired once here so the whole
# 3-step upgrade is atomic against a second upgrade.sh/rollout.sh, and the
# sentinel below tells the rollout.sh call in step 2 not to flock the same
# fd it's already inside of (which would just be a harmless re-lock by the
# same process, but there's no reason to rely on flock's self-reentrancy
# behavior when a plain env var makes the intent explicit).
LOCK_FILE="$(dirname "${BASH_SOURCE[0]}")/.deploy.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || fail "another deploy operation (rollout.sh/upgrade.sh) is already running against this compose project -- refusing to start a second one concurrently."
export CODEVEIRA_DEPLOY_LOCKED=1

log "step 1/3: backup"
./backup.sh

log "step 2/3: updating app + sidekiq"
if docker compose port app 3000 >/dev/null 2>&1; then
  log "docker-compose.byo-proxy.yml detected -- using the plain update path (brief gap while app restarts)."
  docker compose pull app sidekiq
  docker compose up -d app sidekiq
  docker compose exec app rails db:migrate
else
  ./rollout.sh
fi

log "step 3/3: updating remaining services (indexer, lint-runner, lsp, semantic-analysis-*, nginx)"
mapfile -t other_services < <(docker compose config --services | grep -Ev '^(db|redis|app|sidekiq)$')
if [ "${#other_services[@]}" -gt 0 ]; then
  docker compose pull "${other_services[@]}"
  docker compose up -d --no-deps "${other_services[@]}"
else
  log "nothing else to update."
fi

log "done. db and redis were left untouched -- see README for engine-version upgrades."
