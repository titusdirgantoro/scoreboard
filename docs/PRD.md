# PRD — scoreboard.tiusapp.com

| | |
|---|---|
| Versi | 0.1 (draf untuk pengembangan) |
| Tanggal | 11 November 2026 |
| Pemilik produk | Titus Dirgantoro |
| Desain | Kanvas "scoreboard.tiusapp.com — UI/UX Design" (salinan di `docs/design/`) |
| Bahasa produk | Bahasa Indonesia, zona waktu Asia/Jakarta, mata uang Rupiah |

---

## 1. Ringkasan

scoreboard.tiusapp.com adalah platform olahraga amatir Indonesia untuk tiga kebutuhan yang selama ini tercecer di grup WhatsApp dan kertas:

1. **Main bareng** — absen, patungan lapangan, bagi tim seimbang, dan rating pemain untuk grup rutin.
2. **Skor live** — wasit mengetuk skor dari HP, skor langsung tampil di layar TV venue dan halaman event.
3. **Turnamen** — buat event dengan link sendiri, terima pendaftaran dan pembayaran tim, jadwal otomatis, bracket, kartu pemain, story hasil laga, dan e-sertifikat juara.

Cabang yang didukung: futsal, sepak bola, mini soccer, bulu tangkis, tenis, padel, tenis meja, bola voli, basket, dan e-sports.

## 2. Masalah

- Penyelenggara turnamen kampung, kantor, sekolah, dan komunitas mengelola pendaftaran lewat formulir terpisah, pembayaran lewat transfer manual, jadwal di spreadsheet, dan skor di papan tulis.
- Penonton dan pemain tidak tahu skor lapangan lain, jadwal berubah tanpa kabar, dan hasil tidak terdokumentasi.
- Grup main bareng repot menagih patungan dan membagi tim yang adil setiap minggu.

## 3. Tujuan rilis pertama (MVP) dan metrik

| Tujuan | Metrik | Target 3 bulan setelah rilis |
|---|---|---|
| Penyelenggara bisa menjalankan satu event utuh tanpa alat lain | Event terbit yang memakai skor live di ≥ 50% laganya | 60% dari event terbit |
| Skor terasa "langsung" | Jeda ketukan wasit → tampil di TV (p95, 4G) | < 1 detik |
| Pendaftaran dibayar online | Tim diterima yang lunas lewat QRIS/VA/e-wallet | ≥ 70% |
| Konversi berbayar | Event Gratis yang naik ke Pass Event | ≥ 15% |
| Produk tersebar sendiri | Story hasil laga dibagikan per event | ≥ 10 |

## 4. Pengguna dan peran

| Peran | Siapa | Butuh akun? | Kebutuhan utama |
|---|---|---|---|
| Pemilik event | Ketua panitia, karang taruna, HR kantor, OSIS | Ya | Buat event, terima tim, uang, skor, hasil |
| Admin event | Panitia tambahan (≤ 5 di paket Pro) | Ya | Sama seperti pemilik kecuali paket dan hapus event |
| Bendahara | Panitia keuangan | Ya | Pembayaran, tagihan, pencairan, laporan |
| Wasit | Relawan per lapangan | **Tidak** — link + PIN | Mengetuk skor dengan cepat, tahan sinyal jelek |
| Meja verifikasi | Petugas pintu masuk | **Tidak** — link + PIN | Cek kartu pemain dan status boleh main |
| Manajer tim / kapten | Wakil tim peserta | Ya (lewat undangan) | Daftar, bayar, isi data dan foto pemain |
| Pemain | Peserta | Opsional | Lihat jadwal, rating, profil |
| Penonton | Siapa saja dengan link | Tidak | Skor live, jadwal, bracket |
| Pengurus grup main bareng | Admin grup rutin | Ya | Absen, patungan, bagi tim, rating |
| Staf platform | Tim scoreboard.tiusapp.com | Ya + peran staf | Pengguna, event, pembayaran, harga, moderasi, bantuan |

## 5. Lingkup rilis

