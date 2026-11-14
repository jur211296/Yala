/**
 * Punta a punta contra Yala web desplegada en STAGING (`npm run test:e2e`). Necesita:
 * - las contraseñas de los usuarios de prueba: `source ~/Secrets/yala-supabase-test/test-users.env`;
 * - para la sonda de escritura, el cliente OAuth de la web: ~/Secrets/yala-web-staging/supabase-oauth-client.json.
 * Sin ellas, los casos que las usan se saltan.
 *
 * Apple y Google no se automatizan (piden una persona): se prueba hasta la puerta de cada uno, y el resto del camino
 * entra por la ruta de contraseña, que solo existe en staging y que comparte con ellos todo lo que pasa después.
 */
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { describe, expect, it } from "vitest";
import type { Env } from "../../src/worker/env";
import { grantReadOnly, logout, passwordLogin } from "../../src/worker/supabase";
import { randomToken, s256 } from "../../src/worker/session";

const BASE = "https://yala-web-staging.misty-surf-6866.workers.dev";
const SB = "https://fostjbbwstyuunmmefuk.supabase.co";
const toml = readFileSync(new URL("../../wrangler.toml", import.meta.url), "utf8");
const ANON = /SUPABASE_ANON_KEY = "([^"]+)"/.exec(toml)![1]!;
const WEB_CLIENT = /SUPABASE_OAUTH_CLIENT_ID = "([^"]+)"/.exec(toml)![1]!;
const CLIENT_FILE = `${homedir()}/Secrets/yala-web-staging/supabase-oauth-client.json`;

const A = { email: process.env.USER_A_EMAIL, password: process.env.USER_A_PASS };
const B = { email: process.env.USER_B_EMAIL, password: process.env.USER_B_PASS };
// El custodio de los goldens de Grupos es una cuenta «solo Grupos» (medido el 2026-11-13; C ya es completa).
const SOLO_GRUPOS = { email: process.env.USER_CUSTODIO_EMAIL, password: process.env.USER_CUSTODIO_PASS };
const haveUsers = !!(A.email && A.password && B.email && B.password);

/** Un navegador mínimo: una cookie por nombre, sin seguir redirecciones. */
class Browser {
  readonly jar = new Map<string, string>();
  async go(path: string, init: { form?: Record<string, string>; origin?: string } = {}): Promise<Response> {
    const headers = new Headers();
    if (this.jar.size) headers.set("Cookie", [...this.jar].map(([k, v]) => `${k}=${v}`).join("; "));
    let body: string | undefined;
    if (init.form) {
      body = new URLSearchParams(init.form).toString();
      headers.set("Content-Type", "application/x-www-form-urlencoded");
      headers.set("Origin", init.origin ?? BASE);
    }
    const res = await fetch(path.startsWith("http") ? path : `${BASE}${path}`, { method: init.form ? "POST" : "GET", headers, body, redirect: "manual" });
    for (const c of res.headers.getSetCookie()) {
      const [pair] = c.split(";");
      const [name, value] = [pair!.slice(0, pair!.indexOf("=")), pair!.slice(pair!.indexOf("=") + 1)];
      if (/Max-Age=0/.test(c)) this.jar.delete(name);
      else this.jar.set(name, value);
    }
    return res;
  }
}

async function enterWithPassword(user: { email?: string; password?: string }) {
  const b = new Browser();
  const res = await b.go("/auth/password", { form: { email: user.email!, password: user.password! } });
  return { b, res };
}

describe("staging · la página y la puerta de Apple y Google", () => {
  it("la página se sirve con la CSP cerrada y sin caché", async () => {
    const res = await fetch(BASE);
    expect(res.status).toBe(200);
    expect(res.headers.get("Content-Security-Policy")).toContain("frame-ancestors 'none'");
    expect(res.headers.get("Cache-Control")).toBe("no-store");
    expect(await res.text()).toContain('<div id="root">');
  });

  for (const [provider, host, client] of [
    ["apple", "appleid.apple.com", "pe.yala.app.web"],
    ["google", "accounts.google.com", "295312853864-af0pqpn7o2rv4r0uss773pk48i9r0obd.apps.googleusercontent.com"],
  ] as const) {
    it(`«Continuar con ${provider}» llega a ${host} con el cliente web y la vuelta de Supabase`, async () => {
      const b = new Browser();
      // Clave de prueba de Turnstile en staging: cualquier respuesta pasa. Con el widget real, este caso se salta.
      const start = await b.go("/auth/start", { form: { provider, "cf-turnstile-response": "XXXX.DUMMY.TOKEN.XXXX" } });
      expect(start.status).toBe(303);
      const toSupabase = new URL(start.headers.get("Location")!);
      expect(toSupabase.origin).toBe(SB);
      expect(toSupabase.searchParams.get("redirect_to")).toBe(`${BASE}/auth/callback`);
      expect(b.jar.has("__Host-yala-web-login")).toBe(true);
      const atSupabase = await fetch(toSupabase, { redirect: "manual" });
      expect(atSupabase.status).toBe(302);
      const toProvider = new URL(atSupabase.headers.get("Location")!);
      expect(toProvider.hostname).toBe(host);
      expect(toProvider.searchParams.get("client_id")).toBe(client);
      expect(toProvider.searchParams.get("redirect_uri")).toBe(`${SB}/auth/v1/callback`);
    });
  }

  it("un formulario de otro sitio no hace entrar a nadie", async () => {
    const b = new Browser();
    const res = await b.go("/auth/start", { form: { provider: "apple", "cf-turnstile-response": "x" }, origin: "https://malo.example" });
    expect(res.status).toBe(403);
  });
});

