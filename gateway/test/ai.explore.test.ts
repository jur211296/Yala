/**
 * Yala IA en modo nube, camino ampliado (`chat.explore`, src/ai/explore/): el modelo pide datos con herramientas y el
 * gateway las ejecuta contra las tablas del usuario con su JWT de Supabase.
 *
 * Lo que se fija:
 * 1. Las herramientas son las seis del conector MCP, sin zona horaria elegible y con `limite` acotado.
 * 2. Lista cerrada: solo GET a las tablas que leen las herramientas.
 * 3. El bucle: topes por pregunta, cada `tool_call_id` con respuesta, errores de herramienta que no rompen.
 * 4. El handler: con el flag a 0 o sin usuario, `chat.explore` sale EXACTAMENTE como `chat.answer`; con todo, usa
 *    herramientas y gasta UN uso de la cuota por pregunta. `chat.answer` nunca lleva herramientas.
 * 5. Todo lo que el gateway importa del conector carece de dependencias (el CI del gateway no instala las del conector).
 */
import { readFileSync, readdirSync } from "node:fs";
import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";

vi.mock("../src/sync/userauth", async (importOriginal) => {
  const orig = await importOriginal<typeof import("../src/sync/userauth")>();
  return {
    ...orig,
    // Verifica cualquier JWT que no sea «jwt-caducado» (la firma la comprueba el de verdad; aquí se prueba qué hace el
    // gateway con el resultado).
    verifyUserToken: vi.fn(async (_env: unknown, token: string) => (token.startsWith("eyJ") ? { sub: "11111111-1111-4111-8111-111111111111", token } : null)),
  };
});

