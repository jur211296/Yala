/**
 * Rutas del Modo Nube (I6): `/sync/push`, `/sync/pull`, `/sync/merkle`, `/attest/bind`,
 * `/prefs/push`, `/prefs/pull`.
 *
 * Invariantes de seguridad (§2.3, §e.3):
 * - **`user_id` SIEMPRE del JWT verificado** (`sub`), NUNCA del body. Cualquier `user_id` en el
 *   payload se DESCARTA y se loguea. RLS de PostgREST es el árbitro final (reenviamos el JWT del
 *   usuario; jamás `service_role`).
 * - El upsert es PATCH column-by-column POR UNIDAD vía el RPC `apply_delta` (§d.4/§d.4bis), nunca
 *   un replace de fila.
 * - App Attest se reutiliza como venga (observe en staging): el token de sesión de attest va en un
 *   header SEPARADO (`X-Yala-Attest-Session`) porque `Authorization` transporta el JWT de Supabase.
 */
import type { Context } from "hono";
import type { Env } from "../env";
import { jsonError } from "../errors";
import { verifySessionToken, type SessionClaims } from "../attest/session";
import { gateRequest } from "../ratelimit";
import {
  bearerToken,
  callRpc,
  getRows,
  postgrestHeaders,
  verifyUserToken,
} from "./userauth";
import {
  SYNCABLE_ENTITIES,
  isSyncableEntity,
  nestFieldsByUnit,
  projectRowToDelta,
  resolveCapabilitySet,
  validateUpsertShape,
} from "./manifest";
import { checkSchemaGate } from "./schemaGate";
import type {
  PrefsPullResponse,
  PrefsPushRequest,
  PrefsPushResponse,
  PulledDelta,
  SyncDelta,
  SyncDeltaResult,
  SyncPullResponse,
  SyncPushRequest,
  SyncPushResponse,
} from "./types";

type Ctx = Context<{ Bindings: Env }>;

const SERVER_ONLY = new Set([
  "user_id",
  "server_seq",
  "hlc",
  "field_hlcs",
  "deleted",
  "deleted_hlc",
  "schema_version",
  "updated_at",
]);

interface AuthedUser {
  sub: string;
  userJWT: string;
  attest: SessionClaims | null;
}

/**
 * Auth compartida de las rutas de sync: usuario Supabase (obligatorio) + App Attest (observe en
 * staging) + rate-limit. Devuelve el usuario autenticado o una Response de error.
 */
async function requireUserAndAttest(c: Ctx): Promise<AuthedUser | Response> {
  const token = bearerToken(c.req.header("Authorization"));
  if (!token) return jsonError("yala_attest_required", "Falta el JWT de usuario (Authorization: Bearer).", 401);
  const user = await verifyUserToken(c.env, token);
  if (!user) return jsonError("yala_attest_invalid", "JWT de usuario inválido o expirado.", 401);

  // App Attest en header separado (Authorization ya lo ocupa el JWT de Supabase).
  const attestTok = bearerToken(c.req.header("X-Yala-Attest-Session")) ?? c.req.header("X-Yala-Attest-Session") ?? null;
  const attest = attestTok ? await verifySessionToken(c.env, attestTok) : null;
  const enforce = c.env.ENFORCE === "enforce";
  if (enforce && !attest) {
    return jsonError("yala_attest_required", "Falta el token de sesión de App Attest.", 401);
  }

  // Rate-limit: reusa el limiter existente (gateRequest). Bucket = keyId de attest si existe, si no
  // el `sub` del usuario. En un entorno sin Durable Object (tests) se omite (observe).
  if (c.env.RATE_LIMITER) {
    const claims: SessionClaims = attest ?? { keyId: `sub:${user.sub}`, tier: "free" };
    const blocked = await gateRequest(c.env, claims, "sync");
    if (blocked) return blocked;
  }

  return { sub: user.sub, userJWT: user.token, attest };
}

// --------------------------------------------------------------------------------------- /sync/push

export async function handleSyncPush(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  let body: SyncPushRequest;
  try {
    body = await c.req.json<SyncPushRequest>();
  } catch {
    return jsonError("yala_bad_request", "JSON inválido", 400);
  }
  if (!body || !Array.isArray(body.deltas)) {
    return jsonError("yala_bad_request", "Se espera { deltas: [] }", 400);
  }

  const results: SyncDeltaResult[] = [];
  for (const delta of body.deltas) {
    results.push(await applyOneDelta(c, auth, delta));
  }
  const resp: SyncPushResponse = { results };
  return c.json(resp);
}

