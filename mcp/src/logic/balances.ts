/**
 * Saldos de cuentas. No hay columna de saldo: el saldo es la suma de los movimientos de la cuenta, incluido el
 * movimiento de saldo inicial (`balance_adjustment_type = "initial_balance"`).
 *
 * - Por cuenta: port de `InitialBalanceService.currentBalance` (Yala/Services/InitialBalanceService.swift:46):
 *   Σ `amount` de sus movimientos, en la divisa nativa.
 * - Total: port de `LiveBalanceCalculator.liveBalanceBreakdown`
 *   (Yala/App/Logic/Calculators/LiveBalanceCalculator.swift:111) con el filtro de cuentas del chat
 *   (`FullFinancialContextBuilder.buildBalances`: fuera las excluidas de estadísticas y las archivadas). Agrupa por
 *   la divisa DEL MOVIMIENTO y convierte cada bolsa con la tasa más reciente: es «lo que tienes hoy», no la suma de
 *   conversiones históricas.
 */
import { convert, type RateTable } from "./fx";
import { num, round2, type AccountRow, type TxRow } from "./types";

export interface AccountBalance {
  id: string;
  nombre: string;
  tipo: string | null;
  divisa: string | null;
  saldo: number;
  archivada: boolean;
  excluida_de_estadisticas: boolean;
  movimientos: number;
}

export interface BalancesResult {
  cuentas: AccountBalance[];
  total: {
    divisa: string;
    importe: number;
    /** true si alguna divisa se convirtió con la tasa más reciente (siempre que haya más de una divisa). */
    aproximado: boolean;
    /** Divisas que no se pudieron convertir por falta de tasa; su saldo NO está en `importe`. */
    sin_convertir: { divisa: string; importe: number }[];
  };
}

type BalanceTx = Pick<TxRow, "account_ref" | "amount" | "currency_code">;

export function computeBalances(
  accounts: AccountRow[],
  txs: BalanceTx[],
  preferredCurrency: string,
  rates: RateTable | null,
  opts: { incluirArchivadas: boolean },
): BalancesResult {
  const byAccount = new Map<string, { sum: number; count: number }>();
  for (const tx of txs) {
    if (!tx.account_ref) continue;
    const amount = num(tx.amount);
    if (amount === null) continue;
    const agg = byAccount.get(tx.account_ref) ?? { sum: 0, count: 0 };
    agg.sum += amount;
    agg.count += 1;
    byAccount.set(tx.account_ref, agg);
  }

  const countable = new Map<string, AccountRow>();
  for (const a of accounts) {
    if (a.exclude_from_statistics !== true && a.is_archived !== true) countable.set(a.sync_id, a);
  }

  const native = new Map<string, number>();
  for (const tx of txs) {
    if (!tx.account_ref) continue;
    const acc = countable.get(tx.account_ref);
    if (!acc) continue;
    const amount = num(tx.amount);
    if (amount === null) continue;
    // Null = default del modelo (`TransactionItem.currencyCode = "USD"`), que es lo que suma la app.
    const code = (tx.currency_code ?? "USD").toUpperCase();
    native.set(code, (native.get(code) ?? 0) + amount);
  }

  let total = 0;
  let approximate = false;
  const unconverted: { divisa: string; importe: number }[] = [];
  for (const [code, amount] of native) {
    if (code === preferredCurrency.toUpperCase()) {
      total += amount;
      continue;
    }
    const converted = convert(amount, code, preferredCurrency, rates);
    if (converted === null) {
      unconverted.push({ divisa: code, importe: round2(amount) });
    } else {
      total += converted;
      approximate = true;
    }
  }

  const cuentas = accounts
    .filter((a) => opts.incluirArchivadas || a.is_archived !== true)
    .map((a) => {
      const agg = byAccount.get(a.sync_id);
      return {
        id: a.sync_id,
        nombre: a.name ?? "(sin nombre)",
        tipo: a.type,
        divisa: a.currency_code,
        saldo: round2(agg?.sum ?? 0),
        archivada: a.is_archived === true,
        excluida_de_estadisticas: a.exclude_from_statistics === true,
        movimientos: agg?.count ?? 0,
      };
    })
    .sort((x, y) => x.nombre.localeCompare(y.nombre, "es"));

  return {
    cuentas,
    total: { divisa: preferredCurrency, importe: round2(total), aproximado: approximate, sin_convertir: unconverted },
  };
}
