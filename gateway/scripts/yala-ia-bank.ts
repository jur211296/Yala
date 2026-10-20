/**
 * Banco de preguntas de Yala IA contra un gateway desplegado (revisión del 2026-10-20, `docs/ai/revision-ia-2-2.md`).
 *
 * Lee las peticiones EXACTAS que la app construye sobre la semilla `realista` (las vuelca
 * `YalaTests/AIBank/YalaIABankDumpTests.swift` en `<dir>/requests.jsonl`) y las manda como el teléfono: primero
 * `chat.intent` con el prompt del clasificador leído del Swift —salvo que el teléfono ya haya decidido la ruta—, y si
 * sale «pregunta», `chat.answer` con el contexto y el prompt de la app. Guarda las respuestas en `<dir>/answers.jsonl`.
 * Nunca imprime el token.
 *
 *   npx vite-node scripts/yala-ia-bank.ts -- --dir <carpeta> \
 *     --base https://yala-gateway-staging.misty-surf-6866.workers.dev \
 *     --dev-secret-file ~/Secrets/yala-gateway/staging-dev-shared-secret
 *
 * Solo staging: el bypass de desarrollo no existe en producción. En staging la cuota del chat corre en `observe`.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { intentBody } from "../bench/lib/appRequests";

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}
const expand = (p: string) => p.replace(/^~/, homedir());

const BASE = arg("base") ?? "";
const DIR = arg("dir") ?? "";
if (!BASE || !DIR) throw new Error("faltan --base y --dir");
if (BASE.includes("yala-gateway.") && !BASE.includes("staging")) throw new Error("solo staging");

/** Umbral de `ChatIntentClassifierService.minConfidence`. */
const MIN_CONFIDENCE = 0.7;

async function token(): Promise<string> {
  const sf = arg("dev-secret-file");
  if (!sf) throw new Error("falta --dev-secret-file");
  const res = await fetch(`${BASE}/v1/attest/dev`, {
    method: "POST",
    headers: { "X-Yala-Dev-Secret": readFileSync(expand(sf), "utf8").trim(), "X-Yala-Dev-Tier": "pro" },
  });
  if (!res.ok) throw new Error(`/v1/attest/dev → ${res.status}`);
  return ((await res.json()) as { sessionToken: string }).sessionToken;
}

interface Call {
  status: number;
  ms: number;
  content?: string;
  model?: string;
  usage?: { prompt_tokens?: number; completion_tokens?: number; prompt_tokens_details?: { cached_tokens?: number } };
  error?: string;
}

async function call(tok: string, task: string, category: string, body: unknown): Promise<Call> {
  const started = Date.now();
  const res = await fetch(`${BASE}/v1/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${tok}`,
      "Content-Type": "application/json",
      "X-Yala-Category": category,
      "X-Yala-Task": task,
    },
    body: JSON.stringify(body),
  });
  const json = (await res.json().catch(() => ({}))) as {
    model?: string;
    choices?: { message?: { content?: string } }[];
    usage?: Call["usage"];
    error?: { type?: string; message?: string };
  };
  return {
    status: res.status,
    ms: Date.now() - started,
    content: json.choices?.[0]?.message?.content,
    model: json.model,
    usage: json.usage,
    error: json.error?.type,
  };
}

/** Réplica de `classify`: JSON del clasificador + umbral (por debajo de 0,7 → ambiguous). */
function intentOf(content: string | undefined): { intent: string; confidence: number } {
  try {
    const o = JSON.parse(content ?? "") as { intent?: string; confidence?: number };
    const confidence = Math.max(0, Math.min(1, o.confidence ?? 0));
    const intent = o.intent ?? "ask";
    if (intent !== "ambiguous" && confidence < MIN_CONFIDENCE) return { intent: "ambiguous", confidence };
    return { intent, confidence };
  } catch {
    return { intent: "fallback", confidence: 0 };
  }
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const tok = await token();
const lines = readFileSync(join(DIR, "requests.jsonl"), "utf8").split("\n").filter(Boolean);
const only = arg("only")?.split(",");
const out: string[] = [];
for (const line of lines) {
  const r = JSON.parse(line) as { id: string; q: string; route: string; askBody: unknown; expect: string; kind: string; lang: string };
  if (only && !only.includes(r.id)) continue;
  let intent = r.route;
  let classifier: (Call & { confidence?: number }) | undefined;
  if (r.route === "classify") {
    const c = await call(tok, "chat.intent", "suggestions", intentBody(r.q));
    const parsed = intentOf(c.content);
    intent = parsed.intent;
    classifier = { ...c, confidence: parsed.confidence };
    delete classifier.content;
  }
  let answer: Call | undefined;
  if (intent === "ask") {
    answer = await call(tok, "chat.answer", "chat", r.askBody);
  }
  const row = {
    id: r.id,
    kind: r.kind,
    lang: r.lang,
    expect: r.expect,
    q: r.q,
    route: r.route,
    intent,
    classifierMs: classifier?.ms ?? 0,
    classifierStatus: classifier?.status,
    confidence: classifier?.confidence,
    answerMs: answer?.ms ?? 0,
    answerStatus: answer?.status,
    answer: answer?.content ?? (answer ? `ERROR ${answer.status} ${answer.error}` : undefined),
    promptTokens: answer?.usage?.prompt_tokens,
    cachedTokens: answer?.usage?.prompt_tokens_details?.cached_tokens,
    completionTokens: answer?.usage?.completion_tokens,
    model: answer?.model,
  };
  out.push(JSON.stringify(row));
  console.log(`${r.id} · ${intent} · ${row.classifierMs + row.answerMs} ms`);
  await sleep(600);
}
writeFileSync(join(DIR, arg("out") ?? "answers.jsonl"), out.join("\n") + "\n");
console.log(`escritas ${out.length} respuestas`);
