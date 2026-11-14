/**
 * Paridad con la app, con goldens que escribe la propia app.
 *
 * `golden/app-parity.json`: las entradas son filas de PostgREST escritas a mano; los `expected` los calcula el código
 * de producción de la app (YalaTests/MCP/MCPAppParityGoldenTests.swift, ver su cabecera). Aquí se pasan las mismas
 * filas por la lógica del conector y se exige la misma cifra.
 *
 * Tolerancia: el conector redondea a céntimos y la app no, así que se admite medio céntimo y un pelo.
 * Qué NO entra: semanas (dependen de `firstWeekday`), la zona horaria (los escenarios son a las 12:00 UTC y aquí se
 * calcula en UTC), y el periodo de cada presupuesto, que es una entrada del escenario (ver la cabecera del .swift).
 */
import { describe, expect, it } from "vitest";
import goldenJson from "./golden/app-parity.json";
import { computeBalances } from "../src/logic/balances";
import { budgetPeriod, budgetStatuses } from "../src/logic/budgets";
import { dayInZone, resolvePeriod, type PeriodKind } from "../src/logic/dates";
import { buildRateBook, convertOn, utcDateKey } from "../src/logic/fx";
import { STATIC_RATES_PER_USD } from "../src/logic/fx-static";
import { buildGroupAdjustment, LOAN_TO_GROUPS_NAMES } from "../src/logic/groups";
import { buildLookup, categoryOf } from "../src/logic/lookup";
import { listRecurring } from "../src/logic/recurring";
import { summarize, txKindOf, type TxKind } from "../src/logic/summary";
import { distribution, monthlyTrend, statsPeriods, statsSummary, type DistributionEntry } from "../../shared-core/src/logic/stats";
import { paymentDatesInMonth, upcomingPayments, type ScheduleRow } from "../../shared-core/src/logic/schedule";
import { addMonths, monthStart } from "../src/logic/dates";
import type {
  AccountRow,
  BudgetRow,
  CategoryRow,
  ExchangeRateRow,
  ScheduledPaymentRow,
  SubcategoryRow,
  TagRow,
  TxRow,
} from "../src/logic/types";

interface PeriodExpected {
  ingresos: number;
  gastos: number;
  neto: number;
  gasto_medio_diario: number;
  tasa_de_ahorro_pct: number | null;
  aproximado: { ingresos: boolean; gastos: boolean; neto: boolean };
}

/** Yala web, lote 2: lo que pintan Estadísticas y Pagos planificados (ver el bloque del .swift). */
interface SliceExpected {
  categoria: string | null;
  importe: number;
  porcentaje: number;
}

interface WebPeriodExpected {
  ingresos: number;
  gastos: number;
  neto: number;
  variacion: { ingresos: number | null; gastos: number | null; neto: number | null; gasto_medio_diario: number | null };
  gasto_medio_diario: number;
  dias: number;
  gasto_mas_alto: number | null;
  top_categorias: SliceExpected[];
  distribucion: SliceExpected[];
}

interface Expected {
  estadisticas: {
    periodos: Record<"mes_actual" | "mes_pasado" | "anio_actual", WebPeriodExpected>;
    tendencias: { mes: string; ingresos: number; gastos: number; neto: number }[];
  };
  pagos: { fechas: Record<string, string[]>; proximos: string[] };
  balances: { accounts: Record<string, number>; total: number; aproximado: boolean };
  periods: Record<"mes_actual" | "mes_pasado" | "anio_actual", PeriodExpected>;
  budgets: Record<string, number>;
  recurring: { suscripciones_mensual: number; recurrentes_mensual: number };
  groups: Record<string, { amount: number; amountInPreferred: number; suppressed: boolean }>;
  kinds: Record<string, TxKind>;
  conversions: { value: number; quality: string }[];
}

interface Scenario {
  id: string;
  description: string;
  now: string;
  preferredCurrency: string;
  rows: {
    accounts: AccountRow[];
    categories: CategoryRow[];
    subcategories: SubcategoryRow[];
    tags: TagRow[];
    exchange_rates: ExchangeRateRow[];
    tx_items: TxRow[];
    budgets: BudgetRow[];
    scheduled_payments: ScheduleRow[];
  };
  budgetPeriod: { desde: string; hasta: string };
  conversions: { amount: number; from: string; to: string; dateKey: string }[];
  expected: Expected | null;
}

interface Golden {
  app: { fallbackRates: Record<string, number>; loanToGroupsNames: string[] } | null;
  scenarios: Scenario[];
}

const golden = goldenJson as unknown as Golden;
const CENT = 0.0051;

/** La app usa `Date.now` para «la tasa de hoy» en saldos y presupuestos; aquí también (ver la cabecera del .swift). */
const REAL_TODAY_UTC = utcDateKey(new Date()) as string;

function close(got: number | null | undefined, want: number | null, label: string, tol = CENT) {
  if (want === null) {
    expect(got ?? null, label).toBeNull();
    return;
  }
  expect(got, label).not.toBeNull();
  expect(Math.abs((got as number) - want), `${label}: el conector da ${got}, la app ${want}`).toBeLessThanOrEqual(tol);
}

