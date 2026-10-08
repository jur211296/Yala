import { gradeCards, moneyMarkers } from "../lib/insightsGrading";
import { cardsBody, cardsPayload, currencyDisplay, currencySymbol, type CardsInput } from "../lib/insightsRequests";
import { INSIGHTS_SCHEMAS } from "./insights.schemas";
import type { BenchTask } from "./types";

/** Un caso: lo que la app tiene a mano al pedir el análisis de Insights. `locale` = idioma de la app del usuario. */
export interface CardsCase {
  id: string;
  locale: string;
  note?: string;
  input: CardsInput;
}

export function cardsContext(c: CardsCase) {
  return {
    data: cardsPayload(c.input),
    locale: c.locale,
    money: moneyMarkers(c.input.currency, currencySymbol(c.input.currency), currencyDisplay(c.input.currency, c.input.currencyDisplayFormat)),
  };
}

export const insightsCardsTask: BenchTask<CardsCase> = {
  name: "insights.cards",
  baseParams: { temperature: 0.4, responseFormat: "json_object", jsonSchema: INSIGHTS_SCHEMAS["insights.cards"] },
  body: (c) => cardsBody(c.input),
  grade: (content, c) => gradeCards(content, cardsContext(c)),
};
