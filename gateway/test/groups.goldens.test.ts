/**
 * Goldens de G2 — canal de sync Grupos->backend, contra STAGING REAL (network ON). Ejercen el Worker
 * end-to-end vía `app.fetch(...)`: los handlers verifican el JWT (ES256/JWKS), validan forma/pull_only,
 * y llaman al RPC `apply_group_delta` (SECURITY INVOKER; RLS por membership + column grants).
 *
 * NO corren en CI (necesitan red + los 2 usuarios de test i5-user-a/b). `group_id`s ÚNICOS por corrida
 * (`g2-goldens-<ts>-<rand>`): sin cleanup (DELETE revocado por diseño). JAMÁS se llama groups_forget_user
 * (es DESTRUCTIVO global: transfiere/tombstonea TODOS los grupos del caller → rompería re-corridas que
 * comparten users A/B). Los 2 fallos PREEXISTENTES de account.goldens (cuenta B claimeada) NO son de G2.
 */
import { beforeAll, describe, expect, it } from "vitest";
import app from "../src/index";
import type { Env } from "../src/env";
import type { GroupPushResponse, GroupPullResponse, GroupMerkleResponse } from "../src/groups/types";

// Staging (mismo target que sync.goldens). Anon key + 2 JWTs de usuario; NUNCA service_role.
const URL = "https://fostjbbwstyuunmmefuk.supabase.co";
const ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg";

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
let subB = "";

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

