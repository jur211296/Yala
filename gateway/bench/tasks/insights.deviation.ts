import { gradeComment, moneyMarkers } from "../lib/insightsGrading";
import { currencySymbol, deviationBody, deviationPayload, type DeviationInput } from "../lib/insightsRequests";
import { INSIGHTS_SCHEMAS } from "./insights.schemas";
import type { BenchTask } from "./types";

/**
 * Un caso: las líneas del plan de flujo de caja que se pasaron. La app solo llama con al menos una
 * (`guard !deviations.isEmpty`). `locale` = idioma de la app; el prompt tampoco lo manda.
 */
export interface DeviationCase {
  id: string;
  locale: string;
  allowNull?: boolean;
  note?: string;
  input: DeviationInput;
}

export function deviationContext(c: DeviationCase) {
  const sym = currencySymbol(c.input.currency);
  return { data: deviationPayload(c.input), locale: c.locale, money: moneyMarkers(c.input.currency, sym, sym ?? c.input.currency) };
}

export const insightsDeviationTask: BenchTask<DeviationCase> = {
  name: "insights.deviation",
  baseParams: { temperature: 0.4, responseFormat: "json_object", jsonSchema: INSIGHTS_SCHEMAS["insights.deviation"] },
  body: (c) => deviationBody(c.input),
  grade: (content, c) => gradeComment(content, deviationContext(c), !!c.allowNull),
};
