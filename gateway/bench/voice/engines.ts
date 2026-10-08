import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

/**
 * Motores de transcripción del banco de voz: uno por proveedor, cada uno con la petición documentada en su web
 * oficial el día que se escribió (2026-10-07). Todos reciben el MISMO fichero que manda la app (AAC en .m4a,
 * mono, 16 kHz) salvo el streaming de OpenAI, que solo acepta PCM.
 *
 * - OpenAI REST `/v1/audio/transcriptions` — developers.openai.com/api/docs/guides/speech-to-text
 *   `whisper-1` con `language` (lo que manda la app hoy); `gpt-transcribe` con `languages[]` (sustituye a
 *   `language`: no se mandan los dos) y `keywords[]` (una por entrada, sin < > ni saltos de línea).
 *   Apagados: developers.openai.com/api/docs/deprecations — `whisper-1`, `gpt-4o-transcribe`,
 *   `gpt-4o-mini-transcribe` y `gpt-4o-transcribe-diarize` el 2027-02-26; sustitutos `gpt-transcribe` y
 *   `gpt-live-transcribe`.
 * - OpenAI Realtime (WebSocket) con `gpt-live-transcribe` — developers.openai.com/api/docs/guides/realtime-transcription:
 *   sesión `type: "transcription"`, PCM 24 kHz, `turn_detection: null`, `input_audio_buffer.append` + `commit`,
 *   y el texto en `conversation.item.input_audio_transcription.completed`.
 * - xAI REST `POST https://api.x.ai/v1/stt` — docs.x.ai/developers/model-capabilities/audio/speech-to-text:
 *   multipart con `language`, `format=true` (números en cifras; solo en ar, zh, en, fr, de, ja, pt, ru, es, sv y
 *   vi), `keyterm` repetido (máx. 100, 50 caracteres) y `file` el ÚLTIMO. Modelo por defecto
 *   `grok-voice-transcribe-2.0`. `es` = es-MX y `pt` = pt-BR; también `es-ES` y `pt-PT`.
 * - Google Gemini `models.generateContent` con el audio en `inlineData` (`audio/mp4`; 32 tokens por segundo) —
 *   ai.google.dev/gemini-api/docs/audio. Es un modelo general: la transcripción la pide el prompt.
 * - Apple `SpeechAnalyzer` (`SpeechTranscriber` y `DictationTranscriber`) en esta Mac: `voice/apple/transcribe.swift`.
 * - Deepgram `POST https://api.deepgram.com/v1/listen` (`Authorization: Token`, `keyterm` solo con Nova-3) —
 *   developers.deepgram.com/reference/speech-to-text/listen-pre-recorded.
 * - AssemblyAI `POST /v2/upload` + `POST /v2/transcript` (`speech_models`, `language_code`, `keyterms_prompt`) y
 *   sondeo de `GET /v2/transcript/{id}` — assemblyai.com/docs/api-reference/transcripts/submit.
 * - ElevenLabs `POST https://api.elevenlabs.io/v1/speech-to-text` (`xi-api-key`, `model_id=scribe_v2`,
 *   `language_code`, `keyterms` repetido, +0,05 USD/h con ellas) — elevenlabs.io/docs/api-reference/speech-to-text/convert.
 * Estos tres últimos solo corren si su clave está en `~/Secrets/yala-ai-bench/`.
 */

export type Provider = "openai" | "openai-live" | "xai" | "gemini" | "apple" | "deepgram" | "assemblyai" | "elevenlabs";
export type Hints = "auto" | "lang" | "lang+kw";
export type Kind = "clean" | "snr10" | "snr5" | "real";

export interface Clip {
  clip: string;
  kind: Kind;
  locale: string;
  lang: string;
  tts: string | null;
  note: string | null;
  file: string;
  seconds: number;
  refs: string[];
}

