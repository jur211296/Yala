/**
 * Gastos de grupo: «tu parte», no el total. Port de `GroupBridgeStatsAdjustment`
 * (Yala/App/Logic/GroupBridgeStatsAdjustment.swift), sin cambios de regla.
 *
 * Cuando pagas tú un gasto del grupo, la app guarda DOS movimientos con el mismo `split_expense_id`:
 * - la pata REAL en tu cuenta: `amount = -total`;
 * - la pata de préstamo en la cuenta de sistema «Grupos»: `amount = +lo que te deben`.
 * La suma de las dos es `-tu parte`, pero ese número no vive en ninguna fila. Las estadísticas lo reconstruyen:
 * a la pata real le atribuyen `-tu parte` y la de préstamo se SUPRIME (si no, sería un ingreso fantasma).
 *
 * Identificación, igual que la app:
 * - Si alguna pata no tiene cuenta que resuelva, el grupo no se toca.
 * - La pata de préstamo se reconoce por el SIGNO (`amount > 0`) en una cuenta de sistema.
 * - Solo cuando no hay pata de coste, el rol de la subcategoría («Préstamo a grupos», por su nombre en cualquiera de
 *   los idiomas de la app) separa un préstamo suelto de un «saldo inicial: me deben».
 *
 * Los saldos NUNCA se ajustan: reflejan el dinero que de verdad salió de tu cuenta.
 *
 * Líneas de tu parte (Grupos B): una pata de TRANSFERENCIA (`balance_adjustment_type` puesto, la recarga de una línea)
 * no es pata real, de préstamo ni de costo: no se netea. Las demás líneas viven en «Grupos» con su categoría y el
 * préstamo ya las incluye, así que la regla no cambia para ellas.
 *
 * Ventas por cobrar (Grupos B · cards 8-11): lo POR COBRAR lleva `balance_adjustment_type = "receivable"` y no cuenta
 * (cae con los ajustes de saldo, `eligibleForStats`). Lo COBRADO es un ingreso suelto en «Grupos», con la categoría de la
 * venta y la fecha del pago, marcado en `split_lines_raw` (`{"k":"c","of":…}`): cuenta como ingreso y no entra en el
 * neteo, aunque por su forma (sistema, `+x`) parezca un préstamo — igual que `isCollected` en la app.
 *
 * Una pata cuyo importe guardado no se puede creer —0 con un nativo distinto de 0 (la conversión no se escribió), o
 * guardado con otra divisa preferida que la pata real— se reconvierte desde su nativo con la tasa de su día, como
 * `preferredContribution(of:in:converter:)` de la app; si no, «tu parte» salía con el importe del grupo entero y sin
 * «≈» (ticket `bridge-synthesis-trusts-a-zero-converted-amount`).
 *
 * El ajuste se construye con el conjunto MÁS AMPLIO de movimientos (las dos patas presentes) y se consulta desde el
 * subconjunto filtrado, igual que en la app.
 */
import { buildRateBook, convertOn, utcDateKey, type RateBook } from "./fx";
import { num, type AccountRow, type SubcategoryRow, type TxRow } from "./types";

/**
 * Nombres de la subcategoría de sistema `subcategory.system.loanToGroups` en todos los idiomas de la app
 * (`L10n.allLocalizedValues`), en minúsculas. NO se edita a mano: el golden trae la lista que emite la app y
 * `golden.test.ts` falla si esta copia se separa.
 */
export const LOAN_TO_GROUPS_NAMES: readonly string[] = Object.freeze([
  "darlehen an gruppen",
  "empréstimo a grupos",
  "lening aan groepen",
  "loan to groups",
  "pożyczka dla grup",
  "prestito ai gruppi",
  "prêt aux groupes",
  "préstamo a grupos",
  "グループへの貸付",
  "向群组借出",
]);

type LegTx = Pick<
  TxRow,
  | "sync_id"
  | "amount"
  | "account_ref"
  | "subcategory_ref"
  | "split_expense_id"
  | "split_lines_raw"
  | "balance_adjustment_type"
  | "amount_in_preferred_currency"
  | "is_exchange_rate_provisional"
  | "currency_code"
  | "preferred_currency_code"
  | "date"
  | "local_day"
