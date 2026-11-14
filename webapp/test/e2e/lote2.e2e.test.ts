/**
 * Punta a punta del lote 2 contra Yala web en STAGING (`npm run test:e2e`), con los usuarios de prueba A y B
 * (`source ~/Secrets/yala-supabase-test/test-users.env`; sin ellos, se salta). No escribe datos: solo lee y entra.
 *
 * - Estadísticas y Pagos responden con la sesión de solo lectura; el gasto del Resumen es el total de Distribución.
 * - Entrar con el iPhone (QR): el navegador pide un código, el iPhone de A lo lee y lo aprueba, el navegador entra.
 *   B no puede aprobar un código que leyó A, y otro navegador no recibe la aprobación.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const BASE = "https://yala-web-staging.misty-surf-6866.workers.dev";
const SB = "https://fostjbbwstyuunmmefuk.supabase.co";
const toml = readFileSync(new URL("../../wrangler.toml", import.meta.url), "utf8");
const ANON = /SUPABASE_ANON_KEY = "([^"]+)"/.exec(toml)![1]!;

const A = { email: process.env.USER_A_EMAIL, password: process.env.USER_A_PASS };
const B = { email: process.env.USER_B_EMAIL, password: process.env.USER_B_PASS };
const haveUsers = !!(A.email && A.password && B.email && B.password);

class Browser {
  readonly jar = new Map<string, string>();
  constructor(readonly ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36") {}
  async go(path: string, init: { form?: Record<string, string>; json?: unknown } = {}): Promise<Response> {
    const headers = new Headers({ "User-Agent": this.ua });
    if (this.jar.size) headers.set("Cookie", [...this.jar].map(([k, v]) => `${k}=${v}`).join("; "));
    let body: string | undefined;
    if (init.form) {
      body = new URLSearchParams(init.form).toString();
      headers.set("Content-Type", "application/x-www-form-urlencoded");
      headers.set("Origin", BASE);
    } else if (init.json !== undefined) {
      body = JSON.stringify(init.json);
      headers.set("Content-Type", "application/json");
      headers.set("Origin", BASE);
    }
    const res = await fetch(`${BASE}${path}`, { method: body !== undefined ? "POST" : "GET", headers, body, redirect: "manual" });
    for (const c of res.headers.getSetCookie()) {
      const [pair] = c.split(";");
      const [name, value] = [pair!.slice(0, pair!.indexOf("=")), pair!.slice(pair!.indexOf("=") + 1)];
      if (/Max-Age=0/.test(c)) this.jar.delete(name);
      else this.jar.set(name, value);
    }
    return res;
  }
}

async function enter(user: { email?: string; password?: string }, ua?: string): Promise<Browser> {
  const b = new Browser(ua);
  const res = await b.go("/auth/password", { form: { email: user.email!, password: user.password! } });
  expect(res.status).toBe(303);
  expect(b.jar.has("__Host-yala-web")).toBe(true);
  return b;
}

/** El token de la sesión de la APP (lo que manda el iPhone): login normal de Supabase con contraseña. */
async function appToken(user: { email?: string; password?: string }): Promise<string> {
  const res = await fetch(`${SB}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ email: user.email, password: user.password }),
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { access_token: string }).access_token;
}

async function appLogout(token: string) {
  await fetch(`${SB}/auth/v1/logout?scope=local`, { method: "POST", headers: { apikey: ANON, Authorization: `Bearer ${token}` } });
}

function device(path: string, token: string, body?: unknown) {
  return fetch(`${BASE}${path}`, {
    method: body === undefined ? "GET" : "POST",
    headers: { Authorization: `Bearer ${token}`, ...(body === undefined ? {} : { "Content-Type": "application/json" }) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

/** El token de la clave de PRUEBA de Turnstile (staging): la clave secreta de prueba solo acepta este. */
const TURNSTILE_DUMMY = "XXXX.DUMMY.TOKEN.XXXX";

describe.skipIf(!haveUsers)("lote 2 contra staging", () => {
  it("Estadísticas: las tres pestañas responden y el gasto del Resumen es el total de Distribución", async () => {
    const a = await enter(A);
    for (const periodo of ["mes_actual", "mes_pasado", "anio_actual"]) {
      const res = await a.go(`/api/estadisticas?periodo=${periodo}`);
      expect(res.status, periodo).toBe(200);
      const body = (await res.json()) as { resumen: { gastos: number }; distribucion: { total: number }; tendencias: unknown[] };
      expect(Math.abs(body.resumen.gastos - body.distribucion.total), periodo).toBeLessThanOrEqual(0.01);
      expect(body.tendencias.length).toBe(6);
    }
    expect((await a.go("/api/estadisticas?periodo=siempre")).status).toBe(400);
    await a.go("/auth/logout", { form: {} });
  });

  it("Pagos planificados responde", async () => {
    const a = await enter(A);
    const res = await a.go("/api/pagos");
    expect(res.status).toBe(200);
    const body = (await res.json()) as { proximos: unknown[]; suscripciones: unknown[] };
    expect(Array.isArray(body.proximos) && Array.isArray(body.suscripciones)).toBe(true);
    await a.go("/auth/logout", { form: {} });
  });

  it("entrar con el iPhone: el navegador pide un código, el iPhone de A lo aprueba y el navegador entra; B no puede", async () => {
    const web = new Browser("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15");
    const start = await web.go("/auth/qr/start", { json: { turnstile: TURNSTILE_DUMMY, compartido: true } });
    expect(start.status).toBe(200);
    const { codigo } = (await start.json()) as { codigo: string };
    expect(web.jar.has("__Host-yala-web-qr")).toBe(true);

    const tokenA = await appToken(A);
    const tokenB = await appToken(B);
    try {
      const peek = await device(`/api/dispositivo/vincular?codigo=${codigo}`, tokenA);
      expect(peek.status).toBe(200);
      expect(await peek.json()).toEqual(expect.objectContaining({ navegador: "Safari", sistema: "Mac" }));
      // Leído por A: B ya no puede aprobarlo.
      expect((await device("/api/dispositivo/vincular", tokenB, { codigo })).status).toBe(404);
      // Otro navegador no recibe la aprobación.
      const intruso = new Browser();
      expect((await (await intruso.go("/auth/qr/estado", { json: { codigo } })).json()) as { estado: string }).toEqual({ estado: "caducado" });

      expect((await device("/api/dispositivo/vincular", tokenA, { codigo })).status).toBe(200);
      const st = await web.go("/auth/qr/estado", { json: { codigo } });
      expect(((await st.json()) as { estado: string }).estado).toBe("dentro");
      const me = await web.go("/api/me");
      expect(me.status).toBe(200);
      expect(((await me.json()) as { equipoCompartido: boolean }).equipoCompartido).toBe(true);
      // La sesión del iPhone sigue viva (el Worker la usó para aprobar, no la cerró).
      expect((await device("/api/dispositivo/sesiones", tokenA)).status).toBe(200);
      await web.go("/auth/logout", { form: {} });
      expect((await web.go("/api/me")).status).toBe(401);
    } finally {
      await appLogout(tokenA);
      await appLogout(tokenB);
    }
  });
});
