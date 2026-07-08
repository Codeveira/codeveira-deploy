# Changelog

All notable changes to Codeveira are documented here.

## [Unreleased]

### Added
- **@mention notifications** (Free) — type `@username` in any comment to instantly notify the mentioned user with an in-app alert and email, even if they are not a reviewer or watcher of the review
- **Daily digest email** (Free) — per-user opt-in in Profile → Notifications; sends one morning summary (08:00 UTC) of all unread activity grouped by review instead of per-event emails; @mentions still deliver immediately regardless of this setting
- **Reply by email** (Free) — ActionMailbox integration; replying to a comment notification email creates a new comment on the review; requires `INBOUND_EMAIL_DOMAIN` environment variable and MX record pointing to the server
- **Repository browser** (Free) — browse files and navigate directory trees at any branch or commit; **branch switcher dropdown** to switch branches instantly with per-branch file filtering (tree and Cmd+K search show only files on the selected branch); syntax-highlighted file view with dark/light theme; line-by-line blame with author and commit info (GitHub & GitLab); file commit history with "Browse at this SHA" navigation; Cmd+K fuzzy file search scoped to the current branch; go-to-definition via Ctrl+click; branches list with default/protected badges; permalink to any file line via `#L{n}` anchor; **unified repository navigation tab bar** (README, Browse, Branches, Analytics, Members, Metrics, All Reviews) displayed identically on every repository sub-page — active tab underlined in blue, instant one-click switching between sections without returning to the repository home page
- Two-factor authentication (TOTP) — admin global enforcement toggle in Settings → Users; per-user setup from Profile; green 2FA badge on user list; Standard+ feature
- **Audit log export** (Enterprise) — download the current filtered audit log view as CSV or JSON (up to 10 000 events) from Settings → Audit Log
- **Audit webhook forwarding** (Enterprise) — configure an HTTP endpoint in Settings → Audit Log to receive every audit event as a JSON POST in real-time; compatible with Logstash HTTP input, Elastic Agent, Splunk HEC, Datadog, Graylog, and any SIEM
- **Emoji reactions on comments** (Free) — emoji reaction picker (👍 👎 👌 💪 🤞 🙏 🎉 😎 🐛 😢 🙅 🚫 + Yes / No / +1) on every comment; multiple different reactions per user per comment; grouped counters with live updates; own reactions highlighted in blue
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
