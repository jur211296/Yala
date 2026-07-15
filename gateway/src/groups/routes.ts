/**
 * Rutas del canal de sync Grupos->backend (G2): `POST /groups/push`, `GET /groups/pull`,
 * `GET /groups/merkle`. Convive con `/sync/*` (canal personal) sin tocarlo.
 *
 * Invariantes de seguridad (espejo del canal personal):
 * - `user_id`/columnas server-only/identity del payload se DESCARTAN — nunca se confía en el body.
 * - El JWT del usuario se reenvía VERBATIM a PostgREST (RLS de membership + column grants arbitran);
 *   JAMÁS service_role.
 * - `apply_group_delta` es SECURITY INVOKER: el gateway solo valida forma/pull_only y llama al RPC; el
 *   RPC + la RLS deciden authorized/gone. `group_members` es PULL-ONLY (el push la rechaza sin llamar
 *   al RPC); `split_groups` es update_only (nace vía create_group).
 * - El freeze de la reversa del personal NO aplica aquí (canal aparte): NO se llama beginFreezeCheck.
 */
import type { Context } from "hono";
import type { Env } from "../env";
import { jsonError } from "../errors";
import { verifySessionToken, type SessionClaims } from "../attest/session";
import { gateRequest } from "../ratelimit";
import { bearerToken, callRpc, getRows, verifyUserToken } from "../sync/userauth";
import {
  GROUP_ENTITIES,
  groupManifest,
  isGroupEntity,
  isPullOnlyEntity,
  nestFieldsByUnit,
  projectGroupRowToDelta,
  rowIdentity,
  validateUpsertShape,
} from "./manifest";
import { canonRowC1Group, merkleColumnsGroup } from "./canon";
import { CanonError } from "../sync/canon";
import { entityHash, hex, leafChannel1, leafChannel2, merkleRoot } from "../sync/merkle";
import type {
  GroupMerkleResponse,
  GroupPullResponse,
  GroupPushRequest,
  GroupPushResponse,
  GroupSyncDelta,
  PulledGroupDelta,
} from "./types";
import type { SyncDeltaResult } from "../sync/types";

type Ctx = Context<{ Bindings: Env }>;

// Columnas que jamás se aceptan del payload de un delta de grupos (server-only + identidad + owner).
// NOTA: `member_key` NO se strippea — es una columna de DOMINIO de split_shares (grupo gshare) y de
// split_settlements (from/to_member_key); solo es IDENTIDAD para group_members (pull-only, rechazada
// antes de llegar aquí). Igual `user_id` es dominio de group_members (pull-only). owner_user_id
// (split_groups) es server-only y NO está en el manifest → se strippea por seguridad.
const SERVER_ONLY_GROUP = new Set([
  ...groupManifest.server_only_columns,
  ...groupManifest.identity_columns,
  "owner_user_id",
]);

interface AuthedUser {
  sub: string;
  userJWT: string;
  attest: SessionClaims | null;
}

/** Auth compartida (espejo de sync/routes::requireUserAndAttest): JWT Supabase + App Attest + rate-limit. */
async function requireUserAndAttest(c: Ctx): Promise<AuthedUser | Response> {
  const token = bearerToken(c.req.header("Authorization"));
  if (!token) return jsonError("yala_attest_required", "Falta el JWT de usuario (Authorization: Bearer).", 401);
  const user = await verifyUserToken(c.env, token);
  if (!user) return jsonError("yala_attest_invalid", "JWT de usuario inválido o expirado.", 401);

  const attestTok = bearerToken(c.req.header("X-Yala-Attest-Session")) ?? c.req.header("X-Yala-Attest-Session") ?? null;
  const attest = attestTok ? await verifySessionToken(c.env, attestTok) : null;
  const enforce = c.env.ENFORCE === "enforce";
  if (enforce && !attest) {
    return jsonError("yala_attest_required", "Falta el token de sesión de App Attest.", 401);
  }
  if (c.env.RATE_LIMITER) {
    const claims: SessionClaims = attest ?? { keyId: `sub:${user.sub}`, tier: "free" };
    const blocked = await gateRequest(c.env, claims, "sync");
    if (blocked) return blocked;
  }
  return { sub: user.sub, userJWT: user.token, attest };
}

