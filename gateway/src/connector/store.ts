import type { Env } from "../env";
import { findPossibleDuplicates, type DuplicateMatch, type IncomingDraft, type MatchCandidate } from "./match";

/**
 * Lo que la IA de la persona apunta por el conector entra en la cola COMÚN de borradores (decisión D9 del plan de Yala
 * web): la tabla `mail_drafts` del correo del banco (`migrations/0003_mail_forwarding.sql`), con `source: "ai"`. El
 * iPhone la recoge con `GET /mail/drafts` junto a lo del correo y lo de la web, la pasa a su Bandeja y la confirma
 * (`ack`). La caducidad de 30 días, el `ack` y el borrado con la cuenta los pone la cola (`mail/store.ts`).
 *
 * Lo propio del conector: la validación de frontera y dos techos. El diario va en `connector_quota`
 * (`migrations/0004_connector_quota.sql`) y no en la cola, porque el `ack` del iPhone la vacía.
 *
 * El conector ya validó y resolvió todo contra los datos de la persona, pero aquí se vuelve a validar: es la frontera
 * del gateway, y lo que entra en la cola acaba en la Bandeja de la app.
 */

/** El `source` de lo que apunta la IA en la cola común (`AIConnectorDraftLogic.source` en la app). */
export const CONNECTOR_SOURCE = "ai";

/** Movimientos apuntados por cuenta y día (UTC). Una persona apunta unos pocos al día; esto solo frena un bucle. */
export const CONNECTOR_DAILY_CAP = 50;
/** Movimientos esperando a la app. Con la app sin abrir semanas, la cola no crece sin fin. */
export const CONNECTOR_MAX_PENDING = 100;
/** Lo que la cola común guarda un borrador (`DRAFT_TTL_MS` de `mail/store.ts`): más viejo no cuenta en la cola. */
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

/**
 * Lo que el conector manda además del movimiento (lote 5 de «Bandeja sin duplicados», 2026-11-24). Sin este objeto, el
 * `enqueue` se comporta como antes: ni referencia ni comprobación. Así un conector anterior contra este gateway no cambia.
 */
export interface EnqueueOptions {
  /** Llave de idempotencia por cuenta (el id del correo, por ejemplo). Repetida, no crea nada. */
  referencia: string | null;
  /** Crear aunque se parezca a algo: la IA ya preguntó y el usuario dijo que es otro movimiento. */
  forzar: boolean;
  /** Los pendientes de la Bandeja y los movimientos recientes que el conector leyó con la sesión de la persona. */
  candidatos: MatchCandidate[];
}

/** La referencia se recuerda 90 días: lo bastante para un correo releído semanas después. */
export const CONNECTOR_REF_TTL_MS = 90 * 24 * 3600 * 1000;
export const CONNECTOR_MAX_REF = 200;
/** Pendientes de la Bandeja (200 como mucho) más los movimientos de una semana. Frena un payload desmedido. */
export const CONNECTOR_MAX_CANDIDATES = 1000;

const PLACES = new Set(["cola", "bandeja", "guardado"]);

function validateCandidate(raw: unknown): MatchCandidate | null {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  const r = raw as Record<string, unknown>;
  if (typeof r.donde !== "string" || !PLACES.has(r.donde)) return null;
  if (r.kind !== "expense" && r.kind !== "income") return null;
  if (typeof r.amount !== "number" || !Number.isFinite(r.amount) || r.amount < 0) return null;
  if (r.currency !== null && (typeof r.currency !== "string" || !CURRENCY_RE.test(r.currency))) return null;
  if (r.day !== null && (typeof r.day !== "string" || !DAY_RE.test(r.day))) return null;
  const fuente = cleanText(r.fuente, 60);
  const accountId = cleanText(r.account_id, 64);
  const accountName = cleanText(r.account_name, CONNECTOR_MAX_TEXT);
  const merchant = cleanText(r.merchant, CONNECTOR_MAX_TEXT);
  if (!fuente || [accountId, accountName, merchant].some((v) => v === undefined)) return null;
  return {
    donde: r.donde as MatchCandidate["donde"],
    fuente,
    kind: r.kind,
    amount: Math.round(r.amount * 100) / 100,
    currency: r.currency as string | null,
    day: r.day as string | null,
    account_id: accountId ?? null,
    account_name: accountName ?? null,
    merchant: merchant ?? null,
  };
}