async function applyOneDelta(c: Ctx, auth: AuthedUser, delta: SyncDelta): Promise<SyncDeltaResult> {
  const base: SyncDeltaResult = { sync_id: delta.sync_id, client_mutation_id: delta.client_mutation_id, status: "rejected" };

  if (!delta || typeof delta.sync_id !== "string" || typeof delta.entity_type !== "string") {
    return { ...base, reason: "malformed_delta" };
  }
  if (!isSyncableEntity(delta.entity_type)) {
    return { ...base, reason: `unknown_entity:${delta.entity_type}` };
  }

  // Descarta cualquier user_id (u otra columna server-only) del payload — NUNCA se confía en el body.
  const rawFields = (delta.fields ?? {}) as Record<string, unknown>;
  const leaked = Object.keys(rawFields).filter((k) => SERVER_ONLY.has(k) || k === "sync_id");
  if (leaked.length > 0) {
    // Metadata-only: qué columnas server-only intentó inyectar el cliente (nunca el valor).
    console.log(`[sync-push] descartando columnas no-escribibles del payload: ${leaked.join(",")} (${delta.entity_type})`);
    for (const k of leaked) delete rawFields[k];
  }

  const fieldHlcs = (delta.field_hlcs ?? {}) as Record<string, string>;
  const schemaVersion = typeof delta.schema_version === "number" ? delta.schema_version : 1;

  if (delta.op === "tombstone") {
    const rowHlc = delta.hlc;
    if (typeof rowHlc !== "string" || rowHlc.length === 0) {
      return { ...base, reason: "tombstone_sin_hlc" };
    }
    return callApplyDelta(c, auth, delta, {}, {}, rowHlc, schemaVersion, base);
  }

  // op === "upsert"
  // 1. Validación de forma + INVARIANTE DE EMISIÓN (grupo entero) contra el manifest.
  //
  // RESIDUAL ACEPTADO (owner 2026-07-07, decisión #1 tras review adversarial de I6): este guard es
  // el ÚNICO punto de enforcement del invariante de emisión, y es BYPASSEABLE — `apply_delta` tiene
  // GRANT EXECUTE TO authenticated, así que un usuario puede llamarlo directo por PostgREST con su
  // propio JWT y escribir un grupo de coherencia parcial (p.ej. `amount` sin recalcular las derivadas
  // → "número mal convertido"). El daño está CONFINADO a los datos del propio usuario (RLS + PK
  // compuesta (user_id, sync_id) impiden tocar filas ajenas); es corrupción de la propia coherencia,
  // NO una fuga cross-tenant. Aceptado porque (a) el modelo de confianza ya asume que el usuario puede
  // escribir datos raros a su cuenta (hoy mismo vía SwiftData local), y (b) endurecer el RPC con un
  // CHECK de membresía contradiría §d.4bis ("el RPC nunca conoce la membresía"). El cliente legítimo
  // (único en v1) siempre pasa por aquí. Reconsiderar si llega un 2º cliente con bug de emisión.
  const shape = validateUpsertShape(delta.entity_type, rawFields, fieldHlcs);
  if (shape) {
    if (shape.type === "coherence_group_partial") {
      // Canario cloudSyncCoherenceGroupPartial (§d.4bis/§j.4): >0 = write-site sin auditar.
      console.log(`[canary] cloudSyncCoherenceGroupPartial entity=${delta.entity_type} group=${shape.group ?? "?"} (${shape.detail})`);
      return {
        ...base,
        reason: `coherence_group_partial:${shape.group ?? shape.detail}`,
        outcome: { http: 422 },
      };
    }
    return { ...base, reason: `${shape.type}:${shape.detail}` };
  }

  // 2. Gate min_writable_version POR-COLUMNA (§d.2). Lista curada VACÍA hoy → nunca rechaza.
  const touched = Object.keys(rawFields);
  const gate = checkSchemaGate(delta.entity_type, touched, schemaVersion);
  if (gate) {
    return {
      ...base,
      reason: `schema_version_too_old:${gate.column} (min ${gate.min_version}, got ${gate.client_version})`,
    };
  }

  // 3. Re-agrupar fields por unidad para el RPC (el RPC no conoce la membresía columna→unidad).
  const nested = nestFieldsByUnit(delta.entity_type, rawFields);
  return callApplyDelta(c, auth, delta, nested, fieldHlcs, delta.hlc, schemaVersion, base);
}

