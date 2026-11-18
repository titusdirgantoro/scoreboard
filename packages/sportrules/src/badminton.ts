// Aturan bulu tangkis (reli poin). Harus berperilaku sama persis dengan
// internal/sportrules/badminton.go — keduanya diuji dengan
// testdata/sportrules/badminton.json (ADR-0004).

export type Side = "A" | "B";

export interface Score {
  a: number;
  b: number;
}

export interface BadmintonFormat {
  /** Poin untuk memenangkan gim (21 atau 15). */
  target: number;
  /** Skor yang langsung menang (30 atau 21). */
  cap: number;
  /** Jumlah gim maksimal (3). */
  bestOf: number;
}

/** Format standar BWF. 3×15 berlaku mulai 4 Januari 2027. */
export const BADMINTON_3X21: BadmintonFormat = { target: 21, cap: 30, bestOf: 3 };
export const BADMINTON_3X15: BadmintonFormat = { target: 15, cap: 21, bestOf: 3 };

export interface BadmintonState {
  readonly format: BadmintonFormat;
  /** Gim yang sudah selesai sebagai [a, b]. */
  readonly games: ReadonlyArray<readonly [number, number]>;
  readonly gamesWon: Score;
  readonly current: Score;
  readonly server: Side;
  readonly finished: boolean;
  /** "" selama laga belum selesai. */
  readonly winner: Side | "";
}

export function newBadminton(format: BadmintonFormat, firstServer: Side): BadmintonState {
  return {
    format,
    games: [],
    gamesWon: { a: 0, b: 0 },
    current: { a: 0, b: 0 },
    server: firstServer,
    finished: false,
    winner: "",
  };
}

function gameWon(f: BadmintonFormat, own: number, other: number): boolean {
  return own >= f.target && (own - other >= 2 || own >= f.cap);
}

/**
 * Keadaan setelah `winner` memenangkan satu reli. Pemenang reli melakukan
 * servis berikutnya; pemenang gim servis pertama di gim berikutnya.
 * Reli setelah laga selesai diabaikan.
 */
export function rally(s: BadmintonState, winner: Side): BadmintonState {
  if (s.finished) return s;
  const current: Score = winner === "A" ? { a: s.current.a + 1, b: s.current.b } : { a: s.current.a, b: s.current.b + 1 };
  const own = winner === "A" ? current.a : current.b;
  const other = winner === "A" ? current.b : current.a;
  if (!gameWon(s.format, own, other)) {
    return { ...s, current, server: winner };
  }
  const gamesWon: Score = winner === "A" ? { a: s.gamesWon.a + 1, b: s.gamesWon.b } : { a: s.gamesWon.a, b: s.gamesWon.b + 1 };
  const need = Math.floor(s.format.bestOf / 2) + 1;
  const finished = gamesWon.a >= need || gamesWon.b >= need;
  return {
    ...s,
    games: [...s.games, [current.a, current.b] as const],
    gamesWon,
    current: { a: 0, b: 0 },
    server: winner,
    finished,
    winner: finished ? winner : "",
  };
}

/** Bangun ulang keadaan dari log reli. */
export function replayBadminton(format: BadmintonFormat, firstServer: Side, rallies: readonly Side[]): BadmintonState {
  return rallies.reduce((st, r) => rally(st, r), newBadminton(format, firstServer));
}

/** Urai notasi fixture "A20 B20 A1" menjadi daftar reli. */
export function parseRallies(notation: string): Side[] {
  const out: Side[] = [];
  for (const tok of notation.trim().split(/\s+/).filter(Boolean)) {
    const side = tok.slice(0, 1).toUpperCase();
    if (side !== "A" && side !== "B") throw new Error(`token "${tok}": sisi harus A atau B`);
    const rest = tok.slice(1);
    const n = rest === "" ? 1 : Number(rest);
    if (!Number.isInteger(n) || n < 1) throw new Error(`token "${tok}": jumlah reli tidak valid`);
    for (let i = 0; i < n; i++) out.push(side);
  }
  return out;
}
