#!/usr/bin/env bash
# Entrypoint runtime scoreboard (ADR-0009).
#
# Repo di-mount read-only di /src. Saat container start, entrypoint:
#   1. menyalin kode ke /work/code — bawaan hanya kode yang SUDAH DI-COMMIT (HEAD),
#      atau isi folder apa adanya bila SOURCE_MODE=worktree;
#   2. mengompilasi bagian yang berubah (web, Go) — bila gagal, hasil terakhir yang
#      berhasil tetap dipakai sehingga situs tidak mati;
#   3. (api) backup database lalu menjalankan migrasi yang tertunda;
#   4. menjalankan program.
#
# Pemakaian: sb-entrypoint <perintah> <peran>
#   run api|worker      salin → build → (migrasi) → jalankan
#   prepare api|worker  salin → build saja (dipakai `make deploy` agar restart cepat);
#                       keluar dengan kode 3 bila build gagal, sehingga deploy berhenti
#   migrate             backup bila perlu → goose up
#   status              goose status
set -euo pipefail

CMD=${1:-run}
ROLE=${2:-api}
SRC=${SRC_DIR:-/src}
WORK=${WORK_DIR:-/work}
CODE="${WORK}/code"
OUT="${WORK}/out"
STATE="${WORK}/state"
SOURCE_MODE=${SOURCE_MODE:-commit}
MIGRATE_ON_START=${MIGRATE_ON_START:-1}
BACKUP_DIR=${BACKUP_DIR:-/backups}
MIGRATIONS="${CODE}/db/migrations"
BUILD_FAILED=0

log() { printf '%s [%s:%s] %s\n' "$(date -u +%FT%TZ)" "${CMD}" "${ROLE}" "$*" >&2; }
git_src() { git -c safe.directory="${SRC}" -C "${SRC}" "$@"; }

mkdir -p "${CODE}" "${OUT}" "${STATE}"

