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

Codeveira is **free for up to 3 users** — no license key required. Larger teams need a license key entered in **Settings → License**.

| Tier       | Max users | Price       | Included users | Per extra user |
|------------|-----------|-------------|----------------|----------------|
| Free       | 3         | $0          | 3              | —              |
| Standard   | 20        | $69/mo      | 5              | $10/user/mo    |
| Extended   | 50        | $169/mo     | 10             | $14/user/mo    |
| Enterprise | 100       | $279/mo     | 15             | $16/user/mo    |
| Custom     | 101+      | Contact us  | —              | —              |

To purchase a license or ask about Custom pricing: **hello@codeveira.com**

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

```nginx
server {
    listen 80;
    server_name <your-domain>;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name <your-domain>;

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
        proxy_pass        127.0.0.1:7777;
        proxy_timeout     3600s;
        proxy_connect_timeout 5s;
    }
}
```

## Support

- Website: [codeveira.com](https://codeveira.com)
- Email: hello@codeveira.com
