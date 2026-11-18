# scoreboard.tiusapp.com

Platform skor live, turnamen, dan main bareng untuk olahraga amatir Indonesia — oleh Titus Dirgantoro.

- **Backend**: Go (stdlib `net/http`), PostgreSQL, antrean River, WebSocket
- **Frontend**: React + TypeScript + Vite (SPA + PWA remote wasit), disajikan oleh api Go
- **Server**: satu VPS Ubuntu 24.04 (Contabo), Docker Compose, Caddy
- **Lingkungan**: hanya produksi — `https://scoreboard.tiusapp.com` (ADR-0008)
- **Penerapan kode**: repo di `/opt/scoreboard` di-mount ke container; commit terakhir dikompilasi & dijalankan saat container restart (ADR-0009)

## Mulai di sini

| Dokumen | Isi |
|---|---|
| [`docs/PRD.md`](docs/PRD.md) | Kebutuhan produk, paket & harga, matriks akses |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Arsitektur sistem, modul, skor live, pembayaran, deploy |
| [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) | Tabel dan konvensi data |
| [`docs/TASKS.md`](docs/TASKS.md) | Daftar tugas berurutan untuk pengembangan |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Catatan keputusan arsitektur |
| [`docs/RUNBOOK.md`](docs/RUNBOOK.md) | Siapkan server, cara kode diterapkan, mundur versi, backup, hari-H |
| [`docs/design/README.md`](docs/design/README.md) | Referensi desain & pemetaan layar → rute |
| [`AGENTS.md`](AGENTS.md) | Aturan kerja agen AI (Codex & Claude Code) di server produksi |

## Rilis pertama (ringkas)

```bash
sudo bash scripts/bootstrap-server.sh        # sekali per server; repo di /opt/scoreboard
git init && git add -A && git commit -m "T-000"   # bila diekstrak dari zip
cp .env.example .env && chmod 600 .env       # isi rahasia
make setup
cd deploy/edge && cp .env.example .env && cd ../.. && make edge-up
make up                                      # build image runtime, kompilasi, migrasi, jalan

# setelahnya, setiap perubahan:
git commit -am "T-0xx: …" && make deploy     # atau cukup: make restart
```

Lalu buka `https://scoreboard.tiusapp.com`. Detail di `docs/RUNBOOK.md` §2–§3.

## Struktur

```
cmd/            titik masuk program (api, worker)
internal/       modul backend Go (lihat docs/ARCHITECTURE.md §5)
db/             migrasi goose & query sqlc
packages/       paket TypeScript bersama (sportrules)
testdata/       fixture bersama Go ↔ TypeScript
web/            aplikasi React
deploy/         compose produksi, Caddy edge, Dockerfile
scripts/        bootstrap server, backup, uji pulih
docs/           dokumen & referensi desain
```

## Status

Kerangka awal (T-000). Program api sudah menyajikan `/healthz`, `/readyz`, dan SPA placeholder; aturan bulu tangkis dan hub live sudah ada beserta tes. Lanjutkan dari `docs/TASKS.md` T-001.