/** JWT sin firmar con su `exp` (el mock de arriba lo da por verificado). */
function jwtExpiringIn(seconds: number): string {
  const b64 = (o: unknown) => btoa(JSON.stringify(o)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return `${b64({ alg: "ES256", typ: "JWT" })}.${b64({ sub: "u", exp: Math.floor(Date.now() / 1000) + seconds })}.firma`;
}

import app from "../src/index";
import type { Env } from "../src/env";
import { issueSessionToken } from "../src/attest/session";
import { applyCheck, applyRefund, type CheckRequest, type RefundRequest } from "../src/rate_limiter";
import { TOOL_CORES, type ToolContext } from "../../mcp/src/toolCore";
import { EXPLORE_MAX_MOVEMENTS, EXPLORE_TOOL_SPECS, exploreArgs, openAIToolDefinitions } from "../src/ai/explore/tools";
import { EXPLORE_TABLES, exploreReader, isAllowedExploreRead } from "../src/ai/explore/reader";
import { EXPLORE_ADDENDUM, withExploreAddendum } from "../src/ai/explore/prompt";
import { EXPLORE_LIMITS, runExplore, type ExploreLimits } from "../src/ai/explore/loop";
import { EXPLORE_MIN_TOKEN_LIFE_MS, expiresWithin, exploreTimeZone } from "../src/ai/explore";
import { fitResult, runExploreTool } from "../src/ai/explore/loop";
import { ROUTES, type ManagedRoute } from "../src/ai/routes";
import type { OpenAIChatBody } from "../src/ai/providers/types";

const USER_ID = "11111111-1111-4111-8111-111111111111";
const SB = "https://proyecto.supabase.co";
const SB_ENV = { SUPABASE_URL: SB, SUPABASE_ANON_KEY: "anon-publica" };
const NOOP_CTX = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;

// ------------------------------------------------------------------ datos de prueba de las tablas

const ACC = "aaaaaaaa-0000-4000-8000-000000000001";
const TABLES: Record<string, Record<string, unknown>[]> = {
  accounts: [
    {
      sync_id: ACC,
      name: "Cuenta sueldo",
      currency_code: "PEN",
      type: "bank",
      is_archived: false,
      exclude_from_statistics: false,
      is_system_account: false,
      parent_account_id: null,
    },
  ],
  tx_items: [{ account_ref: ACC, amount: "1250.50", currency_code: "PEN" }],
  user_preferences: [{ key: "defaultCurrencyCode", value: "PEN" }],
  exchange_rates: [],
  categories: [],
  subcategories: [],
  tags: [],
  budgets: [],
  scheduled_payments: [],
};

interface Sent {
  url: string;
  method: string;
  headers: Headers;
  json: Record<string, unknown> | null;
}

/** PostgREST falso: devuelve la tabla en la primera página y vacío en las siguientes (así para `all()`). */
function postgrest(url: URL, sent: Sent[], init?: RequestInit): Response {
  sent.push({ url: url.toString(), method: (init?.method ?? "GET").toUpperCase(), headers: new Headers(init?.headers), json: null });
  const table = url.pathname.replace("/rest/v1/", "");
  const offset = Number(url.searchParams.get("offset") ?? "0");
  const rows = offset === 0 ? (TABLES[table] ?? []) : [];
  return Response.json(rows);
}

function completion(message: Record<string, unknown>, usage = { prompt_tokens: 100, completion_tokens: 10 }) {
  return Response.json({
    id: "x",
    object: "chat.completion",
    created: 1,
    model: "gpt-6-luna-2026",
    choices: [{ index: 0, message: { role: "assistant", ...message }, finish_reason: message.tool_calls ? "tool_calls" : "stop" }],
    usage: { ...usage, total_tokens: usage.prompt_tokens + usage.completion_tokens },
  });
}

function toolCall(id: string, name: string, args: unknown = {}) {
  return { id, type: "function", function: { name, arguments: typeof args === "string" ? args : JSON.stringify(args) } };
}

const APP_BODY: OpenAIChatBody = {
  model: "gpt-4.1-mini",
  temperature: 0.4,
  messages: [
    { role: "system", content: "Eres el asistente financiero de Yala. … DATOS DEL USUARIO (JSON): {}" },
    { role: "user", content: "¿cuánto tengo en mis cuentas?" },
  ],
};

function toolContext(sent: Sent[]): ToolContext {
  return {
    reader: exploreReader(SB_ENV, "jwt-usuario", async (input, init) => postgrest(new URL(String(input)), sent, init)),
    env: { ...SB_ENV, DEFAULT_TIMEZONE: "America/Lima" },
    now: new Date("2026-10-18T15:00:00Z"),
  };
}

// ------------------------------------------------------------------ 1 · las herramientas

describe("explore · herramientas", () => {
  it("son las seis del conector, en el mismo orden", () => {
    expect(EXPLORE_TOOL_SPECS.map((s) => s.name)).toEqual(TOOL_CORES.map((c) => c.name));
    expect(EXPLORE_TOOL_SPECS).toHaveLength(6);
  });

  it("ninguna deja elegir la zona horaria al modelo, y `limite` va hasta 50", () => {
    for (const spec of EXPLORE_TOOL_SPECS) {
      expect(Object.keys((spec.parameters.properties ?? {}) as object)).not.toContain("zona_horaria");
    }
    const buscar = EXPLORE_TOOL_SPECS.find((s) => s.name === "buscar_movimientos")!;
    const limite = (buscar.parameters.properties as Record<string, { maximum: number }>).limite;
    expect(limite.maximum).toBe(EXPLORE_MAX_MOVEMENTS);
    expect(EXPLORE_MAX_MOVEMENTS).toBe(50);
  });

  it("las definiciones de Chat Completions llevan la descripción del conector", () => {
    const defs = openAIToolDefinitions() as { type: string; function: { name: string; description: string } }[];
    expect(defs.every((d) => d.type === "function")).toBe(true);
    for (const d of defs) expect(d.function.description).toBe(TOOL_CORES.find((c) => c.name === d.function.name)!.description);
  });

  it("los argumentos: solo los declarados, `limite` acotado y la zona del teléfono pisa la del modelo", () => {
    const buscar = EXPLORE_TOOL_SPECS.find((s) => s.name === "buscar_movimientos")!;
    expect(exploreArgs(buscar, { limite: 500, zona_horaria: "Asia/Tokyo", hackeo: 1, texto: "uber" }, "America/Lima")).toEqual({
      limite: 50,
      texto: "uber",
      zona_horaria: "America/Lima",
    });
    expect(exploreArgs(buscar, { limite: 0 }, "UTC").limite).toBe(1);
    expect(exploreArgs(buscar, {}, "UTC").limite).toBe(20);
    expect(exploreArgs(buscar, "no es un objeto", "UTC")).toEqual({ limite: 20, zona_horaria: "UTC" });
    const cuentas = EXPLORE_TOOL_SPECS.find((s) => s.name === "listar_cuentas")!;
    expect(exploreArgs(cuentas, { incluir_archivadas: true, zona_horaria: "X" }, "UTC")).toEqual({ incluir_archivadas: true });
  });

  it("valida lo que en el conector valida zod: obligatorios, enum, enteros con rango, longitud y fecha", () => {
    const resumen = EXPLORE_TOOL_SPECS.find((s) => s.name === "resumen_periodo")!;
    const buscar = EXPLORE_TOOL_SPECS.find((s) => s.name === "buscar_movimientos")!;
    const cuentas = EXPLORE_TOOL_SPECS.find((s) => s.name === "listar_cuentas")!;
    expect(() => exploreArgs(resumen, {}, "UTC")).toThrow(/Falta periodo/);
    expect(() => exploreArgs(resumen, { periodo: "anio" }, "UTC")).toThrow(/periodo/);
    expect(() => exploreArgs(resumen, { periodo: "mes_actual", top: -3 }, "UTC")).toThrow(/top/);
    expect(() => exploreArgs(resumen, { periodo: "mes_actual", top: 1e9 }, "UTC")).toThrow(/top/);
    expect(() => exploreArgs(resumen, { periodo: "mes_actual", top: 2.5 }, "UTC")).toThrow(/entero/);
    expect(() => exploreArgs(buscar, { texto: "x".repeat(81) }, "UTC")).toThrow(/texto/);
    expect(() => exploreArgs(buscar, { desde: "ayer" }, "UTC")).toThrow(/desde/);
    expect(() => exploreArgs(cuentas, { incluir_archivadas: "sí" }, "UTC")).toThrow(/incluir_archivadas/);
    expect(exploreArgs(resumen, { periodo: "mes_actual", top: 5 }, "UTC")).toEqual({ periodo: "mes_actual", top: 5, zona_horaria: "UTC" });
  });

  it("un resultado con demasiados movimientos se recorta quitando movimientos, y lo dice", () => {
    const result = { movimientos: Array.from({ length: 50 }, (_, i) => ({ id: i, nota: "n".repeat(400) })), siguiente_cursor: "abc", avisos: ["previo"] };
    const text = fitResult(result, 8_000);
    expect(text.length).toBeLessThanOrEqual(8_000);
    const parsed = JSON.parse(text);
    expect(parsed.movimientos.length).toBeLessThan(50);
    expect(parsed.siguiente_cursor).toBeNull();
    expect(parsed.avisos[0]).toBe("previo");
    expect(parsed.avisos.at(-1)).toMatch(new RegExp(`Solo caben ${parsed.movimientos.length} de 50`));
    expect(fitResult({ a: 1 }, 100)).toBe('{"a":1}');
  });

  it("zona horaria: la del teléfono si existe; si falta o es inventada, UTC y se anota", () => {
    expect(exploreTimeZone("America/Lima")).toEqual({ timeZone: "America/Lima", assumed: false });
    expect(exploreTimeZone("Marte/Olympus")).toEqual({ timeZone: "UTC", assumed: true });
    expect(exploreTimeZone(undefined)).toEqual({ timeZone: "UTC", assumed: true });
  });
});

// ------------------------------------------------------------------ 2 · lista cerrada

describe("explore · lista cerrada de lecturas", () => {
  const ok = (m: string, path: string, origin = SB) => isAllowedExploreRead(SB_ENV, m, new URL(`${origin}${path}`));

  it("GET a las tablas de las herramientas, sí", () => {
    for (const t of EXPLORE_TABLES) expect(ok("GET", `/rest/v1/${t}?select=*`), t).toBe(true);
  });

  it("escribir, un RPC, otra tabla, auth u otro origen: no", () => {
    expect(ok("POST", "/rest/v1/tx_items")).toBe(false);
    expect(ok("PATCH", "/rest/v1/accounts")).toBe(false);
    expect(ok("DELETE", "/rest/v1/accounts")).toBe(false);
    expect(ok("GET", "/rest/v1/rpc/apply_delta")).toBe(false);
    expect(ok("POST", "/rest/v1/rpc/apply_delta")).toBe(false);
    expect(ok("GET", "/rest/v1/group_expenses")).toBe(false);
    expect(ok("GET", "/rest/v1/profiles")).toBe(false);
    expect(ok("GET", "/auth/v1/user")).toBe(false);
    expect(ok("GET", "/rest/v1/accounts", "https://otro.supabase.co")).toBe(false);
  });

  it("el lector la aplica de verdad: una tabla fuera de la lista lanza sin tocar la red", async () => {
    const sent: Sent[] = [];
    const reader = toolContext(sent).reader;
    await expect(reader.one("profiles", [["select", "*"]], 1)).rejects.toThrow(/no permitida/);
    expect(sent).toHaveLength(0);
  });
});

// ------------------------------------------------------------------ 3 · el prompt

describe("explore · prompt", () => {
  it("la ampliación va justo detrás del primer mensaje de sistema, sin tocar los demás", () => {
    const out = withExploreAddendum(APP_BODY.messages);
    expect(out).toHaveLength(3);
    expect(out[0]).toBe(APP_BODY.messages[0]);
    expect(out[1]).toEqual({ role: "system", content: EXPLORE_ADDENDUM });
    expect(out[2]).toBe(APP_BODY.messages[1]);
  });

  it("sin mensaje de sistema, va delante", () => {
    const out = withExploreAddendum([{ role: "user", content: "hola" }]);
    expect(out[0].content).toBe(EXPLORE_ADDENDUM);
  });

  it("no cita vocabulario español entre comillas españolas (el modelo lo copiaría en otros idiomas)", () => {
    expect(EXPLORE_ADDENDUM).not.toMatch(/[«»]/);
  });
});

// ------------------------------------------------------------------ 4 · el bucle

const ROUTE = ROUTES["chat.explore"] as ManagedRoute;

function scriptedOpenAI(script: (n: number, payload: Record<string, unknown>) => Response) {
  const payloads: Record<string, unknown>[] = [];
  const fetchFn = vi.fn(async (_url: string, init: RequestInit) => {
    const payload = JSON.parse(String(init.body)) as Record<string, unknown>;
    payloads.push(payload);
    return script(payloads.length, payload);
  });
  return { payloads, fetchFn };
}

describe("explore · bucle", () => {
  it("la fila es la de chat.answer: mismo modelo y parámetros (la sesión no cambia de modelo)", () => {
    const answer = ROUTES["chat.answer"] as ManagedRoute;
    expect(ROUTE.provider).toBe(answer.provider);
    expect(ROUTE.model).toBe(answer.model);
    expect(ROUTE.params).toEqual(answer.params);
  });

  it("sin herramientas pedidas: una llamada, con las herramientas ofrecidas y la ampliación", async () => {
    const sent: Sent[] = [];
    const { payloads, fetchFn } = scriptedOpenAI(() => completion({ content: "Tienes **S/1250.50**." }));
    const r = await runExplore(APP_BODY, ROUTE, { openaiKey: "sk", fetch: fetchFn, toolContext: toolContext(sent), timeZone: "America/Lima" });
    expect(r.status).toBe(200);
    expect(JSON.parse(r.body).choices[0].message.content).toBe("Tienes **S/1250.50**.");
    expect(payloads).toHaveLength(1);
    expect(payloads[0].model).toBe("gpt-6-luna");
    expect(payloads[0].tool_choice).toBe("auto");
    expect((payloads[0].tools as unknown[]).length).toBe(6);
    expect((payloads[0].messages as { content: string }[])[1].content).toBe(EXPLORE_ADDENDUM);
    expect(r.stats).toEqual({ rounds: 0, tools: [], resultChars: 0, forcedFinal: false, toolErrors: 0, fellBack: false });
    expect(sent).toHaveLength(0);
  });

  it("con una herramienta: la ejecuta contra las tablas y le devuelve el resultado al modelo", async () => {
    const sent: Sent[] = [];
    const { payloads, fetchFn } = scriptedOpenAI((n) =>
      n === 1 ? completion({ content: null, tool_calls: [toolCall("call_1", "listar_cuentas")] }) : completion({ content: "Tienes S/1250.50." }),
    );
    const r = await runExplore(APP_BODY, ROUTE, { openaiKey: "sk", fetch: fetchFn, toolContext: toolContext(sent), timeZone: "America/Lima" });
    expect(r.status).toBe(200);
    expect(payloads).toHaveLength(2);
    const msgs = payloads[1].messages as Record<string, unknown>[];
    expect(msgs.at(-2)).toMatchObject({ role: "assistant", tool_calls: [{ id: "call_1" }] });
    const toolMsg = msgs.at(-1) as { role: string; tool_call_id: string; content: string };
    expect(toolMsg.role).toBe("tool");
    expect(toolMsg.tool_call_id).toBe("call_1");
    const result = JSON.parse(toolMsg.content);
    expect(result.cuentas[0].nombre).toBe("Cuenta sueldo");
    expect(result.cuentas[0].saldo).toBe(1250.5);
    expect(r.stats.rounds).toBe(1);
    expect(r.stats.tools).toEqual(["listar_cuentas"]);
    expect(r.stats.resultChars).toBe(toolMsg.content.length);
    // Tokens sumados de las dos llamadas.
    expect(r.usage).toMatchObject({ inputTokens: 200, outputTokens: 20 });
    // Solo GET, con el JWT del usuario y la clave pública.
    expect(sent.length).toBeGreaterThan(0);
    for (const s of sent) {
      expect(s.method).toBe("GET");
      expect(s.headers.get("authorization")).toBe("Bearer jwt-usuario");
      expect(s.headers.get("apikey")).toBe("anon-publica");
    }
  });

  it("si el modelo no para de pedir, a la ronda máxima la última llamada sale sin herramientas", async () => {
    const sent: Sent[] = [];
    let i = 0;
    const { payloads, fetchFn } = scriptedOpenAI((_n, p) =>
      p.tool_choice === "none" ? completion({ content: "Con lo que tengo: …" }) : completion({ content: null, tool_calls: [toolCall(`c${++i}`, "listar_categorias")] }),
    );
    const limits: ExploreLimits = { ...EXPLORE_LIMITS, maxRounds: 2, maxToolCalls: 10 };
    const r = await runExplore(APP_BODY, ROUTE, { openaiKey: "sk", fetch: fetchFn, toolContext: toolContext(sent), timeZone: "UTC", limits });
    expect(payloads.map((p) => p.tool_choice)).toEqual(["auto", "auto", "none"]);
    // Con historial de herramientas, `tools` sigue en la petición (OpenAI lo exige).
    expect(payloads[2].tools).toBeDefined();
    expect(r.stats).toMatchObject({ rounds: 2, forcedFinal: true });
    expect(JSON.parse(r.body).choices[0].message.content).toBe("Con lo que tengo: …");
  });

  it("los defaults: 3 rondas, 4 herramientas, 16 000 caracteres (50 movimientos medidos: 13 400), 12 s y 6 s por herramienta", () => {
    expect(EXPLORE_LIMITS).toEqual({ maxRounds: 3, maxToolCalls: 4, maxResultChars: 16_000, softDeadlineMs: 12_000, toolTimeoutMs: 6_000 });
  });

  it("más llamadas en paralelo que el tope: las de más reciben su respuesta de error, ninguna queda sin contestar", async () => {
    const sent: Sent[] = [];
    const calls = ["a", "b", "c"].map((id) => toolCall(id, "listar_categorias"));
    const { payloads, fetchFn } = scriptedOpenAI((n) => (n === 1 ? completion({ content: null, tool_calls: calls }) : completion({ content: "ok" })));
    const limits: ExploreLimits = { ...EXPLORE_LIMITS, maxToolCalls: 2 };
    const r = await runExplore(APP_BODY, ROUTE, { openaiKey: "sk", fetch: fetchFn, toolContext: toolContext(sent), timeZone: "UTC", limits });
    const toolMsgs = (payloads[1].messages as { role: string; tool_call_id?: string; content: string }[]).filter((m) => m.role === "tool");
    expect(toolMsgs.map((m) => m.tool_call_id)).toEqual(["a", "b", "c"]);
    expect(JSON.parse(toolMsgs[2].content).error).toMatch(/número de consultas/);
    expect(r.stats.tools).toEqual(["listar_categorias", "listar_categorias"]);
    // Agotado el tope de herramientas, la siguiente llamada ya no ofrece pedir más.
    expect(payloads[1].tool_choice).toBe("none");
  });

  it("herramienta desconocida, argumentos rotos o una fecha mal escrita: error para el modelo, y el bucle sigue", async () => {
    const sent: Sent[] = [];
    const calls = [
      toolCall("x1", "borrar_cuenta"),
      toolCall("x2", "listar_cuentas", "{no es json"),
      toolCall("x3", "buscar_movimientos", { desde: "ayer" }),
    ];
    const { payloads, fetchFn } = scriptedOpenAI((n) => (n === 1 ? completion({ content: null, tool_calls: calls }) : completion({ content: "ok" })));
    const r = await runExplore(APP_BODY, ROUTE, { openaiKey: "sk", fetch: fetchFn, toolContext: toolContext(sent), timeZone: "UTC" });
    expect(r.status).toBe(200);
    const toolMsgs = (payloads[1].messages as { role: string; content: string }[]).filter((m) => m.role === "tool");
    expect(toolMsgs.map((m) => typeof JSON.parse(m.content).error)).toEqual(["string", "string", "string"]);
    expect(JSON.parse(toolMsgs[2].content).error).toMatch(/desde/);
    expect(r.stats.toolErrors).toBe(3);
  });

  it("un resultado más largo que el tope llega recortado y lo dice", async () => {
    const sent: Sent[] = [];
    const { payloads, fetchFn } = scriptedOpenAI((n) =>
      n === 1 ? completion({ content: null, tool_calls: [toolCall("c1", "listar_cuentas")] }) : completion({ content: "ok" }),
    );
    const limits: ExploreLimits = { ...EXPLORE_LIMITS, maxResultChars: 40 };
    await runExplore(APP_BODY, ROUTE, { openaiKey: "sk", fetch: fetchFn, toolContext: toolContext(sent), timeZone: "UTC", limits });
    const toolMsg = (payloads[1].messages as { role: string; content: string }[]).find((m) => m.role === "tool")!;
    expect(toolMsg.content.startsWith(toolMsg.content.slice(0, 40))).toBe(true);
    expect(toolMsg.content).toMatch(/recortado/);
  });

  it("pasado el plazo blando no empieza otra ronda con herramientas", async () => {
    const sent: Sent[] = [];
    let t = 0;
    const { payloads, fetchFn } = scriptedOpenAI((n) => {
      t += 16_000;
      return n === 1 ? completion({ content: null, tool_calls: [toolCall("c1", "listar_categorias")] }) : completion({ content: "ok" });
    });
    const r = await runExplore(APP_BODY, ROUTE, { openaiKey: "sk", fetch: fetchFn, toolContext: toolContext(sent), timeZone: "UTC", clock: () => t });
    expect(payloads.map((p) => p.tool_choice)).toEqual(["auto", "none"]);
    expect(r.stats.forcedFinal).toBe(true);
  });

  it("un fallo tras una ronda con herramientas: repite UNA vez la pregunta de la app sin herramientas (como chat.answer)", async () => {
    const sent: Sent[] = [];
    const { payloads, fetchFn } = scriptedOpenAI((n) =>
      n === 1
        ? completion({ content: null, tool_calls: [toolCall("c1", "listar_categorias")] })
        : n === 2
          ? new Response('{"error":{"type":"invalid_request_error","code":"context_length_exceeded"}}', { status: 400 })
          : completion({ content: "con el resumen" }),
    );
    const r = await runExplore(APP_BODY, ROUTE, { openaiKey: "sk", fetch: fetchFn, toolContext: toolContext(sent), timeZone: "UTC" });
    expect(r.status).toBe(200);
    expect(JSON.parse(r.body).choices[0].message.content).toBe("con el resumen");
    expect(payloads).toHaveLength(3);
    expect(payloads[2].tools).toBeUndefined();
    expect(payloads[2].messages).toEqual(APP_BODY.messages);
    expect(r.stats.fellBack).toBe(true);
  });

  it("si también falla la repetición, devuelve ese error (y no lo intenta otra vez)", async () => {
    const sent: Sent[] = [];
    const { payloads, fetchFn } = scriptedOpenAI((n) =>
      n === 1 ? completion({ content: null, tool_calls: [toolCall("c1", "listar_categorias")] }) : new Response('{"error":{"type":"server_error"}}', { status: 500 }),
    );
    const r = await runExplore(APP_BODY, ROUTE, { openaiKey: "sk", fetch: fetchFn, toolContext: toolContext(sent), timeZone: "UTC" });
    expect(r.status).toBe(500);
    expect(payloads).toHaveLength(3);
  });

  it("un fallo en la primera llamada es el de siempre: no se repite", async () => {
    const sent: Sent[] = [];
    const { payloads, fetchFn } = scriptedOpenAI(() => new Response('{"error":{"type":"server_error"}}', { status: 500 }));
    const r = await runExplore(APP_BODY, ROUTE, { openaiKey: "sk", fetch: fetchFn, toolContext: toolContext(sent), timeZone: "UTC" });
    expect(r.status).toBe(500);
    expect(payloads).toHaveLength(1);
    expect(r.stats.fellBack).toBe(false);
  });

  it("las herramientas de una ronda corren en paralelo", async () => {
    let inFlight = 0;
    let maxInFlight = 0;
    const slow: ToolContext = {
      ...toolContext([]),
      reader: exploreReader(SB_ENV, "jwt", async (input, init) => {
        inFlight++;
        maxInFlight = Math.max(maxInFlight, inFlight);
        await new Promise((r) => setTimeout(r, 15));
        inFlight--;
        return postgrest(new URL(String(input)), [], init);
      }),
    };
    const calls = [toolCall("a", "listar_categorias"), toolCall("b", "listar_cuentas")];
    const { fetchFn } = scriptedOpenAI((n) => (n === 1 ? completion({ content: null, tool_calls: calls }) : completion({ content: "ok" })));
    await runExplore(APP_BODY, ROUTE, { openaiKey: "sk", fetch: fetchFn, toolContext: slow, timeZone: "UTC" });
    // Cada herramienta ya lee varias tablas a la vez; lo que se mide es que la segunda no espera a la primera.
    expect(maxInFlight).toBeGreaterThan(4);
  });

  it("una herramienta que tarda más que su tope devuelve un error al modelo, sin colgar la pregunta", async () => {
    const hung: ToolContext = { ...toolContext([]), reader: exploreReader(SB_ENV, "jwt", () => new Promise<Response>(() => {})) };
    const r = await runExploreTool(toolCall("c1", "listar_cuentas"), { openaiKey: "sk", toolContext: hung, timeZone: "UTC" }, 16_000, 20);
    expect(r.ok).toBe(false);
    expect(JSON.parse(r.content).error).toMatch(/tardó demasiado/);
  });

  it("un nombre de herramienta inventado no llega al log", async () => {
    const sent: Sent[] = [];
    const { fetchFn } = scriptedOpenAI((n) =>
      n === 1 ? completion({ content: null, tool_calls: [toolCall("c1", "x".repeat(300))] }) : completion({ content: "ok" }),
    );
    const r = await runExplore(APP_BODY, ROUTE, { openaiKey: "sk", fetch: fetchFn, toolContext: toolContext(sent), timeZone: "UTC" });
    expect(r.stats.tools).toEqual(["?"]);
  });

  it("sin clave de OpenAI: 503 sin llamar a nadie", async () => {
    const sent: Sent[] = [];
    const { fetchFn } = scriptedOpenAI(() => completion({ content: "x" }));
    const r = await runExplore(APP_BODY, ROUTE, { openaiKey: undefined, fetch: fetchFn, toolContext: toolContext(sent), timeZone: "UTC" });
    expect(r.status).toBe(503);
    expect(fetchFn).not.toHaveBeenCalled();
  });
});

// ------------------------------------------------------------------ 5 · el handler

const SECRET = "jwt-secret-unit-explore";
let checks: CheckRequest[];
let openaiPayloads: Record<string, unknown>[];
let supabaseSent: Sent[];
let openaiScript: (n: number, payload: Record<string, unknown>) => Response;
let logs: string[];

function makeEnv(percent: string | undefined): Env {
  const stores = new Map<string, Parameters<typeof applyCheck>[0]>();
  let now = Date.parse("2026-10-18T15:00:00Z");
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "enforce",
    JWT_SIGNING_SECRET: SECRET,
    OPENAI_API_KEY: "sk-unit-openai",
    SUPABASE_URL: SB,
    SUPABASE_ANON_KEY: "anon-publica",
    ...(percent === undefined ? {} : { AI_CLOUD_EXPLORE_ROLLOUT_PERCENT: percent }),
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
          now += 61_000;
          return Response.json(applyCheck(stored, req, now));
        },
      }),
    },
  } as unknown as Env;
}

