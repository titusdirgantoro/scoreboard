# AGENTS.md — aturan kerja untuk agen (Codex, Claude Code) dan manusia

Proyek: **scoreboard.tiusapp.com** — platform skor live, turnamen, dan main bareng untuk olahraga amatir Indonesia. Backend Go + PostgreSQL, frontend React + TypeScript, berjalan di satu VPS Ubuntu 24.04 lewat Docker Compose.

> **Hanya ada satu lingkungan: produksi** (ADR-0008). Tidak ada staging atau dev server. Kamu bekerja di server yang melayani pengguna sungguhan dan data sungguhan. Semua aturan di §4 berlaku mutlak.
>
> Repo ini (`/opt/scoreboard`) di-mount ke container (ADR-0009). Setiap kali container start/restart, **commit terakhir (HEAD)** dikompilasi dan dijalankan. Artinya: **setiap commit adalah calon rilis** — container bisa restart kapan saja (crash, reboot) dan langsung menjalankannya. Jangan pernah commit kode yang belum lulus `make check`.

## 1. Baca dulu (urut)

1. `docs/PRD.md` — apa yang dibangun dan untuk siapa (ID kebutuhan `F-x.y`).
2. `docs/ARCHITECTURE.md` — bagaimana sistem disusun; batas modul; protokol skor live.
3. `docs/DATA_MODEL.md` — tabel dan konvensi data.
4. `docs/TASKS.md` — urutan kerja. **Kerjakan satu tugas per sesi.**
5. `docs/design/README.md` — pemetaan layar desain → rute; sumber di `docs/design/screens/`, gambar di `docs/design/shots/`.
6. `docs/DECISIONS.md` — keputusan yang tidak boleh dilanggar tanpa ADR baru.

## 2. Alur kerja satu sesi

1. Pilih tugas `[ ]` teratas di `docs/TASKS.md` yang semua `Butuh`-nya `[x]`. Ubah jadi `[~]`.
2. Tulis rencana singkat (berkas yang disentuh, tes yang ditambah, apakah ada migrasi) sebelum mengubah kode.
3. Kerjakan dalam langkah kecil. Tambah/ubah tes lebih dulu bila memungkinkan.
4. Jalankan `make check` sampai hijau. Bila tugas menyentuh database: `make test-integration` (memakai database `scoreboard_test`, bukan data produksi).
5. Commit dengan pesan: `T-0xx: ringkasan singkat` + baris "Cek:" berisi bukti (perintah/tes yang dijalankan). Commit hanya setelah langkah 4 hijau.
6. Terapkan dengan `make deploy` (otomatis: `make check` → kompilasi commit HEAD di container yang masih berjalan → restart → backup DB + migrasi saat start → `make verify`). `make deploy` berhenti sebelum restart bila kompilasi gagal. Lihat §4 untuk kapan harus minta izin dulu.
7. Periksa hasil di `https://scoreboard.tiusapp.com` dan `make logs` (≥ 1 menit tanpa galat baru).
8. Perbarui dokumen yang terdampak (`DATA_MODEL.md`, `ARCHITECTURE.md`, `docs/api/openapi.yaml`, ADR), tandai tugas `[x]`, commit.
9. Berhenti dan laporkan. Jangan lanjut ke tugas berikutnya tanpa diminta.

## 3. Perintah

| Perintah | Fungsi | Menyentuh produksi? |
|---|---|---|
| `make setup` | `npm ci` + `go mod download` | tidak |
| `make check` | fmt, vet, tes, typecheck, build — **wajib hijau** | tidak |
| `make test-integration` | Buat ulang `scoreboard_test`, migrasi, tes DB | hanya database uji |
| `make migrate-new name=…` | Buat berkas migrasi baru | tidak |
| `make sqlc` | Bangkitkan kode dari `db/queries` | tidak |
| `make deploy` | Terapkan commit HEAD (lihat §2 langkah 6) | **ya** |
| `make restart` | Restart api & worker (menerapkan HEAD, kompilasi saat start) | **ya** |
| `make verify` | Cek `/readyz` & `/healthz` | baca saja |
| `make logs` / `make ps` | Log & status kontainer | baca saja |
| `make migrate-status` | Status migrasi | baca saja |
| `make backup` | Backup DB sekarang | aman |
| `make psql` | psql ke database produksi | **ya — hanya SELECT** |

## 4. Aturan keras (produksi)

Boleh tanpa bertanya:
- `make deploy` untuk perubahan yang **hanya menambah** (kode baru, tabel/kolom/indeks baru, migrasi yang bisa dibalik tanpa kehilangan data), setelah `make check` dan tes integrasi yang relevan hijau.
- Membatalkan rilismu sendiri bila `make verify` gagal atau log menunjukkan galat baru: `git revert <commit>` lalu `make deploy`; laporkan.

**Wajib minta persetujuan manusia dulu** (berhenti, jelaskan, tunggu):
- Migrasi yang menghapus/mengubah data: `DROP`, `ALTER … TYPE`, `RENAME`, `DELETE`/`UPDATE` massal, menambah `NOT NULL` ke tabel berisi data.
- Mengubah `.env` (termasuk `SOURCE_MODE`), `deploy/` (termasuk `deploy/docker/entrypoint.sh`), `deploy/edge/`, `scripts/`, cron, atau konfigurasi Caddy; menjalankan `make runtime`.
- Mengaktifkan pengiriman WhatsApp/email asli atau kunci Xendit **live**.
- Deploy saat ada event berlangsung (cek `make psql`: `SELECT count(*) FROM matches WHERE status='live'` > 0) atau di hari-H.