async function callApplyDelta(
  c: Ctx,
  auth: AuthedUser,
  delta: SyncDelta,
  nestedFields: Record<string, Record<string, unknown>>,
  fieldHlcs: Record<string, string>,
  rowHlc: string,
  schemaVersion: number,
  base: SyncDeltaResult,
): Promise<SyncDeltaResult> {
  const { ok, status, body } = await callRpc(c.env, auth.userJWT, "apply_delta", {
    p_entity: delta.entity_type,
    p_sync_id: delta.sync_id,
    p_op: delta.op,
    p_fields: nestedFields,
    p_field_hlcs: fieldHlcs,
    p_row_hlc: rowHlc,
    p_schema_version: schemaVersion,
  });
  if (!ok) {
    // No logueamos el body (puede traer datos); solo status + sync_id.
    console.log(`[sync-push] apply_delta upstream ${status} sync_id=${delta.sync_id}`);
    return { ...base, status: "rejected", reason: `upstream_${status}`, outcome: redactUpstream(body) };
  }
  const outcome = body as { noop?: boolean } | null;
  const status2: SyncDeltaResult["status"] = outcome?.noop ? "noop" : "applied";
  return { ...base, status: status2, outcome };
}

/** Reduce un error de PostgREST a su código, sin arrastrar detalles con datos. */
function redactUpstream(body: unknown): unknown {
  if (body && typeof body === "object" && "code" in body) {
    return { code: (body as { code?: unknown }).code };
  }
  return undefined;
}

// --------------------------------------------------------------------------------------- /sync/pull

export async function handleSyncPull(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  const since = parseIntOr(c.req.query("since"), 0);
  const limit = clamp(parseIntOr(c.req.query("limit"), 500), 1, 1000);
  const cap = resolveCapabilitySet(c.req.header("X-Yala-Capability-Set") ?? c.req.query("capability_set") ?? null);

  // El eje de orden es un `server_seq` GLOBAL por-usuario (trigger stamp_server_seq). El pull hace
  // fan-out por tabla (RLS filtra a las filas del usuario), mezcla, ordena por server_seq y aplica el
  // límite GLOBAL. Correctness sobre perf para I6 (volumen personal); una view UNION es optimización I8.
  interface Raw {
    entity: string;
    row: Record<string, unknown>;
    server_seq: number;
  }
  const collected: Raw[] = [];
  for (const entity of SYNCABLE_ENTITIES) {
    const q = `select=*&server_seq=gt.${since}&order=server_seq.asc&limit=${limit}`;
    const { ok, status, rows } = await getRows(c.env, auth.userJWT, entity, q);
    if (!ok) {
      return jsonError("yala_unavailable", `pull upstream ${status} (${entity})`, 502);
    }
    for (const row of rows) {
      collected.push({ entity, row, server_seq: Number(row.server_seq) });
    }
  }
  collected.sort((a, b) => a.server_seq - b.server_seq);
  const page = collected.slice(0, limit);

  const deltas: PulledDelta[] = page.map(({ entity, row, server_seq }) => {
    const storedFh = (row.field_hlcs ?? {}) as Record<string, string>;
    const isDeleted = row.deleted === true;
    // Proyección (poda) al capability-set del cliente (E2E-C2), grupo-entero-o-nada.
    const { fields, field_hlcs } = projectRowToDelta(entity, row, storedFh, cap);
    return {
      entity_type: entity,
      sync_id: String(row.sync_id),
      op: isDeleted ? "tombstone" : "upsert",
      fields: isDeleted ? {} : fields,
      field_hlcs: isDeleted ? {} : field_hlcs,
      // Para un tombstone el árbitro row-level es `deleted_hlc` (§d.4bis), NO `hlc` (que queda
      // stale tras un update-tombstone: apply_delta pone deleted_hlc pero NO reescribe hlc). Enviar
      // `hlc` sub-valoraría el tombstone → un peer con un upsert local intermedio lo resucitaría.
      hlc: isDeleted ? String(row.deleted_hlc ?? row.hlc ?? "") : String(row.hlc ?? ""),
      server_seq,
      schema_version: Number(row.schema_version ?? 1),
    };
  });
  const maxSeq = page.length > 0 ? page[page.length - 1].server_seq : since;
  const resp: SyncPullResponse = { deltas, max_server_seq: maxSeq };
  return c.json(resp);
}

// ------------------------------------------------------------------------------------- /sync/merkle

export function handleSyncMerkle(c: Ctx): Response {
  // Frontera I6/I8 (§d.7 dos canales): la computación del árbol Merkle llega con el codec canon c1
  // en I8. Aquí es un 501 explícito y estable.
  return c.json({ available: false, reason: "merkle_requires_c1_codec" }, 501);
}

