/**
 * Banco de VOZ de Yala: qué motor de transcripción entiende mejor las notas que dicta la gente, en los 10 idiomas.
 *
 *   python3 -I bench/voice/corpus.py all              # una vez: audio sintético, ruido y habla real (ver corpus.py)
 *   cd gateway && npm run bench:voice                  # criba: todos los motores con clave, todos los clips
 *   npm run bench:voice -- --only openai:gpt-transcribe+kw,xai --kinds clean,snr5
 *   npm run bench:voice -- --latency --only openai:whisper-1,openai:gpt-transcribe+kw   # latencia, en serie
 *   npm run bench:voice -- --report                    # solo rehace voice.md desde los .jsonl
 *
 * Qué mide, por clip: el texto transcrito (WER/CER, importes, comercio) y, en las notas sintéticas, el resultado
 * final de la nota ya interpretada: la transcripción pasa por la lectura de la app (`voice/parse.ts`, el prompt
 * leído del Swift, gpt-4.1-mini, temperatura 0.1) y se compara con los movimientos esperados.
 *
 * Resultados en `bench/results/<fecha>/voice.jsonl` (una línea por transcripción), `voice.parse.jsonl` (una por
 * lectura de nota, cacheada por transcripción) y `voice.md`. Reanudable: lo ya medido no se repite.
 *
 * Presupuesto: `--openai-cap` (USD, por defecto 1.85) corta toda llamada a OpenAI —transcripción y lectura— al
 * llegar; la cuenta se hace con los precios de este fichero y la duración de cada clip.
 *
 * Latencia: se mide en una pasada aparte, en serie, con el candado `bench/.latency-lock` (lo comparten los bancos
 * que corran a la vez: mientras exista uno que no es tuyo, no se lanza nada de red).
 */
import { appendFileSync, existsSync, mkdirSync, readFileSync, rmdirSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { APPLE_SPEECH_UNSUPPORTED, appleBatch, appleLocale, type Clip, type Context, type Kind, type SttResult, type Variant, iso2, transcribe } from "./engines";
import { amountPresent, errorRate, isCJK, merchantPresent } from "./metrics";
import { gradeNote, type ExpectedTx, PARSER_MODEL, PARSER_PRICE, parserBody, parserSystemPrompt, seedSubcategories } from "./parse";

const BENCH = new URL("../", import.meta.url);
const CASES = new URL("cases/voice/", BENCH);
const CACHE = new URL(".cache/voice/", BENCH);
const LOCK = new URL(".latency-lock", BENCH).pathname;

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}
const flag = (name: string) => process.argv.includes(`--${name}`);
const date = arg("date") ?? new Date().toISOString().slice(0, 10);
const RESULTS = new URL(`results/${date}/`, BENCH);
const OUT = new URL("voice.jsonl", RESULTS);
const OUT_PARSE = new URL("voice.parse.jsonl", RESULTS);
const OUT_PARSE_LAT = new URL("voice.parse-latency.jsonl", RESULTS);
const OPENAI_CAP = Number(arg("openai-cap") ?? 1.85);
/** TTS de OpenAI del corpus (6 clips de es-PE, gpt-4o-mini-tts) y pruebas de humo a mano: estimación por arriba. */
const OPENAI_TTS_SPENT = 0.02;

export const CHECKED = "2026-10-07";

// ---------- motores ----------

const isSay = (c: Clip) => c.kind === "clean" && c.tts === "say";
/**
 * `gpt-transcribe` deja muchos importes en letra, y la lectura de la app no entiende los decimales coloquiales en
 * letra («cincuenta y seis veinte» = 56,20). Prueba: un `prompt` fijo que pide cifras, en las notas con esos importes.
 */
const PROMPT_DIGITS = "Personal finance voice note. Write every amount with digits, for example 12.50, 56.20 or 1,250.";
const DECIMAL_NOTES = new Set(["es-PE-01", "es-PE-05", "es-ES-01", "es-ES-02", "es-ES-05", "en-US-01", "en-US-03", "en-GB-01", "en-GB-02", "en-GB-05", "pt-BR-01", "pt-PT-01", "pt-PT-02", "fr-FR-01", "fr-FR-02", "fr-FR-05", "de-DE-01", "de-DE-05", "it-IT-01", "it-IT-02", "nl-NL-01", "pl-PL-02"]);
/** Subconjunto para las variantes de control (sin keywords): limpio `say`, ruido 5 dB y habla real. */
const isSubset = (c: Clip) => isSay(c) || c.kind === "snr5" || c.kind === "real";

/**
 * Variantes del banco. Precios del 2026-10-07: OpenAI developers.openai.com/api/docs/pricing; xAI
 * docs.x.ai/developers/pricing (STT REST 0,10 USD/h); Gemini ai.google.dev/gemini-api/docs/pricing (nivel de
 * pago; 3.8 Flash dobla precio el 2027-01-01). Deepgram deepgram.com/pricing, AssemblyAI assemblyai.com/pricing, ElevenLabs elevenlabs.io/pricing/api.
 */