beforeEach(() => {
  checks = [];
  openaiPayloads = [];
  supabaseSent = [];
  logs = [];
  openaiScript = () => completion({ content: "respuesta" });
  vi.spyOn(console, "log").mockImplementation((...args: unknown[]) => {
    logs.push(args.map(String).join(" "));
  });
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown, init?: RequestInit) => {
      const url = new URL(typeof input === "string" ? input : (input as Request).url);
      if (url.origin === SB) return postgrest(url, supabaseSent, init);
      const raw = init?.body instanceof Uint8Array ? new TextDecoder().decode(init.body) : String(init?.body ?? "{}");
      const payload = JSON.parse(raw) as Record<string, unknown>;
      openaiPayloads.push(payload);
      return openaiScript(openaiPayloads.length, payload);
    }),
  );
});

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

async function ask(task: string, env: Env, extra: Record<string, string> = {}): Promise<Response> {
  const { token } = await issueSessionToken(env, { keyId: "unit-device-explore", tier: "pro" });
  return app.fetch(
    new Request("https://gw.local/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", "X-Yala-Task": task, ...extra },
      body: JSON.stringify(APP_BODY),
    }),
    env,
    NOOP_CTX,
  );
}

const USER_JWT = jwtExpiringIn(3600);
const CLOUD_HEADERS = { "X-Yala-User-Token": USER_JWT, "X-Yala-Time-Zone": "America/Lima" };