>;

interface Adjusted {
  native: number;
  preferred: number;
  /** `Σ|patas provisionales|` en divisa preferida: magnitudes, nunca el neto. */
  approximatePreferred: number;
}

export interface GroupAdjustment {
  /** Importe con signo, en la divisa del movimiento: `-tu parte` para la pata real, el original en el resto. */
  amount(tx: LegTx): number | null;
  /** Importe con signo en la divisa preferida guardada. */
  amountInPreferred(tx: LegTx): number | null;
  isSuppressed(tx: Pick<TxRow, "sync_id">): boolean;
  isAdjusted(tx: Pick<TxRow, "sync_id">): boolean;
  /** Numerador de `ApproximateMarkThreshold` para este movimiento (ver `approximateMagnitude` de la app). */
  approximateMagnitude(tx: LegTx, magnitude: number): number;
  /** Cuántos gastos de grupo se proyectaron a «tu parte». */
  readonly adjustedCount: number;
}

/**
 * `true` si `split_lines_raw` marca una pata COBRADA de una venta: `{"k":"c","of":"<id>","v":1}`. Port de
 * `GroupCollectedLegLogic.isCollected` (una versión posterior a la 1 no se entiende y no se toma por cobrada).
 */
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isCollectedLeg(raw: string | null | undefined): boolean {
  if (!raw) return false;
  try {
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== "object" || parsed === null) return false;
    const o = parsed as Record<string, unknown>;
    // Como `GroupSplitLinesRecipe.parse`: `of` es un UUID, y un `l` nulo cuenta como ausente.
    return o.v === 1 && o.k === "c" && typeof o.of === "string" && UUID_RE.test(o.of) && o.l == null;
  } catch {
    return false;
  }
}

/** Un `null` del wire vale el default del modelo: `amount` y `amountInPreferredCurrency` nacen a 0. */
const amountOf = (tx: LegTx) => num(tx.amount) ?? 0;
const preferredOf = (tx: LegTx) => num(tx.amount_in_preferred_currency) ?? 0;
/** Un null del wire vale el default del modelo: `preferredCurrencyCode = "PEN"`. */
const preferredCodeOf = (tx: LegTx) => (tx.preferred_currency_code ?? "PEN").toUpperCase();

/**
 * Lo que UNA pata aporta al importe sintetizado, en `target`, y la magnitud dudosa que lleva. Port de
 * `GroupBridgeStatsAdjustment.preferredContribution(of:in:converter:)`.
 */
function preferredContribution(leg: LegTx, target: string, rates: RateBook): { value: number; approximate: number } {
  const stored = preferredOf(leg);
  const usable = preferredCodeOf(leg) === target && !(stored === 0 && amountOf(leg) !== 0);
  if (!usable) {
    // La regla de `preferredAmount` (rama «se convirtió a otra»): el nativo con la tasa de su día.
    const native = amountOf(leg);
    // Un null del wire vale el default del modelo (`TransactionItem.currencyCode = "USD"`).
    const from = leg.currency_code ?? "USD";
    const key = (leg.date ? utcDateKey(leg.date) : null) ?? leg.local_day;
    const out = key ? convertOn(Math.abs(native), from, target, key, rates) : null;
    if (out) {
      const magnitude = Math.abs(out.value);
      return { value: native < 0 ? -magnitude : magnitude, approximate: out.quality === "exact" ? 0 : magnitude };
    }
    // Divisa que la app no conoce o sin día: se queda lo guardado (diferencia declarada en `fx.ts`).
  }
  return { value: stored, approximate: leg.is_exchange_rate_provisional === true ? Math.abs(stored) : 0 };
}

/**
 * @param rates solo se consulta para reconvertir una pata cuyo importe guardado no se puede creer. Sin tasas, una pata
 *   así se convierte con la tabla estática y sale marcada.
 */
