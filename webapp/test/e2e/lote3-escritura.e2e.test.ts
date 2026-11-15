/**
 * Punta a punta de la escritura en Grupos (lote 3, opción A) contra Yala web en STAGING (`npm run test:e2e`), con los
 * usuarios de prueba A y B (`source ~/Secrets/yala-supabase-test/test-users.env`; sin ellos, se salta).
 *
 * Escribe en el grupo de prueba «Depa Miraflores» (A y B; lo sembró el lote 3 por las rutas del iPhone):
 * - A añade un gasto de 10,01 entre los dos desde la web; repetir el envío no lo duplica; A y B lo ven con su parte.
 * - B salda 5,01 desde la web: nace confirmado porque lo apunta quien paga.
 * - A crea un enlace de invitación con el formato de la app.
 * - Lo escrito baja por `/groups/pull` (el canal del iPhone) con la forma de un gasto del iPhone.
 * Al terminar, lo borra con el token de la APP de A por `/groups/push` (la web no borra) y revoca la invitación.
 */
import { afterAll, describe, expect, it } from "vitest";

const BASE = "https://yala-web-staging.misty-surf-6866.workers.dev";
const GATEWAY = "https://yala-gateway-staging.misty-surf-6866.workers.dev";
const SUPABASE = "https://fostjbbwstyuunmmefuk.supabase.co";
// Clave pública (anon) de staging, la misma que `webapp/wrangler.toml`.
const ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg";

const A = { email: process.env.USER_A_EMAIL, password: process.env.USER_A_PASS };
const B = { email: process.env.USER_B_EMAIL, password: process.env.USER_B_PASS };
const haveUsers = !!(A.email && A.password && B.email && B.password);

