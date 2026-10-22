import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { ADAPTERS } from "../../src/ai/providers";
import type { ProviderKeys, Usage } from "../../src/ai/providers/types";
import type { ManagedRoute, ProviderId, ReasoningEffort } from "../../src/ai/routes";
import { CANDIDATES, costUSD, type Price } from "../candidates";
import { personaContext, type ChatAnswerCase } from "./chatAnswer";
import type { Persona } from "./chatContext";

/**
 * Juez de `chat.answer` para lo que el criterio determinista no ve: una cifra real atribuida a otra cosa
 * (el gasto del mes pasado presentado como el de este), un cálculo mal hecho, decir «no tengo ese dato» cuando
 * está en el JSON, o no contestar lo que se preguntó.
 *
 * Reglas (encargo de la sesión 2): el juez es OTRO modelo, de otro proveedor que el candidato (nadie se juzga a
 * sí mismo ni a su familia), y solo decide si su acuerdo con una muestra puntuada a mano es alto. No juzga
 * idioma, tono ni longitud: eso lo mide el criterio determinista o no cuenta.
 */

export interface JudgeSpec {
  id: string;
  provider: ProviderId;
  model: string;
  effort?: ReasoningEffort;
  price: Price;
}

function candidatePrice(id: string): Price {
  const c = CANDIDATES.find((x) => x.id === id);
  if (!c) throw new Error(`juez: ${id} no está en candidates.ts`);
  return c.price;
}

export const JUDGES: Record<string, JudgeSpec> = {
  "gemini:gemini-3.8-flash": { id: "gemini:gemini-3.8-flash", provider: "gemini", model: "gemini-3.8-flash", effort: "low", price: candidatePrice("gemini:gemini-3.8-flash") },
  "anthropic:claude-haiku-5-5": { id: "anthropic:claude-haiku-5-5", provider: "anthropic", model: "claude-haiku-5-5", effort: "low", price: candidatePrice("anthropic:claude-haiku-5-5") },
  "anthropic:claude-sonnet-5-5": { id: "anthropic:claude-sonnet-5-5", provider: "anthropic", model: "claude-sonnet-5-5", effort: "low", price: candidatePrice("anthropic:claude-sonnet-5-5") },
  "openai:gpt-6.1-sol": { id: "openai:gpt-6.1-sol", provider: "openai", model: "gpt-6.1-sol", effort: "low", price: candidatePrice("openai:gpt-6.1-sol") },
};

export const JUDGE_SCHEMA = {
  name: "chat_answer_verdict",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["verdict", "reason"],
    properties: { verdict: { type: "string", enum: ["pass", "fail"] }, reason: { type: "string" } },
  },
} as const;

const RUBRIC = `Eres un evaluador estricto de un asistente financiero de una app de finanzas personales. El asistente recibió los DATOS DEL USUARIO (JSON) y contestó a la última pregunta. Decide si la respuesta es CORRECTA.

Es "pass" solo si se cumplen las tres:
1. Contesta lo que se preguntó (si la pregunta pide un dato que NO está en el JSON, lo correcto es decir que no lo tiene; si no es de finanzas, lo correcto es redirigir amablemente).
2. Cada cifra y cada afirmación es correcta según el JSON: la cifra de la cosa, del período y de la comparación que dice (no la del mes pasado como si fuera la de este, no una categoría por otra). Valen los redondeos razonables y los cálculos simples bien hechos (sumas, diferencias, porcentajes, lo que queda de un presupuesto). Ojo: el mes en curso todavía no ha terminado.
3. No inventa datos, comercios, categorías ni cifras que no salgan del JSON.

NO evalúes el idioma, el tono, el formato ni la longitud. Un error de cálculo, una cifra atribuida a otra cosa, contestar otra pregunta o negar un dato que sí está en el JSON es "fail".

Responde SOLO con JSON: {"verdict": "pass" | "fail", "reason": "<una frase en español>"}.`;