// -------------------------------------------------------------------------------------- /groups/push

export async function handleGroupsPush(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  let body: GroupPushRequest;
  try {
    body = await c.req.json<GroupPushRequest>();
  } catch {
    return jsonError("yala_bad_request", "JSON inválido", 400);
  }
  if (!body || !Array.isArray(body.deltas)) {
    return jsonError("yala_bad_request", "Se espera { deltas: [] }", 400);
  }

  const results: SyncDeltaResult[] = [];
  for (const delta of body.deltas) {
    results.push(await applyOneGroupDelta(c, auth, delta));
  }
  const resp: GroupPushResponse = { results };
  return c.json(resp);
}

async function applyOneGroupDelta(c: Ctx, auth: AuthedUser, delta: GroupSyncDelta): Promise<SyncDeltaResult> {
  const syncId = typeof delta?.sync_id === "string" ? delta.sync_id : undefined;
  const base: SyncDeltaResult = { sync_id: syncId ?? "", client_mutation_id: delta?.client_mutation_id, status: "rejected" };

  if (!delta || typeof delta.entity_type !== "string" || typeof delta.group_id !== "string") {
    return { ...base, reason: "malformed_delta" };
  }
  if (!isGroupEntity(delta.entity_type)) {
    return { ...base, reason: `unknown_entity:${delta.entity_type}` };
  }
  // group_members (pull-only) jamás se empuja — rechazo ANTES del RPC (que también lo rechazaría).
  if (isPullOnlyEntity(delta.entity_type)) {
    return { ...base, reason: `pull_only:${delta.entity_type}` };
  }
  const gid = delta.group_id;
  if (gid.length < 8 || gid.length > 120) {
    return { ...base, reason: "bad_group_id" };
  }
  // split_groups usa group_id como identidad → sync_id=null. Las 3 de contenido exigen sync_id.
  const isGroupMeta = delta.entity_type === "split_groups";
  if (!isGroupMeta && !syncId) {
    return { ...base, reason: "missing_sync_id" };
  }

  const schemaVersion = typeof delta.schema_version === "number" ? delta.schema_version : 1;

  if (delta.op === "tombstone") {
    const rowHlc = delta.hlc;
    if (typeof rowHlc !== "string" || rowHlc.length === 0) {
      return { ...base, reason: "tombstone_sin_hlc" };
    }
    return callApplyGroupDelta(c, auth, delta, gid, syncId ?? null, {}, {}, rowHlc, schemaVersion, base);
  }

  // op === "upsert"
  const rawFields = (delta.fields ?? {}) as Record<string, unknown>;
  const leaked = Object.keys(rawFields).filter((k) => SERVER_ONLY_GROUP.has(k));
  if (leaked.length > 0) {
    console.log(`[groups-push] descartando columnas no-escribibles: ${leaked.join(",")} (${delta.entity_type})`);
    for (const k of leaked) delete rawFields[k];
  }
  const fieldHlcs = (delta.field_hlcs ?? {}) as Record<string, string>;

  const shape = validateUpsertShape(delta.entity_type, rawFields, fieldHlcs);
  if (shape) {
    if (shape.type === "coherence_group_partial") {
      console.log(`[canary] groupSyncCoherenceGroupPartial entity=${delta.entity_type} group=${shape.group ?? "?"} (${shape.detail})`);
      return { ...base, reason: `coherence_group_partial:${shape.group ?? shape.detail}`, outcome: { http: 422 } };
    }
    return { ...base, reason: `${shape.type}:${shape.detail}` };
  }

  const nested = nestFieldsByUnit(delta.entity_type, rawFields);
  return callApplyGroupDelta(c, auth, delta, gid, syncId ?? null, nested, fieldHlcs, delta.hlc, schemaVersion, base);
}

