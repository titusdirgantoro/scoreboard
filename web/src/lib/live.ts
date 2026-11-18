// Klien siaran skor live (WebSocket) — protokol di docs/ARCHITECTURE.md §6.2.
// Endpoint server dibuat di T-033; klien ini sudah menangani sambung ulang dan versi.

export interface LiveMessage<T = unknown> {
  type: "snapshot";
  topic: string;
  v: number;
  data: T;
}

export interface LiveOptions {
  topics: string[];
  onMessage: (m: LiveMessage) => void;
  onStatus?: (s: "connecting" | "open" | "closed") => void;
}

const BACKOFF_MS = [500, 1000, 2000, 5000, 10000];

/** Berlangganan topik live. Mengembalikan fungsi untuk berhenti. */
export function subscribeLive({ topics, onMessage, onStatus }: LiveOptions): () => void {
  const latest = new Map<string, number>();
  let ws: WebSocket | null = null;
  let attempt = 0;
  let stopped = false;
  let timer: ReturnType<typeof setTimeout> | undefined;

  const connect = () => {
    if (stopped) return;
    onStatus?.("connecting");
    const proto = location.protocol === "https:" ? "wss" : "ws";
    ws = new WebSocket(`${proto}://${location.host}/ws/live?topics=${encodeURIComponent(topics.join(","))}`);
    ws.onopen = () => {
      attempt = 0;
      onStatus?.("open");
    };
    ws.onmessage = (ev) => {
      const m = JSON.parse(String(ev.data)) as LiveMessage;
      if (m.v < (latest.get(m.topic) ?? -1)) return; // abaikan versi lama
      latest.set(m.topic, m.v);
      onMessage(m);
    };
    ws.onclose = () => {
      onStatus?.("closed");
      if (stopped) return;
      const wait = BACKOFF_MS[Math.min(attempt, BACKOFF_MS.length - 1)] ?? 10000;
      attempt++;
      timer = setTimeout(connect, wait);
    };
  };

  connect();
  return () => {
    stopped = true;
    if (timer) clearTimeout(timer);
    ws?.close();
  };
}
