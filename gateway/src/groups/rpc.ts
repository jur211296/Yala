/**
 * Rutas RPC de membresía de Grupos->backend (G3): `POST /groups/rpc/:fn`. Canal PARALELO al de
 * sync (`/groups/push|pull|merkle`); convive con `/sync/*` y `/account/*` sin tocarlos.
 *
 * Invariantes de seguridad (espejo del canal de sync de grupos):
 * - `fn` DEBE estar en la ALLOWLIST estática (9 RPCs de membresía) — cualquier otra ruta (p.ej.
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

type Ctx = Context<{ Bindings: Env }>;

// ALLOWLIST de RPCs + de sus params (del DDL supabase-groups-staging.ddl). create_group tiene 10 params
// tras g3_01_create_group_full_meta (los 3 nuevos con DEFAULT). groups_forget_user no lleva params.
const PARAM_ALLOWLIST: Record<string, Set<string>> = {
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
  // G6-1: migración de un grupo VIVO de CloudKit al backend. p_meta/p_members viajan como jsonb intactos
  // (la allowlist filtra por NOMBRE y copia el valor verbatim vía JSON.stringify — objetos/arrays inclusive).
  migrate_group: new Set(["p_group_id", "p_meta", "p_members"]),
};

// G7: RPCs que escriben columnas † → se les inyecta la llave de cifrado (p_key) tras el filtro de la allowlist.
// p_key NO está en PARAM_ALLOWLIST (el cliente jamás la manda). approve/remove/leave/revoke/create_invite NO
// escriben † → sin llave.
const RPC_NEEDS_ENC_KEY = new Set([
  "create_group",
  "join_group",
  "update_member_display_name",
  "migrate_group",
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
  // Auth PRIMERO: no revelar la allowlist de RPCs a un caller anónimo (sin oráculo de fn existentes).
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  const fn = c.req.param("fn") ?? "";
  const allowedParams = PARAM_ALLOWLIST[fn];
  if (!allowedParams) {
    // fn fuera de la allowlist (fake_fn, apply_group_delta, …): 404 sin llamar a PostgREST.
    return jsonError("yala_bad_request", `unknown rpc: ${fn}`, 404);
  }

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
  if (RPC_NEEDS_ENC_KEY.has(fn)) {
    args.p_key = c.env.GROUPS_ENC_KEY;
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

  // Passthrough del body del RPC: jsonb (objeto) para casi todos; JSON string para create_group_invite.
  return c.json((out ?? null) as never);
}

/** Extrae el `message` de un error de PostgREST (el código yala_* sanitizado vive ahí, no en `code`). */
function upstreamMessage(body: unknown): string | null {
  if (body && typeof body === "object") {
    const m = (body as { message?: unknown }).message;
    if (typeof m === "string") return m;
  }
  return null;
}
