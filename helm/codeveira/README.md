# Codeveira -- Kubernetes (Helm)

MVP Helm deployment for Codeveira, as an alternative to the docker-compose
deployment one directory up. Every service is its own subchart:

| Subchart               | Purpose                                            |
|-------------------------|-----------------------------------------------------|
| `codeveira-common`      | Library chart -- shared naming/label/probe helpers, no resources of its own |
| `codeveira-app`         | Puma/Rails web process (Deployment + Service + optional HPA) |
| `codeveira-sidekiq`     | Background-job worker (Deployment, same image, different command) |
| `codeveira-postgresql`  | PostgreSQL (StatefulSet + PVC)                     |
| `codeveira-redis`       | Valkey cache/queue backend (StatefulSet + PVC)     |
| `codeveira-ingress`     | Native `Ingress` + `cert-manager` `ClusterIssuer`  |
| `codeveira-indexer`     | Tree-sitter symbol index (Find Usages/Go to Declaration/Go to Symbol) -- optional, **disabled by default** |
| `codeveira-lint-runner` | Architectural Lint / duplicate/dead-symbol scanning -- optional, **disabled by default** |
| `codeveira-lsp`         | Global LSP proxy for VS Code/JetBrains/Neovim -- optional, **disabled by default** |
| `codeveira-semantic-analysis` | 8 per-language analysis sandboxes + egress proxies -- optional, **disabled by default**, each language independently toggleable |
| `codeveira-redis-sentinel` | HA overlay on top of `codeveira-redis` (replica + 3-pod Sentinel StatefulSet) -- optional, **disabled by default** |
| `codeveira-monitoring`  | Wires `/metrics` into an existing Prometheus Operator + Grafana install -- optional, **disabled by default**, ships no Prometheus/Grafana of its own |

## Enabling the optional feature subcharts

`codeveira-indexer`/`codeveira-lint-runner`/`codeveira-lsp` mirror the
docker-compose `indexer`/`lint-runner`/`lsp` services and are off by
default, same as `docker-compose.yml` makes none of them mandatory for the
app to run. Turn one on with `--set codeveira-indexer.enabled=true` (or the
equivalent in your values file) -- `codeveira-app`/`codeveira-sidekiq`
already default `SYMBOL_INDEXER_URL`/`LINT_RUNNER_URL` to these subcharts'
fixed Service names (`indexer:8090`/`lint-runner:8091`), so no other wiring
is needed to turn the feature on. Each has its own optional-but-recommended
shared-secret token (blank disables auth on that service, same as
docker-compose) -- set once via `global.integrations.symbolIndexerToken` /
`lintRunnerToken` / `lspProxySharedSecret` so the feature subchart and
`codeveira-app`/`codeveira-sidekiq` always agree, instead of repeating the
value in two places.

`codeveira-lsp`'s Service stays `ClusterIP` by default: whether to expose
its raw TCP port 7777 as a `LoadBalancer` Service or via an ingress-nginx
TCP `ConfigMap` entry (a plain HTTP `Ingress` can't carry this protocol
either way) is a deliberately open decision, not yet resolved by this
chart -- see `charts/codeveira-lsp/values.yaml` and the Helm plan in the
main repo's `IDEAS.md`. Bring your own `Service`/`ConfigMap` for external
IDE-client access in the meantime, or reach it via `kubectl port-forward`.

## Enabling per-language semantic analysis

`codeveira-semantic-analysis` mirrors docker-compose's 8
`semantic-analysis[-<lang>]`/`semantic-analysis[-<lang>]-proxy` service
pairs (go/ts/py/java/kt/php/csharp/ruby), but unlike
indexer/lint-runner/lsp it has a **second** level of toggles: the subchart
itself is off by default (`codeveira-semantic-analysis.enabled: true` to
turn it on at all), and within it each language is *also* off by default
(`languages.<name>.enabled: true`) -- since
`Repository#semantic_analysis_language` restricts each repo to exactly
one language, most deployments only need one or two of the 8 running, not
all of them:

```yaml
codeveira-semantic-analysis:
  enabled: true
  languages:
    go:
      enabled: true
```