export function buildGroupAdjustment(
  txs: LegTx[],
  accounts: Map<string, AccountRow>,
  subcategories: Map<string, SubcategoryRow>,
  rates: RateBook = buildRateBook([]),
): GroupAdjustment {
  const byExpense = new Map<string, LegTx[]>();
  const seen = new Set<string>();
  for (const tx of txs) {
    if (tx.split_expense_id === null || tx.split_expense_id === undefined) continue;
    // El conjunto amplio puede traer la misma fila dos veces (el rango y la búsqueda de hermanas): una sola cuenta.
    if (seen.has(tx.sync_id)) continue;
    seen.add(tx.sync_id);
    const legs = byExpense.get(tx.split_expense_id) ?? [];
    legs.push(tx);
    byExpense.set(tx.split_expense_id, legs);
  }

  const loanNames = new Set(LOAN_TO_GROUPS_NAMES);
  const isLoanToGroupsSub = (ref: string | null) => {
    if (!ref) return null;
    const sub = subcategories.get(ref);
    if (!sub) return null; // relación nil: no se decide (skip-if-nil)
    return (sub.is_system === true || sub.is_default_seed === true) && loanNames.has((sub.name ?? "").toLowerCase());
  };

  const adjusted = new Map<string, Adjusted>();
  const suppressed = new Set<string>();

  for (const legs of byExpense.values()) {
    const accountOf = (tx: LegTx) => (tx.account_ref ? accounts.get(tx.account_ref) : undefined);
    if (legs.some((l) => !accountOf(l))) continue;

    // Una pata de transferencia (recarga de una línea de tu parte) no entra en el neteo: ver la cabecera.
    const nonTransfer = legs.filter((l) => !l.balance_adjustment_type && !isCollectedLeg(l.split_lines_raw));
    // `isSystemAccount` nace a false: un null del wire es una cuenta real.
    const real = nonTransfer.filter((l) => accountOf(l)?.is_system_account !== true);
    const systemLegs = nonTransfer.filter((l) => accountOf(l)?.is_system_account === true);
    const loanBySign = systemLegs.filter((l) => amountOf(l) > 0);
    const hasCostLeg = real.length > 0 || systemLegs.some((l) => amountOf(l) <= 0);

    if (hasCostLeg) {
      const realLeg = real[0];
      if (realLeg) {
        const native = amountOf(realLeg) + loanBySign.reduce((s, l) => s + amountOf(l), 0);
        // Cada pata, en la divisa preferida de la pata REAL (la que compara `preferredAmount`).
        const target = preferredCodeOf(realLeg);
        const parts = [realLeg, ...loanBySign].map((l) => preferredContribution(l, target, rates));
        const preferred = parts.reduce((s, p) => s + p.value, 0);
        // Magnitudes, nunca el neto (ver `approximateMagnitude` de la app).
        const approx = parts.reduce((s, p) => s + p.approximate, 0);
        adjusted.set(realLeg.sync_id, { native, preferred, approximatePreferred: approx });
      }
      for (const l of loanBySign) suppressed.add(l.sync_id);
    } else {
      for (const l of loanBySign) {
        if (isLoanToGroupsSub(l.subcategory_ref) === true) suppressed.add(l.sync_id);
      }
    }
  }

  return {
    amount: (tx) => adjusted.get(tx.sync_id)?.native ?? num(tx.amount),
    amountInPreferred: (tx) => adjusted.get(tx.sync_id)?.preferred ?? num(tx.amount_in_preferred_currency),
    isSuppressed: (tx) => suppressed.has(tx.sync_id),
    isAdjusted: (tx) => adjusted.has(tx.sync_id),
    approximateMagnitude: (tx, magnitude) => {
      const a = adjusted.get(tx.sync_id);
      if (a) return a.approximatePreferred;
      return tx.is_exchange_rate_provisional === true ? magnitude : 0;
    },
    adjustedCount: adjusted.size,
  };
}

/** Sin gastos de grupo: la identidad. */
export const NO_GROUP_ADJUSTMENT: GroupAdjustment = buildGroupAdjustment([], new Map(), new Map());