export const VARIANTS: Variant[] = [
  { id: "openai:whisper-1", provider: "openai", key: "openai", model: "whisper-1", hints: "lang", perMinute: 0.006, shutdown: "2027-02-26", note: "lo que manda la app hoy" },
  { id: "openai:gpt-transcribe", provider: "openai", key: "openai", model: "gpt-transcribe", hints: "lang", perMinute: 0.0045, shutdown: null, only: isSubset, note: "control sin keywords: limpio `say`, 5 dB y habla real" },
  { id: "openai:gpt-transcribe+kw", provider: "openai", key: "openai", model: "gpt-transcribe", hints: "lang+kw", perMinute: 0.0045, shutdown: null },
  {
    id: "openai:gpt-transcribe+kw+prompt", provider: "openai", key: "openai", model: "gpt-transcribe", hints: "lang+kw", perMinute: 0.0045, shutdown: null,
    prompt: PROMPT_DIGITS, only: (c) => c.kind !== "real" && c.tts !== "openai" && DECIMAL_NOTES.has(c.note ?? ""),
    note: "con `prompt` que pide cifras; solo las notas con importes con decimales dichos en letra (limpio y ruido)",
  },
  { id: "openai:gpt-transcribe:auto", provider: "openai", key: "openai", model: "gpt-transcribe", hints: "auto", perMinute: 0.0045, shutdown: null, only: isSay, note: "sin `languages`: solo los clips limpios de `say`" },
  {
    id: "openai:gpt-live-transcribe+kw", provider: "openai-live", key: "openai", model: "gpt-live-transcribe", hints: "lang+kw", perMinute: 0.017, shutdown: null,
    only: (c) => isSay(c) || c.kind === "snr5" || (c.kind === "real" && c.locale === "es-PE"),
    note: "streaming (Realtime); por coste, solo limpio `say`, ruido 5 dB y el habla peruana real",
  },
  { id: "xai:grok-voice-transcribe-2.0", provider: "xai", key: "xai", model: "grok-voice-transcribe-2.0", hints: "lang", perMinute: 0.1 / 60, shutdown: null, only: isSubset, note: "control sin keyterms: limpio `say`, 5 dB y habla real" },
  { id: "xai:grok-voice-transcribe-2.0+kw", provider: "xai", key: "xai", model: "grok-voice-transcribe-2.0", hints: "lang+kw", perMinute: 0.1 / 60, shutdown: null },
  {
    id: "xai:grok-voice-transcribe-2.0+kw:vad0.1", provider: "xai", key: "xai", model: "grok-voice-transcribe-2.0", hints: "lang+kw", perMinute: 0.1 / 60, shutdown: null, xaiVad: 0.1,
    only: (c) => c.kind === "real" || c.kind === "snr5", note: "`vad_threshold=0.1`: con el 0.5 por defecto, 3 de 5 clips de FLEURS en inglés (audio muy bajo) volvían vacíos",
  },
  { id: "gemini:gemini-3.5-flash-lite+kw", provider: "gemini", key: "gemini", model: "gemini-3.5-flash-lite", hints: "lang+kw", perMinute: null, tokenPrice: { input: 0.3, output: 2.5 }, shutdown: null },
  { id: "gemini:gemini-3.8-flash+kw", provider: "gemini", key: "gemini", model: "gemini-3.8-flash", hints: "lang+kw", perMinute: null, tokenPrice: { input: 0.75, output: 3.75 }, thinking: "low", shutdown: null, note: "razonamiento `low` (no admite `minimal`); precio ×2 desde el 2027-01-01" },
  { id: "apple:speech+kw", provider: "apple", key: "", model: "SpeechTranscriber", hints: "lang+kw", perMinute: 0, shutdown: null, appleModule: "speech", only: (c) => !APPLE_SPEECH_UNSUPPORTED.has(iso2(c.locale)), note: "en el dispositivo; sin nl ni pl" },
  { id: "apple:dictation+kw", provider: "apple", key: "", model: "DictationTranscriber", hints: "lang+kw", perMinute: 0, shutdown: null, appleModule: "dictation", note: "en el dispositivo" },
  { id: "deepgram:nova-3+kw", provider: "deepgram", key: "deepgram", model: "nova-3", hints: "lang+kw", perMinute: 0.0052 + 0.0013, shutdown: null, note: "multilingüe 0,0052 + keyterm 0,0013 USD/min; crédito de prueba de 200 USD" },
  { id: "assemblyai:universal-3-5-pro+kw", provider: "assemblyai", key: "assemblyai", model: "universal-3-5-pro", hints: "lang+kw", perMinute: (0.21 + 0.05) / 60, shutdown: null, note: "0,21 + keyterms 0,05 USD/h; crédito de prueba de 50 USD" },
  { id: "elevenlabs:scribe_v2+kw", provider: "elevenlabs", key: "elevenlabs", model: "scribe_v2", hints: "lang+kw", perMinute: 0.22 / 60, shutdown: null, note: "0,22 + keyterms 0,05 USD/h (el recargo lo suma engines.ts); plan Starter con 27 h incluidas" },
];

const isOpenAI = (v: Variant) => v.provider === "openai" || v.provider === "openai-live";

// ---------- claves ----------

function readKey(name: string): string | undefined {
  const p = `${homedir()}/Secrets/yala-ai-bench/${name}.key`;
  return existsSync(p) ? readFileSync(p, "utf8").trim() : undefined;
}
const KEYS: Record<string, string | undefined> = Object.fromEntries(
  ["openai", "xai", "gemini", "deepgram", "assemblyai", "elevenlabs"].map((k) => [k, readKey(k)]),
);
const hasKey = (v: Variant) => v.provider === "apple" || !!KEYS[v.key];

// ---------- casos ----------

interface LocaleCfg {
  lang: string;
  lproj: string[];
  currency: string;
  name: string;
  merchants: string[];
}
interface Note {
  id: string;
  locale: string;
  when: string | null;
  tts: string;
  ref: string;
  refAlt?: string[];
  transactions: ExpectedTx[];
}
interface NotesFile {
  today: string;
  locales: Record<string, LocaleCfg>;
  notes: Note[];
}

const NOTES: NotesFile = JSON.parse(readFileSync(new URL("notes.json", CASES), "utf8"));
const TODAY = NOTES.today;
const NOTE_BY_ID = new Map(NOTES.notes.map((n) => [n.id, n]));

/** La configuración de cada locale; el es-419 de FLEURS usa la de es-PE (mismo español latinoamericano). */
function cfg(locale: string): LocaleCfg {
  return NOTES.locales[locale === "es-419" ? "es-PE" : locale];
}

const subsCache = new Map<string, { expense: string[]; income: string[] }>();
function subs(locale: string) {
  if (!subsCache.has(locale)) subsCache.set(locale, seedSubcategories(cfg(locale).lproj));
  return subsCache.get(locale)!;
}

/**
 * Contexto de la persona: sus subcategorías (las semilla de la app en su idioma) y sus comercios frecuentes. Sin
 * < > ni saltos de línea (OpenAI rechaza la petición entera), hasta 50 caracteres (xAI) y 5 palabras (ElevenLabs).
 */
function context(locale: string): Context {
  const s = subs(locale);
  const keywords = [...new Set([...cfg(locale).merchants, ...s.expense, ...s.income])].filter((k) => !/[<>\r\n]/.test(k) && k.length <= 50 && k.split(/\s+/).length <= 5);
  return { keys: KEYS, keywords, localeName: cfg(locale).name };
}

