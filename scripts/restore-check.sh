#!/usr/bin/env bash
# Uji pulih: pulihkan sebuah dump ke database SEMENTARA (restore_check_<waktu>) di
# Postgres produksi, hitung baris tabel utama, lalu hapus database sementara itu.
# Database utama "scoreboard" tidak disentuh.
#   bash scripts/restore-check.sh /var/backups/scoreboard/scoreboard-YYYYmmdd-HHMMSS.dump
set -euo pipefail
dump=${1:?pakai: scripts/restore-check.sh <berkas.dump>}
[[ -f "${dump}" ]] || { echo "berkas tidak ada: ${dump}" >&2; exit 1; }
cd "$(dirname "$0")/.."

C="docker compose -p scoreboard -f deploy/compose.yml --env-file .env"
db="restore_check_$(date +%s)"
[[ "${db}" != "scoreboard" ]] || exit 1

${C} exec -T postgres createdb -U scoreboard "${db}"
trap '${C} exec -T postgres dropdb -U scoreboard --if-exists "${db}"' EXIT

${C} exec -T postgres pg_restore -U scoreboard -d "${db}" --no-owner --no-privileges < "${dump}"
${C} exec -T postgres psql -U scoreboard -d "${db}" -c "
  SELECT 'users' AS tabel, count(*) FROM users
  UNION ALL SELECT 'events', count(*) FROM events
  UNION ALL SELECT 'matches', count(*) FROM matches
  UNION ALL SELECT 'score_events', count(*) FROM score_events;"
echo "uji pulih OK: ${dump}"
