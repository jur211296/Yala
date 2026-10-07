/**
 * Sesión 2 del gateway de IA (`ai-every-call-sends-its-task-and-passes-the-bench`):
 *
 * 1. Con `X-Yala-Task`, el cubo de cuota sale de la TAREA, no del cliente.
 * 2. Longitud: tope de cuerpo por tarea y la foto exige imagen, antes de gastar cuota.
 * 3. Cupo de prueba del plan free: 5 notas de voz y 5 fotos EN TOTAL. Una nota (transcribir + leer) gasta 1.
 *    La 5.ª nota completa funciona; la 6.ª se rechaza con `yala_trial_exhausted`. Igual con las fotos.
 *    Vale para las versiones instaladas (sin cabecera) y para las nuevas.
 * 4. Un fallo del proveedor devuelve el uso.
 *
 * El limitador es el de verdad (`applyCheck`/`applyRefund` de rate_limiter.ts) sobre un estado en memoria: lo único
 * fingido es el Durable Object que lo guarda.
 */
import { readFileSync } from "node:fs";
import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";
import app from "../src/index";
import type { Env } from "../src/env";
import { issueSessionToken } from "../src/attest/session";
import { applyCheck, applyRefund, NOTE_CREDIT_MS, type CheckRequest, type RefundRequest } from "../src/rate_limiter";
import { photoReadBody } from "../bench/lib/appRequests";

const NOOP_CTX = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;
const SECRET = "jwt-secret-unit-session2";

type Stored = Parameters<typeof applyCheck>[0];
let stores: Map<string, Stored>;
let checks: CheckRequest[];
let now: number;
let upstreamStatus: number;
let sent: { url: string; json: Record<string, unknown> | null }[];

function makeEnv(enforce = "enforce"): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: enforce,
    JWT_SIGNING_SECRET: SECRET,
    OPENAI_API_KEY: "sk-unit-openai",
    RATE_LIMITER: {
      idFromName: (name: string) => name,
      get: (id: string) => ({
        fetch: async (_url: string, init?: RequestInit) => {
          const req = JSON.parse(String(init?.body ?? "{}")) as CheckRequest | RefundRequest;
          const stored = stores.get(id) ?? { day: new Date(now).toISOString().slice(0, 10), counts: {}, burst: [] };
          stores.set(id, stored);
          if (req.op === "refund") {
            applyRefund(stored, req, now);
            return Response.json({ ok: true });
          }
          checks.push(req);
          // La ráfaga no es lo que se prueba aquí: cada llamada avanza un minuto.
          now += 61_000;
          return Response.json(applyCheck(stored, req, now));
        },
      }),
    },
  } as unknown as Env;
}

const CHAT_OK = {
  id: "x",
  object: "chat.completion",
  created: 1,
  model: "upstream",
  choices: [{ index: 0, message: { role: "assistant", content: "{}" }, finish_reason: "stop" }],
  usage: { prompt_tokens: 1, completion_tokens: 1, total_tokens: 2 },
};

beforeEach(() => {
  stores = new Map();
  checks = [];
  sent = [];
  now = Date.parse("2026-10-07T15:00:00Z");
  upstreamStatus = 200;
  vi.spyOn(console, "log").mockImplementation(() => {});
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown, init?: RequestInit) => {
      const url = typeof input === "string" ? input : (input as Request).url;
      let json: Record<string, unknown> | null = null;
      if (typeof init?.body === "string") json = JSON.parse(init.body);
      else if (init?.body instanceof Uint8Array) {
        try {
          json = JSON.parse(new TextDecoder().decode(init.body));
        } catch {
          json = null;
        }
      }
      sent.push({ url, json });
      if (upstreamStatus !== 200) return new Response(JSON.stringify({ error: { type: "server_error", code: null } }), { status: upstreamStatus, headers: { "content-type": "application/json" } });
      if (url.includes("/audio/transcriptions")) return new Response(JSON.stringify({ text: "taxi doce" }), { status: 200, headers: { "content-type": "application/json" } });
      return new Response(JSON.stringify(CHAT_OK), { status: 200, headers: { "content-type": "application/json" } });
    }),
  );
});

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

