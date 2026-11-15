/**
 * Escritura de Grupos para Yala web (lote 3, opción A de Jürgen del 14-nov; solo staging): la entrada interna
 * `WebGroupsWriter` (src/worker.ts) llama a esto con el token de la web.
 *
 * Lo que sustituye a App Attest, que un navegador no puede dar (la opción A lo enumeró así):
 * - Entrar en la web pide la verificación anti-bots, y su sesión se cierra desde el iPhone.
 * - Un rol propio: solo un token `yala_web` (web3_02) pasa por aquí. Ese rol solo puede llamar a
 *   `web_add_group_expense`, `web_add_group_settlement` (AÑADIR un gasto con sus cuotas o un pago, nuevos, en un grupo
 *   donde es miembro activo; las comprobaciones viven también en la base) y `create_group_invite`; nada de editar ni
 *   borrar. El de la app (`authenticated`) no entra por aquí: se saltaría App Attest.
 * - Una lista CERRADA de tres operaciones, que arma el gateway, no el cliente: añadir un gasto con reparto igual,
 *   apuntar un pago y crear un enlace de invitación. La web nunca manda un delta.
 * - Un límite por cuenta (`web_groups_write`, cubo `webw:<sub>`), que se aplica también en `observe`.
 *
 * Invariantes, espejo de `/groups/push`: el JWT se reenvía TAL CUAL a PostgREST (la RLS decide; JAMÁS service_role) y la
 * llave de Grupos solo cifra aquí. Las reglas son las de la app: el reparto igual de `GroupSplitCalculator` y quién
 * confirma un pago de `SettlementSaldar23Logic`. Los demás miembros reciben el aviso push de siempre.
 *
 * Reintentos: los ids los manda la web (uno por formulario abierto). Cada operación es una transacción en la base: un fallo
 * no deja nada escrito, y un reenvío de lo que ya entró devuelve `already` sin tocar nada.
 */
import type { Env } from "../env";
import { callRpc, verifyUserToken } from "../sync/userauth";
import { parseRolloutPercent } from "../config";
import { withinHardLimit } from "../ratelimit";
import { serverCanary } from "../serverCanary";
import { fanOutGroupPush } from "../groups/routes";
import type { GroupNoticeAlert } from "../groups/notice";
import { composeGroupNotice } from "../groups/notice";
import type { GroupSyncDelta } from "../groups/types";
import type { SyncDeltaResult } from "../sync/types";
import { nestFieldsByUnit, validateUpsertShape } from "../groups/manifest";
import { readGroupsForWeb, type Row, type WebGroupRows } from "./groupsReader";
import { equalSplit } from "../../../shared-core/src/logic/groupSplit";

export const WEB_WRITER_ROLE = "yala_web";
export const WEB_WRITE_BUCKET = (sub: string) => `webw:${sub}`;
const MAX_DESCRIPTION = 120;
const MAX_NOTE = 300;
const MAX_AMOUNT = 1_000_000_000;
const MAX_PARTICIPANTS = 50;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const CURRENCY_RE = /^[A-Z]{3}$/;
/** Invitaciones de la web: 7 días, como mucho 20 usos. */
const INVITE_TTL_SECONDS = 7 * 24 * 3600;
const INVITE_MAX_USES = 20;

export type WebWriteError =
  | "disabled"
  | "token"
  | "role"
  | "groups_off"
  | "no_key"
  | "rate"
  | "not_found"
  | "not_allowed"
  | "invalid"
  | "upstream";

export type WebWriteResult = { ok: true; status: "applied" | "already" } | { ok: false; error: WebWriteError; detail?: string };
export type WebInviteResult = { ok: true; url: string; expiresAt: string } | { ok: false; error: WebWriteError; detail?: string };

export interface WebExpenseInput {
  groupId: string;
  /** uuid en minúsculas, uno por envío: es el `sync_id` del gasto. */
  id: string;
  description: string;
  amount: number;
  currency: string;
  paidBy: string;
  /** Instante ISO del gasto. */
  date: string;
  /** Claves de miembro, en el orden en que se reparten los céntimos que sobran. */
  participants: string[];
}

export interface WebSettlementInput {
  groupId: string;
  id: string;
  from: string;
  to: string;
  amount: number;
  currency: string;
  date: string;
  note?: string;
}

/** Lo que el Worker deja corriendo después de responder (el aviso push). */
export type Defer = (p: Promise<unknown>) => void;

interface Ctx {
  sub: string;
  token: string;
  key: string;
  group: WebGroupRows;
  me: Row;
}

