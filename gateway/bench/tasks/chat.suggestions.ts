import { TASK_SCHEMAS } from "../../src/ai/routes";
import { suggestionsBody } from "../lib/appRequests";
import { gradeSuggestions, type SuggestionsCase } from "../lib/grading";
import type { BenchTask } from "./types";

export const suggestionsTask: BenchTask<SuggestionsCase> = {
  name: "chat.suggestions",
  baseParams: { temperature: 0.7, responseFormat: "json_object", jsonSchema: TASK_SCHEMAS["chat.suggestions"] },
  body: (c) => suggestionsBody(c.context),
  grade: (content, c) => gradeSuggestions(content, c),
};
