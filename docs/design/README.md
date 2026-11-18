# Referensi desain

Sumber desain adalah kanvas Claude "scoreboard.tiusapp.com — UI/UX Design":
https://claude.ai/artifact/XWsSLeAZeYEDpSw4oxM7Hp

Isi folder ini:

- `screens/*.dc.html` — salinan sumber tiap layar (markup, gaya, dan logika demo). Bukan kode produksi: sintaksnya memakai runtime kanvas (`{{lubang}}`, `<sc-if>`, `<sc-for>`, kelas `Component extends DCLogic`). Pakai sebagai acuan tata letak, ukuran, warna, teks, animasi, dan perilaku.
- `shots/*.jpg` — tangkapan layar keadaan awal tiap layar.

Cara port ke React (`web/src/`):

1. Ambil struktur dari markup, ubah `{{nama}}` jadi props/state, `<sc-for list>` jadi `.map()`, `<sc-if value>` jadi kondisional.
2. Logika di `renderVals()` adalah contoh perilaku. Data asli datang dari API; aturan olahraga dari `@scoreboard/sportrules`.
3. Kelas animasi (`*-a`/`*-b`) di desain dipakai untuk memicu ulang animasi; di React cukup ganti `key` atau kelas.
4. Teks UI dipakai apa adanya (Bahasa Indonesia).

## Token visual "Arena Malam"

| Token | Nilai |
|---|---|
| Latar | `#0B0D12` (permukaan `#0F1218`, `#12151C`; garis `#232834`, `#343B4A`) |
| Teks | `#F2F1EC` (sekunder `#C9CDD6`, redup `#A3A9B6`) |
| Bara (utama) | `#FF7A2E` |
| Samudra (aksen) | `#4D7CFF` |
| Kunyit | `#F2C230` |
| Anggrek | `#C084FC` |
| Sukses | `#7EE2A8` · Peringatan `#F6D56E` · Bahaya `#FF6B6B` |
| Font | Big Shoulders (judul, angka skor), Inter (teks), JetBrains Mono (label), Playfair Display (sertifikat Prestise) |

Tema event (warna utama/aksen/mode) bisa menggantikan Bara/Samudra di layar event, TV, bracket, story, dan sertifikat.

## Pemetaan layar → rute → tugas

| Layar | Rute web | Tugas |
|---|---|---|
| `Main.dc.html` | `/` | T-130 |
| `Harga.dc.html` | `/harga` | T-061 |
| `Masuk.dc.html` | `/masuk?dari=…` | T-017 |
| `Upgrade.dc.html` | `/upgrade?pemicu=…` | T-061 |
| `EventBuilder.dc.html` | `/buat` | T-022, T-023 |
| `EventPage.dc.html` | `/e/:slug` | T-025, T-040 |
| `Admin.dc.html` | `/e/:slug/admin/*` | T-042–T-048, T-067, T-074 |
| `Jadwal.dc.html` | `/e/:slug/admin/jadwal` | T-053 |
| `Scoreboard.dc.html` | `/e/:slug/tv` dan `/e/:slug/tv/:court` | T-035 |
| `Mobile-Skor.dc.html` | `/e/:slug/w/:court` | T-034 |
| `AturanPoin.dc.html` | `/aturan` | T-038 |
| `Cup.dc.html` | `/e/:slug/bracket` | T-051 |
| `CupEsports.dc.html` | `/e/:slug/bracket` (format upper/lower) | T-100 |
| `Americano.dc.html` | `/e/:slug/americano` | T-101 |
| `KartuPemain.dc.html` | `/e/:slug/kartu` | T-091, T-092 |
| `KartuHasil.dc.html` | `/e/:slug/story/:matchId` | T-082, T-083 |
| `Sertifikat.dc.html` | `/e/:slug/admin/sertifikat` dan `/v/:code` | T-084–T-086 |
| `BagiTim.dc.html` | `/bagi-tim` | T-112 |
| `Mobile-Tim.dc.html` | `/bagi-tim/hasil` (tampilan HP) | T-112 |
| `Absen.dc.html` | `/grup/:id` | T-111 |
| `Rating.dc.html` | `/grup/:id/rating` | T-113 |
| `AdminPlatform.dc.html` | `/backoffice/*` | T-120–T-126 |
| `SistemDesain.dc.html` | — (referensi token & motion) | — |

## Data bersama antarlayar di demo

Di kanvas, layar berbagi data lewat `localStorage` untuk demo (`sbEventTheme`, `sbLastMatch`, `sbChamp`, `sbRsvp`, `sbRatings`). Di produksi semua data itu datang dari API; jangan meniru mekanisme `localStorage` ini kecuali untuk draf event tanpa login (T-021).
