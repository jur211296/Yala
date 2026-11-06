import type { Env } from "../env";

/**
 * D1 de los movimientos que la IA de la persona apunta por el conector (`migrations/0004_connector_drafts.sql`).
 *
 * El conector ya validó y resolvió todo contra los datos de la persona, pero aquí se vuelve a validar: es la frontera
 * del gateway, y lo que entra en la cola acaba en la Bandeja de la app.
 */

/** Movimientos apuntados por cuenta y día (UTC). Una persona apunta unos pocos al día; esto solo frena un bucle. */
export const CONNECTOR_DAILY_CAP = 50;
/** Movimientos esperando a la app. Con la app sin abrir semanas, la cola no crece sin fin. */
export const CONNECTOR_MAX_PENDING = 100;
export const CONNECTOR_DRAFT_TTL_MS = 30 * 24 * 3600 * 1000;

export const CONNECTOR_MAX_AMOUNT = 1_000_000_000;
export const CONNECTOR_MAX_TEXT = 80;

export interface ConnectorDraftPayload {
  kind: "expense" | "income";
  /** Siempre positivo; el signo lo pone `kind`. Dos decimales. */
  amount: number;
  /** ISO 4217 en mayúsculas, o `null` (la app usa la de la cuenta). */
  currency: string | null;
  /** Comercio o concepto. */
  note: string | null;
  /** AAAA-MM-DD, en el día de la persona. */
  date: string | null;
  /** `sync_id` (= `Account.shortcutID`) de la cuenta que la IA nombró, ya resuelto por el conector. */
  account_id: string | null;
  account_name: string | null;
  /** `sync_id` (= `Subcategory.shortcutID`) de la subcategoría, ya resuelta por el conector. */
  subcategory_id: string | null;
  subcategory_name: string | null;
  /** Qué IA lo apuntó («Claude», «ChatGPT», «Grok»), para la línea de evidencia del borrador. */
  client: string | null;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;
const CURRENCY_RE = /^[A-Z]{3}$/;

/** Texto corto y limpio: sin caracteres de control, espacios colapsados, recortado. Vacío → `null`; no texto → `undefined`. */
function cleanText(value: unknown, max: number): string | null | undefined {
  if (value === null || value === undefined) return null;
  if (typeof value !== "string") return undefined;
  // eslint-disable-next-line no-control-regex
  const text = value.replace(/[\u0000-\u001f\u007f-\u009f\u2028\u2029]/g, " ").replace(/\s+/g, " ").trim();
  if (text.length === 0) return null;
  return text.slice(0, max);
}

function cleanId(value: unknown): string | null | undefined {
  if (value === null || value === undefined) return null;
  return typeof value === "string" && UUID_RE.test(value) ? value.toLowerCase() : undefined;
}

/** El payload tal como se guarda, o `null` si algo no cuadra. Estricta: un campo malo invalida todo. */
export function validateConnectorPayload(raw: unknown): ConnectorDraftPayload | null {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  const r = raw as Record<string, unknown>;

  if (r.kind !== "expense" && r.kind !== "income") return null;
  if (typeof r.amount !== "number" || !Number.isFinite(r.amount)) return null;
  const amount = Math.round(r.amount * 100) / 100;
  if (amount <= 0 || amount > CONNECTOR_MAX_AMOUNT) return null;

  let currency: string | null = null;
  if (r.currency !== null && r.currency !== undefined) {
    if (typeof r.currency !== "string" || !CURRENCY_RE.test(r.currency)) return null;
    currency = r.currency;
  }

  let date: string | null = null;
  if (r.date !== null && r.date !== undefined) {
    if (typeof r.date !== "string" || !DAY_RE.test(r.date)) return null;
    const parsed = new Date(`${r.date}T00:00:00Z`);
    if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== r.date) return null;
    date = r.date;
  }

  const note = cleanText(r.note, CONNECTOR_MAX_TEXT);
  const accountName = cleanText(r.account_name, CONNECTOR_MAX_TEXT);
  const subcategoryName = cleanText(r.subcategory_name, CONNECTOR_MAX_TEXT);
  const client = cleanText(r.client, 40);
  const accountId = cleanId(r.account_id);
  const subcategoryId = cleanId(r.subcategory_id);
  if ([note, accountName, subcategoryName, client, accountId, subcategoryId].some((v) => v === undefined)) return null;

  return {
    kind: r.kind,
    amount,
    currency,
    note: note ?? null,
    date,
    account_id: accountId ?? null,
    account_name: accountName ?? null,
    subcategory_id: subcategoryId ?? null,
    subcategory_name: subcategoryName ?? null,
    client: client ?? null,
  };
}

