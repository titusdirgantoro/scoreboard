import { useMemo, useState } from "react";
import { BADMINTON_3X21, replayBadminton } from "@scoreboard/sportrules";
import type { Side } from "@scoreboard/sportrules";

/**
 * Demo kecil remote wasit (bulu tangkis) untuk membuktikan paket sportrules
 * terhubung ke web. Diganti layar penuh Mobile-Skor.dc.html di T-034
 * (token PIN, antrean offline, kirim ke server).
 */
export function RefereeDemo() {
  const [log, setLog] = useState<Side[]>([]);
  const st = useMemo(() => replayBadminton(BADMINTON_3X21, "A", log), [log]);

  const zone = (side: Side, name: string, color: string, pts: number, games: number) => (
    <button
      type="button"
      disabled={st.finished}
      onClick={() => setLog((l) => [...l, side])}
      aria-label={`Poin untuk ${name}`}
      style={{
        flex: 1,
        minHeight: 220,
        borderRadius: 24,
        border: `1px solid ${color}`,
        background: "var(--sb-surface-2)",
        color: "var(--sb-text)",
        display: "grid",
        placeItems: "center",
        gap: 4,
        cursor: "pointer",
      }}
    >
      <span className="sb-display" style={{ fontSize: 26 }}>
        {name} {st.server === side ? "· servis" : ""}
      </span>
      <span className="sb-display" style={{ fontSize: 140, color }}>
        {pts}
      </span>
      <span className="sb-mono" style={{ fontSize: 11, color: "var(--sb-text-2)" }}>
        GIM MENANG {games}
      </span>
    </button>
  );

  return (
    <main style={{ maxWidth: 420, margin: "0 auto", padding: 16, display: "flex", flexDirection: "column", gap: 10, minHeight: "100dvh" }}>
      <h1 className="sb-display" style={{ margin: "24px 0 0", fontSize: 28 }}>
        Remote wasit · demo
      </h1>
      <p className="sb-mono" style={{ margin: 0, fontSize: 11, color: "var(--sb-muted)" }}>
        BULU TANGKIS 3×21 · {st.finished ? `SELESAI — ${st.winner === "A" ? "BARA" : "SAMUDRA"} MENANG` : `GIM ${st.games.length + 1}`}
      </p>
      {zone("A", "Bara", "var(--sb-primary)", st.current.a, st.gamesWon.a)}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <button type="button" onClick={() => setLog((l) => l.slice(0, -1))} disabled={log.length === 0} style={{ minHeight: 44, padding: "0 14px" }}>
          Batal
        </button>
        <span className="sb-display" style={{ fontSize: 30 }}>
          {st.games.map((g) => `${g[0]}–${g[1]}`).join(" · ") || "0–0"}
        </span>
        <button type="button" onClick={() => setLog([])} style={{ minHeight: 44, padding: "0 14px" }}>
          Laga baru
        </button>
      </div>
      {zone("B", "Samudra", "var(--sb-accent)", st.current.b, st.gamesWon.b)}
    </main>
  );
}
