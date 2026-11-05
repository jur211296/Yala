/**
 * El endurecimiento para producción: la configuración que falla cerrado (`config.ts`), los límites de peticiones
 * (`ratelimit.ts`) y el login con contraseña que solo existe en staging (`egress.ts`).
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import { configProblems, STAGING_SUPABASE_REF } from "../src/config";
import { isAllowedEgress } from "../src/egress";
import type { Env } from "../src/env";
import { BASE, connect, FakeLimiter, INIT, makeEnv, productionEnv, register, rpc, unsignedJwt, world } from "./helpers";
import { SB_URL, USER_A, USER_B } from "./supabase-fake";

/** La anon key de staging, tal cual está en `wrangler.toml`: el error de copiar y pegar que hay que cazar. */
const STAGING_ANON_KEY = unsignedJwt({ iss: "supabase", ref: STAGING_SUPABASE_REF, role: "anon" });

function prod(overrides: Partial<Env> = {}): Env {
  return makeEnv(productionEnv(overrides));
}

afterEach(() => vi.restoreAllMocks());

describe("configuración: lo bueno pasa", () => {
  it("staging de los tests y producción completa no tienen problemas", () => {
    expect(configProblems(makeEnv())).toEqual([]);
    expect(configProblems(prod())).toEqual([]);
  });

  it("staging no necesita límites; producción sí", () => {
    expect(configProblems(makeEnv({ RL_BROWSER: undefined }))).toEqual([]);
    expect(configProblems(prod({ RL_MCP: undefined }))).toEqual(["faltan los límites de peticiones (RL_BROWSER, RL_OAUTH, RL_MCP)"]);
  });

  it("una barra final en las URLs se tolera", () => {
    expect(configProblems(prod({ PUBLIC_URL: `${BASE}/`, SUPABASE_URL: `${SB_URL}/` }))).toEqual([]);
  });
});

describe("configuración: lo que se rompe al copiar de staging se caza", () => {
  const cases: [string, Partial<Env>, string][] = [
    ["entorno desconocido", { ENVIRONMENT: "prod" }, "ENVIRONMENT no es staging ni production"],
    ["URL pública con ruta", { PUBLIC_URL: `${BASE}/mcp` }, "PUBLIC_URL no es un origen https (sin ruta, query ni fragmento)"],
    ["URL pública http", { PUBLIC_URL: "http://mcp.yala.test" }, "PUBLIC_URL no es un origen https (sin ruta, query ni fragmento)"],
    ["URL pública con query", { PUBLIC_URL: `${BASE}?x=1` }, "PUBLIC_URL no es un origen https (sin ruta, query ni fragmento)"],
    ["URL pública con credenciales", { PUBLIC_URL: "https://u:p@mcp.yala.test" }, "PUBLIC_URL no es un origen https (sin ruta, query ni fragmento)"],
    ["URL pública que no es URL", { PUBLIC_URL: "PENDIENTE" }, "PUBLIC_URL no es un origen https (sin ruta, query ni fragmento)"],
    ["Supabase sin https", { SUPABASE_URL: "http://proyectoyalatest0001.supabase.co" }, "SUPABASE_URL no es un origen https"],
    ["id de cliente pendiente", { SUPABASE_OAUTH_CLIENT_ID: "PENDIENTE-registrar-en-supabase" }, "SUPABASE_OAUTH_CLIENT_ID no es un uuid (¿sigue PENDIENTE?)"],
    ["sin secreto", { SUPABASE_OAUTH_CLIENT_SECRET: "" }, "falta el secreto SUPABASE_OAUTH_CLIENT_SECRET (wrangler secret put)"],
    ["zona inválida", { DEFAULT_TIMEZONE: "Lima" }, "DEFAULT_TIMEZONE no es una zona IANA válida"],
    ["sin KV", { OAUTH_KV: undefined }, "falta el KV OAUTH_KV"],
    ["sin anon key", { SUPABASE_ANON_KEY: "" }, "falta SUPABASE_ANON_KEY"],
  ];
  for (const [name, override, problem] of cases) {
    it(`${name} (en staging y en producción)`, () => {
      expect(configProblems(makeEnv(override))).toContain(problem);
      expect(configProblems(prod(override))).toContain(problem);
    });
  }

  it("producción apuntando al Supabase de staging", () => {
    const p = configProblems(prod({ SUPABASE_URL: `https://${STAGING_SUPABASE_REF}.supabase.co`, SUPABASE_ANON_KEY: STAGING_ANON_KEY }));
    expect(p).toEqual(["SUPABASE_URL apunta al proyecto de STAGING"]);
  });

  it("producción con la anon key de OTRO proyecto (la de staging con la URL de producción)", () => {
    expect(configProblems(prod({ SUPABASE_ANON_KEY: STAGING_ANON_KEY }))).toEqual(["SUPABASE_ANON_KEY no es la anon key del proyecto de SUPABASE_URL"]);
  });

  it("producción con una clave que no es anon (service_role) o que no es un JWT", () => {
    const ref = new URL(SB_URL).hostname.split(".")[0];
    const msg = "SUPABASE_ANON_KEY no es la anon key del proyecto de SUPABASE_URL";
    expect(configProblems(prod({ SUPABASE_ANON_KEY: unsignedJwt({ ref, role: "service_role" }) }))).toEqual([msg]);
    expect(configProblems(prod({ SUPABASE_ANON_KEY: "anon-publica" }))).toEqual([msg]);
  });

  it("producción con Supabase fuera de <ref>.supabase.co, o con una URL pública de staging", () => {
    expect(configProblems(prod({ SUPABASE_URL: "https://auth.yala.test" }))).toEqual(["SUPABASE_URL no es un proyecto <ref>.supabase.co"]);
    expect(configProblems(prod({ PUBLIC_URL: "https://yala-mcp-staging.misty-surf-6866.workers.dev" }))).toEqual(["PUBLIC_URL es de staging"]);
  });
});

