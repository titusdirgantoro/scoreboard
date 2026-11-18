# Catatan keputusan (ADR)

Format: konteks → keputusan → konsekuensi. Tambahkan ADR baru di bawah; jangan ubah ADR lama — buat ADR baru yang menggantikannya.

---

## ADR-0001 · Monolit modular Go + PostgreSQL di satu VPS

- **Konteks**: Tim kecil, sudah punya VPS Contabo Ubuntu 24.04 dan wildcard DNS `*.tiusapp.com`. Fitur paling kritis adalah skor live dengan banyak koneksi serentak.
- **Keputusan**: Satu repo, dua program Go (`api`, `worker`), satu PostgreSQL, Docker Compose di VPS yang sama. Pembagian modul di dalam `internal/` dengan batas tabel per modul.
- **Konsekuensi**: Biaya tetap rendah, deploy sederhana. Satu server adalah satu titik gagal → wajib backup teruji, antrean offline di HP wasit, dan runbook hari-H. Jalur skala tercatat di ARCHITECTURE §18.

## ADR-0002 · Skor sebagai log kejadian, server sebagai sumber kebenaran

- **Konteks**: Sinyal di GOR sering putus; panitia perlu koreksi skor dengan riwayat.
- **Keputusan**: Setiap ketukan adalah baris `score_events` dengan kunci idempoten `(match_id, client_id, seq)`. Snapshot dihitung ulang dari log dengan `internal/sportrules`. Undo dan koreksi adalah kejadian baru, bukan penghapusan.
- **Konsekuensi**: Kiriman ulang aman, audit lengkap. Replay harus cepat (log per laga kecil, < 1.000 baris).

## ADR-0003 · Kirim skor lewat HTTP POST, siaran lewat WebSocket

- **Konteks**: Remote wasit perlu antrean offline yang bisa diulang; penonton hanya menerima.
- **Keputusan**: Wasit `POST` kejadian; TV/halaman/panel berlangganan `GET /ws/live`. Hub pub/sub di memori; `LISTEN/NOTIFY` Postgres bila api lebih dari satu proses.
- **Konsekuensi**: Penulisan sederhana dan idempoten; WebSocket hanya satu arah (server → klien) plus ping.

## ADR-0004 · Aturan olahraga ditulis di Go dan TypeScript dengan fixture bersama

- **Konteks**: HP wasit harus menghitung skor saat offline; server harus memvalidasi.
- **Keputusan**: `internal/sportrules` (Go) dan `packages/sportrules` (TS) menerapkan aturan yang sama dan wajib lulus fixture JSON yang sama di `testdata/sportrules/`.
- **Konsekuensi**: Logika ditulis dua kali, tetapi perbedaan langsung ketahuan di CI. Setiap perubahan aturan = perubahan fixture lebih dulu.

## ADR-0005 · Xendit xenPlatform untuk uang penyelenggara

- **Konteks**: Biaya daftar milik penyelenggara; platform mengambil Rp2.000 per transaksi; penyelenggara perlu pencairan.
- **Keputusan**: Sub-akun Xendit per penyelenggara, split rule untuk fee platform, payout ke rekening penyelenggara. Semua mutasi dicatat di buku besar dua sisi milik kita.
- **Konsekuensi**: Perlu KYC penyelenggara sesuai jenis sub-akun; rekonsiliasi harian antara ledger dan laporan Xendit (tugas tahap 2).

## ADR-0006 · PostgreSQL 18 sebagai bawaan, tetap kompatibel 16

- **Konteks**: Pemilik mengusulkan PostgreSQL 16 (bawaan Ubuntu 24.04, didukung sampai Nov 2028). PostgreSQL 18 didukung sampai Nov 2030.
- **Keputusan**: Image `postgres:18` di compose (bisa diganti `POSTGRES_IMAGE=postgres:16`). Skema dan query tidak boleh memakai fitur yang hanya ada di 17/18 (mis. `uuidv7()` bawaan) — UUIDv7 dibuat di Go.
- **Konsekuensi**: Bisa pindah versi tanpa ubah kode; upgrade mayor dengan `pg_dump`/`pg_upgrade` sesuai RUNBOOK.

## ADR-0007 · Region VPS dan DNS (diisi di T-002)

- **Konteks**: Jeda skor live sangat dipengaruhi jarak server ke Indonesia; wildcard sertifikat `*.scoreboard` butuh API DNS.
- **Keputusan**: _belum diisi_ — tulis region VPS dan penyedia DNS.
- **Konsekuensi**: _belum diisi_.

## ADR-0008 · Hanya lingkungan produksi

- **Konteks**: Pemilik memutuskan (11 Nov 2026) tidak memakai staging atau dev environment; pengembangan oleh agen (Codex/Claude Code) langsung di VPS produksi.
- **Keputusan**: Satu compose project `scoreboard` dan satu domain `scoreboard.tiusapp.com`. Tidak ada dev server/Vite dev, tidak ada domain dev. Perubahan dirilis dengan `make deploy` yang selalu menjalankan `make check`, backup DB, migrasi, dan `make verify`. Tes database memakai database terpisah `scoreboard_test` di instance Postgres yang sama. Fitur yang belum siap disembunyikan dengan feature flag. Sebelum peluncuran memakai kunci test mode Xendit dan WhatsApp nonaktif.
- **Konsekuensi**: Lebih sederhana dan murah, tetapi setiap kesalahan langsung terlihat pengguna. Penjaga yang wajib: aturan §4 di `AGENTS.md`, backup otomatis sebelum deploy, migrasi selalu kompatibel mundur (tambah dulu, hapus belakangan), rollback image dengan `make rollback`, dan pembekuan deploy saat hari-H.

## ADR-0009 · Repo di-mount ke container, kode diterapkan dengan restart

- **Konteks**: Pemilik ingin repo di `/opt/scoreboard` di-mount ke Docker sehingga perubahan kode cukup diterapkan dengan restart container, tanpa membangun image aplikasi.
- **Keputusan**: Image `scoreboard-runtime` hanya berisi toolchain (Go, Node, goose, pg_dump). Repo di-mount read-only ke `/src`. `deploy/docker/entrypoint.sh` saat start menyalin **commit HEAD** (bawaan `SOURCE_MODE=commit`) ke volume kerja, mengompilasi web/Go yang berubah (cache di volume), mem-backup lalu memigrasi database (api), lalu menjalankan program. Kompilasi gagal → hasil terakhir yang berhasil tetap dipakai. `make deploy` mengompilasi dulu di container yang masih berjalan agar jeda restart hanya beberapa detik. Mundur versi dengan `git revert`.
- **Konsekuensi**: Penerapan sederhana (commit + restart) dan versi = commit git. Image produksi lebih besar dan berisi compiler (permukaan serangan lebih luas, diterima untuk satu VPS). Restart tanpa `make deploy` menunggu kompilasi. Setiap commit ke branch yang di-mount bisa tayang kapan saja container restart, sehingga commit wajib lulus `make check` dan pekerjaan setengah jadi dilakukan di branch lain. Menggantikan bagian rilis berbasis image di ADR-0008.
