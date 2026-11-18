import { createBrowserRouter } from "react-router";
import { Placeholder } from "./routes/Placeholder";
import { RefereeDemo } from "./routes/RefereeDemo";

// Satu rute per layar desain (docs/design/README.md). Ganti <Placeholder> dengan
// layar sungguhan saat tugasnya dikerjakan.
const screen = (title: string, design: string, task: string) => <Placeholder title={title} design={design} task={task} />;

export const router = createBrowserRouter([
  { path: "/", element: screen("Beranda", "Main.dc.html", "T-130") },
  { path: "/harga", element: screen("Harga", "Harga.dc.html", "T-061") },
  { path: "/masuk", element: screen("Masuk", "Masuk.dc.html", "T-017") },
  { path: "/upgrade", element: screen("Upgrade", "Upgrade.dc.html", "T-061") },
  { path: "/buat", element: screen("Buat event", "EventBuilder.dc.html", "T-022") },
  { path: "/aturan", element: screen("Aturan poin", "AturanPoin.dc.html", "T-038") },
  { path: "/bagi-tim", element: screen("Bagi tim", "BagiTim.dc.html", "T-112") },
  { path: "/bagi-tim/hasil", element: screen("Hasil bagi tim (HP)", "Mobile-Tim.dc.html", "T-112") },
  { path: "/grup/:id", element: screen("Absen main bareng", "Absen.dc.html", "T-111") },
  { path: "/grup/:id/rating", element: screen("Rating pemain", "Rating.dc.html", "T-113") },
  { path: "/v/:code", element: screen("Cek sertifikat", "Sertifikat.dc.html", "T-084") },
  { path: "/backoffice/*", element: screen("Portal admin platform", "AdminPlatform.dc.html", "T-120") },
  {
    path: "/e/:slug",
    children: [
      { index: true, element: screen("Halaman event", "EventPage.dc.html", "T-025") },
      { path: "tv", element: screen("Papan skor TV", "Scoreboard.dc.html", "T-035") },
      { path: "tv/:court", element: screen("Papan skor TV", "Scoreboard.dc.html", "T-035") },
      { path: "w/:court", element: <RefereeDemo /> },
      { path: "bracket", element: screen("Bracket", "Cup.dc.html", "T-051") },
      { path: "americano", element: screen("Americano", "Americano.dc.html", "T-101") },
      { path: "kartu", element: screen("Kartu pemain", "KartuPemain.dc.html", "T-091") },
      { path: "story/:matchId", element: screen("Story hasil laga", "KartuHasil.dc.html", "T-082") },
      { path: "admin/jadwal", element: screen("Jadwal otomatis", "Jadwal.dc.html", "T-053") },
      { path: "admin/sertifikat", element: screen("E-sertifikat", "Sertifikat.dc.html", "T-085") },
      { path: "admin/*", element: screen("Panel penyelenggara", "Admin.dc.html", "T-042") },
    ],
  },
  { path: "*", element: screen("Halaman tidak ditemukan", "—", "—") },
]);
