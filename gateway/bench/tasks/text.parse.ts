import { TEXT_PARSE_SCHEMA } from "../../src/ai/schemas";
import { gradeTextParse, textParseBody, type TextParseCase } from "../lib/textParse";
import type { BenchTask } from "./types";

/**
 * `text.parse` — `TranscriptionParserService.parseMultiple` (nota de voz, registro desde el chat y Siri).
 * Parámetros de la fila desde el 2026-10-09: JSON estricto con `TEXT_PARSE_SCHEMA` (`json_object` + `strictSchema`),
 * igual que `ROUTES["text.parse"]`. Antes era texto libre (el prompt pedía JSON y la app quitaba las vallas).
 */
export const textParseTask: BenchTask<TextParseCase> = {
  name: "text.parse",
  baseParams: { temperature: 0.1, responseFormat: "json_object", jsonSchema: TEXT_PARSE_SCHEMA, strictSchema: true },
  body: (c) => textParseBody(c),
  grade: (content, c) => gradeTextParse(content, c),
};