| Fase | Isi |
|---|---|
| **MVP** | Akun & masuk, buat event, halaman event, pendaftaran tim, panel penyelenggara inti, skor live (remote wasit + papan TV + aturan poin), jadwal otomatis, grup + gugur, pembayaran pendaftaran (Xendit), Pass Event, paywall, pengumuman, story hasil laga, e-sertifikat, portal admin platform inti |
| **Rilis 2** | Kartu pemain & meja verifikasi, upper/lower bracket (e-sports), liga, Americano/Mexicano, WhatsApp otomatis berkuota, paket Komunitas (absen, patungan, bagi tim, rating), paket Pro (5 admin, slot sponsor, ekspor Excel) |
| **Nanti** | Alamat sendiri `nama.scoreboard.tiusapp.com`, aplikasi native, statistik pemain lanjutan, streaming |

Urutan kerja rinci ada di `docs/TASKS.md`.

## 6. Kebutuhan fungsional

Setiap kebutuhan punya ID `F-x.y` yang dirujuk oleh tugas di `docs/TASKS.md`. Layar desain disebut dengan nama berkasnya di `docs/design/screens/`.

### F-1 Akun & masuk — `Masuk.dc.html`

- F-1.1 Masuk dengan Google, kode OTP email, atau kode OTP WhatsApp. Tidak ada kata sandi.
- F-1.2 Setelah masuk pertama, pengguna memilih peran awal (penyelenggara, manajer tim, pengurus grup, pemain). Peran awal hanya menentukan halaman tujuan, bukan izin.
- F-1.3 Konteks masuk dibawa dari layar asal (`dari`): terbitkan event → kembali ke Buat Event; undangan manajer → isi data pemain tim; simpan grup → buka grup.
- F-1.4 Wasit dan meja verifikasi masuk dengan link + PIN 4 digit tanpa akun. PIN salah dibatasi 5 kali per 10 menit per perangkat. PIN berlaku sampai event selesai dan bisa diganti panitia (link lama langsung tidak berlaku).
- F-1.5 Sesi bertahan 30 hari di perangkat; bisa keluar dari semua perangkat.

### F-2 Buat event — `EventBuilder.dc.html`

- F-2.1 Wizard 4 langkah: Identitas (nama, penyelenggara, tanggal, lokasi), Tampilan (logo, warna utama & aksen, mode terang/gelap, bentuk), Kompetisi (cabang, format, jumlah peserta, pendaftaran online, biaya per tim, sponsor), Tautan (slug, visibilitas, fitur yang tampil).
- F-2.2 Draf tersimpan otomatis tanpa login; login diminta saat menerbitkan.
- F-2.3 Format: grup + gugur, gugur langsung, upper & lower (double elimination), liga, Americano/Mexicano (padel). Tiap format menautkan contoh bracket.
- F-2.4 Slug unik, huruf kecil/angka/tanda hubung, dibuat otomatis dari nama; ketersediaan dicek langsung.
- F-2.5 Visibilitas: Publik (muncul di pencarian), Hanya pemilik link, Privat + PIN penonton.
- F-2.6 Setelah terbit: link, tombol bagikan WhatsApp, kode QR, poster, buka halaman event, buka panel penyelenggara.
- F-2.7 Pratinjau langsung (ponsel dan layar TV) mengikuti isian.

### F-3 Halaman event publik — `EventPage.dc.html`

- F-3.1 Alamat `scoreboard.tiusapp.com/e/{slug}`; tema event (warna, logo, mode) diterapkan.
- F-3.2 Fase "sebelum" (hitung mundur, pendaftaran) dan "berlangsung" (skor live semua lapangan, jadwal, klasemen).
- F-3.3 Formulir pendaftaran tim: nama tim, kapten, nomor WhatsApp, cabang; sisa slot dan biaya tampil; setelah kirim muncul ajakan mengisi data & foto pemain.
- F-3.4 Pratinjau link (judul, gambar) benar saat dibagikan di WhatsApp.
- F-3.5 Pengumuman panitia tampil di halaman.
- F-3.6 Slot sponsor (paket Pro) tampil di halaman, papan TV, dan story.

