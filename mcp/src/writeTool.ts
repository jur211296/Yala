/**
 * La única herramienta de ESCRITURA del conector: `apuntar_movimiento` («apunta 25 soles de almuerzo»).
 *
 * Es estrecha a propósito (ADR del conector, 2026-09-26, y decisión del 21-oct: «la IA solo deja borradores en la
 * Bandeja, por confirmar»):
 * - No escribe en los datos de la nube de la persona. Su sesión de Supabase sigue siendo de solo lectura. Lo que hace es
 *   dejar el movimiento en una cola del gateway (`ConnectorDrafts.enqueue`, service binding `CONNECTOR_DRAFTS`), y la
 *   app lo convierte en un borrador de la Bandeja que la persona confirma o descarta. Hasta entonces no cuenta en
 *   saldos, presupuestos ni estadísticas.
 * - Solo crea. No edita, no borra, no confirma.
 * - Resuelve la cuenta y la subcategoría contra las de la persona (las lee con la misma sesión que las herramientas de
 *   lectura). Un nombre que no existe o es ambiguo devuelve error con las opciones, para que la IA lo corrija en la
 *   misma conversación en vez de dejar un borrador incompleto.
 *
 * No está en `TOOL_CORES`: ese núcleo lo comparte el gateway para Yala IA, que no debe escribir.
 */
import { z } from "zod";
import { InvalidInputError, assertDay, dayInZone } from "./logic/dates";
import type { AccountRow, CategoryRow, SubcategoryRow } from "./logic/types";
import { loadLookup, loadPrefs, resolvePreferredCurrency, zoneNotice, zoneOf, type ToolContext } from "./toolCore";

export const WRITE_TOOL_NAME = "apuntar_movimiento";
export const WRITE_TOOL_TITLE = "Apuntar un movimiento en la Bandeja";
export const WRITE_TOOL_DESCRIPTION =
  "Deja un gasto o un ingreso del usuario como BORRADOR en la Bandeja de Yala. El usuario lo confirma o lo descarta en la " +
  "app; hasta entonces no cuenta en saldos, presupuestos ni estadísticas. No modifica ni borra nada. La cuenta y la " +
  "categoría se buscan por nombre entre las del usuario (las de listar_cuentas y listar_categorias): si no se encuentran " +
  "o hay varias que encajan, devuelve un error con las opciones. Sin cuenta, se usa la única cuenta en esa divisa si la " +
  "hay; si no, el borrador la pide en la app. Devuelve lo que quedó en el borrador y lo que falta completar.";

const MAX_AMOUNT = 1_000_000_000;
const MAX_LISTED_OPTIONS = 40;

export const WRITE_TOOL_INPUT = {
  importe: z
    .number()
    .positive()
    .max(MAX_AMOUNT)
    .describe("El importe, siempre positivo (25 para «25 soles»). Si es gasto o ingreso lo dice «tipo»."),
  tipo: z.enum(["gasto", "ingreso"]).optional().describe("Gasto o ingreso. Por defecto, gasto."),
  divisa: z
    .string()
    .regex(/^[A-Za-z]{3}$/)
    .optional()
    .describe("Código ISO 4217 de la divisa (PEN para soles, USD para dólares). Si no se pasa, la de la cuenta o la preferida del usuario."),
  nota: z.string().max(80).optional().describe("Comercio o concepto, corto («Almuerzo», «Uber», «Sueldo»)."),
  fecha: z.string().optional().describe("Día del movimiento, AAAA-MM-DD. Por defecto, hoy en la zona del usuario. No puede ser futuro."),
  cuenta: z.string().max(80).optional().describe("Nombre de la cuenta del usuario con la que se pagó o donde entró, o parte de él."),
  categoria: z
    .string()
    .max(120)
    .optional()
    .describe("Nombre de la subcategoría del usuario («Restaurantes»), o «Categoría › Subcategoría» si el nombre se repite."),
  zona_horaria: z
    .string()
    .max(64)
    .optional()
    .describe("Zona horaria IANA del usuario, por ejemplo America/Lima. Decide qué día es «hoy»."),
};