export function judgeMessages(p: Persona, c: ChatAnswerCase, answer: string): { role: string; content: string }[] {
  const b = personaContext(p);
  const turns = (c.turns ?? []).map((t) => `Usuario: ${t.q}\nAsistente: ${t.a}`).join("\n\n");
  const user = [
    `Hoy es ${p.today}. Idioma del usuario: ${p.language}. Divisa: ${b.context.metadata.currency} (${b.context.metadata.currency_display}).`,
    `DATOS DEL USUARIO (JSON):\n${b.json}`,
    turns ? `CONVERSACIÓN PREVIA:\n${turns}` : "",
    `PREGUNTA:\n${c.question}`,
    `RESPUESTA DEL ASISTENTE:\n${answer}`,
  ].filter(Boolean).join("\n\n");
  return [{ role: "system", content: RUBRIC }, { role: "user", content: user }];
}

function readKey(name: string): string | undefined {
  const p = `${homedir()}/Secrets/yala-ai-bench/${name}.key`;
  return existsSync(p) ? readFileSync(p, "utf8").trim() : undefined;
}

let keyCache: ProviderKeys | null = null;
function keys(): ProviderKeys {
  if (!keyCache) keyCache = { openai: readKey("openai"), gemini: readKey("gemini"), anthropic: readKey("anthropic"), xai: readKey("xai") };
  return keyCache;
}

export interface JudgeResult {
  verdict: "pass" | "fail" | null;
  reason: string;
  status: number;
  ms: number;
  usage: Usage | null;
  cost: number | null;
  error?: string;
}

export async function runJudge(j: JudgeSpec, messages: { role: string; content: string }[]): Promise<JudgeResult> {
  const route: ManagedRoute = {
    mode: "managed",
    provider: j.provider,
    model: j.model,
    params: { responseFormat: "json_object", jsonSchema: JUDGE_SCHEMA, reasoningEffort: j.effort },
    retries: 1,
  };
  const started = performance.now();
  const res = await ADAPTERS[j.provider].send({ messages }, route, { keys: keys() });
  const ms = Math.round(performance.now() - started);
  const base = { status: res.status, ms, usage: res.usage, cost: costUSD(j.price, res.usage) };
  if (res.status !== 200) return { ...base, verdict: null, reason: "", error: res.error?.slice(0, 200) };
  const content = (JSON.parse(res.body) as { choices?: { message?: { content?: string } }[] }).choices?.[0]?.message?.content ?? "";
  try {
    const v = JSON.parse(content.trim().replace(/^```(?:json)?|```$/g, "")) as { verdict?: string; reason?: string };
    const verdict = v.verdict === "pass" || v.verdict === "fail" ? v.verdict : null;
    return { ...base, verdict, reason: String(v.reason ?? "").slice(0, 300) };
  } catch {
    return { ...base, verdict: null, reason: content.slice(0, 200), error: "veredicto no JSON" };
  }
}

/** Jueces que pueden juzgar a un candidato: ninguno de su mismo proveedor. */
export function judgesFor(candidateProvider: string, judgeIds: string[]): JudgeSpec[] {
  return judgeIds.map((id) => JUDGES[id]).filter((j) => j && j.provider !== candidateProvider);
}

/** FNV-1a de 32 bits: identifica una respuesta para no pagar dos veces el mismo juicio. */
export function answerHash(s: string): string {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h.toString(16).padStart(8, "0");
}

/** Cohen's kappa entre dos listas de veredictos binarios. */
export function agreement(a: boolean[], b: boolean[]): { n: number; accuracy: number; kappa: number; tp: number; tn: number; fp: number; fn: number } {
  let tp = 0, tn = 0, fp = 0, fn = 0;
  for (let i = 0; i < a.length; i++) {
    if (a[i] && b[i]) tp++;
    else if (!a[i] && !b[i]) tn++;
    else if (!a[i] && b[i]) fp++;
    else fn++;
  }
  const n = a.length;
  const po = (tp + tn) / n;
  const pe = ((tp + fn) / n) * ((tp + fp) / n) + ((tn + fp) / n) * ((tn + fn) / n);
  return { n, accuracy: po, kappa: pe === 1 ? 1 : (po - pe) / (1 - pe), tp, tn, fp, fn };
}
