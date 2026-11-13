import { describe, expect, it } from "vitest";
import { BASE, FakeLimiter, SB_URL, WEB_CLIENT, makeEnv, world } from "./fakes";
import { configProblems } from "../src/worker/config";
import { isAllowedEgress, TURNSTILE_VERIFY_URL } from "../src/worker/egress";
import type { Env } from "../src/worker/env";

function unsignedJwt(payload: Record<string, unknown>): string {
  const enc = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  return `${enc({ alg: "HS256" })}.${enc(payload)}.firma`;
}

function productionEnv(overrides: Partial<Env> = {}): Env {
  return makeEnv({
    ENVIRONMENT: "production",
    PUBLIC_URL: "https://app.yala.test",
    SUPABASE_ANON_KEY: unsignedJwt({ ref: new URL(SB_URL).hostname.split(".")[0], role: "anon" }),
    TURNSTILE_SITE_KEY: "0x4AAAAAAA-real",
    TURNSTILE_SECRET_KEY: "0x4AAAAAAA-secreto-real",
    RL_AUTH: new FakeLimiter(),
    RL_API: new FakeLimiter(),
    ...overrides,
  });
}

describe("configuración: mal configurado = 503 a todo", () => {
  it("staging de las pruebas es válido; producción completa también", () => {
    expect(configProblems(makeEnv())).toEqual([]);
    expect(configProblems(productionEnv())).toEqual([]);
  });

  it("producción rechaza Supabase de staging, las claves de prueba de Turnstile y la falta de límites", () => {
    const p = configProblems(
      productionEnv({
        SUPABASE_URL: "https://fostjbbwstyuunmmefuk.supabase.co",
        TURNSTILE_SITE_KEY: "1x00000000000000000000AA",
        RL_AUTH: undefined,
      }),
    );
    expect(p).toContain("SUPABASE_URL apunta al proyecto de STAGING");
    expect(p).toContain("Turnstile usa las claves de prueba de Cloudflare");
    expect(p).toContain("faltan los límites de peticiones (RL_AUTH, RL_API)");
  });

  it("un id de cliente PENDIENTE o sin secreto deja el Worker en 503", async () => {
    const w = await world({ SUPABASE_OAUTH_CLIENT_ID: "PENDIENTE", SUPABASE_OAUTH_CLIENT_SECRET: "" });
    const res = await w.call(new Request(`${BASE}/`));
    expect(res.status).toBe(503);
    expect(await res.text()).not.toContain("PENDIENTE");
  });
});

describe("la ruta de contraseña existe solo en staging", () => {
  it("staging: entra con usuario y contraseña (para las pruebas de punta a punta)", async () => {
    const w = await world();
    w.supabase.addUser({ email: "a@yala.test", password: "secreta" });
    const res = await w.browser.request("/auth/password", { form: { email: "a@yala.test", password: "secreta" } });
    expect(res.headers.get("Location")).toBe("/");
    expect((await w.browser.request("/api/me")).status).toBe(200);
  });

  it("producción: la ruta no existe, y la lista cerrada niega el login con contraseña", async () => {
    const env = productionEnv();
    const w = await world(env);
    w.supabase.addUser({ email: "a@yala.test", password: "secreta" });
    const res = await w.browser.request("/auth/password", { form: { email: "a@yala.test", password: "secreta" }, headers: { Origin: env.PUBLIC_URL } });
    expect(res.status).toBe(404);
    expect(isAllowedEgress(env, "POST", new URL(`${SB_URL}/auth/v1/token?grant_type=password`))).toBe(false);
    expect(isAllowedEgress(makeEnv(), "POST", new URL(`${SB_URL}/auth/v1/token?grant_type=password`))).toBe(true);
  });
});

