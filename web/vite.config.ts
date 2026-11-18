import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Hanya dipakai untuk build. Tidak ada dev server: hasil build disajikan oleh api Go
// di produksi (ADR-0008). Lihat docs/RUNBOOK.md §2.
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: "dist",
    sourcemap: true,
  },
});
