# Codeveira — Self-Hosted Code Review

> Post-commit code review platform for GitLab, GitHub, Gitea, Forgejo, Bitbucket, Azure DevOps and Gerrit.  
> The modern self-hosted alternative to JetBrains Upsource.

## Requirements

- Docker Engine 24+
- Docker Compose v2
- A domain with SSL certificate (recommended)

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/Codeveira/codeveira-deploy
cd codeveira-deploy

# 2. Configure
cp .env.example .env
# Edit .env — required: DB_PASSWORD, SECRET_KEY_BASE, APP_HOST

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

## Pinning a version

```bash
IMAGE_TAG=1.2.0 docker compose up -d
```

## Licensing

Codeveira is **free for any number of users** — no license key required (local AI models only). A license unlocks cloud AI providers and advanced features, priced per active user.

| Tier       | Price          | Users     | Key features                                                                  |
|------------|----------------|-----------|-------------------------------------------------------------------------------|
| Free       | $0             | Unlimited | Core review, 1 local AI bot, email notifications, IDE diagnostics             |
| Standard   | $10/user/mo    | Unlimited | Cloud AI providers, Compare, Slack/Teams, REST API, Backup, 2FA, review watchers |
| Extended   | $14/user/mo    | Unlimited | Multiple AI bots, Autofix, LDAP/AD, Audit log, Prometheus metrics             |
| Enterprise | $16/user/mo    | Unlimited | All features + Upsource import + audit log export/SIEM + CI status badge      |

To purchase a license: **hello@codeveira.com**

## Two-Factor Authentication

2FA is available on **Standard and higher** tiers. Admins can enforce it globally from **Settings → Users** — users without 2FA configured will be prompted to set it up after login and cannot bypass it. Users can also enable 2FA voluntarily from their **Profile** page.

## Repository Browser

A **unified navigation tab bar** sits at the top of every repository sub-page — README, Browse, Branches, Analytics, Members, Metrics, Edit, and All Reviews. The active section is underlined in blue. Jump between sections with one click without going back to the repository home page.

The browser lets you navigate the file tree, view syntax-highlighted files, check line-by-line blame (GitHub & GitLab), and inspect file commit history — all at any branch or commit SHA. A **branch switcher dropdown** lets you change branches instantly; the file tree shows only files on the selected branch. Cmd+K fuzzy file search is scoped to the current branch. Every line gets a `#L{n}` anchor for shareable deep links.

## @Mentions, Digest & Reply by Email

- **@mention** a user in any comment body to send them an immediate in-app + email notification.
- Users can opt into a **daily digest** in Profile → Notifications instead of per-event emails.
- **Reply by email** — set `INBOUND_EMAIL_DOMAIN` in `.env` and configure MX. Replying to a notification email posts a comment directly on the review.

## Documentation

Full documentation at **[codeveira.com/docs](https://codeveira.com/docs/)**.

- [Installation](https://codeveira.com/docs/installation/)
- [Settings](https://codeveira.com/docs/settings/)
- [IDE Integration](https://codeveira.com/docs/ide-integration/)
- [GitLab](https://codeveira.com/docs/gitlab-integration/)
- [GitHub](https://codeveira.com/docs/github-integration/)
- [Gitea / Forgejo](https://codeveira.com/docs/gitea-integration/)
- [Bitbucket](https://codeveira.com/docs/bitbucket-integration/)
- [Azure DevOps](https://codeveira.com/docs/azure-devops-integration/)
- [Gerrit](https://codeveira.com/docs/gerrit-integration/)
- [LDAP](https://codeveira.com/docs/ldap/)

## Nginx

A full nginx config template with all recommended headers and LSP TCP proxy is in [`nginx.conf.example`](nginx.conf.example).

Quick reference — copy to `/etc/nginx/sites-available/codeveira` and symlink to `sites-enabled/`:

```nginx
server {
    listen 80;
    server_name your-domain.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name your-domain.example.com;

    ssl_certificate     /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    client_max_body_size 10m;

    location / {
        proxy_pass         http://localhost:3000;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto https;
        proxy_set_header   X-Forwarded-Host  $host;
        proxy_redirect     off;
        proxy_read_timeout 90;
    }
}
```

For IDE integration (LSP), add to the **top level** of `/etc/nginx/nginx.conf`:

```nginx
stream {
    server {
        listen 7777;
        proxy_pass            127.0.0.1:7777;
        proxy_timeout         3600s;
        proxy_connect_timeout 5s;
    }
}
```

Then: `nginx -t && systemctl reload nginx` and open firewall port 7777/tcp.

## Support

- Website: [codeveira.com](https://codeveira.com)
- Email: hello@codeveira.com
