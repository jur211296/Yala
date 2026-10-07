/**
 * Verificación en vivo del proxy de IA tras un despliegue: manda las peticiones EXACTAS de la app (las del banco,
 * prompts leídos del Swift) a un gateway desplegado y dice, por tarea, qué contestó y con qué modelo. Nunca imprime
 * contenido ni el token.
 *
 *   # staging: token por el bypass de dev (solo staging; el secreto vive en ~/Secrets/yala-gateway/)
 *   npx vite-node scripts/verify-ai.ts -- --base https://yala-gateway-staging.misty-surf-6866.workers.dev \
 *        --dev-secret-file ~/Secrets/yala-gateway/staging-dev-shared-secret --tier pro
 *
 *   # producción: token de 15 min acuñado a mano para un dispositivo ficticio (aprobado por Jürgen, ver PR)
 *   npx vite-node scripts/verify-ai.ts -- --base https://<prod> --token-file /ruta/token --tier free --trial
 *
 * Opciones: `--headers` manda X-Yala-Task como la app nueva (por defecto, sin cabecera como las instaladas);
 * `--trial` recorre el cupo de prueba (6 notas y 6 fotos) y espera el 403 en la sexta, a ritmo de persona (una nota
 * cada 25 s, una foto cada 13 s: la ráfaga del plan free es de 5 llamadas por minuto); `--audio <m4a>`.
 */
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { intentBody, photoReadBody, suggestionsBody } from "../bench/lib/appRequests";

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}
const flag = (name: string) => process.argv.includes(`--${name}`);
const expand = (p: string) => p.replace(/^~/, homedir());

const BASE = arg("base") ?? "";
if (!BASE) throw new Error("falta --base");
const withHeaders = flag("headers");
const tier = arg("tier") === "free" ? "free" : "pro";

async function token(): Promise<string> {
  const tf = arg("token-file");
  if (tf) return readFileSync(expand(tf), "utf8").trim();
  const sf = arg("dev-secret-file");
  if (!sf) throw new Error("falta --token-file o --dev-secret-file");
  const res = await fetch(`${BASE}/v1/attest/dev`, {
    method: "POST",
    headers: { "X-Yala-Dev-Secret": readFileSync(expand(sf), "utf8").trim(), "X-Yala-Dev-Tier": tier },
  });
  if (!res.ok) throw new Error(`/v1/attest/dev → ${res.status}`);
  return ((await res.json()) as { sessionToken: string }).sessionToken;
}

const IMAGE = readFileSync(new URL("../../Yala/Resources/Assets.xcassets/ExampleImages/example-bank-alert-es.imageset/example-bank-alert-es.png", import.meta.url)).toString("base64");
const PARSE = {
  model: "gpt-4.1-mini",
  messages: [
    { role: "system", content: "Extrae movimientos de este texto dictado y responde SOLO JSON." },
    { role: "user", content: "taxi 12 soles" },
  ],
  temperature: 0.1,
  stream: false,
};

interface Probe {
  task: string;
  category: string;
  body: Record<string, unknown>;
}

const PROBES: Probe[] = [
  { task: "photo.read", category: "vision", body: photoReadBody(IMAGE, new Date().toISOString().slice(0, 10)) },
  { task: "chat.intent", category: "suggestions", body: intentBody("ayer gasté 45 soles en el mercado") },
  {
    task: "chat.suggestions",
    category: "suggestions",
    body: suggestionsBody({ language: "es-PE", topCategories: ["Comida"], subcategoryNames: ["Mercado"], merchantNames: ["Plaza Vea"], activeBudgets: [], tagNames: [], recurringPaidNames: [], totalIncome: 3000, totalExpense: 1200 }),
  },
  { task: "text.parse", category: "voice", body: PARSE },
  {
    task: "chat.answer",
    category: "chat",
    body: { model: "gpt-4.1-mini", messages: [{ role: "system", content: "Eres Yala IA. Contexto: gastos del mes 1200 PEN." }, { role: "user", content: "¿Cuánto gasté este mes?" }], temperature: 0.4, stream: false },
  },
  {
    task: "chat.rewrite",
    category: "suggestions",
    body: {
      model: "gpt-4.1-mini",
      messages: [
        { role: "system", content: "You rewrite chat suggestion phrases for a personal finance app. Reply as JSON {\"rewritten\": [..]}." },
        { role: "user", content: "Rewrite: ¿Cuánto gasté en Starbucks?" },
      ],
      response_format: { type: "json_object" },
      temperature: 0.3,
      stream: false,
    },
  },
];

async function chat(tok: string, p: Probe): Promise<{ status: number; type?: string; model?: string; ms: number }> {
  const started = Date.now();
  const res = await fetch(`${BASE}/v1/chat/completions`, {
    method: "POST",
    headers: { Authorization: `Bearer ${tok}`, "Content-Type": "application/json", "X-Yala-Category": p.category, ...(withHeaders ? { "X-Yala-Task": p.task } : {}) },
    body: JSON.stringify(p.body),
  });
  const json = (await res.json().catch(() => ({}))) as { model?: string; error?: { type?: string } };
  return { status: res.status, type: json.error?.type, model: json.model, ms: Date.now() - started };
}

async function transcribe(tok: string, audioPath: string): Promise<{ status: number; type?: string; chars?: number; ms: number }> {
  const form = new FormData();
  form.append("file", new Blob([readFileSync(expand(audioPath))], { type: "audio/m4a" }), "audio.m4a");
  form.append("model", "whisper-1");
  form.append("language", "es");
  const started = Date.now();
  const res = await fetch(`${BASE}/v1/audio/transcriptions`, {
    method: "POST",
    headers: { Authorization: `Bearer ${tok}`, "X-Yala-Category": "voice", ...(withHeaders ? { "X-Yala-Task": "voice.transcribe" } : {}) },
    body: form,
  });
  const json = (await res.json().catch(() => ({}))) as { text?: string; error?: { type?: string } };
  return { status: res.status, type: json.error?.type, chars: json.text?.length, ms: Date.now() - started };
}

const tok = await token();
const audio = arg("audio");
console.log(`gateway ${BASE} · tier ${tier} · ${withHeaders ? "con X-Yala-Task (app nueva)" : "sin cabecera (versiones instaladas)"}`);

if (flag("trial")) {
  if (!audio) throw new Error("--trial necesita --audio");
  const pause = (ms: number) => new Promise((r) => setTimeout(r, ms));
  for (let i = 1; i <= 6; i++) {
    if (i > 1) await pause(25_000);
    const t = await transcribe(tok, audio);
    const p = t.status === 200 ? await chat(tok, PROBES[3]) : null;
    console.log(`nota ${i}: transcribir ${t.status}${t.type ? ` ${t.type}` : ""} · leer ${p ? `${p.status}${p.type ? ` ${p.type}` : ""}` : "—"}`);
  }
  await pause(61_000);
  for (let i = 1; i <= 6; i++) {
    if (i > 1) await pause(13_000);
    const r = await chat(tok, PROBES[0]);
    console.log(`foto ${i}: ${r.status}${r.type ? ` ${r.type}` : ""}`);
  }
} else {
  for (const p of PROBES) {
    const r = await chat(tok, p);
    console.log(`${p.task.padEnd(18)} ${r.status} ${r.type ?? ""} modelo=${r.model ?? "-"} ${r.ms} ms`);
  }
  if (audio) {
    const t = await transcribe(tok, audio);
    console.log(`${"voice.transcribe".padEnd(18)} ${t.status} ${t.type ?? ""} texto=${t.chars ?? 0} caracteres ${t.ms} ms`);
  }
}