function loadClips(): Clip[] {
  const out: Clip[] = [];
  const clips = JSON.parse(readFileSync(new URL("clips.json", CASES), "utf8")).clips as { clip: string; note: string; locale: string; tts: string; file: string; seconds: number }[];
  const refsOf = (n: Note) => [n.ref, ...(n.refAlt ?? []), n.tts];
  for (const c of clips) {
    const n = NOTE_BY_ID.get(c.note)!;
    out.push({ clip: c.clip, kind: "clean", locale: c.locale, lang: iso2(c.locale), tts: c.tts, note: c.note, file: new URL(c.file, CASES).pathname, seconds: c.seconds, refs: refsOf(n) });
  }
  const byLocale = new Map<string, Note[]>();
  for (const n of NOTES.notes) byLocale.set(n.locale, [...(byLocale.get(n.locale) ?? []), n]);
  const secs = new Map(clips.map((c) => [c.clip, c.seconds]));
  for (const [locale, ns] of byLocale) {
    ns.forEach((n, i) => {
      const tts = i % 2 === 0 ? "say" : "gemini";
      const base = `${n.id}.${tts}`;
      for (const kind of ["snr10", "snr5"] as Kind[]) {
        const file = new URL(`noisy/${base}.${kind}.m4a`, CACHE).pathname;
        if (!existsSync(file)) continue;
        out.push({ clip: `${base}.${kind}`, kind, locale, lang: iso2(locale), tts, note: n.id, file, seconds: (secs.get(base) ?? 0) + 1.2, refs: refsOf(n) });
      }
    });
  }
  const realPath = new URL("real.json", CASES);
  if (existsSync(realPath)) {
    for (const r of JSON.parse(readFileSync(realPath, "utf8")).clips as { clip: string; locale: string; file: string; seconds: number; text: string }[]) {
      const file = new URL(r.file, CACHE).pathname;
      if (!existsSync(file)) continue;
      out.push({ clip: r.clip, kind: "real", locale: r.locale, lang: iso2(r.locale), tts: null, note: null, file, seconds: r.seconds, refs: [r.text] });
    }
  }
  return out;
}

// ---------- filas ----------

interface Row {
  phase: "screen" | "latency";
  clip: string;
  kind: Kind;
  locale: string;
  tts: string | null;
  note: string | null;
  variant: string;
  provider: string;
  model: string;
  rep: number;
  status: number;
  ms: number;
  msAfterSpeech?: number;
  seconds: number;
  text: string;
  cost: number | null;
  error?: string;
  at: string;
}

interface ParseRow {
  key: string;
  locale: string;
  transcript: string;
  status: number;
  ms: number;
  content: string;
  usage: { prompt_tokens?: number; completion_tokens?: number; prompt_tokens_details?: { cached_tokens?: number } } | null;
  cost: number | null;
  error?: string;
  at: string;
}

function readJsonl<T>(u: URL): T[] {
  if (!existsSync(u)) return [];
  return readFileSync(u, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l) as T);
}

const final = (r: { status: number }) => r.status === 200 || (r.status >= 400 && r.status < 500 && r.status !== 429);
const rowKey = (phase: string, clip: string, variant: string, rep: number) => `${phase}|${clip}|${variant}|${rep}`;

/** La última fila de cada clave (una reanudación deja varias; un fallo de transporte viejo no es una medida). */
function latestRows(): Row[] {
  const m = new Map<string, Row>();
  for (const r of readJsonl<Row>(OUT)) m.set(rowKey(r.phase, r.clip, r.variant, r.rep), r);
  return [...m.values()];
}

