.PHONY: help dev dev-down build test lint migrate seed

help: ## Afficher l'aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ---- Docker ----

dev: ## Lancer l'environnement de dev (DB + API)
	cd docker && docker compose up --build -d

dev-down: ## Arreter l'environnement de dev
	cd docker && docker compose down

dev-logs: ## Voir les logs
	cd docker && docker compose logs -f api

dev-reset: ## Reset complet (supprime les donnees)
	cd docker && docker compose down -v && docker compose up --build -d

# ---- Backend Go ----

build: ## Compiler le backend
	cd backend && go build -o bin/geonote ./cmd/server

run: ## Lancer le backend en local
	cd backend && go run ./cmd/server

test: ## Lancer les tests backend
	cd backend && go test -v -race ./...

test-cover: ## Tests avec couverture
	cd backend && go test -coverprofile=coverage.out ./... && go tool cover -html=coverage.out

lint: ## Linter le backend
	cd backend && go vet ./...

# ---- Mobile Flutter ----

mobile-get: ## Installer les dependances Flutter
	cd mobile && flutter pub get

mobile-run: ## Lancer l'app mobile
	cd mobile && flutter run

mobile-test: ## Tests Flutter
	cd mobile && flutter test

mobile-analyze: ## Analyser le code Flutter
	cd mobile && flutter analyze

# ---- Database ----

migrate: ## Executer les migrations SQL
	@echo "Appliquer les migrations via Docker..."
	cd docker && docker compose exec db psql -U geonote -d geonote -f /docker-entrypoint-initdb.d/001_init_schema.up.sql

seed: ## Charger les donnees de test
	cd docker && docker compose exec db psql -U geonote -d geonote -f /docker-entrypoint-initdb.d/002_seed_data.up.sql

psql: ## Ouvrir un shell PostgreSQL
	cd docker && docker compose exec db psql -U geonote -d geonote
