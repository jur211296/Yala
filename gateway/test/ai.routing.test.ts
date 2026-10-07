/**
 * Enrutado de IA por tarea (src/ai/): tabla tarea → {proveedor, modelo, parámetros}.
 *
 * Cuerpos REALES: los prompts salen del código Swift de la app (bench/lib/appRequests.ts) y la imagen es un
 * ejemplo que la app enseña al usuario. Lo que fija:
 *
 * 1. CONTROL ROJO CON EL CÓDIGO VIEJO: ninguna de las tres tareas de gpt-4.1-nano sale hacia el proveedor
 *    con `gpt-4.1-nano` (OpenAI lo apaga el 2026-10-23). El proxy anterior reenviaba el cuerpo tal cual, así
 *    que el primer `describe` falla entero contra él (medido: ver el PR).
 * 2. Deducción sin cabecera de las tres tareas, por categoría + modelo + huella del prompt.
 * 3. Con cabecera manda la tabla; una cabecera desconocida se ignora; una de otro cubo se rechaza.
 * 4. Modelo fuera de la tabla → 400, y no se gasta cuota ni se llama a nadie.
 * 5. Los parámetros salen según la fila (y no los de la app).
 * 6. Las llamadas que no eran de nano: desde la sesión 2 las decide la tabla (con los parámetros de hoy hasta que su
 *    banco elija); solo lo que ninguna huella reconoce sale BYTE A BYTE como antes.
 * 7. Sin cabecera, nunca un proveedor que no sea OpenAI (las versiones instaladas lo prometen).
 */
import { readFileSync } from "node:fs";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import app from "../src/index";
import type { Env } from "../src/env";
import { issueSessionToken } from "../src/attest/session";
import { ROUTES, routeFor, type ManagedRoute, type Route } from "../src/ai/routes";
import { TASKS, type TaskId } from "../src/ai/tasks";
import { intentBody, photoReadBody, suggestionsBody } from "../bench/lib/appRequests";

const NOOP_CTX = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;
const SECRET = "jwt-secret-unit-ai-routing";

let gateCalls = 0;
let gateCategories: string[] = [];
function makeEnv(overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "enforce",
    JWT_SIGNING_SECRET: SECRET,
    OPENAI_API_KEY: "sk-unit-openai",
    RATE_LIMITER: {
      idFromName: () => "id",
      get: () => ({
        fetch: async (_url: string, init?: RequestInit) => {
          gateCalls++;
          gateCategories.push((JSON.parse(String(init?.body ?? "{}")) as { category?: string }).category ?? "");
          return new Response(JSON.stringify({ allowed: true }));
        },
      }),
    },
    ...overrides,
  } as unknown as Env;
}

interface Sent {
  url: string;
  headers: Headers;
  bytes: Uint8Array;
  json: Record<string, unknown> | null;
}

let sent: Sent[] = [];
const OPENAI_OK = {
  id: "chatcmpl-x",
  object: "chat.completion",
  created: 1,
  model: "upstream-model",
  choices: [{ index: 0, message: { role: "assistant", content: "{}" }, finish_reason: "stop" }],
  usage: { prompt_tokens: 10, completion_tokens: 2, total_tokens: 12 },
};

beforeEach(() => {
  sent = [];
  gateCalls = 0;
  gateCategories = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown, init?: RequestInit) => {
      const url = typeof input === "string" ? input : (input as Request).url;
      const body = init?.body;
      // El proxy anterior reenviaba el cuerpo como stream: se lee igual para que el control mida al viejo.
      const bytes =
        body instanceof Uint8Array
          ? body
          : typeof body === "string"
            ? new TextEncoder().encode(body)
            : body
              ? new Uint8Array(await new Response(body as ReadableStream).arrayBuffer())
              : new Uint8Array();
      let json: Record<string, unknown> | null = null;
      try {
        json = JSON.parse(new TextDecoder().decode(bytes));
      } catch {
        json = null;
      }
      sent.push({ url, headers: new Headers(init?.headers), bytes, json });
      if (url.includes("/audio/transcriptions")) {
        return new Response(JSON.stringify({ text: "hola" }), { status: 200, headers: { "content-type": "application/json" } });
      }
      return new Response(JSON.stringify(OPENAI_OK), { status: 200, headers: { "content-type": "application/json" } });
    }),
  );
});

