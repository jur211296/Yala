/**
 * Repartir un recibo en un grupo (2.3): `receipt.photo` y `receipt.voice`.
 *
 * Fija el contrato de las tareas: la foto exige imagen, la nota se transcribe con `receipt.transcribe` y leerla tras
 * transcribir no gasta otra, y las dos salen con JSON estricto con el esquema que decodifica la app.
 * Desde el 2026-11-14 (Jürgen) todo cuenta en el cubo `receipt`: 5 recibos al día en Free y 50 en Pro, foto o voz, sin
 * tocar las 5 fotos y 5 notas de prueba de personal.
 * El arnés es el de `ai.session2.test.ts` (limitador real con un Durable Object falso).
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

const RECEIPT_TEXT = {
  model: "gpt-4.1-mini",
  messages: [
    { role: "system", content: "receipt splitter" },
    { role: "user", content: "pizza 40, lomo 35, dos chichas 16. Ana el lomo, Luis y yo la pizza" },
  ],
};
const RECEIPT_PHOTO = {
  ...RECEIPT_TEXT,
  messages: [
    { role: "system", content: "receipt splitter" },
    {
      role: "user",
      content: [
        { type: "text", text: "Ana el lomo" },
        { type: "image_url", image_url: { url: `data:image/png;base64,${IMAGE_B64}`, detail: "auto" } },
      ],
    },
  ],
};

describe("receipt.photo · la foto de un recibo con su frase", () => {
  it("sin imagen → 400, sin gastar ni llamar: el cubo de visión no sirve para leer texto gratis", async () => {
    const res = await chat(RECEIPT_TEXT, { "X-Yala-Task": "receipt.photo" });
    expect(res.status).toBe(400);
    expect(checks).toHaveLength(0);
    expect(sent).toHaveLength(0);
  });

  it("con imagen pasa, gasta del cubo de recibos y sale con JSON estricto y la imagen en alta", async () => {
    expect((await chat(RECEIPT_PHOTO, { "X-Yala-Task": "receipt.photo" })).status).toBe(200);
    expect(checks.map((c) => c.category)).toEqual(["receipt"]);
    const body = sent[0]?.json as Record<string, any>;
    expect(body.model).toBe("gpt-6-luna");
    expect(body.response_format).toMatchObject({ type: "json_schema", json_schema: { name: "receipt_split", strict: true } });
    expect(body.messages[1].content[1].image_url.detail).toBe("high");
    expect(typeof body.max_completion_tokens).toBe("number");
  });

  it("no toca las 5 fotos de prueba de personal: con la prueba agotada, el recibo pasa", async () => {
    for (let i = 0; i < 5; i++) await chat(PHOTO, { "X-Yala-Task": "photo.read" });
    expect((await chat(PHOTO, { "X-Yala-Task": "photo.read" })).status).toBe(403);
    expect((await chat(RECEIPT_PHOTO, { "X-Yala-Task": "receipt.photo" })).status).toBe(200);
    expect(stores.get("unit-device")?.trial?.vision).toBe(5);
  });

  it("Free: 5 recibos al día; el 6.º es 429 de cupo diario, y al día siguiente vuelve", async () => {
    for (let i = 0; i < 5; i++) expect((await chat(RECEIPT_PHOTO, { "X-Yala-Task": "receipt.photo" })).status).toBe(200);
    const sixth = await chat(RECEIPT_PHOTO, { "X-Yala-Task": "receipt.photo" });
    expect(sixth.status).toBe(429);
    expect(await errorType(sixth)).toBe("yala_quota_daily");
    now += 24 * 60 * 60 * 1000;
    expect((await chat(RECEIPT_PHOTO, { "X-Yala-Task": "receipt.photo" })).status).toBe(200);
  });

  it("Pro: 50 recibos al día con su propio contador; el 51.º es 429", async () => {
    for (let i = 0; i < 50; i++) expect((await chat(RECEIPT_PHOTO, { "X-Yala-Task": "receipt.photo" }, "pro")).status).toBe(200);
    expect((await chat(RECEIPT_PHOTO, { "X-Yala-Task": "receipt.photo" }, "pro")).status).toBe(429);
    expect((await chat(PHOTO, { "X-Yala-Task": "photo.read" }, "pro")).status).toBe(200);
  });

  it("una categoría declarada que no casa (voz) → 400", async () => {
    const res = await chat(RECEIPT_PHOTO, { "X-Yala-Task": "receipt.photo", "X-Yala-Category": "voice" });
    expect(res.status).toBe(400);
    expect(await errorType(res)).toBe("yala_task_mismatch");
  });
});

describe("receipt.voice · una nota con las líneas y el reparto", () => {
  it("transcribir y leer el recibo es UN recibo del día, y no gasta notas de prueba", async () => {
    expect((await transcribe({ "X-Yala-Task": "receipt.transcribe", "X-Yala-Category": "receipt" })).status).toBe(200);
    expect((await chat(RECEIPT_TEXT, { "X-Yala-Task": "receipt.voice" })).status).toBe(200);
    expect(checks.map((c) => c.category)).toEqual(["receipt", "receipt"]);
    expect(stores.get("unit-device")?.counts?.receipt).toBe(1);
    expect(stores.get("unit-device")?.trial?.voice).toBeUndefined();
  });

  it("la transcripción del recibo va con el modelo de voz de siempre", async () => {
    await transcribe({ "X-Yala-Task": "receipt.transcribe" });
    expect(sent[0]?.url).toContain("/audio/transcriptions");
  });

  it("foto y voz comparten los 5 del día", async () => {
    for (let i = 0; i < 3; i++) await chat(RECEIPT_PHOTO, { "X-Yala-Task": "receipt.photo" });
    for (let i = 0; i < 2; i++) {
      await transcribe({ "X-Yala-Task": "receipt.transcribe" });
      await chat(RECEIPT_TEXT, { "X-Yala-Task": "receipt.voice" });
    }
    expect((await transcribe({ "X-Yala-Task": "receipt.transcribe" })).status).toBe(429);
  });

  it("leer sin haber transcrito gasta su propio recibo del día", async () => {
    await chat(RECEIPT_TEXT, { "X-Yala-Task": "receipt.voice" });
    expect(checks.map((c) => c.category)).toEqual(["receipt"]);
    expect(stores.get("unit-device")?.counts?.receipt).toBe(1);
  });

  it("sale con JSON estricto con el mismo esquema que la foto", async () => {
    await chat(RECEIPT_TEXT, { "X-Yala-Task": "receipt.voice" }, "pro");
    const body = sent[0]?.json as Record<string, any>;
    expect(body.response_format).toMatchObject({ type: "json_schema", json_schema: { name: "receipt_split", strict: true } });
  });
});
