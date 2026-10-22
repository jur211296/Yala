/**
 * Esquemas de respuesta de las cuatro tareas de Insights y Tendencias, con la forma de `TASK_SCHEMAS` de
 * `src/ai/routes.ts` (Frank los moverá allí al encender las filas). Solo los usa quien no tiene «JSON libre»
 * (Anthropic, por `output_config.format`) o una fila con `strictSchema`.
 *
 * Son lo que lee la app, ni más ni menos: `tip` y `funFact` son opcionales en la app (`as? String`), así que aquí
 * van obligatorios pero admiten `null`, que la app lee igual que «no está». `sentiment` y `chart` llevan su
 * enumerado: la app trata un valor desconocido como neutro / sin icono propio.
 */
const CARDS_SCHEMA = {
  name: "insights_cards",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["hero", "cards", "funFact"],
    properties: {
      hero: { type: "string" },
      cards: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["icon", "text", "sentiment", "tip"],
          properties: {
            icon: { type: "string" },
            text: { type: "string" },
            sentiment: { type: "string", enum: ["positive", "neutral", "attention"] },
            tip: { type: ["string", "null"] },
          },
        },
      },
      funFact: { type: ["string", "null"] },
    },
  },
} as const;

const COMMENT_SCHEMA = (name: string) =>
  ({
    name,
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["comment"],
      properties: { comment: { type: ["string", "null"] } },
    },
  }) as const;

const TRENDS_SCHEMA = {
  name: "trends_summary",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["bullets"],
    properties: {
      bullets: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["chart", "text"],
          properties: {
            chart: { type: "string", enum: ["trend", "comparison", "cashflow", "weekday"] },
            text: { type: "string" },
          },
        },
      },
    },
  },
} as const;

export const INSIGHTS_SCHEMAS = {
  "insights.cards": CARDS_SCHEMA,
  "insights.cashflow": COMMENT_SCHEMA("insights_cashflow"),
  "insights.deviation": COMMENT_SCHEMA("insights_deviation"),
  "trends.summary": TRENDS_SCHEMA,
} as const;
