/**
 * Control del coste de la IA (2026-11-04).
 *
 * 1. Toda fila de chat tiene tope de salida explícito: las activas (`ROUTES`), las preparadas de otro proveedor
 *    (`PREPARED_ROUTES`) y las de las versiones instaladas (`LEGACY_OVERRIDES`). Las passthrough lo llevan por
 *    `PASSTHROUGH_MAX_OUTPUT_TOKENS`. La transcripción no tiene tope de salida en la API de audio: queda fuera.
 * 2. El tope llega al proveedor con el nombre de cada uno (OpenAI, Gemini, Anthropic).
 * 3. Cada llamada deja su registro de uso: tarea, proveedor, modelo, tokens, `finish_reason` y estado. Nada del
 *    contenido ni del dispositivo.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import app from "../src/index";
import type { Env } from "../src/env";
import { issueSessionToken } from "../src/attest/session";
import { LEGACY_OVERRIDES, PASSTHROUGH_MAX_OUTPUT_TOKENS, PREPARED_ROUTES, ROUTES, type ManagedRoute, type Route } from "../src/ai/routes";
import { buildOpenAIBody } from "../src/ai/providers/openai";
import { buildGeminiBody } from "../src/ai/providers/gemini";
import { buildAnthropicBody } from "../src/ai/providers/anthropic";
import { withPassthroughCap } from "../src/ai/handler";
import type { AIUsageRecord } from "../src/ai/usage";
import { intentBody } from "../bench/lib/appRequests";

const recorded: AIUsageRecord[] = [];
vi.mock("../src/ai/usage", async (importOriginal) => {
  const real = await importOriginal<typeof import("../src/ai/usage")>();
  return { ...real, usageSink: () => ({ record: (e: AIUsageRecord) => void recorded.push(e) }) };
});

const NOOP_CTX = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;
const SECRET = "jwt-secret-unit-ai-caps";

function makeEnv(): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "enforce",
    JWT_SIGNING_SECRET: SECRET,
    OPENAI_API_KEY: "sk-unit-openai",
    RATE_LIMITER: { idFromName: () => "id", get: () => ({ fetch: async () => new Response(JSON.stringify({ allowed: true })) }) },
  } as unknown as Env;
}

const USER_TEXT = "ayer gasté 45 soles en el mercado";
let upstream: () => Response;

beforeEach(() => {
  recorded.length = 0;
  upstream = () =>
    new Response(
      JSON.stringify({
        id: "x",
        object: "chat.completion",
        created: 1,
        model: "gpt-6-luna-2026-09-01",
        choices: [{ index: 0, message: { role: "assistant", content: '{"intent":"register","confidence":0.9}' }, finish_reason: "length" }],
        usage: { prompt_tokens: 812, completion_tokens: 200, prompt_tokens_details: { cached_tokens: 512 }, completion_tokens_details: { reasoning_tokens: 0 } },
      }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  vi.stubGlobal("fetch", vi.fn(async () => upstream()));
});

afterEach(() => vi.unstubAllGlobals());

async function chat(body: unknown, category: string, extra: Record<string, string> = {}): Promise<Response> {
  const env = makeEnv();
  const { token } = await issueSessionToken(env, { keyId: "unit-device-caps", tier: "pro" });
  return await app.fetch(
    new Request("https://gw.local/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", "X-Yala-Category": category, ...extra },
      body: JSON.stringify(body),
    }),
    env,
    NOOP_CTX,
  );
}

function chatRows(): [string, Route][] {
  return [
    ...Object.entries(ROUTES).map(([t, r]) => [`ROUTES.${t}`, r] as [string, Route]),
    ...Object.entries(PREPARED_ROUTES).map(([t, r]) => [`PREPARED_ROUTES.${t}`, r as Route] as [string, Route]),
    ...Object.entries(LEGACY_OVERRIDES).map(([t, r]) => [`LEGACY_OVERRIDES.${t}`, r as Route] as [string, Route]),
  ];
}

describe("tope de salida en todas las rutas de IA", () => {
  it("cada fila managed declara maxOutputTokens (entero positivo)", () => {
    const managed = chatRows().filter(([, r]) => r.mode === "managed") as [string, ManagedRoute][];
    expect(managed.length).toBeGreaterThan(10);
    for (const [name, r] of managed) {
      expect(Number.isInteger(r.params.maxOutputTokens), name).toBe(true);
      expect(r.params.maxOutputTokens ?? 0, name).toBeGreaterThan(0);
    }
  });

  it("solo la transcripción va sin tope (la API de audio no lo tiene); el resto es managed o passthrough", () => {
    for (const [name, r] of chatRows()) {
      if (r.mode === "transcription") expect(name).toBe("ROUTES.voice.transcribe");
    }
    expect(PASSTHROUGH_MAX_OUTPUT_TOKENS).toBeGreaterThan(0);
  });

  it("el tope llega a cada proveedor con su nombre de parámetro", () => {
    const body = { messages: [{ role: "user", content: USER_TEXT }] };
    for (const [name, r] of chatRows()) {
      if (r.mode !== "managed") continue;
      const cap = r.params.maxOutputTokens;
      if (r.provider === "gemini") {
        expect((buildGeminiBody(body, r).generationConfig as Record<string, unknown>).maxOutputTokens, name).toBe(cap);
      } else if (r.provider === "anthropic") {
        expect(buildAnthropicBody(body, r).max_tokens, name).toBe(cap);
      } else {
        expect(buildOpenAIBody(body, r).max_completion_tokens, name).toBe(cap);
      }
    }
  });

  it("passthrough: el tope se antepone sin tocar el resto de bytes; con tope propio, intacto", () => {
    const enc = new TextEncoder();
    const dec = new TextDecoder();
    const raw = '  {"model":"gpt-4.1-mini","messages":[]}';
    expect(dec.decode(withPassthroughCap(enc.encode(raw), JSON.parse(raw)))).toBe(`  {"max_completion_tokens":${PASSTHROUGH_MAX_OUTPUT_TOKENS},"model":"gpt-4.1-mini","messages":[]}`);
    expect(dec.decode(withPassthroughCap(enc.encode("{ }"), {} as never))).toBe(`{"max_completion_tokens":${PASSTHROUGH_MAX_OUTPUT_TOKENS} }`);
    const own = '{"max_tokens":10,"messages":[]}';
    expect(dec.decode(withPassthroughCap(enc.encode(own), JSON.parse(own)))).toBe(own);
  });
});

describe("registro de uso por llamada", () => {
  it("una llamada managed deja tarea, proveedor, modelo, tokens, finish_reason y estado", async () => {
    const res = await chat(intentBody(USER_TEXT), "suggestions", { "X-Yala-Task": "chat.intent" });
    expect(res.status).toBe(200);
    expect(recorded).toEqual([
      {
        task: "chat.intent",
        category: "suggestions",
        provider: "openai",
        model: "gpt-6-luna-2026-09-01",
        status: 200,
        finishReason: "length",
        inputTokens: 812,
        cachedInputTokens: 512,
        outputTokens: 200,
        reasoningTokens: 0,
        ms: expect.any(Number),
        attempts: 1,
      },
    ]);
  });

  it("el registro no lleva nada del contenido ni del dispositivo", async () => {
    await chat(intentBody(USER_TEXT), "suggestions", { "X-Yala-Task": "chat.intent" });
    const dump = JSON.stringify(recorded);
    expect(recorded).toHaveLength(1);
    expect(dump).not.toContain("mercado");
    expect(dump).not.toContain("register"); // contenido de la respuesta
    expect(dump).not.toContain("unit-device-caps");
    expect(Object.keys(recorded[0]).sort()).toEqual(
      ["attempts", "cachedInputTokens", "category", "finishReason", "inputTokens", "model", "ms", "outputTokens", "provider", "reasoningTokens", "status", "task"],
    );
  });

  it("un error del proveedor también se registra, sin tokens", async () => {
    upstream = () => new Response(JSON.stringify({ error: { type: "server_error", code: null, message: "x" } }), { status: 500, headers: { "content-type": "application/json" } });
    const res = await chat(intentBody(USER_TEXT), "suggestions", { "X-Yala-Task": "chat.intent" });
    expect(res.status).toBe(500);
    expect(recorded).toHaveLength(1);
    expect(recorded[0]).toMatchObject({ task: "chat.intent", status: 500, finishReason: null, inputTokens: null, outputTokens: null });
  });

  it("un registro que falla no tumba la respuesta", async () => {
    const { recordUsage } = await vi.importActual<typeof import("../src/ai/usage")>("../src/ai/usage");
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    expect(() => recordUsage({ record: () => { throw new Error("AE caído"); } }, {} as AIUsageRecord)).not.toThrow();
    log.mockRestore();
  });
});

describe("registro de uso en Analytics Engine", () => {
  it("con el binding AI_USAGE escribe un punto con las columnas fijadas; sin él, nada", async () => {
    const real = await vi.importActual<typeof import("../src/ai/usage")>("../src/ai/usage");
    const points: AnalyticsEngineDataPoint[] = [];
    const dataset = { writeDataPoint: (p: AnalyticsEngineDataPoint) => void points.push(p) } as AnalyticsEngineDataset;
    const entry: AIUsageRecord = {
      task: "photo.read", category: "vision", provider: "openai", model: "gpt-6-luna", status: 200, finishReason: "stop",
      inputTokens: 1200, cachedInputTokens: 0, outputTokens: 150, reasoningTokens: 40, ms: 3100, attempts: 1,
    };
    real.usageSink({ AI_USAGE: dataset } as unknown as Env).record(entry);
    expect(points).toEqual([
      {
        blobs: ["photo.read", "vision", "openai", "gpt-6-luna", "stop"],
        doubles: [200, 1200, 0, 150, 40, 3100, 1, 1],
        indexes: ["photo.read"],
      },
    ]);
    real.usageSink({ AI_USAGE: dataset } as unknown as Env).record({ ...entry, status: 502, finishReason: null, model: null, inputTokens: null, cachedInputTokens: null, outputTokens: null, reasoningTokens: null });
    expect(points[1]).toEqual({ blobs: ["photo.read", "vision", "openai", "", ""], doubles: [502, 0, 0, 0, 0, 3100, 1, 0], indexes: ["photo.read"] });
    expect(() => real.usageSink({} as Env).record(entry)).not.toThrow();
    expect(points).toHaveLength(2);
  });
});