describe("un Worker mal configurado no atiende", () => {
  it("503 en TODAS las rutas, sin hablar con Supabase, sin decir qué falla, y con un log una sola vez", async () => {
    const errors = vi.spyOn(console, "error").mockImplementation(() => {});
    const w = await world({ env: productionEnv({ SUPABASE_OAUTH_CLIENT_ID: "PENDIENTE" }) });
    for (const path of ["/", "/.well-known/oauth-authorization-server", "/.well-known/oauth-protected-resource/mcp", "/authorize", "/oauth/consent", "/oauth/register", "/oauth/token", "/mcp"]) {
      const res = await w.call(`${BASE}${path}`, { method: path === "/mcp" || path.startsWith("/oauth/") ? "POST" : "GET" });
      expect(res.status, path).toBe(503);
      const text = await res.text();
      expect(text, path).not.toMatch(/PENDIENTE|SUPABASE/);
    }
    expect(w.supabase.calls).toEqual([]);
    const logs = errors.mock.calls.map((c) => String(c[0])).filter((l) => l.includes("config_invalida"));
    expect(logs).toHaveLength(1);
    expect(JSON.parse(logs[0]!)).toMatchObject({ evento: "config_invalida", entorno: "production" });
  });

  it("producción bien configurada sí atiende, y `/` no dice staging", async () => {
    const w = await world({ env: productionEnv() });
    const res = await w.call(`${BASE}/`);
    expect(res.status).toBe(200);
    const text = await res.text();
    expect(text.startsWith("Yala MCP:")).toBe(true);
    expect(text).not.toMatch(/staging/i);
    const meta = await w.call(`${BASE}/.well-known/oauth-protected-resource/mcp`);
    expect(((await meta.json()) as { resource_name: string }).resource_name).toBe("Yala");
  });
});

