import type { Context } from "hono";
import type { Env } from "../env";
import { jsonError } from "../errors";
import { requireUserAndAttest } from "../groups/routes";
import { ackConnectorDrafts, listConnectorDrafts } from "./store";

/**
 * Rutas de la app para los movimientos que apuntó la IA de la persona por el conector (`mcp/`). Guard:
 * `requireUserAndAttest` (datos financieros personales, como `/mail/*`); el `user_id` sale SIEMPRE del JWT.
 *
 *   GET  /connector/drafts      → los movimientos que esperan a la app.
 *   POST /connector/drafts/ack  → {ids:[…]} la app ya los creó en su Bandeja: se borran del servidor.
 *
 * Encolar NO tiene ruta: solo el conector lo hace, por la llamada interna `ConnectorDrafts.enqueue` (entrypoint.ts).
 */
type Ctx = Context<{ Bindings: Env }>;

export async function handleConnectorDrafts(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;
  const drafts = await listConnectorDrafts(c.env, auth.sub);
  return c.json({
    drafts: drafts.map((d) => ({ id: d.id, received_at_ms: d.created_at, ...d.payload })),
  });
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function handleConnectorDraftsAck(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;
  let body: { ids?: unknown };
  try {
    body = await c.req.json();
  } catch {
    return jsonError("yala_bad_request", "JSON inválido", 400);
  }
  const ids = Array.isArray(body.ids)
    ? body.ids.filter((x): x is string => typeof x === "string" && UUID_RE.test(x)).map((x) => x.toLowerCase())
    : [];
  if (ids.length === 0 || ids.length > 100) return jsonError("yala_bad_request", "ids inválidos (1-100 UUID)", 400);
  const deleted = await ackConnectorDrafts(c.env, auth.sub, ids);
  return c.json({ deleted });
}