/** Lo que el conector deja en la cola del gateway. Espejo de `ConnectorDraftPayload` (`gateway/src/connector/store.ts`). */
export interface ConnectorDraftPayload {
  kind: "expense" | "income";
  amount: number;
  currency: string | null;
  note: string | null;
  date: string | null;
  account_id: string | null;
  account_name: string | null;
  subcategory_id: string | null;
  subcategory_name: string | null;
  client: string | null;
}

export type EnqueueOutcome = { ok: true; id: string } | { ok: false; reason: "invalid" | "daily_cap" | "queue_full" };

/** El service binding a la clase RPC `ConnectorDrafts` del gateway. */
export interface ConnectorDraftsBinding {
  enqueue(userId: string, payload: ConnectorDraftPayload): Promise<EnqueueOutcome>;
}

/** La cola rechazó el movimiento: se le dice a la IA por qué, en palabras. */
export class EnqueueRejectedError extends Error {
  constructor(readonly reason: "invalid" | "daily_cap" | "queue_full") {
    super(reason);
  }
}

export interface WriteToolDeps {
  queue: ConnectorDraftsBinding;
  sub: string;
  /** Qué IA está conectada («Claude», «ChatGPT», «Grok»), o `null` si no se sabe. */
  clientLabel: () => Promise<string | null>;
}

/** Minúsculas y sin tildes: «Café» y «cafe» son la misma cuenta. */
export function fold(text: string): string {
  return text.normalize("NFD").replace(/\p{M}/gu, "").toLocaleLowerCase("es").replace(/\s+/g, " ").trim();
}

/** Las filas cuyo nombre es EXACTAMENTE el buscado; si no hay ninguna, las que lo contienen. */
function byName<T>(rows: T[], needle: string, nameOf: (row: T) => string): T[] {
  const n = fold(needle);
  if (!n) return [];
  const exact = rows.filter((r) => fold(nameOf(r)) === n);
  if (exact.length > 0) return exact;
  return rows.filter((r) => fold(nameOf(r)).includes(n));
}

function optionsList(names: string[]): string {
  const unique = [...new Set(names)].sort((a, b) => a.localeCompare(b, "es"));
  const shown = unique.slice(0, MAX_LISTED_OPTIONS).join(", ");
  return unique.length > MAX_LISTED_OPTIONS ? `${shown}…` : shown;
}

/** Cuentas que se pueden elegir: ni archivadas ni de sistema (las de Grupos las asigna el puente). */
function eligibleAccounts(accounts: Iterable<AccountRow>): AccountRow[] {
  return [...accounts].filter((a) => a.is_archived !== true && a.is_system_account !== true);
}

/**
 * La cuenta del borrador. Nombrada: se busca entre las cuentas que se nombran (sin las líneas de otra divisa de una
 * tarjeta); con divisa, la tarjeta va a su línea en esa divisa, y una cuenta en otra divisa es un error. Sin nombrar: la
 * ÚNICA cuenta en esa divisa (molde de `DraftBuilder.findAccount(byCurrency:)` de la app), o ninguna.
 */
export function resolveAccount(
  accounts: Iterable<AccountRow>,
  mention: string | undefined,
  currency: string | null,
): AccountRow | null {
  const live = eligibleAccounts(accounts);
  if (mention !== undefined && mention.trim() !== "") {
    const named = live.filter((a) => !a.parent_account_id);
    const matches = byName(named, mention, (a) => a.name ?? "");
    if (matches.length === 0) {
      throw new InvalidInputError(
        `No hay ninguna cuenta que se llame «${mention.trim()}». Cuentas del usuario: ${optionsList(named.map((a) => a.name ?? "(sin nombre)"))}.`,
      );
    }
    if (matches.length > 1) {
      throw new InvalidInputError(
        `«${mention.trim()}» encaja con varias cuentas: ${optionsList(matches.map((a) => a.name ?? "(sin nombre)"))}. Usa el nombre completo.`,
      );
    }
    const chosen = matches[0] as AccountRow;
    if (!currency || (chosen.currency_code ?? "").toUpperCase() === currency) return chosen;
    const line = live.find((a) => a.parent_account_id === chosen.sync_id && (a.currency_code ?? "").toUpperCase() === currency);
    if (line) return line;
    throw new InvalidInputError(
      `La cuenta «${chosen.name ?? ""}» es en ${(chosen.currency_code ?? "?").toUpperCase()} y el importe es en ${currency}. Elige una cuenta en ${currency} o no indiques la divisa.`,
    );
  }
  if (!currency) return null;
  const inCurrency = live.filter((a) => (a.currency_code ?? "").toUpperCase() === currency);
  return inCurrency.length === 1 ? (inCurrency[0] as AccountRow) : null;
}

