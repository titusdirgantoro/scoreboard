# Daftar tugas pengembangan

Cara memakai berkas ini (untuk manusia dan agen):

1. Kerjakan berurutan per milestone. Ambil tugas `[ ]` paling atas yang semua `Butuh`-nya sudah `[x]`.
2. Saat mulai, ubah `[ ]` → `[~]` dan tulis inisial/tanggal di akhir baris judul. Saat selesai → `[x]`.
3. **Satu tugas = satu sesi agen = satu commit** (atau beberapa commit kecil) yang lulus `make check`.
4. Kriteria "Selesai bila" wajib terpenuhi dan dibuktikan dengan tes atau langkah cek yang ditulis di pesan commit.
5. Kalau tugas terlalu besar, pecah menjadi `T-xxxa`, `T-xxxb` di bawahnya sebelum mulai.
6. Temuan/keputusan baru → tambahkan ke `docs/DECISIONS.md`; perubahan skema → perbarui `docs/DATA_MODEL.md`.

Rujukan: `F-x.y` = kebutuhan di `docs/PRD.md`; nama `*.dc.html` = layar di `docs/design/screens/` (screenshot di `docs/design/shots/`).

Tanda **MVP** = wajib untuk rilis pertama.

---

## M0 · Fondasi repo & server

- [x] **T-000 · Kerangka repo** — struktur folder, dokumen, kerangka Go/TS yang bisa di-build, fixture bersama, compose, Caddy, skrip bootstrap.
- [ ] **T-001 · Siapkan server** (manusia + agen) · MVP
  - Jalankan `sudo bash scripts/bootstrap-server.sh` di VPS (lihat `docs/RUNBOOK.md` §1). Letakkan repo di `/opt/scoreboard` milik user `deploy` sebagai repo git dengan minimal 1 commit.
  - Selesai bila: `docker`, `go`, `node`, `make` tersedia untuk `deploy`; `ufw status` hanya 22/80/443; login root via SSH mati.
- [ ] **T-002 · Catat region VPS & penyedia DNS** · MVP
  - Cek region di panel Contabo; cek NS `tiusapp.com`. Tulis sebagai ADR baru di `docs/DECISIONS.md`. Bila VPS bukan di Asia, rencanakan pindah ke Singapura sebelum T-033.
  - Selesai bila: ADR tercatat.
- [ ] **T-003 · Edge Caddy** · MVP · Butuh T-001
  - `deploy/edge/`: isi `.env` (ACME_EMAIL), `make edge-up`. Pastikan tidak bentrok dengan web server lain yang sudah memakai 80/443.
  - Selesai bila: `make edge-validate` lulus; sertifikat untuk `scoreboard.tiusapp.com` terbit (lihat `make edge-logs`).
- [ ] **T-004 · Rilis pertama** · MVP · Butuh T-003
  - `cp .env.example .env` (isi rahasia, `chmod 600`), `make setup`, `make up`. Ini membangun image runtime, mengompilasi kode di container, menyalakan Postgres, dan menjalankan migrasi 00001–00002.
  - Selesai bila: `make verify` hijau dari luar (`https://scoreboard.tiusapp.com/healthz`), `make migrate-status` menunjukkan 2 migrasi terpasang, backup pra-migrasi ada di `/var/backups/scoreboard`; `make deploy` tanpa perubahan selesai dengan jeda < 10 detik.
- [ ] **T-005 · Dependensi Go inti** · MVP · Butuh T-001
  - `go get` jackc/pgx/v5 (pgxpool), google/uuid (UUIDv7 via `uuid.NewV7()`; dipakai override sqlc), pressly/goose/v3, coder/websocket, riverqueue/river (+ riverpgxv5), golang.org/x/oauth2. `go mod tidy`. Jangan tambah framework web/ORM.
  - Selesai bila: `make check` hijau, `go.sum` ter-commit.
- [ ] **T-006 · Koneksi DB, readiness, helper tes DB** · MVP · Butuh T-004, T-005
  - `internal/infra/db`: pool pgx dari `DATABASE_URL`, tutup saat shutdown; `/readyz` mengecek `SELECT 1` dengan timeout 1 detik.
  - `internal/infra/db/dbtest`: helper tes yang membaca **hanya** `TEST_DATABASE_URL`, menolak (t.Fatal) bila nama database tidak berakhiran `_test`, dan membungkus tiap tes dalam transaksi yang di-rollback.
  - Selesai bila: tes unit `/readyz` 200/503 dengan pinger tiruan; `make test-integration` hijau; helper menolak URL `…/scoreboard`; setelah `make deploy`, `/readyz` di produksi berisi `"db":"up"`.