function decodeClaims(token: string): Record<string, unknown> | null {
  const part = token.split(".")[1];
  if (!part) return null;
  try {
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(part.length / 4) * 4, "=");
    return JSON.parse(atob(b64)) as Record<string, unknown>;
  } catch {
    return null;
  }
}

/** Reloj de versiones con el formato de la app (`HLC.description`): ISO con ms, contador hex de 4 y nodo hex de 16. */
export function webHlc(nowMs: number, node: string): string {
  return `${new Date(nowMs).toISOString()}-0000-${node}`;
}

function randomNode(): string {
  const b = crypto.getRandomValues(new Uint8Array(8));
  return [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
}

/** El `sync_id` de la cuota de un miembro: sale del gasto, así un reintento no duplica cuotas. */
export async function shareId(expenseId: string, memberKey: string): Promise<string> {
  const d = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`yala-web-share|${expenseId}|${memberKey}`)));
  d[6] = (d[6]! & 0x0f) | 0x40;
  d[8] = (d[8]! & 0x3f) | 0x80;
  const h = [...d.slice(0, 16)].map((x) => x.toString(16).padStart(2, "0")).join("");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`;
}

function isAmount(n: unknown): n is number {
  return typeof n === "number" && Number.isFinite(n) && n > 0 && n <= MAX_AMOUNT && Math.abs(Math.round(n * 100) - n * 100) < 1e-6;
}

function parseInstant(s: unknown, nowMs: number): string | null {
  if (typeof s !== "string" || s.length > 40) return null;
  const t = Date.parse(s);
  if (!Number.isFinite(t)) return null;
  // Nada antes de 2000 ni más de un día en el futuro (el `cap_future_hlc` del servidor acota las versiones, no esto).
  if (t < Date.UTC(2000, 0, 1) || t > nowMs + 24 * 3600 * 1000) return null;
  return new Date(t).toISOString();
}

const str = (v: unknown) => (typeof v === "string" ? v : "");
const activeMembers = (g: WebGroupRows) => g.members.filter((m) => m.status === "active" && m.deleted !== true);
/** Divisas que ya usa el grupo: la suya y las de sus gastos y pagos. La web no estrena divisas en un grupo. */
function groupCurrencies(g: WebGroupRows): Set<string> {
  const out = new Set<string>();
  const own = str(g.group?.currency_code);
  if (own) out.add(own);
  for (const r of [...g.expenses, ...g.settlements]) {
    const c = str(r.currency_code);
    if (c) out.add(c);
  }
  return out;
}

async function open(env: Env, token: string, groupId: string): Promise<Ctx | { ok: false; error: WebWriteError; detail?: string }> {
  if (env.WEB_GROUPS_WRITER !== "on" || env.ENVIRONMENT === "production") return { ok: false, error: "disabled" };
  if (parseRolloutPercent(env.GROUPS_BACKEND_ROLLOUT_PERCENT) <= 0) return { ok: false, error: "groups_off" };
  const key = env.GROUPS_ENC_KEY;
  if (!key) return { ok: false, error: "no_key" };
  if (typeof groupId !== "string" || groupId.length < 8 || groupId.length > 120) return { ok: false, error: "invalid", detail: "group" };

  // Verificar ANTES de leer el claim: un `role` sin firma no vale nada.
  const user = await verifyUserToken(env, token);
  if (!user) return { ok: false, error: "token" };
  if (decodeClaims(token)?.role !== WEB_WRITER_ROLE) return { ok: false, error: "role" };

  if (env.RATE_LIMITER && !(await withinHardLimit(env, WEB_WRITE_BUCKET(user.sub), "web_groups_write"))) {
    serverCanary(env, "webGroupsWriteLimited");
    return { ok: false, error: "rate" };
  }

  const snap = await readGroupsForWeb(env, token, groupId);
  if (!snap.ok) return { ok: false, error: snap.error === "role" ? "role" : snap.error === "token" ? "token" : "upstream" };
  const group = snap.groups.find((g) => g.group_id === groupId);
  if (!group || !group.group) return { ok: false, error: "not_found" };
  const me = activeMembers(group).find((m) => str(m.member_key) === group.me && str(m.user_id) === user.sub);
  if (!me) return { ok: false, error: "not_allowed", detail: "member" };
  if (group.group.is_archived === true) return { ok: false, error: "not_allowed", detail: "archived" };
  return { sub: user.sub, token, key, group, me };
}

/** La forma de `/groups/push` (unidades de coherencia enteras, columnas del manifest) y los campos anidados por unidad. */
function shaped(d: GroupSyncDelta): { fields: Record<string, Record<string, unknown>>; field_hlcs: Record<string, string> } | null {
  const shape = validateUpsertShape(d.entity_type, d.fields ?? {}, d.field_hlcs ?? {});
  if (shape) {
    console.log(`[web-groups-write] forma inválida ${shape.type}:${shape.detail}`);
    return null;
  }
  return { fields: nestFieldsByUnit(d.entity_type, d.fields ?? {}), field_hlcs: d.field_hlcs ?? {} };
}

type RpcOutcome = { status: "applied" | "exists" } | { status: "rejected"; http: number };

/**
 * Una operación = una llamada = una transacción en la base (web3_02): `web_add_group_expense` escribe el gasto con TODAS
 * sus cuotas o nada, y `web_add_group_settlement` el pago. Las dos comprueban que el id es nuevo en todos los grupos (el
 * iPhone busca gastos y pagos solo por id), que las personas son miembros activos y, en el gasto, que las cuotas suman
 * su importe. `exists`: ese id ya está en este grupo (un reenvío).
 */
async function writeRpc(env: Env, ctx: Ctx, fn: "web_add_group_expense" | "web_add_group_settlement", args: Record<string, unknown>, what: string): Promise<RpcOutcome> {
  const { ok, status, body } = await callRpc(env, ctx.token, fn, { ...args, p_key: ctx.key });
  if (!ok) {
    console.log(`[web-groups-write] ${fn} upstream ${status}`);
    serverCanary(env, "webGroupsWriteRejected", `${what}/${status}`);
    return { status: "rejected", http: status };
  }
  const outcome = body as { noop?: boolean; reason?: string } | null;
  if (outcome?.noop) return { status: "exists" };
  return { status: "applied" };
}

/** Un delta como los del iPhone: todas sus unidades con el mismo reloj (`DeltaEmitter.emit`). */
function delta(entity: string, groupId: string, syncId: string, fields: Record<string, unknown>, hlc: string): GroupSyncDelta {
  const field_hlcs: Record<string, string> = {};
  for (const unit of Object.keys(nestFieldsByUnit(entity, fields))) field_hlcs[unit] = hlc;
  return { entity_type: entity, group_id: groupId, sync_id: syncId, op: "upsert", fields, field_hlcs, hlc, schema_version: 1 } as GroupSyncDelta;
}

function formatAmount(amount: number, currency: string): string {
  try {
    return new Intl.NumberFormat("es-PE", { style: "currency", currency }).format(amount);
  } catch {
    return `${currency} ${amount.toFixed(2)}`;
  }
}

function notify(env: Env, ctx: Ctx, deltas: GroupSyncDelta[], results: SyncDeltaResult[], rows: Record<string, Record<string, string>>, defer: Defer): void {
  if (!results.some((r) => r.status === "applied")) return;
  const gid = ctx.group.group_id;
  const notice = {
    actors: { [gid]: str(ctx.me.display_name) },
    groups: { [gid]: str(ctx.group.group?.name) },
    rows,
  };
  const alerts: Record<string, GroupNoticeAlert> = {};
  const alert = composeGroupNotice(gid, deltas, results, notice);
  if (alert) alerts[gid] = alert;
  defer(fanOutGroupPush(env, { userJWT: ctx.token, sub: ctx.sub }, [gid], null, { kind: "coMembers" }, undefined, alerts));
}

/** Añadir un gasto con reparto igual entre `participants`, pagado por `paidBy`. */
export async function addWebExpense(env: Env, token: string, input: WebExpenseInput, defer: Defer, nowMs = Date.now()): Promise<WebWriteResult> {
  const ctx = await open(env, token, input?.groupId);
  if (!("group" in ctx)) return ctx;
  const g = ctx.group;
  const id = str(input.id);
  if (!UUID_RE.test(id)) return { ok: false, error: "invalid", detail: "id" };
  const description = str(input.description).trim();
  if (!description || description.length > MAX_DESCRIPTION) return { ok: false, error: "invalid", detail: "description" };
  if (!isAmount(input.amount)) return { ok: false, error: "invalid", detail: "amount" };
  const currency = str(input.currency);
  if (!CURRENCY_RE.test(currency) || !groupCurrencies(g).has(currency)) return { ok: false, error: "invalid", detail: "currency" };
  const date = parseInstant(input.date, nowMs);
  if (!date) return { ok: false, error: "invalid", detail: "date" };
  const active = new Set(activeMembers(g).map((m) => str(m.member_key)));
  if (!active.has(str(input.paidBy))) return { ok: false, error: "invalid", detail: "paidBy" };
  const participants = Array.isArray(input.participants) ? input.participants.map(str) : [];
  if (participants.length === 0 || participants.length > MAX_PARTICIPANTS || new Set(participants).size !== participants.length
    || participants.some((p) => !active.has(p))) {
    return { ok: false, error: "invalid", detail: "participants" };
  }
  const parts = equalSplit(input.amount, participants);
  if (!parts) return { ok: false, error: "invalid", detail: "amount" };

  // Si el gasto ya está, es un reenvío: no se toca nada (tampoco cuotas: un gasto solo nace con las suyas).
  if (g.expenses.some((e) => str(e.sync_id) === id)) return { ok: true, status: "already" };

  const hlc = webHlc(nowMs, randomNode());
  const expense = delta("split_expenses", g.group_id, id, {
    amount: input.amount,
    currency_code: currency,
    expense_description: description,
    date,
    created_at: new Date(nowMs).toISOString(),
    paid_by_member_key: str(input.paidBy),
    split_type: "equal",
    is_settled: false,
    is_opening_balance: false,
    last_edited_by_member_key: str(ctx.me.member_key),
  }, hlc);
  const shares: GroupSyncDelta[] = [];
  for (const p of parts) {
    shares.push(delta("split_shares", g.group_id, await shareId(id, p.member), { expense_id: id, member_key: p.member, amount: p.amount, is_paid: false }, hlc));
  }
  const e = shaped(expense);
  const ss = shares.map(shaped);
  if (!e || ss.some((s) => s === null)) return { ok: false, error: "invalid", detail: "shape" };

  const r = await writeRpc(env, ctx, "web_add_group_expense", {
    p_group_id: g.group_id,
    p_expense_id: id,
    p_fields: e.fields,
    p_field_hlcs: e.field_hlcs,
    p_shares: shares.map((s, i) => ({ sync_id: s.sync_id, fields: ss[i]!.fields, field_hlcs: ss[i]!.field_hlcs })),
    p_row_hlc: hlc,
  }, "expense");
  if (r.status === "rejected") return { ok: false, error: r.http === 400 ? "invalid" : "upstream", detail: r.http === 400 ? "id" : undefined };
  if (r.status === "exists") return { ok: true, status: "already" };

  const rows: Record<string, Record<string, string>> = { [id]: { concept: description, amount: formatAmount(input.amount, currency) } };
  for (const s of shares) rows[String(s.sync_id)] = { parent: id };
  const all = [expense, ...shares];
  notify(env, ctx, all, all.map((d) => ({ sync_id: String(d.sync_id), status: "applied" as const, outcome: { inserted: true } })), rows, defer);
  serverCanary(env, "webGroupsWritten", "expense");
  return { ok: true, status: "applied" };
}

/** Apuntar un pago de `from` a `to`. Confirmado si lo apunta una de las dos partes; si no, espera a quien recibe. */
export async function addWebSettlement(env: Env, token: string, input: WebSettlementInput, defer: Defer, nowMs = Date.now()): Promise<WebWriteResult> {
  const ctx = await open(env, token, input?.groupId);
  if (!("group" in ctx)) return ctx;
  const g = ctx.group;
  const id = str(input.id);
  if (!UUID_RE.test(id)) return { ok: false, error: "invalid", detail: "id" };
  if (g.settlements.some((s) => str(s.sync_id) === id)) return { ok: true, status: "already" };
  if (!isAmount(input.amount)) return { ok: false, error: "invalid", detail: "amount" };
  const currency = str(input.currency);
  if (!CURRENCY_RE.test(currency) || !groupCurrencies(g).has(currency)) return { ok: false, error: "invalid", detail: "currency" };
  const date = parseInstant(input.date, nowMs);
  if (!date) return { ok: false, error: "invalid", detail: "date" };
  const from = str(input.from);
  const to = str(input.to);
  const active = new Set(activeMembers(g).map((m) => str(m.member_key)));
  // Quien recibe tiene que poder confirmarlo (miembro activo), y quien paga también: es una deuda del grupo.
  if (!from || !to || from === to || !active.has(from) || !active.has(to)) return { ok: false, error: "invalid", detail: "members" };
  const note = str(input.note).trim();
  if (note.length > MAX_NOTE) return { ok: false, error: "invalid", detail: "note" };
  const recorder = str(ctx.me.member_key);
  const confirmed = recorder === from || recorder === to;

  const hlc = webHlc(nowMs, randomNode());
  const fields: Record<string, unknown> = {
    from_member_key: from,
    to_member_key: to,
    amount: input.amount,
    currency_code: currency,
    date,
    is_confirmed: confirmed,
    recorded_by_member_key: recorder,
  };
  if (note) fields.note = note;
  const d = delta("split_settlements", g.group_id, id, fields, hlc);
  const s = shaped(d);
  if (!s) return { ok: false, error: "invalid", detail: "shape" };
  const r = await writeRpc(env, ctx, "web_add_group_settlement", { p_group_id: g.group_id, p_sync_id: id, p_fields: s.fields, p_field_hlcs: s.field_hlcs, p_row_hlc: hlc }, "settlement");
  if (r.status === "rejected") return { ok: false, error: r.http === 400 ? "invalid" : "upstream", detail: r.http === 400 ? "id" : undefined };
  if (r.status === "exists") return { ok: true, status: "already" };
  const name = (k: string) => str(g.members.find((m) => str(m.member_key) === k)?.display_name);
  notify(env, ctx, [d], [{ sync_id: id, status: "applied", outcome: { inserted: true } }], { [id]: { amount: formatAmount(input.amount, currency), from: name(from), to: name(to) } }, defer);
  serverCanary(env, "webGroupsWritten", confirmed ? "settlement:confirmed" : "settlement:pending");
  return { ok: true, status: "applied" };
}

/** Base64URL sin relleno, como `InviteLinkService.base64URLEncode`. */
function b64url(s: string): string {
  return btoa(String.fromCharCode(...new TextEncoder().encode(s))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/**
 * El enlace de invitación con el formato de la app (`InviteLinkService.buildBackendInviteURL`, contrato C1):
 * `https://yala-app.pe/invite?g=&t=&s=&n=&i=&c=&m=&u=`, con `s` = la forma mínima `…/invite?g=&t=` en base64URL.
 */
