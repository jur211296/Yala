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
import { GROUP_ENTITIES } from "../src/groups/manifest";
import { entityHash, hex, merkleRoot } from "../src/sync/merkle";

// Node expone `process` en runtime (vitest env node), pero el tsconfig del Worker no trae @types/node → declaración
// mínima type-only para leer la llave G7 del entorno (nunca inline: la llave JAMÁS commiteada).
declare const process: { env: Record<string, string | undefined> };

/** Root del canal 1 de un corpus VACÍO (las 5 tablas con entityHash de "" = sha256("")). Lo que ve un
 *  no-member (RLS filtra todas las tablas). Determinista — se recomputa con las MISMAS primitivas del Worker. */
async function emptyCorpusRoot(): Promise<string> {
  const eh = await entityHash([]); // sha256("")
  const map = new Map<string, Uint8Array>();
  for (const e of GROUP_ENTITIES) map.set(e, eh);
  return hex(await merkleRoot(map));
}

// Staging (mismo target que sync.goldens). Anon key + 2 JWTs de usuario; NUNCA service_role.
const URL = "https://fostjbbwstyuunmmefuk.supabase.co";
const ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg";

// G7: la llave de cifrado NO puede ir inline (la anon key SÍ — es pública). Se lee del entorno; el fail-fast vive
// en beforeAll (importar el archivo no debe lanzar — así el subset offline de la suite no se rompe).
const ENC_KEY = process.env.GROUPS_ENC_KEY ?? "";