async function callApplyGroupDelta(
  c: Ctx,
  auth: AuthedUser,
  delta: GroupSyncDelta,
  groupId: string,
  syncId: string | null,
  nestedFields: Record<string, Record<string, unknown>>,
  fieldHlcs: Record<string, string>,
  rowHlc: string,
  schemaVersion: number,
  base: SyncDeltaResult,
): Promise<SyncDeltaResult> {
  const { ok, status, body } = await callRpc(c.env, auth.userJWT, "apply_group_delta", {
    p_entity: delta.entity_type,
    p_group_id: groupId,
    p_sync_id: syncId, // null para split_groups (identidad = group_id)
    p_op: delta.op,
    p_fields: nestedFields,
    p_field_hlcs: fieldHlcs,
    p_row_hlc: rowHlc,
    p_schema_version: schemaVersion,
  });
  if (!ok) {
    console.log(`[groups-push] apply_group_delta upstream ${status} group=${groupId} sync_id=${syncId ?? "-"}`);
    // Los mensajes del RPC de grupos son constantes SANITIZADAS (yala_not_authorized / yala_bad_request,
    // sin interpolar inputs) → se exponen en el outcome para el diagnóstico del cliente (sin PII).
    return { ...base, status: "rejected", reason: `upstream_${status}`, outcome: redactGroupUpstream(body) };
  }
  const outcome = body as { noop?: boolean } | null;
  const status2: SyncDeltaResult["status"] = outcome?.noop ? "noop" : "applied";
  return { ...base, status: status2, outcome };
}

/** Reduce un error de PostgREST a su código + mensaje SANITIZADO (los del RPC de grupos no traen PII). */
function redactGroupUpstream(body: unknown): unknown {
  if (body && typeof body === "object") {
    const b = body as { code?: unknown; message?: unknown };
    return { code: b.code, message: typeof b.message === "string" ? b.message : undefined };
  }
  return undefined;
}

// -------------------------------------------------------------------------------------- /groups/pull

// Grupos procesados en paralelo por el pull (cada uno abre 5 fetches simultáneos → ≤30 en vuelo).
// Workers capa ~6 conexiones simultáneas por invocación y encola el resto — subirlo no acelera más.
const PULL_GROUP_CONCURRENCY = 6;

