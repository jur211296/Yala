import { gradeTrends, moneyMarkers } from "../lib/insightsGrading";
import { currencyDisplay, currencySymbol, trendsBody, trendsPayload, type TrendsInput } from "../lib/insightsRequests";
import { INSIGHTS_SCHEMAS } from "./insights.schemas";
import type { BenchTask } from "./types";

/** Un caso: lo que pintan las cuatro gráficas de Tendencias (`TrendsAIInput`). El idioma va en `input.locale`. */
export interface TrendsCase {
  id: string;
  note?: string;
  input: TrendsInput;
}

export function trendsContext(c: TrendsCase) {
  return {
    data: trendsPayload(c.input),
    locale: c.input.locale,
    money: moneyMarkers(c.input.currency, currencySymbol(c.input.currency), currencyDisplay(c.input.currency, c.input.currencyDisplayFormat)),
  };
}

export const trendsSummaryTask: BenchTask<TrendsCase> = {
  name: "trends.summary",
  baseParams: { temperature: 0.4, responseFormat: "json_object", jsonSchema: INSIGHTS_SCHEMAS["trends.summary"] },
  body: (c) => trendsBody(c.input),
  grade: (content, c) => gradeTrends(content, trendsContext(c)),
};