/** Las opciones tal como se usan, `undefined` si no vinieron (comportamiento de antes), o `null` si algo no cuadra. */
export function validateEnqueueOptions(raw: unknown): EnqueueOptions | null | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== "object" || Array.isArray(raw)) return null;
  const r = raw as Record<string, unknown>;

  let referencia: string | null = null;
  if (r.referencia !== undefined && r.referencia !== null) {
    if (typeof r.referencia !== "string") return null;
    // eslint-disable-next-line no-control-regex
    const text = r.referencia.replace(/[\u0000-\u001f\u007f-\u009f\u2028\u2029]/g, "").trim();
    if (text.length > CONNECTOR_MAX_REF) return null;
    referencia = text.length > 0 ? text : null;
  }
  if (r.forzar !== undefined && typeof r.forzar !== "boolean") return null;

  const candidatos: MatchCandidate[] = [];
  if (r.candidatos !== undefined) {
    if (!Array.isArray(r.candidatos) || r.candidatos.length > CONNECTOR_MAX_CANDIDATES) return null;
    for (const c of r.candidatos) {
      const ok = validateCandidate(c);
      if (!ok) return null;
      candidatos.push(ok);
    }
  }
  return { referencia, forzar: r.forzar === true, candidatos };
}

export type EnqueueOutcome =
  | { ok: true; id: string }
  /** La referencia ya había creado un borrador: no se creó otro ni se gastó cupo. `first_at` es cuándo (epoch ms). */
  | { ok: true; id: string; repeated: true; first_at: number }
  | { ok: false; reason: "invalid" | "daily_cap" | "queue_full" }
  | { ok: false; reason: "possible_duplicate"; matches: DuplicateMatch[] };

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function findRef(env: Env, user: string, refHash: string, now: number): Promise<{ draft_id: string; created_at: number } | null> {
  return env.DB.prepare("SELECT draft_id, created_at FROM connector_refs WHERE user_id = ? AND ref_hash = ? AND created_at > ?")
    .bind(user, refHash, now - CONNECTOR_REF_TTL_MS)
    .first<{ draft_id: string; created_at: number }>();
}

/** Una fila de la cola común, sea de quien sea (correo, web o IA), tal como la guarda cada escritor. */
interface QueueRowPayload {
  kind?: unknown;
  amount?: unknown;
  currency?: unknown;
  merchant?: unknown;
  date?: unknown;
  source?: unknown;
  client?: unknown;
  account_ref?: unknown;
  account_name?: unknown;
  subcategory_ref?: unknown;
  subcategory_name?: unknown;
  bank?: unknown;
  account_last4?: unknown;
}

const str = (v: unknown): string | null => (typeof v === "string" && v.trim() !== "" ? v : null);

/** La fuente de una fila de la cola en la regla de coincidencia: la IA es `ai:<IA>`, para que otra IA cuente como otra. */
export function queueFuente(p: QueueRowPayload): string {
  if (p.source === CONNECTOR_SOURCE) return `ai:${str(p.client) ?? ""}`;
  if (p.source === "web") return "web";
  return "correo";
}

async function queueRows(env: Env, user: string, now: number): Promise<{ id: string; created_at: number; payload: QueueRowPayload }[]> {
  const res = await env.DB.prepare("SELECT id, created_at, payload FROM mail_drafts WHERE user_id = ? AND created_at > ? ORDER BY created_at LIMIT 200")
    .bind(user, now - CONNECTOR_DRAFT_TTL_MS)
    .all<{ id: string; created_at: number; payload: string }>();
  const out: { id: string; created_at: number; payload: QueueRowPayload }[] = [];
  for (const row of res.results ?? []) {
    try {
      const payload = JSON.parse(row.payload) as unknown;
      if (payload && typeof payload === "object" && !Array.isArray(payload)) out.push({ id: row.id, created_at: row.created_at, payload: payload as QueueRowPayload });
    } catch {
      // Una fila ilegible no tumba la comprobación; se va con el TTL, como en `listDrafts`.
    }
  }
  return out;
}