- [ ] **T-007 · sqlc** · MVP · Butuh T-006
  - Lengkapi `db/sqlc.yaml`, query contoh `db/queries/users.sql` → paket `internal/infra/db/gen` (atau per modul). `make sqlc` lewat image Docker resmi.
  - Selesai bila: kode tergenerasi ter-commit dan dipakai satu fungsi `auth` dengan tes.
- [ ] **T-008 · CI** · MVP
  - Pastikan `.github/workflows/ci.yml` berjalan (Go vet/test, sqlc diff, web typecheck/test/build, migrasi di Postgres service).
  - Selesai bila: CI hijau di branch `main`.
- [ ] **T-009 · Validasi & galat API** · MVP · Butuh T-005
  - Helper decode JSON ketat (`DisallowUnknownFields`, batas 1 MB), galat `validation` dengan `fields`, pemetaan galat domain → HTTP di `infra/httpx`.
  - Selesai bila: tes tabel untuk tiap kode galat di ARCHITECTURE §13.
- [ ] **T-010 · Jadwal backup & pembekuan deploy** · MVP · Butuh T-004
  - Pasang cron backup harian (`docs/RUNBOOK.md` §5) + `rclone config` ke object storage; uji `scripts/restore-check.sh` sekali.
  - Selesai bila: dua backup berturut-turut tercatat di `/var/backups/scoreboard/backup.log` dan salinan ada di object storage; uji pulih lulus.

## M1 · Akun & masuk (F-1)

- [ ] **T-011 · Pengguna & sesi** · MVP · Butuh T-007
  - Store `users`, `sessions`; middleware sesi cookie `sb_session` (ARCHITECTURE §7); `GET /api/v1/me`; `POST /auth/logout`, keluar dari semua perangkat.
  - Selesai bila: tes integrasi login→me→logout; token di DB hanya hash.
- [ ] **T-012 · OTP email** · MVP · Butuh T-011
  - `POST /auth/otp/request` & `/verify` untuk email; selama SMTP belum diisi kode ditulis ke log; rate limit 5/10 menit per tujuan dan per IP.
  - Selesai bila: tes kedaluwarsa, salah 5×, rate limit.
- [ ] **T-013 · OTP WhatsApp** · MVP · Butuh T-012, T-072
  - Kanal `whatsapp` memakai template authentication; nomor dinormalisasi E.164 (`08…` → `+628…`).
  - Selesai bila: tes normalisasi nomor + alur verifikasi dengan klien WA tiruan.
- [ ] **T-014 · Masuk dengan Google** · MVP · Butuh T-011
  - OAuth Code + PKCE, tautkan ke pengguna lewat email terverifikasi.
  - Selesai bila: alur berjalan di `https://scoreboard.tiusapp.com` (redirect URI terdaftar di Google Console); tes unit untuk state/PKCE.
- [ ] **T-015 · CSRF** · MVP · Butuh T-011
  - Double-submit token untuk metode non-GET bersesi; dikecualikan: webhook, endpoint token PIN.
  - Selesai bila: tes 403 tanpa token.
- [ ] **T-016 · OpenAPI & klien TS** · MVP · Butuh T-011
  - `docs/api/openapi.yaml` untuk endpoint yang ada; `npm run gen:api` menghasilkan tipe ke `web/src/lib/api-types.ts` (openapi-typescript).
  - Selesai bila: CI gagal bila spesifikasi dan tipe tidak sinkron.
- [ ] **T-017 · Layar Masuk** · MVP · Butuh T-012, T-014 · `Masuk.dc.html`
  - Rute `/masuk?dari=…`, langkah masuk → kode → pilih peran → selesai; jalur PIN wasit.
  - Selesai bila: tampilan sesuai desain di 390 × 844; navigasi tujuan sesuai `dari`.
- [ ] **T-018 · Organisasi & anggota** · MVP · Butuh T-011
  - Org dibuat saat pertama menerbitkan event; `org_members` peran owner/admin/treasurer; undangan `org_invites`.
  - Selesai bila: tes izin matriks ARCHITECTURE §7 untuk aksi org.

## M2 · Event inti (F-2, F-3)