/** Clave de caché de la lectura: el texto sin mayúsculas, sin puntuación de frase y sin espacios de más. */
export function parseKey(locale: string, text: string): string {
  const t = text
    .normalize("NFKC")
    .toLowerCase()
    .replace(/(?<!\d)[.,]|[.,](?!\d)|[;:!?¡¿。、，！？"“”«»]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return `${locale}|${t}`;
}

// ---------- gasto ----------

function openaiSpent(): number {
  const stt = readJsonl<Row>(OUT).filter((r) => r.provider === "openai" || r.provider === "openai-live").reduce((a, r) => a + (r.cost ?? 0), 0);
  const parse = [...readJsonl<ParseRow>(OUT_PARSE), ...readJsonl<ParseRow>(OUT_PARSE_LAT)].reduce((a, r) => a + (r.cost ?? 0), 0);
  return OPENAI_TTS_SPENT + stt + parse;
}

function spendByProvider(): Record<string, { calls: number; usd: number }> {
  const t: Record<string, { calls: number; usd: number }> = {};
  for (const r of readJsonl<Row>(OUT)) {
    const k = r.provider === "openai-live" ? "openai" : r.provider;
    t[k] = { calls: (t[k]?.calls ?? 0) + 1, usd: (t[k]?.usd ?? 0) + (r.cost ?? 0) };
  }
  const p = [...readJsonl<ParseRow>(OUT_PARSE), ...readJsonl<ParseRow>(OUT_PARSE_LAT)];
  t["openai (lectura de la nota)"] = { calls: p.length, usd: p.reduce((a, r) => a + (r.cost ?? 0), 0) };
  return t;
}

let openaiRunning = 0;
function openaiAllowed(estimate: number): boolean {
  if (openaiRunning + estimate > OPENAI_CAP) return false;
  openaiRunning += estimate;
  return true;
}

// ---------- ejecución ----------

async function pool<T>(items: T[], n: number, fn: (t: T) => Promise<void>): Promise<void> {
  let i = 0;
  await Promise.all(
    Array.from({ length: Math.min(n, items.length) }, async () => {
      while (i < items.length) await fn(items[i++]);
    }),
  );
}

function selectedVariants(): Variant[] {
  const only = arg("only")?.split(",");
  return VARIANTS.filter((v) => !only || only.some((o) => v.id === o || v.provider === o));
}

function rowFrom(phase: Row["phase"], c: Clip, v: Variant, rep: number, r: SttResult): Row {
  return {
    phase, clip: c.clip, kind: c.kind, locale: c.locale, tts: c.tts, note: c.note, variant: v.id, provider: v.provider, model: v.model, rep,
    status: r.status, ms: r.ms, ...(r.msAfterSpeech !== undefined ? { msAfterSpeech: r.msAfterSpeech } : {}), seconds: c.seconds,
    text: r.text, cost: r.cost, ...(r.error ? { error: r.error.slice(0, 300) } : {}), at: new Date().toISOString(),
  };
}

function appleBin(): string {
  const bin = new URL("apple-transcribe", CACHE).pathname;
  if (!existsSync(bin)) {
    mkdirSync(CACHE, { recursive: true });
    execFileSync("swiftc", ["-O", "-parse-as-library", new URL("voice/apple/transcribe.swift", BENCH).pathname, "-o", bin], { stdio: "inherit" });
  }
  return bin;
}

function keywordsFile(locale: string): string {
  const p = new URL(`kw-${locale}.txt`, CACHE).pathname;
  writeFileSync(p, `${context(locale).keywords.join("\n")}\n`);
  return p;
}

async function runStt(phase: Row["phase"], variants: Variant[], clips: Clip[], reps: number, concurrency: number): Promise<void> {
  mkdirSync(RESULTS, { recursive: true });
  const done = new Set(readJsonl<Row>(OUT).filter(final).map((r) => rowKey(r.phase, r.clip, r.variant, r.rep)));
  openaiRunning = openaiSpent();
  for (const v of variants) {
    if (!hasKey(v)) {
      console.log(`· ${v.id}: sin clave, se salta`);
      continue;
    }
    const mine = clips.filter((c) => !v.only || v.only(c));
    const jobs: { c: Clip; rep: number }[] = [];
    for (const c of mine) for (let rep = 0; rep < reps; rep++) if (!done.has(rowKey(phase, c.clip, v.id, rep))) jobs.push({ c, rep });
    if (!jobs.length) continue;
    console.log(`${v.id}: ${jobs.length} transcripciones pendientes (${phase})`);
    if (v.provider === "apple") {
      const bin = appleBin();
      const groups = new Map<string, { c: Clip; rep: number }[]>();
      for (const j of jobs) {
        const k = `${appleLocale(j.c.locale)}|${j.c.locale}`;
        groups.set(k, [...(groups.get(k) ?? []), j]);
      }
      for (const [k, js] of groups) {
        const [aloc, locale] = k.split("|");
        const kw = v.hints === "lang+kw" ? keywordsFile(locale === "es-419" ? "es-PE" : locale) : null;
        const lines = appleBatch(bin, v.appleModule!, aloc, kw, js.map((j) => j.c.file));
        const byFile = new Map(lines.map((l) => [l.file, l]));
        for (const j of js) {
          const l = byFile.get(j.c.file);
          const r: SttResult = l
            ? { status: l.error ? 500 : 200, text: l.text, ms: l.ms, cost: 0, ...(l.error ? { error: l.error } : {}) }
            : { status: 500, text: "", ms: 0, cost: 0, error: "sin línea de salida" };
          appendFileSync(OUT, `${JSON.stringify(rowFrom(phase, j.c, v, j.rep, r))}\n`);
        }
        console.log(`  apple ${v.appleModule} ${aloc} (${locale}): ${js.length}`);
      }
      continue;
    }
    let n = 0;
    await pool(jobs, v.provider === "openai-live" ? Math.min(concurrency, 3) : concurrency, async ({ c, rep }) => {
      if (isOpenAI(v) && !openaiAllowed((v.perMinute ?? 0) * (c.seconds / 60))) {
        console.log(`  presupuesto de OpenAI (${OPENAI_CAP} USD) alcanzado: ${v.id} ${c.clip} no se manda`);
        return;
      }
      await waitForeignLock();
      const r = await transcribe(v, c, context(c.locale));
      appendFileSync(OUT, `${JSON.stringify(rowFrom(phase, c, v, rep, r))}\n`);
      n++;
      if (n % 50 === 0 || r.status !== 200) console.log(`  ${n}/${jobs.length} ${v.id} ${c.clip} → ${r.status}${r.error ? ` ${r.error.slice(0, 140)}` : ""}`);
    });
  }
}

const promptCache = new Map<string, string>();
function systemPrompt(locale: string): string {
  if (!promptCache.has(locale)) promptCache.set(locale, parserSystemPrompt(TODAY, subs(locale)));
  return promptCache.get(locale)!;
}

/** Una lectura de la nota, con reintentos de transporte; la latencia es la del intento que contestó. */
async function parseOnce(key: string, locale: string, text: string): Promise<ParseRow> {
  const body = parserBody(systemPrompt(locale), text);
  let row: ParseRow = { key, locale, transcript: text, status: 0, ms: 0, content: "", usage: null, cost: null, error: "sin intentos", at: new Date().toISOString() };
  for (let a = 0; a < 4; a++) {
    const t0 = performance.now();
    try {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { Authorization: `Bearer ${KEYS.openai}`, "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(60_000),
      });
      const raw = await res.text();
      const ms = Math.round(performance.now() - t0);
      if (!res.ok) {
        row = { key, locale, transcript: text, status: res.status, ms, content: "", usage: null, cost: null, error: raw.slice(0, 300), at: new Date().toISOString() };
      } else {
        const j = JSON.parse(raw) as { choices?: { message?: { content?: string } }[]; usage?: ParseRow["usage"] };
        const u = j.usage ?? null;
        const cached = u?.prompt_tokens_details?.cached_tokens ?? 0;
        const cost = u ? (((u.prompt_tokens ?? 0) - cached) * PARSER_PRICE.input + cached * PARSER_PRICE.cachedInput + (u.completion_tokens ?? 0) * PARSER_PRICE.output) / 1e6 : null;
        row = { key, locale, transcript: text, status: 200, ms, content: j.choices?.[0]?.message?.content ?? "", usage: u, cost, at: new Date().toISOString() };
      }
    } catch (e) {
      row = { key, locale, transcript: text, status: 0, ms: Math.round(performance.now() - t0), content: "", usage: null, cost: null, error: String(e).slice(0, 200), at: new Date().toISOString() };
    }
    if (final(row)) break;
    await new Promise((r) => setTimeout(r, 2000 * 2 ** a));
  }
  return row;
}

/** Latencia de la lectura de la nota en serie: el texto de referencia de las notas de la pasada de latencia. */
async function runParseLatency(clips: Clip[], reps: number): Promise<void> {
  const done = new Set(readJsonl<ParseRow>(OUT_PARSE_LAT).filter((r) => r.status === 200).map((r) => r.key));
  const notes = [...new Set(clips.map((c) => c.note).filter((n): n is string => !!n))];
  for (const id of notes) {
    const n = NOTE_BY_ID.get(id)!;
    for (let rep = 0; rep < reps; rep++) {
      const key = `${id}|${rep}`;
      if (done.has(key)) continue;
      if (!openaiAllowed(0.0006)) return;
      const row = await parseOnce(key, n.locale, n.ref);
      appendFileSync(OUT_PARSE_LAT, `${JSON.stringify(row)}\n`);
    }
  }
}

async function runParse(concurrency: number): Promise<void> {
  const have = new Map(readJsonl<ParseRow>(OUT_PARSE).filter(final).map((r) => [r.key, r]));
  const todo = new Map<string, { locale: string; text: string }>();
  const onlyVariants = arg("parse-variants")?.split(",");
  for (const r of latestRows()) {
    if (r.kind === "real" || r.status !== 200 || !r.text.trim()) continue;
    if (onlyVariants && !onlyVariants.includes(r.variant)) continue;
    const k = parseKey(r.locale, r.text);
    if (!have.has(k) && !todo.has(k)) todo.set(k, { locale: r.locale, text: r.text });
  }
  if (!todo.size) return;
  console.log(`lectura de la nota: ${todo.size} transcripciones nuevas`);
  openaiRunning = openaiSpent();
  let n = 0;
  await pool([...todo.entries()], concurrency, async ([key, { locale, text }]) => {
    if (!openaiAllowed(0.0006)) {
      console.log(`  presupuesto de OpenAI (${OPENAI_CAP} USD) alcanzado: lectura sin mandar`);
      return;
    }
    await waitForeignLock();
    const row = await parseOnce(key, locale, text);
    openaiRunning += (row.cost ?? 0) - 0.0006;
    appendFileSync(OUT_PARSE, `${JSON.stringify(row)}\n`);
    n++;
    if (n % 100 === 0) console.log(`  lectura ${n}/${todo.size}`);
  });
}

// ---------- candado de latencia ----------

let ownLock = false;

/**
 * Mientras otro banco tenga el candado (está midiendo latencia en serie), aquí no sale nada a la red: se espera
 * antes de cada llamada. Con el candado propio, sí.
 */
async function waitForeignLock(): Promise<void> {
  let told = false;
  // `--no-lock-wait`: solo con el visto bueno de quien coordina los bancos (una tanda pequeña, en serie).
  while (!ownLock && !flag("no-lock-wait") && existsSync(LOCK)) {
    if (!told) console.log(`candado de latencia de otro banco (${LOCK}): espero sin lanzar nada de red`);
    told = true;
    await new Promise((r) => setTimeout(r, 60_000));
  }
}

async function withLatencyLock(fn: () => Promise<void>): Promise<void> {
  for (;;) {
    try {
      mkdirSync(LOCK);
      break;
    } catch {
      console.log(`candado de latencia ocupado (${LOCK}); reintento en 60 s`);
      await new Promise((r) => setTimeout(r, 60_000));
    }
  }
  writeFileSync(`${LOCK}/owner`, `banco de voz ${new Date().toISOString()}\n`);
  ownLock = true;
  try {
    await fn();
  } finally {
    ownLock = false;
    try {
      writeFileSync(`${LOCK}/owner`, "");
      execFileSync("rm", ["-rf", LOCK]);
    } catch {
      rmdirSync(LOCK);
    }
  }
}

/** Para la latencia, dos clips por variante de idioma: la nota 02 limpia (`say`) y la nota 05 con ruido a 5 dB. */
function latencyClips(all: Clip[]): Clip[] {
  return all.filter((c) => (c.kind === "clean" && c.tts === "say" && c.note?.endsWith("-02")) || (c.kind === "snr5" && c.note?.endsWith("-05")));
}

// ---------- informe ----------

interface Scored {
  row: Row;
  err: number;
  amounts: number | null;
  merchants: number | null;
  noteCore: boolean | null;
  noteMerchant: boolean | null;
  noteStrict: boolean | null;
  noteParsed: boolean | null;
}

function score(rows: Row[]): Scored[] {
  const parses = new Map(readJsonl<ParseRow>(OUT_PARSE).filter((r) => r.status === 200).map((r) => [r.key, r]));
  return rows.map((row) => {
    const clipNote = row.note ? NOTE_BY_ID.get(row.note)! : null;
    const refs = clipNote ? [clipNote.ref, ...(clipNote.refAlt ?? []), clipNote.tts] : [];
    const realRef = row.kind === "real" ? [REAL_TEXT.get(row.clip) ?? ""] : refs;
    const lang = iso2(row.locale);
    const ok = row.status === 200;
    const err = ok ? Math.min(1, errorRate(row.text, realRef, lang)) : 1;
    if (!clipNote) return { row, err, amounts: null, merchants: null, noteCore: null, noteMerchant: null, noteStrict: null, noteParsed: null };
    const tx = clipNote.transactions;
    const amounts = ok ? tx.filter((t) => amountPresent(row.text, t.amount, lang, t.spoken)).length / tx.length : 0;
    const withM = tx.filter((t) => t.merchant);
    const merchants = withM.length ? (ok ? withM.filter((t) => merchantPresent(row.text, [t.merchant!, ...(t.merchantAlt ?? [])])).length / withM.length : 0) : null;
    let noteCore: boolean | null = false;
    let noteMerchant: boolean | null = false;
    let noteStrict: boolean | null = false;
    let noteParsed: boolean | null = false;
    if (ok && row.text.trim()) {
      const p = parses.get(parseKey(row.locale, row.text));
      if (!p) {
        noteCore = noteMerchant = noteStrict = noteParsed = null; // sin leer (presupuesto o pendiente)
      } else {
        const g = gradeNote(p.content, tx, TODAY);
        noteCore = g.core;
        noteMerchant = g.withMerchant;
        noteStrict = g.strict;
        noteParsed = g.appParsed;
      }
    }
    return { row, err, amounts, merchants, noteCore, noteMerchant, noteStrict, noteParsed };
  });
}

const REAL_TEXT = new Map<string, string>(
  existsSync(new URL("real.json", CASES)) ? (JSON.parse(readFileSync(new URL("real.json", CASES), "utf8")).clips as { clip: string; text: string }[]).map((c) => [c.clip, c.text]) : [],
);

function mean(xs: (number | null)[]): number | null {
  const v = xs.filter((x): x is number => x !== null);
  return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null;
}
function rate(xs: (boolean | null)[]): number | null {
  const v = xs.filter((x): x is boolean => x !== null);
  return v.length ? v.filter(Boolean).length / v.length : null;
}
function pctl(xs: number[], p: number): number | null {
  if (!xs.length) return null;
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.ceil((p / 100) * s.length) - 1)];
}
const pc = (x: number | null, d = 1) => (x === null ? "—" : `${(x * 100).toFixed(d)} %`);
const sec = (x: number | null) => (x === null ? "—" : (x / 1000).toFixed(1));

