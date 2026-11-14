/**
 * Punta a punta del lote 1 contra Yala web en STAGING (`npm run test:e2e`), con los usuarios de prueba A y B
 * (`source ~/Secrets/yala-supabase-test/test-users.env`; sin ellos, se salta).
 *
 * - Mirar: Panel, Registros y Bandeja responden con las cifras del núcleo compartido, y el saldo coincide con el que
 *   calcula el conector para la misma cuenta (mismo código, otro Worker).
 * - Apuntar: el borrador llega a la cola común (se ve en «enviados» de la Bandeja). Lo apuntado lleva la descripción
 *   `e2e-lote1-<marca>` para poder borrarlo de la cola de staging al terminar (lo hace quien corre la prueba).
 * - Sesiones: dos navegadores de A; uno cierra al otro, y el iPhone (token de la app) cierra todas.
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
export const MARK = `e2e-lote1-${Date.now().toString(36)}`;

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

describe.skipIf(!haveUsers)("staging · lote 1: mirar", () => {
  it("Panel, Registros, categorías y Bandeja responden para A", async () => {
    const b = await enter(A);
    const panel = await b.go("/api/panel");
    expect(panel.status).toBe(200);
    const p = (await panel.json()) as { cuentas: { cuentas: unknown[]; total: { divisa: string; importe: number } }; mes: { divisa: string }; ultimos: { movimientos: unknown[] } };
    expect(Array.isArray(p.cuentas.cuentas)).toBe(true);
    expect(p.cuentas.total.divisa).toMatch(/^[A-Z]{3}$/);
    expect(Number.isFinite(p.cuentas.total.importe)).toBe(true);
    for (const path of ["/api/registros", "/api/registros?desde=2026-01-01&hasta=2026-12-31", "/api/categorias", "/api/bandeja", "/api/sesiones"]) {
      expect((await b.go(path)).status, path).toBe(200);
    }
    expect((await b.go("/api/registros?desde=ayer")).status).toBe(400);
    await b.go("/auth/logout", { form: {} });
  });

  it("los saldos de A son los mismos que da el núcleo con su token normal (misma cuenta, mismo cálculo)", async () => {
    const b = await enter(A);
    const web = (await (await b.go("/api/panel")).json()) as { cuentas: { cuentas: { id: string; saldo: number }[] } };
    // El conector y el gateway usan el mismo `listar_cuentas`; aquí se compara contra las filas crudas: la suma de cada
    // cuenta en su divisa, sin futuros (lo que hace `computeBalances` en el caso simple).
    const token = await appToken(A);
    const rows = (await (
      await fetch(`${SB}/rest/v1/tx_items?select=account_ref,amount,local_day,date&deleted=is.false&account_ref=not.is.null&limit=20000`, {
        headers: { apikey: ANON, Authorization: `Bearer ${token}` },
      })
    ).json()) as { account_ref: string; amount: number | string; local_day: string | null; date: string | null }[];
    await appLogout(token);
    const today = new Date().toISOString().slice(0, 10);
    const sums = new Map<string, number>();
    let future = 0;
    for (const r of rows) {
      const day = r.local_day ?? r.date?.slice(0, 10) ?? "";
      if (day > today) {
        future++;
        continue;
      }
      sums.set(r.account_ref, (sums.get(r.account_ref) ?? 0) + Number(r.amount));
    }
    if (future === 0) {
      for (const c of web.cuentas.cuentas) expect(c.saldo, c.id).toBeCloseTo(sums.get(c.id) ?? 0, 2);
    }
    await b.go("/auth/logout", { form: {} });
  });
});

describe.skipIf(!haveUsers)("staging · lote 1: apuntar a la cola común", () => {
  it("el borrador de A llega a la cola y se ve como «enviado»; B no lo ve", async () => {
    const a = await enter(A);
    const today = new Date().toISOString().slice(0, 10);
    const res = await a.go("/api/borradores", { json: { tipo: "gasto", importe: 1.23, divisa: "PEN", descripcion: MARK, fecha: today, cuenta: null, subcategoria: null } });
    expect(res.status).toBe(201);
    const bandeja = (await (await a.go("/api/bandeja")).json()) as { enviados: { descripcion: string }[] };
    expect(bandeja.enviados.some((e) => e.descripcion === MARK)).toBe(true);
    const bee = await enter(B);
    const otra = (await (await bee.go("/api/bandeja")).json()) as { enviados: { descripcion: string }[] };
    expect(otra.enviados.some((e) => e.descripcion === MARK)).toBe(false);
    expect((await a.go("/api/borradores", { json: { importe: 0, divisa: "PEN", fecha: today } })).status).toBe(400);
    await a.go("/auth/logout", { form: {} });
    await bee.go("/auth/logout", { form: {} });
  });
});

describe.skipIf(!haveUsers)("staging · lote 1: sesiones", () => {
  it("un navegador cierra al otro, y la pestaña cerrada deja de leer al momento", async () => {
    const mac = await enter(A);
    const win = await enter(A, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0");
    const list = (await (await mac.go("/api/sesiones")).json()) as { sesiones: { id: string; esta: boolean; navegador: string; sistema: string }[] };
    const other = list.sesiones.find((s) => !s.esta && s.navegador === "Edge");
    expect(other?.sistema).toBe("Windows");
    const closed = await mac.go("/api/sesiones/cerrar", { json: { id: other!.id } });
    expect(((await closed.json()) as { cerradas: number }).cerradas).toBe(1);
    expect((await win.go("/api/panel")).status).toBe(401);
    expect((await mac.go("/api/me")).status).toBe(200);
    await mac.go("/auth/logout", { form: {} });
  });

  it("el iPhone (token de la app) ve las sesiones y las cierra todas; la web de solo lectura no puede usar esa puerta", async () => {
    const web1 = await enter(A);
    const web2 = await enter(A);
    const token = await appToken(A);
    try {
      const list = await device("/api/dispositivo/sesiones", token);
      expect(list.status).toBe(200);
      const { sesiones } = (await list.json()) as { sesiones: { esta: boolean }[] };
      expect(sesiones.length).toBeGreaterThanOrEqual(2);
      expect(sesiones.every((s) => !s.esta)).toBe(true);
      const all = await device("/api/dispositivo/sesiones/cerrar-todas", token, {});
      expect(((await all.json()) as { cerradas: number }).cerradas).toBeGreaterThanOrEqual(2);
      expect((await web1.go("/api/panel")).status).toBe(401);
      expect((await web2.go("/api/panel")).status).toBe(401);
      // La sesión de la app sigue viva: solo se cerraron las web.
      const me = await fetch(`${SB}/auth/v1/user`, { headers: { apikey: ANON, Authorization: `Bearer ${token}` } });
      expect(me.status).toBe(200);
      expect((await fetch(`${BASE}/api/dispositivo/sesiones`)).status).toBe(401);
    } finally {
      await appLogout(token);
    }
  });
});
