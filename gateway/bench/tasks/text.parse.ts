import { TEXT_PARSE_SCHEMA } from "../../src/ai/schemas";
import { gradeTextParse, textParseBody, type TextParseCase } from "../lib/textParse";
import type { BenchTask } from "./types";

/**
 * `text.parse` — `TranscriptionParserService.parseMultiple` (nota de voz, registro desde el chat y Siri).
 * Parámetros de hoy: `gpt-4.1-mini`, temperatura 0.1, sin `response_format`. El esquema solo lo usaría un
 * proveedor que lo necesite con `json_object` (Anthropic); en texto no se manda.
 */
export const textParseTask: BenchTask<TextParseCase> = {
  name: "text.parse",
  baseParams: { temperature: 0.1, responseFormat: "text", jsonSchema: TEXT_PARSE_SCHEMA },
  body: (c) => textParseBody(c),
  grade: (content, c) => gradeTextParse(content, c),
};
