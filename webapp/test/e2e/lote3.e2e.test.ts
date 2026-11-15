/**
 * Punta a punta del lote 3 contra Yala web en STAGING (`npm run test:e2e`), con los usuarios de prueba A y B y el
 * custodio de los goldens, que es una cuenta «solo Grupos» (`source ~/Secrets/yala-supabase-test/test-users.env`; sin
 * ellos, se salta). Lee Grupos por la entrada interna del gateway; escribe solo un borrador propio de A, que retira.
 *
 * - Grupos: la lista y el detalle responden; en el grupo de prueba «Viaje a Cusco» (lo siembra el lote 3 por las rutas
 *   del iPhone), las cifras calculadas a mano con las reglas de la app.
 * - B no ve un grupo de A del que no es miembro (404), aunque sepa su id.
 * - «Solo Grupos» entra, ve Grupos y lo de la nube completa responde 409.
 * - Un borrador de la web se edita y se descarta; descartado, ya no se puede tocar (409).
 */
import { describe, expect, it } from "vitest";

const BASE = "https://yala-web-staging.misty-surf-6866.workers.dev";

const A = { email: process.env.USER_A_EMAIL, password: process.env.USER_A_PASS };
const B = { email: process.env.USER_B_EMAIL, password: process.env.USER_B_PASS };
const SOLO = { email: process.env.USER_CUSTODIO_EMAIL, password: process.env.USER_CUSTODIO_PASS };
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

interface Lista {
  grupos: { id: string; nombre: string; gastos: number; banda: { estado: string } }[];
}
interface Detalle {
  banda: { estado: string; teDeben: { divisa: string; importe: number }[] };
  deudas: { de: string; a: string; aTi: boolean; importe: number }[];
  saldos: { nombre: string; esTu: boolean; pago: number; leToca: number; neto: number }[];
}

describe.skipIf(!haveUsers)("lote 3 contra staging", () => {
  it("Grupos: lista y detalle; «Viaje a Cusco» da las cifras de la app", async () => {
    const a = await enter(A);
    const res = await a.go("/api/grupos");
    expect(res.status).toBe(200);
    const lista = (await res.json()) as Lista;
    expect(lista.grupos.length).toBeGreaterThan(0);
    for (const g of lista.grupos) expect(["theyOweMe", "iOwe", "mixed", "settled"]).toContain(g.banda.estado);
    const conGastos = lista.grupos.filter((g) => g.gastos > 0).slice(0, 3);
    expect(conGastos.length).toBeGreaterThan(0);
    for (const g of conGastos) expect((await a.go(`/api/grupos/detalle?id=${encodeURIComponent(g.id)}`)).status, g.id).toBe(200);
    const viaje = lista.grupos.find((g) => g.nombre === "Viaje a Cusco");
    if (viaje) {
      // Ana pagó 450 + 96; le tocan 150 + 20 + 67,50 + 32 y el pago confirmado de Beto (50); el de Caro (30) no está
      // confirmado y no cuenta. Con «Menos pagos»: Beto le debe 92 y Caro 134,50.
      const d = (await (await a.go(`/api/grupos/detalle?id=${encodeURIComponent(viaje.id)}`)).json()) as Detalle;
      expect(d.banda).toEqual(expect.objectContaining({ estado: "theyOweMe", teDeben: [{ divisa: "PEN", importe: 226.5 }] }));
      expect(d.deudas.map((x) => [x.de, x.importe])).toEqual([["Beto", 92], ["Caro", 134.5]]);
      expect(d.saldos.find((x) => x.esTu)).toEqual(expect.objectContaining({ pago: 546, leToca: 319.5, neto: 226.5 }));
    }
    await a.go("/auth/logout", { form: {} });
  }, 60_000);

  it("B no ve un grupo de A del que no es miembro", async () => {
    const a = await enter(A);
    const b = await enter(B);
    const deA = ((await (await a.go("/api/grupos")).json()) as Lista).grupos.map((g) => g.id);
    const deB = new Set(((await (await b.go("/api/grupos")).json()) as Lista).grupos.map((g) => g.id));
    const ajeno = deA.find((id) => !deB.has(id));
    expect(ajeno).toBeTruthy();
    expect((await b.go(`/api/grupos/detalle?id=${encodeURIComponent(ajeno!)}`)).status).toBe(404);
    await a.go("/auth/logout", { form: {} });
    await b.go("/auth/logout", { form: {} });
  }, 60_000);

  it.skipIf(!SOLO.email)("«solo Grupos» entra, ve Grupos y lo demás responde 409", async () => {
    const s = await enter(SOLO);
    const me = (await (await s.go("/api/me")).json()) as { soloGrupos: boolean };
    expect(me.soloGrupos).toBe(true);
    expect((await s.go("/api/panel")).status).toBe(409);
    expect((await s.go("/api/registros")).status).toBe(409);
    expect((await s.go("/api/grupos")).status).toBe(200);
    await s.go("/auth/logout", { form: {} });
  }, 60_000);

  it("un borrador de la web se edita y se descarta", async () => {
    const a = await enter(A);
    const fecha = new Date().toISOString().slice(0, 10);
    const sent = await a.go("/api/borradores", { json: { importe: 12.3, divisa: "PEN", descripcion: "e2e lote 3", fecha } });
    expect(sent.status).toBe(201);
    const { id } = (await sent.json()) as { id: string };
    const edit = await a.go("/api/borradores/editar", { json: { id, importe: 15, divisa: "PEN", descripcion: "e2e lote 3 editado", fecha } });
    expect(edit.status).toBe(200);
    const bandeja = (await (await a.go("/api/bandeja")).json()) as { enviados: { id: string; importe: number; descripcion: string }[] };
    expect(bandeja.enviados.find((d) => d.id === id)).toEqual(expect.objectContaining({ importe: 15, descripcion: "e2e lote 3 editado" }));
    expect((await a.go("/api/borradores/descartar", { json: { id } })).status).toBe(200);
    expect((await a.go("/api/borradores/descartar", { json: { id } })).status).toBe(409);
    await a.go("/auth/logout", { form: {} });
  }, 60_000);
});
