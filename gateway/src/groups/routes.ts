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
import { sendPush } from "../push/apns";

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

export interface AuthedUser {
  sub: string;
  userJWT: string;
  attest: SessionClaims | null;
}

/** Auth compartida (espejo de sync/routes::requireUserAndAttest): JWT Supabase + App Attest + rate-limit.
 *  Exportada para que las rutas de push (`push/register.ts`) la reusen sin una 3ª copia (brief G8 §rutas). */
export async function requireUserAndAttest(c: Ctx): Promise<AuthedUser | Response> {
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

  // Fan-out de silent push (G8): por cada delta APPLIED, su group_id. SyncDeltaResult NO porta group_id →
  // zip index-alineado con body.deltas (mismo largo, mismo orden). El fan-out corre EN waitUntil y JAMÁS
  // bloquea ni afecta la respuesta (ya respondida): un fallo de APNs es best-effort, la cadencia de pull cubre.
  const groupIds = new Set<string>();
  for (let i = 0; i < results.length; i++) {
    if (results[i].status !== "applied") continue;
    const gid = body.deltas[i]?.group_id;
    if (typeof gid === "string" && gid.length > 0) groupIds.add(gid);
  }
  if (groupIds.size > 0) {
    // G8-3: el device emisor viaja en `X-Yala-Device-Token` (opcional). hex-64 o se ignora con log (NUNCA se
    // persiste ni se loggea completo — prefijo ≤8 como los demás tokens). Presente → el fan-out excluye SOLO
    // ese device del autor (los otros devices del autor SÍ reciben push); ausente/ inválido → fallback G8-1.
    const rawDeviceToken = c.req.header("X-Yala-Device-Token");
    let excludeDeviceToken: string | null = null;
    if (typeof rawDeviceToken === "string" && rawDeviceToken.length > 0) {
      if (/^[0-9a-f]{64}$/i.test(rawDeviceToken)) {
        excludeDeviceToken = rawDeviceToken;
      } else {
        console.log(`[groups-fanout] X-Yala-Device-Token inválido (no hex-64) — ignorado token=${rawDeviceToken.slice(0, 8)}`);
      }
    }
    c.executionCtx.waitUntil(fanOutGroupPush(c.env, auth, Array.from(groupIds), excludeDeviceToken));
  }

  const resp: GroupPushResponse = { results };
  return c.json(resp);
}

// ----------------------------------------------------------------------------- fan-out de silent push (G8)

// Cap de sanidad: máx tokens por invocación del fan-out (un push a decenas de devices en un waitUntil de
// segundos). Si se recorta se loguea — señal de un grupo anormalmente grande.
const FANOUT_TOKEN_CAP = 50;

/**
 * Despierta con un silent push (`content-available:1`) a los co-members ACTIVOS de los grupos tocados por un
 * push APPLIED, para que hagan pull del contenido nuevo. G8-3: los RPCs de push se llaman con la CREDENCIAL DE
 * MÁQUINA `env.PUSH_ROLE_JWT` (rol `yala_push`, el único con EXECUTE tras g8_02) — NO con el JWT del autor. El
 * autor viaja solo como `p_exclude_user_id: auth.sub` (a quién NO despertar) + `excludeDeviceToken` (su device
 * emisor). Best-effort TOTAL: cualquier fallo (secret ausente/revocado → 401, APNs caído, token muerto) se traga
 * con un log — la respuesta del push ya se envió y la cadencia de pull es la red. ⚠️ un 401 recurrente en el log
 * `upstream 401` = legacy secret revocado → re-acuñar PUSH_ROLE_JWT (mint-push-role-jwt.mjs). Ver g8_02.
 */