export interface Variant {
  id: string;
  provider: Provider;
  /** Clave de `~/Secrets/yala-ai-bench/<key>.key`. */
  key: string;
  model: string;
  hints: Hints;
  /** USD por minuto de audio (null: se calcula por tokens). */
  perMinute: number | null;
  /** USD por 1M tokens, para los que cobran por token. */
  tokenPrice?: { input: number; output: number };
  /** Apagado anunciado (AAAA-MM-DD) o null. */
  shutdown: string | null;
  /** Qué clips mide (por coste). */
  only?: (c: Clip) => boolean;
  /** Gemini: nivel de razonamiento (3.8 Flash no admite `minimal`: medido, 400). */
  thinking?: "minimal" | "low";
  /** OpenAI `gpt-transcribe`: `prompt` fijo (contexto y estilo de escritura). */
  prompt?: string;
  /** xAI: umbral del detector de voz (por defecto 0.5; con él, un audio muy bajo vuelve vacío: medido). */
  xaiVad?: number;
  /** `apple`: qué módulo. */
  appleModule?: "speech" | "dictation";
  note?: string;
}

export interface SttResult {
  status: number;
  text: string;
  ms: number;
  /** Streaming: desde que acaba la voz (commit) hasta el texto final. */
  msAfterSpeech?: number;
  cost: number | null;
  usage?: unknown;
  error?: string;
}

export interface Context {
  keys: Record<string, string | undefined>;
  keywords: string[];
  localeName: string;
}

// ---------- idiomas ----------

const ISO: Record<string, string> = { "zh-Hans": "zh" };
export function iso2(locale: string): string {
  return ISO[locale] ?? locale.split("-")[0];
}

function xaiLanguage(locale: string): string {
  if (locale === "es-ES" || locale === "pt-PT") return locale;
  return iso2(locale);
}

/** Locale de Apple. No hay es-PE ni es-AR: se usa es-MX (el español latinoamericano que ofrece). */
export function appleLocale(locale: string): string {
  const map: Record<string, string> = {
    "es-PE": "es-MX", "es-AR": "es-MX", "es-419": "es-MX", "es-ES": "es-ES", "en-US": "en-US", "en-GB": "en-GB",
    "pt-BR": "pt-BR", "pt-PT": "pt-PT", "fr-FR": "fr-FR", "de-DE": "de-DE", "it-IT": "it-IT", "nl-NL": "nl-NL",
    "pl-PL": "pl-PL", "ja-JP": "ja-JP", "zh-Hans": "zh-CN",
  };
  return map[locale] ?? locale;
}

/** Idiomas de `SpeechTranscriber.supportedLocales` en macOS 27.0.1 (medido el 2026-10-07): sin nl ni pl. */
export const APPLE_SPEECH_UNSUPPORTED = new Set(["nl", "pl"]);

// ---------- utilidades ----------

const SLEEP = (ms: number) => new Promise((r) => setTimeout(r, ms));

function audioBytes(file: string): Uint8Array {
  return readFileSync(file) as unknown as Uint8Array;
}

function m4aBlob(file: string): Blob {
  return new Blob([audioBytes(file)], { type: "audio/m4a" });
}

