# Changelog

All notable changes to Codeveira are documented here.

## [Unreleased]

### Added
- **@mention notifications** (Free) — type `@username` in any comment to instantly notify the mentioned user with an in-app alert and email, even if they are not a reviewer or watcher of the review
- **Daily digest email** (Free) — per-user opt-in in Profile → Notifications; sends one morning summary (08:00 UTC) of all unread activity grouped by review instead of per-event emails; @mentions still deliver immediately regardless of this setting
- **Reply by email** (Free) — ActionMailbox integration; replying to a comment notification email creates a new comment on the review; requires `INBOUND_EMAIL_DOMAIN` environment variable and MX record pointing to the server
- **Repository browser** (Free) — browse files and navigate directory trees at any branch or commit; **branch switcher dropdown** to switch branches instantly with per-branch file filtering (tree and Cmd+K search show only files on the selected branch); syntax-highlighted file view with dark/light theme; line-by-line blame with author and commit info (GitHub & GitLab); file commit history with "Browse at this SHA" navigation; Cmd+K fuzzy file search scoped to the current branch; go-to-definition via Ctrl+click; branches list with default/protected badges; permalink to any file line via `#L{n}` anchor; **unified repository navigation tab bar** (README, Browse, Branches, Analytics, Members, Metrics, All Reviews) displayed identically on every repository sub-page — active tab underlined in blue, instant one-click switching; repository name in the header is a clickable link back to the repository home page
- **Repository home page** (Free) — stat cards showing open reviews (with total count), member count, and last commit (message, SHA, relative time); webhook setup section collapsed by default via `<details>` element; recent reviews list with reviewer assignment badges
- **All Reviews filters** (Free) — filter reviews by status (All / Open / Approved / Rejected), by author, and by assigned reviewer simultaneously; dropdowns appear only when data exists; all filters combinable and preserve state when changed; ✕ Clear link resets all active filters
- **Compare Files branch/ref selector** (Standard) — each side of the Compare tool now has a branch/commit ref field (defaults to HEAD); compare any file across branches, tags, or specific commits without cloning; diff labels show `repo@ref — path`
- Two-factor authentication (TOTP) — admin global enforcement toggle in Settings → Users; per-user setup from Profile; green 2FA badge on user list; Standard+ feature
- **Audit log export** (Enterprise) — download the current filtered audit log view as CSV or JSON (up to 10 000 events) from Settings → Audit Log
- **Audit webhook forwarding** (Enterprise) — configure an HTTP endpoint in Settings → Audit Log to receive every audit event as a JSON POST in real-time; compatible with Logstash HTTP input, Elastic Agent, Splunk HEC, Datadog, Graylog, and any SIEM
- **Emoji reactions on comments** (Free) — emoji reaction picker (👍 👎 👌 💪 🤞 🙏 🎉 😎 🐛 😢 🙅 🚫 + Yes / No / +1) on every comment; multiple different reactions per user per comment; grouped counters with live updates; own reactions highlighted in blue
- **Review watchers** (Standard+) — any user can watch a review without being assigned as a reviewer; watchers receive all notifications (comments, status changes) but don't appear in the approval progress
- **CI status badge** (Enterprise) — CI systems (Jenkins, GitHub Actions, GitLab CI, etc.) POST build results to `/webhooks/ci`; live badge updates on review pages via Turbo Streams; configure secret token in Settings → CI Integration
- **Review templates** (Free) — reusable title presets for new code reviews; managed in Settings → Review Templates; "Use template" dropdown appears in the New Review form when templates exist
- **Outgoing webhooks per repository** (Free) — each repository can POST JSON events (`review.approved`, `review.rejected`, `review.closed`, `review.reopened`, `comment.created`) to any HTTP/HTTPS endpoint; optional HMAC-SHA256 signature via `X-Codeveira-Signature`; managed under the Webhooks tab on the repository page
- **Diff statistics in reviews list** (Free) — additions (+N) and deletions (-M) displayed in green/red next to commit count on the All Reviews list
- **Copy link to commit** (Free) — "⎘ Copy link" button on commit diff pages and next to each commit in the per-commit review view; copies the direct URL to clipboard
- **Global Cmd+K search** (Free) — press ⌘K / Ctrl+K anywhere to open a search overlay; searches repositories by name, reviews by title or CR number, and commits by SHA prefix; keyboard navigation with ↑↓ arrows and Enter to open
- **Copy link to review** (Free) — ⎘ Copy link button now also appears in the review header next to the CR-ID; copies the full review URL to clipboard
- **Go to file from diff** (Free) — "Go to file" button next to "Side by side" in every file header in commit diffs and CR diffs (combined and per-commit views); opens the full syntax-highlighted file in the repository browser at the exact commit SHA
- **User Stats** (Free) — new Settings → User Stats page; admin-only dashboard with per-user activity: 52-week GitLab-style contribution heatmap (full-width, fixed month labels), weekly bar chart (last 26 weeks), day-of-week bar chart, CR status breakdown donut, reviews authored table, reviewer activity table; all charts on inner JS tabs without page reload; summary stat cards (CRs authored, reviews given, approvals, rejections, comments)
- **Notifications redesign** (Standard+) — Settings → Chat Notifications renamed to Settings → Notifications; new tabs: Slack | Teams | Email | Webhook | SMS; each channel has independent per-event toggles (New review / Assigned / Comment / Approved / Rejected) and fully customisable message templates with `{{cr_id}}`, `{{title}}`, `{{status}}`, `{{repository}}`, `{{author}}`, `{{url}}` variables; green dot indicator on active channels
- **Global outgoing Webhook notifications** (Standard+) — new Notifications → Webhook tab; POST HMAC-SHA256 signed JSON payload to any HTTPS endpoint on selected review events; payload includes event, review metadata (id, cr_id, title, status, url, repository, author), actor and ISO-8601 timestamp; secret key optional
- **SMS notifications via HTTP API** (Standard+) — new Notifications → SMS tab; integrates with any HTTP SMS provider (SMSAPI, Twilio, Vonage, MessageBird, Infobip and others); quick-fill presets for 5 providers; configurable API URL, auth token, auth style (Bearer/Token/X-API-Key), sender, recipients, JSON field name mapping; message templates with character counter (160-char SMS limit)
- **Email notifications settings** (Standard+) — new Notifications → Email tab; configure sender display name, per-event toggles, and per-event subject line templates; SMTP config shown read-only from environment variables
- **Notification commit author** (Free) — commit author name shown in the CR review sidebar below each commit entry

### Performance
- **Diff stats pre-computed** — `additions_count` / `deletions_count` columns added to `commits` table; stats are computed once on save and read from DB instead of being parsed from raw diff text on every request; dashboard and review list performance improved significantly for large repositories

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
