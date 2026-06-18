.PHONY: dev up down db-up db-down migrate api test test-go test-flutter flutter lint build-api

COMPOSE := docker compose -f infra/docker/docker-compose.yml

# Local dev: Postgres + API (migrations run automatically on API start).
dev: db-up
	@echo "Waiting for Postgres..."
	@i=0; until $(COMPOSE) exec -T postgres pg_isready -U justclock -q 2>/dev/null; do \
		i=$$((i+1)); \
		if [ $$i -ge 30 ]; then echo "Postgres did not become ready in time"; exit 1; fi; \
		sleep 1; \
	done
	$(MAKE) api

# Full stack in Docker (Postgres + API). Migrations run when the API container starts.
up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

db-up:
	$(COMPOSE) up -d postgres

db-down:
	$(COMPOSE) down

migrate:
	cd backend && go run ./cmd/migrate

migrate-down:
	cd backend && go run -tags tools ./cmd/migrate 2>/dev/null || true

api:
	cd backend && go run ./cmd/api

test: test-go test-flutter

test-go:
	cd backend && go test ./...

test-flutter:
	cd frontend && flutter test

flutter:
	cd frontend && flutter run -d web-server

lint:
	cd backend && go vet ./...
	cd frontend && flutter analyze

build-api:
	cd backend && go build -o bin/api ./cmd/api