- [ ] **T-020 · API event** · MVP · Butuh T-018
  - CRUD event, slug otomatis + cek ketersediaan, tema `jsonb`, visibilitas & PIN penonton (hash).
  - Selesai bila: tes slug bentrok, validasi tanggal (selesai ≥ mulai), izin.
- [ ] **T-021 · Draf tanpa login** · MVP · Butuh T-020
  - Draf disimpan di `localStorage` (`sbDraftEvent`) lalu dikirim ke server setelah login (alur `dari=terbitkan-event`).
  - Selesai bila: draf utuh setelah login; tidak ada data hilang saat muat ulang.
- [ ] **T-022 · Layar Buat Event** · MVP · Butuh T-021 · `EventBuilder.dc.html`
  - Wizard 4 langkah, pratinjau ponsel/TV, contoh format menaut ke layar bracket.
  - Selesai bila: semua validasi di desain berjalan; tampilan sesuai screenshot.
- [ ] **T-023 · Terbitkan event** · MVP · Butuh T-022
  - `POST /events/{id}/publish`: validasi, `published_at`, cek entitlement; tiket terbit: salin link, WA, QR (dibuat di klien), poster, buka panel.
  - Selesai bila: event muncul di `/e/{slug}`; QR memindai ke link yang benar.
- [ ] **T-024 · API publik & meta OG** · MVP · Butuh T-020
  - `GET /api/v1/public/events/{slug}` (hormati visibilitas/PIN); Go menyuntikkan `<title>`, `og:title`, `og:description`, `og:image` ke `index.html` untuk `/e/{slug}`.
  - Selesai bila: pratinjau link di WhatsApp menampilkan nama event (cek dengan `curl -A WhatsApp`).
- [ ] **T-025 · Halaman Event** · MVP · Butuh T-024 · `EventPage.dc.html`
  - Fase sebelum/berlangsung, tema event, hitung mundur, slot, biaya, sponsor, pengumuman.
  - Selesai bila: LCP < 2,5 dtk di profil "Slow 4G" Lighthouse; tampilan sesuai desain.
- [ ] **T-026 · Lapangan, PIN, token akses** · MVP · Butuh T-020
  - CRUD `courts`, PIN 4 digit (hash argon2id/bcrypt), `pin_version`, rotasi mencabut `access_tokens`; `POST /api/v1/live/pin` dengan rate limit 5/10 menit per perangkat+IP.
  - Selesai bila: tes token lama ditolak setelah rotasi; brute force diblokir.
- [ ] **T-027 · Pengumuman (halaman event)** · MVP · Butuh T-024
  - `announcements` kanal `page`; tampil di halaman event urut terbaru.
  - Selesai bila: pengumuman baru tampil tanpa muat ulang (polling 30 dtk atau event live).

## M3 · Skor live (F-5)

- [ ] **T-030 · Aturan poin semua cabang** · MVP
  - Contoh lengkap: bulu tangkis (`internal/sportrules/badminton.go` + `packages/sportrules/src/badminton.ts` + `testdata/sportrules/badminton.json`). Tambahkan dengan pola sama: futsal/sepak bola/mini soccer, tenis (gim, deuce, tie-break, super tie-break), padel (opsi golden point), tenis meja, voli (25/15, set penentu), basket (1/2/3, kuarter).
  - Selesai bila: setiap cabang punya ≥ 8 kasus fixture yang lulus di Go **dan** TS (`make test`).
- [ ] **T-031 · Laga & log kejadian** · MVP · Butuh T-030, T-026
  - Store `matches`, `score_events`; `live.Apply(matchID, event)` menghitung snapshot dengan replay sportrules dalam satu transaksi; `live_version` naik.
  - Selesai bila: kiriman ulang `(client_id, seq)` sama tidak menggandakan poin; undo bekerja; tes integrasi.
- [ ] **T-032 · Endpoint kejadian skor** · MVP · Butuh T-031
  - `POST /api/v1/live/courts/{id}/events` (Bearer token PIN), `GET /api/v1/live/courts/{id}` snapshot.
  - Selesai bila: p95 < 30 ms lokal untuk 1 kejadian; tes izin lapangan lain ditolak.
- [ ] **T-033 · WebSocket siaran** · MVP · Butuh T-032
  - `GET /ws/live?topics=` memakai `internal/live.Hub` + coder/websocket; snapshot saat berlangganan, ping 25 dtk, putus klien lambat, batas topik per koneksi (20).
  - Selesai bila: tes integrasi subscribe→publish→terima; penonton menerima snapshot < 100 ms lokal.