afterEach(() => {
  vi.unstubAllGlobals();
});

async function bearer(tier: "pro" | "free" = "pro"): Promise<string> {
  const env = makeEnv();
  const { token } = await issueSessionToken(env, { keyId: "unit-device", tier });
  return `Bearer ${token}`;
}

async function chat(body: unknown, category: string, extra: Record<string, string> = {}, env = makeEnv(), tier: "pro" | "free" = "pro"): Promise<Response> {
  return await app.fetch(
    new Request("https://gw.local/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: await bearer(tier), "Content-Type": "application/json", "X-Yala-Category": category, ...extra },
      body: typeof body === "string" ? body : JSON.stringify(body),
    }),
    env,
    NOOP_CTX,
  );
}

// Imagen real: el ejemplo de alerta bancaria que la app enseña (PNG; la app manda JPEG, al gateway le da igual).
const IMAGE_B64 = Buffer.from(
  readFileSync(new URL("../../Yala/Resources/Assets.xcassets/ExampleImages/example-bank-alert-es.imageset/example-bank-alert-es.png", import.meta.url) as unknown as string),
).toString("base64");

const PHOTO = photoReadBody(IMAGE_B64, "2026-10-07");
const INTENT = intentBody("ayer gasté 45 soles en el mercado");
const SUGGESTIONS = suggestionsBody({
  language: "es-PE",
  topCategories: ["Comida", "Transporte"],
  subcategoryNames: ["Mercado", "Taxi"],
  merchantNames: ["Plaza Vea"],
  activeBudgets: ["Mercado"],
  tagNames: [],
  recurringPaidNames: ["Netflix"],
  totalIncome: 4200,
  totalExpense: 1830,
});

const NANO_CASES: { task: TaskId; body: Record<string, unknown>; category: string }[] = [
  { task: "photo.read", body: PHOTO, category: "vision" },
  { task: "chat.intent", body: INTENT, category: "suggestions" },
  { task: "chat.suggestions", body: SUGGESTIONS, category: "suggestions" },
];

function managed(task: TaskId): ManagedRoute {
  const r = ROUTES[task];
  if (r.mode !== "managed") throw new Error(`${task} no es managed`);
  return r;
}

describe("CONTROL: las tres tareas de gpt-4.1-nano ya no salen con gpt-4.1-nano (rojo con el proxy viejo)", () => {
  for (const c of NANO_CASES) {
    it(`${c.task} (sin cabecera, como las versiones instaladas)`, async () => {
      const res = await chat(c.body, c.category);
      expect(res.status).toBe(200);
      expect(sent).toHaveLength(1);
      expect(sent[0].json?.model).not.toBe("gpt-4.1-nano");
      expect(sent[0].json?.model).toBe(managed(c.task).model);
    });
  }

  it("ninguna fila de la tabla apunta a gpt-4.1-nano", () => {
    for (const [task, route] of Object.entries(ROUTES) as [TaskId, Route][]) {
      if (route.mode === "managed") expect(route.model, task).not.toBe("gpt-4.1-nano");
      else expect(route.allowedModels, task).not.toContain("gpt-4.1-nano");
    }
  });
});