`languages` is a *map* keyed by language name, not a list -- see the
comment at the top of `charts/codeveira-semantic-analysis/values.yaml`
for why (short version: Helm replaces overridden lists wholesale rather
than merging entries, so a list would silently drop a language's other
fields the moment you tried to turn just that language on). Each
language's token can be set once via
`global.integrations.semanticAnalysisTokens.<name>` so this subchart and
`codeveira-sidekiq` always agree, same pattern as
`symbolIndexerToken`/`lintRunnerToken` above.

Each enabled language gets its own persistent PVC for its
dependency-install cache (`go mod`/`npm`/`pip`/`.m2`/composer/NuGet/
bundler), 5Gi `ReadWriteOnce` by default -- kept persistent (not
`emptyDir`) because the drivers' own size-capped cache-eviction pass only
makes sense against a durable cache. **Known limitation:** the php
sandbox's proxy normally reloads a dynamic self-hosted-VCS allowlist
written by `codeveira-app`/`codeveira-sidekiq`
(`ComposerProxyFilter`/`RegenerateComposerProxyFilterJob` in the main
repo) over a shared volume; this chart does not wire that up (it would
need a `ReadWriteMany` volume shared across two different subcharts), so
the php proxy only ships its bake-time GitHub-hosted-Composer-packages
allowlist -- self-hosted-VCS-hosted PHP dependencies are not reachable
through it yet.

## Enabling Redis Sentinel HA

`codeveira-redis-sentinel` mirrors `docker-compose.sentinel.yml`'s overlay
shape: it does not replace `codeveira-redis` (which stays the initial
Sentinel-monitored master), it adds a `redis-replica` Deployment plus a
fixed-name, 3-pod `redis-sentinel` StatefulSet (quorum 2-of-3) alongside
it. Enable both the subchart and the app/sidekiq side of the switch:

```yaml
codeveira-redis-sentinel:
  enabled: true

global:
  redis:
    sentinelEnabled: true
    # sentinelMasterName/sentinelHosts already default to the right
    # values (mymaster / redis-sentinel-{0,1,2}.redis-sentinel:26379) --
    # only override if you renamed the release or the subchart's fixed
    # Service name.
```

When `sentinelEnabled` is set (via `global.redis.*` or
`codeveira-app.redisSentinel`/`codeveira-sidekiq.redisSentinel` directly),
`codeveira-app`/`codeveira-sidekiq`'s Secret sets `REDIS_SENTINELS`/
`REDIS_MASTER_NAME` alongside the existing `REDIS_URL` -- the app's own
`lib/redis_sentinel_config.rb` switches Sidekiq/ActionCable into Sentinel
mode purely off `REDIS_SENTINELS`'s presence, ignoring `REDIS_URL` once
active, so no other wiring is needed. Replica count is fixed at 3 (not
configurable) to match the app's literal 3-entry default host list.

## Enabling Prometheus/Grafana monitoring

`codeveira-monitoring` is a thin wrapper, not a bundled monitoring stack --
unlike `docker-compose.monitoring.yml` (which ships its own Prometheus/
Grafana/Loki/Promtail containers), it deploys no Prometheus/Grafana pods of
its own. It assumes a Prometheus Operator + Grafana-with-dashboard-sidecar
install already exists on the cluster (see Prerequisites below) and adds
only a `ServiceMonitor` pointing Prometheus at `codeveira-app`'s `/metrics`
endpoint, plus a labeled `ConfigMap` carrying a Grafana dashboard for the
sidecar to auto-import:

```yaml
codeveira-monitoring:
  enabled: true
  auth:
    token: "<service-account API token>"
```

`/metrics` requires an Extended-or-higher license
(`License.current.feature?(:prometheus_metrics)`) and Bearer-token auth via
a service-account user (Settings -> Users, `service_account: true`, then
copy its API token) -- same requirement as the docker-compose monitoring
stack. If the `ServiceMonitor` CRD isn't installed, that one resource is
skipped rather than failing the whole `helm template`/`helm install` run
(the Secret still renders regardless, harmless if unused). The bundled
dashboard is a manually-synced copy of the main repo's
`monitoring/grafana/dashboards/codeveira.json` -- see
`charts/codeveira-monitoring/values.yaml` for the datasource-UID override
knob. **Known limitation:** the docker-compose stack's second dashboard
(`nginx-security.json`, Loki-based nginx access-log analysis via Promtail)
has no Kubernetes equivalent here, since this chart's ingress path
(`codeveira-ingress`, native `Ingress` + `cert-manager`) has no bundled
nginx container to scrape logs from in the first place.

