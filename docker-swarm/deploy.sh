#!/bin/bash
# Deploys/updates the Codeveira stack on an existing Docker Swarm cluster.
#
# Unlike `docker compose`, `docker stack deploy` does not auto-load a `.env`
# file from the working directory — the vars it substitutes into
# docker-stack.yml must already be exported in the shell environment. This
# script does that (via `set -a` + `source .env`) and then deploys.
#
# Usage:
#   cp .env.example .env   # fill in values first
#   ./deploy.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -f .env ]; then
  echo "Missing .env — copy .env.example to .env and fill in values first." >&2
  exit 1
fi

set -a
source .env
set +a

: "${CODEVEIRA_DATA_DIR:?CODEVEIRA_DATA_DIR must be set in .env}"

docker stack deploy -c docker-stack.yml codeveira

echo
echo "Deployed. Check status with: docker stack services codeveira"
