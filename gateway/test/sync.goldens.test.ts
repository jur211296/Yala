/**
 * Goldens de I6 — contra STAGING REAL (network ON). Ejercen el Worker end-to-end vía `app.fetch(...)`:
 * el handler verifica el JWT (ES256/JWKS), valida forma/invariante de emisión, gatea schema_version
 * por-columna, y llama al RPC `apply_delta`/`apply_pref` de PostgREST con el JWT del USUARIO (RLS).
 *
 * NO corren en CI (necesitan red + los 2 usuarios de test sembrados en I5). `sync_id`s ÚNICOS por run
 * (UUID fresco): NO hay cleanup posible (DELETE revocado por diseño). Ver qa/cloud/README.
 */
import { beforeAll, describe, expect, it } from "vitest";
import app from "../src/index";
import type { Env } from "../src/env";
import { setBreakingColumnsForTest } from "../src/sync/schemaGate";
import type { SyncPushResponse, SyncPullResponse, PrefsPullResponse } from "../src/sync/types";

// Staging (mismo target que qa/cloud/cross-user-rls-test.sh). Anon key + 2 JWTs de usuario; NUNCA service_role.
const URL = "https://fostjbbwstyuunmmefuk.supabase.co";
const ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg";

// Env de test: sin RATE_LIMITER (Durable Object no existe en node → el wiring lo omite), ENFORCE=observe.
const env = {
  ENVIRONMENT: "staging",
  ENFORCE: "observe",
  JWT_SIGNING_SECRET: "test-secret-please-change-0123456789",
  SUPABASE_URL: URL,
  SUPABASE_ANON_KEY: ANON,
} as unknown as Env;

let jwtA = "";
let jwtB = "";
let subA = "";

function decodeSub(jwt: string): string {
  let p = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
  p += "=".repeat((4 - (p.length % 4)) % 4);
  return (JSON.parse(atob(p)) as { sub: string }).sub;
}
async function login(email: string, password: string): Promise<string> {
  const res = await fetch(`${URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  const body = (await res.json()) as { access_token?: string };
  if (!body.access_token) throw new Error(`login ${email} failed: ${JSON.stringify(body)}`);
  return body.access_token;
}

// HLC canon c1: 46 chars `<T-CANON:24>-<counterHex:4>-<nodeID:16>` (ancho fijo → orden text = orden §d.3).
function hlc(ms: number, counter = 1, node = "aa"): string {
  const t = new Date(ms).toISOString(); // 24 chars, ms precision
  return `${t}-${counter.toString(16).padStart(4, "0")}-${node.padStart(16, "0")}`;
}
const T0 = Date.UTC(2026, 6, 7, 12, 0, 0);
function uuid(): string {
  return crypto.randomUUID();
}

async function push(jwt: string, deltas: unknown[]): Promise<{ status: number; body: SyncPushResponse }> {
  const res = await app.fetch(
    new Request("https://gw.local/sync/push", {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
      body: JSON.stringify({ deltas }),
    }),
    env,
  );
  return { status: res.status, body: (await res.json()) as SyncPushResponse };
}
async function pull(jwt: string, since = 0, limit = 1000): Promise<SyncPullResponse> {
  const res = await app.fetch(
    new Request(`https://gw.local/sync/pull?since=${since}&limit=${limit}`, {
      method: "GET",
      headers: { Authorization: `Bearer ${jwt}` },
    }),
    env,
  );
  return (await res.json()) as SyncPullResponse;
}
/** Lectura directa de una fila (para asserts sobre columnas server-side como field_hlcs). */
async function readRow(jwt: string, entity: string, syncId: string): Promise<Record<string, unknown> | null> {
  const res = await fetch(`${URL}/rest/v1/${entity}?sync_id=eq.${syncId}&select=*`, {
    headers: { apikey: ANON, Authorization: `Bearer ${jwt}` },
  });
  const rows = (await res.json()) as Record<string, unknown>[];
  return rows[0] ?? null;
}

