# CLAUDE.md

Aturan utama proyek ada di AGENTS.md (dipakai bersama dengan Codex). Server ini adalah **produksi** — baca §4 di sana sebelum menjalankan perintah apa pun.

@AGENTS.md

## Tambahan khusus Claude Code

- Mulai setiap sesi dengan membaca `docs/TASKS.md` dan menyebutkan tugas yang akan dikerjakan.
- Ingat: commit ke branch yang di-mount (`main`) akan dijalankan pada restart container berikutnya. Commit hanya setelah `make check` hijau.
- Untuk tugas yang menyentuh lebih dari tiga berkas, susun rencana dulu (plan mode). Tunggu persetujuan bila tugas menyentuh uang, autentikasi, migrasi yang mengubah data, atau berkas di `deploy/`/`scripts/`.
- Pakai daftar tugas (todo) untuk langkah-langkah di dalam satu tugas `T-0xx`.
- Izin yang disarankan untuk `/permissions`:
  - izinkan: `make check`, `make test*`, `make sqlc`, `make migrate-new*`, `make verify`, `make logs`, `make ps`, `make migrate-status`, `go *`, `npm *`, `git status/diff/add/commit/log`
  - minta konfirmasi: `make deploy`, `make restart`, `make runtime`, `make psql`, `docker *`, `git push`, `git revert`, semua `rm`
  - tolak: `docker compose * down -v`, `docker volume rm *`, `docker system prune*`
