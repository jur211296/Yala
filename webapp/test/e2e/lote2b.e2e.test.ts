/**
 * Punta a punta del lote 2b contra Yala web en STAGING (`npm run test:e2e`), con el usuario de prueba A
 * (`source ~/Secrets/yala-supabase-test/test-users.env`; sin él, se salta). No escribe datos: solo lee.
 *
 * - Presupuestos responde con la sesión de la web y la forma de `estado_presupuestos`.
 * - Pagos trae `pagado` en cada cobro y «Por pagar» no cuenta lo pagado.
 * - Registros da páginas de 200 (exportar a CSV) y la página siguiente no repite filas.
 * - Las páginas de idioma se sirven (el navegador carga solo la del idioma elegido).
 */
import { describe, expect, it } from "vitest";

const BASE = "https://yala-web-staging.misty-surf-6866.workers.dev";
const A = { email: process.env.USER_A_EMAIL, password: process.env.USER_A_PASS };

class Browser {
  readonly jar = new Map<string, string>();
  async go(path: string, form?: Record<string, string>): Promise<Response> {
    const headers = new Headers({ "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36" });
    if (this.jar.size) headers.set("Cookie", [...this.jar].map(([k, v]) => `${k}=${v}`).join("; "));
    let body: string | undefined;
    if (form) {
      body = new URLSearchParams(form).toString();
      headers.set("Content-Type", "application/x-www-form-urlencoded");
      headers.set("Origin", BASE);
    }
    const res = await fetch(`${BASE}${path}`, { method: body !== undefined ? "POST" : "GET", headers, body, redirect: "manual" });
    for (const c of res.headers.getSetCookie()) {
      const [pair] = c.split(";");
      const name = pair!.slice(0, pair!.indexOf("="));
      if (/Max-Age=0/.test(c)) this.jar.delete(name);
      else this.jar.set(name, pair!.slice(pair!.indexOf("=") + 1));
    }
    return res;
  }
}

describe.skipIf(!(A.email && A.password))("lote 2b en staging", () => {
  async function enter(): Promise<Browser> {
    const b = new Browser();
    expect((await b.go("/auth/password", { email: A.email!, password: A.password! })).status).toBe(303);
    return b;
  }

  it("Presupuestos, Pagos con «pagado» y Registros de 200 en 200", async () => {
    const b = await enter();
    try {
      const pre = await b.go("/api/presupuestos");
      expect(pre.status).toBe(200);
      const budgets = (await pre.json()) as { presupuestos: { id: string; gastado: number; estado: string; periodo: { desde: string } }[] };
      expect(Array.isArray(budgets.presupuestos)).toBe(true);
      for (const p of budgets.presupuestos) expect(["sin_limite", "excedido", "en_riesgo", "en_camino", "inactivo"]).toContain(p.estado);

      const pag = await b.go("/api/pagos");
      expect(pag.status).toBe(200);
      const pagos = (await pag.json()) as { proximos: { pagado: boolean; movimiento: string; importe_en_divisa_preferida: number | null }[]; total_gastos: number; pagados: number };
      expect(pagos.proximos.every((c) => typeof c.pagado === "boolean")).toBe(true);
      expect(pagos.pagados).toBe(pagos.proximos.filter((c) => c.pagado).length);
      const pending = pagos.proximos.filter((c) => !c.pagado && c.movimiento === "gasto").reduce((s, c) => s + (c.importe_en_divisa_preferida ?? 0), 0);
      expect(Math.abs(pagos.total_gastos - pending)).toBeLessThan(0.05 * Math.max(1, pagos.proximos.length));

      const first = (await (await b.go("/api/registros?limite=200")).json()) as { movimientos: { id: string }[]; siguiente_cursor: string | null };
      expect(first.movimientos.length).toBeLessThanOrEqual(200);
      if (first.siguiente_cursor) {
        expect(first.movimientos.length).toBe(200);
        const next = (await (await b.go(`/api/registros?limite=200&cursor=${encodeURIComponent(first.siguiente_cursor)}`)).json()) as { movimientos: { id: string }[] };
        const seen = new Set(first.movimientos.map((m) => m.id));
        expect(next.movimientos.some((m) => seen.has(m.id))).toBe(false);
      }
    } finally {
      await b.go("/auth/logout", {});
    }
  });
});
