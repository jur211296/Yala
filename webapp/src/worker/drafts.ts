/**
 * «Apuntar» desde la web: el gasto entra en la cola COMÚN de borradores (decisión D9), la misma del correo del banco:
 * la tabla `mail_drafts` del D1 del gateway (`gateway/migrations/0003_mail_forwarding.sql`). El iPhone la recoge con
 * `GET /mail/drafts`, la pasa a su Bandeja y la confirma (`ack`), y el gateway borra lo confirmado. La web no escribe
 * en la sincronización: quien escribe sigue siendo el iPhone (lote 1 del plan).
 *
 * La fila lleva la forma del payload del correo (`DraftPayload` de `gateway/src/mail/store.ts`), más:
 * - `source: "web"`: el iPhone lo distingue del correo (origen y evidencia «Yala web»);
 * - `account_ref` / `subcategory_ref`: la cuenta y la subcategoría elegidas, por su `sync_id`. Un id que no es de la
 *   persona no casa con nada en su iPhone: no hace falta comprobarlo aquí.
 *
 * Lo que la cola ya da: caducidad de 30 días (`listDrafts`), borrado con la cuenta (`deleteMailData`) y el `ack`.
 * Lo que pone la web: un tope de borradores por cuenta y día (sin App Attest, la defensa es el límite). Lo cuenta el
 * objeto de la lista de sesiones de la cuenta (`takeDraftSlot`), no la cola: el `ack` del iPhone borra de la cola lo
 * recogido, y contar ahí dejaría el cupo en cero cada vez que el iPhone abre.
 */
import type { Env } from "./env";
import { STATIC_RATES_PER_USD } from "../../../shared-core/src/logic/fx-static";

export const WEB_DRAFTS_PER_DAY = 30;
const DAY_MS = 86_400_000;
/** Lo que la cola guarda (`DRAFT_TTL_MS` del gateway): más viejo, el iPhone ya no lo recibe. */
const QUEUE_TTL_MS = 30 * DAY_MS;
/** Las divisas que la app reconoce (las de `CurrencyCode`, espejadas en el núcleo). */
const KNOWN_CURRENCIES = new Set(Object.keys(STATIC_RATES_PER_USD));
/** Controles y marcas de dirección (U+202E y compañía): una descripción no los necesita y pueden falsear lo que se ve. */
const UNSAFE_CHARS = /[\p{Cc}\u200E\u200F\u202A-\u202E\u2066-\u2069]/gu;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAY_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

export interface WebDraftInput {
  tipo: "gasto" | "ingreso";
  importe: number;
  divisa: string;
  descripcion: string;
  fecha: string;
  cuenta: string | null;
  subcategoria: string | null;
}

export type Parsed = { ok: true; value: WebDraftInput } | { ok: false; campo: string };

function validDay(raw: string, nowMs: number): boolean {
  const m = DAY_RE.exec(raw);
  if (!m) return false;
  const t = Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  if (Number.isNaN(t) || new Date(t).toISOString().slice(0, 10) !== raw) return false;
  // Como el iPhone (`BankEmailDraftLogic.date`, que cambia por la de llegada lo que cae más de un día después): hasta
  // mañana, por la zona horaria de quien apunta. Y nada de hace más de 10 años.
  return t <= nowMs + DAY_MS && t >= nowMs - 3650 * DAY_MS;
}

/** Valida el cuerpo de `POST /api/borradores`. Devuelve el primer campo que no vale, para que la página lo marque. */
export function parseWebDraft(body: unknown, nowMs: number): Parsed {
  if (!body || typeof body !== "object") return { ok: false, campo: "cuerpo" };
  const b = body as Record<string, unknown>;
  const tipo = b.tipo === "ingreso" ? "ingreso" : b.tipo === "gasto" || b.tipo === undefined ? "gasto" : null;
  if (!tipo) return { ok: false, campo: "tipo" };
  // Se valida ya redondeado: 0,001 no es un importe.
  const importe = typeof b.importe === "number" && Number.isFinite(b.importe) ? Math.round(b.importe * 100) / 100 : Number.NaN;
  if (!Number.isFinite(importe) || importe <= 0 || importe > 1_000_000_000) return { ok: false, campo: "importe" };
  const divisa = typeof b.divisa === "string" ? b.divisa.trim().toUpperCase() : "";
  if (!/^[A-Z]{3}$/.test(divisa) || !KNOWN_CURRENCIES.has(divisa)) return { ok: false, campo: "divisa" };
  const descripcion = typeof b.descripcion === "string" ? b.descripcion.replace(UNSAFE_CHARS, "").replace(/\s+/g, " ").trim() : "";
  if (descripcion.length > 120) return { ok: false, campo: "descripcion" };
  const fecha = typeof b.fecha === "string" ? b.fecha : "";
  if (!validDay(fecha, nowMs)) return { ok: false, campo: "fecha" };
  const cuenta = b.cuenta == null || b.cuenta === "" ? null : typeof b.cuenta === "string" && UUID_RE.test(b.cuenta) ? b.cuenta.toLowerCase() : undefined;
  if (cuenta === undefined) return { ok: false, campo: "cuenta" };
  const sub =
    b.subcategoria == null || b.subcategoria === "" ? null : typeof b.subcategoria === "string" && UUID_RE.test(b.subcategoria) ? b.subcategoria.toLowerCase() : undefined;
  if (sub === undefined) return { ok: false, campo: "subcategoria" };
  return { ok: true, value: { tipo, importe, divisa, descripcion, fecha, cuenta, subcategoria: sub } };
}

