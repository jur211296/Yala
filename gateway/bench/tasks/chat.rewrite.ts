import { CHAT_REWRITE_SCHEMA } from "../../src/ai/schemas";
import { gradeRewrite, rewriteBody, type RewriteCase } from "../lib/chatRewrite";
import type { BenchTask } from "./types";

/** `chat.rewrite` — `SuggestionsRewriterService.rewrite`. Hoy `gpt-4.1-mini`, temperatura 0.3, `json_object`. */
export const chatRewriteTask: BenchTask<RewriteCase> = {
  name: "chat.rewrite",
  baseParams: { temperature: 0.3, responseFormat: "json_object", jsonSchema: CHAT_REWRITE_SCHEMA },
  body: (c) => rewriteBody(c),
  grade: (content, c) => gradeRewrite(content, c),
};