const LOCALE_ORDER = ["es-PE", "es-AR", "es-ES", "en-US", "en-GB", "pt-BR", "pt-PT", "fr-FR", "de-DE", "it-IT", "nl-NL", "pl-PL", "ja-JP", "zh-Hans"];
const SYNTH: Kind[] = ["clean", "snr10", "snr5"];

/** Listón (propuesto en docs/ai-voice-bench-2026-10.md). */
export const BAR = {
  maxErrClean: 0.15,
  maxErrCleanCJK: 0.1,
  minAmounts: 0.9,
  p95Ms: 15_000,
  shutdownBefore: "2027-10-07",
};

export function report(): string {
  const rows = latestRows();
  const screen = score(rows.filter((r) => r.phase === "screen"));
  const latency = rows.filter((r) => r.phase === "latency" && r.status === 200);
  const variants = VARIANTS.filter((v) => screen.some((s) => s.row.variant === v.id));
  const base = screen.filter((s) => s.row.variant === "openai:whisper-1");
  const baseCore = new Map(LOCALE_ORDER.map((l) => [l, rate(base.filter((s) => s.row.locale === l && SYNTH.includes(s.row.kind)).map((s) => s.noteCore))]));
  const L: string[] = [];
  L.push(`# voice.transcribe — banco del ${date}`, "", `Precios comprobados el ${CHECKED}. Generado por \`npm run bench:voice -- --report\`.`, "");
  L.push("Error = WER (CER en ja y zh) contra la mejor referencia, tope 100 % por clip. Importes y comercio: en el texto transcrito (el importe vale en cifras o en letra tal como se dijo). Nota: resultado final tras la lectura de la app (núcleo = importe, signo y fecha; con comercio = además el comercio en la nota; estricta = además la divisa). Latencia: pasada en serie (`--latency`); con *, de la criba en paralelo (solo orienta).", "");
  L.push("## Resumen por motor (notas sintéticas: limpio + ruido 10 dB + ruido 5 dB)", "");
  L.push("| Motor | Clips | Error | Error limpio | Error 10 dB | Error 5 dB | Error habla real | Importes | Comercio | Notas leídas | Nota núcleo | Nota + comercio | Nota estricta | JSON de la app | Fallos | p50 / p95 s | USD/hora | Apagado |");
  L.push("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|");
  for (const v of variants) {
    const mine = screen.filter((s) => s.row.variant === v.id);
    const syn = mine.filter((s) => SYNTH.includes(s.row.kind));
    const byKind = (k: Kind) => mean(mine.filter((s) => s.row.kind === k).map((s) => s.err));
    const lat = latency.filter((r) => r.variant === v.id).map((r) => r.ms);
    const latStar = !lat.length;
    const ms = lat.length ? lat : mine.filter((s) => s.row.status === 200).map((s) => s.row.ms);
    const fails = mine.filter((s) => s.row.status !== 200).length;
    // Coste real por hora de audio, de lo gastado (incluye recargos como las keyterms de ElevenLabs).
    const perHour = (() => {
      const ok = mine.filter((s) => s.row.status === 200 && s.row.cost !== null);
      const usd = ok.reduce((a, s) => a + (s.row.cost ?? 0), 0);
      const h = ok.reduce((a, s) => a + s.row.seconds, 0) / 3600;
      return h ? usd / h : null;
    })();
    L.push(
      `| \`${v.id}\` | ${mine.length} | ${pc(mean(syn.map((s) => s.err)))} | ${pc(byKind("clean"))} | ${pc(byKind("snr10"))} | ${pc(byKind("snr5"))} | ${pc(byKind("real"))} | ${pc(mean(syn.map((s) => s.amounts)))} | ${pc(mean(syn.map((s) => s.merchants)))} | ${syn.filter((s) => s.noteCore !== null).length}/${syn.length} | ${pc(rate(syn.map((s) => s.noteCore)))} | ${pc(rate(syn.map((s) => s.noteMerchant)))} | ${pc(rate(syn.map((s) => s.noteStrict)))} | ${pc(rate(syn.map((s) => s.noteParsed)), 0)} | ${fails} | ${sec(pctl(ms, 50))} / ${sec(pctl(ms, 95))}${latStar ? "*" : ""} | ${perHour === null ? "—" : perHour.toFixed(3)} | ${v.shutdown ?? "—"} |`,
    );
  }
  L.push("", "## Nota por condición", "");
  L.push("| Motor | Núcleo limpio | Núcleo 10 dB | Núcleo 5 dB | Con comercio limpio | Con comercio 10 dB | Con comercio 5 dB |", "|---|---|---|---|---|---|---|");
  for (const v of variants) {
    const mine = screen.filter((s) => s.row.variant === v.id);
    const k = (kind: Kind, f: (s: Scored) => boolean | null) => pc(rate(mine.filter((s) => s.row.kind === kind).map(f)));
    L.push(`| \`${v.id}\` | ${k("clean", (s) => s.noteCore)} | ${k("snr10", (s) => s.noteCore)} | ${k("snr5", (s) => s.noteCore)} | ${k("clean", (s) => s.noteMerchant)} | ${k("snr10", (s) => s.noteMerchant)} | ${k("snr5", (s) => s.noteMerchant)} |`);
  }
  L.push("", "## Nota núcleo por variante de idioma (sintéticas, todas las condiciones)", "");
  L.push(`| Motor | ${LOCALE_ORDER.join(" | ")} |`, `|---|${LOCALE_ORDER.map(() => "---").join("|")}|`);
  for (const v of variants) {
    const mine = screen.filter((s) => s.row.variant === v.id && SYNTH.includes(s.row.kind));
    L.push(`| \`${v.id}\` | ${LOCALE_ORDER.map((l) => pc(rate(mine.filter((s) => s.row.locale === l).map((s) => s.noteCore)), 0)).join(" | ")} |`);
  }
  L.push("", "## Nota con comercio por variante de idioma", "");
  L.push(`| Motor | ${LOCALE_ORDER.join(" | ")} |`, `|---|${LOCALE_ORDER.map(() => "---").join("|")}|`);
  for (const v of variants) {
    const mine = screen.filter((s) => s.row.variant === v.id && SYNTH.includes(s.row.kind));
    L.push(`| \`${v.id}\` | ${LOCALE_ORDER.map((l) => pc(rate(mine.filter((s) => s.row.locale === l).map((s) => s.noteMerchant)), 0)).join(" | ")} |`);
  }
  L.push("", "## Nota estricta por variante de idioma (la divisa depende sobre todo del prompt de la app)", "");
  L.push(`| Motor | ${LOCALE_ORDER.join(" | ")} |`, `|---|${LOCALE_ORDER.map(() => "---").join("|")}|`);
  for (const v of variants) {
    const mine = screen.filter((s) => s.row.variant === v.id && SYNTH.includes(s.row.kind));
    L.push(`| \`${v.id}\` | ${LOCALE_ORDER.map((l) => pc(rate(mine.filter((s) => s.row.locale === l).map((s) => s.noteStrict)), 0)).join(" | ")} |`);
  }
  L.push("", "## Error en limpio por variante de idioma (WER; CER en ja y zh)", "");
  L.push(`| Motor | ${LOCALE_ORDER.join(" | ")} |`, `|---|${LOCALE_ORDER.map(() => "---").join("|")}|`);
  for (const v of variants) {
    const mine = screen.filter((s) => s.row.variant === v.id && s.row.kind === "clean");
    L.push(`| \`${v.id}\` | ${LOCALE_ORDER.map((l) => pc(mean(mine.filter((s) => s.row.locale === l).map((s) => s.err)), 0)).join(" | ")} |`);
  }
  L.push("", "## Error con ruido a 5 dB por variante de idioma", "");
  L.push(`| Motor | ${LOCALE_ORDER.join(" | ")} |`, `|---|${LOCALE_ORDER.map(() => "---").join("|")}|`);
  for (const v of variants) {
    const mine = screen.filter((s) => s.row.variant === v.id && s.row.kind === "snr5");
    L.push(`| \`${v.id}\` | ${LOCALE_ORDER.map((l) => pc(mean(mine.filter((s) => s.row.locale === l).map((s) => s.err)), 0)).join(" | ")} |`);
  }
  L.push("", "## Importes en el texto por variante de idioma (sintéticas, todas las condiciones)", "");
  L.push(`| Motor | ${LOCALE_ORDER.join(" | ")} |`, `|---|${LOCALE_ORDER.map(() => "---").join("|")}|`);
  for (const v of variants) {
    const mine = screen.filter((s) => s.row.variant === v.id && SYNTH.includes(s.row.kind));
    L.push(`| \`${v.id}\` | ${LOCALE_ORDER.map((l) => pc(mean(mine.filter((s) => s.row.locale === l).map((s) => s.amounts)), 0)).join(" | ")} |`);
  }
  L.push("", "## Sesgo del TTS: error y nota núcleo en limpio, por motor que generó el audio", "");
  L.push("| Motor | Error `say` (Apple) | Error `gemini` (Google) | Error `openai` (solo es-PE) | Nota `say` | Nota `gemini` | Nota `openai` |", "|---|---|---|---|---|---|---|");
  for (const v of variants) {
    const mine = screen.filter((s) => s.row.variant === v.id && s.row.kind === "clean");
    const t = (k: string) => mine.filter((s) => s.row.tts === k);
    L.push(`| \`${v.id}\` | ${pc(mean(t("say").map((s) => s.err)))} | ${pc(mean(t("gemini").map((s) => s.err)))} | ${pc(mean(t("openai").map((s) => s.err)))} | ${pc(rate(t("say").map((s) => s.noteCore)), 0)} | ${pc(rate(t("gemini").map((s) => s.noteCore)), 0)} | ${pc(rate(t("openai").map((s) => s.noteCore)), 0)} |`);
  }
  const realLocales = ["es-PE", "es-419", "en-US", "pt-BR", "fr-FR", "de-DE", "it-IT", "nl-NL", "pl-PL", "ja-JP", "zh-Hans"];
  L.push("", "## Habla humana real (OpenSLR 73 = es-PE; FLEURS = el resto): error por idioma", "");
  L.push(`| Motor | ${realLocales.join(" | ")} |`, `|---|${realLocales.map(() => "---").join("|")}|`);
  for (const v of variants) {
    const mine = screen.filter((s) => s.row.variant === v.id && s.row.kind === "real");
    if (!mine.length) continue;
    L.push(`| \`${v.id}\` | ${realLocales.map((l) => pc(mean(mine.filter((s) => s.row.locale === l).map((s) => s.err)), 0)).join(" | ")} |`);
  }
  // Listón
  L.push("", "## Listón", "");
  L.push(`Pasa si cumple TODO: (1) error en limpio ≤ ${BAR.maxErrClean * 100} % (CER ≤ ${BAR.maxErrCleanCJK * 100} % en ja/zh) en CADA variante; (2) importes en el texto ≥ ${BAR.minAmounts * 100} % en cada variante; (3) nota núcleo ≥ la de \`whisper-1\` en CADA variante; (4) latencia p95 ≤ ${BAR.p95Ms / 1000} s; (5) sin apagado anunciado antes del ${BAR.shutdownBefore}; (6) cubre las 14 variantes.`, "");
  L.push("| Motor | (1) error | (2) importes | (3) nota ≥ whisper-1 | (4) p95 | (5) apagado | (6) cobertura | Pasa |", "|---|---|---|---|---|---|---|---|");
  for (const v of variants) {
    const mine = screen.filter((s) => s.row.variant === v.id);
    const fails1: string[] = [];
    const fails2: string[] = [];
    const fails3: string[] = [];
    let covered = 0;
    for (const l of LOCALE_ORDER) {
      const clean = mine.filter((s) => s.row.locale === l && s.row.kind === "clean");
      const syn = mine.filter((s) => s.row.locale === l && SYNTH.includes(s.row.kind));
      if (!syn.length) continue;
      covered++;
      const e = mean(clean.map((s) => s.err));
      if (e !== null && e > (isCJK(iso2(l)) ? BAR.maxErrCleanCJK : BAR.maxErrClean)) fails1.push(`${l} ${pc(e, 0)}`);
      const a = mean(syn.map((s) => s.amounts));
      if (a !== null && a < BAR.minAmounts) fails2.push(`${l} ${pc(a, 0)}`);
      const n = rate(syn.map((s) => s.noteCore));
      const b = baseCore.get(l) ?? null;
      if (n !== null && b !== null && n < b) fails3.push(`${l} ${pc(n, 0)}<${pc(b, 0)}`);
    }
    const lat = latency.filter((r) => r.variant === v.id).map((r) => r.ms);
    const p95 = pctl(lat.length ? lat : mine.filter((s) => s.row.status === 200).map((s) => s.row.ms), 95);
    const ok4 = p95 !== null && p95 <= BAR.p95Ms;
    const ok5 = !v.shutdown || v.shutdown > BAR.shutdownBefore;
    const ok6 = covered === LOCALE_ORDER.length;
    const all = !fails1.length && !fails2.length && !fails3.length && ok4 && ok5 && ok6;
    const cell = (f: string[]) => (f.length ? `✗ ${f.join(", ")}` : "✓");
    L.push(`| \`${v.id}\` | ${cell(fails1)} | ${cell(fails2)} | ${cell(fails3)} | ${ok4 ? "✓" : "✗"} ${sec(p95)}${lat.length ? "" : "*"} | ${ok5 ? "✓" : `✗ ${v.shutdown}`} | ${ok6 ? "✓" : `✗ ${covered}/14`} | ${all ? "**sí**" : "no"} |`);
  }
  // Latencia
  if (latency.length) {
    L.push("", "## Latencia en serie (pasada `--latency`: nota 02 limpia y nota 05 a 5 dB de cada variante, 2 repeticiones)", "");
    L.push("| Motor | Llamadas | p50 s | p95 s | máx s | Tras la voz p50 / p95 s (streaming) |", "|---|---|---|---|---|---|");
    for (const v of VARIANTS) {
      const ls = latency.filter((r) => r.variant === v.id);
      if (!ls.length) continue;
      const ms = ls.map((r) => r.ms);
      const after = ls.map((r) => r.msAfterSpeech).filter((x): x is number => typeof x === "number");
      L.push(`| \`${v.id}\` | ${ls.length} | ${sec(pctl(ms, 50))} | ${sec(pctl(ms, 95))} | ${sec(Math.max(...ms))} | ${after.length ? `${sec(pctl(after, 50))} / ${sec(pctl(after, 95))}` : "—"} |`);
    }
  }
  const pl = readJsonl<ParseRow>(OUT_PARSE_LAT).filter((r) => r.status === 200).map((r) => r.ms);
  if (pl.length) {
    L.push("", `**Lectura de la nota (\`${PARSER_MODEL}\`, en serie, ${pl.length} llamadas con el texto de referencia):** p50 ${sec(pctl(pl, 50))} s · p95 ${sec(pctl(pl, 95))} s · máx ${sec(Math.max(...pl))} s. La app la manda DESPUÉS de transcribir, con su propio corte de 20 s.`);
  }
  L.push("", "## Gasto", "");
  for (const [k, s] of Object.entries(spendByProvider())) L.push(`- ${k}: ${s.calls} llamadas, ${s.usd.toFixed(3)} USD`);
  L.push(`- OpenAI total (con el TTS de es-PE, ~${OPENAI_TTS_SPENT} USD): ${openaiSpent().toFixed(3)} USD`);
  const md = `${L.join("\n")}\n`;
  writeFileSync(new URL("voice.md", RESULTS), md);
  return md;
}