describe("deducción sin cabecera, con cuerpos reales", () => {
  it("photo.read: categoría vision + imagen; la imagen viaja intacta y con el `detail` de la fila", async () => {
    await chat(PHOTO, "vision");
    const msgs = sent[0].json?.messages as { role: string; content: unknown }[];
    const parts = msgs[1].content as { type: string; image_url?: { url: string; detail: string } }[];
    const img = parts.find((p) => p.type === "image_url");
    expect(img?.image_url?.url).toBe(`data:image/jpeg;base64,${IMAGE_B64}`);
    expect(img?.image_url?.detail).toBe(managed("photo.read").params.image?.detail);
    expect(msgs[0]).toEqual((PHOTO.messages as unknown[])[0]);
  });

  it("chat.intent y chat.suggestions comparten categoría y modelo: los separa la huella del prompt", async () => {
    const intentRoute = managed("chat.intent");
    const suggRoute = managed("chat.suggestions");
    await chat(INTENT, "suggestions");
    await chat(SUGGESTIONS, "suggestions");
    expect(sent[0].json?.temperature).toBe(intentRoute.params.temperature);
    expect(sent[1].json?.temperature).toBe(suggRoute.params.temperature);
  });

  it("sin huella (cuerpo que no salió de la app): temperatura 0 → chat.intent, otra → chat.suggestions", async () => {
    const strip = (b: Record<string, unknown>) => ({
      ...b,
      messages: [{ role: "system", content: "otro prompt" }, ...(b.messages as unknown[]).slice(1)],
    });
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    await chat(strip(INTENT), "suggestions");
    await chat(strip(SUGGESTIONS), "suggestions");
    const routes = log.mock.calls.map((c) => String(c[0])).filter((l) => l.includes('"evt":"ai_route"')).map((l) => JSON.parse(l));
    log.mockRestore();
    expect(routes.map((r) => [r.task, r.how])).toEqual([
      ["chat.intent", "heuristic"],
      ["chat.suggestions", "heuristic"],
    ]);
  });

  it("gpt-4.1-nano en una categoría donde la app nunca lo usó → 400 sin llamar a nadie ni gastar cuota", async () => {
    const res = await chat({ ...INTENT }, "insights");
    expect(res.status).toBe(400);
    expect(((await res.json()) as { error: { type: string } }).error.type).toBe("yala_model_not_allowed");
    expect(sent).toHaveLength(0);
    expect(gateCalls).toBe(0);
  });
});

describe("cabecera X-Yala-Task", () => {
  it("con cabecera manda la tabla aunque el cuerpo pida otro modelo", async () => {
    await chat({ ...INTENT, model: "gpt-9-imaginario" }, "suggestions", { "X-Yala-Task": "chat.intent" });
    expect(sent).toHaveLength(1);
    expect(sent[0].json?.model).toBe(managed("chat.intent").model);
  });

  it("cabecera desconocida → se ignora y se deduce (un gateway viejo no tumba a una app nueva)", async () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    const res = await chat(INTENT, "suggestions", { "X-Yala-Task": "chat.futuro" });
    const line = log.mock.calls.map((c) => String(c[0])).find((l) => l.includes('"evt":"ai_route"'));
    log.mockRestore();
    expect(res.status).toBe(200);
    expect(JSON.parse(line ?? "{}")).toMatchObject({ task: "chat.intent", how: "fingerprint", headerUnknown: true });
  });

  it("tarea de otro cubo de cuota → 400 yala_task_mismatch (no se cuela una tarea cara en un cubo barato)", async () => {
    const res = await chat(PHOTO, "suggestions", { "X-Yala-Task": "photo.read" });
    expect(res.status).toBe(400);
    expect(((await res.json()) as { error: { type: string } }).error.type).toBe("yala_task_mismatch");
    expect(sent).toHaveLength(0);
  });

  it("una tarea que solo se deduce (legacy.passthrough, insights.hero) no se puede pedir por cabecera: se ignora", async () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    const res = await chat({ model: "gpt-5", messages: [{ role: "user", content: "hola" }] }, "chat", { "X-Yala-Task": "legacy.passthrough" });
    log.mockRestore();
    // Sin la cabecera, gpt-5 no se deduce a nada: 400 sin gastar cuota.
    expect(res.status).toBe(400);
    expect(sent).toHaveLength(0);
    expect(gateCalls).toBe(0);
  });
});

describe("modelo desconocido sin cabecera", () => {
  for (const model of ["gpt-5", "gpt-4o", "o3", ""]) {
    it(`«${model || "(vacío)"}» → 400, sin reenviar ni gastar cuota`, async () => {
      const res = await chat({ model, messages: [{ role: "user", content: "hola" }] }, "chat");
      expect(res.status).toBe(400);
      expect(sent).toHaveLength(0);
      expect(gateCalls).toBe(0);
    });
  }

  it("cuerpo que no es JSON → 400", async () => {
    const res = await chat("no-json", "chat");
    expect(res.status).toBe(400);
    expect(sent).toHaveLength(0);
  });
});

