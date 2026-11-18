# Runbook operasional

Satu lingkungan saja: **produksi** di `https://scoreboard.tiusapp.com` (ADR-0008). Repo berada di `/opt/scoreboard` dan di-mount read-only ke container (ADR-0009). Semua perintah dijalankan di VPS sebagai user `deploy` dari `/opt/scoreboard`, kecuali disebut `sudo`.

## 1. Menyiapkan server (sekali)

```bash
# sebagai root / sudo, dari salinan repo di server
sudo bash scripts/bootstrap-server.sh                    # paket dasar, Docker, Go, Node, ufw, fail2ban, user deploy
sudo INSTALL_AGENTS=1 bash scripts/bootstrap-server.sh   # sama + Claude Code & Codex CLI (opsional)

# pindahkan repo ke lokasi tetap
sudo mkdir -p /opt/scoreboard && sudo chown deploy:deploy /opt/scoreboard   # skrip bootstrap sudah membuatnya
sudo -u deploy git clone <url-repo> /opt/scoreboard   # atau ekstrak zip ke sini
```

Sebelum menyalakan ufw dari skrip, pastikan sesi SSH memakai port 22 atau set `SSH_PORT=` saat menjalankan skrip. Skrip **tidak** mematikan login password SSH; lakukan manual setelah kunci SSH `deploy` terpasang:

```bash
sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/; s/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl reload ssh
```

### Cek port 80/443 sudah dipakai?

```bash
sudo ss -ltnp '( sport = :80 or sport = :443 )'
```

Kalau sudah ada nginx/Apache untuk aplikasi lain di `*.tiusapp.com`, jangan jalankan `deploy/edge`. Tambahkan blok host di web server yang ada yang meneruskan `scoreboard.tiusapp.com` → `127.0.0.1:8080` (dengan dukungan WebSocket: header `Upgrade`/`Connection`) dan `/img/` → `127.0.0.1:8090`.

## 2. Rilis pertama

Folder repo **harus** repo git dengan minimal satu commit, karena container menjalankan commit terakhir (HEAD). Bila diekstrak dari zip:

```bash
cd /opt/scoreboard
git init && git add -A && git commit -m "T-000: kerangka repo"
```

Lalu:

```bash
cp .env.example .env && chmod 600 .env     # isi SESSION_SECRET, POSTGRES_PASSWORD, IMGPROXY_KEY/SALT (openssl rand -hex 32)
make setup                                 # npm ci + go mod download di host (untuk make check & tes)

cd deploy/edge && cp .env.example .env && cd ../..   # isi ACME_EMAIL
make edge-up                               # Caddy 80/443 + sertifikat otomatis

make up                                    # build image runtime, kompilasi web+Go di container, migrasi, jalan
```

Start pertama butuh beberapa menit (unduh toolchain, `npm ci`, kompilasi). Start berikutnya hanya mengompilasi bagian yang berubah. Buka `https://scoreboard.tiusapp.com`.

Sebelum peluncuran publik (T-135), pakai kunci **test mode** Xendit dan biarkan kredensial WhatsApp kosong (pesan hanya dicetak ke log). Fitur yang belum siap disembunyikan dengan feature flag, bukan lingkungan terpisah.

## 3. Cara kode diterapkan

```
/opt/scoreboard (repo, read-only di container)
   │  container start / restart
   ▼
sb-entrypoint: salin commit HEAD → /work/code → kompilasi yang berubah (web, Go) → backup + migrasi (api) → jalankan
```

| Mau | Perintah | Jeda layanan |
|---|---|---|
| Terapkan commit terbaru (disarankan) | `make deploy` — cek, kompilasi di container yang **masih berjalan**, lalu restart | beberapa detik |
| Cukup restart | `docker compose -p scoreboard -f deploy/compose.yml restart api worker` atau `make restart` | selama kompilasi (±5–60 detik) |
| Lihat yang sedang berjalan | `curl -s localhost:8080/healthz` (field `version`) | — |

Perilaku penting:

- **Hanya kode yang sudah di-commit** yang dijalankan (`SOURCE_MODE=commit`). Perubahan yang belum di-commit diabaikan dan dicatat di log. Ini mencegah suntingan setengah jadi ikut tayang saat container restart sendiri (crash, reboot server). `SOURCE_MODE=worktree` di `.env` membuat container menjalankan isi folder apa adanya — tidak disarankan.
- **Kompilasi gagal tidak mematikan situs**: saat restart, biner/web terakhir yang berhasil tetap dipakai dan peringatan muncul di `make logs`. `make deploy` berhenti sebelum restart bila kompilasi gagal.
- **Migrasi otomatis** saat api start; bila ada migrasi tertunda, database di-backup dulu ke `/var/backups/scoreboard/scoreboard-premigrate-*.dump`. Bila migrasi gagal, api tidak jalan (cek `make logs`), perbaiki dengan commit baru lalu `make deploy`.
- Image runtime hanya berisi toolchain (Go, Node, goose, pg_dump). Build ulang (`make runtime`) hanya saat mengganti versi Go/Node/Postgres atau mengubah `deploy/docker/`.