export async function fanOutGroupPush(
  env: Env,
  auth: { userJWT: string; sub: string },
  groupIds: string[],
  excludeDeviceToken: string | null = null,
): Promise<void> {
  // Short-circuit si APNs no está configurado (espejo del 503 de /v1/debug/push; aquí silencioso, 1 log).
  // Prod arranca así hasta que el owner cargue APNS_KEY_ID/APNS_AUTH_KEY (pendiente-owner en wrangler.toml).
  if (!env.APNS_AUTH_KEY || !env.APNS_KEY_ID) {
    console.log("[groups-fanout] APNs no configurado (sin APNS_KEY_ID/APNS_AUTH_KEY) — fan-out no-op");
    return;
  }
  // Short-circuit si falta la credencial de máquina (G8-3): sin PUSH_ROLE_JWT los RPCs responden 403 (los
  // revocamos de authenticated) → el fan-out no puede resolver tokens. Mismo trato que el de APNs (1 log).
  if (!env.PUSH_ROLE_JWT) {
    console.log("[groups-fanout] PUSH_ROLE_JWT ausente — fan-out no-op (credencial de máquina no configurada)");
    return;
  }
  const machineJWT = env.PUSH_ROLE_JWT;

  // Recolectar tokens de todos los grupos del batch; dedup por device_token (un member en 2 grupos → 1 push).
  const targets = new Map<string, { userId: string; deviceToken: string; platform: string }>();
  for (const gid of groupIds) {
    const { ok, status, body } = await callRpc(env, machineJWT, "get_group_push_tokens", {
      p_group_id: gid,
      p_exclude_user_id: auth.sub,
      p_exclude_device_token: excludeDeviceToken,
    });
    if (!ok) {
      console.log(`[groups-fanout] get_group_push_tokens upstream ${status} group=${gid}`);
      continue;
    }
    for (const row of Array.isArray(body) ? (body as Record<string, unknown>[]) : []) {
      const deviceToken = typeof row.device_token === "string" ? row.device_token : "";
      const userId = typeof row.user_id === "string" ? row.user_id : "";
      const platform = typeof row.platform === "string" ? row.platform : "ios-prod";
      if (!deviceToken || !userId) continue;
      if (!targets.has(deviceToken)) targets.set(deviceToken, { userId, deviceToken, platform });
    }
  }

  let list = Array.from(targets.values());
  if (list.length > FANOUT_TOKEN_CAP) {
    console.log(`[groups-fanout] recortando ${list.length} → ${FANOUT_TOKEN_CAP} tokens`);
    list = list.slice(0, FANOUT_TOKEN_CAP);
  }

  for (const t of list) {
    const result = await sendPush(env, {
      deviceToken: t.deviceToken,
      sandbox: t.platform === "ios-sandbox",
      payload: { aps: { "content-available": 1 }, yala: { kind: "groups-sync" } },
    });
    if (result.delivered) continue;

    const reason = apnsReason(result.body);
    if (reason === "BadDeviceToken" || reason === "Unregistered") {
      // Token muerto → prune best-effort con la credencial de máquina (G8-3: prune_push_token solo callable
      // por yala_push tras g8_02; el guard de radio de G8-1 se retiró — solo el Worker confiable la llama).
      const pruned = await callRpc(env, machineJWT, "prune_push_token", { p_user_id: t.userId, p_device_token: t.deviceToken });
      if (!pruned.ok) console.log(`[groups-fanout] prune upstream ${pruned.status} token=${t.deviceToken.slice(0, 8)}`);
    } else {
      // Canario §12 (server-side): observable en wrangler tail. SIN el token completo (prefijo ≤8 chars).
      console.log(
        `[canary] groupApnsSendFailed status=${result.status ?? "-"} reason=${reason ?? result.transportError?.slice(0, 40) ?? "?"} token=${t.deviceToken.slice(0, 8)}`,
      );
    }
  }
}