describe.skipIf(!haveUsers)("staging · entrar, ver la cuenta y salir (usuarios A y B)", () => {
  for (const [label, user] of [["A", A], ["B", B]] as const) {
    it(`${label}: entra, ve su nombre y sale; después no queda sesión`, async () => {
      const { b, res } = await enterWithPassword(user);
      expect(res.status).toBe(303);
      expect(res.headers.get("Location")).toBe("/");
      const cookie = res.headers.getSetCookie().find((c) => c.startsWith("__Host-yala-web="))!;
      expect(cookie).toMatch(/HttpOnly/);
      expect(cookie).toMatch(/Secure/);

      const me = await b.go("/api/me");
      expect(me.status).toBe(200);
      const body = (await me.json()) as { nombre: string; correo: string };
      expect(body.correo).toBe(user.email);
      expect(body.nombre).toBeTruthy();

      const out = await b.go("/auth/logout", { form: {} });
      expect(out.headers.get("Location")).toBe("/?aviso=salida");
      expect((await b.go("/api/me")).status).toBe(401);
    });
  }

  it("contraseña equivocada: no entra", async () => {
    const { b, res } = await enterWithPassword({ email: A.email, password: "no-es-esta" });
    expect(res.headers.get("Location")).toBe("/?aviso=error");
    expect(b.jar.has("__Host-yala-web")).toBe(false);
  });

  it.skipIf(!SOLO_GRUPOS.email)("una cuenta solo de Grupos entra desde el lote 3 (D3) y `me` lo dice", async () => {
    const { b, res } = await enterWithPassword(SOLO_GRUPOS);
    expect(res.headers.get("Location")).toBe("/");
    expect(b.jar.has("__Host-yala-web")).toBe(true);
    expect(((await (await b.go("/api/me")).json()) as { soloGrupos: boolean }).soloGrupos).toBe(true);
    await b.go("/auth/logout", { form: {} });
  });
});

describe.skipIf(!haveUsers || !existsSync(CLIENT_FILE))("staging · la sesión de la web no puede escribir", () => {
  it("con el rol de la web, PostgREST rechaza insertar, cambiar y borrar", async () => {
    const secret = (JSON.parse(readFileSync(CLIENT_FILE, "utf8")) as { client_secret: string }).client_secret;
    const env = {
      ENVIRONMENT: "staging",
      PUBLIC_URL: BASE,
      SUPABASE_URL: SB,
      SUPABASE_ANON_KEY: ANON,
      SUPABASE_OAUTH_CLIENT_ID: WEB_CLIENT,
      SUPABASE_OAUTH_CLIENT_SECRET: secret,
    } as Env;
    const f = (input: Request | string | URL, init?: RequestInit) => fetch(input, init);
    // El mismo camino que el Worker: sesión normal → permiso de la web → sesión de lectura. Se cierra todo al final.
    const normal = (await passwordLogin(env, f, A.email!, A.password!))!;
    expect(normal).not.toBeNull();
    const verifier = randomToken();
    const grant = await grantReadOnly(env, f, normal, { verifier, challenge: await s256(verifier), state: randomToken(16) });
    await logout(env, f, normal.access);
    expect(grant.ok).toBe(true);
    if (!grant.ok) return;
    const access = grant.tokens.access;
    try {
      const claims = JSON.parse(Buffer.from(access.split(".")[1]!, "base64url").toString()) as Record<string, unknown>;
      expect(claims.role).toBe("yala_mcp_reader");
      expect(claims.client_id).toBe(WEB_CLIENT);

      const h = { apikey: ANON, Authorization: `Bearer ${access}`, "Content-Type": "application/json" };
      // Filtros que no casan con ninguna fila: aunque el rol pudiera escribir, la sonda no tocaría datos de A.
      const nadie = "00000000-0000-4000-8000-00000000dead";
      const read = await fetch(`${SB}/rest/v1/accounts?select=sync_id&limit=1`, { headers: h });
      expect(read.status).toBe(200);
      const probes = [
        fetch(`${SB}/rest/v1/tx_items`, { method: "POST", headers: h, body: JSON.stringify({ sync_id: nadie }) }),
        fetch(`${SB}/rest/v1/accounts?sync_id=eq.${nadie}`, { method: "PATCH", headers: h, body: JSON.stringify({ name: "sonda" }) }),
        fetch(`${SB}/rest/v1/accounts?sync_id=eq.${nadie}`, { method: "DELETE", headers: h }),
      ];
      for (const res of await Promise.all(probes)) {
        const text = await res.text();
        expect([401, 403], text).toContain(res.status);
        expect(text).toContain("42501"); // permission denied
      }
    } finally {
      await logout(env, f, access);
    }
  });
});
