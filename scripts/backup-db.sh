#!/usr/bin/env bash
# Backup database produksi (pg_dump format custom) ke /var/backups/scoreboard, salin ke
# object storage bila RCLONE_REMOTE diisi, lalu hapus backup lebih tua dari KEEP_DAYS.
# Sebelum migrasi, container api juga membuat backup sendiri (scoreboard-premigrate-*.dump).
#
# Cron (sebagai deploy, 02.00 WIB = 19.00 UTC):
#   0 19 * * * cd /opt/scoreboard && RCLONE_REMOTE=contabo:scoreboard-backups bash scripts/backup-db.sh >> /var/backups/scoreboard/backup.log 2>&1
set -euo pipefail
cd "$(dirname "$0")/.."

BACKUP_DIR=${BACKUP_DIR:-/var/backups/scoreboard}
KEEP_DAYS=${KEEP_DAYS:-14}
RCLONE_REMOTE=${RCLONE_REMOTE:-}

ts=$(date -u +%Y%m%d-%H%M%S)
file="${BACKUP_DIR}/scoreboard-${ts}.dump"
mkdir -p "${BACKUP_DIR}"

docker compose -p scoreboard -f deploy/compose.yml --env-file .env \
  exec -T postgres pg_dump -U scoreboard -d scoreboard -Fc > "${file}.partial"
mv "${file}.partial" "${file}"
echo "$(date -u +%FT%TZ) backup: ${file} ($(du -h "${file}" | cut -f1))"

if [[ -n "${RCLONE_REMOTE}" ]]; then
  rclone copy "${file}" "${RCLONE_REMOTE}/"
  echo "disalin ke ${RCLONE_REMOTE}"
fi

find "${BACKUP_DIR}" -name 'scoreboard-*.dump' -mtime +"${KEEP_DAYS}" -print -delete