### F-4 Pendaftaran tim & pemain — `Admin.dc.html` (Pendaftaran), `KartuPemain.dc.html`

- F-4.1 Panitia melihat pendaftar per status (menunggu, diterima, ditolak), menerima, atau menolak dengan alasan (kuota penuh, data tidak lengkap, belum bayar); kapten diberi tahu lewat WhatsApp.
- F-4.2 Kuota tim mengikuti paket (Gratis 8, Pass 16/32/64).
- F-4.3 Manajer tim mengisi pemain: nama, nomor punggung, posisi, tanggal lahir, foto, kontak darurat.
- F-4.4 Kartu pemain ukuran ATM (54 × 85,6 mm) per pemain: depan (foto, nama, nomor, tim, status) dan belakang (data lengkap, akumulasi kartu kuning/merah); cetak per tim ke PDF.
- F-4.5 Meja verifikasi mencari nama/nomor, mencocokkan wajah, dan melihat status Boleh main / Larangan main / Dokumen kurang.

### F-5 Skor live — `Mobile-Skor.dc.html`, `Scoreboard.dc.html`, `AturanPoin.dc.html`

- F-5.1 Remote wasit di HP: dua zona besar untuk poin, batal (undo), tukar posisi, penanda servis, status set/gim, tanda laga selesai.
- F-5.2 Aturan poin per cabang dihitung otomatis: futsal/sepak bola (gol, babak), bulu tangkis (3 × 21 dan 3 × 15 BWF — main ke 15, di 14–14 selisih 2, di 20–20 poin berikut menang), tenis & padel (gim, set, tie-break, super tie-break), tenis meja (11, selisih 2), voli (25/15, selisih 2), basket (poin 1/2/3, kuarter).
- F-5.3 Setiap ketukan dikirim sebagai kejadian bernomor urut; ketukan yang dikirim ulang tidak terhitung dua kali.
- F-5.4 Saat sinyal putus, ketukan disimpan di HP dan dikirim begitu tersambung; layar menunjukkan status "tertunda N".
- F-5.5 Papan skor TV (`/e/{slug}/tv`) menampilkan satu lapangan atau semua lapangan, tema event, animasi saat poin; berjalan di browser TV tanpa login.
- F-5.6 Jeda ketukan → TV p95 < 1 detik.
- F-5.7 Hasil akhir mengalir ke bracket/klasemen dan bisa dijadikan story hasil laga.
- F-5.8 Panitia bisa mengoreksi skor dengan alasan wajib; koreksi tercatat di riwayat dan langsung tampil di TV.
- F-5.9 Walk-over (WO) dicatat dengan alasan.

### F-6 Kompetisi & jadwal — `Cup.dc.html`, `CupEsports.dc.html`, `Jadwal.dc.html`, `Americano.dc.html`

- F-6.1 Grup + gugur: undian grup, klasemen (poin, selisih, head-to-head), dua teratas lolos, babak gugur dengan bye.
- F-6.2 Upper & lower bracket (double elimination) untuk e-sports, Bo1/Bo3/Bo5.
- F-6.3 Liga (round-robin).
- F-6.4 Americano & Mexicano untuk padel: pasangan berganti tiap ronde, klasemen individu.
- F-6.5 Jadwal otomatis: jumlah lapangan, jam mulai, durasi laga, jeda istirahat (mis. 12.00–13.00), larangan tim main dua laga beruntun; konflik ditandai sebelum terbit.
- F-6.6 Terbitkan jadwal ke halaman event dan panel wasit; kirim ke kapten lewat WhatsApp.
- F-6.7 Juara dari bracket dibawa ke e-sertifikat.

### F-7 Panel penyelenggara — `Admin.dc.html`

Sepuluh bagian:

| Bagian | Isi |
|---|---|
| Ringkasan | Angka utama, daftar tugas (sebagian tercentang otomatis), pintasan ke alat event |
| Live semua lapangan | Skor tiap lapangan, wasit tersambung, umpan kejadian |
| Pendaftaran | Lihat F-4.1 |
| Laga & hasil | Daftar laga per status, koreksi skor, isi hasil/WO, riwayat koreksi |
| Wasit & lapangan | Tunjuk wasit, PIN per lapangan, ganti PIN, salin/kirim link, tambah lapangan (paywall di Gratis) |
| Keuangan | Terkumpul, saldo online, tunai, belum bayar; pembayaran per tim; kirim tagihan; tandai lunas tunai; cairkan saldo; unduh laporan |
| Pengumuman | Judul, isi, penerima, saluran (halaman event / bagikan sendiri via WhatsApp / WhatsApp otomatis berkuota) |
| Panitia & akses | Daftar panitia, undang (admin, bendahara, wasit, meja), batas admin per paket |
| Tema event | Nama, warna, palet siap pakai, pratinjau TV/bracket/halaman, terapkan |
| Pengaturan | Buka/tutup pendaftaran, tanggal tutup otomatis, biaya, visibilitas, paket & naik paket, arsipkan, hapus (konfirmasi ketik nama) |

### F-8 Pembayaran & keuangan

- F-8.1 Pendaftar membayar biaya tim lewat QRIS, virtual account, atau e-wallet melalui Xendit; status otomatis lewat webhook.
- F-8.2 Biaya layanan Rp2.000 per pembayaran online ditambahkan ke tagihan pendaftar.
- F-8.3 Dana masuk ke sub-akun penyelenggara (Xendit xenPlatform); panitia mencairkan ke rekening bank penyelenggara.
- F-8.4 Pembayaran tunai dicatat manual oleh bendahara/admin dan tidak masuk saldo online.
- F-8.5 Refund dari panel admin platform dengan alasan; fitur yang dibeli dinonaktifkan.
- F-8.6 Semua uang dicatat di buku besar dua sisi (debit/kredit); laporan bisa diunduh.
- F-8.7 Nominal disimpan sebagai bilangan bulat Rupiah.

### F-9 Paket, kuota & paywall — `Harga.dc.html`, `Upgrade.dc.html`

| Paket | Harga | Isi |
|---|---|---|
| Gratis | Rp0 | Event ≤ 8 tim di 1 lapangan, skor live, halaman event, bagi tim, absen dasar; watermark di story; e-sertifikat hanya pratinjau; 1 admin |
| Pass Event ≤16 | Rp49.000 / event | ≤ 16 tim, lapangan tak dibatasi, tanpa watermark, e-sertifikat, aktif sampai 30 hari setelah event selesai |
| Pass Event ≤32 | Rp99.000 / event | ≤ 32 tim, isi sama |
| Pass Event ≤64 | Rp199.000 / event | ≤ 64 tim, isi sama |
| Komunitas | Rp39.000 / bulan | Grup main bareng: absen, daftar tunggu, patungan, riwayat, rating |
| Pro | Rp299.000 / bulan | Event tanpa batas (≤ 64 tim/event), semua fitur Komunitas, sampai 5 admin, alamat sendiri, slot sponsor, ekspor Excel |
| Tambahan | Rp2.000 / pembayaran online; Rp50.000 / 100 pesan WhatsApp otomatis | |

- F-9.1 Batas paket ditegakkan di server; respons batas memakai kode `plan_limit` beserta pemicunya.
- F-9.2 Pemicu paywall: tim ke-9, lapangan ke-2, terbitkan sertifikat, hapus watermark. Layar Upgrade menampilkan pilihan paket yang relevan dan melanjutkan aksi setelah bayar.
- F-9.3 Harga diatur dari portal admin platform tanpa deploy ulang; perubahan berlaku untuk pembelian baru.
- F-9.4 Kode promo (persen, kuota pakai, cakupan paket).

### F-10 Notifikasi