const env = {
  ENVIRONMENT: "staging",
  ENFORCE: "observe",
  JWT_SIGNING_SECRET: "test-secret-please-change-0123456789",
  SUPABASE_URL: URL,
  SUPABASE_ANON_KEY: ANON,
  GROUPS_ENC_KEY: ENC_KEY,
  // OBLIGATORIO desde el kill-switch server-side: fail-closed (ausente → percent 0 → 403 en las 4 rutas
  // de `/groups/*`, incluido el «sin JWT → 401» de abajo, que pasaría a 403). Ver src/groups/killSwitch.ts.
  GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
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

// G7: los RPCs escritores de † exigen p_key (el gateway lo inyecta; este helper directo lo añade a mano).
const RPC_NEEDS_ENC_KEY = new Set([
  "create_group",
  "join_group",
  "update_member_display_name",
  "groups_forget_user",
]);

// --- RPC directo (setup de G1: create_group / invite / join / approve). JWT del caller + anon key. ---
async function rpc(jwt: string, fn: string, args: Record<string, unknown>): Promise<{ status: number; body: any }> {
  const finalArgs = RPC_NEEDS_ENC_KEY.has(fn) ? { ...args, p_key: ENC_KEY } : args;
  const res = await fetch(`${URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { apikey: ANON, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
    body: JSON.stringify(finalArgs),
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
    // G8 AJUSTE #1: handleGroupsPush accede a `c.executionCtx.waitUntil` (fan-out de push) cuando hay un delta
    // APPLIED — sin 3er arg, Hono LANZA "no ExecutionContext" → 500. En el runtime real el ctx SIEMPRE existe;
    // aquí un ctx no-op basta (estos goldens no ejercen el fan-out — eso es push.fanout.test.ts).
    { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext,
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
/**
 * G7: lectura DESCIFRADA de una fila de grupo vía el RPC lector (con p_key) — sustituye la lectura directa
 * PostgREST donde el
 * assert toca una columna † (post-cifrado un select=* directo vería bytea). El reader pagina por group_id +
 * server_seq → se filtra por identidad en JS. split_groups no lleva sync_id (una fila por grupo).
 */
async function readGroupRowDecrypted(jwt: string, entity: string, gid: string, syncId?: string): Promise<Record<string, unknown> | null> {
  const r = await rpc(jwt, `groups_pull_rows_${entity}`, { p_group_id: gid, p_after_seq: 0, p_limit: 1000, p_key: ENC_KEY });
  if (r.status !== 200 || !Array.isArray(r.body)) return null;
  const rows = r.body as Record<string, unknown>[];
  if (syncId === undefined) return rows[0] ?? null;
  const idKey = entity === "group_members" ? "member_key" : "sync_id";
  return rows.find((x) => x[idKey] === syncId) ?? null;
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

// Credenciales de los usuarios de test de staging: SOLO desde el entorno. NUNCA literales en el
// árbol — el repo es público y estuvieron en claro hasta el 2026-09-01 (ticket
// `staging-test-credentials-in-public-repo`). Se invoca DENTRO del beforeAll, nunca al importar:
// importar este fichero no debe lanzar, o se rompe el subset offline de la suite.
function testUser(letra: "A" | "B"): { email: string; password: string } {
  const email = process.env[`USER_${letra}_EMAIL`] ?? `i5-user-${letra.toLowerCase()}@test.yala`;
  const password = process.env[`USER_${letra}_PASS`] ?? "";
  if (!password) {
    throw new Error(
      `Falta USER_${letra}_PASS en el entorno — export USER_${letra}_PASS=<pass de staging> ` +
        `antes de npm test (ver qa/cloud/README.md)`,
    );
  }
  return { email, password };
}

beforeAll(async () => {
  if (!ENC_KEY) {
    throw new Error("G7: falta GROUPS_ENC_KEY en el entorno — export GROUPS_ENC_KEY=<staging key> antes de npm test");
  }
  const userA = testUser("A");
  const userB = testUser("B");
  jwtA = await login(userA.email, userA.password);
  jwtB = await login(userB.email, userB.password);
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
    // G7: amount es † → se lee descifrado (string decimal exacto escala-4 "30.0000"; Number("30.0000") === 30).
    const expRow = await readGroupRowDecrypted(jwtA, "split_expenses", gid, expId);
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

    // G7: note y amount son † → leer descifrado (byte-idéntico entre gemelos incl. amount "30.0000").
    const rx = await readGroupRowDecrypted(jwtA, "split_expenses", gid, twinX);
    const ry = await readGroupRowDecrypted(jwtA, "split_expenses", gid, twinY);
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
    // G7: amount/note son † → leer descifrado (el noop no re-cifra → after == before, server_seq/updated_at intactos).
    const before = await readGroupRowDecrypted(jwtA, "split_expenses", gid, expId);
    const second = await push(jwtA, batch);
    expect(second.body.results[0].status).toBe("noop");
    const after = await readGroupRowDecrypted(jwtA, "split_expenses", gid, expId);
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
    // G7: name es † → leer descifrado.
    const row = await readGroupRowDecrypted(jwtA, "split_groups", gid);
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
    // Nada se escribió (A no ve la fila del intruso). G7: note es † → el filtro server-side `note=eq.intruder`
    // ya no aplica sobre bytea; se lee vía el RPC lector (descifra) y se filtra por note en JS.
    const all = await rpc(jwtA, "groups_pull_rows_split_expenses", { p_group_id: gid, p_after_seq: 0, p_limit: 1000, p_key: ENC_KEY });
    const intruders = (Array.isArray(all.body) ? (all.body as Array<{ note?: unknown }>) : []).filter((x) => x.note === "intruder");
    expect(intruders.length).toBe(0);
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

  it("8. merkle autosuficiente: root ESTABLE sobre filas conocidas (2 fetches idénticos, != vacío) + no-member ve root de corpus VACÍO", async () => {
    // Grupo A-ONLY (create_group sin invitar): B NUNCA es member → RLS le oculta TODO.
    const gid = freshGid();
    const cg = await rpc(jwtA, "create_group", {
      p_group_id: gid,
      p_name: "G2 merkle-standalone",
      p_currency_code: "PEN",
      p_icon_name: "star",
      p_color_hex: "#445566",
      p_display_name: "Alice",
      p_default_split_type: "equal",
    });
    expect(cg.status).toBe(200);

    // Filas CONOCIDAS: un expense gmoney.
    const expId = uuid();
    const h = hlc(T0 + 800);
    const r = await push(jwtA, [
      { entity_type: "split_expenses", group_id: gid, sync_id: expId, op: "upsert", fields: { ...gmoney(42), expense_description: "Known" }, field_hlcs: { gmoney: h, expense_description: h }, hlc: h },
    ]);
    expect(r.body.results[0].status).toBe("applied");

    const empty = await emptyCorpusRoot();

    // A: root ESTABLE (2 fetches del mismo corpus == byte-idénticos) y NO vacío (tiene contenido).
    const mA1 = await merkle(jwtA, gid);
    const mA2 = await merkle(jwtA, gid);
    expect(mA1.root).toBe(mA2.root);
    expect(mA1.canon_version).toBe("c1");
    expect(Object.keys(mA1.entities).length).toBe(5);
    expect(mA1.entities.split_expenses.count).toBeGreaterThanOrEqual(1);
    expect(mA1.root).not.toBe(empty);

    // B (NO member): todas las tablas vacías por RLS → root == corpus vacío.
    const mB = await merkle(jwtB, gid);
    expect(mB.root).toBe(empty);
    for (const e of Object.values(mB.entities)) expect(e.count).toBe(0);
  }, 90_000);

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
    // G7: split_groups.name es † → leer vía el RPC lector (los flags no-† se sirven igual).
    const row = await readGroupRowDecrypted(jwtA, "split_groups", gid);
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

  // Golden 3-bis (G4-invites, C7): el invite COMPLETO del lado wire — is_group_writer transiciona con
  // status='active'. B en pendingApproval NO puede pushear; tras approve SÍ; el pull ve el grupo en
  // memberships + group_members con B active. Cubre lo que G3-2 (create_invite→join→approve, sin
  // pull ni write) NO cubría.
  it("3-bis. writer transiciona con status: B pendingApproval NO pushea; approve → active → pushea; pull ve membership+active", async () => {
    const gid = freshGid();
    const cg = await rpcGw(jwtA, "create_group", {
      p_group_id: gid, p_name: "G4 writer-transition", p_currency_code: "PEN", p_icon_name: "star",
      p_color_hex: "#112233", p_display_name: "Alice", p_default_split_type: "equal",
    });
    expect(cg.status).toBe(200);

    const inv = await rpcGw(jwtA, "create_group_invite", { p_group_id: gid, p_ttl_seconds: 3600, p_max_uses: null });
    expect(inv.status).toBe(200);
    const token = inv.body as string;

    const joined = await rpcGw(jwtB, "join_group", { p_token: token, p_display_name: "Bob", p_legacy_member_key: null });
    expect(joined.status).toBe(200);
    expect(joined.body.status).toBe("pendingApproval");
    const memberKeyB = joined.body.member_key as string;
    expect(memberKeyB).toBe(subB);

    // ASSERT CENTRAL 1: B en pendingApproval NO es writer → push de expense RECHAZADO (RLS is_group_writer).
    const hBefore = hlc(T0 + 700);
    const expId = uuid();
    const rBefore = await push(jwtB, [
      { entity_type: "split_expenses", group_id: gid, sync_id: expId, op: "upsert", fields: { ...gmoney(25), note: "pre-approve" }, field_hlcs: { gmoney: hBefore, note: hBefore }, hlc: hBefore, client_mutation_id: uuid() },
    ]);
    expect(rBefore.body.results[0].status).toBe("rejected");
    expect((rBefore.body.results[0].outcome as { message?: string })?.message ?? "").toContain("not_authorized");
    // Nada se escribió (A no ve la fila). G7: leer vía el RPC lector (sin fila → null).
    const noRow = await readGroupRowDecrypted(jwtA, "split_expenses", gid, expId);
    expect(noRow).toBeNull();

    // A aprueba → B pasa a active.
    const ap = await rpcGw(jwtA, "approve_member", { p_group_id: gid, p_member_key: memberKeyB });
    expect(ap.status).toBe(200);
    expect(ap.body.status).toBe("active");

    // B pull: el grupo en memberships + group_members con B status active.
    const p = await pull(jwtB, {});
    expect(p.memberships).toContain(gid);
    const meB = p.deltas
      .filter((d) => d.group_id === gid && d.entity_type === "group_members")
      .find((d) => d.sync_id === subB);
    expect(meB?.fields.status).toBe("active");
    expect(meB?.fields.display_name).toBe("Bob");

    // ASSERT CENTRAL 2: B ahora ES writer (status active) → el MISMO push queda APPLIED.
    const hAfter = hlc(T0 + 710);
    const rAfter = await push(jwtB, [
      { entity_type: "split_expenses", group_id: gid, sync_id: expId, op: "upsert", fields: { ...gmoney(25), note: "post-approve" }, field_hlcs: { gmoney: hAfter, note: hAfter }, hlc: hAfter, client_mutation_id: uuid() },
    ]);
    expect(rAfter.body.results[0].status).toBe("applied");
    // G7: note/amount son † → leer descifrado (amount "25.0000", Number === 25).
    const expRow = await readGroupRowDecrypted(jwtA, "split_expenses", gid, expId);
    expect(expRow?.sync_id).toBe(expId);
    expect(expRow?.note).toBe("post-approve");
    expect(Number(expRow?.amount)).toBe(25);
  }, 120_000);

  // g13_02 · A QUIEN RECHAZAN SE LE DICE. Hasta la policy `group_members_select_own_rejected`, la fila
  // de B pasaba a `rejected`, salía del filtro del pull y el cliente leía esa AUSENCIA como «el grupo
  // desapareció»: lo borraba sin una palabra, y a B le parecía que la app se había roto.
  //
  // Este golden prueba las DOS mitades, y la segunda es la que importa de verdad: que B vea SU fila y
  // NO la de A. Ampliar `is_group_member` habría hecho pasar la primera aserción y fallar la segunda —
  // le habría dado a B la lista completa de miembros de un grupo al que no le dejaron entrar.
  it("3-ter. rechazo visible: A rechaza a B; el pull de B trae SU fila 'rejected' y NINGUNA otra (g13_02)", async () => {
    const gid = freshGid();
    const cg = await rpcGw(jwtA, "create_group", {
      p_group_id: gid, p_name: "G13-02 rechazo", p_currency_code: "PEN", p_icon_name: "star",
      p_color_hex: "#445566", p_display_name: "Alice", p_default_split_type: "equal",
    });
    expect(cg.status).toBe(200);

    const inv = await rpcGw(jwtA, "create_group_invite", { p_group_id: gid, p_ttl_seconds: 3600, p_max_uses: null });
    expect(inv.status).toBe(200);
    const joined = await rpcGw(jwtB, "join_group", { p_token: inv.body as string, p_display_name: "Bob", p_legacy_member_key: null });
    expect(joined.status).toBe(200);
    expect(joined.body.status).toBe("pendingApproval");
    const memberKeyB = joined.body.member_key as string;

    // Control previo: en la sala de espera B ya ve el grupo. Sin esto, un pull vacío por cualquier otra
    // razón haría pasar las aserciones de abajo por el motivo equivocado.
    const before = await pull(jwtB, {});
    expect(before.memberships).toContain(gid);

    // A rechaza. `remove_member` deja 'rejected' porque el objetivo estaba pendingApproval.
    const rm = await rpcGw(jwtA, "remove_member", { p_group_id: gid, p_member_key: memberKeyB });
    expect(rm.status).toBe(200);
    expect(rm.body.status).toBe("rejected");

    const after = await pull(jwtB, {});

    // MITAD 1: el grupo sigue en la lista (no se esfuma) y B recibe su propia fila con el estado.
    expect(after.memberships).toContain(gid);
    const rows = after.deltas.filter((d) => d.group_id === gid && d.entity_type === "group_members");
    const meB = rows.find((d) => d.sync_id === memberKeyB);
    expect(meB?.fields.status).toBe("rejected");

    // MITAD 2, la decisión de seguridad: B ve SU fila y ninguna más. La policy está acotada por
    // `user_id` propio, así que la fila de A (owner, 'active') tiene que seguir invisible para B.
    expect(rows.length).toBe(1);
    expect(rows.every((d) => d.sync_id === memberKeyB)).toBe(true);
  }, 120_000);

  // g13_03 · EL GRUPO BORRADO DEJA DE CONFUNDIRSE CON UN ENLACE MUERTO. `join_group` colapsaba CINCO
  // causas en `yala_invalid_invite`, y el copy que las cubre a todas dice «pídele al admin que regenere
  // uno» — imposible de seguir si el grupo ya no existe: no hay admin ni enlace que regenerar.
  //
  // Las dos aserciones son igual de importantes. La primera es la funcional. La SEGUNDA protege el
  // no-oráculo: con un token INVENTADO el servidor sigue diciendo `yala_invalid_invite` y no revela
  // nada, porque el error nuevo solo se alcanza DESPUÉS de validar que el token existe, no está
  // revocado, no ha caducado y no está agotado. Quien lo recibe tenía un token real que alguien le dio.
  it("3-quater. grupo borrado ≠ enlace inválido: token válido → yala_group_deleted; token inventado → yala_invalid_invite (g13_03)", async () => {
    const gid = freshGid();
    const cg = await rpcGw(jwtA, "create_group", {
      p_group_id: gid, p_name: "G13-03 borrado", p_currency_code: "PEN", p_icon_name: "star",
      p_color_hex: "#778899", p_display_name: "Alice", p_default_split_type: "equal",
    });
    expect(cg.status).toBe(200);

    const inv = await rpcGw(jwtA, "create_group_invite", { p_group_id: gid, p_ttl_seconds: 3600, p_max_uses: null });
    expect(inv.status).toBe(200);
    const token = inv.body as string;

    // A borra el grupo (tombstone del meta ⇒ split_groups.deleted = true).
    //
    // El HLC va al FUTURO y no a `T0 + n` como el resto del archivo: `apply_group_delta` solo aplica el
    // tombstone si `p_row_hlc > v_row_hlc`, y la fila de `split_groups` ya existe con el `server_hlc()`
    // real de `create_group` — que es de HOY, muy por delante de T0 (15-jul-2026). Con un HLC del
    // pasado el tombstone sale `noop` y el grupo seguiría vivo, con lo que el test pasaría a medir otra
    // cosa. Medido: así es como falló la primera versión de este golden.
    const hDel = hlc(Date.now() + 3_600_000);
    const del = await push(jwtA, [
      { entity_type: "split_groups", group_id: gid, sync_id: null, op: "tombstone", fields: {}, field_hlcs: {}, hlc: hDel, client_mutation_id: uuid() },
    ]);
    expect(del.body.results[0].status).toBe("applied");

    // ASERCIÓN 1: con el token REAL de un grupo borrado, el servidor lo dice.
    const joinDeleted = await rpcGw(jwtB, "join_group", { p_token: token, p_display_name: "Bob", p_legacy_member_key: null });
    expect(joinDeleted.status).toBe(400);
    const codeDeleted = String((joinDeleted.body as { error?: { code?: string; message?: string } })?.error?.code
      ?? (joinDeleted.body as { error?: { message?: string } })?.error?.message ?? "");
    expect(codeDeleted).toContain("yala_group_deleted");

    // ASERCIÓN 2, la que protege el no-oráculo: un token que no existe sigue dando el error genérico.
    // Si algún día esto empieza a decir `yala_group_deleted`, se podría sondear qué tokens son válidos.
    const joinFake = await rpcGw(jwtB, "join_group", { p_token: `no-existe-${uuid()}`, p_display_name: "Bob", p_legacy_member_key: null });
    expect(joinFake.status).toBe(400);
    const codeFake = String((joinFake.body as { error?: { code?: string; message?: string } })?.error?.code
      ?? (joinFake.body as { error?: { message?: string } })?.error?.message ?? "");
    expect(codeFake).toContain("yala_invalid_invite");
    expect(codeFake).not.toContain("yala_group_deleted");
  }, 120_000);
});

// ============================================================================
// G7 goldens · cifrado pgcrypto de columnas de grupos (post-aplicación g7_01 + recrypt + g7_02)
// ============================================================================
describe("G7 goldens · pgcrypto encryption contra staging real", () => {
  it("g7-logging-settings: yala_logging_settings asserta el gate §16e (la llave nunca en logs)", async () => {
    const res = await fetch(`${URL}/rest/v1/rpc/yala_logging_settings`, {
      method: "POST",
      headers: { apikey: ANON, Authorization: `Bearer ${jwtA}`, "Content-Type": "application/json" },
      body: "{}",
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, string>;
    // Los 3 settings que garantizan que la llave (argumento de request) no aterrice en ningún log.
    expect(body.log_statement).toBe("ddl");
    expect(body.log_min_duration_statement).toBe("-1");
    expect(body.log_parameter_max_length_on_error).toBe("0");
  }, 30_000);

  it("g7-roundtrip: push amount/note → pull plaintext byte-igual (amount STRING escala-4); columna física cifrada; merkle estable", async () => {
    const { gid } = await setupGroup("g7-roundtrip");
    const expId = uuid();
    const h = hlc(T0 + 1000);
    const r = await push(jwtA, [
      {
        entity_type: "split_expenses",
        group_id: gid,
        sync_id: expId,
        op: "upsert",
        fields: { ...gmoney(30), note: "secreto-g7" },
        field_hlcs: { gmoney: h, note: h },
        hlc: h,
        client_mutation_id: uuid(),
      },
    ]);
    expect(r.body.results[0].status).toBe("applied");

    // Pull vía Worker: plaintext byte-igual + amount como STRING decimal exacto escala-4 (representación C1).
    const p = await pull(jwtA, {});
    const d = p.deltas.find((x) => x.group_id === gid && x.entity_type === "split_expenses" && x.sync_id === expId);
    expect(d).toBeTruthy();
    expect(d!.fields.amount).toBe("30.0000"); // STRING decimal exacto escala-4 (no número JS)
    expect(d!.fields.note).toBe("secreto-g7");
    expect(d!.fields.currency_code).toBe("PEN");

    // Lectura PostgREST DIRECTA de la columna FÍSICA: NO es plaintext (bytea/base64 ≠ el valor).
    const rawRes = await fetch(`${URL}/rest/v1/split_expenses?group_id=eq.${gid}&sync_id=eq.${expId}&select=amount,note`, {
      headers: { apikey: ANON, Authorization: `Bearer ${jwtA}` },
    });
    const rawRows = (await rawRes.json()) as Array<{ amount: unknown; note: unknown }>;
    expect(rawRows.length).toBe(1);
    const physAmount = String(rawRows[0].amount ?? "");
    const physNote = String(rawRows[0].note ?? "");
    expect(physAmount.length).toBeGreaterThan(0); // hay ciphertext
    expect(physAmount).not.toBe("30.0000");
    expect(physAmount).not.toBe("30");
    expect(physNote).not.toBe("secreto-g7");

    // Merkle estable entre 2 fetches del mismo corpus (byte-idénticos).
    const m1 = await merkle(jwtA, gid);
    const m2 = await merkle(jwtA, gid);
    expect(m1.root).toBe(m2.root);
    expect(m1.channel2_root).toBe(m2.channel2_root);
  }, 90_000);
});

/** Lectura DESCIFRADA de una fila group_members vía el RPC lector (display_name es † post-G7 → un select=*
 *  directo vería bytea). Filtra por member_key en JS (el reader pagina por group_id + server_seq). */
async function readMember(jwt: string, gid: string, memberKey: string): Promise<Record<string, unknown> | null> {
  const r = await rpc(jwt, "groups_pull_rows_group_members", { p_group_id: gid, p_after_seq: 0, p_limit: 1000, p_key: ENC_KEY });
  if (r.status !== 200 || !Array.isArray(r.body)) return null;
  return (r.body as Record<string, unknown>[]).find((x) => x.member_key === memberKey) ?? null;
}

// ============================================================================
// G10 goldens · transfer_group_ownership (D10 — batch "salir de todos mis grupos")
// ============================================================================
// ACTIVOS desde 2026-07-20 (commit a9ed3785), tras aplicar g10_01_transfer_group_ownership en staging.
// Corren contra STAGING con URL hard-codeada y MUTAN datos ⇒ `npm test` JAMÁS toca prod, y por tanto estos
// goldens NO verifican la promoción a prod (2026-07-21): esa se cubre con el precheck/post-check SQL
// documentados en qa/cloud/README §transfer_group_ownership.
//
// LIMITACIÓN CONOCIDA (2 users A/B en staging): el tie-break "admin-first + más-antiguo entre 2 herederos
// REALES" NO es E2E-testeable (solo A/B tienen JWT ⇒ como máximo UN co-member con user_id real además del
// owner, y group_members no admite UPDATE directo). Mitigación: el ORDER BY es copia
// byte-idéntica de groups_forget_user loop1 (g7_02:311-315, ya confiable). Con un 3er user, añadir un golden
// de ordenamiento.
describe("G10 goldens · transfer_group_ownership contra staging real (post-aplicación g10_01)", () => {
  it("1. owner con co-member elegible → transfiere al heredero; heredero promovido a admin; owner intacto (el leave lo hace el cliente); retry-transient → already", async () => {
    // setupGroup: A owner+admin, B joined+approved (active, user_id=subB, role=member, member_key=subB).
    const { gid } = await setupGroup("transfer-heir");

    const t = await rpcGw(jwtA, "transfer_group_ownership", { p_group_id: gid });
    expect(t.status).toBe(200);
    expect(t.body.transferred).toBe(true);
    expect(t.body.already).toBe(false);
    expect(t.body.reason).toBeNull();
    expect(t.body.new_owner_member_key).toBe(subB);

    // split_groups: owner ahora es B (owner_user_id=subB); grupo VIVO.
    const grp = await readGroupRowDecrypted(jwtA, "split_groups", gid);
    expect(grp?.owner_user_id).toBe(subB);
    expect(grp?.deleted).toBe(false);

    // B promovido a admin; A intacto (active — el leave lo ejecuta el orquestador batch DESPUÉS).
    const bM = await readMember(jwtA, gid, subB);
    expect(bM?.role).toBe("admin");
    expect(bM?.status).toBe("active");
    const aM = await readMember(jwtA, gid, subA);
    expect(aM?.status).toBe("active");

    // Retry-transient SEGURO: 2º call → ya no soy owner → already:true, sin re-transferir.
    const retry = await rpcGw(jwtA, "transfer_group_ownership", { p_group_id: gid });
    expect(retry.status).toBe(200);
    expect(retry.body.transferred).toBe(false);
    expect(retry.body.already).toBe(true);
    const grp2 = await readGroupRowDecrypted(jwtA, "split_groups", gid);
    expect(grp2?.owner_user_id).toBe(subB); // sin cambio
  }, 120_000);

  it("2. owner sin heredero elegible (co-member sin aprobar) → no_eligible_owner SIN tombstone; tercero intacto", async () => {
    // Fixture RE-SEMBRADO con RPCs vivos (la Fase 1 retiró del gateway el RPC de migración que fabricaba el
    // placeholder user_id NULL — ver qa/cloud/README §addendum 2026-07-28). El candidato exige
    // status='active' AND user_id IS NOT NULL, así que se ataca la OTRA rama inelegible del mismo predicado:
    // un co-member en pendingApproval. Sin atajo por UPDATE directo — group_members tiene el UPDATE revocado
    // para authenticated (g7_02, "FREEZE TOTAL de la unidad membership").
    const gid = freshGid();
    const cg = await rpcGw(jwtA, "create_group", {
      p_group_id: gid, p_name: "G10 noheir", p_currency_code: "PEN", p_icon_name: "star",
      p_color_hex: "#112233", p_display_name: "Alice", p_default_split_type: "equal",
    });
    expect(cg.status).toBe(200);
    const inv = await rpcGw(jwtA, "create_group_invite", { p_group_id: gid, p_ttl_seconds: 3600, p_max_uses: null });
    expect(inv.status).toBe(200);
    const joined = await rpcGw(jwtB, "join_group", { p_token: inv.body as string, p_display_name: "Bob", p_legacy_member_key: null });
    expect(joined.status).toBe(200);
    expect(joined.body.status).toBe("pendingApproval"); // NO se aprueba: sin 'active' no hay heredero elegible

    const t = await rpcGw(jwtA, "transfer_group_ownership", { p_group_id: gid });
    expect(t.status).toBe(200);
    expect(t.body.transferred).toBe(false);
    expect(t.body.already).toBe(false);
    expect(t.body.reason).toBe("no_eligible_owner");
    expect(t.body.new_owner_member_key).toBeNull();

    // INVARIANTE D10: JAMÁS tombstonea; owner intacto; el tercero (no elegible) intacto.
    const grp = await readGroupRowDecrypted(jwtA, "split_groups", gid);
    expect(grp?.owner_user_id).toBe(subA);
    expect(grp?.deleted).toBe(false);
    const pending = await readMember(jwtA, gid, subB);
    expect(pending?.status).toBe("pendingApproval");
    expect(pending?.user_id).toBe(subB);
  }, 120_000);

  it("3. caller no-owner (member activo) → already:true (no-op); owner intacto, sin auto-promoción", async () => {
    const { gid } = await setupGroup("transfer-nonowner");

    const t = await rpcGw(jwtB, "transfer_group_ownership", { p_group_id: gid });
    expect(t.status).toBe(200);
    expect(t.body.transferred).toBe(false);
    expect(t.body.already).toBe(true);

    const grp = await readGroupRowDecrypted(jwtA, "split_groups", gid);
    expect(grp?.owner_user_id).toBe(subA); // sin cambio
    const bM = await readMember(jwtA, gid, subB);
    expect(bM?.role).toBe("member"); // sin auto-promoción
  }, 120_000);
});