/** Extrae el `reason` del body JSON de APNs ({"reason":"BadDeviceToken"} etc.). undefined si no parsea. */
function apnsReason(body: string | undefined): string | undefined {
  if (!body) return undefined;
  try {
    return (JSON.parse(body) as { reason?: string }).reason;
  } catch {
    return undefined;
  }
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
    p_key: c.env.GROUPS_ENC_KEY, // G7: la llave cifra las columnas † server-side (jamás en URL/query)
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

  // G7: sin la llave de cifrado no se puede descifrar el contenido † → 503 (JAMÁS servir ciphertext).
  const encKey = c.env.GROUPS_ENC_KEY;
  if (!encKey) return jsonError("yala_unavailable", "enc key no configurada", 503);

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
    // G7: se lee vía los RPCs lectores `groups_pull_rows_<tabla>` (POST body — la llave JAMÁS en URL/query;
    // el RPC descifra las † server-side y sirve los amounts como STRING decimal exacto escala-4). El shape del
    // body ES el array de rows del returns-table (mismo count de subrequests y misma paginación por server_seq).
    const perEntity = await Promise.all(
      GROUP_ENTITIES.map((entity) =>
        callRpc(c.env, auth.userJWT, `groups_pull_rows_${entity}`, {
          p_group_id: gid,
          p_after_seq: since,
          p_limit: limit,
          p_key: encKey,
        }),
      ),
    );
    // Filas en orden GROUP_ENTITIES (Promise.all preserva el orden de entrada) + sort ESTABLE por
    // server_seq → página idéntica a la del bucle secuencial original.
    const collected: Raw[] = [];
    for (let i = 0; i < GROUP_ENTITIES.length; i++) {
      const entity = GROUP_ENTITIES[i];
      const { ok, status, body } = perEntity[i];
      if (!ok) {
        return { error: jsonError("yala_unavailable", `pull upstream ${status} (${entity})`, 502) };
      }
      for (const row of rowsFromRpc(body)) collected.push({ entity, row, server_seq: Number(row.server_seq) });
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

  // G7: sin la llave no se puede descifrar el contenido † para re-serializar el canon → 503.
  const encKey = c.env.GROUPS_ENC_KEY;
  if (!encKey) return jsonError("yala_unavailable", "enc key no configurada", 503);

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
      const leaves1: Array<{ syncId: string; leaf: Uint8Array }> = [];
      const leaves2: Array<{ syncId: string; leaf: Uint8Array }> = [];
      const pageSize = 1000;
      // G7: se lee vía el mismo RPC lector que el pull (descifra † + amounts como string exacto). Keyset por
      // server_seq (el reader ordena por server_seq asc). entityHash ordena los leaves por syncId internamente
      // → el orden de recolección es irrelevante (M8: no estable ante updates concurrentes a mitad de
      // paginación — irrelevante en beta, corpus < pageSize 1000).
      let afterSeq = 0;
      for (;;) {
        const { ok, status, body } = await callRpc(c.env, auth.userJWT, `groups_pull_rows_${entity}`, {
          p_group_id: gid,
          p_after_seq: afterSeq,
          p_limit: pageSize,
          p_key: encKey,
        });
        if (!ok) {
          return jsonError("yala_unavailable", `merkle upstream ${status} (${entity})`, 502);
        }
        const rows = rowsFromRpc(body);
        for (const row of rows) {
          const id = rowIdentity(entity, row).toLowerCase();
          const payload = canonRowC1Group(entity, row, columns);
          leaves2.push({ syncId: id, leaf: await leafChannel2(id, String(row.hlc ?? ""), payload) });
          if (row.deleted !== true) {
            leaves1.push({ syncId: id, leaf: await leafChannel1(id, payload) });
          }
        }
        if (rows.length < pageSize) break;
        afterSeq = Number(rows[rows.length - 1].server_seq);
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

/**
 * Rows de un RPC lector `groups_pull_rows_<tabla>`: `callRpc` devuelve `{ok,status,body}` donde el body ES el
 * array de rows del returns-table (donde el pull vía `getRows` destructuraba `.rows`). Degrada a [] si no es array.
 */
function rowsFromRpc(body: unknown): Record<string, unknown>[] {
  return Array.isArray(body) ? (body as Record<string, unknown>[]) : [];
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