- [ ] **T-034 · Remote wasit (PWA)** · MVP · Butuh T-033 · `Mobile-Skor.dc.html`
  - Rute `/e/{slug}/w/{court}`: masuk PIN, dua zona ketuk, undo, tukar, servis, status; antrean IndexedDB + kirim ulang; Wake Lock; manifest + service worker.
  - Selesai bila: mode pesawat 5 menit lalu online → semua ketukan masuk berurutan tanpa ganda (uji manual tercatat + tes unit antrean).
- [ ] **T-035 · Papan skor TV** · MVP · Butuh T-033 · `Scoreboard.dc.html`
  - Rute `/e/{slug}/tv` (semua lapangan) dan `/e/{slug}/tv/{court}`; tema event; animasi poin; tahan sambung ulang.
  - Selesai bila: berjalan 2 jam tanpa kebocoran memori di Chrome; jeda ketuk→TV p95 < 1 dtk di 4G.
- [ ] **T-036 · Koreksi skor & WO** · MVP · Butuh T-031
  - `POST /matches/{id}/corrections` (alasan wajib ≥ 4 huruf), `POST /matches/{id}/walkover`; `score_corrections`; publikasi ke hub; audit.
  - Selesai bila: riwayat koreksi lengkap; TV berubah langsung.
- [ ] **T-037 · Uji beban live** · MVP · Butuh T-035
  - Skrip di `scripts/loadtest/` (Go atau k6): 5.000 koneksi WS, 20 lapangan × 1 ketuk/2 dtk.
  - Selesai bila: p95 jeda < 1 dtk di VPS prod, CPU < 70%; hasil ditulis di `docs/RUNBOOK.md`.
- [ ] **T-038 · Layar Aturan poin** · `AturanPoin.dc.html` · Butuh T-030
  - Konten dari metadata sportrules (nama format, ringkasan aturan).
  - Selesai bila: teks sama dengan perilaku aturan di kode.

## M4 · Pendaftaran & panel penyelenggara (F-4.1–4.2, F-7)

- [ ] **T-040 · Pendaftaran publik** · MVP · Butuh T-025
  - `POST /public/events/{slug}/registrations`; rate limit; duplikasi nama tim ditolak; notifikasi panitia.
  - Selesai bila: formulir di halaman event berfungsi sesuai desain; tes validasi.
- [ ] **T-041 · Terima/tolak tim** · MVP · Butuh T-040, T-060
  - Alasan penolakan, kuota dari entitlement (`plan_limit` pemicu `tim-ke-9`), batalkan/pulihkan.
  - Selesai bila: tes kuota & paywall; kapten diberi tahu (job notifikasi).
- [ ] **T-042 · Kerangka panel + Ringkasan** · MVP · Butuh T-020 · `Admin.dc.html`
  - Rute `/e/{slug}/admin/*` dengan 10 bagian; Ringkasan: KPI, daftar tugas otomatis, pintasan alat.
  - Selesai bila: semua tab dapat dibuka; tampilan sesuai screenshot.
- [ ] **T-043 · Panel: Live semua lapangan** · MVP · Butuh T-033, T-042
- [ ] **T-044 · Panel: Wasit & lapangan** · MVP · Butuh T-026, T-042
  - Tunjuk wasit, ganti PIN, salin/kirim link WA, tambah lapangan (`plan_limit` pemicu `lapangan-ke-2`).
- [ ] **T-045 · Panel: Laga & hasil** · MVP · Butuh T-036, T-042
- [ ] **T-046 · Panel: Panitia & akses** · Butuh T-018, T-042
  - Undang admin/bendahara (batas admin per paket), wasit/meja (tanpa batas), hapus.
- [ ] **T-047 · Panel: Tema event** · MVP · Butuh T-042
  - Palet, warna kustom dengan cek kontras, pratinjau, terapkan ke TV/bracket/halaman.
- [ ] **T-048 · Panel: Pengaturan** · MVP · Butuh T-042
  - Pendaftaran buka/tutup + tanggal tutup otomatis (job), biaya, visibilitas, paket, arsip, hapus (ketik nama).

## M5 · Kompetisi & jadwal (F-6)

- [ ] **T-050 · Grup + gugur** · MVP · Butuh T-031
  - `stages`, undian grup, klasemen (poin, selisih, head-to-head), lolos 2 teratas, bracket gugur dengan bye; hasil laga memperbarui klasemen/bracket.
  - Selesai bila: tes properti (semua tim bertanding sesuai format), tes tie-break klasemen.