/** Una fila de la cola como candidata. Sin día (un correo sin fecha), el de llegada en UTC: la regla da ±3 días de margen. */
function queueCandidate(row: { created_at: number; payload: QueueRowPayload }): MatchCandidate | null {
  const p = row.payload;
  const amount = typeof p.amount === "number" && Number.isFinite(p.amount) ? Math.abs(p.amount) : null;
  if (amount === null || amount === 0) return null;
  const date = str(p.date);
  return {
    donde: "cola",
    fuente: queueFuente(p),
    kind: p.kind === "income" ? "income" : "expense",
    amount,
    currency: str(p.currency)?.toUpperCase() ?? null,
    day: date && DAY_RE.test(date) ? date : new Date(row.created_at).toISOString().slice(0, 10),
    account_id: str(p.account_ref),
    account_name: str(p.account_name),
    merchant: str(p.merchant),
  };
}

/**
 * Deja un movimiento en la cola de la cuenta. El `userId` lo pone el conector con el `sub` de la sesión que ya verificó;
 * esta función solo se alcanza por la llamada interna entre Workers (`ConnectorDrafts`), nunca desde internet.
 *
 * Con `options` (conector desde el 2026-11-24), en este orden:
 * 1. una `referencia` ya usada devuelve el borrador de entonces, sin crear ni gastar cupo (antes que todo: si no, la
 *    segunda llamada chocaría con su propio borrador como «posible duplicado»);
 * 2. sin `forzar`, lo que se parezca en la cola, la Bandeja o lo guardado devuelve `possible_duplicate`, sin crear;
 * 3. la referencia se reserva ANTES de crear: dos llamadas a la vez con la misma dejan un solo borrador.
 */
export async function enqueueConnectorDraft(
  env: Env,
  userId: string,
  raw: unknown,
  now = Date.now(),
  rawOptions?: unknown,
): Promise<EnqueueOutcome> {
  if (typeof userId !== "string" || !UUID_RE.test(userId)) return { ok: false, reason: "invalid" };
  const payload = validateConnectorPayload(raw);
  if (!payload) return { ok: false, reason: "invalid" };
  const options = validateEnqueueOptions(rawOptions);
  if (options === null) return { ok: false, reason: "invalid" };
  // Tal cual, sin normalizar: las rutas de la app leen con el `sub` del JWT, y tiene que ser el mismo texto.
  const user = userId;

  const refHash = options?.referencia ? await sha256Hex(options.referencia) : null;
  if (refHash) {
    const seen = await findRef(env, user, refHash, now);
    if (seen) return { ok: true, id: seen.draft_id, repeated: true, first_at: seen.created_at };
  }

  const pending = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM mail_drafts WHERE user_id = ? AND created_at > ? AND json_extract(payload, '$.source') = ?",
  )
    .bind(user, now - CONNECTOR_DRAFT_TTL_MS, CONNECTOR_SOURCE)
    .first<{ n: number }>();
  if (Number(pending?.n ?? 0) >= CONNECTOR_MAX_PENDING) return { ok: false, reason: "queue_full" };

  if (options && !options.forzar) {
    const incoming: IncomingDraft = {
      fuente: `ai:${payload.client ?? ""}`,
      kind: payload.kind,
      amount: payload.amount,
      currency: payload.currency,
      day: payload.date ?? new Date(now).toISOString().slice(0, 10),
      account_id: payload.account_id,
      account_name: payload.account_name,
      merchant: payload.note,
    };
    const fromQueue = (await queueRows(env, user, now)).map(queueCandidate).filter((c): c is MatchCandidate => c !== null);
    const matches = findPossibleDuplicates(incoming, [...fromQueue, ...options.candidatos]);
    if (matches.length > 0) return { ok: false, reason: "possible_duplicate", matches };
  }

  const id = crypto.randomUUID();
  if (refHash) {
    await env.DB.prepare("DELETE FROM connector_refs WHERE user_id = ? AND created_at <= ?").bind(user, now - CONNECTOR_REF_TTL_MS).run();
    const claimed = await env.DB.prepare("INSERT OR IGNORE INTO connector_refs (user_id, ref_hash, draft_id, created_at) VALUES (?, ?, ?, ?)")
      .bind(user, refHash, id, now)
      .run();
    if ((claimed.meta?.changes ?? 0) === 0) {
      // Otra llamada con la misma referencia ganó la carrera entre la lectura y aquí: su borrador es el bueno.
      const winner = await findRef(env, user, refHash, now);
      if (winner) return { ok: true, id: winner.draft_id, repeated: true, first_at: winner.created_at };
      return { ok: false, reason: "invalid" };
    }
  }
  const release = async () => {
    if (refHash) await env.DB.prepare("DELETE FROM connector_refs WHERE user_id = ? AND ref_hash = ? AND draft_id = ?").bind(user, refHash, id).run();
  };

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
  if ((counted.meta?.changes ?? 0) === 0) {
    await release();
    return { ok: false, reason: "daily_cap" };
  }

  try {
    await env.DB.prepare("INSERT INTO mail_drafts (id, user_id, created_at, payload) VALUES (?, ?, ?, ?)")
      .bind(id, user, now, JSON.stringify(commonQueuePayload(payload)))
      .run();
  } catch (err) {
    // Sin borrador, la referencia no puede quedar reservada: el reintento de la IA volvería como «ya apuntado».
    await release();
    throw err;
  }
  return { ok: true, id };
}

