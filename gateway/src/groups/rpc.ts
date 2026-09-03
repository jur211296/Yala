/**
 * Rutas RPC de membresía de Grupos->backend (G3): `POST /groups/rpc/:fn`. Canal PARALELO al de
 * sync (`/groups/push|pull|merkle`); convive con `/sync/*` y `/account/*` sin tocarlos.
 *
 * Invariantes de seguridad (espejo del canal de sync de grupos):
 * - `fn` DEBE estar en la ALLOWLIST estática (12 RPCs: 10 de membresía + los 2 del consent C1) —
 *   cualquier otra ruta (p.ej.
 *   apply_group_delta, que solo va por /groups/push) → 404. Evita que el gateway sea un proxy RPC
 *   genérico contra PostgREST.
 * - ALLOWLIST DE PARAMS por fn: los params desconocidos del body se DESCARTAN silenciosamente. Motivo
 *   doble: (1) un arg extra hace que PostgREST devuelva 404 PGRST202 ("no function matches") porque no
 *   encaja ninguna sobrecarga; (2) JAMÁS se inyecta user_id/sub — los RPCs derivan el uid del JWT
 *   (auth.uid() adentro), así que un `user_id` del payload nunca debe llegar al RPC.
 * - El JWT del usuario se reenvía VERBATIM a PostgREST (RLS + column grants de G1 arbitran); JAMÁS
 *   service_role.
 * - Errores del RPC: los mensajes son constantes SANITIZADAS `yala_*` (errcode P0001, sin interpolar
 *   inputs). Se exponen como código al cliente (400 yala_rpc_error). El resto de fallos upstream se
 *   colapsa a 502 yala_unavailable SIN reenviar el body crudo (sanitización).
 */
import type { Context } from "hono";
import type { Env } from "../env";
import { errorBody, jsonError } from "../errors";
import { verifySessionToken, type SessionClaims } from "../attest/session";
import { gateRequest } from "../ratelimit";
import { bearerToken, callRpc, verifyUserToken } from "../sync/userauth";
import { requireEncKey } from "./encKey";
import { KILL_EXEMPT_RPCS, groupsChannelKilled } from "./killSwitch";
// g8_03: los RPC de membresía pasan a emitir push. Vive en `routes.ts` porque el resolver de tokens,
// el cap y el prune ya están ahí — duplicarlo aquí sería la segunda copia del mismo fan-out.
import { fanOutGroupPush } from "./routes";

type Ctx = Context<{ Bindings: Env }>;

// ALLOWLIST de RPCs + de sus params (del DDL supabase-groups-staging.ddl). create_group tiene 10 params
// tras g3_01_create_group_full_meta (los 3 nuevos con DEFAULT). groups_forget_user y groups_consent_state
// no llevan params.
// Exportada para que `test/groups.killswitch.test.ts` derive de AQUÍ la lista de RPCs a clasificar (kill vs
// exento) en vez de copiarla a mano: con un espejo manual, un RPC nuevo nacería sin clasificar y ningún test
// lo notaría. Solo se lee en tests — el handler la usa directamente.
export const PARAM_ALLOWLIST: Record<string, Set<string>> = {
  create_group: new Set([
    "p_group_id",
    "p_name",
    "p_currency_code",
    "p_icon_name",
    "p_color_hex",
    "p_display_name",
    "p_default_split_type",
    "p_simplify_debts",
    "p_show_debts_in_single_currency",
    "p_members_can_invite",
  ]),
  create_group_invite: new Set(["p_group_id", "p_ttl_seconds", "p_max_uses"]),
  join_group: new Set(["p_token", "p_display_name", "p_legacy_member_key"]),
  approve_member: new Set(["p_group_id", "p_member_key"]),
  remove_member: new Set(["p_group_id", "p_member_key"]),
  leave_group: new Set(["p_group_id"]),
  revoke_invite: new Set(["p_token"]),
  update_member_display_name: new Set(["p_group_id", "p_display_name"]),
  groups_forget_user: new Set<string>(),
  // D10 (batch "salir de todos mis grupos"): transfiere el ownership de UN grupo backend al co-member
  // elegible más antiguo. NO escribe columnas † → NO va a RPC_NEEDS_ENC_KEY (sin p_key).
  transfer_group_ownership: new Set(["p_group_id"]),
  // C1 (registro GDPR del consent de Grupos, g13_01): alcance-CUENTA dentro del namespace de grupos —
  // precedente exacto `groups_forget_user`, que también deriva todo de auth.uid(). NO escriben columnas †
  // ⇒ fuera de RPC_NEEDS_ENC_KEY. `p_accepted_at` viaja del cliente A PROPÓSITO (el epoch es la hora de la
  // ACEPTACIÓN, no la del reintento que consiguió red) y el RPC lo acota: futuro → clamp, absurdo → 400.
  // NO son KILL_EXEMPT: con el canal apagado el registro devuelve 403 y el intent durable del cliente lo
  // CONSERVA como transitorio — el consent ya ocurrió y la prueba no se tira.
  record_groups_consent: new Set(["p_text_version", "p_accepted_at", "p_path"]),
  groups_consent_state: new Set<string>(),
};

