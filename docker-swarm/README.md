# Docker Swarm deployment

This is an **additional** deployment option alongside [`../docker-compose.yml`](../docker-compose.yml) —
it does not replace it. Use this if you already have (or want) a Docker Swarm cluster and want native
rolling updates and the ability to spread stateless workers across multiple nodes. If you just want to run
Codeveira on a single machine, stick with `docker compose` — it's simpler and this buys you nothing extra
in that case.

## What you get over docker-compose.yml

- **Zero-downtime rolling updates**, built into the orchestrator (`deploy.update_config: order:
  start-first`) — a new task starts and must pass its `/up` healthcheck before the old one stops. This
  replaces the manual `../rollout.sh` script (which does the same thing by hand via `--scale app=2` +
  polling). A failed rollout auto-rolls-back (`failure_action: rollback`).
- **Horizontal scaling** for the genuinely stateless services — `app`, `sidekiq`, `indexer`,
  `lint-runner`, `lsp`, and all 16 `semantic-analysis-*`/`*-proxy` workers except
  `semantic-analysis-php-proxy` — across however many nodes join the cluster.

## What you do NOT get — read this before deploying

**This is not high availability.** `db` (PostgreSQL), `redis`, `nginx`, `app`, `sidekiq`, and
`semantic-analysis-php-proxy` are all pinned to a single "primary" node (see below for why) with
`replicas: 1` each. If that node goes down, the whole stack goes down until it comes back — exactly the
same single point of failure as the `docker-compose.yml` deployment, just now with more moving parts
around it. Genuine automatic failover needs at least 3 independent failure zones for quorum (Postgres
replication + a failover manager like Patroni, a Redis Sentinel/Cluster setup, etc.) — that's real
additional infrastructure this stack does not set up. If you need that, look at `../redis-sentinel/` for
the Redis half, or consider a managed Postgres with replication in front of this stack instead of the
bundled `db` service.

What Swarm buys you here is **deploy automation and worker scaling**, not fault tolerance.

## Why some services are pinned to one node

Every named volume in this stack (`app_storage`, `pgdata`, `redis` data, `php_composer_proxy_filter`,
etc.) uses Docker's default `local` volume driver, which is **per-node** — it is not shared across a
Swarm cluster. Two services that need to read/write the *same* data therefore have to land on the *same*
node, or Swarm will silently hand each one an independent, empty volume with no error. This stack handles
that by labeling one node `codeveira.role=primary` and constraining every state-touching service to it:
`db`, `redis`, `app`, `sidekiq`, `nginx` (shares TLS cert/config volumes with app), and
`semantic-analysis-php-proxy` (shares `php_composer_proxy_filter` with app/sidekiq — the dynamic Composer
egress allow-list feature; every other `semantic-analysis-*-proxy` is stateless and unconstrained). All
other services are free to land on any node.

If you only have one Swarm node, this constraint is a no-op — everything runs there anyway, and you still
get rolling-update automation for free.

## Setup

### 1. Initialize the cluster (skip if you already have one)

```bash
# On the machine that will be the primary node:
docker swarm init

# On each additional node, run the `docker swarm join ...` command it prints:
docker swarm join --token <TOKEN> <PRIMARY_IP>:2377
```

### 2. Label the primary node

Pick the node that will hold `db`/`redis`/`app`/`sidekiq`/`nginx` (the one you'd have run
`docker compose up` on):

```bash
docker node ls                                        # find its NAME/ID
docker node update --label-add codeveira.role=primary <NODE>
```

### 3. Prepare the data directory on the primary node

```bash
sudo mkdir -p /srv/codeveira/data/{pgdata,redis,backup}
sudo chown -R 999:999 /srv/codeveira/data/pgdata   # postgres container UID
```

Set `CODEVEIRA_DATA_DIR` in `.env` to match (default: `/srv/codeveira/data`).

### 4. Configure and deploy

```bash
cp .env.example .env
# fill in .env — see ../.env.example for the full annotated var reference
./deploy.sh
```

`deploy.sh` sources `.env` into the shell (Swarm doesn't auto-load `.env` the way `docker compose` does)
and runs `docker stack deploy -c docker-stack.yml codeveira`.

### 5. Run first-time setup (migrations/seed/admin user)

The `app`/`sidekiq` entrypoint already runs `db:create db:migrate` and `db:seed` on every boot (same as
the Compose deployment), so this happens automatically on first deploy — no extra step needed.

## Operating

Check status:

```bash
docker stack services codeveira
docker service ps codeveira_app
docker service logs -f codeveira_sidekiq
```

Scale a stateless worker up or down:

```bash
docker service scale codeveira_semantic-analysis-ts=3
```

Scale `app` or `sidekiq` persistently (survives redeploys): edit `APP_REPLICAS`/`SIDEKIQ_REPLICAS` in
`.env`, then re-run `./deploy.sh`.

## Updates and rollbacks

Bump `IMAGE_TAG` in `.env` (or leave it as a floating tag like `latest` — Swarm re-resolves against the
registry on every deploy by default) and re-run `./deploy.sh`. Each primary-pinned or scaled service
rolls forward one task at a time, waiting for the new task's healthcheck before stopping the old one.

If a rollout's healthcheck fails, Swarm auto-rolls-back automatically (`failure_action: rollback`). To
roll back manually at any time:

```bash
docker service rollback codeveira_app
```

## Teardown

```bash
docker stack rm codeveira
```

This removes the services and networks but leaves `CODEVEIRA_DATA_DIR` and named volumes untouched.

## Not included here

- `test`/`selenium` — dev/test-only tooling from `docker-compose.yml`'s `profiles:`, which Swarm doesn't
  support cleanly. Run those against a Compose deployment instead.
- Monitoring (`../monitoring/`) and Redis Sentinel (`../redis-sentinel/`) overlays — these are
  Compose-specific files; if you want them under Swarm you'll need to port them the same way this stack
  was ported from `../docker-compose.yml`, which we haven't done yet.
