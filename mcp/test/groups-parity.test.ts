/**
 * Paridad de los saldos de Grupos con la app (Yala web, lote 3).
 *
 * `golden/groups-parity.json`: gastos, repartos y pagos escritos a mano; los `expected` los calcula el
 * `GroupBalanceService` de la app (YalaTests/MCP/WebGroupsParityGoldenTests.swift). Aquí se pasan las mismas entradas
 * por `shared-core/src/logic/groupBalances.ts` y se exige la misma cifra.
 */
import { describe, expect, it } from "vitest";
import goldenJson from "./golden/groups-parity.json";
import {
  calculateBalances,
  globalSummary,
  headerBalance,
  round2,
  shownBalances,
  shownDebts,
  sortDebts,
  simplify,
  type GroupSource,
} from "../../shared-core/src/logic/groupBalances";

interface GoldenGroup {
  id: string;
  simplifyDebts: boolean;
  singleCurrency: string | null;
  me: string;
  expenses: GroupSource["expenses"];
  shares: GroupSource["shares"];
  settlements: GroupSource["settlements"];
}

interface GoldenScenario {
  id: string;
  ratesPerUSD: Record<string, number>;
  groups: GoldenGroup[];
  expected: unknown;
}

const golden = goldenJson as unknown as { scenarios: GoldenScenario[] };
const TOL = 1e-6;

function compute(s: GoldenScenario) {
  const convert = (amount: number, from: string, to: string) => {
    const f = s.ratesPerUSD[from];
    const t = s.ratesPerUSD[to];
    if (!f || t === undefined) return amount;
    return amount * (t / f);
  };
  const groups: Record<string, unknown> = {};
  const all: { source: GroupSource; me: Set<string> }[] = [];
  for (const g of s.groups) {
    const source: GroupSource = {
      expenses: g.expenses,
      shares: g.shares,
      settlements: g.settlements,
      simplifyDebts: g.simplifyDebts,
      singleCurrency: g.singleCurrency,
    };
    all.push({ source, me: new Set([g.me]) });
    const debts = sortDebts(shownDebts(source, convert));
    const header = headerBalance(debts, g.me);
    groups[g.id] = {
      balances: calculateBalances(g.expenses, g.shares, g.settlements).map((b) => ({
        member: b.member,
        currency: b.currency,
        totalPaid: b.totalPaid,
        totalOwes: b.totalOwes,
        net: b.net,
      })),
      balancesShown: shownBalances(source, convert).map((b) => ({
        member: b.member,
        currency: b.currency,
        totalPaid: b.totalPaid,
        totalOwes: b.totalOwes,
        net: b.net,
      })),
      debts: debts.map((d) => ({ from: d.from, to: d.to, amount: d.amount, currency: d.currency })),
      header: { state: header.state, owedToMe: header.owedToMe, iOwe: header.iOwe },
    };
  }
  const summary = globalSummary(all, convert);
  return {
    groups,
    global: { owedToMe: summary.owedToMe, iOwe: summary.iOwe, pendingSettlements: summary.pendingSettlements },
  };
}

function compare(got: unknown, want: unknown, path: string): void {
  if (typeof want === "number") {
    expect(typeof got, `${path}: tipo`).toBe("number");
    expect(Math.abs((got as number) - want), `${path}: núcleo ${String(got)}, app ${want}`).toBeLessThanOrEqual(TOL);
    return;
  }
  if (Array.isArray(want)) {
    expect(Array.isArray(got), `${path}: no es lista`).toBe(true);
    expect((got as unknown[]).length, `${path}: longitud`).toBe(want.length);
    want.forEach((w, i) => compare((got as unknown[])[i], w, `${path}[${i}]`));
    return;
  }
  if (want && typeof want === "object") {
    expect(got && typeof got === "object", `${path}: no es objeto`).toBe(true);
    const keys = new Set([...Object.keys(want as object), ...Object.keys(got as object)]);
    for (const k of [...keys].sort()) compare((got as Record<string, unknown>)[k], (want as Record<string, unknown>)[k], `${path}.${k}`);
    return;
  }
  expect(got, path).toBe(want);
}

describe("Grupos · el núcleo da los saldos de la app (golden)", () => {
  for (const s of golden.scenarios) {
    it(s.id, () => {
      expect(s.expected, `${s.id} sin expected: genera el golden desde la app`).toBeTruthy();
      compare(compute(s), s.expected, s.id);
    });
  }
});

describe("Grupos · reglas que el golden no cubre", () => {
  it("redondea las mitades alejándose de cero, como Swift", () => {
    expect(round2(0.125)).toBe(0.13);
    expect(round2(-0.125)).toBe(-0.13);
    expect(round2(-0.0001)).toBe(0);
  });

  it("con un empate desempata por la clave menor, y lo que debe cada uno no cambia", () => {
    const out = simplify([
      { from: "b", to: "a", amount: 10, currency: "PEN" },
      { from: "c", to: "d", amount: 10, currency: "PEN" },
    ]);
    expect(out).toEqual([
      { from: "b", to: "a", amount: 10, currency: "PEN" },
      { from: "c", to: "d", amount: 10, currency: "PEN" },
    ]);
  });
});
