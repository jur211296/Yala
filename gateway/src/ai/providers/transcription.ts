import type { TranscriptionRoute } from "../routes";
import { OPENAI_BASE } from "./openai";

/**
 * Transcripción gestionada (sesión 2): el gateway decide modelo y parámetros de `voice.transcribe`, como en el chat.
 *
 * Entrada: el multipart que manda la app (SDK MacPaw: `file`, `model`, `language` ISO 639-1 y, desde la sesión 2,
 * `prompt` con los nombres de comercios y subcategorías del usuario, uno por línea). Salida: el JSON del proveedor
 * (`{ "text": … }`), que es lo que decodifica la app.
 *
 * Por qué se rehace el multipart y no se reenvía: `gpt-transcribe` no acepta `language` (usa `languages[]`, y mandar
 * los dos tumba la petición) y quiere los términos como `keywords[]`, uno por campo
 * (developers.openai.com/api/docs/guides/speech-to-text, 2026-10-07).
 */

export interface TranscriptionResult {
  status: number;
  body: string;
  model: string;
  /** Solo diagnóstico, sin contenido del usuario. */
  error?: string;
}

/** Un término vale si cabe en una línea y no trae `<`, `>` ni saltos (lo que `keywords[]` rechaza). */
export function sanitizeKeyword(raw: string): string | null {
  const k = raw.replace(/[<>\r\n]/g, " ").replace(/\s+/g, " ").trim();
  return k.length >= 2 && k.length <= 64 ? k : null;
}

/**
 * Los términos del usuario desde el `prompt` de la app: uno por línea, sin repetir. Solo por línea: un nombre que la
 * persona escribió con coma («Pollos, Brasas y Más») es un término, no tres.
 */
export function keywordsFrom(prompt: string | null, max: number): string[] {
  if (!prompt) return [];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const part of prompt.split("\n")) {
    const k = sanitizeKeyword(part);
    if (!k || seen.has(k.toLowerCase())) continue;
    seen.add(k.toLowerCase());
    out.push(k);
    if (out.length >= max) break;
  }
  return out;
}

/** El idioma que manda la app, si es un código razonable (ISO 639-1, o `zh-cn`/`zh-tw`/`zh-hk`). */
export function languageFrom(raw: string | null): string | null {
  if (!raw) return null;
  const v = raw.trim().toLowerCase();
  return /^[a-z]{2}(-[a-z]{2})?$/.test(v) ? v : null;
}

/** El multipart hacia el proveedor según la fila. */
export async function buildTranscriptionForm(bytes: Uint8Array, contentType: string, route: TranscriptionRoute): Promise<FormData | null> {
  let incoming: FormData;
  try {
    incoming = await new Request("https://gateway.local/in", { method: "POST", headers: { "content-type": contentType }, body: bytes }).formData();
  } catch {
    return null;
  }
  const file = incoming.get("file");
  if (!file || typeof file === "string") return null;
  const p = route.params;
  const out = new FormData();
  out.append("file", file, (file as File).name || "audio.m4a");
  out.append("model", route.model);
  const language = languageFrom(typeof incoming.get("language") === "string" ? (incoming.get("language") as string) : null);
  if (language) out.append(p.languageField === "languages" ? "languages[]" : "language", language);
  if (p.maxKeywords > 0) {
    const prompt = incoming.get("prompt");
    for (const k of keywordsFrom(typeof prompt === "string" ? prompt : null, p.maxKeywords)) out.append("keywords[]", k);
  }
  if (p.prompt) out.append("prompt", p.prompt);
  return out;
}

export async function sendTranscription(bytes: Uint8Array, contentType: string, route: TranscriptionRoute, key: string | undefined, doFetch: typeof fetch = fetch): Promise<TranscriptionResult> {
  if (!key) return { status: 503, body: JSON.stringify({ error: { message: "Sin clave del proveedor.", type: "yala_upstream_error", param: null, code: "yala_upstream_error" } }), model: route.model, error: "sin clave" };
  const form = await buildTranscriptionForm(bytes, contentType, route);
  if (!form) {
    return { status: 400, body: JSON.stringify({ error: { message: "Audio inválido.", type: "yala_bad_request", param: null, code: "yala_bad_request" } }), model: route.model, error: "multipart" };
  }
  let resp: Response;
  try {
    resp = await doFetch(`${OPENAI_BASE}/audio/transcriptions`, { method: "POST", headers: { authorization: `Bearer ${key}` }, body: form });
  } catch (err) {
    return { status: 502, body: JSON.stringify({ error: { message: "El proveedor de IA no respondió.", type: "yala_upstream_error", param: null, code: "yala_upstream_error" } }), model: route.model, error: `red: ${String(err).slice(0, 120)}` };
  }
  const text = await resp.text();
  return { status: resp.status, body: text, model: route.model, ...(resp.ok ? {} : { error: `openai ${resp.status}` }) };
}