interface SubOption {
  sub: SubcategoryRow;
  category: CategoryRow;
  label: string;
}

/**
 * La subcategoría del borrador, del lado del tipo (un gasto no va a una categoría de ingreso, como en la app:
 * `DraftBuilder.matchesNature`). Acepta el nombre de la subcategoría, «Categoría › Subcategoría» (también con «/» o
 * «>»), o el nombre de una categoría que tenga una sola subcategoría.
 */
export function resolveSubcategory(
  categories: Map<string, CategoryRow>,
  subcategories: Iterable<SubcategoryRow>,
  mention: string,
  isIncome: boolean,
): SubOption {
  const options: SubOption[] = [];
  for (const sub of subcategories) {
    if (sub.is_visible === false || sub.is_system === true || !sub.category_ref) continue;
    const category = categories.get(sub.category_ref);
    if (!category || category.is_visible === false || (category.is_income === true) !== isIncome) continue;
    options.push({ sub, category, label: `${category.name ?? ""} › ${sub.name ?? ""}` });
  }
  const kindWord = isIncome ? "ingreso" : "gasto";
  const all = () => optionsList(options.map((o) => o.label));

  // Primero el texto entero, contra el nombre de la subcategoría y contra «Categoría › Subcategoría» (el que dan los
  // errores): una subcategoría puede llevar «/» en su nombre («Luz/Agua») y partirlo la haría inalcanzable.
  const whole = options.filter((o) => fold(o.sub.name ?? "") === fold(mention));
  const wholeLabel = options.filter((o) => fold(o.label) === fold(mention));
  if (whole.length === 1) return whole[0] as SubOption;
  if (whole.length === 0 && wholeLabel.length === 1) return wholeLabel[0] as SubOption;

  const parts = mention.split(/\s*(?:›|>|\/)\s*/).filter((p) => p.trim() !== "");
  let matches: SubOption[];
  if (parts.length === 2) {
    const [catName, subName] = parts as [string, string];
    matches = byName(byName(options, catName, (o) => o.category.name ?? ""), subName, (o) => o.sub.name ?? "");
  } else {
    matches = byName(options, mention, (o) => o.sub.name ?? "");
    if (matches.length === 0) {
      const inCategory = byName(options, mention, (o) => o.category.name ?? "");
      const categoriesHit = new Set(inCategory.map((o) => o.category.sync_id));
      if (categoriesHit.size === 1) matches = inCategory;
    }
  }

  if (matches.length === 1) return matches[0] as SubOption;
  if (matches.length === 0) {
    throw new InvalidInputError(`No hay ninguna subcategoría de ${kindWord} que se llame «${mention.trim()}». Subcategorías de ${kindWord} del usuario: ${all()}.`);
  }
  throw new InvalidInputError(
    `«${mention.trim()}» encaja con varias subcategorías: ${optionsList(matches.map((o) => o.label))}. Usa «Categoría › Subcategoría».`,
  );
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/** Corre la herramienta: valida, resuelve, encola y cuenta qué quedó. Los errores de entrada son `InvalidInputError`. */
export async function runWriteTool(ctx: ToolContext, deps: WriteToolDeps, args: Record<string, unknown>) {
  const amount = round2(Number(args.importe));
  if (!Number.isFinite(amount) || amount <= 0 || amount > MAX_AMOUNT) throw new InvalidInputError("importe debe ser un número positivo");
  const isIncome = args.tipo === "ingreso";
  const givenCurrency = typeof args.divisa === "string" && args.divisa ? args.divisa.toUpperCase() : null;
  const note = typeof args.nota === "string" && args.nota.trim() ? args.nota.trim() : null;

  const prefsP = loadPrefs(ctx);
  prefsP.catch(() => undefined); // si la zona falla antes de esperarla, que su rechazo no quede suelto
  const zone = await zoneOf(ctx, args, prefsP);
  const today = dayInZone(ctx.now, zone.tz);
  let date = today;
  if (typeof args.fecha === "string" && args.fecha) {
    date = assertDay(args.fecha, "fecha");
    // Hasta hoy: la app toma el día a mediodía y descarta lo que caiga más de 24 h después de la llegada, así que
    // «mañana» acababa con la fecha de llegada sin decírselo a nadie (`BankEmailDraftLogic.date`).
    if (date > today) throw new InvalidInputError(`fecha no puede ser futura (hoy es ${today} para el usuario)`);
  }

  const [lookup, prefs] = await Promise.all([loadLookup(ctx), prefsP]);
  const accountMention = typeof args.cuenta === "string" ? args.cuenta : undefined;
  const account = resolveAccount(lookup.accounts.values(), accountMention, givenCurrency);
  let currency = givenCurrency ?? account?.currency_code?.toUpperCase() ?? null;
  let fallbackAccount: AccountRow | null = null;
  if (!currency) {
    currency = resolvePreferredCurrency(prefs, eligibleAccounts(lookup.accounts.values()).map((a) => a.currency_code)).code;
    fallbackAccount = account ?? resolveAccount(lookup.accounts.values(), undefined, currency);
  }
  const finalAccount = account ?? fallbackAccount;

  const subMention = typeof args.categoria === "string" && args.categoria.trim() ? args.categoria : null;
  const sub = subMention ? resolveSubcategory(lookup.categories, lookup.subcategories.values(), subMention, isIncome) : null;

  const payload: ConnectorDraftPayload = {
    kind: isIncome ? "income" : "expense",
    amount,
    currency,
    note,
    date,
    account_id: finalAccount?.sync_id ?? null,
    account_name: finalAccount?.name ?? null,
    subcategory_id: sub?.sub.sync_id ?? null,
    subcategory_name: sub?.sub.name ?? null,
    client: await deps.clientLabel(),
  };
  const out = await deps.queue.enqueue(deps.sub, payload);
  if (!out.ok) throw new EnqueueRejectedError(out.reason);

  const falta: string[] = [];
  if (!finalAccount) falta.push("cuenta");
  if (!sub) falta.push("categoría");
  const avisos = [
    "Es un borrador: aparece en la Bandeja de Yala la próxima vez que el usuario abra la app, y no cuenta en saldos ni presupuestos hasta que lo confirme.",
    ...(falta.length > 0 ? [`Falta ${falta.join(" y ")}: el usuario lo elige en la Bandeja antes de confirmar.`] : []),
    ...zoneNotice(zone),
  ];
  return {
    resultado: "borrador_en_bandeja",
    borrador: {
      tipo: isIncome ? "ingreso" : "gasto",
      importe: amount,
      divisa: currency,
      nota: note,
      fecha: date,
      cuenta: finalAccount?.name ?? null,
      categoria: sub?.label ?? null,
    },
    falta,
    avisos,
  };
}

/** El mensaje a la IA cuando la cola no aceptó el movimiento. */
export function enqueueRejectedMessage(reason: EnqueueRejectedError["reason"]): string {
  switch (reason) {
    case "daily_cap":
      return "Ya se apuntaron 50 movimientos hoy desde una IA. Se puede volver a apuntar mañana, o directamente en la app.";
    case "queue_full":
      return "Hay 100 movimientos esperando en la Bandeja de Yala. El usuario tiene que abrir la app y revisarlos antes de apuntar más.";
    case "invalid":
      return "Yala no aceptó el movimiento. Revisa el importe, la divisa y la fecha.";
  }
}

/** La IA conectada, por la vuelta que registró su cliente (no por el nombre que se puso: ese lo elige el cliente). */
export function clientLabelFromRedirects(redirectUris: string[]): string | null {
  for (const raw of redirectUris) {
    let host: string;
    try {
      host = new URL(raw).hostname;
    } catch {
      continue;
    }
    if (host === "claude.ai" || host === "claude.com" || host === "localhost" || host === "127.0.0.1" || host === "[::1]") return "Claude";
    if (host === "chatgpt.com" || host === "chat.openai.com") return "ChatGPT";
    if (host === "grok.com" || host.endsWith(".grok.com") || host === "x.ai" || host.endsWith(".x.ai")) return "Grok";
  }
  return null;
}
