// Klien API tipis. Setelah T-016, tipe request/response diambil dari
// web/src/lib/api-types.ts (dibangkitkan dari docs/api/openapi.yaml).

export interface ApiErrorBody {
  code: string;
  message: string;
  fields?: Record<string, string>;
  [extra: string]: unknown; // mis. trigger & upgrade untuk plan_limit
}

export class ApiError extends Error {
  readonly status: number;
  readonly body: ApiErrorBody;
  constructor(status: number, body: ApiErrorBody) {
    super(body.message);
    this.status = status;
    this.body = body;
  }
  /** Batas paket tercapai → buka layar Upgrade dengan pemicu ini. */
  get planTrigger(): string | null {
    return this.body.code === "plan_limit" && typeof this.body.trigger === "string" ? this.body.trigger : null;
  }
}

function csrfToken(): string {
  const m = document.cookie.match(/(?:^|;\s*)sb_csrf=([^;]+)/);
  return m?.[1] ? decodeURIComponent(m[1]) : "";
}

export async function api<T>(path: string, init: RequestInit & { json?: unknown } = {}): Promise<T> {
  const { json, headers, ...rest } = init;
  const h = new Headers(headers);
  h.set("Accept", "application/json");
  if (json !== undefined) h.set("Content-Type", "application/json");
  const method = (rest.method ?? "GET").toUpperCase();
  if (method !== "GET" && method !== "HEAD") h.set("X-CSRF-Token", csrfToken());

  const res = await fetch(path, {
    credentials: "same-origin",
    ...rest,
    method,
    headers: h,
    ...(json !== undefined ? { body: JSON.stringify(json) } : {}),
  });
  if (res.status === 204) return undefined as T;
  const data: unknown = await res.json().catch(() => null);
  if (!res.ok) {
    const body = (data as { error?: ApiErrorBody } | null)?.error ?? { code: "http_" + res.status, message: res.statusText };
    throw new ApiError(res.status, body);
  }
  return data as T;
}
