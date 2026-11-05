import type { Context } from "hono";
import type { Env } from "../env";
import { getAccountEntitlement, isAccountProActive } from "../db";
import { jsonError } from "../errors";
import { requireUserAndAttest } from "../groups/routes";
import { formatAddress, mailConfig } from "./address";
import { ackDrafts, getOrCreateAddress, GMAIL_CODE_TTL_MS, listDrafts, TRIAL_LIMIT, type MailAddressRow } from "./store";

/**
 * Rutas de la app para el correo del banco. Guard: `requireUserAndAttest` (datos financieros personales, como
 * `/sync/*`); el `user_id` sale SIEMPRE del JWT, nunca del cuerpo.
 *
 *   POST /mail/address        → crea (si hace falta) y devuelve la dirección, el cupo y el código de Gmail.
 *   GET  /mail/drafts         → los movimientos leídos que esperan a la app.
 *   POST /mail/drafts/ack     → {ids:[…]} la app ya los creó en su Bandeja: se borran del servidor.
 */
type Ctx = Context<{ Bindings: Env }>;

export function addressBody(row: MailAddressRow, env: Env, pro: boolean, now = Date.now()): Record<string, unknown> {
  const gmailFresh = row.gmail_code !== null && row.gmail_code_at !== null && now - row.gmail_code_at < GMAIL_CODE_TTL_MS;
  return {
    address: formatAddress(row.code, mailConfig(env)),
    pro,
    trial_limit: TRIAL_LIMIT,
    trial_used: Math.min(row.trial_used, TRIAL_LIMIT),
    skipped_quota: row.skipped_quota,
    last_received_at_ms: row.last_received_at,
    gmail_confirmation: gmailFresh ? { code: row.gmail_code, received_at_ms: row.gmail_code_at } : null,
  };
}

export async function handleMailAddress(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;
  const row = await getOrCreateAddress(c.env, auth.sub);
  const pro = isAccountProActive(await getAccountEntitlement(c.env, auth.sub));
  return c.json(addressBody(row, c.env, pro));
}

export async function handleMailDrafts(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;
  const drafts = await listDrafts(c.env, auth.sub);
  return c.json({
    drafts: drafts.map((d) => ({ id: d.id, received_at_ms: d.created_at, ...d.payload })),
  });
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function handleMailDraftsAck(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;
  let body: { ids?: unknown };
  try {
    body = await c.req.json();
  } catch {
    return jsonError("yala_bad_request", "JSON inválido", 400);
  }
  const ids = Array.isArray(body.ids) ? body.ids.filter((x): x is string => typeof x === "string" && UUID_RE.test(x)) : [];
  if (ids.length === 0 || ids.length > 100) return jsonError("yala_bad_request", "ids inválidos (1-100 UUID)", 400);
  const deleted = await ackDrafts(c.env, auth.sub, ids);
  return c.json({ deleted });
}
