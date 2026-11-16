COMPOSE = docker compose -f docker/docker-compose.yml --env-file .env

.PHONY: up down logs ps test isolation-demo reset

up:            ## build and start the local stack
	@test -f .env || (echo "Missing .env - run: cp .env.example .env  (then edit values)" && exit 1)
	$(COMPOSE) up -d --build
	$(COMPOSE) ps

down:          ## stop containers (keeps the database volume)
	$(COMPOSE) down

reset:         ## stop AND delete the database volume (fresh start)
	$(COMPOSE) down -v

logs:
	$(COMPOSE) logs -f --tail=100

ps:
	$(COMPOSE) ps

test:          ## backend tests (SQLite, no Postgres needed)
	cd backend && TENANT_DB_ENGINE=sqlite TENANTS_FILE=../database/tenants/tenants.json DJANGO_DEBUG=true python manage.py test

isolation-demo: ## prove tenant A cannot see tenant B (needs `make up` first)
	bash scripts/isolation_demo.sh