function routeLog(): Record<string, unknown> {
  const line = logs.find((l) => l.includes('"evt":"ai_route"'));
  return line ? (JSON.parse(line) as Record<string, unknown>) : {};
}

describe("explore · handler", () => {
  it("flag a 0 (el estado de los dos entornos): chat.explore sale EXACTAMENTE como chat.answer", async () => {
    const r1 = await ask("chat.explore", makeEnv("0"), CLOUD_HEADERS);
    expect(r1.status).toBe(200);
    const explorePayload = openaiPayloads[0];
    expect(routeLog().explore).toBe("off");
    logs = [];
    const r2 = await ask("chat.answer", makeEnv("0"));
    expect(r2.status).toBe(200);
    expect(explorePayload).toEqual(openaiPayloads[1]);
    expect(explorePayload.tools).toBeUndefined();
    expect(supabaseSent).toHaveLength(0);
  });

  it("flag ausente: igual que a 0", async () => {
    await ask("chat.explore", makeEnv(undefined), CLOUD_HEADERS);
    expect(openaiPayloads[0].tools).toBeUndefined();
    expect(routeLog().explore).toBe("off");
  });

  it("flag encendido sin JWT del usuario, o con uno que no verifica: sin herramientas, y responde", async () => {
    const r = await ask("chat.explore", makeEnv("100"), { "X-Yala-Time-Zone": "America/Lima" });
    expect(r.status).toBe(200);
    expect(openaiPayloads[0].tools).toBeUndefined();
    expect(routeLog().explore).toBe("no_user");
    logs = [];
    await ask("chat.explore", makeEnv("100"), { ...CLOUD_HEADERS, "X-Yala-User-Token": "jwt-caducado" });
    expect(openaiPayloads[1].tools).toBeUndefined();
    expect(routeLog().explore).toBe("no_user");
  });

  it("flag encendido con usuario: herramientas, lee sus tablas y gasta UN uso de la cuota chat", async () => {
    openaiScript = (n) => (n === 1 ? completion({ content: null, tool_calls: [toolCall("c1", "listar_cuentas")] }) : completion({ content: "S/1250.50" }));
    const r = await ask("chat.explore", makeEnv("100"), CLOUD_HEADERS);
    expect(r.status).toBe(200);
    expect(JSON.parse(await r.text()).choices[0].message.content).toBe("S/1250.50");
    expect(openaiPayloads).toHaveLength(2);
    expect(openaiPayloads[0].tools).toBeDefined();
    expect(checks).toHaveLength(1);
    expect(checks[0].category).toBe("chat");
    expect(supabaseSent.length).toBeGreaterThan(0);
    expect(supabaseSent.every((s) => s.method === "GET" && s.headers.get("authorization") === `Bearer ${USER_JWT}`)).toBe(true);
    const log = routeLog();
    expect(log).toMatchObject({ task: "chat.explore", explore: "tools", rounds: 1, tools: ["listar_cuentas"], in: 200, out: 20 });
    // El log no lleva nada del usuario: ni la pregunta ni lo que devolvió la herramienta.
    expect(JSON.stringify(log)).not.toContain("Cuenta sueldo");
    expect(JSON.stringify(log)).not.toContain("cuánto");
  });

  it("un JWT que caduca en menos de un minuto: sin herramientas (no se rompe a mitad de la pregunta)", async () => {
    await ask("chat.explore", makeEnv("100"), { ...CLOUD_HEADERS, "X-Yala-User-Token": jwtExpiringIn(30) });
    expect(openaiPayloads[0].tools).toBeUndefined();
    expect(routeLog().explore).toBe("no_user");
    expect(EXPLORE_MIN_TOKEN_LIFE_MS).toBe(60_000);
    expect(expiresWithin(jwtExpiringIn(120), new Date(), 60_000)).toBe(false);
    expect(expiresWithin("no-es-un-jwt", new Date(), 60_000)).toBe(true);
  });

  it("chat.answer nunca lleva herramientas, aunque el flag esté encendido y venga el JWT (modo privado intacto)", async () => {
    await ask("chat.answer", makeEnv("100"), CLOUD_HEADERS);
    expect(openaiPayloads[0].tools).toBeUndefined();
    expect(supabaseSent).toHaveLength(0);
    expect(routeLog().explore).toBeUndefined();
  });

  it("un fallo del proveedor en el camino ampliado devuelve el uso", async () => {
    openaiScript = () => new Response('{"error":{"type":"server_error"}}', { status: 503, headers: { "content-type": "application/json" } });
    const r = await ask("chat.explore", makeEnv("100"), CLOUD_HEADERS);
    expect(r.status).toBe(503);
    expect(routeLog().quota).toBe("refunded");
  });
});

