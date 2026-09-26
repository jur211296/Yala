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
 * El ajuste se construye con el conjunto MÁS AMPLIO de movimientos (las dos patas presentes) y se consulta desde el
 * subconjunto filtrado, igual que en la app.
 */
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
  "sync_id" | "amount" | "account_ref" | "subcategory_ref" | "split_expense_id" | "amount_in_preferred_currency" | "is_exchange_rate_provisional"
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

/** Un `null` del wire vale el default del modelo: `amount` y `amountInPreferredCurrency` nacen a 0. */
const amountOf = (tx: LegTx) => num(tx.amount) ?? 0;
const preferredOf = (tx: LegTx) => num(tx.amount_in_preferred_currency) ?? 0;

export function buildGroupAdjustment(
  txs: LegTx[],
  accounts: Map<string, AccountRow>,
  subcategories: Map<string, SubcategoryRow>,
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

    // `isSystemAccount` nace a false: un null del wire es una cuenta real.
    const real = legs.filter((l) => accountOf(l)?.is_system_account !== true);
    const systemLegs = legs.filter((l) => accountOf(l)?.is_system_account === true);
    const loanBySign = systemLegs.filter((l) => amountOf(l) > 0);
    const hasCostLeg = real.length > 0 || systemLegs.some((l) => amountOf(l) <= 0);

    if (hasCostLeg) {
      const realLeg = real[0];
      if (realLeg) {
        const native = amountOf(realLeg) + loanBySign.reduce((s, l) => s + amountOf(l), 0);
        const preferred = preferredOf(realLeg) + loanBySign.reduce((s, l) => s + preferredOf(l), 0);
        const approx =
          (realLeg.is_exchange_rate_provisional === true ? Math.abs(preferredOf(realLeg)) : 0) +
          loanBySign.reduce((s, l) => s + (l.is_exchange_rate_provisional === true ? Math.abs(preferredOf(l)) : 0), 0);
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