/** Lo que espera en la cola a que la app lo recoja, para `ver_bandeja`. Sin ids: la IA no tiene nada que hacer con ellos. */
export interface QueuedDraftView {
  fuente: "correo" | "web" | "ia";
  /** Qué IA lo apuntó, si fue una. */
  ia: string | null;
  kind: "expense" | "income";
  amount: number;
  currency: string | null;
  merchant: string | null;
  date: string | null;
  account_ref: string | null;
  account_name: string | null;
  subcategory_ref: string | null;
  subcategory_name: string | null;
  bank: string | null;
  account_last4: string | null;
  /** Cuándo llegó a la cola, ISO. */
  created_at: string;
}

/** La cola de la cuenta en solo lectura (sin purgar: eso lo hace la recogida de la app), del más nuevo al más viejo. */
export async function listQueuedForConnector(env: Env, userId: string, now = Date.now()): Promise<QueuedDraftView[] | null> {
  if (typeof userId !== "string" || !UUID_RE.test(userId)) return null;
  const rows = await queueRows(env, userId, now);
  const out: QueuedDraftView[] = [];
  for (const row of rows) {
    const p = row.payload;
    const amount = typeof p.amount === "number" && Number.isFinite(p.amount) ? Math.abs(p.amount) : null;
    if (amount === null) continue;
    const fuente = queueFuente(p);
    out.push({
      fuente: fuente.startsWith("ai:") ? "ia" : (fuente as "correo" | "web"),
      ia: fuente.startsWith("ai:") ? str(p.client) : null,
      kind: p.kind === "income" ? "income" : "expense",
      amount,
      currency: str(p.currency)?.toUpperCase() ?? null,
      merchant: str(p.merchant),
      date: str(p.date),
      account_ref: str(p.account_ref),
      account_name: str(p.account_name),
      subcategory_ref: str(p.subcategory_ref),
      subcategory_name: str(p.subcategory_name),
      bank: str(p.bank),
      account_last4: str(p.account_last4),
      created_at: new Date(row.created_at).toISOString(),
    });
  }
  return out.reverse();
}

/**
 * La fila de la cola común: la forma del correo (`DraftPayload` de `mail/store.ts`) con `merchant` = la nota, más lo
 * que distingue a la IA. La cuenta y la subcategoría van como en la web (`account_ref`/`subcategory_ref`, su `sync_id`)
 * y además por su nombre, por si el id no casa en el iPhone (aún sin bajar).
 */
export function commonQueuePayload(p: ConnectorDraftPayload) {
  return {
    kind: p.kind,
    amount: p.amount,
    currency: p.currency,
    merchant: p.note,
    date: p.date,
    bank: null,
    account_last4: null,
    source: CONNECTOR_SOURCE,
    account_ref: p.account_id,
    subcategory_ref: p.subcategory_id,
    account_name: p.account_name,
    subcategory_name: p.subcategory_name,
    client: p.client,
  };
}

/** Borrado de cuenta: el contador diario y las referencias. La cola la vacía `deleteMailData`. Lo llama `/account/delete`. */
export async function deleteConnectorData(env: Env, userId: string): Promise<void> {
  // Dos órdenes sueltas, no un lote: un lote de D1 es una transacción, y un gateway desplegado antes que su migración
  // 0007 desharía también el borrado del contador.
  await env.DB.prepare("DELETE FROM connector_quota WHERE user_id = ?").bind(userId).run();
  await env.DB.prepare("DELETE FROM connector_refs WHERE user_id = ?").bind(userId).run();
}