## Prerequisites

Not installed by this chart -- must already exist on the target cluster:

- An Ingress controller, e.g. [ingress-nginx](https://kubernetes.github.io/ingress-nginx/).
  `codeveira-ingress.className` must match its `IngressClass` name.
- [cert-manager](https://cert-manager.io/) (the `jetstack/cert-manager`
  chart, including its CRDs). `codeveira-ingress` either creates its own
  `ClusterIssuer` (`clusterIssuer.create: true`, the default -- ACME
  HTTP-01 against Let's Encrypt) or references one your platform team
  already manages (`clusterIssuer.create: false` +
  `existingIssuerName: ...`).
- Only if enabling `codeveira-monitoring`: a Prometheus Operator + Grafana
  install with its dashboard sidecar enabled, e.g.
  [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
  with its stock defaults (matches this chart's own
  `grafana.datasourceUid: prometheus` default).

## Install

```sh
cat > my-values.yaml <<'EOF'
global:
  appHost: codeveira.example.com
  database:
    password: "<random>"
  rails:
    secretKeyBase: "<rails secret>"
    encryptionPrimaryKey: "<...>"
    encryptionDeterministicKey: "<...>"
    encryptionKeyDerivationSalt: "<...>"
  admin:
    password: "<random>"

codeveira-ingress:
  clusterIssuer:
    email: ops@example.com
EOF

helm install codeveira -f my-values.yaml ./codeveira
```

Generate the Rails secrets the same way the docker-compose deployment's
README does:

```sh
docker run --rm ghcr.io/codeveira/codeveira:latest rails secret
docker run --rm ghcr.io/codeveira/codeveira:latest rails db:encryption:init
```

Every other integration (GitLab/GitHub/Gitea/Bitbucket/Azure/Gerrit
webhook secrets, SMTP, LDAP) lives under `codeveira-app.integrations` /
`codeveira-sidekiq.integrations` in `charts/codeveira-app/values.yaml` and
`charts/codeveira-sidekiq/values.yaml` -- optional, leave blank to disable.

## Why "Domain & HTTPS" disappears from Settings

`codeveira-app`'s Secret always sets `DEPLOYMENT_PLATFORM=kubernetes`. The
app reads that (`app/services/deployment_platform.rb`) to hide the
Settings -> Domain & HTTPS page and reject its controller actions --
`cert-manager` owns certificate issuance/renewal here instead of the
in-app nginx/certbot flow the docker-compose deployment uses.

## Standalone subcharts

Each subchart under `charts/` can also be installed on its own (it
declares `codeveira-common` as a normal chart dependency, resolved via
`helm dependency update` run inside that subchart's directory) -- useful
if you want, say, only `codeveira-postgresql` from this repo and to bring
your own app deployment. When installed together via this umbrella chart,
shared settings (DB/Redis credentials, Rails secrets, admin credentials,
hostname) come from the `global:` block above instead of being repeated
per subchart.

## Known MVP limitations

- `codeveira-app`'s `/app/storage` (ActiveStorage local uploads) defaults
  to an `emptyDir` -- it does not survive a pod replacement. Set
  `codeveira-app.persistence.enabled: true` with a `storageClassName`
  that supports `ReadWriteMany` for a real deployment; `ReadWriteOnce` is
  only safe at `replicaCount: 1`.
- `codeveira-app.autoscaling` is disabled by default: `entrypoint.sh`
  (baked into the image) runs `rails db:migrate` on every app-container
  boot, so scaling past 1 replica during a version upgrade can race
  concurrent migrations. There is no dedicated migration Job in this MVP.
- Database backups (`DatabaseBackupJob` in the Rails app) are unchanged by
  this chart -- they still need a writable destination mounted into
  `codeveira-app`, same as the docker-compose `./backup` bind mount.