export type EnqueueOutcome = { ok: true; id: string } | { ok: false; reason: "invalid" | "daily_cap" | "queue_full" };

/**
 * Deja un movimiento en la cola de la cuenta. El `userId` lo pone el conector con el `sub` de la sesión que ya verificó;
 * esta función solo se alcanza por la llamada interna entre Workers (`ConnectorDrafts`), nunca desde internet.
 */
export async function enqueueConnectorDraft(env: Env, userId: string, raw: unknown, now = Date.now()): Promise<EnqueueOutcome> {
  if (typeof userId !== "string" || !UUID_RE.test(userId)) return { ok: false, reason: "invalid" };
  const payload = validateConnectorPayload(raw);
  if (!payload) return { ok: false, reason: "invalid" };
  // Tal cual, sin normalizar: las rutas de la app leen con el `sub` del JWT, y tiene que ser el mismo texto.
  const user = userId;

  await env.DB.prepare("DELETE FROM connector_drafts WHERE user_id = ? AND created_at < ?")
    .bind(user, now - CONNECTOR_DRAFT_TTL_MS)
    .run();
  const pending = await env.DB.prepare("SELECT COUNT(*) AS n FROM connector_drafts WHERE user_id = ?").bind(user).first<{ n: number }>();
  if (Number(pending?.n ?? 0) >= CONNECTOR_MAX_PENDING) return { ok: false, reason: "queue_full" };

  const day = new Date(now).toISOString().slice(0, 10);
  await env.DB.prepare("INSERT OR IGNORE INTO connector_quota (user_id, day_key, day_count) VALUES (?, ?, 0)").bind(user, day).run();
  const counted = await env.DB.prepare(
    `UPDATE connector_quota
        SET day_count = CASE WHEN day_key = ?1 THEN day_count + 1 ELSE 1 END,
            day_key = ?1
      WHERE user_id = ?2 AND (day_key IS NOT ?1 OR day_count < ?3)`,
  )
    .bind(day, user, CONNECTOR_DAILY_CAP)
    .run();
  if ((counted.meta?.changes ?? 0) === 0) return { ok: false, reason: "daily_cap" };

  const id = crypto.randomUUID();
  await env.DB.prepare("INSERT INTO connector_drafts (id, user_id, created_at, payload) VALUES (?, ?, ?, ?)")
    .bind(id, user, now, JSON.stringify(payload))
    .run();
  return { ok: true, id };
}

export interface StoredConnectorDraft {
  id: string;
  created_at: number;
  payload: ConnectorDraftPayload;
}

/** Los movimientos de la cuenta, del más viejo al más nuevo. Los de más de 30 días se borran antes de leer. */
export async function listConnectorDrafts(env: Env, userId: string, now = Date.now()): Promise<StoredConnectorDraft[]> {
  await env.DB.prepare("DELETE FROM connector_drafts WHERE user_id = ? AND created_at < ?")
    .bind(userId, now - CONNECTOR_DRAFT_TTL_MS)
    .run();
  const res = await env.DB.prepare("SELECT id, created_at, payload FROM connector_drafts WHERE user_id = ? ORDER BY created_at LIMIT 100")
    .bind(userId)
    .all<{ id: string; created_at: number; payload: string }>();
  const out: StoredConnectorDraft[] = [];
  for (const row of res.results ?? []) {
    try {
      const payload = validateConnectorPayload(JSON.parse(row.payload));
      if (payload) out.push({ id: row.id, created_at: row.created_at, payload });
    } catch {
      // Una fila ilegible no tumba la lista; se va con el TTL.
    }
  }
  return out;
}

/** Borra los que la app ya creó. Solo los de ESTA cuenta: un id ajeno no hace nada. */
export async function ackConnectorDrafts(env: Env, userId: string, ids: string[]): Promise<number> {
  if (ids.length === 0) return 0;
  const stmts = ids.map((id) => env.DB.prepare("DELETE FROM connector_drafts WHERE id = ? AND user_id = ?").bind(id, userId));
  const results = await env.DB.batch(stmts);
  return results.reduce((n, r) => n + (r.meta?.changes ?? 0), 0);
}

/** Borrado de cuenta: cola y contador. Lo llama `/account/delete`. */
export async function deleteConnectorData(env: Env, userId: string): Promise<void> {
  await env.DB.batch([
    env.DB.prepare("DELETE FROM connector_drafts WHERE user_id = ?").bind(userId),
    env.DB.prepare("DELETE FROM connector_quota WHERE user_id = ?").bind(userId),
  ]);
}