// ------------------------------------------------------------------------------------- /attest/bind

export async function handleAttestBind(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  let body: Record<string, unknown>;
  try {
    body = await c.req.json<Record<string, unknown>>();
  } catch {
    body = {};
  }
  // El keyId de confianza es el del attest-session verificado; el body es fallback (staging/QA).
  const keyId = auth.attest?.keyId ?? (typeof body.key_id === "string" ? body.key_id : null);
  if (!keyId) {
    return jsonError("yala_bad_request", "falta key_id (o token de sesión de App Attest)", 400);
  }
  const attestationType = typeof body.attestation_type === "string" ? body.attestation_type : "app_attest";
  const publicKey = typeof body.public_key === "string" ? body.public_key : null;
  if ("user_id" in body) {
    console.log("[attest-bind] descartando user_id del payload (se usa el sub del JWT)");
  }

  // Insert con user_id = sub (RLS WITH CHECK lo enforcea). UNIQUE(attestation_type,key_id) rechaza
  // robar un keyId de otro user (409). El re-bind del mismo dueño es un merge idempotente.
  const row: Record<string, unknown> = {
    user_id: auth.sub,
    key_id: keyId,
    attestation_type: attestationType,
    last_seen_at: new Date().toISOString(),
  };
  if (publicKey) row.public_key = `\\x${publicKey}`; // bytea hex (si el cliente lo manda base16)

  const res = await fetch(`${c.env.SUPABASE_URL}/rest/v1/attest_keys?on_conflict=user_id,key_id`, {
    method: "POST",
    headers: postgrestHeaders(c.env, auth.userJWT, { Prefer: "resolution=merge-duplicates,return=minimal" }),
    body: JSON.stringify(row),
  });
  if (res.status === 409) {
    return jsonError("yala_attest_invalid", "key_id ya vinculado a otra cuenta", 409);
  }
  if (!res.ok) {
    const status = res.status;
    console.log(`[attest-bind] upstream ${status}`);
    return jsonError("yala_unavailable", `bind upstream ${status}`, 502);
  }
  return c.json({ bound: true, key_id: keyId, attestation_type: attestationType });
}

// --------------------------------------------------------------------------- /prefs/push · /prefs/pull

export async function handlePrefsPush(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  let body: PrefsPushRequest;
  try {
    body = await c.req.json<PrefsPushRequest>();
  } catch {
    return jsonError("yala_bad_request", "JSON inválido", 400);
  }
  if (!body || !Array.isArray(body.prefs)) {
    return jsonError("yala_bad_request", "Se espera { prefs: [{key,value,hlc}] }", 400);
  }

  const results: PrefsPushResponse["results"] = [];
  for (const p of body.prefs) {
    if (!p || typeof p.key !== "string" || typeof p.hlc !== "string") {
      results.push({ key: String(p?.key ?? ""), status: "noop", reason: "malformed" });
      continue;
    }
    const { ok, status, body: out } = await callRpc(c.env, auth.userJWT, "apply_pref", {
      p_key: p.key,
      p_value: p.value ?? null,
      p_hlc: p.hlc,
    });
    if (!ok) {
      results.push({ key: p.key, status: "noop", reason: `upstream_${status}` });
      continue;
    }
    const applied = (out as { applied?: boolean } | null)?.applied === true;
    results.push({ key: p.key, status: applied ? "applied" : "noop" });
  }
  const resp: PrefsPushResponse = { results };
  return c.json(resp);
}

export async function handlePrefsPull(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  const since = parseIntOr(c.req.query("since"), 0);
  const q = `select=key,value,hlc,server_seq&server_seq=gt.${since}&order=server_seq.asc`;
  const { ok, status, rows } = await getRows(c.env, auth.userJWT, "user_preferences", q);
  if (!ok) return jsonError("yala_unavailable", `prefs pull upstream ${status}`, 502);

  const prefs = rows.map((r) => ({
    key: String(r.key),
    value: (r.value ?? null) as string | null,
    hlc: String(r.hlc ?? ""),
    server_seq: Number(r.server_seq ?? 0),
  }));
  const maxSeq = prefs.length > 0 ? prefs[prefs.length - 1].server_seq : since;
  const resp: PrefsPullResponse = { prefs, max_server_seq: maxSeq };
  return c.json(resp);
}

// --------------------------------------------------------------------------------------------- utils

function parseIntOr(v: string | undefined | null, fallback: number): number {
  if (v == null) return fallback;
  const n = Number.parseInt(v, 10);
  return Number.isFinite(n) ? n : fallback;
}
function clamp(n: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, n));
}
