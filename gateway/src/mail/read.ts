import { ADAPTERS } from "../ai/providers";
import type { AdapterContext, Usage } from "../ai/providers/types";
import type { ManagedRoute } from "../ai/routes";

/**
 * Lectura con IA de un aviso del banco reenviado.
 *
 * Vive fuera de `gateway/src/ai/` (decisión de Jürgen del 2026-11-04, opción B: el control del coste, S1, tenía esa
 * carpeta). Reconciliado con S1 al rebasar el mismo día: **su tope** — toda llamada de chat sale con
 * `maxOutputTokens` (aquí 400, el JSON de un movimiento cabe en ~120) — y **su registro de uso**: `email.ts` deja una
 * fila por lectura en `yala_ai_usage` con `recordUsage`, tarea `mail.read`, cubo `mail`.
 *
 * NO está en `TASKS`/`ROUTES` a propósito: esa tabla es también la lista de lo que la app puede pedir por el proxy con
 * `X-Yala-Task`, y la lectura del correo solo la lanza el servidor. Si algún día entra, como `deducedOnly`.
 *
 * Llama al adaptador de OpenAI que ya usa el proxy (`ai/providers`): mismo proveedor que la política de privacidad
 * nombra, sin proveedor nuevo.
 */
/** Tope propio de la lectura del correo: el JSON de un movimiento cabe en ~120 tokens; 400 deja margen al razonamiento. */
export const MAIL_READ_MAX_OUTPUT_TOKENS = 400;

export const MAIL_READ_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["is_transaction", "kind", "amount", "currency", "merchant", "date", "bank", "account_last4"],
  properties: {
    is_transaction: { type: "boolean" },
    kind: { type: ["string", "null"], enum: ["expense", "income", null] },
    amount: { type: ["number", "null"] },
    currency: { type: ["string", "null"] },
    merchant: { type: ["string", "null"] },
    date: { type: ["string", "null"] },
    bank: { type: ["string", "null"] },
    account_last4: { type: ["string", "null"] },
  },
} as const;

export const MAIL_READ_ROUTE: ManagedRoute = {
  mode: "managed",
  provider: "openai",
  // El mismo modelo que la lectura de una frase (`text.parse`), medido en su banco para sacar importe, divisa y comercio.
  model: "gpt-6-luna",
  params: {
    reasoningEffort: "low",
    responseFormat: "json_object",
    jsonSchema: { name: "bank_email", schema: MAIL_READ_SCHEMA as unknown as Record<string, unknown> },
    strictSchema: true,
    maxOutputTokens: MAIL_READ_MAX_OUTPUT_TOKENS,
  },
  retries: 0,
};

export const MAIL_READ_SYSTEM_PROMPT = [
  "Lees avisos de bancos y billeteras de Perú que una persona se reenvía a sí misma (BCP, Interbank, BBVA, Scotiabank,",
  "BanBif, Pichincha, Falabella, Ripley, Mibanco, Caja Arequipa, Caja Huancayo, Yape, Plin y otros). Devuelve SOLO un JSON",
  "con el esquema pedido.",
  "",
  "Reglas:",
  "- is_transaction es true solo si el correo informa de UN movimiento ya hecho: una compra, un consumo con tarjeta, un",
  "  retiro, una transferencia enviada o recibida, un pago de servicio, un depósito o un abono. Es false para promociones,",
  "  estados de cuenta, avisos de seguridad, códigos de verificación, recordatorios de pago y cualquier otra cosa.",
  "- kind: expense si sale dinero de la persona (compra, consumo, retiro, pago, transferencia enviada); income si entra",
  "  (abono, depósito, transferencia recibida, devolución). null si is_transaction es false.",
  "- amount: el importe del movimiento, positivo, con punto decimal (S/ 1,250.50 → 1250.5). Nunca el saldo disponible,",
  "  el límite de crédito ni una comisión aparte.",
  "- currency: código ISO 4217. «S/», «S/.», «soles» o «PEN» → PEN. «US$», «$», «USD» o «dólares» → USD. Otro símbolo",
  "  inequívoco, su código. null si no se dice.",
  "- merchant: el comercio o la persona de la otra parte, tal como lo escribe el aviso, sin el texto de alrededor.",
  "  null si no lo dice.",
  "- date: la fecha del movimiento como YYYY-MM-DD. null si no la dice.",
  "- bank: el banco o la billetera que manda el aviso (p. ej. «BCP», «Interbank», «Yape»). null si no se sabe.",
  "- account_last4: los 4 últimos dígitos de la tarjeta o la cuenta del movimiento si el aviso los trae (****1234 → «1234»).",
  "  null si no.",
  "- Si el correo es un reenvío, lee el aviso original que va dentro e ignora la cabecera del reenvío.",
  "- No inventes: un dato que no está en el correo es null.",
].join("\n");