**Dilarang**:
- `docker compose … down -v`, `docker volume rm`, `docker system prune`, `DROP DATABASE scoreboard`, `TRUNCATE` di database `scoreboard`.
- Menulis ke database produksi lewat `make psql` (pakai migrasi atau kode aplikasi).
- Menjalankan tes atau skrip yang memakai `DATABASE_URL` produksi. Tes hanya boleh memakai `TEST_DATABASE_URL` yang nama database-nya berakhiran `_test`.
- Membaca, mencetak, atau meng-commit isi `.env`; menaruh rahasia di kode atau log.
- Mengirim pesan ke nomor/alamat asli dari tes; klien WA/email di tes harus tiruan.
- Perintah destruktif di luar folder repo (`rm -rf`, mengubah `/etc`, `ufw`, `sshd`).
- Mengubah migrasi yang sudah ter-commit atau sudah jalan; buat migrasi baru.
- `git push --force`, `git reset --hard` ke commit lama, atau menulis ulang riwayat di branch yang di-mount — pakai `git revert`.
- Commit setengah jadi ("WIP") ke branch yang di-mount. Kerja panjang yang belum selesai: simpan di branch lain (`git switch -c t-0xx`), gabungkan ke `main` setelah lulus cek.
- Menambah dependensi besar (framework web, ORM, state manager global, UI kit) tanpa ADR baru.

Bila ragu → berhenti dan tanya.

## 5. Konvensi Go

- Go stdlib `net/http` (pola rute Go 1.22: `mux.HandleFunc("GET /api/v1/x/{id}", …)`). Tidak ada framework web.
- Database: pgx v5 + sqlc. Tidak ada ORM. Setiap query bisnis memfilter `org_id` atau `event_id`.
- Modul di `internal/<modul>`: `service.go` (logika, tanpa HTTP), `handler.go` (HTTP), `store.go` (DB), `*_test.go`. Modul lain hanya memanggil fungsi publik service; tidak membaca tabel modul lain.
- `context.Context` argumen pertama; tidak ada variabel global yang bisa diubah.
- Galat: bungkus dengan `fmt.Errorf("…: %w", err)`; galat domain memakai tipe di `internal/infra/httpx` agar dipetakan ke kode API yang stabil.
- Log: `log/slog`, terstruktur, tanpa data pribadi (nomor HP disamarkan dengan `logx.MaskPhone`).
- Waktu disimpan UTC (`timestamptz`), ditampilkan `Asia/Jakarta`. Uang `int64` Rupiah.
- Tes: tabel-driven. Tes DB memakai build tag `integration` dan **hanya** `TEST_DATABASE_URL`; helper tes harus menolak URL yang nama database-nya tidak berakhiran `_test`. `go test ./...` tanpa tag harus jalan tanpa database.
- Fitur yang belum siap untuk publik disembunyikan dengan feature flag (`feature_flags`, T-126) atau rute yang belum ditautkan — bukan dengan lingkungan terpisah.
- Format: `gofmt`; nama paket huruf kecil tanpa garis bawah.

## 6. Konvensi TypeScript / React

- TypeScript `strict`. Tidak ada `any` tanpa komentar alasan.
- Komponen fungsi + hooks. Gaya CSS biasa per komponen/rute dengan token dari `web/src/styles/tokens.css`; tidak ada UI kit.
- Aturan olahraga hanya dari `@scoreboard/sportrules` — jangan menulis ulang di komponen.
- Panggilan API lewat `web/src/lib/api.ts`; tipe dari OpenAPI setelah T-016.
- Teks UI Bahasa Indonesia, sama dengan desain. Format tanggal/angka pakai `Intl` `id-ID`.
- Hormati `prefers-reduced-motion`; target sentuh ≥ 44 px; kontras AA.
- Tidak ada dev server; cek tampilan setelah `make deploy`, atau buka hasil `npm run build` lewat `APP_ENV=local ./bin/api` di port lokal sementara (mis. `HTTP_ADDR=127.0.0.1:18080`) lalu matikan.

## 7. Aturan olahraga (penting)

- Logika ada di dua tempat: `internal/sportrules` (Go) dan `packages/sportrules` (TS).
- Ubah fixture `testdata/sportrules/*.json` **lebih dulu**, lalu sesuaikan kedua implementasi sampai lulus.
- Tidak boleh ada perilaku yang hanya ada di satu bahasa.

## 8. Definisi selesai

- Kriteria "Selesai bila" tugas terpenuhi dan dibuktikan.
- `make check` hijau; tes integrasi hijau bila menyentuh DB; `make verify` hijau setelah deploy.
- Tidak ada TODO baru tanpa nomor tugas (`// TODO(T-0xx): …`).
- Dokumen yang terdampak sudah diperbarui.
- Tidak ada rahasia, data pribadi asli, atau berkas besar (> 1 MB) baru di commit kecuali aset desain yang disengaja.
