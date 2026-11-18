import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { BADMINTON_3X15, BADMINTON_3X21, parseRallies, rally, replayBadminton, newBadminton } from "./badminton";
import type { BadmintonFormat, Score, Side } from "./badminton";

interface Fixture {
  formats: Record<string, BadmintonFormat>;
  cases: Array<{
    name: string;
    format: string;
    firstServer: Side;
    rallies: string;
    expect: {
      games: Array<[number, number]>;
      gamesWon: Score;
      current: Score;
      server: Side;
      finished: boolean;
      winner: Side | "";
    };
  }>;
}

const fixturePath = fileURLToPath(new URL("../../../testdata/sportrules/badminton.json", import.meta.url));
const fx = JSON.parse(readFileSync(fixturePath, "utf8")) as Fixture;

describe("bulu tangkis — fixture bersama", () => {
  it("fixture tidak kosong", () => {
    expect(fx.cases.length).toBeGreaterThan(0);
  });

  for (const c of fx.cases) {
    it(c.name, () => {
      const f = fx.formats[c.format];
      if (!f) throw new Error(`format ${c.format} tidak ada`);
      const got = replayBadminton(f, c.firstServer, parseRallies(c.rallies));
      expect({
        games: got.games,
        gamesWon: got.gamesWon,
        current: got.current,
        server: got.server,
        finished: got.finished,
        winner: got.winner,
      }).toEqual(c.expect);
    });
  }

  it("format standar sama dengan fixture", () => {
    expect(fx.formats["3x21"]).toEqual(BADMINTON_3X21);
    expect(fx.formats["3x15"]).toEqual(BADMINTON_3X15);
  });

  it("rally tidak mengubah keadaan asal", () => {
    const s0 = newBadminton(BADMINTON_3X21, "A");
    const s1 = rally(s0, "B");
    expect(s0.current).toEqual({ a: 0, b: 0 });
    expect(s1.current).toEqual({ a: 0, b: 1 });
  });

  it("menolak token tidak valid", () => {
    for (const bad of ["C1", "A0", "Ax"]) expect(() => parseRallies(bad)).toThrow();
  });
});