function draftPayload(d: WebDraftInput) {
  return {
    kind: d.tipo === "ingreso" ? "income" : "expense",
    amount: d.importe,
    currency: d.divisa,
    merchant: d.descripcion || null,
    date: d.fecha,
    bank: null,
    account_last4: null,
    source: "web",
    account_ref: d.cuenta,
    subcategory_ref: d.subcategoria,
  };
}

export async function insertWebDraft(env: Env, userId: string, d: WebDraftInput, nowMs: number): Promise<string> {
  const id = crypto.randomUUID();
  await env.DRAFTS_DB.prepare("INSERT INTO mail_drafts (id, user_id, created_at, payload) VALUES (?, ?, ?, ?)")
    .bind(id, userId, nowMs, JSON.stringify(draftPayload(d)))
    .run();
  return id;
}

/**
 * Lote 3: editar o descartar un borrador que la web dejó y el iPhone AÚN NO RECOGIÓ. Solo los de esta cuenta, con
 * `source = web` y dentro de la caducidad de la cola. El iPhone borra lo que confirma (`ack`), así que «no está» es
 * «ya lo recogió» (o caducó): `false`, y la página lo dice.
 *
 * Se edita EN SITIO, con el mismo `id` y la misma fecha de alta: el iPhone deduplica por `id`, y uno nuevo podría
 * acabar dos veces en su Bandeja. Ventana aceptada: si el iPhone ya bajó el borrador y aún no lo confirmó (segundos,
 * dentro de un mismo ciclo), le llega la versión que bajó.
 */
export async function editWebDraft(env: Env, userId: string, id: string, d: WebDraftInput, nowMs: number): Promise<boolean | "entrada"> {
  if (!UUID_RE.test(id)) return "entrada";
  const res = await env.DRAFTS_DB.prepare(
    "UPDATE mail_drafts SET payload = ? WHERE id = ? AND user_id = ? AND created_at > ? AND json_extract(payload, '$.source') = 'web'",
  )
    .bind(JSON.stringify(draftPayload(d)), id.toLowerCase(), userId, nowMs - QUEUE_TTL_MS)
    .run();
  return (res.meta?.changes ?? 0) > 0;
}

export async function discardWebDraft(env: Env, userId: string, id: string, nowMs: number): Promise<boolean | "entrada"> {
  if (!UUID_RE.test(id)) return "entrada";
  const res = await env.DRAFTS_DB.prepare(
    "DELETE FROM mail_drafts WHERE id = ? AND user_id = ? AND created_at > ? AND json_extract(payload, '$.source') = 'web'",
  )
    .bind(id.toLowerCase(), userId, nowMs - QUEUE_TTL_MS)
    .run();
  return (res.meta?.changes ?? 0) > 0;
}

export interface QueuedWebDraft {
  id: string;
  enviado: number;
  tipo: "gasto" | "ingreso";
  importe: number;
  divisa: string;
  descripcion: string | null;
  fecha: string | null;
  /** Lo que se eligió al apuntarlo, para poder editarlo (lote 3). */
  cuenta: string | null;
  subcategoria: string | null;
}

/** Lo que la web mandó y el iPhone todavía no recogió (y aún puede recoger): «esperando a tu iPhone». */
export async function queuedWebDrafts(env: Env, userId: string, nowMs: number): Promise<QueuedWebDraft[]> {
  const res = await env.DRAFTS_DB.prepare(
    "SELECT id, created_at, payload FROM mail_drafts WHERE user_id = ? AND created_at > ? AND json_extract(payload, '$.source') = 'web' ORDER BY created_at DESC LIMIT 50",
  )
    .bind(userId, nowMs - QUEUE_TTL_MS)
    .all<{ id: string; created_at: number; payload: string }>();
  const out: QueuedWebDraft[] = [];
  for (const r of res.results ?? []) {
    try {
      const p = JSON.parse(r.payload) as {
        kind?: string;
        amount?: number;
        currency?: string;
        merchant?: string | null;
        date?: string | null;
        account_ref?: string | null;
        subcategory_ref?: string | null;
      };
      out.push({
        id: r.id,
        enviado: r.created_at,
        tipo: p.kind === "income" ? "ingreso" : "gasto",
        importe: typeof p.amount === "number" ? p.amount : 0,
        divisa: typeof p.currency === "string" ? p.currency : "",
        descripcion: p.merchant ?? null,
        fecha: p.date ?? null,
        cuenta: typeof p.account_ref === "string" ? p.account_ref : null,
        subcategoria: typeof p.subcategory_ref === "string" ? p.subcategory_ref : null,
      });
    } catch {
      // Una fila ilegible no tumba la lista; se va con la caducidad de la cola.
    }
  }
  return out;
}