describe("límites de peticiones por IP (navegador y OAuth)", () => {
  const ip = (addr: string) => ({ "CF-Connecting-IP": addr });

  it("/oauth/register: corta a esa IP con 429 y deja pasar a otra; la clave es el cubo y la IP", async () => {
    const limiter = new FakeLimiter(2);
    const w = await world({ env: { RL_OAUTH: limiter } });
    const body = JSON.stringify({ client_name: "Claude", redirect_uris: ["http://localhost:1/callback"], token_endpoint_auth_method: "none" });
    const post = (addr: string) => w.call(`${BASE}/oauth/register`, { method: "POST", headers: { ...ip(addr), "Content-Type": "application/json" }, body });
    expect((await post("1.1.1.1")).status).toBe(201);
    expect((await post("1.1.1.1")).status).toBe(201);
    const third = await post("1.1.1.1");
    expect(third.status).toBe(429);
    expect(third.headers.get("Retry-After")).toBe("60");
    expect(((await third.json()) as { error: string }).error).toBe("too_many_requests");
    expect((await post("2.2.2.2")).status).toBe(201);
    expect(limiter.keys).toEqual(["RL_OAUTH:1.1.1.1", "RL_OAUTH:1.1.1.1", "RL_OAUTH:1.1.1.1", "RL_OAUTH:2.2.2.2"]);
    expect(w.kv.store.size).toBe(3);
  });

  it("/oauth/token comparte el cubo de OAuth", async () => {
    const limiter = new FakeLimiter(0);
    const w = await world({ env: { RL_OAUTH: limiter } });
    const res = await w.call(`${BASE}/oauth/token`, { method: "POST", headers: ip("3.3.3.3"), body: "grant_type=refresh_token" });
    expect(res.status).toBe(429);
    expect(limiter.keys).toEqual(["RL_OAUTH:3.3.3.3"]);
  });

  it("las páginas del navegador responden con una página, no con JSON, y no salen a Supabase", async () => {
    const limiter = new FakeLimiter(0);
    const w = await world({ env: { RL_BROWSER: limiter } });
    for (const path of ["/authorize", "/oauth/consent?authorization_id=az_12345678", "/oauth/supabase/callback"]) {
      const res = await w.call(`${BASE}${path}`, { headers: ip("4.4.4.4") });
      expect(res.status, path).toBe(429);
      expect(res.headers.get("Content-Type")).toContain("text/html");
      expect(res.headers.get("Retry-After")).toBe("60");
      expect(res.headers.get("X-Frame-Options")).toBe("DENY");
    }
    expect(limiter.keys.every((k) => k === "RL_BROWSER:4.4.4.4")).toBe(true);
    expect(w.supabase.calls).toEqual([]);
  });

  it("los metadatos y la raíz no cuentan contra ningún cubo", async () => {
    const limiter = new FakeLimiter(0);
    const w = await world({ env: { RL_BROWSER: limiter, RL_OAUTH: limiter } });
    expect((await w.call(`${BASE}/.well-known/oauth-authorization-server`)).status).toBe(200);
    expect((await w.call(`${BASE}/`)).status).toBe(200);
    expect(limiter.keys).toEqual([]);
  });

  it("si el límite falla al consultarse, se deja pasar y se anota", async () => {
    const errors = vi.spyOn(console, "error").mockImplementation(() => {});
    const broken = { limit: async () => { throw new Error("caído"); } };
    const w = await world({ env: { RL_OAUTH: broken } });
    const { res } = await register(w);
    expect(res.status).toBe(201);
    expect(errors.mock.calls.some((c) => String(c[0]).includes("mcp_limite_error"))).toBe(true);
  });
});

describe("límite por USUARIO en /mcp", () => {
  it("corta al usuario que se pasa y no a otro que llega desde la MISMA IP (los servidores de claude.ai)", async () => {
    const limiter = new FakeLimiter(2);
    const w = await world({ env: { RL_MCP: limiter } });
    const a = (await connect(w, USER_A)).tokens.access_token;
    const b = (await connect(w, USER_B)).tokens.access_token;
    const before = w.supabase.calls.length;

    expect((await rpc(w, a, INIT)).status).toBe(200);
    expect((await rpc(w, a, INIT)).status).toBe(200);
    const third = await rpc(w, a, INIT);
    expect(third.status).toBe(429);
    expect(third.headers.get("Retry-After")).toBe("60");
    expect((await rpc(w, b, INIT)).status).toBe(200);
    expect(limiter.keys).toEqual([`RL_MCP:${USER_A.id}`, `RL_MCP:${USER_A.id}`, `RL_MCP:${USER_A.id}`, `RL_MCP:${USER_B.id}`]);
    // Las dos primeras de A y la de B comprueban la sesión en Supabase; la cortada no sale.
    const sessionChecks = w.supabase.calls.slice(before).filter((c) => c.path === "/auth/v1/user");
    expect(sessionChecks).toHaveLength(3);
  });

  it("un token inválido no llega a gastar el cubo de nadie", async () => {
    const limiter = new FakeLimiter(0);
    const w = await world({ env: { RL_MCP: limiter } });
    const res = await rpc(w, `${USER_A.id}:grant:secreto`, INIT);
    expect(res.status).toBe(401);
    expect(limiter.keys).toEqual([]);
  });
});

describe("el login con contraseña, solo en staging (lista de salidas)", () => {
  const url = new URL(`${SB_URL}/auth/v1/token?grant_type=password`);

  it("staging lo deja salir; producción, un entorno raro o sin entorno (el gateway), no", () => {
    expect(isAllowedEgress(makeEnv(), "POST", url)).toBe(true);
    expect(isAllowedEgress(prod(), "POST", url)).toBe(false);
    expect(isAllowedEgress(makeEnv({ ENVIRONMENT: "Staging" }), "POST", url)).toBe(false);
    expect(isAllowedEgress({ SUPABASE_URL: SB_URL, SUPABASE_ANON_KEY: "x" }, "POST", url)).toBe(false);
  });

  it("el resto de salidas no depende del entorno", () => {
    for (const env of [makeEnv(), prod()]) {
      expect(isAllowedEgress(env, "POST", new URL(`${SB_URL}/auth/v1/oauth/token`))).toBe(true);
      expect(isAllowedEgress(env, "GET", new URL(`${SB_URL}/auth/v1/user`))).toBe(true);
      expect(isAllowedEgress(env, "PUT", new URL(`${SB_URL}/auth/v1/user`))).toBe(false);
    }
  });
});
