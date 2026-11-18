# Image runtime: berisi toolchain (Go, Node, goose, pg_dump), BUKAN kode aplikasi.
# Kode datang dari repo yang di-mount read-only ke /src (ADR-0009); entrypoint
# menyalin, mengompilasi, lalu menjalankannya. Image ini jarang perlu di-build ulang
# (hanya saat ganti versi Go/Node/Postgres atau mengubah berkas ini): make runtime
FROM golang:1-bookworm

ARG PG_MAJOR=18
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg rsync git tini; \
    install -d /usr/share/postgresql-common/pgdg; \
    curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc; \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends "postgresql-client-${PG_MAJOR}"; \
    rm -rf /var/lib/apt/lists/*

# Node.js (untuk build web) dari image resmi.
COPY --from=node:24-bookworm-slim /usr/local/bin/node /usr/local/bin/node
COPY --from=node:24-bookworm-slim /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && node -v && npm -v

# goose untuk migrasi.
RUN GOBIN=/usr/local/bin go install github.com/pressly/goose/v3/cmd/goose@latest

ENV GOTOOLCHAIN=local \
    CGO_ENABLED=0 \
    NPM_CONFIG_UPDATE_NOTIFIER=false

COPY deploy/docker/entrypoint.sh /usr/local/bin/sb-entrypoint
RUN chmod +x /usr/local/bin/sb-entrypoint

WORKDIR /work
ENTRYPOINT ["/usr/bin/tini", "--", "sb-entrypoint"]
CMD ["run", "api"]