function base64(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

function minutes(c: Clip): number {
  return c.seconds / 60;
}

async function timed(fn: () => Promise<Response>): Promise<{ res: Response | null; ms: number; error?: string }> {
  const t0 = performance.now();
  try {
    const res = await fn();
    return { res, ms: Math.round(performance.now() - t0) };
  } catch (e) {
    return { res: null, ms: Math.round(performance.now() - t0), error: String(e).slice(0, 200) };
  }
}

/** Reintenta transporte (red, 429, 5xx) hasta 4 veces; la latencia es la del intento que contestó. */
async function withRetries(fn: () => Promise<SttResult>): Promise<SttResult> {
  let last: SttResult = { status: 0, text: "", ms: 0, cost: null, error: "sin intentos" };
  for (let a = 0; a < 4; a++) {
    last = await fn();
    if (last.status !== 0 && last.status !== 429 && last.status < 500) return last;
    await SLEEP(2000 * 2 ** a);
  }
  return last;
}

// ---------- OpenAI REST ----------

async function openaiRest(v: Variant, c: Clip, ctx: Context): Promise<SttResult> {
  return withRetries(async () => {
    const form = new FormData();
    form.append("model", v.model);
    if (v.model === "whisper-1") {
      if (v.hints !== "auto") form.append("language", iso2(c.locale));
    } else {
      if (v.hints !== "auto") form.append("languages[]", iso2(c.locale));
      if (v.hints === "lang+kw") for (const k of ctx.keywords) form.append("keywords[]", k);
      if (v.prompt) form.append("prompt", v.prompt);
    }
    form.append("file", m4aBlob(c.file), "audio.m4a");
    const { res, ms, error } = await timed(() =>
      fetch("https://api.openai.com/v1/audio/transcriptions", {
        method: "POST",
        headers: { Authorization: `Bearer ${ctx.keys[v.key]}` },
        body: form,
        signal: AbortSignal.timeout(60_000),
      }),
    );
    if (!res) return { status: 0, text: "", ms, cost: null, error };
    const body = await res.text();
    if (!res.ok) return { status: res.status, text: "", ms, cost: null, error: body.slice(0, 300) };
    const json = JSON.parse(body) as { text?: string; usage?: unknown };
    return { status: 200, text: json.text ?? "", ms, cost: (v.perMinute ?? 0) * minutes(c), usage: json.usage };
  });
}

// ---------- OpenAI Realtime (gpt-live-transcribe) ----------

interface WsLike {
  send(data: string): void;
  close(): void;
  onopen: ((ev: unknown) => void) | null;
  onmessage: ((ev: { data: unknown }) => void) | null;
  onerror: ((ev: unknown) => void) | null;
  onclose: ((ev: { code?: number; reason?: string }) => void) | null;
}

export function pcm16(file: string, rate: number): Uint8Array {
  const p = spawnSync("ffmpeg", ["-loglevel", "error", "-i", file, "-f", "s16le", "-ac", "1", "-ar", String(rate), "-"], { maxBuffer: 64 * 1024 * 1024 });
  if (p.status !== 0) throw new Error(`ffmpeg: ${p.stderr.toString().slice(0, 200)}`);
  return p.stdout;
}

async function openaiLive(v: Variant, c: Clip, ctx: Context): Promise<SttResult> {
  const pcm = pcm16(c.file, 24_000);
  const WS = (globalThis as unknown as { WebSocket: new (url: string, protocols?: string[]) => WsLike }).WebSocket;
  const attempt = () =>
    new Promise<SttResult>((resolve) => {
      const t0 = performance.now();
      let tCommit = 0;
      let done = false;
      const finish = (r: SttResult) => {
        if (done) return;
        done = true;
        clearTimeout(timer);
        try {
          ws.close();
        } catch {
          /* ya cerrado */
        }
        resolve(r);
      };
      const timer = setTimeout(() => finish({ status: 0, text: "", ms: Math.round(performance.now() - t0), cost: null, error: "timeout 60 s" }), 60_000);
      const ws = new WS("wss://api.openai.com/v1/realtime?intent=transcription", ["realtime", `openai-insecure-api-key.${ctx.keys[v.key]}`]);
      ws.onerror = (e) => finish({ status: 0, text: "", ms: Math.round(performance.now() - t0), cost: null, error: `ws: ${String((e as { message?: string })?.message ?? e)}` });
      ws.onclose = (e) => finish({ status: 0, text: "", ms: Math.round(performance.now() - t0), cost: null, error: `ws cerrado ${e?.code ?? ""} ${e?.reason ?? ""}` });
      ws.onopen = () => {
        const transcription: Record<string, unknown> = { model: v.model };
        if (v.hints !== "auto") transcription.languages = [iso2(c.locale)];
        if (v.hints === "lang+kw") transcription.keywords = ctx.keywords;
        ws.send(JSON.stringify({
          type: "session.update",
          session: { type: "transcription", audio: { input: { format: { type: "audio/pcm", rate: 24_000 }, transcription, turn_detection: null } } },
        }));
        const chunk = 4800; // 100 ms
        for (let i = 0; i < pcm.length; i += chunk) ws.send(JSON.stringify({ type: "input_audio_buffer.append", audio: base64(pcm.subarray(i, i + chunk)) }));
        ws.send(JSON.stringify({ type: "input_audio_buffer.commit" }));
        tCommit = performance.now();
      };
      ws.onmessage = (ev) => {
        let msg: { type?: string; transcript?: string; error?: { message?: string; code?: string } };
        try {
          msg = JSON.parse(String(ev.data));
        } catch {
          return;
        }
        if (msg.type === "conversation.item.input_audio_transcription.completed") {
          const now = performance.now();
          finish({
            status: 200,
            text: msg.transcript ?? "",
            ms: Math.round(now - t0),
            msAfterSpeech: Math.round(now - tCommit),
            cost: (v.perMinute ?? 0) * minutes(c),
          });
        } else if (msg.type === "error" || msg.type === "conversation.item.input_audio_transcription.failed") {
          finish({ status: 400, text: "", ms: Math.round(performance.now() - t0), cost: null, error: JSON.stringify(msg.error ?? msg).slice(0, 300) });
        }
      };
    });
  let r = await attempt();
  for (let a = 1; a < 3 && r.status === 0; a++) {
    await SLEEP(3000 * a);
    r = await attempt();
  }
  return r;
}

// ---------- xAI ----------

async function xai(v: Variant, c: Clip, ctx: Context): Promise<SttResult> {
  return withRetries(async () => {
    const form = new FormData();
    form.append("model", v.model);
    if (v.hints !== "auto") {
      form.append("language", xaiLanguage(c.locale));
      form.append("format", "true");
    }
    if (v.hints === "lang+kw") for (const k of ctx.keywords.slice(0, 100)) form.append("keyterm", k.slice(0, 50));
    if (v.xaiVad !== undefined) form.append("vad_threshold", String(v.xaiVad));
    form.append("file", m4aBlob(c.file), "audio.m4a"); // tiene que ir el último
    const { res, ms, error } = await timed(() =>
      fetch("https://api.x.ai/v1/stt", { method: "POST", headers: { Authorization: `Bearer ${ctx.keys[v.key]}` }, body: form, signal: AbortSignal.timeout(60_000) }),
    );
    if (!res) return { status: 0, text: "", ms, cost: null, error };
    const body = await res.text();
    if (!res.ok) return { status: res.status, text: "", ms, cost: null, error: body.slice(0, 300) };
    const json = JSON.parse(body) as { text?: string; duration?: number; language?: string };
    return { status: 200, text: json.text ?? "", ms, cost: (v.perMinute ?? 0) * minutes(c), usage: { duration: json.duration, language: json.language } };
  });
}

// ---------- Gemini ----------

export function geminiPrompt(ctx: Context, hints: Hints): string {
  const lang = hints === "auto" ? "" : ` The speaker is speaking ${ctx.localeName}.`;
  const kw = hints === "lang+kw" ? ` It may contain amounts, dates and names such as: ${ctx.keywords.join(", ")}.` : "";
  return (
    `Transcribe this voice note verbatim, in the language it is spoken.${lang} It was dictated to a personal finance app.${kw} ` +
    "Write numbers and amounts with digits. Output only the transcript, without quotes, labels or comments. If there is no speech, output nothing."
  );
}

async function gemini(v: Variant, c: Clip, ctx: Context): Promise<SttResult> {
  return withRetries(async () => {
    const body = {
      contents: [{ role: "user", parts: [{ text: geminiPrompt(ctx, v.hints) }, { inlineData: { mimeType: "audio/mp4", data: base64(audioBytes(c.file)) } }] }],
      generationConfig: { temperature: 0, thinkingConfig: { thinkingLevel: v.thinking ?? "minimal" } },
    };
    const { res, ms, error } = await timed(() =>
      fetch(`https://generativelanguage.googleapis.com/v1beta/models/${v.model}:generateContent`, {
        method: "POST",
        headers: { "x-goog-api-key": ctx.keys[v.key] ?? "", "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(60_000),
      }),
    );
    if (!res) return { status: 0, text: "", ms, cost: null, error };
    const raw = await res.text();
    if (!res.ok) return { status: res.status, text: "", ms, cost: null, error: raw.slice(0, 300) };
    const json = JSON.parse(raw) as {
      candidates?: { content?: { parts?: { text?: string; thought?: boolean }[] } }[];
      usageMetadata?: { promptTokenCount?: number; candidatesTokenCount?: number; thoughtsTokenCount?: number };
    };
    const text = (json.candidates?.[0]?.content?.parts ?? []).filter((p) => !p.thought).map((p) => p.text ?? "").join("").trim();
    const u = json.usageMetadata ?? {};
    const price = v.tokenPrice ?? { input: 0, output: 0 };
    const cost = ((u.promptTokenCount ?? 0) * price.input + ((u.candidatesTokenCount ?? 0) + (u.thoughtsTokenCount ?? 0)) * price.output) / 1e6;
    return { status: 200, text, ms, cost, usage: u };
  });
}

// ---------- Deepgram / AssemblyAI / ElevenLabs (solo con clave) ----------

async function deepgram(v: Variant, c: Clip, ctx: Context): Promise<SttResult> {
  return withRetries(async () => {
    const q = new URLSearchParams({ model: v.model, smart_format: "true", punctuate: "true" });
    if (v.hints !== "auto") q.set("language", c.locale === "zh-Hans" ? "zh-CN" : c.locale === "es-PE" || c.locale === "es-AR" ? "es-419" : c.locale);
    else q.set("detect_language", "true");
    if (v.hints === "lang+kw") for (const k of ctx.keywords) q.append("keyterm", k);
    const { res, ms, error } = await timed(() =>
      fetch(`https://api.deepgram.com/v1/listen?${q}`, {
        method: "POST",
        headers: { Authorization: `Token ${ctx.keys[v.key]}`, "Content-Type": "audio/mp4" },
        body: audioBytes(c.file),
        signal: AbortSignal.timeout(60_000),
      }),
    );
    if (!res) return { status: 0, text: "", ms, cost: null, error };
    const raw = await res.text();
    if (!res.ok) return { status: res.status, text: "", ms, cost: null, error: raw.slice(0, 300) };
    const json = JSON.parse(raw) as { results?: { channels?: { alternatives?: { transcript?: string }[] }[] } };
    return { status: 200, text: json.results?.channels?.[0]?.alternatives?.[0]?.transcript ?? "", ms, cost: v.perMinute === null ? null : v.perMinute * minutes(c) };
  });
}

async function assemblyai(v: Variant, c: Clip, ctx: Context): Promise<SttResult> {
  return withRetries(async () => {
    const auth = { authorization: ctx.keys[v.key] ?? "" };
    const t0 = performance.now();
    try {
      const up = await fetch("https://api.assemblyai.com/v2/upload", { method: "POST", headers: auth, body: audioBytes(c.file), signal: AbortSignal.timeout(60_000) });
      if (!up.ok) return { status: up.status, text: "", ms: Math.round(performance.now() - t0), cost: null, error: (await up.text()).slice(0, 300) };
      const { upload_url } = (await up.json()) as { upload_url: string };
      const body: Record<string, unknown> = { audio_url: upload_url, speech_models: [v.model] };
      if (v.hints !== "auto") body.language_code = iso2(c.locale);
      if (v.hints === "lang+kw") body.keyterms_prompt = ctx.keywords;
      const sub = await fetch("https://api.assemblyai.com/v2/transcript", { method: "POST", headers: { ...auth, "content-type": "application/json" }, body: JSON.stringify(body) });
      if (!sub.ok) return { status: sub.status, text: "", ms: Math.round(performance.now() - t0), cost: null, error: (await sub.text()).slice(0, 300) };
      const { id } = (await sub.json()) as { id: string };
      for (;;) {
        await SLEEP(400);
        const g = await fetch(`https://api.assemblyai.com/v2/transcript/${id}`, { headers: auth });
        const j = (await g.json()) as { status?: string; text?: string; error?: string };
        if (j.status === "completed") return { status: 200, text: j.text ?? "", ms: Math.round(performance.now() - t0), cost: v.perMinute === null ? null : v.perMinute * minutes(c) };
        if (j.status === "error") return { status: 400, text: "", ms: Math.round(performance.now() - t0), cost: null, error: (j.error ?? "error").slice(0, 300) };
        if (performance.now() - t0 > 60_000) return { status: 0, text: "", ms: Math.round(performance.now() - t0), cost: null, error: "timeout 60 s" };
      }
    } catch (e) {
      return { status: 0, text: "", ms: Math.round(performance.now() - t0), cost: null, error: String(e).slice(0, 200) };
    }
  });
}

async function elevenlabs(v: Variant, c: Clip, ctx: Context): Promise<SttResult> {
  return withRetries(async () => {
    const form = new FormData();
    form.append("model_id", v.model);
    if (v.hints !== "auto") form.append("language_code", iso2(c.locale));
    if (v.hints === "lang+kw") for (const k of ctx.keywords) form.append("keyterms", k);
    form.append("file", m4aBlob(c.file), "audio.m4a");
    const { res, ms, error } = await timed(() =>
      fetch("https://api.elevenlabs.io/v1/speech-to-text", { method: "POST", headers: { "xi-api-key": ctx.keys[v.key] ?? "" }, body: form, signal: AbortSignal.timeout(60_000) }),
    );
    if (!res) return { status: 0, text: "", ms, cost: null, error };
    const raw = await res.text();
    if (!res.ok) return { status: res.status, text: "", ms, cost: null, error: raw.slice(0, 300) };
    const json = JSON.parse(raw) as { text?: string };
    // Recargo de keyterms: +0,05 USD/h (elevenlabs.io/pricing/api, 2026-10-07).
    const surcharge = v.hints === "lang+kw" ? 0.05 / 60 : 0;
    return { status: 200, text: json.text ?? "", ms, cost: v.perMinute === null ? null : (v.perMinute + surcharge) * minutes(c) };
  });
}

export async function transcribe(v: Variant, c: Clip, ctx: Context): Promise<SttResult> {
  switch (v.provider) {
    case "openai":
      return openaiRest(v, c, ctx);
    case "openai-live":
      return openaiLive(v, c, ctx);
    case "xai":
      return xai(v, c, ctx);
    case "gemini":
      return gemini(v, c, ctx);
    case "deepgram":
      return deepgram(v, c, ctx);
    case "assemblyai":
      return assemblyai(v, c, ctx);
    case "elevenlabs":
      return elevenlabs(v, c, ctx);
    case "apple":
      throw new Error("apple va por lotes: appleBatch()");
  }
}

// ---------- Apple (por lotes: el modelo se carga una vez por idioma) ----------

export interface AppleLine {
  file: string;
  text: string;
  ms: number;
  error?: string | null;
}

export function appleBatch(bin: string, module: "speech" | "dictation", locale: string, keywordsFile: string | null, files: string[]): AppleLine[] {
  const args = ["--module", module, "--locale", locale, ...(keywordsFile ? ["--keywords-file", keywordsFile] : []), ...files];
  const p = spawnSync(bin, args, { maxBuffer: 64 * 1024 * 1024, timeout: 30 * 60_000 });
  const out = p.stdout.toString("utf8");
  const lines: AppleLine[] = [];
  for (const l of out.split("\n").filter(Boolean)) {
    try {
      lines.push(JSON.parse(l) as AppleLine);
    } catch {
      /* línea rota: se ignora */
    }
  }
  if (p.status !== 0 && !lines.length) throw new Error(`apple-transcribe: ${p.stderr.toString().slice(0, 300)}`);
  return lines;
}
