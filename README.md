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
| Enterprise | $16/user/mo    | Unlimited | All features + Upsource import + audit log export/SIEM + CI status badge + real semantic analysis (Go, TypeScript, Python, Java, Kotlin, PHP, C# & Ruby) |

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

**Settings → Outgoing Webhooks** (global admin) configures the default set of HTTP/HTTPS endpoints every repository fires against out of the box — one config for the whole instance. A repository only needs its own instead if it must notify a different endpoint/tracker: tick **"Use this repository's own outgoing webhooks"** on the repository's Edit page, and its own **Webhooks** tab (repository page → Webhooks) then takes over completely for that repository, ignoring the global list. Either scope supports any number of webhooks, each subscribed to a different set of `review.opened`, `review.approved`, `review.rejected`, `review.closed`, `review.reopened`, and `comment.created` events, with optional HMAC-SHA256 signing via secret token (`X-Codeveira-Signature` header).

Not to be confused with the single **Global Outgoing Webhook** under Notifications → Webhook (Standard+), which is a chat-style notification channel alongside Slack/Teams/SMS — this is a separate system, purpose-built for task-tracker/automation integration.

This is also the standardized way to connect a task tracker (Jira, YouTrack, Linear, Azure Boards, or anything else) — every payload includes `ticket_keys` (auto-extracted from the CR's title/branch, e.g. `PROJ-123`, pattern overridable per repository) and `review.url` (a direct link back to the CR), so the tracker's own automation (a Jira Automation "incoming webhook" rule, a YouTrack workflow, a Zapier/Make recipe) can match the delivery to its issue with no Codeveira-specific code on its end.

Upgrading from an earlier version: any repository that already had its own webhooks configured is automatically switched to "use this repository's own outgoing webhooks" so its deliveries keep firing unchanged — the global list starts out empty until you add something to it.

## Code Coverage (Enterprise)

Upload a coverage report from your CI test run and Codeveira overlays it directly on the diff view — a green stripe on covered lines, red on uncovered, in both the combined and side-by-side views. Codeveira never runs your tests or compiles anything itself for this — it's pure ingest and display of a report CI already produced.

POST to `/webhooks/ci/coverage` (multipart form: `commit_sha`, optional `pipeline_name`/`format`, and the `report` file) using the same token as the CI status webhook, configured under **Settings → CI Integration**. Format is auto-detected from content when not specified:

- `lcov` — nyc/istanbul (JS/TS), gcov/lcov (C/C++)
- `jacoco` — JaCoCo XML (Java/Kotlin)
- `cobertura` — Cobertura XML, also an export option from Python's coverage.py and PHPUnit
- `simplecov` — SimpleCov `.resultset.json` (Ruby)
- `go_cover` — `go tool cover` profile (Go)

A summary card on the review page shows coverage percentage, lines covered/total, format, and pipeline name, with a warning if the report predates the review's current HEAD commit.

## Semantic Analysis (Enterprise)

Real semantic analysis: **Go via `gopls`** (Phase 1), **TypeScript via `typescript-language-server`**, **Python via `pyright`**, **Java via Eclipse JDT Language Server (`jdtls`)**, **Kotlin via `kotlin-language-server`**, **PHP via Psalm's `psalm-language-server`**, **C# via OmniSharp-Roslyn**, and **Ruby via `ruby-lsp` + RuboCop** (Phase 2) — pick one language per repository; all eight originally-scoped languages now ship. A new, separate subsystem alongside the existing tree-sitter `indexer` container (Find Usages, Go to Declaration & Go to Symbol above) — not an upgrade to it. The indexer is purely syntactic name-matching; this runs the real language server, so its diagnostics are actual compiler output (`go vet` for Go, `tsc`-derived for TypeScript, `pyright`-derived for Python, `jdtls`-derived for Java, `kotlin-language-server`-derived for Kotlin, Psalm-derived for PHP, OmniSharp-derived for C#, RuboCop-derived for Ruby) and its definitions are type-resolved (PHP is the one diagnostics-only exception: `psalm-language-server` doesn't implement `documentSymbol`, so it never returns definitions; C# and Ruby both get real definitions and diagnostics, though Ruby's diagnostics are RuboCop's lint/style findings rather than compiler type errors, since no mature Ruby LSP does real type-checking against untyped Ruby).

Off by default, opt-in per repository from the repository's **Edit** page ("Enable real semantic analysis" toggle plus a **Language** dropdown to pick Go, TypeScript, Python, Java, Kotlin, PHP, C#, or Ruby), only offered when your license includes Enterprise. Once enabled, it triggers automatically on every push alongside the symbol indexer — a coalescing guard skips a new run outright (rather than queuing it) if one is already running for that repository/branch, which bounds load from triggering on every push.

Rails fetches the repository archive itself (GitLab only, for now — other platforms no-op and the feature stays off for those repos) and streams it to a dedicated per-language container over the internal Docker network — `semantic-analysis` for Go, `semantic-analysis-ts` for TypeScript, `semantic-analysis-py` for Python, `semantic-analysis-java` for Java, `semantic-analysis-kt` for Kotlin, `semantic-analysis-php` for PHP, `semantic-analysis-csharp` for C#, `semantic-analysis-ruby` for Ruby. The Go container runs `go mod download`, spawns `gopls`, and collects real diagnostics and type-resolved definitions before tearing itself down. The TypeScript container conditionally runs `npm ci --ignore-scripts` when a `package.json` is present (requires a `tsconfig.json` at the workspace root to run at all), spawns `typescript-language-server`, walks every `.ts`/`.tsx`/`.js`/`.jsx` file, and collects the same shape of diagnostics/definitions before tearing itself down. The Python container requires one of `pyproject.toml`/`requirements.txt`/`setup.py`/`setup.cfg`/`Pipfile`/`pyrightconfig.json` at the workspace root to run at all (Python has no single canonical manifest); when a `requirements.txt` is present, it installs dependencies into an isolated venv with `pip install --only-binary=:all:` (wheels only — see below), spawns `pyright-langserver`, walks every `.py` file, and collects the same shape of diagnostics/definitions. The Java container requires a `pom.xml` at the workspace root to run at all (**Maven only** — Gradle's `build.gradle`/`build.gradle.kts` are executable Groovy/Kotlin scripts evaluated just by importing the project, so Gradle-only repos are simply skipped); it runs `mvn dependency:resolve` as a standalone goal (resolves declared dependencies into `~/.m2` without invoking the project's own compiler/packaging plugins), spawns `jdtls`, walks every `.java` file, and collects the same shape of diagnostics/definitions. The Kotlin container requires a `pom.xml` at the workspace root too (same Maven-only scope and Gradle-exclusion reasoning as Java — most real-world Kotlin projects use Gradle, but the trust boundary comes first); it spawns the MIT-licensed `fwcd/kotlin-language-server` directly, walks every `.kt`/`.kts` file, and collects the same shape of diagnostics/definitions — the language server resolves its own Maven classpath internally (`mvn dependency:list`/`dependency:sources`, both standalone goals), so there's no separate dependency-resolution step before spawning it, unlike Java's driver. The PHP container requires a `composer.json` at the workspace root to run at all; it runs `composer install --no-scripts --no-plugins --no-interaction` (Composer honors `http_proxy`/`https_proxy` env vars natively, so no settings-file plumbing is needed the way Maven requires), writes a minimal default `psalm.xml` only if the target repo doesn't already have one (Psalm refuses to run without a config file), spawns the MIT-licensed `vimeo/psalm`'s bundled `psalm-language-server`, walks every `.php` file, and collects real diagnostics — but never definitions, since `psalm-language-server` doesn't implement `documentSymbol`. The C# container requires a `.sln` (preferred) or `.csproj` (fallback) at the workspace root to run at all — a repo with multiple independent `.csproj` files and no `.sln` only gets the first one found; it runs `dotnet restore` with `http_proxy`/`https_proxy` env vars set (NuGet, like Composer, honors these natively), spawns OmniSharp-Roslyn with the same proxy env vars set on its own process too (its MSBuild project loader can independently trigger a NuGet restore), walks every `.cs` file, and collects both real diagnostics and type-resolved definitions — unlike PHP, OmniSharp's `documentSymbol` implementation works. The Ruby container has **no marker-file gate at all** — every `.rb` file is analyzed whether or not a `Gemfile` exists; it writes its own composed Gemfile pinning `ruby-lsp`/RuboCop (since `ruby-lsp`'s own auto-bootstrap only pulls in RuboCop when the target repo already depends on it) and runs `bundle install` against it — a hard failure here fails the run, since `ruby-lsp` is this driver's own hard dependency, not an optional extra like every other language's target-repo deps; it spawns `ruby-lsp`, walks every `.rb` file, and collects `documentSymbol` results plus RuboCop-derived diagnostics — pulled explicitly via `textDocument/diagnostic` requests, since `ruby-lsp` (unlike every other language server here) only implements LSP's pull diagnostics model rather than pushing `publishDiagnostics` notifications unprompted. This is the first Codeveira feature that ever runs a target repository's own dependency-install tooling, so all eight containers ship with a real egress allow-list from day one, not "open egress, fast-follow": none has a direct route to the internet at all — Go's only path out is through a dedicated `semantic-analysis-proxy` container (tinyproxy) allow-listing just `proxy.golang.org`, `sum.golang.org`, and `storage.googleapis.com`, the Go module proxy's own domain set; TypeScript's only path out is a separate `semantic-analysis-ts-proxy` container allow-listing just `registry.npmjs.org`; Python's only path out is `semantic-analysis-py-proxy`, allow-listing just `pypi.org` and `files.pythonhosted.org`; Java's only path out is `semantic-analysis-java-proxy`, allow-listing just `repo1.maven.org` and `repo.maven.apache.org` (Maven Central); Kotlin's only path out is `semantic-analysis-kt-proxy`, allow-listing the same two Maven Central hostnames as Java's proxy; PHP's only path out is `semantic-analysis-php-proxy`, allow-listing `repo.packagist.org`, `codeload.github.com`, `api.github.com`, and `objects.githubusercontent.com` — wider than every other language's allow-list, since Packagist only serves package metadata and the real `dist` downloads for GitHub-hosted packages come straight from GitHub; C#'s only path out is `semantic-analysis-csharp-proxy`, allow-listing just `api.nuget.org` — back to a single host, since NuGet serves both package metadata and content from the same place; Ruby's only path out is `semantic-analysis-ruby-proxy`, allow-listing just `rubygems.org` — also a single host, same as NuGet/Maven Central/PyPI/the Go module proxy. None of the containers talks to your git host directly, and the eight proxies/networks are kept fully separate rather than shared. Python's install step needed an extra safeguard the other languages don't: pip has no `--ignore-scripts` equivalent, since installing from an sdist always runs `setup.py`/build-backend code — `--only-binary=:all:` avoids that by only ever extracting prebuilt wheels, skipping (not failing the run for) any dependency with no wheel available. PHP's `composer install` runs with `--no-scripts --no-plugins`, the Composer analogue of `npm ci --ignore-scripts`, blocking both script hooks and Composer plugins from running arbitrary code. C#'s `dotnet restore` has no equivalent flag to disable MSBuild target/task execution — disclosed, not solved, same posture as Java/Kotlin's Maven `<build><extensions>` caveat. Ruby's `bundle install` has no `--ignore-scripts` equivalent either — a gem's native-extension build step can still run arbitrary code during install, disclosed here rather than solved, same posture as C#'s MSBuild caveat.

A "Semantic Analysis" panel on the review page shows run status, definition/diagnostic counts, a staleness warning if the run's commit doesn't match the review's current HEAD, and a scrollable diagnostics list linking straight into the diff at each finding's file — the same panel regardless of which language ran.

`SEMANTIC_ANALYSIS_TOKEN` (shared secret, same value on `app`/`sidekiq`/`semantic-analysis`), `SEMANTIC_ANALYSIS_MEM_LIMIT` (default `1536m`), and `SEMANTIC_ANALYSIS_CPUS` (default `1.5`) configure the Go sidecar; `SEMANTIC_ANALYSIS_TS_TOKEN`, `SEMANTIC_ANALYSIS_TS_MEM_LIMIT` (default `1536m`), and `SEMANTIC_ANALYSIS_TS_CPUS` (default `1.5`) configure the TypeScript sidecar the same way; `SEMANTIC_ANALYSIS_PY_TOKEN`, `SEMANTIC_ANALYSIS_PY_MEM_LIMIT` (default `1536m`), and `SEMANTIC_ANALYSIS_PY_CPUS` (default `1.5`) configure the Python sidecar the same way; `SEMANTIC_ANALYSIS_JAVA_TOKEN`, `SEMANTIC_ANALYSIS_JAVA_MEM_LIMIT` (default `1536m`), and `SEMANTIC_ANALYSIS_JAVA_CPUS` (default `1.5`) configure the Java sidecar the same way; `SEMANTIC_ANALYSIS_KT_TOKEN`, `SEMANTIC_ANALYSIS_KT_MEM_LIMIT` (default `1536m`), and `SEMANTIC_ANALYSIS_KT_CPUS` (default `1.5`) configure the Kotlin sidecar the same way; `SEMANTIC_ANALYSIS_PHP_TOKEN`, `SEMANTIC_ANALYSIS_PHP_MEM_LIMIT` (default `1024m`), and `SEMANTIC_ANALYSIS_PHP_CPUS` (default `1.0`) configure the PHP sidecar the same way; `SEMANTIC_ANALYSIS_CSHARP_TOKEN`, `SEMANTIC_ANALYSIS_CSHARP_MEM_LIMIT` (default `1536m`), and `SEMANTIC_ANALYSIS_CSHARP_CPUS` (default `1.5`) configure the C# sidecar the same way; `SEMANTIC_ANALYSIS_RUBY_TOKEN`, `SEMANTIC_ANALYSIS_RUBY_MEM_LIMIT` (default `1536m`), and `SEMANTIC_ANALYSIS_RUBY_CPUS` (default `1.5`) configure the Ruby sidecar the same way. All are configurable in `.env` — see `.env.example`.

**Not yet built (a future phase):** all eight originally-scoped languages now ship. Remaining gaps: GitLab/Bitbucket/self-hosted-VCS-hosted Composer packages for PHP (only GitHub-hosted `dist` downloads are allow-listed); a repo with multiple independent `.csproj` files and no `.sln` for C# (only the first found is restored/analyzed); Gradle support for Java and Kotlin; a typed Find-Usages/Go-to-Definition upgrade (Find Usages still runs on the tree-sitter index only, for all languages); diagnostics inlined into diff hunks; non-GitLab archive fetching; yarn/pnpm lockfile support for TypeScript (npm/`package-lock.json` only today).

## Architectural Lint & Duplicate Code Detection (Standard+)

Two independent checks, both off by default, both on **Settings → Architectural Lint**, both posting inline review comments from a dedicated bot account.

- **Architectural Lint** — Ruby (raw-SQL string interpolation) and TypeScript (explicit `any`) use the same tree-sitter parse the symbol indexer already does. **Go**, **Python**, **PHP**, **Java**, **Kotlin**, **Ruby**, and **JavaScript** are additionally checked by real external linters — `golangci-lint`, `Pylint`, `PHP_CodeSniffer`, `PMD`, `detekt`, `RuboCop`, and `ESLint` — running in a dedicated `lint-runner` container that starts automatically with the rest of the stack. All run fully offline: only checks confirmed not to need the target repository's own dependencies installed are enabled, so nothing is fetched over the network and no target code is ever executed — same trust model as the tree-sitter rules next to them. Posts as **Lint Bot**.
- **Duplicate Code Detection** — flags a changed method that's near-identical to another method anywhere in the repository. Every function/method-sized definition (4+ lines) already gets a body-only, whitespace-normalized fingerprint during indexing, so a duplicate is just a same-fingerprint lookup against existing data — no external tool, no extra scan. Catches exact-after-formatting duplicates, not ones with renamed variables throughout. Posts as **Duplicate Bot**.

### Go, Python, PHP, Java, Kotlin, Ruby, and JavaScript lint rules

| Language | Tool | Rules |
|---|---|---|
| Go | `golangci-lint` | `unqueryvet` (possible SQL injection via `SELECT *`, red), `ineffassign`, `predeclared`, `misspell` (yellow) |
| Python | `Pylint` | `eval-used`, `exec-used` (arbitrary code execution risk, red), `unused-variable` (yellow) |
| PHP | `PHP_CodeSniffer` + `phpcs-security-audit` | Full security-audit standard: SQL injection, `eval()`/`exec()`, remote file inclusion, weak crypto, and more — each finding's red/yellow severity comes from the tool's own classification |
| Java | `PMD` | `HardCodedCryptoKey`, `InsecureCryptoIv` (red); `EmptyCatchBlock`, `UnusedLocalVariable` (yellow) |
| Kotlin | `detekt` | `EmptyCatchBlock`, `UnusedPrivateProperty` (yellow) — smaller than the others since detekt ships no built-in security ruleset, and its type-resolution-dependent rules don't work without a real build classpath |
| Ruby | `RuboCop` | Whole `Security` department — `Eval`, `Open`, `JSONLoad`, `MarshalLoad`, `YAMLLoad`, `IoMethods`, `CompoundHash` (red); `UselessAssignment` (yellow) |
| JavaScript | `ESLint` | `no-eval`, `no-implied-eval` (red); `no-unused-vars`, `no-var`, `eqeqeq` (yellow) — run against our own bundled config, never the target repository's |

`LINT_RUNNER_TOKEN` (optional but recommended) authenticates requests to the `lint-runner` container the same way `SYMBOL_INDEXER_TOKEN` authenticates the symbol indexer — see `.env.example`.

## Semantic Search (Standard+)

Natural-language code search ("where do we handle JWT tokens") — an upgrade to ⌘K/Ctrl+K search, not a replacement for Find Usages/Go to Declaration.

Configure under **Settings → Semantic Search**: point it at a self-hosted **Ollama** instance (or any Ollama-compatible `/api/embeddings` endpoint) and pick an embedding model (default `mxbai-embed-large`, must already be pulled — `ollama pull mxbai-embed-large`). No code ever leaves your infrastructure; the URL is SSRF-validated the same way as other admin-configured provider URLs. Off by default until configured.

Every function/method-sized definition the tree-sitter indexer already extracts gets embedded after each push (async, so a slow embeddings API never blocks push processing). Search results rank by cosine similarity — computed in Ruby against the existing `symbol_definitions` table, no pgvector extension or separate vector database required. Runs across every branch that's been embedded for a repository, not just its default branch.

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

If you'd rather run your own reverse proxy in front of Codeveira instead (e.g. an existing host-level nginx/Caddy/Traefik shared across other services), that still works. By default `app:3000` and `lsp:7777` are internal-network-only (only the bundled `nginx` container publishes anything to the host, so every request actually gets TLS) — merge `docker-compose.byo-proxy.yml` to republish them: `docker compose -f docker-compose.yml -f docker-compose.byo-proxy.yml up -d`, and comment out the bundled nginx's own `ports:` block in `docker-compose.yml` (Compose merges `ports:` lists additively across `-f` files, so that block can't be removed via the override alone). Then point your own proxy at `app:3000` (and `lsp:7777` for IDE integration, over raw TCP, not HTTP). A reference host-nginx config is kept in [`nginx.conf.example`](nginx.conf.example) for that case.

## Scaling & High Availability

The shipped `docker-compose.yml` runs one replica of each service — enough for a single team on a single host. `app`, `sidekiq`, `lsp`, `indexer`, `lint-runner`, `semantic-analysis`, `semantic-analysis-ts`, `semantic-analysis-py`, `semantic-analysis-java`, and `semantic-analysis-kt` are stateless and safe to scale horizontally as-is:

- **`app`** — sessions use Rails' default cookie store (no server affinity needed) and the codebase makes no use of `Rails.cache`, so there's no server-local cache to desync between replicas. Put a load balancer in front of multiple `app` containers.
- **`sidekiq`** — scale with `docker compose up -d --scale sidekiq=3`; Sidekiq is designed for multiple workers pulling from the same Redis-backed queues.
- **`lsp` / `indexer` / `lint-runner` / `semantic-analysis` / `semantic-analysis-ts` / `semantic-analysis-py` / `semantic-analysis-java` / `semantic-analysis-kt` / `semantic-analysis-php` / `semantic-analysis-csharp` / `semantic-analysis-ruby`** — all stateless per-connection/per-request; add replicas if one becomes a bottleneck. `semantic-analysis`, `semantic-analysis-ts`, `semantic-analysis-py`, `semantic-analysis-java`, `semantic-analysis-kt`, `semantic-analysis-php`, `semantic-analysis-csharp`, and `semantic-analysis-ruby` are the heaviest of the group (`go mod download`/`npm ci`/`pip install`/`mvn dependency:resolve`/`kotlin-language-server`'s own Maven resolution/`composer install`/`dotnet restore`/`bundle install` plus a full LSP pass per run) — raise `SEMANTIC_ANALYSIS_MEM_LIMIT`/`SEMANTIC_ANALYSIS_CPUS`, `SEMANTIC_ANALYSIS_TS_MEM_LIMIT`/`SEMANTIC_ANALYSIS_TS_CPUS`, `SEMANTIC_ANALYSIS_PY_MEM_LIMIT`/`SEMANTIC_ANALYSIS_PY_CPUS`, `SEMANTIC_ANALYSIS_JAVA_MEM_LIMIT`/`SEMANTIC_ANALYSIS_JAVA_CPUS`, `SEMANTIC_ANALYSIS_KT_MEM_LIMIT`/`SEMANTIC_ANALYSIS_KT_CPUS`, `SEMANTIC_ANALYSIS_PHP_MEM_LIMIT`/`SEMANTIC_ANALYSIS_PHP_CPUS`, `SEMANTIC_ANALYSIS_CSHARP_MEM_LIMIT`/`SEMANTIC_ANALYSIS_CSHARP_CPUS`, and `SEMANTIC_ANALYSIS_RUBY_MEM_LIMIT`/`SEMANTIC_ANALYSIS_RUBY_CPUS` before adding replicas. `semantic-analysis-proxy`, `semantic-analysis-ts-proxy`, `semantic-analysis-py-proxy`, `semantic-analysis-java-proxy`, `semantic-analysis-kt-proxy`, `semantic-analysis-php-proxy`, `semantic-analysis-csharp-proxy`, and `semantic-analysis-ruby-proxy` only ever need one replica each — they're thin egress ACLs, not a bottleneck.
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
