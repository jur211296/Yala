import { readFileSync } from "node:fs";
import { chatAnswerBody, gradeChatAnswer, personaContext, resolveRef, triggersAnomalies, type ChatAnswerCase } from "../lib/chatAnswer";
import type { Persona, SpendHabit } from "../lib/chatContext";
import type { BenchTask } from "./types";

/**
 * `chat.answer` — `ChatAssistantService.runAskFlow`: la respuesta del asistente con el contexto financiero
 * entero (Opción B, sin function calling). Hoy `gpt-4.1-mini`, temperatura 0.4, texto libre; corte de la app
 * a los 20 s (`timeoutSeconds`).
 *
 * Los casos traen personas (no JSON hecho a mano): `lib/chatContext.ts` genera su libro y lo agrega como la
 * app. Los turnos previos pueden citar cifras del contexto con `{{ruta|decimales}}`.
 */

interface CaseFile {
  habitTemplates: Record<string, SpendHabit[]>;
  personas: (Omit<Persona, "habits"> & { habits: SpendHabit[] | string; scale?: number })[];
  cases: ChatAnswerCase[];
}

const FILE = JSON.parse(readFileSync(new URL("../cases/chat.answer.json", import.meta.url), "utf8")) as CaseFile;

function round(x: number, d: number): number {
  return Math.round(x * 10 ** d) / 10 ** d;
}

/** Los hábitos de plantilla se escalan a la divisa de la persona (la plantilla va en «dólares»). */
export const PERSONAS: Map<string, Persona> = new Map(
  FILE.personas.map((p) => {
    const habits = typeof p.habits === "string"
      ? FILE.habitTemplates[p.habits].map((h) => ({ ...h, min: round(h.min * (p.scale ?? 1), p.decimals), max: round(h.max * (p.scale ?? 1), p.decimals) }))
      : p.habits;
    return [p.id, { ...p, habits } as Persona];
  }),
);

function persona(id: string): Persona {
  const p = PERSONAS.get(id);
  if (!p) throw new Error(`chat.answer: persona desconocida «${id}»`);
  return p;
}

/** Sustituye `{{ruta|decimales}}` en los turnos previos por la cifra del contexto (la que la app habría dicho). */
export function materializeTurns(c: ChatAnswerCase): ChatAnswerCase {
  if (!c.turns?.length) return c;
  const p = persona(c.persona);
  const b = personaContext(p);
  const fill = (s: string) => s.replace(/\{\{([^|}]+)\|(\d)\}\}/g, (_w, ref: string, d: string) => {
    const v = Number(resolveRef(b.context, ref, b.lproj));
    return v.toLocaleString(p.language, { minimumFractionDigits: Number(d), maximumFractionDigits: Number(d) });
  });
  return { ...c, turns: c.turns.map((t) => ({ q: fill(t.q), a: fill(t.a) })) };
}

for (const c of FILE.cases) {
  if (triggersAnomalies(c.question)) throw new Error(`chat.answer: «${c.id}» activaría las anomalías (no replicadas): reescribe la pregunta`);
}

export const chatAnswerTask: BenchTask<ChatAnswerCase> = {
  name: "chat.answer",
  baseParams: { temperature: 0.4, responseFormat: "text" },
  body: (c) => chatAnswerBody(persona(c.persona), materializeTurns(c)),
  grade: (content, c) => gradeChatAnswer(content, materializeTurns(c), persona(c.persona)),
};
