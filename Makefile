# Makefile — perintah harian. Satu lingkungan saja: produksi (ADR-0008).
# Repo di /opt/scoreboard di-mount ke container; kode yang sudah di-commit diterapkan
# dengan restart (ADR-0009). Resep memakai prefiks ">" (bukan tab) supaya aman diedit agen.
.RECIPEPREFIX := >
SHELL := /bin/bash
.DEFAULT_GOAL := help

-include .env
export

GOOSE_VERSION ?= latest
GOOSE := go run github.com/pressly/goose/v3/cmd/goose@$(GOOSE_VERSION)
COMPOSE := docker compose -p scoreboard -f deploy/compose.yml --env-file .env
COMPOSE_EDGE := docker compose -p scoreboard-edge -f deploy/edge/compose.yml --env-file deploy/edge/.env
# Database uji terpisah di Postgres yang sama. Nama WAJIB berakhiran _test.
TEST_DATABASE_URL ?= postgres://scoreboard:$(POSTGRES_PASSWORD)@127.0.0.1:5432/scoreboard_test?sslmode=disable

.PHONY: help setup env-check fmt vet test test-go test-ts test-db test-integration typecheck build check \
        runtime up deploy restart verify migrate migrate-status migrate-new sqlc psql ps logs backup \
        edge-validate edge-up edge-logs

help: ## Daftar perintah
> @grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

setup: ## Pasang dependensi Node & Go di host (untuk tes & cek sebelum commit)
> npm ci
> go mod download

env-check:
> @test -f .env || (echo ".env belum ada: cp .env.example .env lalu isi" && exit 1)
> @test -n "$(POSTGRES_PASSWORD)" || (echo "POSTGRES_PASSWORD kosong di .env" && exit 1)

# ---------- kualitas (di host, tidak menyentuh data produksi) ----------
fmt: ## Format kode Go
> gofmt -w cmd internal

vet: ## go vet
> go vet ./...

test-go: ## Tes Go tanpa database
> go test ./...

test-ts: ## Tes TypeScript
> npm test

test: test-go test-ts ## Semua tes tanpa database

test-db: env-check ## Buat ulang database uji scoreboard_test lalu migrasi (dari kode di folder kerja)
> @case "$(TEST_DATABASE_URL)" in *_test\?*|*_test) ;; *) echo "TEST_DATABASE_URL harus menunjuk database *_test"; exit 1;; esac
> $(COMPOSE) exec -T postgres dropdb -U scoreboard --if-exists scoreboard_test
> $(COMPOSE) exec -T postgres createdb -U scoreboard scoreboard_test
> $(GOOSE) -dir db/migrations postgres "$(TEST_DATABASE_URL)" up

test-integration: test-db ## Tes Go yang butuh database (scoreboard_test, bukan data produksi)
> TEST_DATABASE_URL="$(TEST_DATABASE_URL)" go test -tags integration -count=1 ./...

typecheck: ## Cek tipe TypeScript
> npm run typecheck

build: ## Build web + biner Go di host (pemeriksaan saja; produksi mengompilasi di container)
> npm run build
> CGO_ENABLED=0 go build -o bin/api ./cmd/api
> CGO_ENABLED=0 go build -o bin/worker ./cmd/worker

check: ## WAJIB sebelum commit: format, vet, tes, typecheck, build
> @test -z "$$(gofmt -l cmd internal)" || (echo "Jalankan: make fmt" && gofmt -l cmd internal && exit 1)
> $(MAKE) vet test typecheck build

# ---------- produksi ----------
runtime: ## Build image runtime (toolchain) — hanya saat ganti versi Go/Node/Postgres
> $(COMPOSE) build api

up: env-check ## Nyalakan semua service (pertama kali: build image runtime + kompilasi)
> $(COMPOSE) up -d postgres api worker imgproxy
> $(MAKE) verify

deploy: env-check check ## Terapkan commit terakhir: kompilasi di container yang berjalan → restart → verifikasi
> @if [ -n "$$(git status --porcelain)" ]; then echo "PERINGATAN: ada perubahan belum di-commit — tidak ikut diterapkan (SOURCE_MODE=commit)"; fi
> @if $(COMPOSE) ps --status running --services 2>/dev/null | grep -qx api; then \
>   $(COMPOSE) exec -T api sb-entrypoint prepare api && \
>   $(COMPOSE) exec -T worker sb-entrypoint prepare worker && \
>   $(COMPOSE) restart api worker; \
> else \
>   $(COMPOSE) up -d postgres api worker imgproxy; \
> fi
> $(MAKE) verify
> @echo "Diterapkan: $$(git describe --always 2>/dev/null)"

restart: ## Restart api & worker (mengompilasi ulang bila ada commit baru)
> $(COMPOSE) restart api worker

verify: ## Tunggu & cek /readyz lokal dan /healthz publik
> @for i in $$(seq 1 120); do curl -fsS http://127.0.0.1:8080/readyz >/dev/null 2>&1 && break; sleep 2; done
> curl -fsS http://127.0.0.1:8080/readyz && echo
> curl -fsS $(PUBLIC_BASE_URL)/healthz && echo

migrate: env-check ## Jalankan migrasi tertunda sekarang (otomatis juga saat api start; backup dulu)
> $(COMPOSE) exec -T api sb-entrypoint migrate

migrate-status: env-check ## Status migrasi produksi
> $(COMPOSE) exec -T api sb-entrypoint status

migrate-new: ## Buat berkas migrasi baru: make migrate-new name=tambah_tabel
> @test -n "$(name)" || (echo "pakai: make migrate-new name=…" && exit 1)
> $(GOOSE) -dir db/migrations -s create $(name) sql

sqlc: ## Bangkitkan kode Go dari db/queries
> docker run --rm -u $$(id -u):$$(id -g) -v "$$PWD":/src -w /src/db sqlc/sqlc generate

psql: env-check ## Buka psql ke database produksi (hanya SELECT)
> $(COMPOSE) exec postgres psql -U scoreboard -d scoreboard

ps: ## Status kontainer
> $(COMPOSE) ps

logs: ## Log api & worker
> $(COMPOSE) logs -f --tail=200 api worker

backup: env-check ## Backup database sekarang
> bash scripts/backup-db.sh

# ---------- edge ----------
edge-validate: ## Cek sintaks Caddyfile
> docker run --rm --env-file deploy/edge/.env -v "$$PWD/deploy/edge":/etc/caddy:ro caddy:2 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

edge-up: edge-validate ## Nyalakan Caddy edge (80/443)
> $(COMPOSE_EDGE) up -d

edge-logs: ## Log Caddy edge
> $(COMPOSE_EDGE) logs -f --tail=200