- [ ] **T-051 · Layar Mode Cup** · MVP · Butuh T-050 · `Cup.dc.html`
- [ ] **T-052 · Algoritma jadwal otomatis** · MVP · Butuh T-050
  - Masukan: lapangan, jam mulai, durasi, jeda, istirahat; aturan: tidak main beruntun, seimbang per lapangan. Keluaran + daftar konflik.
  - Selesai bila: tes untuk 16 tim × 4 lapangan tanpa konflik; deterministik untuk seed sama.
- [ ] **T-053 · Layar Jadwal otomatis** · MVP · Butuh T-052 · `Jadwal.dc.html`
  - Terbitkan ke halaman event & panel wasit, kirim ke kapten.
- [ ] **T-054 · Gugur langsung & liga** · Butuh T-050

## M6 · Paket & uang (F-8, F-9)

- [ ] **T-060 · Entitlement & harga** · MVP · Butuh T-018
  - `plan_prices` (seed dari PRD §F-9), `billing.Entitlements()`, galat 402 `plan_limit` (ARCHITECTURE §10).
  - Selesai bila: tes matriks paket × batas.
- [ ] **T-061 · Layar Harga & Upgrade** · MVP · Butuh T-060 · `Harga.dc.html`, `Upgrade.dc.html`
  - Upgrade menerima `pemicu` (tim-ke-9, lapangan-ke-2, sertifikat, watermark) dan melanjutkan aksi setelah bayar.
- [ ] **T-062 · Klien Xendit & sub-akun** · MVP · Butuh T-018
  - Klien HTTP (kunci test mode sampai peluncuran), buat sub-akun penyelenggara, simpan ID; verifikasi token webhook.
  - Selesai bila: tes dengan server tiruan; panggilan test mode terdokumentasi di RUNBOOK.
- [ ] **T-063 · Bayar pendaftaran** · MVP · Butuh T-062, T-041
  - Invoice/payment request atas nama sub-akun + split Rp2.000; webhook idempoten (`payment_webhooks`); status tim lunas.
  - Selesai bila: webhook ganda tidak menggandakan saldo; tes kedaluwarsa.
- [ ] **T-064 · Buku besar & tunai** · MVP · Butuh T-063
  - `ledger_entries` dua sisi, saldo dari ledger, lunas tunai, unduh laporan CSV (bisa dibuka Excel).
  - Selesai bila: invarian Σ = 0 dites untuk semua jenis transaksi.
- [ ] **T-065 · Beli paket & kuota** · MVP · Butuh T-062, T-060
  - Pass (aktif s.d. 30 hari setelah `ends_on`), Komunitas/Pro bulanan, kuota WA 100.
- [ ] **T-066 · Pencairan** · MVP · Butuh T-064
  - Penyelenggara minta → staf finance setuju/tahan → payout Xendit → webhook.
- [ ] **T-067 · Panel: Keuangan** · MVP · Butuh T-064, T-042
- [ ] **T-068 · Kode promo** · Butuh T-065

## M7 · Antrean & notifikasi (F-10)

- [ ] **T-070 · River & worker** · MVP · Butuh T-006
  - Migrasi River, `cmd/worker` memproses antrean, retry bertahap, job periodik; River UI hanya bisa diakses lewat SSH tunnel (tidak diekspos publik).
  - Selesai bila: job contoh dienqueue dalam transaksi yang sama dengan data.
- [ ] **T-071 · Email SMTP** · MVP · Butuh T-070
- [ ] **T-072 · WhatsApp Cloud API** · MVP · Butuh T-070
  - Kirim template, webhook status (verifikasi tanda tangan), `wa_messages`.
- [ ] **T-073 · Kuota WhatsApp** · Butuh T-072, T-065
- [ ] **T-074 · Panel: Pengumuman** · MVP · Butuh T-027, T-073
- [ ] **T-075 · Notifikasi otomatis** · MVP · Butuh T-072
  - Pendaftaran diterima/ditolak, tagihan, jadwal terbit, pengingat H-1.

## M8 · Konten berbagi (F-11)

- [ ] **T-080 · Unggah & gambar** · MVP · Butuh T-005
  - Presigned PUT ke object storage, validasi MIME/ukuran, URL imgproxy bertanda tangan.