describe("lista cerrada de salidas", () => {
  const env = makeEnv();
  const ok = (method: string, url: string) => isAllowedEgress(env, method, new URL(url));

  it("no escribe en PostgREST ni llama a RPC", () => {
    expect(ok("GET", `${SB_URL}/rest/v1/profiles?select=kind`)).toBe(true);
    expect(ok("POST", `${SB_URL}/rest/v1/tx_items`)).toBe(false);
    expect(ok("PATCH", `${SB_URL}/rest/v1/accounts`)).toBe(false);
    expect(ok("DELETE", `${SB_URL}/rest/v1/accounts`)).toBe(false);
    expect(ok("GET", `${SB_URL}/rest/v1/rpc/delete_account`)).toBe(false);
    expect(ok("POST", `${SB_URL}/rest/v1/rpc/delete_account`)).toBe(false);
  });

  it("no puede cambiar la cuenta ni pedir permisos para otro cliente", () => {
    expect(ok("PUT", `${SB_URL}/auth/v1/user`)).toBe(false);
    expect(ok("POST", `${SB_URL}/auth/v1/factors`)).toBe(false);
    expect(ok("POST", `${SB_URL}/auth/v1/logout?scope=global`)).toBe(false);
    const authorize = (client: string, redirect = `${BASE}/auth/supabase/callback`) =>
      `${SB_URL}/auth/v1/oauth/authorize?` +
      new URLSearchParams({ response_type: "code", client_id: client, redirect_uri: redirect, code_challenge: "x", code_challenge_method: "S256", state: "s" });
    expect(ok("GET", authorize(WEB_CLIENT))).toBe(true);
    expect(ok("GET", authorize("65fb5767-59a5-4f50-b77c-7970e67589c5"))).toBe(false);
    expect(ok("GET", authorize(WEB_CLIENT, "https://malo.test/cb"))).toBe(false);
  });

  it("solo Supabase de su configuración y la verificación de Turnstile", () => {
    expect(ok("POST", TURNSTILE_VERIFY_URL)).toBe(true);
    expect(ok("GET", TURNSTILE_VERIFY_URL)).toBe(false);
    expect(ok("GET", "https://otro.supabase.co/rest/v1/profiles")).toBe(false);
    expect(ok("GET", "https://example.com/")).toBe(false);
    expect(ok("GET", `https://user:pass@${new URL(SB_URL).host}/rest/v1/profiles`)).toBe(false);
  });
});

describe("cabeceras de seguridad en todo, página incluida", () => {
  it("la página: CSP cerrada, sin caché, sin referrer y no incrustable", async () => {
    const w = await world();
    const res = await w.call(new Request(`${BASE}/`));
    expect(res.status).toBe(200);
    const csp = res.headers.get("Content-Security-Policy")!;
    expect(csp).toContain("default-src 'none'");
    expect(csp).toContain("script-src 'self' https://challenges.cloudflare.com");
    expect(csp).toContain("connect-src 'self'");
    expect(csp).toContain("frame-ancestors 'none'");
    expect(res.headers.get("Cache-Control")).toBe("no-store");
    expect(res.headers.get("Referrer-Policy")).toBe("no-referrer");
    expect(res.headers.get("X-Frame-Options")).toBe("DENY");
  });

  it("la API y los errores también; los ficheros con huella sí se pueden guardar", async () => {
    const w = await world();
    const api = await w.call(new Request(`${BASE}/api/me`));
    expect(api.status).toBe(401);
    expect(api.headers.get("Cache-Control")).toBe("no-store");
    expect(api.headers.get("Content-Security-Policy")).toBeTruthy();
    const asset = await w.call(new Request(`${BASE}/assets/index-abc123.js`));
    expect(asset.headers.get("Cache-Control")).toContain("immutable");
  });

  it("/api/config da la clave pública de Turnstile y nada más", async () => {
    const w = await world();
    expect(await (await w.call(new Request(`${BASE}/api/config`))).json()).toEqual({ turnstileSiteKey: "1x00000000000000000000AA", entorno: "staging" });
  });

  it("la API solo atiende GET", async () => {
    const w = await world();
    expect((await w.call(new Request(`${BASE}/api/me`, { method: "POST" }))).status).toBe(405);
  });
});