describe("golden de la app: lo que el conector copia tal cual", () => {
  it("el golden está generado por la app", () => {
    expect(golden.app, "falta la cabecera `app`: corre MCPAppParityGoldenTests en modo escritura").not.toBeNull();
    for (const s of golden.scenarios) expect(s.expected, `${s.id} sin expected`).not.toBeNull();
  });

  it("la tabla estática de tasas es la de la app", () => {
    expect({ ...STATIC_RATES_PER_USD }).toEqual(golden.app?.fallbackRates);
  });

  it("los nombres de «Préstamo a grupos» son los de todos los idiomas de la app", () => {
    expect([...LOAN_TO_GROUPS_NAMES].sort()).toEqual([...(golden.app?.loanToGroupsNames ?? [])].sort());
  });
});

for (const s of golden.scenarios) {
  describe(`golden de la app: ${s.id}`, () => {
    const exp = s.expected as Expected;
    const lookup = buildLookup(s.rows);
    const book = buildRateBook(s.rows.exchange_rates);
    const groups = buildGroupAdjustment(s.rows.tx_items, lookup.accounts, lookup.subcategories, book);
    const tz = "UTC";
    const today = dayInZone(new Date(s.now), tz);
    const nowUtc = utcDateKey(s.now) as string;

    it("saldo de cada cuenta y total, con el corte de hoy (AccountBalanceCalculator + LiveBalanceCalculator)", () => {
      const r = computeBalances(s.rows.accounts, s.rows.tx_items, s.preferredCurrency, book, {
        incluirArchivadas: true,
        todayUtc: REAL_TODAY_UTC,
        // El corte de hoy, con el MISMO «hoy» que la app: el `now` del escenario (`asOf: now` en el .swift).
        today,
        tz,
      });
      for (const [id, want] of Object.entries(exp.balances.accounts)) {
        close(r.cuentas.find((c) => c.id === id)?.saldo, want, `saldo ${id}`);
      }
      close(r.total.importe, exp.balances.total, "total");
      expect(r.total.aproximado, "«≈» del total").toBe(exp.balances.aproximado);
      expect(r.total.sin_convertir).toEqual([]);
    });

    for (const kind of ["mes_actual", "mes_pasado", "anio_actual"] as const satisfies readonly PeriodKind[]) {
      it(`resumen ${kind} (CashFlowCalculator con el filtro del chat)`, () => {
        const want = exp.periods[kind];
        const r = summarize(s.rows.tx_items, lookup, resolvePeriod(kind, today), {
          today,
          tz,
          preferredCurrency: s.preferredCurrency,
          rates: book,
          groups,
          top: 5,
        });
        close(r.ingresos, want.ingresos, `${kind}.ingresos`);
        close(r.gastos, want.gastos, `${kind}.gastos`);
        close(r.neto, want.neto, `${kind}.neto`);
        close(r.gasto_medio_diario, want.gasto_medio_diario, `${kind}.gasto_medio_diario`);
        close(r.tasa_de_ahorro_pct, want.tasa_de_ahorro_pct, `${kind}.tasa_de_ahorro_pct`);
        expect(r.aproximado_detalle, `${kind}: marca de «≈»`).toEqual(want.aproximado);
      });
    }

    it("gasto de cada presupuesto (BudgetsViewModel.calculateSpending)", () => {
      const r = budgetStatuses(s.rows.budgets, s.rows.tx_items, lookup, {
        today,
        todayUtc: REAL_TODAY_UTC,
        tz,
        rates: book,
        groups,
        firstWeekday: 2,
        soloActivos: false,
      });
      for (const b of s.rows.budgets) {
        const p = budgetPeriod(b, today, tz, 2);
        expect({ desde: p.desde, hasta: p.hasta }, `periodo de ${b.name}`).toEqual(s.budgetPeriod);
      }
      for (const [id, want] of Object.entries(exp.budgets)) {
        close(r.presupuestos.find((b) => b.id === id)?.gastado, want, `presupuesto ${id}`);
      }
    });

    it("totales mensuales de recurrentes (monthlyTotal)", () => {
      const r = listRecurring(s.rows.scheduled_payments, new Map(), lookup, {
        today,
        todayUtc: nowUtc,
        tz,
        preferredCurrency: s.preferredCurrency,
        rates: book,
        soloActivos: true,
      });
      close(r.totales_gasto.suscripciones_mensual, exp.recurring.suscripciones_mensual, "suscripciones");
      close(r.totales_gasto.recurrentes_mensual, exp.recurring.recurrentes_mensual, "recurrentes");
    });

    it("ajuste de grupos por movimiento (GroupBridgeStatsAdjustment)", () => {
      const byId = new Map(s.rows.tx_items.map((t) => [t.sync_id, t]));
      for (const [id, want] of Object.entries(exp.groups)) {
        const tx = byId.get(id) as TxRow;
        close(groups.amount(tx), want.amount, `amount ${id}`, 1e-6);
        close(groups.amountInPreferred(tx), want.amountInPreferred, `amountInPreferred ${id}`, 1e-6);
        expect(groups.isSuppressed(tx), `suprimida ${id}`).toBe(want.suppressed);
      }
    });

    it("tipo de cada movimiento en buscar_movimientos (TransactionClassificationLogic)", () => {
      // Todos los movimientos del escenario, no solo los que la app nombró: uno sin `expected` sería un hueco.
      const got = Object.fromEntries(s.rows.tx_items.map((t) => [t.sync_id, txKindOf(t, categoryOf(lookup, t))]));
      expect(got).toEqual(exp.kinds);
    });

    it("conversiones sueltas con la tasa del día (CurrencyConverter.convertChecked)", () => {
      s.conversions.forEach((c, i) => {
        const want = exp.conversions[i] as { value: number; quality: string };
        const got = convertOn(c.amount, c.from, c.to, c.dateKey, book);
        close(got?.value, want.value, `${c.amount} ${c.from}→${c.to} el ${c.dateKey}`, 1e-6);
        expect(got?.quality, `calidad de ${c.from}→${c.to} el ${c.dateKey}`).toBe(want.quality);
      });
    });

    // ─── Yala web, lote 2 ───────────────────────────────────────────────────────────────────────────────────────

    const slices = (got: DistributionEntry[], want: SliceExpected[], label: string) => {
      expect(got.length, `${label}: trozos`).toBe(want.length);
      want.forEach((w, i) => {
        expect(got[i]?.categoria ?? null, `${label}[${i}] categoría`).toBe(w.categoria);
        close(got[i]?.importe, w.importe, `${label}[${i}] importe`);
        close(got[i]?.porcentaje, w.porcentaje, `${label}[${i}] porcentaje`, 0.01);
      });
    };

    for (const kind of ["mes_actual", "mes_pasado", "anio_actual"] as const) {
      it(`Yala web · Estadísticas ${kind} (InsightsCalculator y TopSpendingCategoriesCalculator)`, () => {
        const want = exp.estadisticas.periodos[kind];
        const ctx = { today, tz, preferredCurrency: s.preferredCurrency, rates: book, groups };
        const r = statsSummary(s.rows.tx_items, lookup, kind, ctx);
        close(r.ingresos, want.ingresos, "ingresos");
        close(r.gastos, want.gastos, "gastos");
        close(r.neto, want.neto, "neto");
        // Porcentajes sobre cifras ya redondeadas a céntimos: una centésima de punto de margen.
        close(r.variacion.ingresos, want.variacion.ingresos, "variación de ingresos", 0.01);
        close(r.variacion.gastos, want.variacion.gastos, "variación de gastos", 0.01);
        close(r.variacion.neto, want.variacion.neto, "variación del neto", 0.01);
        close(r.variacion.gasto_medio_diario, want.variacion.gasto_medio_diario, "variación del gasto medio", 0.01);
        close(r.gasto_medio_diario, want.gasto_medio_diario, "gasto medio diario");
        expect(r.dias, "días del promedio").toBe(want.dias);
        close(r.gasto_mas_alto?.importe ?? null, want.gasto_mas_alto, "gasto más alto");
        slices(r.top_categorias, want.top_categorias, "top");
        slices(distribution(s.rows.tx_items, lookup, statsPeriods(kind, today).actual, ctx).categorias, want.distribucion, "distribución");
      });
    }

    it("Yala web · Tendencias, entradas y salidas de seis meses (CashFlowCalculator por mes)", () => {
      const r = monthlyTrend(s.rows.tx_items, lookup, 6, { today, tz, preferredCurrency: s.preferredCurrency, rates: book, groups });
      expect(r.map((m) => m.mes)).toEqual(exp.estadisticas.tendencias.map((m) => m.mes));
      exp.estadisticas.tendencias.forEach((w, i) => {
        close(r[i]?.ingresos, w.ingresos, `${w.mes} ingresos`);
        close(r[i]?.gastos, w.gastos, `${w.mes} gastos`);
        close(r[i]?.neto, w.neto, `${w.mes} neto`);
      });
    });

    it("Yala web · fechas de cobro de seis meses (ScheduledPaymentDateCalculator.paymentDatesInMonth)", () => {
      for (const p of s.rows.scheduled_payments) {
        const got: string[] = [];
        for (let i = 0; i < 6; i++) got.push(...paymentDatesInMonth(p, addMonths(monthStart(today), i), tz));
        expect(got, `fechas de ${p.name}`).toEqual(exp.pagos.fechas[p.sync_id]);
      }
    });

    it("Yala web · próximos cobros de 30 días, sin los saltados (paymentDatesInMonth + isDateSkipped)", () => {
      const r = upcomingPayments(s.rows.scheduled_payments, lookup, {
        today,
        todayUtc: nowUtc,
        tz,
        preferredCurrency: s.preferredCurrency,
        rates: book,
        days: 30,
      });
      expect(r.proximos.map((c) => `${c.id} ${c.dia}`).sort()).toEqual(exp.pagos.proximos);
    });
  });
}