- [ ] **T-081 · Potong latar** · Butuh T-080, T-070
- [ ] **T-082 · Story 9:16** · MVP · Butuh T-031, T-080 · `KartuHasil.dc.html`
  - Port 15 tata letak, 5 gaya, 13 stiker dari desain; ekspor PNG 1080 × 1920; tes Playwright "tidak ada teks/stiker tumpang tindih & di area aman".
- [ ] **T-083 · Watermark via entitlement** · MVP · Butuh T-082, T-060
- [ ] **T-084 · Data sertifikat & cek keaslian** · MVP · Butuh T-050
  - Penerima dari hasil bracket, token teks, kode unik, `/v/{kode}` publik.
- [ ] **T-085 · Layar Sertifikat** · MVP · Butuh T-084 · `Sertifikat.dc.html`
  - 5 gaya, edit teks, kunci paket Gratis (pemicu `sertifikat`).
- [ ] **T-086 · PDF sertifikat & kirim** · Butuh T-085, T-070

## M9 · Kartu pemain & verifikasi (F-4.3–4.5)

- [ ] **T-090 · Data pemain oleh manajer** · Butuh T-018, T-080
  - Undangan manajer, CRUD pemain, persetujuan wali untuk < 18 tahun.
- [ ] **T-091 · Layar Kartu Pemain & cetak** · Butuh T-090 · `KartuPemain.dc.html`
- [ ] **T-092 · Meja verifikasi** · Butuh T-091, T-026

## M10 · Format lanjutan (F-6.2–6.4)

- [ ] **T-100 · Upper & lower bracket** · Butuh T-050 · `CupEsports.dc.html`
- [ ] **T-101 · Americano & Mexicano** · Butuh T-050 · `Americano.dc.html`

## M11 · Komunitas (F-12)

- [ ] **T-110 · Grup & jadwal main bareng** · Butuh T-011, T-060
- [ ] **T-111 · Absen, daftar tunggu, patungan** · Butuh T-110 · `Absen.dc.html`
- [ ] **T-112 · Bagi tim seimbang** · Butuh T-110 · `BagiTim.dc.html`, `Mobile-Tim.dc.html`
- [ ] **T-113 · Rating Elo & profil** · Butuh T-112 · `Rating.dc.html`

## M12 · Portal admin platform (F-13) — `AdminPlatform.dc.html`

- [ ] **T-120 · Staf, izin, audit** · MVP · Butuh T-011
- [ ] **T-121 · Ringkasan & pengguna** · MVP · Butuh T-120
- [ ] **T-122 · Event & moderasi** · MVP · Butuh T-120
- [ ] **T-123 · Pembayaran & pencairan** · MVP · Butuh T-120, T-066
- [ ] **T-124 · Harga & promo** · MVP · Butuh T-120, T-060
- [ ] **T-125 · Tiket bantuan** · Butuh T-120
- [ ] **T-126 · WhatsApp, flag, mode perawatan** · Butuh T-120, T-072

## M13 · Peluncuran

- [ ] **T-130 · Beranda & SEO** · MVP · `Main.dc.html`
- [ ] **T-131 · Kebijakan privasi & ketentuan** · MVP (draf, ditinjau konsultan)
- [ ] **T-132 · Backup & uji pulih** · MVP · Butuh T-010
  - `scripts/backup-db.sh` di cron, salinan ke object storage, uji pulih tercatat; tahap 2 WAL-G.
- [ ] **T-133 · Pemantauan** · MVP · Butuh T-010
  - Uptime dari luar untuk `/healthz` & `/readyz`, `/metrics` Prometheus, alert ke WhatsApp/Telegram pemilik.
- [ ] **T-134 · Hardening keamanan** · MVP
  - Header Caddy, CSP, rate limit, cek dependensi (`govulncheck`, `npm audit`), review izin.
- [ ] **T-135 · Gladi hari-H & peluncuran** · MVP · Butuh T-037, T-067
  - Simulasi event 8 lapangan, 500 penonton, 1 jam; ikuti `docs/RUNBOOK.md` §6.
  - Peluncuran (dengan persetujuan pemilik): ganti kunci Xendit test mode → live, isi kredensial WhatsApp, matikan feature flag fitur yang belum siap, hapus data uji dari database produksi lewat migrasi/skrip yang ditinjau.
- [ ] **T-136 · Alamat sendiri paket Pro** · Butuh T-003, T-065
  - Record DNS `*.scoreboard`, Caddy dengan modul DNS (DNS-01) untuk sertifikat wildcard, routing host → org.