export function inviteUrl(groupId: string, token: string, group: Row, members: Row[], me: Row): string {
  const inner = new URL("https://yala-app.pe/invite");
  inner.searchParams.set("g", groupId);
  inner.searchParams.set("t", token);
  const meKey = str(me.member_key);
  const names = members
    .filter((m) => m.status === "active" && m.deleted !== true)
    .slice(0, 5)
    .map((m) => (str(m.member_key) === meKey ? str(me.display_name) : str(m.display_name)).slice(0, 20))
    .join(",");
  const url = new URL("https://yala-app.pe/invite");
  url.searchParams.set("g", groupId);
  url.searchParams.set("t", token);
  url.searchParams.set("s", b64url(inner.toString()));
  url.searchParams.set("n", str(group.name).slice(0, 50));
  url.searchParams.set("i", str(group.icon_name));
  url.searchParams.set("c", str(group.color_hex).replace(/#/g, ""));
  url.searchParams.set("m", names);
  url.searchParams.set("u", str(me.display_name).slice(0, 30));
  return url.toString();
}

/** Crear un enlace de invitación: lo decide `create_group_invite` (admin, o «miembros pueden invitar»). */
export async function createWebInvite(env: Env, token: string, groupId: string, nowMs = Date.now()): Promise<WebInviteResult> {
  const ctx = await open(env, token, groupId);
  if (!("group" in ctx)) return ctx;
  const g = ctx.group;
  const isAdmin = ctx.me.role === "admin";
  if (!isAdmin && g.group?.members_can_invite !== true) return { ok: false, error: "not_allowed", detail: "invite" };
  const { ok, status, body } = await callRpc(env, token, "create_group_invite", {
    p_group_id: g.group_id,
    p_ttl_seconds: INVITE_TTL_SECONDS,
    p_max_uses: INVITE_MAX_USES,
  });
  if (!ok || typeof body !== "string" || !/^[0-9a-f]{32}$/.test(body)) {
    console.log(`[web-groups-write] create_group_invite upstream ${status}`);
    serverCanary(env, "webGroupsWriteRejected", `invite/${status}`);
    return { ok: false, error: ok ? "upstream" : status === 400 ? "not_allowed" : "upstream" };
  }
  serverCanary(env, "webGroupsWritten", "invite");
  return {
    ok: true,
    url: inviteUrl(g.group_id, body, g.group ?? {}, g.members, ctx.me),
    expiresAt: new Date(nowMs + INVITE_TTL_SECONDS * 1000).toISOString(),
  };
}
