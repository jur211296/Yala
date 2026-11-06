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
          required: ["amount", "date", "note", "isExpense", "subcategoryHint", "tagHints", "currencyHint", "paymentHint", "confidence"],
          properties: {
            amount: { type: ["number", "null"] },
            date: { type: ["string", "null"] },
            note: { type: "string" },
            isExpense: { type: "boolean" },
            subcategoryHint: { type: ["string", "null"] },
            tagHints: { type: "array", items: { type: "string" } },
            currencyHint: { type: ["string", "null"] },
            // Las palabras del medio de pago que dijo el usuario («yape», «tarjeta»), o null (card v466, 2026-11-04). Las
            // versiones instaladas lo ignoran al decodificar; la app nueva elige la cuenta con él.
            paymentHint: { type: ["string", "null"] },
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

/**
 * `ReceiptSplitResponse` de `ReceiptSplitService` (repartir un recibo en un grupo, 2.3): las líneas del recibo y, por
 * línea, los nombres tal como los escribió la persona en la frase («Ana», `@me` para «yo», `@all` para «todos»). El
 * miembro lo elige la app: los nombres del grupo no viajan. Las mismas claves para foto (`receipt.photo`) y voz
 * (`receipt.voice`).
 */
export const RECEIPT_SPLIT_SCHEMA = {
  name: "receipt_split",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["merchant", "currency", "printedTotal", "lines"],
    properties: {
      merchant: { type: ["string", "null"] },
      currency: { type: ["string", "null"] },
      printedTotal: { type: ["number", "null"] },
      lines: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["description", "amount", "kind", "people"],
          properties: {
            description: { type: "string" },
            amount: { type: "number" },
            kind: { type: "string", enum: ["item", "tip", "tax", "service", "discount"] },
            people: { type: "array", items: { type: "string" } },
          },
        },
      },
    },
  },
} as const;

export const CHAT_AND_NOTE_SCHEMAS = {
  "text.parse": TEXT_PARSE_SCHEMA,
  "chat.rewrite": CHAT_REWRITE_SCHEMA,
  "receipt.photo": RECEIPT_SPLIT_SCHEMA,
  "receipt.voice": RECEIPT_SPLIT_SCHEMA,
} as const;