// HLC canon c1: 46 chars `<T-CANON:24>-<counterHex:4>-<nodeID:16>`.
function hlc(ms: number, counter = 1, node = "aa"): string {
  const t = new Date(ms).toISOString();
  return `${t}-${counter.toString(16).padStart(4, "0")}-${node.padStart(16, "0")}`;
}
const T0 = Date.UTC(2026, 6, 15, 12, 0, 0);
function uuid(): string {
  return crypto.randomUUID();
}
function freshGid(): string {
  return `g2-goldens-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

// --- RPC directo (setup de G1: create_group / invite / join / approve). JWT del caller + anon key. ---
async function rpc(jwt: string, fn: string, args: Record<string, unknown>): Promise<{ status: number; body: any }> {
  const res = await fetch(`${URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { apikey: ANON, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
    body: JSON.stringify(args),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

// --- Endpoints del gateway (app.fetch local contra staging DB). ---
async function push(jwt: string, deltas: unknown[]): Promise<{ status: number; body: GroupPushResponse }> {
  const res = await app.fetch(
    new Request("https://gw.local/groups/push", {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
      body: JSON.stringify({ deltas }),
    }),
    env,
  );
  return { status: res.status, body: (await res.json()) as GroupPushResponse };
}
async function pull(jwt: string, cursors: Record<string, number> = {}, limit = 1000): Promise<GroupPullResponse> {
  const q = `cursors=${encodeURIComponent(JSON.stringify(cursors))}&limit=${limit}`;
  const res = await app.fetch(
    new Request(`https://gw.local/groups/pull?${q}`, { method: "GET", headers: { Authorization: `Bearer ${jwt}` } }),
    env,
  );
  return (await res.json()) as GroupPullResponse;
}
async function merkle(jwt: string, gid: string): Promise<GroupMerkleResponse> {
  const res = await app.fetch(
    new Request(`https://gw.local/groups/merkle?group_id=${gid}`, { method: "GET", headers: { Authorization: `Bearer ${jwt}` } }),
    env,
  );
  expect(res.status).toBe(200);
  return (await res.json()) as GroupMerkleResponse;
}
/** Lectura directa de una fila de grupo (PostgREST) — para assertar p_group_id/p_sync_id reales. */
async function readGroupRow(jwt: string, entity: string, gid: string, syncId?: string): Promise<Record<string, unknown> | null> {
  const q = syncId ? `group_id=eq.${gid}&sync_id=eq.${syncId}` : `group_id=eq.${gid}`;
  const res = await fetch(`${URL}/rest/v1/${entity}?${q}&select=*`, {
    headers: { apikey: ANON, Authorization: `Bearer ${jwt}` },
  });
  const rows = (await res.json()) as Record<string, unknown>[];
  return rows[0] ?? null;
}

/** Setup completo de un grupo: A crea + invita, B se une, A aprueba. Devuelve gid + member_keys. */
async function setupGroup(nameSuffix: string): Promise<{ gid: string }> {
  const gid = freshGid();
  const cg = await rpc(jwtA, "create_group", {
    p_group_id: gid,
    p_name: `G2 ${nameSuffix}`,
    p_currency_code: "PEN",
    p_icon_name: "star",
    p_color_hex: "#112233",
    p_display_name: "Alice",
    p_default_split_type: "equal",
  });
  expect(cg.status).toBe(200);
  const inv = await rpc(jwtA, "create_group_invite", { p_group_id: gid, p_ttl_seconds: 3600, p_max_uses: null });
  expect(inv.status).toBe(200);
  const token = inv.body as string;
  const joined = await rpc(jwtB, "join_group", { p_token: token, p_display_name: "Bob", p_legacy_member_key: null });
  expect(joined.status).toBe(200);
  const memberKeyB = joined.body.member_key as string;
  const ap = await rpc(jwtA, "approve_member", { p_group_id: gid, p_member_key: memberKeyB });
  expect(ap.status).toBe(200);
  return { gid };
}

const gmoney = (amount: number, cur = "PEN") => ({ amount, currency_code: cur });

beforeAll(async () => {
  jwtA = await login("i5-user-a@test.yala", "I5-Passw0rd-A!");
  jwtB = await login("i5-user-b@test.yala", "I5-Passw0rd-B!");
  subA = decodeSub(jwtA);
  subB = decodeSub(jwtB);
}, 30_000);

describe("G2 goldens · /groups/* contra staging real", () => {
  it("2. push A (expense gmoney + 2 shares gshare) → applied; pull B ve grupo/members/expense/shares con p_group_id/p_sync_id correctos", async () => {
    const { gid } = await setupGroup("push-pull");
    const expId = uuid();
    const shId1 = uuid();
    const shId2 = uuid();
    const h = hlc(T0 + 1);

    const r = await push(jwtA, [
      {
        entity_type: "split_expenses",
        group_id: gid,
        sync_id: expId,
        op: "upsert",
        fields: { ...gmoney(30), expense_description: "Dinner", date: "2026-07-15T12:00:00.000Z", paid_by_member_key: subA, split_type: "equal" },
        field_hlcs: { gmoney: h, expense_description: h, date: h, paid_by_member_key: h, split_type: h },
        hlc: h,
        client_mutation_id: uuid(),
      },
      { entity_type: "split_shares", group_id: gid, sync_id: shId1, op: "upsert", fields: { expense_id: expId, member_key: subA, amount: 15 }, field_hlcs: { gshare: h }, hlc: h, client_mutation_id: uuid() },
      { entity_type: "split_shares", group_id: gid, sync_id: shId2, op: "upsert", fields: { expense_id: expId, member_key: subB, amount: 15 }, field_hlcs: { gshare: h }, hlc: h, client_mutation_id: uuid() },
    ]);
    expect(r.status).toBe(200);
    expect(r.body.results.map((x) => x.status)).toEqual(["applied", "applied", "applied"]);

    // BODY assertion (lección d49d2e47): el gateway envió p_group_id/p_sync_id correctos → la fila los porta.
    const expRow = await readGroupRow(jwtA, "split_expenses", gid, expId);
    expect(expRow?.group_id).toBe(gid);
    expect(expRow?.sync_id).toBe(expId);
    expect(Number(expRow?.amount)).toBe(30);
    expect(expRow?.currency_code).toBe("PEN");
    expect((expRow?.field_hlcs as Record<string, string>).gmoney).toBe(h);

    // pull B (cursors {}): ve las 5 clases visibles + cursor + membership.
    const p = await pull(jwtB, {});
    expect(p.memberships).toContain(gid);
    expect(p.cursors[gid]).toBeGreaterThan(0);
    const forGid = p.deltas.filter((d) => d.group_id === gid);
    const byEntity = (e: string) => forGid.filter((d) => d.entity_type === e);
    expect(byEntity("split_groups").length).toBe(1);
    expect(byEntity("group_members").length).toBe(2); // A + B
    expect(byEntity("split_expenses").map((d) => d.sync_id)).toContain(expId);
    expect(byEntity("split_shares").map((d) => d.sync_id).sort()).toEqual([shId1, shId2].sort());

    // group_members se proyecta con identidad = member_key y user_id server-side.
    const meB = byEntity("group_members").find((d) => d.sync_id === subB);
    expect(meB?.fields.display_name).toBe("Bob");
    expect(meB?.fields.status).toBe("active");
    // el expense pulleado trae el gmoney entero.
    const expDelta = byEntity("split_expenses").find((d) => d.sync_id === expId);
    expect(expDelta?.op).toBe("upsert");
    expect(expDelta?.fields.currency_code).toBe("PEN");
    expect(expDelta?.field_hlcs.gmoney).toBe(h);
  }, 60_000);

  it("3. convergencia orden-independiente: 2 expenses gemelos, mismos deltas en órdenes inversos (A fwd, B rev) → byte-idénticos", async () => {
    const { gid } = await setupGroup("converge");
    const twinX = uuid();
    const twinY = uuid();
    const mk = (sid: string) => [
      { entity_type: "split_expenses", group_id: gid, sync_id: sid, op: "upsert" as const, fields: { note: "n1" }, field_hlcs: { note: hlc(T0 + 200) }, hlc: hlc(T0 + 200) },
      { entity_type: "split_expenses", group_id: gid, sync_id: sid, op: "upsert" as const, fields: gmoney(30, "PEN"), field_hlcs: { gmoney: hlc(T0 + 210) }, hlc: hlc(T0 + 210) },
      { entity_type: "split_expenses", group_id: gid, sync_id: sid, op: "upsert" as const, fields: { note: "n3" }, field_hlcs: { note: hlc(T0 + 220) }, hlc: hlc(T0 + 220) },
      { entity_type: "split_expenses", group_id: gid, sync_id: sid, op: "upsert" as const, fields: gmoney(99, "USD"), field_hlcs: { gmoney: hlc(T0 + 205) }, hlc: hlc(T0 + 205) }, // gmoney stale
      { entity_type: "split_expenses", group_id: gid, sync_id: sid, op: "upsert" as const, fields: { note: "n2" }, field_hlcs: { note: hlc(T0 + 215) }, hlc: hlc(T0 + 215) }, // note stale vs n3
    ];
    const dX = mk(twinX);
    const dY = [...mk(twinY)].reverse();
    for (const d of dX) await push(jwtA, [d]); // A, forward
    for (const d of dY) await push(jwtB, [d]); // B, reverse

    const rx = await readGroupRow(jwtA, "split_expenses", gid, twinX);
    const ry = await readGroupRow(jwtA, "split_expenses", gid, twinY);
    const norm = (r: Record<string, unknown> | null) => ({
      note: r?.note,
      amount: r?.amount,
      currency_code: r?.currency_code,
      field_hlcs: r?.field_hlcs,
      hlc: r?.hlc,
    });
    expect(norm(rx)).toEqual(norm(ry)); // byte-idéntico incl. field_hlcs
    expect(rx?.note).toBe("n3");
    expect(Number(rx?.amount)).toBe(30); // gmoney@210 gana sobre el stale@205
    expect(rx?.currency_code).toBe("PEN");
  }, 60_000);

  it("4. idempotencia: re-push del mismo batch → todo NO-OP, estado intacto", async () => {
    const { gid } = await setupGroup("idem");
    const expId = uuid();
    const h = hlc(T0 + 300);
    const batch = [
      {
        entity_type: "split_expenses",
        group_id: gid,
        sync_id: expId,
        op: "upsert",
        fields: { ...gmoney(42), note: "batch" },
        field_hlcs: { gmoney: h, note: h },
        hlc: h,
        client_mutation_id: uuid(),
      },
    ];
    const first = await push(jwtA, batch);
    expect(first.body.results[0].status).toBe("applied");
    const before = await readGroupRow(jwtA, "split_expenses", gid, expId);
    const second = await push(jwtA, batch);
    expect(second.body.results[0].status).toBe("noop");
    const after = await readGroupRow(jwtA, "split_expenses", gid, expId);
    expect(after).toEqual(before); // server_seq/updated_at intactos
  }, 60_000);

  it("5a. pull_only: push de group_members → rejected (pull_only), sin tocar la fila", async () => {
    const { gid } = await setupGroup("pullonly");
    const h = hlc(T0 + 400);
    const r = await push(jwtA, [
      { entity_type: "group_members", group_id: gid, sync_id: subA, op: "upsert", fields: { display_name: "hacked", role: "admin" }, field_hlcs: { display_name: h, role: h }, hlc: h },
    ]);
    expect(r.body.results[0].status).toBe("rejected");
    expect(r.body.results[0].reason).toContain("pull_only");
  }, 60_000);

  it("5b. split_groups: upsert de grupo INEXISTENTE → noop group_not_found (nace solo vía create_group)", async () => {
    const ghost = freshGid();
    const h = hlc(T0 + 410);
    const r = await push(jwtA, [
      { entity_type: "split_groups", group_id: ghost, sync_id: null, op: "upsert", fields: { name: "phantom" }, field_hlcs: { name: h }, hlc: h },
    ]);
    expect(r.body.results[0].status).toBe("noop");
    expect((r.body.results[0].outcome as { reason?: string })?.reason).toBe("group_not_found");
  }, 30_000);

  it("5c. split_groups: UPDATE de meta por el admin (p_sync_id=null) → applied; la fila cambia por group_id", async () => {
    const { gid } = await setupGroup("meta");
    const h = hlc(T0 + 420);
    const r = await push(jwtA, [
      { entity_type: "split_groups", group_id: gid, sync_id: null, op: "upsert", fields: { name: "Renamed Trip", is_archived: true }, field_hlcs: { name: h, is_archived: h }, hlc: h, client_mutation_id: uuid() },
    ]);
    expect(r.body.results[0].status).toBe("applied");
    const row = await readGroupRow(jwtA, "split_groups", gid);
    expect(row?.group_id).toBe(gid);
    expect(row?.name).toBe("Renamed Trip");
    expect(row?.is_archived).toBe(true);
    expect((row?.field_hlcs as Record<string, string>).name).toBe(h);
  }, 60_000);

  it("5d. not-writer: B empuja a un grupo del que NO es member → rejected not_authorized (RLS decide en silencio)", async () => {
    const gid = freshGid();
    // Grupo SOLO de A (B nunca se une).
    const cg = await rpc(jwtA, "create_group", {
      p_group_id: gid, p_name: "G2 A-only", p_currency_code: "PEN",
      p_icon_name: "star", p_color_hex: "#112233", p_display_name: "Alice", p_default_split_type: "equal",
    });
    expect(cg.status).toBe(200);
    const h = hlc(T0 + 430);
    const r = await push(jwtB, [
      { entity_type: "split_expenses", group_id: gid, sync_id: uuid(), op: "upsert", fields: { ...gmoney(10), note: "intruder" }, field_hlcs: { gmoney: h, note: h }, hlc: h },
    ]);
    expect(r.body.results[0].status).toBe("rejected");
    expect((r.body.results[0].outcome as { message?: string })?.message ?? "").toContain("not_authorized");
    // Nada se escribió (A no ve la fila del intruso).
    const rows = await fetch(`${URL}/rest/v1/split_expenses?group_id=eq.${gid}&note=eq.intruder&select=sync_id`, {
      headers: { apikey: ANON, Authorization: `Bearer ${jwtA}` },
    });
    expect(((await rows.json()) as unknown[]).length).toBe(0);
  }, 60_000);

  it("6. merkle: A y B ven el MISMO root del mismo grupo; el root cambia tras un write", async () => {
    const { gid } = await setupGroup("merkle");
    const expId = uuid();
    const h = hlc(T0 + 500);
    await push(jwtA, [
      { entity_type: "split_expenses", group_id: gid, sync_id: expId, op: "upsert", fields: { ...gmoney(20), note: "café" }, field_hlcs: { gmoney: h, note: h }, hlc: h },
    ]);

    const mA = await merkle(jwtA, gid);
    const mB = await merkle(jwtB, gid);
    expect(mA.canon_version).toBe("c1");
    expect(mA.group_id).toBe(gid);
    expect(Object.keys(mA.entities).length).toBe(5); // las 5 tablas SIEMPRE
    expect(mA.root).toBe(mB.root); // A y B convergen sobre el mismo corpus visible
    expect(mA.channel2_root).toBe(mB.channel2_root);

    // Un write cambia el root.
    const h2 = hlc(T0 + 510);
    await push(jwtA, [
      { entity_type: "split_expenses", group_id: gid, sync_id: expId, op: "upsert", fields: { note: "editado" }, field_hlcs: { note: h2 }, hlc: h2 },
    ]);
    const mA2 = await merkle(jwtA, gid);
    expect(mA2.root).not.toBe(mA.root);
    expect(mA2.entities.split_expenses.count).toBe(mA.entities.split_expenses.count);
  }, 90_000);

  it("7. paginación: pull limit=1 partiendo del baseline recorre los 3 expenses nuevos del gid sin duplicar; página vacía = done, cursor no avanza", async () => {
    const { gid } = await setupGroup("paginate");

    // Baseline: siembra el max de TODOS los grupos históricos de A (incl. meta+members del gid nuevo).
    // A partir de aquí, lo ÚNICO nuevo del gid serán los 3 expenses que empujamos.
    const baseline = (await pull(jwtA, {}, 1000)).cursors;

    // Push de 3 expenses al gid (sync_ids distintos).
    const expIds = [uuid(), uuid(), uuid()];
    const h = hlc(T0 + 600);
    for (const sid of expIds) {
      const r = await push(jwtA, [
        { entity_type: "split_expenses", group_id: gid, sync_id: sid, op: "upsert", fields: { ...gmoney(11), note: "paginate" }, field_hlcs: { gmoney: h, note: h }, hlc: h, client_mutation_id: uuid() },
      ]);
      expect(r.body.results[0].status).toBe("applied");
    }

    // Iterar pull con limit=1 partiendo del baseline. Cada página trae ≤1 delta DEL gid.
    let cursors: Record<string, number> = { ...baseline };
    const collected = new Set<string>();
    let iterations = 0;
    for (; iterations < 15; iterations++) {
      const p = await pull(jwtA, cursors, 1);
      const forGid = p.deltas.filter((d) => d.group_id === gid);
      expect(forGid.length).toBeLessThanOrEqual(1);
      for (const d of forGid) if (d.entity_type === "split_expenses") collected.add(d.sync_id as string);
      cursors = { ...cursors, ...p.cursors };
      if (forGid.length === 0) break; // página vacía POR GRUPO = terminación del cliente
    }
    expect(iterations).toBeLessThan(15); // no se agotó el cap → terminó por página vacía

    // La unión recolectada == los 3 esperados, sin duplicados (el Set ya garantiza unicidad).
    expect(collected.size).toBe(3);
    expect([...collected].sort()).toEqual([...expIds].sort());

    // Pull final de confirmación: 0 deltas del gid y el cursor del gid no avanza respecto al acumulado.
    const cursorAtDone = cursors[gid];
    const confirm = await pull(jwtA, cursors, 1);
    expect(confirm.deltas.filter((d) => d.group_id === gid).length).toBe(0);
    const confirmCursor = confirm.cursors[gid];
    if (confirmCursor !== undefined) expect(confirmCursor).toBe(cursorAtDone); // ausente o sin avance
  }, 360_000); // 6 pulls (baseline + 4 loop + confirm): A acumula 76+ grupos históricos (sin cleanup por diseño). Con el fan-out paralelo del pull (pool de 6 grupos × 5 tablas) cada pull baja de ~42s a segundos; el timeout holgado queda como red.

  it("auth: sin JWT → 401 en push/pull/merkle", async () => {
    const rPush = await app.fetch(new Request("https://gw.local/groups/push", { method: "POST", body: "{}" }), env);
    expect(rPush.status).toBe(401);
    const rPull = await app.fetch(new Request("https://gw.local/groups/pull"), env);
    expect(rPull.status).toBe(401);
    const rMerkle = await app.fetch(new Request("https://gw.local/groups/merkle?group_id=whatever8"), env);
    expect(rMerkle.status).toBe(401);
  });
});

// --- Endpoint del gateway para los RPCs de membresía (G3): POST /groups/rpc/:fn. ---
async function rpcGw(jwt: string | null, fn: string, body: unknown): Promise<{ status: number; body: any }> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (jwt) headers.Authorization = `Bearer ${jwt}`;
  const res = await app.fetch(
    new Request(`https://gw.local/groups/rpc/${fn}`, { method: "POST", headers, body: JSON.stringify(body ?? {}) }),
    env,
  );
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

describe("G3 goldens · /groups/rpc/* contra staging real", () => {
  it("1. create_group vía gateway → 200 {group_id, member_key==sub}; meta completa (simplify/show/members_can_invite) escrita", async () => {
    const gid = freshGid();
    // Los 3 params nuevos (A3, g3_01) con valores NO-default (true) para probar que el gateway los pasa.
    const cg = await rpcGw(jwtA, "create_group", {
      p_group_id: gid,
      p_name: "G3 create",
      p_currency_code: "PEN",
      p_icon_name: "star",
      p_color_hex: "#112233",
      p_display_name: "Alice",
      p_default_split_type: "equal",
      p_simplify_debts: true,
      p_show_debts_in_single_currency: true,
      p_members_can_invite: true,
    });
    expect(cg.status).toBe(200);
    expect(cg.body.group_id).toBe(gid);
    expect(cg.body.member_key).toBe(subA); // member_key == sub del JWT (auth.uid())

    // BODY assertion (lección d49d2e47): la fila porta los 3 flags NO-null con los valores enviados.
    const row = await readGroupRow(jwtA, "split_groups", gid);
    expect(row?.group_id).toBe(gid);
    expect(row?.simplify_debts).toBe(true);
    expect(row?.show_debts_in_single_currency).toBe(true);
    expect(row?.members_can_invite).toBe(true);
  }, 60_000);

  it("2. flujo invite vía gateway: create_group_invite → token; join_group(B) pendingApproval; approve_member(A) active", async () => {
    const gid = freshGid();
    const cg = await rpcGw(jwtA, "create_group", {
      p_group_id: gid, p_name: "G3 invite", p_currency_code: "PEN", p_icon_name: "star",
      p_color_hex: "#112233", p_display_name: "Alice", p_default_split_type: "equal",
    });
    expect(cg.status).toBe(200);

    const inv = await rpcGw(jwtA, "create_group_invite", { p_group_id: gid, p_ttl_seconds: 3600, p_max_uses: null });
    expect(inv.status).toBe(200);
    // create_group_invite devuelve el token como JSON string escalar (no objeto).
    expect(typeof inv.body).toBe("string");
    const token = inv.body as string;

    const joined = await rpcGw(jwtB, "join_group", { p_token: token, p_display_name: "Bob", p_legacy_member_key: null });
    expect(joined.status).toBe(200);
    expect(joined.body.status).toBe("pendingApproval");
    expect(joined.body.rebound).toBe(false);
    const memberKeyB = joined.body.member_key as string;
    expect(memberKeyB).toBe(subB);

    const ap = await rpcGw(jwtA, "approve_member", { p_group_id: gid, p_member_key: memberKeyB });
    expect(ap.status).toBe(200);
    expect(ap.body.status).toBe("active");
  }, 90_000);

  it("3. error preservado: join_group con token falso → 400 y error.code == yala_invalid_invite", async () => {
    const bad = await rpcGw(jwtB, "join_group", { p_token: "deadbeefdeadbeef", p_display_name: "Bob", p_legacy_member_key: null });
    expect(bad.status).toBe(400);
    expect(bad.body.error.type).toBe("yala_rpc_error");
    expect(bad.body.error.code).toBe("yala_invalid_invite");
    expect(bad.body.error.message).toBe("yala_invalid_invite");
  }, 30_000);

  it("4. allowlist: fake_fn → 404; apply_group_delta (solo va por /groups/push) → 404", async () => {
    const fake = await rpcGw(jwtA, "fake_fn", {});
    expect(fake.status).toBe(404);
    const agd = await rpcGw(jwtA, "apply_group_delta", { p_entity: "split_expenses" });
    expect(agd.status).toBe(404);
  }, 30_000);

  it("5. param extra descartado: create_group con args basura/user_id inyectado → 200; member_key sigue siendo el sub", async () => {
    const gid = freshGid();
    const cg = await rpcGw(jwtA, "create_group", {
      p_group_id: gid, p_name: "G3 extra", p_currency_code: "PEN", p_icon_name: "star",
      p_color_hex: "#112233", p_display_name: "Alice", p_default_split_type: "equal",
      // Params desconocidos: se descartan silenciosamente (sin PGRST202) y NUNCA se inyectan.
      p_garbage: "should-be-dropped", user_id: "00000000-0000-0000-0000-000000000000", sub: "injected",
    });
    expect(cg.status).toBe(200);
    expect(cg.body.group_id).toBe(gid);
    expect(cg.body.member_key).toBe(subA); // el sub del JWT, NO el user_id inyectado
  }, 60_000);

  it("6. sin JWT → 401", async () => {
    const res = await app.fetch(
      new Request("https://gw.local/groups/rpc/create_group", { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" }),
      env,
    );
    expect(res.status).toBe(401);
  });
});