// G7: RPCs que escriben columnas † → se les inyecta la llave de cifrado (p_key) tras el filtro de la allowlist.
// p_key NO está en PARAM_ALLOWLIST (el cliente jamás la manda). approve/remove/leave/revoke/create_invite NO
// escriben † → sin llave.
const RPC_NEEDS_ENC_KEY = new Set([
  "create_group",
  "join_group",
  "update_member_display_name",
  "groups_forget_user",
]);

interface AuthedUser {
  sub: string;
  userJWT: string;
  attest: SessionClaims | null;
}

/** Auth compartida (espejo de routes::requireUserAndAttest): JWT Supabase + App Attest + rate-limit. */
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

// ---------------------------------------------------------------------------------- /groups/rpc/:fn

export async function handleGroupsRpc(c: Ctx): Promise<Response> {
  const fn = c.req.param("fn") ?? "";

  // Kill-switch ANTES de la auth (racional en `groups/routes.ts::handleGroupsPush`), con la EXCEPCIÓN del
  // teardown: `groups_forget_user` pasa siempre, porque el cliente ya lo exceptúa por capacidad compilada
  // y bloquearlo aquí le quitaría al usuario su derecho de supresión mientras durase el kill (detalle en
  // `killSwitch.ts`). Leer `fn` antes del guard NO rompe el invariante de la línea siguiente: con el kill
  // activo, un `fn` inexistente y uno de la allowlist reciben el MISMO 403, así que sigue sin haber
  // oráculo de qué RPCs existen. Lo único distinguible es `groups_forget_user`, cuyo nombre ya es público
  // en el DDL y en el runbook.
  if (!KILL_EXEMPT_RPCS.has(fn)) {
    const killed = groupsChannelKilled(c.env);
    if (killed) return killed;
  }

  // Auth ANTES de la allowlist: no revelar la allowlist de RPCs a un caller anónimo.
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  const allowedParams = PARAM_ALLOWLIST[fn];
  if (!allowedParams) {
    // fn fuera de la allowlist (fake_fn, apply_group_delta, …): 404 sin llamar a PostgREST.
    return jsonError("yala_bad_request", `unknown rpc: ${fn}`, 404);
  }

  // G7: la llave se comprueba ANTES de leer el body y de construir los args — sin ella `p_key` viajaría
  // `undefined` y PostgREST respondería con un error de firma de función que no nombra el secreto. Mismo
  // 503 tipado y MISMO mensaje que /groups/pull y /groups/merkle (constante compartida en encKey.ts).
  // Solo la exigen los RPCs que escriben columnas † : los otros 6 de la allowlist siguen funcionando sin
  // llave, así que un secreto ausente no tumba `leave_group`/`approve_member`/… de más.
  const encKey = RPC_NEEDS_ENC_KEY.has(fn) ? requireEncKey(c.env) : null;
  if (encKey instanceof Response) return encKey;

  // groups_forget_user no lleva body → un body ausente/no-JSON se trata como {}.
  let raw: unknown = {};
  try {
    raw = await c.req.json<unknown>();
  } catch {
    raw = {};
  }
  const body = raw && typeof raw === "object" && !Array.isArray(raw) ? (raw as Record<string, unknown>) : {};

  // Filtrar por la allowlist de params (descarte silencioso de desconocidos).
  const args: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(body)) {
    if (allowedParams.has(k)) args[k] = v;
  }

  // G7: los RPCs que escriben columnas † reciben la llave de cifrado como argumento — INYECTADA aquí (jamás por
  // el cliente; NO está en PARAM_ALLOWLIST). Fuera de la allowlist a propósito: la llave nunca viaja en el body.
  // `encKey` es no-null exactamente para los fn de RPC_NEEDS_ENC_KEY y YA está validada arriba (nunca `undefined`).
  if (encKey !== null) {
    args.p_key = encKey;
  }

  const { ok, status, body: out } = await callRpc(c.env, auth.userJWT, fn, args);
  if (!ok) {
    const message = upstreamMessage(out);
    // Los errores del RPC de grupos son constantes yala_* sanitizadas → 400 con el código preservado.
    if (message && /^yala_[a-z_]+$/.test(message)) {
      console.log(`[groups-rpc] ${fn} rejected: ${message}`);
      return new Response(JSON.stringify(errorBody("yala_rpc_error", message, message)), {
        status: 400,
        headers: { "content-type": "application/json" },
      });
    }
    // Cualquier otro fallo upstream: sanitizado a 502, SIN reenviar el body crudo.
    console.log(`[groups-rpc] ${fn} upstream ${status}`);
    return jsonError("yala_unavailable", `groups rpc upstream ${status}`, 502);
  }

  // Fan-out de MEMBRESÍA (g8_03). Hasta hoy este fichero no emitía NADA: `fanOutGroupPush` tenía un
  // único llamador, la ruta de deltas de `/groups/push`, así que el admin no se enteraba de una
  // solicitud de entrada hasta que abría la app por su cuenta — podían ser horas, y mientras el
  // invitado esperaba a ciegas.
  //
  // Va en `waitUntil` y DESPUÉS de que el RPC haya tenido éxito: es best-effort total, igual que su
  // hermano, y jamás debe afectar a la respuesta que el cliente ya está esperando.
  notifyMembershipChange(c, auth, fn, out);

  // Passthrough del body del RPC: jsonb (objeto) para casi todos; JSON string para create_group_invite.
  return c.json((out ?? null) as never);
}

