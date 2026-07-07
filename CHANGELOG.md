# Changelog

All notable changes to Codeveira are documented here.

## [Unreleased]

### Added
- Two-factor authentication (TOTP) — admin global enforcement toggle in Settings → Users; per-user setup from Profile; green 2FA badge on user list; Standard+ feature

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