export async function handleGroupsPull(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  const limit = clamp(parseIntOr(c.req.query("limit"), 500), 1, 1000);
  let cursors: Record<string, number> = {};
  const rawCursors = c.req.query("cursors");
  if (rawCursors) {
    try {
      const parsed = JSON.parse(rawCursors) as Record<string, unknown>;
      for (const [gid, seq] of Object.entries(parsed)) {
        const n = Number(seq);
        if (Number.isFinite(n)) cursors[gid] = n;
      }
    } catch {
      return jsonError("yala_bad_request", "cursors debe ser JSON {group_id: server_seq}", 400);
    }
  }

  // 1. Memberships (RLS del JWT): descubre grupos NUEVOS y PERDIDOS (un gid en cursors que ya no esté
  //    en memberships se reporta solo en `memberships`, sin deltas).
  const memQ = `select=group_id&user_id=eq.${auth.sub}&deleted=eq.false&status=in.(active,pendingApproval)`;
  const mem = await getRows(c.env, auth.userJWT, "group_members", memQ);
  if (!mem.ok) {
    return jsonError("yala_unavailable", `pull memberships upstream ${mem.status}`, 502);
  }
  const memberGroupIds = Array.from(new Set(mem.rows.map((r) => String(r.group_id))));

  const outCursors: Record<string, number> = {};
  const deltas: PulledGroupDelta[] = [];

  // 2. Por cada grupo del que soy member: fan-out por las 5 tablas, merge + sort por server_seq DENTRO
  //    del grupo, corte al `limit` por grupo. Las 5 queries de un grupo van en paralelo y los grupos en
  //    un pool acotado (≤ PULL_GROUP_CONCURRENCY×5 fetches simultáneos; el runtime de Workers encola por
  //    encima de su cap de conexiones). Las queries son byte-idénticas a la versión secuencial — mismo
  //    count de subrequests, solo cambia la orquestación. NO se batchea con group_id=in.(...): el cursor
  //    server_seq es POR GRUPO y el limit de PostgREST es global por query — una truncación dejaría
  //    grupos de la cola sin filas de una tabla mientras el merge avanza el cursor con filas de otras
  //    tablas de server_seq mayor → deltas perdidos silenciosos.
  interface Raw {
    entity: string;
    row: Record<string, unknown>;
    server_seq: number;
  }
  const fetchGroupPage = async (gid: string): Promise<{ page: Raw[] } | { error: Response }> => {
    const since = cursors[gid] ?? 0;
    const perEntity = await Promise.all(
      GROUP_ENTITIES.map((entity) => {
        const q = `select=*&group_id=eq.${gid}&server_seq=gt.${since}&order=server_seq.asc&limit=${limit}`;
        return getRows(c.env, auth.userJWT, entity, q);
      }),
    );
    // Filas en orden GROUP_ENTITIES (Promise.all preserva el orden de entrada) + sort ESTABLE por
    // server_seq → página idéntica a la del bucle secuencial original.
    const collected: Raw[] = [];
    for (let i = 0; i < GROUP_ENTITIES.length; i++) {
      const entity = GROUP_ENTITIES[i];
      const { ok, status, rows } = perEntity[i];
      if (!ok) {
        return { error: jsonError("yala_unavailable", `pull upstream ${status} (${entity})`, 502) };
      }
      for (const row of rows) collected.push({ entity, row, server_seq: Number(row.server_seq) });
    }
    collected.sort((a, b) => a.server_seq - b.server_seq);
    return { page: collected.slice(0, limit) };
  };

  const pages = new Array<{ page: Raw[] } | { error: Response }>(memberGroupIds.length);
  let nextGroup = 0;
  await Promise.all(
    Array.from({ length: Math.min(PULL_GROUP_CONCURRENCY, memberGroupIds.length) }, async () => {
      for (;;) {
        const i = nextGroup++;
        if (i >= memberGroupIds.length) return;
        pages[i] = await fetchGroupPage(memberGroupIds[i]);
      }
    }),
  );

  // Ensamblado en orden memberGroupIds (mismo orden de salida que la versión secuencial); el primer
  // error upstream gana, como antes (solo que ya no aborta los fetches de los demás grupos).
  for (let i = 0; i < memberGroupIds.length; i++) {
    const gid = memberGroupIds[i];
    const result = pages[i];
    if ("error" in result) return result.error;
    const page = result.page;
    if (page.length === 0) continue;

    for (const { entity, row, server_seq } of page) {
      const storedFh = (row.field_hlcs ?? {}) as Record<string, string>;
      const isDeleted = row.deleted === true;
      const { fields, field_hlcs } = projectGroupRowToDelta(entity, row, storedFh);
      deltas.push({
        entity_type: entity,
        group_id: gid,
        sync_id: rowIdentity(entity, row),
        op: isDeleted ? "tombstone" : "upsert",
        fields: isDeleted ? {} : fields,
        field_hlcs: isDeleted ? {} : field_hlcs,
        hlc: isDeleted ? String(row.deleted_hlc ?? row.hlc ?? "") : String(row.hlc ?? ""),
        server_seq,
        schema_version: Number(row.schema_version ?? 1),
      });
    }
    outCursors[gid] = page[page.length - 1].server_seq;
  }

  const resp: GroupPullResponse = { deltas, cursors: outCursors, memberships: memberGroupIds };
  return c.json(resp);
}

// ------------------------------------------------------------------------------------ /groups/merkle

