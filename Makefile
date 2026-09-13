.DEFAULT_GOAL := help

.PHONY: help update rollout backup upgrade ps logs

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /|/' | column -t -s '|'

update: ## Pull the latest images and recreate (brief gap while app restarts)
	docker compose pull
	docker compose up -d
	docker compose exec app rails db:migrate

rollout: ## Zero-downtime app update via rollout.sh (see README: not compatible with byo-proxy)
	./rollout.sh

backup: ## Snapshot Postgres (pg_dump) + Redis (BGSAVE+tar) into ./backup
	./backup.sh

upgrade: ## backup.sh, then zero-downtime app/sidekiq update + recreate everything else
	./upgrade.sh

ps: ## Show container status
	docker compose ps

logs: ## Tail logs (SERVICE=app by default: make logs SERVICE=sidekiq)
	docker compose logs -f $(or $(SERVICE),app)