/**
 * Dispara el push de los RPC que cambian una membresía. No hace nada para el resto.
 *
 * **El `group_id` se lee del RETORNO, no de `args`, y no es un detalle.** `PARAM_ALLOWLIST.join_group`
 * es `{p_token, p_display_name, p_legacy_member_key}`: no lleva group id, porque quien se une sólo
 * tiene el token del enlace. Las tres ramas del RPC devuelven `{group_id, member_key, status}`
 * (`supabase-groups-staging.ddl:483,:494,:509,:523`), y ahí sí está.
 *
 * **Y el `status` decide si hay algo que avisar.** La rama «ya eras miembro» de `join_group`
 * (`ddl:492-495`) devuelve `status:'active'` SIN haber cambiado nada: notificar ahí spamearía a los
 * admins cada vez que alguien reabre el enlace. Sólo se avisa de transiciones reales.
 */
export function notifyMembershipChange(
  c: Context<{ Bindings: Env }>,
  auth: { userJWT: string; sub: string },
  fn: string,
  out: unknown,
): void {
  if (fn !== "join_group" && fn !== "approve_member" && fn !== "remove_member") return;

  // **`c.executionCtx` LANZA si el Worker se invocó sin ExecutionContext.** En el runtime real siempre
  // existe, pero `app.fetch(req, env)` sin 3er argumento —como llaman varios tests— hace que Hono tire
  // «no ExecutionContext», y aquí eso convertiría un RPC que YA tuvo éxito en un 500. El aviso es
  // best-effort: jamás puede tumbar la operación que lo dispara.
  //
  // Se resuelve UNA vez y aquí, no en cada rama: `/groups/push` ya se topó con esto (su llamador de
  // test pasa un ctx no-op a propósito, ver el comentario de `groups.goldens.test.ts:115`) y la
  // lección es que el fan-out no debe depender de que cada llamador se acuerde.
  let waitUntil: (p: Promise<unknown>) => void;
  try {
    const ctx = c.executionCtx;
    waitUntil = (p) => ctx.waitUntil(p);
  } catch {
    // Sin ctx no hay dónde colgar el trabajo en segundo plano: se descarta el aviso y se deja rastro.
    // Nunca se hace `await`: bloquearía la respuesta del RPC, que es justo lo que `waitUntil` evita.
    console.log(`[groups-rpc] ${fn}: sin ExecutionContext — fan-out de membresía omitido`);
    return;
  }

  const body = (out ?? {}) as Record<string, unknown>;
  const groupId = typeof body.group_id === "string" ? body.group_id : "";
  const memberKey = typeof body.member_key === "string" ? body.member_key : "";
  const status = typeof body.status === "string" ? body.status : "";
  if (!groupId) return;

  // `join_group` → avisa a QUIEN PUEDE APROBAR, y sólo si de verdad quedó pendiente. Un `rebound` o
  // un re-tap del enlace de alguien ya activo no es noticia para nadie.
  if (fn === "join_group") {
    if (status !== "pendingApproval") return;
    waitUntil(
      fanOutGroupPush(c.env, auth, [groupId], null, { kind: "admins" }, "notifications.groups.remotePendingRequest"),
    );
    return;
  }

  // `approve_member` / `remove_member` → avisan a LA PERSONA afectada, que no es quien llama: aquí el
  // autor es el admin. Por eso la audiencia va por `member_key` y no excluye a nadie.
  //
  // El mismo texto neutro sirve para aprobado, rechazado y expulsado a propósito: una negativa no
  // debería leerse en una pantalla de bloqueo delante de quien sea, y el detalle lo da la app al
  // abrir — que además es la única que puede descifrarlo.
  if (!memberKey) return;
  waitUntil(
    fanOutGroupPush(
      c.env,
      auth,
      [groupId],
      null,
      { kind: "member", memberKey },
      "notifications.groups.remoteMembershipUpdate",
    ),
  );
}

/** Extrae el `message` de un error de PostgREST (el código yala_* sanitizado vive ahí, no en `code`). */
function upstreamMessage(body: unknown): string | null {
  if (body && typeof body === "object") {
    const m = (body as { message?: unknown }).message;
    if (typeof m === "string") return m;
  }
  return null;
}
