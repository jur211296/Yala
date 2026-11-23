/**
 * «Comercios en común» (2.3, 2026-11-22): las dos rutas.
 *
 * - `POST /comercios-comun/aportes` — el lote semanal de un teléfono: `{ "items": [{ "merchant": "TAMBO",
 *   "kind": "supermarket" }] }`. Nada más viaja: ni importe, ni fecha, ni cuenta, ni categoría del usuario.
 * - `GET /comercios-comun/lista` — la lista común entera, con ETag. El teléfono busca dentro, sin preguntar por un
 *   comercio.
 *
 * Las dos piden el token de sesión de App Attest (`requireSession`, como los tipos de cambio): solo la app real aporta,
 * y la huella que cuenta cada teléfono una vez sale de su keyId. No hace falta cuenta.
 */
import type { Context } from "hono";
import type { Env } from "../env";
import { allowsDevBypass } from "../env";
import { requireSession } from "../auth";
import { jsonError } from "../errors";
import { MIN_DEVICE_AGE_MS, normalizeKind, normalizeMerchant, WEEKLY_CAP } from "./rules";
import { type Contribution, deviceHash, ingest, todaysList } from "./store";

type Ctx = Context<{ Bindings: Env }>;

/** El reloj, sustituible en los tests. */
export const clock = { now: () => Date.now() };

/** Un teléfono aporta con 7 días o más desde su primera atestación. Sin fila (token de desarrollo), solo fuera de prod. */
async function deviceIsOldEnough(env: Env, keyId: string, nowMs: number): Promise<boolean> {
  const row = await env.DB.prepare("SELECT created_at, revoked FROM attest_keys WHERE key_id = ?1")
    .bind(keyId)
    .first<{ created_at: number; revoked: number }>();
  if (!row) return allowsDevBypass(env);
  if (Number(row.revoked) !== 0) return false;
  return nowMs - Number(row.created_at) >= MIN_DEVICE_AGE_MS;
}

function parseItems(body: unknown): Contribution[] | null {
  if (!body || typeof body !== "object" || !Array.isArray((body as { items?: unknown }).items)) return null;
  const raw = (body as { items: unknown[] }).items;
  if (raw.length > WEEKLY_CAP) return null;
  const seen = new Set<string>();
  const out: Contribution[] = [];
  for (const entry of raw) {
    if (!entry || typeof entry !== "object") continue;
    const merchant = normalizeMerchant((entry as { merchant?: unknown }).merchant);
    const kind = normalizeKind((entry as { kind?: unknown }).kind);
    if (!merchant || !kind || seen.has(merchant)) continue;
    seen.add(merchant);
    out.push({ merchant, kind });
  }
  return out;
}

export async function handleComerciosAportes(c: Ctx): Promise<Response> {
  const claims = await requireSession(c);
  if (claims instanceof Response) return claims;

  let body: unknown;
  try {
    body = await c.req.json();
  } catch {
    return jsonError("yala_bad_request", "Cuerpo no válido.", 400);
  }
  const items = parseItems(body);
  if (!items) return jsonError("yala_bad_request", "Lote no válido.", 400);

  const now = clock.now();
  if (!(await deviceIsOldEnough(c.env, claims.keyId, now))) {
    console.log(`[cc] aportes status=too_new items=${items.length}`);
    return c.json({ status: "too_new", accepted: 0 });
  }
  const hash = await deviceHash(c.env.JWT_SIGNING_SECRET, claims.keyId);
  const accepted = await ingest(c.env.DB, hash, items, now);
  const status = accepted < items.length ? "capped" : "ok";
  console.log(`[cc] aportes status=${status} items=${items.length} accepted=${accepted}`);
  return c.json({ status, accepted });
}

export async function handleComerciosLista(c: Ctx): Promise<Response> {
  const claims = await requireSession(c);
  if (claims instanceof Response) return claims;

  const list = await todaysList(c.env.DB, c.env.KV, clock.now());
  const etag = `"${list.etag}"`;
  const headers = { etag, "cache-control": "private, max-age=3600" };
  if (c.req.header("If-None-Match") === etag) return new Response(null, { status: 304, headers });
  return new Response(list.body, { status: 200, headers: { "content-type": "application/json", ...headers } });
}
