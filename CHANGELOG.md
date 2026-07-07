# Changelog

All notable changes to Codeveira are documented here.

## [Unreleased]

### Added
- Two-factor authentication (TOTP) — admin global enforcement toggle in Settings → Users; per-user setup from Profile; green 2FA badge on user list; Standard+ feature
- **Audit log export** (Enterprise) — download the current filtered audit log view as CSV or JSON (up to 10 000 events) from Settings → Audit Log
- **Audit webhook forwarding** (Enterprise) — configure an HTTP endpoint in Settings → Audit Log to receive every audit event as a JSON POST in real-time; compatible with Logstash HTTP input, Elastic Agent, Splunk HEC, Datadog, Graylog, and any SIEM
- **Like reactions on comments** (Free) — thumbs-up reactions on review comments; toggle with a single click, counter updates live
- **Review watchers** (Standard+) — any user can watch a review without being assigned as a reviewer; watchers receive all notifications (comments, status changes) but don't appear in the approval progress
- **CI status badge** (Enterprise) — CI systems (Jenkins, GitHub Actions, GitLab CI, etc.) POST build results to `/webhooks/ci`; live badge updates on review pages via Turbo Streams; configure secret token in Settings → CI Integration

### Changed
- **Upsource import wizard** moved from Standard to **Enterprise** tier

### Changed
- **Licensing model** — removed user limits from all tiers; every tier (including Free) now supports unlimited users. License key records the number of paid seats (`paid_users`) for billing reference only — no enforcement in the application
- Pricing changed to flat per-user rates: Standard $10/user/mo, Extended $14/user/mo, Enterprise $16/user/mo
- `bin/generate_license` flag renamed from `--max-users` to `--paid-users`
- License validation now rejects keys missing the `paid_users` field (old keys with `max_users` are rejected — regenerate using the new `--paid-users` flag)

## [1.0.0] — 2026-07-06

### Added
- Initial release
- Post-commit code review for GitLab, GitHub, Gitea, Forgejo, Bitbucket Cloud, Bitbucket Server, Azure DevOps, Gerrit
- AI Reviewer (Claude, OpenAI, DeepSeek, Gemini, Qwen, Ollama)
- Autofix — one-click AI suggestion commit via platform API
- Smart Reviewer Suggestions based on git history
- IDE integration via global LSP server (VS Code, JetBrains, Neovim)
- MCP server for Claude Code integration
- Slack and Microsoft Teams notifications
- Audit log, Prometheus metrics, cycle time metrics
- Database backup & restore
- Upsource migration import wizard
- 4 colour themes (Light, Dark, Dracula, Nord)
- LDAP / Active Directory authentication
- License system — Free / Standard / Extended / Enterprise / Custom tiers with RSA-signed JWT keys, offline verification, pricing calculator
- Stale CR badge and automatic tagging for inactive reviews
- Dashboard filters (time range, label)
