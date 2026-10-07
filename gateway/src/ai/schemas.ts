/**
 * Esquemas de respuesta de las tareas de la sesión 2 · chat y nota, con la forma de `TASK_SCHEMAS`
 * (`routes.ts`): `{ name, schema }`. Son lo que parsea la app, ni más ni menos (ver `bench/lib/textParse.ts` y
 * `bench/lib/chatRewrite.ts`, que replican sus parsers).
 *
 * Para qué: un proveedor sin modo «JSON libre» (Anthropic) solo garantiza JSON con un esquema
 * (`output_config.format`); con OpenAI solo se usan si la fila pide `strictSchema`.
 */

/** `LLMMultipleResponse` de `TranscriptionParserService`: `note` e `isExpense` obligatorios, `confidence` con sus cinco números. */
export const TEXT_PARSE_SCHEMA = {
  name: "text_parse",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["transactions"],
    properties: {
      transactions: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["amount", "date", "note", "isExpense", "subcategoryHint", "tagHints", "currencyHint", "confidence"],
          properties: {
            amount: { type: ["number", "null"] },
            date: { type: ["string", "null"] },
            note: { type: "string" },
            isExpense: { type: "boolean" },
            subcategoryHint: { type: ["string", "null"] },
            tagHints: { type: "array", items: { type: "string" } },
            currencyHint: { type: ["string", "null"] },
            confidence: {
              type: "object",
              additionalProperties: false,
              required: ["amount", "date", "merchant", "subcategory", "tags"],
              properties: {
                amount: { type: "number" },
                date: { type: "number" },
                merchant: { type: "number" },
                subcategory: { type: "number" },
                tags: { type: "number" },
              },
            },
          },
        },
      },
    },
  },
} as const;

/** `SuggestionsRewriterService.parseRewritten`: `{ "suggestions": [String] }`, no vacío. */
export const CHAT_REWRITE_SCHEMA = {
  name: "chat_rewrite",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["suggestions"],
    properties: { suggestions: { type: "array", items: { type: "string" } } },
  },
} as const;

export const CHAT_AND_NOTE_SCHEMAS = {
  "text.parse": TEXT_PARSE_SCHEMA,
  "chat.rewrite": CHAT_REWRITE_SCHEMA,
} as const;