export interface MailReading {
  isTransaction: boolean;
  kind: "expense" | "income" | null;
  amount: number | null;
  currency: string | null;
  merchant: string | null;
  date: string | null;
  bank: string | null;
  accountLast4: string | null;
}

/** Lo que el registro de uso de S1 necesita de la llamada (nunca contenido). */
export interface ReadCall {
  status: number;
  usage: Usage | null;
  model: string | null;
  finishReason: string | null;
  attempts: number;
}

export type ReadOutcome =
  | { ok: true; reading: MailReading; usage: Usage | null; call?: ReadCall }
  /** `providerFailed`: 5xx, 429, 408 o red. El uso del cupo se devuelve (molde de `refundQuota` del proxy). */
  | { ok: false; providerFailed: boolean; status: number; call?: ReadCall };

export async function readBankEmail(text: string, ctx: AdapterContext, today: string): Promise<ReadOutcome> {
  const body = {
    messages: [
      { role: "system", content: `${MAIL_READ_SYSTEM_PROMPT}\n\nHoy es ${today}.` },
      { role: "user", content: text },
    ],
  };
  const result = await ADAPTERS[MAIL_READ_ROUTE.provider].send(body, MAIL_READ_ROUTE, ctx);
  const call: ReadCall = {
    status: result.status,
    usage: result.usage,
    model: result.model,
    finishReason: result.finishReason ?? null,
    attempts: result.attempts,
  };
  if (result.status < 200 || result.status >= 300) {
    const providerFailed = result.status >= 500 || result.status === 429 || result.status === 408;
    return { ok: false, providerFailed, status: result.status, call };
  }
  const reading = parseReading(contentOf(result.body));
  if (!reading) return { ok: false, providerFailed: false, status: 422, call };
  return { ok: true, reading, usage: result.usage, call };
}

function contentOf(body: string): string {
  try {
    const json = JSON.parse(body) as { choices?: { message?: { content?: string | null } }[] };
    return json.choices?.[0]?.message?.content ?? "";
  } catch {
    return "";
  }
}

const ISO_CURRENCY = /^[A-Z]{3}$/;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
const LAST4 = /^\d{4}$/;

/** Valida y normaliza lo que contestó el modelo. Un campo que no casa con su forma se trata como no dicho. */
export function parseReading(content: string): MailReading | null {
  let raw: Record<string, unknown>;
  try {
    raw = JSON.parse(content) as Record<string, unknown>;
  } catch {
    return null;
  }
  if (typeof raw !== "object" || raw === null || typeof raw.is_transaction !== "boolean") return null;
  const str = (v: unknown, max = 80): string | null => {
    if (typeof v !== "string") return null;
    const t = v.trim();
    return t.length === 0 ? null : t.slice(0, max);
  };
  // Los campos con forma fija se validan ENTEROS: recortar antes dejaba pasar «soles» como «SOL».
  const currency = str(raw.currency, 100)?.toUpperCase() ?? null;
  const date = str(raw.date, 100);
  const last4 = str(raw.account_last4, 100);
  const amount = typeof raw.amount === "number" && Number.isFinite(raw.amount) && raw.amount > 0 ? Math.round(raw.amount * 100) / 100 : null;
  const kind = raw.kind === "expense" || raw.kind === "income" ? raw.kind : null;
  return {
    isTransaction: raw.is_transaction,
    kind: raw.is_transaction ? kind : null,
    amount,
    currency: currency && ISO_CURRENCY.test(currency) ? currency : null,
    merchant: str(raw.merchant),
    date: date && ISO_DATE.test(date) ? date : null,
    bank: str(raw.bank, 40),
    accountLast4: last4 && LAST4.test(last4) ? last4 : null,
  };
}

/** Un movimiento que la Bandeja puede enseñar: tiene que ser un movimiento y traer importe. */
export function isUsableReading(r: MailReading): boolean {
  return r.isTransaction && r.amount !== null;
}