// ---------- main ----------

if (flag("spend")) {
  for (const [k, s] of Object.entries(spendByProvider())) console.log(`${k}: ${s.calls} llamadas, ${s.usd.toFixed(3)} USD`);
  console.log(`OpenAI total: ${openaiSpent().toFixed(3)} USD (tope ${OPENAI_CAP})`);
  process.exit(0);
}

if (!flag("report")) {
  const kinds = arg("kinds")?.split(",") as Kind[] | undefined;
  const locales = arg("locales")?.split(",");
  const limit = Number(arg("limit") ?? 0);
  let clips = loadClips().filter((c) => (!kinds || kinds.includes(c.kind)) && (!locales || locales.includes(c.locale)));
  if (limit) clips = clips.slice(0, limit);
  const variants = selectedVariants();
  const concurrency = Number(arg("concurrency") ?? 6);
  if (flag("latency")) {
    const net = variants.filter((v) => v.provider !== "apple");
    if (net.length || flag("parse-latency")) {
      await withLatencyLock(async () => {
        // Con el candado propio, también lo que queda de la criba de lecturas (red, pero de nadie más midiendo).
        if (flag("parse-first")) await runParse(Number(arg("parse-concurrency") ?? 8));
        openaiRunning = openaiSpent();
        await runStt("latency", net, latencyClips(clips), Number(arg("reps") ?? 2), 1);
        if (flag("parse-latency")) await runParseLatency(latencyClips(clips), Number(arg("reps") ?? 2));
      });
    }
    // Apple corre en local: no satura la red, pero también se mide en serie (es lo que tarda en la Mac).
    const apple = variants.filter((v) => v.provider === "apple");
    if (apple.length) await runStt("latency", apple, latencyClips(clips), Number(arg("reps") ?? 2), 1);
  } else {
    await runStt("screen", variants, clips, 1, concurrency);
    if (!flag("no-parse")) await runParse(Number(arg("parse-concurrency") ?? 8));
  }
}
console.log(report());
console.log(`OpenAI gastado: ${openaiSpent().toFixed(3)} USD (tope ${OPENAI_CAP})`);
