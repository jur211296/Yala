import { TASK_SCHEMAS } from "../../src/ai/routes";
import { intentBody } from "../lib/appRequests";
import { gradeIntent, type IntentCase } from "../lib/grading";
import type { BenchTask } from "./types";

export const intentTask: BenchTask<IntentCase> = {
  name: "chat.intent",
  baseParams: { temperature: 0, responseFormat: "json_object", jsonSchema: TASK_SCHEMAS["chat.intent"] },
  body: (c) => intentBody(c.text),
  grade: (content, c) => gradeIntent(content, c),
};