# Hash isi berkas (relatif terhadap ${CODE}); node_modules & hasil build diabaikan.
hash_of() {
  local p existing=()
  for p in "$@"; do [[ -e "${CODE}/${p}" ]] && existing+=("${p}"); done
  if [[ ${#existing[@]} -eq 0 ]]; then echo none; return 0; fi
  (cd "${CODE}" && find "${existing[@]}" -type f \
      -not -path '*/node_modules/*' -not -path 'web/dist/*' -print0 \
    | sort -z | xargs -0 -r sha256sum | sha256sum | cut -d' ' -f1)
}

sync_code() {
  if [[ "${SOURCE_MODE}" == "commit" ]]; then
    if ! git_src rev-parse --verify -q HEAD >/dev/null; then
      log "repo belum punya commit — jalankan: git add -A && git commit -m 'T-000' (atau SOURCE_MODE=worktree)"
      return 1
    fi
    local tmp
    tmp=$(mktemp -d)
    git_src archive --format=tar HEAD | tar -x -C "${tmp}"
    rsync -a --delete --exclude node_modules --exclude web/dist "${tmp}/" "${CODE}/"
    rm -rf "${tmp}"
    APP_VERSION=$(git_src describe --always 2>/dev/null || echo unknown)
    if [[ -n "$(git_src status --porcelain 2>/dev/null)" ]]; then
      log "catatan: ada perubahan belum di-commit — TIDAK ikut dijalankan (SOURCE_MODE=commit)"
    fi
  elif [[ "${SOURCE_MODE}" == "worktree" ]]; then
    rsync -a --delete --exclude .git --exclude node_modules --exclude web/dist \
      --exclude bin --exclude '.env' --exclude '.env.*' "${SRC}/" "${CODE}/"
    APP_VERSION=$(git_src describe --always --dirty 2>/dev/null || echo worktree)
  else
    log "SOURCE_MODE harus commit atau worktree, bukan '${SOURCE_MODE}'"
    return 1
  fi
  export APP_VERSION
  log "kode ${APP_VERSION} (${SOURCE_MODE}) disalin ke ${CODE}"
}

build_web() {
  local lock src
  lock=$(hash_of package.json package-lock.json web/package.json packages)
  if [[ ! -d "${CODE}/node_modules" || "$(cat "${STATE}/npm.hash" 2>/dev/null)" != "${lock}" ]]; then
    log "web: npm ci"
    if (cd "${CODE}" && npm ci --no-audit --no-fund); then
      echo "${lock}" > "${STATE}/npm.hash"
    else
      log "PERINGATAN: npm ci gagal — memakai hasil build web terakhir"
      BUILD_FAILED=1
      return 0
    fi
  fi
  src=$(hash_of package-lock.json web packages testdata)
  if [[ -d "${OUT}/web" && "$(cat "${STATE}/web.hash" 2>/dev/null)" == "${src}" ]]; then
    log "web: tidak ada perubahan"
    return 0
  fi
  log "web: build"
  if (cd "${CODE}" && npm run build -w web); then
    rm -rf "${OUT}/web.new" "${OUT}/web.old"
    cp -a "${CODE}/web/dist" "${OUT}/web.new"
    [[ -d "${OUT}/web" ]] && mv "${OUT}/web" "${OUT}/web.old"
    mv "${OUT}/web.new" "${OUT}/web"
    echo "${src}" > "${STATE}/web.hash"
    log "web: OK"
  else
    log "PERINGATAN: build web GAGAL — memakai hasil build terakhir"
    BUILD_FAILED=1
  fi
}

build_go() {
  local bin=$1 h
  h=$(hash_of go.mod go.sum cmd internal)
  if [[ -x "${OUT}/${bin}" && "$(cat "${STATE}/${bin}.hash" 2>/dev/null)" == "${h}" ]]; then
    log "${bin}: tidak ada perubahan Go"
    return 0
  fi
  log "${bin}: kompilasi"
  if (cd "${CODE}" && go build -trimpath -o "${OUT}/${bin}.new" "./cmd/${bin}"); then
    mv "${OUT}/${bin}.new" "${OUT}/${bin}"
    echo "${h}" > "${STATE}/${bin}.hash"
    echo "${APP_VERSION}" > "${STATE}/${bin}.version"
    log "${bin}: OK"
  else
    rm -f "${OUT}/${bin}.new"
    if [[ -x "${OUT}/${bin}" ]]; then
      log "PERINGATAN: kompilasi ${bin} GAGAL — tetap memakai biner terakhir ($(cat "${STATE}/${bin}.version" 2>/dev/null || echo ?))"
      BUILD_FAILED=1
      return 0
    fi
    log "kompilasi ${bin} gagal dan belum ada biner sebelumnya"
    return 1
  fi
}

wait_db() {
  for _ in $(seq 1 60); do
    pg_isready -q -d "${DATABASE_URL}" && return 0
    sleep 1
  done
  log "database tidak siap dalam 60 detik"
  return 1
}

migrate() {
  local status pending
  if ! status=$(goose -dir "${MIGRATIONS}" postgres "${DATABASE_URL}" status 2>&1); then
    log "migrasi: goose status gagal:"; printf '%s\n' "${status}" >&2
    return 1
  fi
  pending=$(printf '%s\n' "${status}" | grep -c 'Pending' || true)
  if [[ "${pending}" -eq 0 ]]; then
    log "migrasi: tidak ada yang tertunda"
    return 0
  fi
  mkdir -p "${BACKUP_DIR}"
  if find "${BACKUP_DIR}" -maxdepth 1 -name 'scoreboard-premigrate-*.dump' -mmin -60 2>/dev/null | grep -q .; then
    log "migrasi: ${pending} tertunda; backup < 60 menit sudah ada, tidak backup ulang"
  else
    local f
    f="${BACKUP_DIR}/scoreboard-premigrate-$(date -u +%Y%m%d-%H%M%S).dump"
    log "migrasi: ${pending} tertunda → backup ke ${f}"
    pg_dump -d "${DATABASE_URL}" -Fc -f "${f}.partial"
    mv "${f}.partial" "${f}"
  fi
  goose -dir "${MIGRATIONS}" postgres "${DATABASE_URL}" up
  log "migrasi: selesai"
}

case "${CMD}" in
  run)
    sync_code
    case "${ROLE}" in
      api)
        build_web
        build_go api
        wait_db
        if [[ "${MIGRATE_ON_START}" == "1" ]]; then migrate; fi
        export WEB_DIST_DIR="${OUT}/web"
        APP_VERSION=$(cat "${STATE}/api.version" 2>/dev/null || echo "${APP_VERSION}")
        log "menjalankan api ${APP_VERSION}"
        exec "${OUT}/api"
        ;;
      worker)
        build_go worker
        wait_db
        APP_VERSION=$(cat "${STATE}/worker.version" 2>/dev/null || echo "${APP_VERSION}")
        log "menjalankan worker ${APP_VERSION}"
        exec "${OUT}/worker"
        ;;
      *) log "peran tidak dikenal: ${ROLE}"; exit 2 ;;
    esac
    ;;
  prepare)
    sync_code
    if [[ "${ROLE}" == "api" ]]; then build_web; fi
    build_go "${ROLE}"
    if [[ "${BUILD_FAILED}" == "1" ]]; then
      log "BUILD GAGAL — jangan restart; perbaiki kode (lihat galat di atas). Versi yang berjalan tidak berubah."
      exit 3
    fi
    log "siap — restart container untuk menerapkan ${APP_VERSION}"
    ;;
  migrate)
    sync_code
    wait_db
    migrate
    ;;
  status)
    sync_code
    wait_db
    goose -dir "${MIGRATIONS}" postgres "${DATABASE_URL}" status
    ;;
  *)
    exec "$@"
    ;;
esac
