import { gradeComment, moneyMarkers } from "../lib/insightsGrading";
import { cashFlowBody, cashFlowPayload, currencySymbol, type CashFlowInput } from "../lib/insightsRequests";
import { INSIGHTS_SCHEMAS } from "./insights.schemas";
import type { BenchTask } from "./types";

/**
 * Un caso: la proyección de flujo de caja que ve el usuario. `locale` = idioma de la app (el que el usuario lee);
 * ojo, el prompt de la app NO lo manda (ver el informe). `allowNull`: el caso no tiene nada que comentar y
 * `{"comment": null}` (la app enseña su comentario de reglas) también vale.
 */
export interface CashFlowCase {
  id: string;
  locale: string;
  allowNull?: boolean;
  note?: string;
  input: CashFlowInput;
}

export function cashFlowContext(c: CashFlowCase) {
  const sym = currencySymbol(c.input.currency);
  return { data: cashFlowPayload(c.input), locale: c.locale, money: moneyMarkers(c.input.currency, sym, sym ?? c.input.currency) };
}

export const insightsCashflowTask: BenchTask<CashFlowCase> = {
  name: "insights.cashflow",
  baseParams: { temperature: 0.4, responseFormat: "json_object", jsonSchema: INSIGHTS_SCHEMAS["insights.cashflow"] },
  body: (c) => cashFlowBody(c.input),
  grade: (content, c) => gradeComment(content, cashFlowContext(c), !!c.allowNull),
};
