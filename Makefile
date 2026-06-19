.PHONY: dev up down db-up db-down migrate api test test-go test-flutter flutter lint build-api klein templ-install

COMPOSE := docker compose -f infra/docker/docker-compose.yml

define run_templ
	if command -v templ >/dev/null 2>&1; then \
		templ $(1); \
	elif [ -x "$$(go env GOPATH)/bin/templ" ]; then \
		"$$(go env GOPATH)/bin/templ" $(1); \
	else \
		go run github.com/a-h/templ/cmd/templ@latest $(1); \
	fi
endef

templ-install:
	go install github.com/a-h/templ/cmd/templ@latest

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

klein:
	cd backend/dashboard && \
	$(call run_templ,generate ./views/...) && \
	mkdir -p .klein/views && \
	for f in views/*_templ.go; do \
		base=$$(basename "$$f" _templ.go); \
		cp "$$f" ".klein/views/$$base.templ.go"; \
	done && \
	rm -f views/*_templ.go

api: klein
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

build-api: klein
	cd backend && go build -o bin/api ./cmd/api