describe("parámetros según la fila", () => {
  for (const c of NANO_CASES) {
    it(`${c.task}: modelo, temperatura, razonamiento, tope y formato salen de la tabla`, async () => {
      await chat(c.body, c.category);
      const r = managed(c.task);
      const out = sent[0].json ?? {};
      expect(out.model).toBe(r.model);
      expect(out.temperature).toBe(r.params.temperature);
      expect(out.reasoning_effort).toBe(r.params.reasoningEffort);
      expect(out.max_completion_tokens).toBe(r.params.maxOutputTokens);
      expect((out.response_format as { type: string }).type).toBe(r.params.strictSchema ? "json_schema" : "json_object");
      // Los mensajes son los de la app (salvo el `detail` de imagen).
      expect((out.messages as unknown[]).length).toBe((c.body.messages as unknown[]).length);
      expect(sent[0].headers.get("authorization")).toBe("Bearer sk-unit-openai");
    });
  }

  it("la respuesta vuelve a la app con la forma de OpenAI", async () => {
    const res = await chat(INTENT, "suggestions");
    expect(await res.json()).toEqual(OPENAI_OK);
  });
});

describe("las de gpt-4.1-mini: las decide la tabla, con los parámetros de hoy hasta su banco (sesión 2)", () => {
  const MINI_CASES: [string, TaskId, Record<string, unknown>][] = [
    ["chat", "chat.answer", { model: "gpt-4.1-mini", messages: [{ role: "system", content: "Eres Yala IA…" }, { role: "user", content: "¿cuánto gasté?" }], temperature: 0.4, stream: false }],
    ["voice", "text.parse", { model: "gpt-4.1-mini", messages: [{ role: "system", content: "parser" }, { role: "user", content: "50 en taxi" }], temperature: 0.1, stream: false }],
    ["insights", "trends.summary", { model: "gpt-4.1-mini", messages: [{ role: "system", content: "Eres un analista financiero personal. El usuario está mirando la pestaña Tendencias de su app, con estas gráficas:" }], response_format: { type: "json_object" }, temperature: 0.4, stream: false }],
    ["suggestions", "chat.rewrite", { model: "gpt-4.1-mini", messages: [{ role: "system", content: "You rewrite chat suggestion phrases for a personal finance app." }], response_format: { type: "json_object" }, temperature: 0.3, stream: false }],
  ];
  for (const [category, task, body] of MINI_CASES) {
    it(`${task} (sin cabecera): mensajes de la app intactos + modelo, temperatura y formato de la fila`, async () => {
      const res = await chat(body, category);
      expect(res.status).toBe(200);
      expect(sent).toHaveLength(1);
      expect(sent[0].url).toBe("https://api.openai.com/v1/chat/completions");
      const r = managed(task);
      const out = sent[0].json ?? {};
      expect(out.messages).toEqual(body.messages);
      expect(out.model).toBe(r.model);
      expect(out.temperature).toBe(r.params.temperature);
      expect(out.max_completion_tokens).toBe(r.params.maxOutputTokens);
      expect(out.response_format).toEqual(body.response_format);
    });
  }

  it("mientras su banco no decida, cada fila reproduce la llamada de hoy (gpt-4.1-mini, misma temperatura y formato)", () => {
    for (const [, task, body] of MINI_CASES) {
      const r = managed(task);
      if (r.model !== "gpt-4.1-mini") continue; // ya decidida por su banco: la fija su propio test
      expect(r.params.temperature, task).toBe(body.temperature);
      expect(r.params.responseFormat, task).toBe(body.response_format ? "json_object" : "text");
    }
  });

  it("una petición con gpt-4.1-mini que ninguna huella reconoce sale BYTE A BYTE como siempre (legacy.passthrough)", async () => {
    const body = { model: "gpt-4.1-mini", messages: [{ role: "system", content: "un prompt que no es de esta app" }], response_format: { type: "json_object" }, temperature: 0.2, stream: false };
    const raw = JSON.stringify(body, null, 3);
    const res = await chat(raw, "suggestions");
    expect(res.status).toBe(200);
    expect(new TextDecoder().decode(sent[0].bytes)).toBe(raw);
  });

  it("transcripción: multipart idéntico, y otro modelo que no sea whisper-1 → 400", async () => {
    const boundary = "----yala-unit";
    const audio = new Uint8Array([0, 1, 2, 255, 13, 10, 13, 10, 7]);
    const enc = new TextEncoder();
    const build = (model: string) => {
      const head = enc.encode(
        `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="a.m4a"\r\nContent-Type: audio/m4a\r\n\r\n`,
      );
      const tail = enc.encode(`\r\n--${boundary}\r\nContent-Disposition: form-data; name="model"\r\n\r\n${model}\r\n--${boundary}\r\nContent-Disposition: form-data; name="language"\r\n\r\nes\r\n--${boundary}--\r\n`);
      const all = new Uint8Array(head.length + audio.length + tail.length);
      all.set(head, 0);
      all.set(audio, head.length);
      all.set(tail, head.length + audio.length);
      return all;
    };
    const post = async (bytes: Uint8Array) =>
      await app.fetch(
        new Request("https://gw.local/v1/audio/transcriptions", {
          method: "POST",
          headers: { Authorization: await bearer(), "Content-Type": `multipart/form-data; boundary=${boundary}`, "X-Yala-Category": "voice" },
          body: bytes,
        }),
        makeEnv(),
        NOOP_CTX,
      );
    const ok = build("whisper-1");
    expect((await post(ok)).status).toBe(200);
    expect(sent).toHaveLength(1);
    expect(Array.from(sent[0].bytes)).toEqual(Array.from(ok));
    expect(sent[0].headers.get("content-type")).toBe(`multipart/form-data; boundary=${boundary}`);
    expect((await post(build("gpt-4o-mini-transcribe"))).status).toBe(400);
    expect(sent).toHaveLength(1);
  });
});