- F-10.1 WhatsApp memakai WhatsApp Business Cloud API dengan template yang disetujui Meta (utility/authentication): OTP, konfirmasi pendaftaran, diterima/ditolak, tagihan, jadwal, pengumuman.
- F-10.2 Kuota pesan otomatis per penyelenggara; habis → tawarkan beli kuota atau "bagikan sendiri".
- F-10.3 Email untuk OTP dan kuitansi.
- F-10.4 Opsi "bagikan sendiri" selalu tersedia (membuka WhatsApp pengguna dengan teks siap kirim, gratis).

### F-11 Konten berbagi — `KartuHasil.dc.html`, `Sertifikat.dc.html`

- F-11.1 Story 9:16 (1080 × 1920) setelah tiap laga: 5 gaya (saat ini, duotone, potong latar, foto asli, foto sendiri), 15 tata letak, 13 stiker + otomatis/tanpa; teks dan stiker tidak boleh tumpang tindih dan berada di area aman Instagram.
- F-11.2 Foto tim (beregu) atau foto pemain (perorangan); potong latar otomatis.
- F-11.3 Watermark "Dibuat dengan scoreboard.tiusapp.com" di paket Gratis.
- F-11.4 E-sertifikat A4 lanskap: 5 gaya (klasik, modern, gelap, prestise, arena); judul, pengantar, dan isi bisa diedit dengan token (`{nama}`, `{peringkat}`, `{event}`, dll.); per penerima bisa diubah nama/peringkat.
- F-11.5 Nomor sertifikat unik dan halaman cek keaslian `scoreboard.tiusapp.com/v/{kode}`.
- F-11.6 Terbitkan, unduh PDF, kirim ke manajer tim/semua penerima.

### F-12 Komunitas — `Absen.dc.html`, `BagiTim.dc.html`, `Mobile-Tim.dc.html`, `Rating.dc.html`

- F-12.1 Absen main bareng: jadwal rutin, hadir/tidak/mungkin, daftar tunggu saat penuh, patungan per orang, pengingat yang belum bayar.
- F-12.2 Bagi tim: tim seimbang dari rating, kocok ulang, salin untuk grup, tampilan HP, mulai papan skor.
- F-12.3 Rating Elo: mulai 1.000, perubahan = 32 × (hasil − peluang menang), peluang = 1 / (1 + 10^((R lawan − R tim) / 400)); bintang 1–5 diturunkan dari rating; catat hasil laga + MVP.
- F-12.4 Profil pemain: top skor, MVP, laga dimainkan, riwayat rating.

### F-13 Portal admin platform — `AdminPlatform.dc.html`

- F-13.1 Ringkasan: KPI, pendapatan per sumber, peringatan, event live.
- F-13.2 Pengguna: cari, ganti paket (tercatat), catatan, kirim ulang link masuk, tangguhkan dengan alasan.
- F-13.3 Event: sembunyikan/tampilkan dengan alasan, perpanjang Pass +7 hari.
- F-13.4 Pembayaran: transaksi, refund, tagih ulang, ekspor; persetujuan/penahanan pencairan.
- F-13.5 Paket & harga, kode promo.
- F-13.6 Laporan konten (moderasi), tiket bantuan, statistik & template WhatsApp.
- F-13.7 Tim internal dengan matriks izin, log audit semua aksi staf.
- F-13.8 Pengaturan: cabang aktif, feature flag, mode perawatan (halaman publik menampilkan pesan, skor live dan remote wasit tetap jalan).

## 7. Matriks akses

| Fitur | Tanpa login | Login | Berbayar |
|---|---|---|---|
| Lihat halaman event, skor live, jadwal, bracket, papan TV | ✓ | | |
| Remote wasit, meja verifikasi | ✓ (link + PIN) | | |
| Daftar tim lewat formulir | ✓ | | |
| Bagi tim sekali pakai, aturan poin | ✓ | | |
| Cek keaslian sertifikat | ✓ | | |
| Buat draf event | ✓ | | |
| Terbitkan & kelola event | | ✓ | Kuota di atas 8 tim / >1 lapangan → Pass |
| Isi data & foto pemain (manajer) | | ✓ | |
| Story tanpa watermark | | ✓ | Pass/Pro |
| Terbitkan e-sertifikat | | ✓ | Pass/Pro |
| Simpan grup, absen, patungan, rating | | ✓ | Komunitas/Pro |
| Admin tambahan, slot sponsor, ekspor Excel, alamat sendiri | | ✓ | Pro |
| WhatsApp otomatis | | ✓ | Kuota tambahan |