## 4. Bekerja dengan agen (Codex / Claude Code)

```bash
cd /opt/scoreboard
tmux new -s agen           # sesi tetap hidup saat SSH putus
claude                     # Claude Code — membaca CLAUDE.md → AGENTS.md
codex                      # Codex CLI — membaca AGENTS.md
```

Siklus setiap tugas: kode → `make check` → (`make test-integration` bila menyentuh DB) → commit → `make deploy` → cek situs & `make logs` → tandai tugas selesai. Aturan kapan agen harus minta izin ada di `AGENTS.md` §4.

Tes yang butuh database memakai database terpisah `scoreboard_test` di Postgres yang sama (dibuat ulang setiap `make test-integration`). Database `scoreboard` tidak pernah dipakai tes.

## 5. Mundur ke versi sebelumnya

Versi = commit git. Untuk membatalkan rilis:

```bash
git revert <commit>        # buat commit pembatal (riwayat tetap utuh)
make deploy
```

Migrasi **tidak** ikut dibatalkan oleh revert kode; karena itu migrasi harus selalu kompatibel dengan versi kode sebelumnya (tambah dulu, hapus belakangan di rilis terpisah). Bila migrasi merusak data: `docker compose -p scoreboard -f deploy/compose.yml --env-file .env stop api worker`, pulihkan backup `scoreboard-premigrate-*.dump` (§6 "Pulih sungguhan"), revert commit migrasinya, `make up`.

## 6. Backup & pulih

- Otomatis sebelum setiap migrasi (oleh container api), plus harian via cron:

```cron
0 19 * * * cd /opt/scoreboard && RCLONE_REMOTE=contabo:scoreboard-backups bash scripts/backup-db.sh >> /var/backups/scoreboard/backup.log 2>&1
```

- Berkas: `/var/backups/scoreboard/scoreboard-*.dump` (disimpan 14 hari) + salinan di object storage (`rclone config` sekali untuk remote `contabo`).
- Contabo Auto Backup/snapshot sebagai lapisan VPS.
- Uji pulih bulanan (memakai database sementara, database utama tidak disentuh):

```bash
bash scripts/restore-check.sh /var/backups/scoreboard/scoreboard-YYYYmmdd-HHMMSS.dump
```

- Pulih sungguhan (darurat):

```bash
docker compose -p scoreboard -f deploy/compose.yml --env-file .env stop api worker
docker compose -p scoreboard -f deploy/compose.yml --env-file .env exec -T postgres \
  pg_restore -U scoreboard -d scoreboard --clean --if-exists --no-owner < /var/backups/scoreboard/<berkas>.dump
make up
```

## 7. Hari-H event (checklist)

H-1:
- [ ] `make backup` dan pastikan file baru ada di object storage.
- [ ] `make verify` hijau; ruang disk > 30% (`df -h`).
- [ ] **Bekukan deploy** mulai H-1 18.00 sampai event selesai (beri tahu agen: jangan `make deploy`).
- [ ] Panitia sudah mencoba link wasit + PIN di HP masing-masing.

Hari-H:
- [ ] Pantau `make logs` dan dasbor uptime. Jangan commit ke `main` selama event (restart otomatis akan menerapkannya).
- [ ] Bila server tidak terjangkau: wasit terus mengetuk (antrean offline); umumkan via WhatsApp; cek `make ps`, `df -h`, `free -m`; `make restart`.
- [ ] Bila database rusak: ikuti §6 "Pulih sungguhan"; antrean HP wasit akan mengirim ulang ketukan.

## 8. Rotasi rahasia

| Rahasia | Lokasi | Cara rotasi |
|---|---|---|
| `SESSION_SECRET` | `.env` | Ganti → `make deploy` → semua pengguna harus masuk ulang |
| Kunci Xendit & token webhook | `.env` + dasbor Xendit | Buat kunci baru, deploy, cabut lama |
| Token WhatsApp | `.env` + Meta | Token sistem baru, deploy, cabut lama |
| Kunci S3 | `.env` + panel Contabo | Buat kunci baru, deploy, cabut lama |
| `POSTGRES_PASSWORD` | `.env` + `ALTER ROLE` | Ubah di DB dulu, lalu `.env`, lalu `make deploy` |

## 9. Upgrade PostgreSQL mayor

```bash
make backup
docker compose -p scoreboard -f deploy/compose.yml --env-file .env stop api worker
# dump → ganti POSTGRES_IMAGE & PG_MAJOR di .env → make runtime → volume baru → restore → make up
```

Rincian langkah ditulis saat upgrade pertama dilakukan.