describe("la lectura de la nota de voz cuenta en el cubo de voz (rojo con el gateway anterior)", () => {
  const PARSER = { model: "gpt-4.1-mini", messages: [{ role: "system", content: "parser" }, { role: "user", content: "taxi 12" }], temperature: 0.1, stream: false };

  it("free: la nota de voz se lee (antes: 403 «requiere Pro» porque caía en el cubo chat)", async () => {
    const res = await chat(PARSER, "voice", {}, makeEnv(), "free");
    expect(res.status).toBe(200);
    expect(gateCategories).toEqual(["voice"]);
    expect(sent).toHaveLength(1);
  });

  it("pro: gasta del cubo de voz, no del de chat", async () => {
    await chat(PARSER, "voice");
    expect(gateCategories).toEqual(["voice"]);
  });

  it("free sigue sin chat: una pregunta al asistente → 403 yala_pro_required", async () => {
    const res = await chat({ ...PARSER, messages: [{ role: "user", content: "¿cuánto gasté?" }] }, "chat", {}, makeEnv(), "free");
    expect(res.status).toBe(403);
    expect(sent).toHaveLength(0);
  });
});

describe("sin cabecera, solo OpenAI", () => {
  it("las filas que sirven a versiones instaladas son todas de OpenAI", () => {
    for (const task of Object.keys(TASKS) as TaskId[]) {
      const r = routeFor(task, false);
      if (r.mode === "managed") expect(r.provider, task).toBe("openai");
    }
  });

  it("si una fila pasa a otro proveedor sin su override de OpenAI, routeFor se niega", () => {
    const table = { ...ROUTES, "chat.intent": { ...managed("chat.intent"), provider: "gemini" as const, model: "gemini-x" } };
    expect(() => routeFor("chat.intent", false, table, {})).toThrow(/LEGACY_OVERRIDE/);
    expect(routeFor("chat.intent", true, table, {})).toMatchObject({ provider: "gemini" });
    expect(routeFor("chat.intent", false, table, { "chat.intent": managed("chat.intent") })).toMatchObject({ provider: "openai" });
  });
});

describe("log por petición", () => {
  it("una línea ai_route con tarea, modelo y tokens, y sin contenido del usuario", async () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    await chat(INTENT, "suggestions");
    const lines = log.mock.calls.map((c) => String(c[0]));
    log.mockRestore();
    const line = lines.find((l) => l.includes('"evt":"ai_route"')) ?? "";
    expect(JSON.parse(line)).toMatchObject({ task: "chat.intent", how: "fingerprint", provider: "openai", model: "upstream-model", status: 200, in: 10, out: 2 });
    expect(lines.join("\n")).not.toContain("mercado");
  });
});