class Browser {
  readonly jar = new Map<string, string>();
  async go(path: string, init: { form?: Record<string, string>; json?: unknown } = {}): Promise<Response> {
    const headers = new Headers({ "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36" });
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

async function enter(user: { email?: string; password?: string }): Promise<Browser> {
  const b = new Browser();
  const res = await b.go("/auth/password", { form: { email: user.email!, password: user.password! } });
  expect(res.status).toBe(303);
  return b;
}

/** El token de la APP (rol `authenticated`), para leer por el canal del iPhone y para limpiar al final. */
async function appToken(user: { email?: string; password?: string }): Promise<string> {
  const res = await fetch(`${SUPABASE}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ email: user.email, password: user.password }),
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { access_token: string }).access_token;
}

interface Detalle {
  id: string;
  puedeEscribir: boolean;
  puedeInvitar: boolean;
  divisa: string | null;
  miembros: { clave: string; nombre: string; esTu: boolean }[];
  gastos: { id: string; descripcion: string; importe: number; tuParte: number | null; pagasteTu: boolean }[];
  pagos: { id: string; importe: number; confirmado: boolean; deTi: boolean }[];
}

const hlcNow = (bump = 0) => `${new Date(Date.now() + bump).toISOString()}-0000-e2e0e2e0e2e0e2e0`;
const written: { entity: string; sync_id: string }[] = [];
let inviteToken: string | null = null;
let groupId = "";

describe.skipIf(!haveUsers)("lote 3 · escribir en Grupos contra staging", () => {
  afterAll(async () => {
    if (!haveUsers || !groupId) return;
    const token = await appToken(A);
    // Las cuotas de los gastos borrados (las de esta corrida y las que dejara una corrida cortada) también se borran:
    // una cuota sin su gasto no suma en ningún lado, pero ensucia el grupo de prueba.
    const pulled = await fetch(`${GATEWAY}/groups/pull?cursors=${encodeURIComponent("{}")}&limit=1000`, { headers: { Authorization: `Bearer ${token}` } });
    const rows = ((await pulled.json()) as { deltas: { entity_type: string; sync_id: string; group_id: string; op: string; fields: Record<string, unknown> }[] }).deltas.filter(
      (d) => d.group_id === groupId,
    );
    const writtenExpenses = new Set(written.filter((w) => w.entity === "split_expenses").map((w) => w.sync_id));
    const aliveExpenses = new Set(rows.filter((d) => d.entity_type === "split_expenses" && d.op !== "tombstone" && !writtenExpenses.has(d.sync_id)).map((d) => d.sync_id));
    for (const s of rows) {
      if (s.entity_type !== "split_shares" || s.op === "tombstone") continue;
      if (!aliveExpenses.has(String(s.fields.expense_id)) && !written.some((w) => w.sync_id === s.sync_id)) written.push({ entity: "split_shares", sync_id: s.sync_id });
    }
    if (written.length > 0) {
      const res = await fetch(`${GATEWAY}/groups/push`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          deltas: written.map((w) => ({ entity_type: w.entity, group_id: groupId, sync_id: w.sync_id, op: "tombstone", hlc: hlcNow(5000), client_mutation_id: crypto.randomUUID() })),
        }),
      });
      const out = (await res.json()) as { results: { status: string }[] };
      expect(out.results.map((r) => r.status).every((s) => s === "applied" || s === "noop")).toBe(true);
    }
    if (inviteToken) {
      const res = await fetch(`${GATEWAY}/groups/rpc/revoke_invite`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify({ p_token: inviteToken }),
      });
      expect(res.ok).toBe(true);
    }
  }, 60_000);

  it("A añade un gasto, B salda, A invita; lo escrito baja por el canal del iPhone", async () => {
    const a = await enter(A);
    const lista = (await (await a.go("/api/grupos")).json()) as { grupos: { id: string; nombre: string }[] };
    const depa = lista.grupos.find((g) => g.nombre === "Depa Miraflores");
    expect(depa, "falta el grupo de prueba «Depa Miraflores» de A y B").toBeTruthy();
    groupId = depa!.id;
    const detalle = async (b: Browser) => (await (await b.go(`/api/grupos/detalle?id=${encodeURIComponent(groupId)}`)).json()) as Detalle;

    const d0 = await detalle(a);
    expect(d0.puedeEscribir).toBe(true);
    const ana = d0.miembros.find((m) => m.esTu)!;
    const beto = d0.miembros.find((m) => !m.esTu)!;
    expect(beto).toBeTruthy();

    // 1 · Gasto de 10,01 entre los dos: el céntimo que sobra va a la primera de la lista (Ana), como en la app.
    const gastoId = crypto.randomUUID();
    const gasto = {
      grupo: groupId,
      id: gastoId,
      descripcion: "e2e web lote 3",
      importe: 10.01,
      divisa: d0.divisa ?? "PEN",
      pagadoPor: ana.clave,
      fecha: new Date().toISOString(),
      participantes: [ana.clave, beto.clave],
    };
    const r1 = await a.go("/api/grupos/gasto", { json: gasto });
    expect(r1.status, await r1.clone().text()).toBe(201);
    written.push({ entity: "split_expenses", sync_id: gastoId });
    const again = await a.go("/api/grupos/gasto", { json: gasto });
    expect(again.status).toBe(200);
    expect(await again.json()).toEqual({ estado: "ya_estaba" });

    const d1 = await detalle(a);
    const mine = d1.gastos.filter((g) => g.id === gastoId);
    expect(mine).toHaveLength(1);
    expect(mine[0]).toEqual(expect.objectContaining({ descripcion: "e2e web lote 3", importe: 10.01, tuParte: 5.01, pagasteTu: true }));

    const b = await enter(B);
    const dB = await detalle(b);
    expect(dB.gastos.find((g) => g.id === gastoId)).toEqual(expect.objectContaining({ tuParte: 5, pagasteTu: false }));

    // 2 · B salda lo suyo: nace confirmado porque lo apunta quien paga.
    const pagoId = crypto.randomUUID();
    const r2 = await b.go("/api/grupos/pago", { json: { grupo: groupId, id: pagoId, de: beto.clave, a: ana.clave, importe: 5, divisa: gasto.divisa, fecha: new Date().toISOString() } });
    expect(r2.status, await r2.clone().text()).toBe(201);
    written.push({ entity: "split_settlements", sync_id: pagoId });
    const pago = (await detalle(a)).pagos.find((p) => p.id === pagoId);
    expect(pago).toEqual(expect.objectContaining({ importe: 5, confirmado: true }));

    // 3 · A invita: enlace con el formato de la app.
    if (d0.puedeInvitar) {
      const r3 = await a.go("/api/grupos/invitar", { json: { grupo: groupId } });
      expect(r3.status).toBe(201);
      const { enlace } = (await r3.json()) as { enlace: string };
      const u = new URL(enlace);
      expect(`${u.origin}${u.pathname}`).toBe("https://yala-app.pe/invite");
      expect(u.searchParams.get("g")).toBe(groupId);
      inviteToken = u.searchParams.get("t");
      expect(inviteToken).toMatch(/^[0-9a-f]{32}$/);
    }

    // 4 · Por el canal del iPhone: el gasto y sus cuotas, con la forma que el iPhone sabe leer.
    const token = await appToken(A);
    // Con la cabecera de capacidades de la app 2.3 (`v3`): sin ella el pull poda el autor del gasto, que llegó en la v3.
    const pull = await fetch(`${GATEWAY}/groups/pull?cursors=${encodeURIComponent("{}")}&limit=1000`, {
      headers: { Authorization: `Bearer ${token}`, "X-Yala-Capability-Set": "v3" },
    });
    expect(pull.status).toBe(200);
    const body = (await pull.json()) as { deltas: { entity_type: string; sync_id: string; group_id: string; fields: Record<string, unknown>; field_hlcs: Record<string, string> }[] };
    const exp = body.deltas.find((x) => x.entity_type === "split_expenses" && x.sync_id === gastoId);
    expect(exp?.fields).toEqual(
      expect.objectContaining({ expense_description: "e2e web lote 3", currency_code: gasto.divisa, paid_by_member_key: ana.clave, split_type: "equal", last_edited_by_member_key: ana.clave }),
    );
    expect(Number(exp?.fields.amount)).toBe(10.01);
    expect(Object.keys(exp?.field_hlcs ?? {})).toEqual(expect.arrayContaining(["gmoney", "expense_description", "date", "paid_by_member_key", "split_type"]));
    const shares = body.deltas.filter((x) => x.entity_type === "split_shares" && x.fields.expense_id === gastoId);
    expect(shares.map((s) => [s.fields.member_key, Number(s.fields.amount)]).sort()).toEqual([
      [ana.clave, 5.01],
      [beto.clave, 5],
    ].sort());
  }, 120_000);
});
