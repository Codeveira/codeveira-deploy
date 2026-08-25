.DEFAULT_GOAL := help

.PHONY: help update rollout ps logs

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /|/' | column -t -s '|'

update: ## Pull the latest images and recreate (brief gap while app restarts)
	docker compose pull
	docker compose up -d
	docker compose exec app rails db:migrate

rollout: ## Zero-downtime app update via rollout.sh (see README: not compatible with byo-proxy)
	./rollout.sh

ps: ## Show container status
	docker compose ps

logs: ## Tail logs (SERVICE=app by default: make logs SERVICE=sidekiq)
	docker compose logs -f $(or $(SERVICE),app)
