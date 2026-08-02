# Codeveira — Self-Hosted Code Review

> Post-commit code review platform for GitLab, GitHub, Gitea, Forgejo, Bitbucket, Azure DevOps and Gerrit.  
> The modern self-hosted alternative to JetBrains Upsource.

## Requirements

- Docker Engine 24+
- Docker Compose v2
- A domain pointed at this server (optional — Codeveira issues/renews its own TLS certificate for it via the built-in `nginx` container and Let's Encrypt; see [Domain & HTTPS](#domain--https))

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/Codeveira/codeveira-deploy
cd codeveira-deploy

# 2. Configure
cp .env.example .env
# Edit .env — required: DB_PASSWORD, SECRET_KEY_BASE, APP_HOST,
# ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY, ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY,
# ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT (generate with:
# docker compose run --rm app rails db:encryption:init)

# 3. Start
docker compose up -d

# 4. Initialise the database (first run only)
docker compose exec app rails db:create db:migrate db:seed
```

Default admin credentials are set via `ADMIN_EMAIL` / `ADMIN_PASSWORD` in `.env`.  
**Change them before going to production.**

## Updating

```bash
docker compose pull
docker compose up -d
docker compose exec app rails db:migrate
```

> **Upgrading from before the encryption-at-rest release?** Add `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, and `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` to `.env` first (see `.env.example`) — the app won't boot without them. Existing repository tokens, AI provider keys, and similar secrets stay readable during the upgrade and get encrypted automatically when `rails db:migrate` runs.
>
> Also add `AZURE_WEBHOOK_SECRET`/`GERRIT_WEBHOOK_SECRET` if you use those integrations — their webhooks now require authentication (HTTP Basic Auth) where they previously accepted any request.

## Pinning a version

```bash
IMAGE_TAG=1.2.0 docker compose up -d
```

## Licensing

Codeveira is **free for any number of users** — no license key required (local AI models only). A license unlocks cloud AI providers and advanced features, priced per active user.

| Tier       | Price          | Users     | Key features                                                                  |
|------------|----------------|-----------|-------------------------------------------------------------------------------|
| Free       | $0             | Unlimited | Core review, 1 local AI bot, email notifications, IDE diagnostics, configurable dashboard |
| Standard   | $10/user/mo    | Unlimited | Cloud AI providers, Compare (file-to-file & full-repo diff), Slack/Teams/Email/Webhook/SMS notifications, REST API, Backup, 2FA, review watchers |
| Extended   | $14/user/mo    | Unlimited | Multiple AI bots, Autofix, LDAP/AD, Audit log, Prometheus metrics             |
| Enterprise | $16/user/mo    | Unlimited | All features + Upsource import + audit log export/SIEM + CI status badge      |

To purchase a license: **hello@codeveira.com**

## Two-Factor Authentication

2FA is available on **Standard and higher** tiers. Admins can enforce it globally from **Settings → Users** — users without 2FA configured will be prompted to set it up after login and cannot bypass it. Users can also enable 2FA voluntarily from their **Profile** page.

## Repository Browser

A **unified navigation tab bar** sits at the top of every repository sub-page — README, Browse, Branches, Analytics, Members, Metrics, Edit, and All Reviews. The repository name in the header is a clickable link back to the repository home page. The active section is underlined in blue. Jump between sections with one click.

The **repository home page** shows stat cards (open reviews, member count, last commit), a collapsible webhook setup section, and a recent reviews list with reviewer badges.

The browser lets you navigate the file tree, view syntax-highlighted files, check line-by-line blame (GitHub & GitLab), and inspect file commit history — all at any branch or commit SHA. A **branch switcher dropdown** lets you change branches instantly; the file tree shows only files on the selected branch. Cmd+K fuzzy file search is scoped to the current branch. Every line gets a `#L{n}` anchor for shareable deep links.

The **All Reviews** page supports filtering by status, author, and reviewer simultaneously. Each review row shows **+N / -M diff statistics** (additions in green, deletions in red) so you can gauge review size at a glance.

## Find Usages, Go to Declaration & Go to Symbol

**Standard+.** A tree-sitter symbol index for **JavaScript, TypeScript, Ruby, Python, Go, Java, Kotlin and PHP**, built incrementally by a dedicated `indexer` container on every push — no full-repo re-index needed, only touched files are re-parsed.

- **Web UI** — Ctrl+click a symbol for its declaration, Alt+click for every usage grouped by file.
- **IDE** — the same index backs standard LSP requests, so VS Code, JetBrains, and Neovim get native **Go to Declaration** (F12), **Find All References** (Shift+F12), and **Go to Symbol in File** (Ctrl+Shift+O) — no extra plugin code required.
- **Isolated by design** — the `indexer` container is separate from `app`/`sidekiq`/`lsp` so a parsing failure never affects review creation, comments, or notifications; its memory/CPU limits (`INDEXER_MEM_LIMIT`, `INDEXER_CPUS`) are configured independently.
- If a repository was added before this feature existed, trigger a one-time backfill from its **Edit page → Rebuild symbol index** (admin only).
- This is a syntactic index (tree-sitter), not a full semantic engine — it matches symbols by name within a repository/branch, not resolved type.

## Review Templates

Go to **Settings → Review Templates** to create reusable title presets. A **"Use template"** dropdown always appears next to the title field on the New Review form — when no templates exist yet it shows an empty-state message with a link to create one.

## Outgoing Webhooks

Each repository has a **Webhooks** tab (visible to admins). Configure one or more HTTP/HTTPS endpoints to receive JSON payloads for `review.opened`, `review.approved`, `review.rejected`, `review.closed`, `review.reopened`, and `comment.created` events. Optional HMAC-SHA256 signing via secret token (`X-Codeveira-Signature` header).

This is also the standardized way to connect a task tracker (Jira, YouTrack, Linear, Azure Boards, or anything else) — every payload includes `ticket_keys` (auto-extracted from the CR's title/branch, e.g. `PROJ-123`, pattern overridable per repository) and `review.url` (a direct link back to the CR), so the tracker's own automation (a Jira Automation "incoming webhook" rule, a YouTrack workflow, a Zapier/Make recipe) can match the delivery to its issue with no Codeveira-specific code on its end.

## Global Search (Cmd+K)

Press **⌘K** (Mac) or **Ctrl+K** (Windows/Linux) anywhere to open a search overlay. Searches repositories by name, reviews by title or CR number, and commits by SHA prefix. Navigate results with arrow keys, confirm with Enter, close with Esc.

## Copy Link

A **⎘ Copy link** button appears in three places: next to the CR-ID in the review header (copies the review URL), in the commits sidebar of a review (copies the commit URL), and in the per-commit diff header. Works on both HTTPS and HTTP (falls back to `execCommand`).

## Go to File

Every file header in a diff view has a **"Go to file"** button next to "Side by side". It opens the full syntax-highlighted file in the repository browser at the exact commit SHA — so you always see the file as it was at that point in history. Available in:
- Commit diff pages (`/repositories/:id/commits/:sha`)
- CR combined diff view
- CR per-commit diff view

The button is hidden for deleted files (they no longer exist at that SHA).

## @Mentions, Digest & Reply by Email

- **@mention** a user in any comment body to send them an immediate in-app + email notification.
- Users can opt into a **daily digest** in Profile → Notifications instead of per-event emails.
- **Reply by email** — set `INBOUND_EMAIL_DOMAIN` in `.env` and configure MX. Replying to a notification email posts a comment directly on the review.

## Documentation

Full documentation at **[codeveira.com/docs](https://codeveira.com/docs/)**.

- [Installation](https://codeveira.com/docs/installation/)
- [Settings](https://codeveira.com/docs/settings/)
- [IDE Integration](https://codeveira.com/docs/ide-integration/)
- [Repository Browser](https://codeveira.com/docs/repository-browser/)
- [GitLab](https://codeveira.com/docs/gitlab-integration/)
- [GitHub](https://codeveira.com/docs/github-integration/)
- [Gitea / Forgejo](https://codeveira.com/docs/gitea-integration/)
- [Bitbucket](https://codeveira.com/docs/bitbucket-integration/)
- [Azure DevOps](https://codeveira.com/docs/azure-devops-integration/)
- [Gerrit](https://codeveira.com/docs/gerrit-integration/)
- [LDAP](https://codeveira.com/docs/ldap/)

## Domain & HTTPS

Codeveira ships with a **built-in `nginx` reverse-proxy container** — no separate reverse proxy to install or configure on the host. It's included in `docker-compose.yml` above and boots with a zero-config self-signed certificate on ports 80/443, proxying both the web app and the LSP TCP port (7777) automatically.

To go live on a real domain, sign in as an admin and go to **Settings → Domain & HTTPS**:

- **Upload your own certificate** — paste in a PEM cert/key pair from any CA, applied immediately.
- **Let's Encrypt — HTTP-01** — simplest option if this server is reachable on port 80 from the public internet. Codeveira runs `certbot` for you and renews automatically twice a day.
- **Let's Encrypt — DNS-01** — works without exposing port 80, and supports wildcard domains. Supported DNS providers: **Cloudflare, AWS Route 53, Google Cloud DNS**.

No manual nginx config, no `certbot` install on the host, no cron job to set up — it's all handled inside the `nginx`/`sidekiq` containers, coordinated through the `nginx_certs`/`nginx_conf` volumes already declared in `docker-compose.yml`.

If you'd rather run your own reverse proxy in front of Codeveira instead (e.g. an existing host-level nginx/Caddy/Traefik shared across other services), that still works — just don't publish the bundled `nginx` container's ports and point your own proxy at `app:3000` (and `lsp:7777` for IDE integration, over raw TCP, not HTTP). A reference host-nginx config is kept in [`nginx.conf.example`](nginx.conf.example) for that case.

## Scaling & High Availability

The shipped `docker-compose.yml` runs one replica of each service — enough for a single team on a single host. `app`, `sidekiq`, `lsp`, and `indexer` are stateless and safe to scale horizontally as-is:

- **`app`** — sessions use Rails' default cookie store (no server affinity needed) and the codebase makes no use of `Rails.cache`, so there's no server-local cache to desync between replicas. Put a load balancer in front of multiple `app` containers.
- **`sidekiq`** — scale with `docker compose up -d --scale sidekiq=3`; Sidekiq is designed for multiple workers pulling from the same Redis-backed queues.
- **`lsp` / `indexer`** — both stateless per-connection/per-request; add replicas if one becomes a bottleneck.
- **Real-time updates (ActionCable)** — already configured with the Redis adapter in production, so broadcasts fan out correctly across multiple `app` replicas, not just within one process.

**Not HA out of the box:** `db` (PostgreSQL) and `redis` are single-node in this compose file, with no replication or automatic failover. For Postgres, point `DATABASE_URL` at an externally managed HA database (RDS Multi-AZ, Cloud SQL HA, or a self-managed Patroni cluster) instead of the bundled `db` service. Redis has a built-in HA option — see below.

## Redis Sentinel (optional)

The default `redis` service is a single non-HA instance. To run Redis with automatic master failover instead, merge the included Sentinel topology on top:

```bash
docker compose -f docker-compose.yml -f docker-compose.sentinel.yml up -d
```

This adds a replica and three Sentinel instances (quorum 2 of 3) and points `app`/`sidekiq` at them via `REDIS_SENTINELS`/`REDIS_MASTER_NAME` instead of a fixed host — both Sidekiq and ActionCable's Redis clients are Sentinel-aware, so they auto-discover the current master and reconnect after a failover without a restart. The base `docker-compose.yml` is unmodified either way; switching back is just dropping the `-f docker-compose.sentinel.yml`. See `lib/redis_sentinel_config.rb` in the app image for the connection logic, and `redis-sentinel/sentinel.conf.template` for the Sentinel config.

**Before switching back to plain `docker-compose.yml`:** if a failover ever actually happened while Sentinel was running, the original `redis` container gets reconfigured as a *replica* of whichever node got promoted — correct while Sentinel is managing it, but if you then remove the Sentinel containers it's left stuck read-only, pointed at a host that no longer exists (Sidekiq will crash-loop with `READONLY You can't write against a read only replica`). Promote it back to a standalone master first: `docker exec <redis container> redis-cli replicaof no one` (confirm with `redis-cli info replication` — `role` should read `master`).

## Monitoring (optional)

A ready-made Prometheus + Grafana + Loki/Promtail stack, merged on top of the base compose file the same way Redis Sentinel is:

```bash
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
```

One-time setup:
1. Create a service account (**Settings → Users → New Service Account**), generate its API token, and paste it into `monitoring/prometheus_token` (see `monitoring/prometheus_token.example`) — Prometheus reads the token from that file at scrape time via `credentials_file`, so the secret never goes into a compose/env file.
2. Set `GRAFANA_ADMIN_PASSWORD` in `.env`.

Grafana comes up at `:3001` (`admin` / `GRAFANA_ADMIN_PASSWORD`) with two dashboards already provisioned — no manual datasource or import step:

- **Codeveira — Review Health & Bottlenecks** — review throughput, cycle time, and per-reviewer bottleneck detection (who's got a backlog, whose assignments have sat pending >7 days, assignment→decision time), from the `/metrics` endpoint above.
- **Nginx — Connections & Security** — who's connecting to the instance and any failed/suspicious requests by IP (a spike of 404s/401s from one address is what a scan or brute-force attempt looks like here), sourced from nginx's own access log via Loki rather than a Prometheus metric — client IP is unbounded-cardinality data, so it's shipped as logs, not a label.

Prometheus itself is exposed at `:9090` for ad-hoc queries. Loki/Promtail have no exposed ports — Grafana talks to them over the internal Docker network only.

## Redis Data & Backup

There's no scheduled backup job for Redis, unlike the [Backup & Restore](https://codeveira.com/docs/settings/) feature for PostgreSQL — by design, not an oversight. Everything durable (reviews, comments, users, the symbol index, audit log) lives in Postgres; Redis only holds Sidekiq's job queues and ActionCable's pub/sub, which are transient in-flight state.

It's already persisted: the `redis_data` volume survives container restarts, and Redis's default RDB snapshot policy is active out of the box. AOF is off by default, so a hard crash can lose up to the last snapshot window — in practice a handful of in-flight jobs (an unprocessed webhook, an AI review run, a symbol-indexing job for the last few commits), never committed application data.

If you want a point-in-time snapshot anyway (e.g. before a risky upgrade):

```bash
docker compose exec redis sh -c "tar czf - -C /data ." > redis-backup-$(date +%Y%m%d).tar.gz
```

## Support

- Website: [codeveira.com](https://codeveira.com)
- Email: hello@codeveira.com