async function bearer(tier: "pro" | "free", keyId = "unit-device"): Promise<string> {
  const { token } = await issueSessionToken(makeEnv(), { keyId, tier });
  return `Bearer ${token}`;
}

async function chat(body: unknown, headers: Record<string, string>, tier: "pro" | "free" = "free", env = makeEnv()): Promise<Response> {
  return await app.fetch(
    new Request("https://gw.local/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: await bearer(tier), "Content-Type": "application/json", ...headers },
      body: typeof body === "string" ? body : JSON.stringify(body),
    }),
    env,
    NOOP_CTX,
  );
}

const BOUNDARY = "----yala-unit-s2";
function multipart(model = "whisper-1"): Uint8Array {
  const enc = new TextEncoder();
  return enc.encode(
    `--${BOUNDARY}\r\nContent-Disposition: form-data; name="file"; filename="a.m4a"\r\nContent-Type: audio/m4a\r\n\r\nAUDIO\r\n--${BOUNDARY}\r\nContent-Disposition: form-data; name="model"\r\n\r\n${model}\r\n--${BOUNDARY}--\r\n`,
  );
}

async function transcribe(headers: Record<string, string> = {}, tier: "pro" | "free" = "free", env = makeEnv()): Promise<Response> {
  return await app.fetch(
    new Request("https://gw.local/v1/audio/transcriptions", {
      method: "POST",
      headers: { Authorization: await bearer(tier), "Content-Type": `multipart/form-data; boundary=${BOUNDARY}`, ...headers },
      body: multipart(),
    }),
    env,
    NOOP_CTX,
  );
}

const PARSE = { model: "gpt-4.1-mini", messages: [{ role: "system", content: "parser" }, { role: "user", content: "taxi 12" }], temperature: 0.1, stream: false };
const IMAGE_B64 = Buffer.from(
  readFileSync(new URL("../../Yala/Resources/Assets.xcassets/ExampleImages/example-bank-alert-es.imageset/example-bank-alert-es.png", import.meta.url) as unknown as string),
).toString("base64");
const PHOTO = photoReadBody(IMAGE_B64, "2026-10-07");

/** Una nota como la manda la app: transcribir y leer. Con `withHeaders`, como la app nueva. */
async function note(withHeaders: boolean): Promise<[number, number]> {
  const t = await transcribe(withHeaders ? { "X-Yala-Task": "voice.transcribe", "X-Yala-Category": "voice" } : { "X-Yala-Category": "voice" });
  const p = await chat(PARSE, withHeaders ? { "X-Yala-Task": "text.parse", "X-Yala-Category": "voice" } : { "X-Yala-Category": "voice" });
  return [t.status, p.status];
}

async function errorType(res: Response): Promise<string> {
  return ((await res.json()) as { error: { type: string } }).error.type;
}

describe("1 · con cabecera, el cubo sale de la tarea", () => {
  it("sin X-Yala-Category: text.parse cuenta en voz y chat.answer en chat (Pro)", async () => {
    expect((await chat(PARSE, { "X-Yala-Task": "text.parse" }, "pro")).status).toBe(200);
    expect((await chat({ ...PARSE, messages: [{ role: "user", content: "¿cuánto gasté?" }] }, { "X-Yala-Task": "chat.answer" }, "pro")).status).toBe(200);
    expect(checks.map((c) => c.category)).toEqual(["voice", "chat"]);
  });

  it("free: text.parse sin categoría declarada sigue siendo voz (antes caía en chat → 403)", async () => {
    expect((await chat(PARSE, { "X-Yala-Task": "text.parse" })).status).toBe(200);
    expect(checks.map((c) => c.category)).toEqual(["voice"]);
  });

  it("una categoría declarada que no casa con la tarea → 400, sin gastar ni llamar", async () => {
    const res = await chat(PARSE, { "X-Yala-Task": "text.parse", "X-Yala-Category": "vision" });
    expect(res.status).toBe(400);
    expect(await errorType(res)).toBe("yala_task_mismatch");
    expect(checks).toHaveLength(0);
    expect(sent).toHaveLength(0);
  });

  it("sin cabecera de tarea, el cubo sigue siendo el declarado (versiones instaladas)", async () => {
    await chat(PARSE, { "X-Yala-Category": "voice" }, "pro");
    expect(checks.map((c) => c.category)).toEqual(["voice"]);
  });
});