// ------------------------------------------------------------------ 6 · sin dependencias

describe("explore · lo que el gateway importa del conector no tiene dependencias", () => {
  /** Imports de un fichero que no son relativos (paquetes). `import type` también cuenta: tsc los resuelve. */
  function packageImports(path: string): string[] {
    const src = readFileSync(new URL(path, import.meta.url), "utf8");
    return [...src.matchAll(/from\s+"([^"]+)"/g)].map((m) => m[1]).filter((s) => !s.startsWith("."));
  }

  it("toolCore, data, egress, supabaseEnv y logic/*", () => {
    const files = ["../../mcp/src/toolCore.ts", "../../mcp/src/data.ts", "../../mcp/src/egress.ts", "../../mcp/src/supabaseEnv.ts"];
    const logicDir = new URL("../../mcp/src/logic/", import.meta.url);
    for (const f of readdirSync(logicDir)) if (f.endsWith(".ts")) files.push(`../../mcp/src/logic/${f}`);
    expect(files.length).toBeGreaterThan(8); // control: el escáner encontró la carpeta
    for (const f of files) expect(packageImports(f), f).toEqual([]);
  });

  it("control positivo: el escáner sí ve un paquete donde lo hay", () => {
    expect(packageImports("../../mcp/src/tools.ts")).toContain("zod");
  });
});
