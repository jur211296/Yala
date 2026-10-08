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

/**
 * Lo que la app manda desde el 2026-10-07: el idioma de la app (`locale` del caso), no `input.language`, que guarda
 * el idioma de la región con el que se midió la sesión 2.
 */
export function cardsInput(c: CardsCase): CardsInput {
  return { ...c.input, language: c.locale };
}

export function cardsContext(c: CardsCase) {
  return {
    data: cardsPayload(cardsInput(c)),
    locale: c.locale,
    money: moneyMarkers(c.input.currency, currencySymbol(c.input.currency), currencyDisplay(c.input.currency, c.input.currencyDisplayFormat)),
  };
}

export const insightsCardsTask: BenchTask<CardsCase> = {
  name: "insights.cards",
  baseParams: { temperature: 0.4, responseFormat: "json_object", jsonSchema: INSIGHTS_SCHEMAS["insights.cards"] },
  body: (c) => cardsBody(cardsInput(c)),
  grade: (content, c) => gradeCards(content, cardsContext(c)),
};