describe("2 · longitud: tope de cuerpo y foto con imagen, antes de la cuota", () => {
  it("un cuerpo de texto de 1 MB en text.parse → 413 yala_too_large, sin gastar", async () => {
    const big = { ...PARSE, messages: [{ role: "user", content: "x".repeat(1024 * 1024) }] };
    const res = await chat(big, { "X-Yala-Task": "text.parse" }, "pro");
    expect(res.status).toBe(413);
    expect(await errorType(res)).toBe("yala_too_large");
    expect(checks).toHaveLength(0);
    expect(sent).toHaveLength(0);
  });

  it("photo.read sin imagen → 400: el cubo de visión no sirve para chatear gratis", async () => {
    const res = await chat({ ...PHOTO, messages: [{ role: "user", content: "¿cuánto gasté este mes?" }] }, { "X-Yala-Task": "photo.read" });
    expect(res.status).toBe(400);
    expect(checks).toHaveLength(0);
    expect(sent).toHaveLength(0);
  });

  it("la foto real que manda la app pasa", async () => {
    expect((await chat(PHOTO, { "X-Yala-Task": "photo.read" })).status).toBe(200);
  });
});

describe("3 · cupo de prueba free: 5 notas y 5 fotos en total", () => {
  for (const withHeaders of [true, false]) {
    const who = withHeaders ? "app nueva (con cabecera)" : "versión instalada (sin cabecera)";
    it(`${who}: la 5.ª nota completa funciona y la 6.ª se rechaza con yala_trial_exhausted`, async () => {
      for (let i = 1; i <= 5; i++) expect(await note(withHeaders), `nota ${i}`).toEqual([200, 200]);
      const sixth = await transcribe(withHeaders ? { "X-Yala-Task": "voice.transcribe" } : { "X-Yala-Category": "voice" });
      expect(sixth.status).toBe(403);
      expect(await errorType(sixth)).toBe("yala_trial_exhausted");
      expect(sixth.headers.get("X-Yala-Limit")).toBe("trial");
      // Lo rechazado no llegó al proveedor: 5 transcripciones + 5 lecturas.
      expect(sent).toHaveLength(10);
    });
  }

  it("una nota gasta UN uso aunque haga dos llamadas (antes: dos)", async () => {
    await note(true);
    expect(stores.get("unit-device")?.trial?.voice).toBe(1);
  });

  it("el cupo no se repone al día siguiente", async () => {
    for (let i = 0; i < 5; i++) await note(true);
    now += 3 * 86_400_000;
    expect((await transcribe({ "X-Yala-Task": "voice.transcribe" })).status).toBe(403);
  });

  it("leer sin haber transcrito (atajo de texto) gasta su propio uso", async () => {
    await chat(PARSE, { "X-Yala-Task": "text.parse" });
    await chat(PARSE, { "X-Yala-Task": "text.parse" });
    expect(stores.get("unit-device")?.trial?.voice).toBe(2);
  });

  it("una lectura más de 10 min después de transcribir ya no va con la nota: gasta", async () => {
    await transcribe({ "X-Yala-Task": "voice.transcribe" });
    now += NOTE_CREDIT_MS + 1;
    await chat(PARSE, { "X-Yala-Task": "text.parse" });
    expect(stores.get("unit-device")?.trial?.voice).toBe(2);
  });

  it("fotos: la 5.ª funciona y la 6.ª se rechaza con yala_trial_exhausted", async () => {
    for (let i = 1; i <= 5; i++) expect((await chat(PHOTO, { "X-Yala-Task": "photo.read" })).status, `foto ${i}`).toBe(200);
    const sixth = await chat(PHOTO, { "X-Yala-Task": "photo.read" });
    expect(sixth.status).toBe(403);
    expect(await errorType(sixth)).toBe("yala_trial_exhausted");
  });

  it("voz y foto son cupos separados", async () => {
    for (let i = 0; i < 5; i++) await chat(PHOTO, { "X-Yala-Task": "photo.read" });
    expect(await note(true)).toEqual([200, 200]);
  });

  it("Pro no tiene cupo de prueba: la 6.ª nota pasa", async () => {
    for (let i = 0; i < 6; i++) {
      expect((await transcribe({ "X-Yala-Task": "voice.transcribe" }, "pro")).status).toBe(200);
      expect((await chat(PARSE, { "X-Yala-Task": "text.parse" }, "pro")).status).toBe(200);
    }
  });

  it("en observe (staging) el cupo agotado se cuenta pero no bloquea", async () => {
    const env = makeEnv("observe");
    for (let i = 0; i < 5; i++) await transcribe({ "X-Yala-Task": "voice.transcribe" }, "free", env);
    expect((await transcribe({ "X-Yala-Task": "voice.transcribe" }, "free", env)).status).toBe(200);
  });
});