## 8. Kebutuhan non-fungsional

| Area | Kebutuhan |
|---|---|
| Kinerja | Skor ketuk → TV p95 < 1 detik (4G). Halaman event LCP < 2,5 detik di Android kelas menengah 4G. API p95 < 200 ms untuk baca. |
| Kapasitas awal | 50 event bersamaan, 5.000 penonton live serentak, di satu VPS (4 vCPU / 8 GB) |
| Ketahanan | Remote wasit bekerja offline ≥ 30 menit tanpa kehilangan ketukan. Target ketersediaan hari-H 99,5%. |
| Data | RPO ≤ 5 menit (WAL diarsipkan), RTO ≤ 2 jam, uji pulih sebulan sekali |
| Keamanan | HTTPS di mana-mana, sesi cookie `HttpOnly` + `Secure` + `SameSite=Lax`, CSRF untuk aksi berubah, rate limit OTP/PIN, webhook diverifikasi, rahasia tidak di repo |
| Aksesibilitas | Kontras WCAG AA, target sentuh ≥ 44 px, dukung `prefers-reduced-motion` |
| Bahasa & format | Teks UI Bahasa Indonesia; tanggal "5–6 Desember 2026"; Rupiah "Rp250.000" |
| Peramban | Chrome Android 2 versi terakhir, Safari iOS 16+, Chrome/Edge desktop, browser Smart TV berbasis Chromium |

## 9. Data pribadi & kepatuhan

- Data yang disimpan: nama, nomor WhatsApp, email, foto, tanggal lahir pemain, kontak darurat, data pembayaran (tanpa data kartu — ditangani Xendit).
- Ikuti UU No. 27/2022 (PDP): dasar pemrosesan, pemberitahuan privasi, hak akses/hapus, notifikasi kebocoran. Server di Singapura diperbolehkan dengan syarat perlindungan setara (Pasal 56); catat di kebijakan privasi.
- Pemain di bawah 18 tahun (class meeting, liga pelajar): persetujuan wali saat manajer mengisi data; perhatikan PP 17/2025 (PP TUNAS). Foto anak tidak dipakai untuk promosi tanpa izin.
- Retensi: data event diarsip 12 bulan setelah selesai lalu dianonimkan kecuali hasil & sertifikat.
- Bukan nasihat hukum — tinjau dengan konsultan sebelum rilis publik.

## 10. Di luar lingkup MVP

Aplikasi native iOS/Android, siaran video, taruhan/odds, statistik per pemain per laga di luar gol/MVP, integrasi federasi resmi, multi-bahasa.

## 11. Pertanyaan terbuka

1. Region VPS Contabo (Singapura disarankan) dan penyedia DNS `tiusapp.com` (menentukan modul Caddy untuk wildcard `*.scoreboard`).
2. Badan usaha untuk akun Xendit xenPlatform dan model sub-akun (owned vs managed) — menentukan alur KYC penyelenggara.
3. Penyedia email transaksional (SMTP) dan mitra WhatsApp (langsung Meta Cloud API atau BSP).
4. Kebijakan refund Pass Event bila event batal.
5. Apakah pendaftaran tim mewajibkan OTP WhatsApp kapten (anti-spam) di MVP.

## 12. Referensi

- Desain: `docs/design/README.md` (pemetaan layar → rute) dan kanvas https://claude.ai/artifact/XWsSLeAZeYEDpSw4oxM7Hp
- Arsitektur: `docs/ARCHITECTURE.md`; data: `docs/DATA_MODEL.md`; keputusan: `docs/DECISIONS.md`
- Xendit xenPlatform: https://docs.xendit.co/xenplatform
- WhatsApp Cloud API: https://developers.facebook.com/docs/whatsapp/cloud-api