/**
 * GET /groups/merkle?group_id=<gid> — molde de handleSyncMerkle acotado a UN grupo (las 5 tablas con
 * group_id=eq.<gid>). Keyset por la IDENTIDAD de cada tabla (sync_id / member_key / group_id). Si el
 * user no es member, todas las tablas vienen vacías por RLS → root de corpus vacío (sin oráculo).
 */
export async function handleGroupsMerkle(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  const gid = c.req.query("group_id");
  if (!gid || gid.length < 8 || gid.length > 120) {
    return jsonError("yala_bad_request", "falta group_id (8..120)", 400);
  }

  const channel1 = new Map<string, Uint8Array>();
  const channel2 = new Map<string, Uint8Array>();
  const entities: Record<string, { count: number; hash: string }> = {};

  try {
    for (const entity of GROUP_ENTITIES) {
      const columns = merkleColumnsGroup(entity);
      const select = merkleSelect(entity, columns);
      const keyCol = keysetColumn(entity);
      const leaves1: Array<{ syncId: string; leaf: Uint8Array }> = [];
      const leaves2: Array<{ syncId: string; leaf: Uint8Array }> = [];
      const pageSize = 1000;
      let lastKey: string | null = null;
      for (;;) {
        const keyset = lastKey === null ? "" : `&${keyCol}=gt.${encodeURIComponent(lastKey)}`;
        // gid viene CRUDO del caller (a diferencia del pull, cuyos gid son memberships server-derivadas):
        // URL-encode para que caracteres especiales de PostgREST no rompan/alteren la query.
        const q = `select=${select}&group_id=eq.${encodeURIComponent(gid)}&order=${keyCol}.asc&limit=${pageSize}${keyset}`;
        const { ok, status, rows } = await getRows(c.env, auth.userJWT, entity, q);
        if (!ok) {
          return jsonError("yala_unavailable", `merkle upstream ${status} (${entity})`, 502);
        }
        for (const row of rows) {
          const id = rowIdentity(entity, row).toLowerCase();
          const payload = canonRowC1Group(entity, row, columns);
          leaves2.push({ syncId: id, leaf: await leafChannel2(id, String(row.hlc ?? ""), payload) });
          if (row.deleted !== true) {
            leaves1.push({ syncId: id, leaf: await leafChannel1(id, payload) });
          }
        }
        if (rows.length < pageSize) break;
        lastKey = String(rows[rows.length - 1][keyCol]);
      }
      const eh = await entityHash(leaves1);
      channel1.set(entity, eh);
      channel2.set(entity, await entityHash(leaves2));
      entities[entity] = { count: leaves1.length, hash: hex(eh) };
    }
  } catch (e) {
    if (e instanceof CanonError) {
      console.log(`[groups-merkle] canon error: ${e.code}`);
      return jsonError("yala_unavailable", `merkle canon ${e.code}`, 502);
    }
    throw e;
  }

  const resp: GroupMerkleResponse = {
    canon_version: groupManifest.canon_version,
    group_id: gid,
    root: hex(await merkleRoot(channel1)),
    entities,
    channel2_root: hex(await merkleRoot(channel2)),
  };
  return c.json(resp);
}

/** Columna del keyset del Merkle por tabla: la identidad de la fila. */
function keysetColumn(entity: string): string {
  if (entity === "split_groups") return "group_id";
  if (entity === "group_members") return "member_key";
  return "sync_id";
}

/** Select del Merkle: identidad + flags server-side + columnas (NUMERIC como `::text`). */
function merkleSelect(entity: string, columns: string[]): string {
  const spec = groupManifest.entities[entity];
  const cols = columns.map((c) => (spec.columns[c]?.pg_type === "numeric" ? `${c}::text` : c));
  const idCols = entity === "group_members" ? ["group_id", "member_key"] : entity === "split_groups" ? ["group_id"] : ["group_id", "sync_id"];
  return [...idCols, "hlc", "deleted", "deleted_hlc", ...cols].join(",");
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