describe("4 · un fallo del proveedor devuelve el uso", () => {
  it("transcripción con 500: la nota no gasta y no queda abierta", async () => {
    upstreamStatus = 500;
    await transcribe({ "X-Yala-Task": "voice.transcribe" });
    expect(stores.get("unit-device")?.trial?.voice).toBe(0);
    expect(stores.get("unit-device")?.notes).toEqual([]);
  });

  it("lectura con 500 tras una transcripción buena: la nota vuelve a quedar abierta y el reintento no gasta", async () => {
    await transcribe({ "X-Yala-Task": "voice.transcribe" });
    upstreamStatus = 500;
    await chat(PARSE, { "X-Yala-Task": "text.parse" });
    upstreamStatus = 200;
    expect((await chat(PARSE, { "X-Yala-Task": "text.parse" })).status).toBe(200);
    expect(stores.get("unit-device")?.trial?.voice).toBe(1);
  });

  it("foto con 429 del proveedor (sin crédito): no gasta", async () => {
    upstreamStatus = 429;
    await chat(PHOTO, { "X-Yala-Task": "photo.read" });
    expect(stores.get("unit-device")?.trial?.vision).toBe(0);
  });

  it("un 400 del proveedor (petición mala) sí gasta", async () => {
    upstreamStatus = 400;
    await chat(PHOTO, { "X-Yala-Task": "photo.read" });
    expect(stores.get("unit-device")?.trial?.vision).toBe(1);
  });
});

describe("limitador (lógica pura)", () => {
  const base = (): Stored => ({ day: "2026-10-07", counts: {}, burst: [] });
  const t0 = Date.parse("2026-10-07T12:00:00Z");

  it("un estado de antes de la sesión 2 (sin trial ni notas) se lee como vacío", () => {
    const s = base();
    expect(applyCheck(s, { category: "voice", trial: 5, burstPerMin: 5 }, t0).allowed).toBe(true);
    expect(s.trial?.voice).toBe(1);
  });

  it("la cuota diaria (Pro, tasas, sync) sigue igual: se repone al cambiar de día", () => {
    const s = base();
    for (let i = 0; i < 3; i++) applyCheck(s, { category: "rates", daily: 3, burstPerMin: 100 }, t0 + i);
    expect(applyCheck(s, { category: "rates", daily: 3, burstPerMin: 100 }, t0 + 10).reason).toBe("daily");
    expect(applyCheck(s, { category: "rates", daily: 3, burstPerMin: 100 }, t0 + 86_400_000).allowed).toBe(true);
  });

  it("leer con nota abierta no mira el cupo pero sí la ráfaga", () => {
    const s = base();
    for (let i = 0; i < 5; i++) applyCheck(s, { category: "voice", trial: 5, burstPerMin: 100, notePairing: "grant" }, t0 + i);
    expect(s.trial?.voice).toBe(5);
    expect(applyCheck(s, { category: "voice", trial: 5, burstPerMin: 100, notePairing: "consume" }, t0 + 10)).toMatchObject({ allowed: true, ticket: { counted: null } });
    const burst = base();
    burst.notes = [t0];
    burst.burst = [t0, t0, t0];
    expect(applyCheck(burst, { category: "voice", trial: 5, burstPerMin: 3, notePairing: "consume" }, t0 + 1).reason).toBe("burst");
  });

  it("un rechazo no gasta (los reintentos no se castigan solos)", () => {
    const s = base();
    s.trial = { voice: 5 };
    applyCheck(s, { category: "voice", trial: 5, burstPerMin: 5, notePairing: "grant" }, t0);
    expect(s.trial.voice).toBe(5);
    expect(s.notes).toEqual([]);
  });
});