const money = (amount: number, aip: number, rate: number, cur = "PEN", prov = false) => ({
  amount,
  amount_in_preferred_currency: aip,
  exchange_rate: rate,
  preferred_currency_code: cur,
  is_exchange_rate_provisional: prov,
});

beforeAll(async () => {
  jwtA = await login("i5-user-a@test.yala", "I5-Passw0rd-A!");
  jwtB = await login("i5-user-b@test.yala", "I5-Passw0rd-B!");
  subA = decodeSub(jwtA);
});

describe("I6 goldens · /sync/* contra staging real", () => {
  it("1. user_id SIEMPRE del JWT: un user_id ajeno en el payload se descarta; la fila queda del caller", async () => {
    const sid = uuid();
    const r = await push(jwtA, [
      {
        entity_type: "tx_items",
        sync_id: sid,
        op: "upsert",
        fields: { user_id: decodeSub(jwtB), note: "de A" }, // user_id ajeno inyectado
        field_hlcs: { note: hlc(T0 + 1) },
        hlc: hlc(T0 + 1),
        client_mutation_id: uuid(),
      },
    ]);
    expect(r.status).toBe(200);
    expect(r.body.results[0].status).toBe("applied"); // no rechazado — solo se descartó la columna
    const rowA = await readRow(jwtA, "tx_items", sid);
    expect(rowA?.user_id).toBe(subA); // la fila es de A, NO de B
    expect(rowA?.note).toBe("de A");
    const rowB = await readRow(jwtB, "tx_items", sid);
    expect(rowB).toBeNull(); // B no la ve (RLS)
  });

  it("2. PATCH FATAL-2: un edit de solo `note` preserva otra columna (subcategory_ref)", async () => {
    const sid = uuid();
    const sub = uuid();
    await push(jwtA, [
      {
        entity_type: "tx_items",
        sync_id: sid,
        op: "upsert",
        fields: { note: "orig", subcategory_ref: sub },
        field_hlcs: { note: hlc(T0 + 10), subcategory_ref: hlc(T0 + 10) },
        hlc: hlc(T0 + 10),
      },
    ]);
    const r = await push(jwtA, [
      {
        entity_type: "tx_items",
        sync_id: sid,
        op: "upsert",
        fields: { note: "editado" }, // solo note
        field_hlcs: { note: hlc(T0 + 20) },
        hlc: hlc(T0 + 20),
      },
    ]);
    expect(r.body.results[0].status).toBe("applied");
    const row = await readRow(jwtA, "tx_items", sid);
    expect(row?.note).toBe("editado");
    expect(row?.subcategory_ref).toBe(sub); // sobrevive — NO se puso a NULL
  });

  it("3. gate por-columna: edit de columna no-relacionada pasa; el de la columna reinterpretada se rechaza", async () => {
    setBreakingColumnsForTest([{ entity: "tx_items", column: "need_override", min_version: 5 }]);
    try {
      const sid = uuid();
      await push(jwtA, [
        {
          entity_type: "tx_items",
          sync_id: sid,
          op: "upsert",
          fields: { note: "base", need_override: "want" },
          field_hlcs: { note: hlc(T0 + 30), need_override: hlc(T0 + 30) },
          hlc: hlc(T0 + 30),
          schema_version: 5,
        },
      ]);
      // cliente viejo (schema_version 1) edita `note` (no-relacionada) → ACEPTADO
      const rNote = await push(jwtA, [
        {
          entity_type: "tx_items",
          sync_id: sid,
          op: "upsert",
          fields: { note: "note-viejo-ok" },
          field_hlcs: { note: hlc(T0 + 40) },
          hlc: hlc(T0 + 40),
          schema_version: 1,
        },
      ]);
      expect(rNote.body.results[0].status).toBe("applied");
      // cliente viejo edita la columna REINTERPRETADA → RECHAZADO
      const rBreaking = await push(jwtA, [
        {
          entity_type: "tx_items",
          sync_id: sid,
          op: "upsert",
          fields: { need_override: "need-viejo" },
          field_hlcs: { need_override: hlc(T0 + 50) },
          hlc: hlc(T0 + 50),
          schema_version: 1,
        },
      ]);
      expect(rBreaking.body.results[0].status).toBe("rejected");
      expect(rBreaking.body.results[0].reason).toContain("schema_version_too_old");
      const row = await readRow(jwtA, "tx_items", sid);
      expect(row?.note).toBe("note-viejo-ok");
      expect(row?.need_override).toBe("want"); // el edit rechazado NO tocó la columna
    } finally {
      setBreakingColumnsForTest(null);
    }
  });

  it("4. invariante de emisión: un delta con SOLO `amount` (grupo money parcial) → rechazado 422", async () => {
    const sid = uuid();
    const r = await push(jwtA, [
      {
        entity_type: "tx_items",
        sync_id: sid,
        op: "upsert",
        fields: { amount: 99.99 }, // grupo money incompleto
        field_hlcs: { money: hlc(T0 + 60) },
        hlc: hlc(T0 + 60),
      },
    ]);
    expect(r.body.results[0].status).toBe("rejected");
    expect(r.body.results[0].reason).toContain("coherence_group_partial");
    expect((r.body.results[0].outcome as { http?: number }).http).toBe(422);
    const row = await readRow(jwtA, "tx_items", sid);
    expect(row).toBeNull(); // no se escribió nada
  });

  it("5. delete-vs-upsert (ambos sentidos)", async () => {
    // (a) tombstone@H2 luego upsert@H1 → sigue borrada (no resucita)
    const sidA = uuid();
    await push(jwtA, [
      { entity_type: "tx_items", sync_id: sidA, op: "upsert", fields: { note: "vive" }, field_hlcs: { note: hlc(T0 + 70) }, hlc: hlc(T0 + 70) },
    ]);
    await push(jwtA, [{ entity_type: "tx_items", sync_id: sidA, op: "tombstone", hlc: hlc(T0 + 90) }]);
    const rStale = await push(jwtA, [
      { entity_type: "tx_items", sync_id: sidA, op: "upsert", fields: { note: "zombie" }, field_hlcs: { note: hlc(T0 + 80) }, hlc: hlc(T0 + 80) },
    ]);
    expect(rStale.body.results[0].status).toBe("noop");
    const rowA = await readRow(jwtA, "tx_items", sidA);
    expect(rowA?.deleted).toBe(true);
    expect(rowA?.note).toBe("vive");

    // (b) tombstone@H1 luego upsert@H2 → des-borrado deliberado
    const sidB = uuid();
    await push(jwtA, [
      { entity_type: "tx_items", sync_id: sidB, op: "upsert", fields: { note: "orig" }, field_hlcs: { note: hlc(T0 + 100) }, hlc: hlc(T0 + 100) },
    ]);
    await push(jwtA, [{ entity_type: "tx_items", sync_id: sidB, op: "tombstone", hlc: hlc(T0 + 110) }]);
    const rRevive = await push(jwtA, [
      { entity_type: "tx_items", sync_id: sidB, op: "upsert", fields: { note: "revivido" }, field_hlcs: { note: hlc(T0 + 120) }, hlc: hlc(T0 + 120) },
    ]);
    expect(rRevive.body.results[0].status).toBe("applied");
    const rowB = await readRow(jwtA, "tx_items", sidB);
    expect(rowB?.deleted).toBe(false);
    expect(rowB?.note).toBe("revivido");
  });

  it("6. convergencia orden-independiente (re-golden S-B6 G3): 2 filas gemelas, 5 deltas en 2 órdenes → estado idéntico", async () => {
    const twinX = uuid();
    const twinY = uuid();
    const mk = (sid: string) => [
      { entity_type: "tx_items", sync_id: sid, op: "upsert" as const, fields: { note: "n1" }, field_hlcs: { note: hlc(T0 + 200) }, hlc: hlc(T0 + 200) },
      { entity_type: "tx_items", sync_id: sid, op: "upsert" as const, fields: money(10, 40, 4, "PEN"), field_hlcs: { money: hlc(T0 + 210) }, hlc: hlc(T0 + 210) },
      { entity_type: "tx_items", sync_id: sid, op: "upsert" as const, fields: { note: "n3" }, field_hlcs: { note: hlc(T0 + 220) }, hlc: hlc(T0 + 220) },
      { entity_type: "tx_items", sync_id: sid, op: "upsert" as const, fields: money(99, 1, 1, "USD", true), field_hlcs: { money: hlc(T0 + 205) }, hlc: hlc(T0 + 205) }, // money stale
      { entity_type: "tx_items", sync_id: sid, op: "upsert" as const, fields: { note: "n2" }, field_hlcs: { note: hlc(T0 + 215) }, hlc: hlc(T0 + 215) }, // note stale vs n3
    ];
    const dX = mk(twinX);
    const dY = [...mk(twinY)].reverse();
    // Aplica cada delta por separado (una llamada por delta) para forzar órdenes de merge distintos.
    for (const d of dX) await push(jwtA, [d]);
    for (const d of dY) await push(jwtA, [d]);

    const rx = await readRow(jwtA, "tx_items", twinX);
    const ry = await readRow(jwtA, "tx_items", twinY);
    const norm = (r: Record<string, unknown> | null) => ({
      note: r?.note,
      amount: r?.amount,
      preferred_currency_code: r?.preferred_currency_code,
      is_exchange_rate_provisional: r?.is_exchange_rate_provisional,
      field_hlcs: r?.field_hlcs,
      hlc: r?.hlc,
    });
    expect(norm(rx)).toEqual(norm(ry)); // byte-idéntico incl. field_hlcs
    expect(rx?.note).toBe("n3"); // el note más nuevo gana
    expect(Number(rx?.amount)).toBe(10); // el money@210 gana sobre el stale@205
  });

  it("7. idempotencia de batch re-enviado: reenviar el mismo batch → todo NO-OP, estado intacto", async () => {
    const sid = uuid();
    const batch = [
      {
        entity_type: "tx_items",
        sync_id: sid,
        op: "upsert",
        fields: { note: "batch", ...money(5, 20, 4) },
        field_hlcs: { note: hlc(T0 + 300), money: hlc(T0 + 300) },
        hlc: hlc(T0 + 300),
        client_mutation_id: uuid(),
      },
    ];
    const first = await push(jwtA, batch);
    expect(first.body.results[0].status).toBe("applied");
    const before = await readRow(jwtA, "tx_items", sid);
    const second = await push(jwtA, batch);
    expect(second.body.results[0].status).toBe("noop");
    const after = await readRow(jwtA, "tx_items", sid);
    expect(after).toEqual(before); // server_seq/updated_at no cambian (NO-OP exacto)
  });

  it("8. prefs push/pull round-trip + LWW por key", async () => {
    const key = `pref-${uuid()}`;
    const push1 = await app.fetch(
      new Request("https://gw.local/prefs/push", {
        method: "POST",
        headers: { Authorization: `Bearer ${jwtA}`, "Content-Type": "application/json" },
        body: JSON.stringify({ prefs: [{ key, value: "v1", hlc: hlc(T0 + 400) }] }),
      }),
      env,
    );
    expect((await push1.json()) as unknown).toMatchObject({ results: [{ key, status: "applied" }] });

    // LWW: un hlc menor NO pisa
    const stale = await app.fetch(
      new Request("https://gw.local/prefs/push", {
        method: "POST",
        headers: { Authorization: `Bearer ${jwtA}`, "Content-Type": "application/json" },
        body: JSON.stringify({ prefs: [{ key, value: "stale", hlc: hlc(T0 + 390) }] }),
      }),
      env,
    );
    expect((await stale.json()) as { results: { status: string }[] }).toMatchObject({ results: [{ status: "noop" }] });

    const pullRes = await app.fetch(
      new Request("https://gw.local/prefs/pull?since=0", {
        method: "GET",
        headers: { Authorization: `Bearer ${jwtA}` },
      }),
      env,
    );
    const pulled = (await pullRes.json()) as PrefsPullResponse;
    const found = pulled.prefs.find((p) => p.key === key);
    expect(found?.value).toBe("v1"); // el stale NO ganó
  });

  it("9. pull de un tombstone expone deleted_hlc como hlc (árbitro row-level §d.4bis), no el hlc stale", async () => {
    const sid = uuid();
    const hAlive = hlc(T0 + 500);
    const hDead = hlc(T0 + 600); // > hAlive
    await push(jwtA, [
      { entity_type: "tx_items", sync_id: sid, op: "upsert", fields: { note: "vive" }, field_hlcs: { note: hAlive }, hlc: hAlive },
    ]);
    await push(jwtA, [{ entity_type: "tx_items", sync_id: sid, op: "tombstone", hlc: hDead }]);
    // La fila conserva hlc=hAlive (stale) pero deleted_hlc=hDead; el pull DEBE exponer hDead.
    const row = await readRow(jwtA, "tx_items", sid);
    expect(row?.hlc).toBe(hAlive);
    expect(row?.deleted_hlc).toBe(hDead);
    const seq = Number(row?.server_seq);
    const p = await pull(jwtA, seq - 1, 1000);
    const d = p.deltas.find((x) => x.sync_id === sid);
    expect(d?.op).toBe("tombstone");
    expect(d?.hlc).toBe(hDead); // NO hAlive — si no, un peer resucitaría con un upsert intermedio
  });

  it("10. grupo budget con uuid[] vacías como [] explícito → applied; Postgres persiste '{}' no NULL (DIFERIDOS #25 opción 1)", async () => {
    const sid = uuid();
    const subcatA = "aa000000-0000-0000-0000-000000000002";
    const h = hlc(T0 + 700);
    const r = await push(jwtA, [
      {
        entity_type: "budgets",
        sync_id: sid,
        op: "upsert",
        fields: {
          currency_code: "PEN",
          limit_amount: "500.0000",
          natures: null,
          subcategory_ids: [subcatA],
          account_ids: [], // vacía EN grupo → [] explícito (antes de #25 el codec la omitía → 422)
          tag_refs: [],
        },
        field_hlcs: { budget: h },
        hlc: h,
        client_mutation_id: uuid(),
      },
    ]);
    expect(r.status).toBe(200);
    expect(r.body.results[0].status).toBe("applied");
    // El RPC (jsonb_populate_record) traga []→uuid[] vacío: la columna queda '{}' (array vacío), NO NULL.
    const row = await readRow(jwtA, "budgets", sid);
    expect(row?.account_ids).toEqual([]);
    expect(row?.tag_refs).toEqual([]);
    expect(row?.subcategory_ids).toEqual([subcatA]);
    expect((row?.field_hlcs as Record<string, string>).budget).toBe(h);
  });

  it("merkle: 501 explícito hasta I8 (codec canon c1)", async () => {
    const res = await app.fetch(new Request("https://gw.local/sync/merkle", { headers: { Authorization: `Bearer ${jwtA}` } }), env);
    expect(res.status).toBe(501);
    expect((await res.json()) as unknown).toEqual({ available: false, reason: "merkle_requires_c1_codec" });
  });

  it("auth: sin JWT → 401", async () => {
    const res = await app.fetch(new Request("https://gw.local/sync/push", { method: "POST", body: "{}" }), env);
    expect(res.status).toBe(401);
  });

  it("pull devuelve las filas del caller ordenadas por server_seq (proyección al capability-set completo)", async () => {
    const p = await pull(jwtA, 0, 5);
    expect(Array.isArray(p.deltas)).toBe(true);
    for (let i = 1; i < p.deltas.length; i++) {
      expect(p.deltas[i].server_seq).toBeGreaterThanOrEqual(p.deltas[i - 1].server_seq);
    }
  });
});
