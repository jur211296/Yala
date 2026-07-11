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
  manifest,
  nestFieldsByUnit,
  projectRowToDelta,
  resolveCapabilitySet,
  validateUpsertShape,
} from "./manifest";
import { CanonError, canonRowC1, merkleColumns } from "./canon";
import { entityHash, hex, leafChannel1, leafChannel2, merkleRoot } from "./merkle";
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

  // Enforcement del freeze de la reversa (§h.1 — cierre del DIFERIDO de qa/cloud/README): con
  // `profiles.reverse_frozen_at` estampado (`reverse_freeze`) el backend DEJÓ de ser fuente de verdad
  // (y sigue congelado tras `reverse_complete` — red §h.4, hasta un re-cutover futuro). Decisiones:
  //   - REQUEST-level (409 `yala_account_reverting`), NO per-delta: un `rejected` por-delta
  //     dead-letterearía en el cliente filas legítimas que deben sobrevivir en el outbox para la
  //     adopción/reversa de ese device (y meter el guard en `apply_delta` = per-delta + migración SQL).
  //   - COSTO CERO de pared para el push normal: el check (1 GET a la fila propia de `profiles`, RLS/PK,
  //     POR REQUEST) se dispara EN PARALELO con el primer `apply_delta` y se gatea antes del 2º delta y
  //     antes de responder — medido secuencial costaba +~160ms/request (el motivo original del diferido).
  //   - LEAK ACOTADO documentado: el delta[0] puede aterrizar en el backend congelado (y el batch entero
  //     en el caso 1-delta). Benigno por diseño: apply HLC-idempotente, el backend congelado JAMÁS vuelve
  //     a ser fuente de verdad (la reversa dejó de pullear ANTES del freeze), y el 409 hace que el
  //     cliente pare SIN purgar → convergencia intacta. El freeze tiene TOCTOU inherente de todos modos
  //     (un push en vuelo cuando cae el freeze también aterriza). La propia reversa no se auto-bloquea:
  //     todos sus pushes (`reverseDrainOnce`) ocurren ANTES de `reverse_freeze`.
  //   - Fail-closed: check upstream caído → 502 (cliente → transient/backoff; el batch ya aplicado se
  //     re-pushea noop-idempotente).
  // El .catch normaliza un reject de red a !ok (fail-closed 502) — sin él, un throw del fetch mientras
  // la promesa corre en la sombra del apply sería un unhandled rejection.
  const frozenCheck = getRows(c.env, auth.userJWT, "profiles", "select=reverse_frozen_at&reverse_frozen_at=not.is.null&limit=1")
    .catch(() => ({ ok: false as const, status: 0, rows: [] as Record<string, unknown>[], body: null as unknown }));
  const rejectReverting = (): Response => {
    // Metadata-only: el sub ya viaja en logs de auth; ningún dato de usuario.
    console.log("[sync-push] rechazado 409: cuenta en reversa (reverse_frozen_at set)");
    return jsonError("yala_account_reverting", "La cuenta está en reversa a iCloud (backend congelado, §h.1) — push rechazado.", 409);
  };

  const results: SyncDeltaResult[] = [];
  let frozen: Awaited<typeof frozenCheck> | null = null;
  for (const delta of body.deltas) {
    if (results.length > 0) {
      // Gate antes del 2º delta en adelante: el check ya corrió en la sombra del apply anterior.
      frozen ??= await frozenCheck;
      if (frozen.ok && frozen.rows.length > 0) return rejectReverting();
    }
    results.push(await applyOneDelta(c, auth, delta));
  }
  frozen ??= await frozenCheck;
  if (!frozen.ok) {
    return jsonError("yala_unavailable", `freeze check upstream ${frozen.status}`, 502);
  }
  if (frozen.rows.length > 0) return rejectReverting();

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

