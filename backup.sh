#!/bin/bash
# Pre-upgrade snapshot of Postgres and Redis, meant to run right before
# `upgrade.sh` (or on its own, e.g. from cron) so a bad pull/migration always
# has something to roll back to.
#
# Postgres: `pg_dump -Fc` run *inside* the `db` container via its own local
# unix-socket connection (trust auth, no password needed) so the dump always
# matches the server's exact version. Written directly to the host-mounted
# `./backup` dir as `codeveira_<timestamp>.dump` — the same prefix/format
# Settings::BackupsController's FILENAME_RE expects, so these backups show up
# and are restorable from Settings -> Backup & Restore like any backup the
# app made itself (Standard+ license required for that UI; the file is
# produced either way).
#
# Redis: forces a fresh BGSAVE first (the existing manual command in the
# README just tars whatever's on disk, which can be stale), then tars the
# host-mounted `./redis` dir once the save completes.
#
# Independent retention from DatabaseBackupJob's own rotation, since that one
# only fires on a Standard+ license and only when the in-app job actually
# runs -- a Free-tier instance calling this script would otherwise never
# rotate anything.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

BACKUP_DIR="./backup"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

log() { echo "[backup] $*"; }
fail() { echo "[backup] ERROR: $*" >&2; exit 1; }

mkdir -p "$BACKUP_DIR"

[ -n "$(docker compose ps -q db)" ] || fail "db container is not running."
[ -n "$(docker compose ps -q redis)" ] || fail "redis container is not running."

# --- Postgres ---------------------------------------------------------------
dump_path="$BACKUP_DIR/codeveira_${TIMESTAMP}.dump"
log "dumping Postgres to $dump_path ..."
if ! docker compose exec -T db pg_dump -U codereview -Fc codereview > "$dump_path"; then
  rm -f "$dump_path"
  fail "pg_dump failed."
fi
[ -s "$dump_path" ] || { rm -f "$dump_path"; fail "pg_dump produced an empty file."; }
log "Postgres dump OK ($(du -h "$dump_path" | cut -f1))."

# --- Redis -------------------------------------------------------------------
log "triggering Redis BGSAVE..."
before="$(docker compose exec -T redis valkey-cli LASTSAVE | tr -d '\r')"
docker compose exec -T redis valkey-cli BGSAVE >/dev/null

elapsed=0
while [ "$elapsed" -lt 60 ]; do
  in_progress="$(docker compose exec -T redis valkey-cli INFO persistence 2>/dev/null | grep -o 'rdb_bgsave_in_progress:[01]' | cut -d: -f2 | tr -d '\r')"
  after="$(docker compose exec -T redis valkey-cli LASTSAVE | tr -d '\r')"
  if [ "$in_progress" = "0" ] && [ "$after" != "$before" ]; then
    break
  fi
  sleep 1
  elapsed=$((elapsed + 1))
done
[ "$elapsed" -lt 60 ] || fail "Redis BGSAVE did not complete within 60s."

redis_path="$BACKUP_DIR/redis_${TIMESTAMP}.tar.gz"
log "archiving ./redis to $redis_path ..."
# dump.rdb is written by the valkey container's own (non-root) user at mode
# 0600, which the invoking host user usually can't read directly off the
# ./redis bind mount -- tar inside the container instead (docker compose
# exec runs as root there) and stream the archive out over stdout.
if ! docker compose exec -T redis tar czf - -C /data . > "$redis_path"; then
  rm -f "$redis_path"
  fail "tar of ./redis failed."
fi
[ -s "$redis_path" ] || { rm -f "$redis_path"; fail "Redis archive is empty."; }
log "Redis snapshot OK ($(du -h "$redis_path" | cut -f1))."

# --- Rotation ----------------------------------------------------------------
log "pruning backups older than ${RETENTION_DAYS}d..."
find "$BACKUP_DIR" -maxdepth 1 -name 'codeveira_*.dump' -mtime "+${RETENTION_DAYS}" -print -delete
find "$BACKUP_DIR" -maxdepth 1 -name 'redis_*.tar.gz' -mtime "+${RETENTION_DAYS}" -print -delete

log "done: $dump_path, $redis_path"
