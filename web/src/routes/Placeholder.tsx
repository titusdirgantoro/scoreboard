import { useEffect, useState } from "react";
import { Link, useLocation } from "react-router";
import { api } from "../lib/api";

interface Props {
  title: string;
  design: string;
  task: string;
}

/** Layar sementara: menunjukkan rute, berkas desain acuan, dan tugas yang akan membangunnya. */
export function Placeholder({ title, design, task }: Props) {
  const { pathname } = useLocation();
  const [status, setStatus] = useState("memeriksa…");

  useEffect(() => {
    api<{ version: string; env: string }>("/api/v1/meta")
      .then((m) => setStatus(`api ${m.env} · ${m.version}`))
      .catch(() => setStatus("api tidak terjangkau"));
  }, []);

  return (
    <main style={{ maxWidth: 880, margin: "0 auto", padding: "48px 24px", display: "grid", gap: 16 }}>
      <p className="sb-mono" style={{ margin: 0, fontSize: 12, color: "var(--sb-primary)" }}>
        SCOREBOARD.TIUSAPP.COM · {status.toUpperCase()}
      </p>
      <h1 className="sb-display" style={{ margin: 0, fontSize: 56 }}>
        {title}
      </h1>
      <p style={{ margin: 0, color: "var(--sb-text-2)", lineHeight: 1.6 }}>
        Rute <code>{pathname}</code> belum dibangun. Acuan desain: <code>docs/design/screens/{design}</code>. Dikerjakan di tugas{" "}
        <strong>{task}</strong> (<code>docs/TASKS.md</code>).
      </p>
      <nav style={{ display: "flex", flexWrap: "wrap", gap: 12 }}>
        <Link to="/">Beranda</Link>
        <Link to="/e/piala-jumat-malam-2026">Contoh halaman event</Link>
        <Link to="/e/piala-jumat-malam-2026/w/l1">Contoh remote wasit</Link>
      </nav>
    </main>
  );
}