/**
 * GET /sync/merkle (I8f-3, §d.7 dos canales). Fan-out por las 16 tablas con el select construido del
 * manifest (NUMERIC casteado a `::text` — NUNCA confiar en el padding de PostgREST; el re-serializador
 * re-cuantiza con aritmética string/BigInt), re-serializa cada fila con `canon.ts` (proyectada al
 * capability-set EXPLÍCITO de la request, grupo-entero-o-nada; `local_day` excluida — A-2b) y computa
 * leaves/entityHash/root (regla A-4). El Canal 1 EXCLUYE `deleted=true` (A-2: el cliente no tiene fila
 * local que hashear para un tombstone aplicado); el Canal 2 (interno, informativo) las incluye.
 * Buckets POR ENTIDAD (A-1): el trie fino por-sync_id queda diferido; la remediación v1 del cliente es
 * re-pull completo de la tabla divergente.
 */
export async function handleSyncMerkle(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  const rawCap = c.req.header("X-Yala-Capability-Set") ?? c.req.query("capability_set") ?? null;
  const cap = resolveCapabilitySet(rawCap);

  const channel1 = new Map<string, Uint8Array>();
  const channel2 = new Map<string, Uint8Array>();
  const entities: Record<string, { count: number; hash: string }> = {};

  try {
    for (const entity of SYNCABLE_ENTITIES) {
      const columns = merkleColumns(entity, cap);
      const select = merkleSelect(entity, columns);
      const leaves1: Array<{ syncId: string; leaf: Uint8Array }> = [];
      const leaves2: Array<{ syncId: string; leaf: Uint8Array }> = [];
      const pageSize = 1000;
      // Paginación KEYSET por sync_id (fix #2 del review): con offset, un insert concurrente durante
      // el fan-out desplaza las páginas → filas saltadas/duplicadas → root incorrecto transitorio.
      // `sync_id=gt.<último>` con `order=sync_id.asc` es estable ante inserts: una fila nueva jamás se
      // cuenta dos veces (si cae detrás del cursor simplemente no entra en ESTE snapshot — divergencia
      // transitoria esperada que el guard A-3 del cliente absorbe).
      let lastSyncId: string | null = null;
      for (;;) {
        const keyset = lastSyncId === null ? "" : `&sync_id=gt.${lastSyncId}`;
        const q = `select=${select}&order=sync_id.asc&limit=${pageSize}${keyset}`;
        const { ok, status, rows } = await getRows(c.env, auth.userJWT, entity, q);
        if (!ok) {
          return jsonError("yala_unavailable", `merkle upstream ${status} (${entity})`, 502);
        }
        for (const row of rows) {
          const syncId = String(row.sync_id).toLowerCase();
          const payload = canonRowC1(entity, row, columns);
          // Canal 2 (full-row, incluye deleted): hlc de fila VERBATIM (informativo, sin consumidor v1).
          leaves2.push({ syncId, leaf: await leafChannel2(syncId, String(row.hlc ?? ""), payload) });
          if (row.deleted !== true) {
            leaves1.push({ syncId, leaf: await leafChannel1(syncId, payload) });
          }
        }
        if (rows.length < pageSize) break;
        lastSyncId = String(rows[rows.length - 1].sync_id);
      }
      const eh = await entityHash(leaves1);
      channel1.set(entity, eh);
      channel2.set(entity, await entityHash(leaves2));
      entities[entity] = { count: leaves1.length, hash: hex(eh) };
    }
  } catch (e) {
    if (e instanceof CanonError) {
      // Una fila almacenada que el canon rechaza = incidente de datos (no debe ocurrir: todo entró
      // canónico por push). Metadata-only, nunca el valor.
      console.log(`[sync-merkle] canon error: ${e.code}`);
      return jsonError("yala_unavailable", `merkle canon ${e.code}`, 502);
    }
    throw e;
  }

  return c.json({
    canon_version: manifest.canon_version,
    capability_set: rawCap ?? "full",
    root: hex(await merkleRoot(channel1)),
    entities,
    channel2_root: hex(await merkleRoot(channel2)),
  });
}

/** Select del Merkle: identidad + flags server-side + columnas proyectadas (NUMERIC como `::text`). */
function merkleSelect(entity: string, columns: string[]): string {
  const spec = manifest.entities[entity];
  const cols = columns.map((c) => (spec.columns[c]?.pg_type === "numeric" ? `${c}::text` : c));
  return ["sync_id", "hlc", "deleted", "deleted_hlc", ...cols].join(",");
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
