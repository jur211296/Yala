/**
 * Lote 3, opción A de Jürgen (14-nov): escribir en Grupos desde la web. La escritura de verdad es del gateway
 * (`gateway/test/web.groupsWriter.test.ts`); aquí, que las rutas de la web le pasan el formulario con el token del rol
 * propio, traducen sus respuestas, renuevan una vez un token de antes de web3_02 y lo guardan, y que el detalle dice qué
 * se puede hacer.
 */
import { describe, expect, it } from "vitest";
import { BASE, world, type Browser, type World } from "./fakes";
import type { GroupsReaderBinding, WebGroupRows, WebGroupsResult } from "../src/worker/groups";
import type { GroupsWriterBinding, WebExpenseInput, WebInviteResult, WebSettlementInput, WebWriteResult } from "../src/worker/groupsWrite";

function viaje(): WebGroupRows {
  return {
    group_id: "g-viaje",
    me: "m-ana",
    group: { group_id: "g-viaje", name: "Viaje a Cusco", currency_code: "PEN", simplify_debts: true, show_debts_in_single_currency: false, is_archived: false, members_can_invite: false },
    members: [
      { member_key: "m-ana", display_name: "Ana", role: "admin", status: "active" },
      { member_key: "m-beto", display_name: "Beto", role: "member", status: "active" },
    ],
    expenses: [{ sync_id: "e1", amount: "90.0000", currency_code: "PEN", paid_by_member_key: "m-ana", expense_description: "Hotel", date: "2026-11-10T12:00:00Z" }],
    shares: [
      { expense_id: "e1", member_key: "m-ana", amount: "45.0000" },
      { expense_id: "e1", member_key: "m-beto", amount: "45.0000" },
    ],
    settlements: [{ sync_id: "p1", from_member_key: "m-beto", to_member_key: "m-ana", amount: "5.0000", currency_code: "USD", is_confirmed: true }],
  };
}

class FakeReader implements GroupsReaderBinding {
  group = viaje();
  async snapshot(_token: string, only?: string): Promise<WebGroupsResult> {
    return { ok: true, groups: !only || only === this.group.group_id ? [this.group] : [], truncated: false };
  }
}

function role(token: string): string {
  return (JSON.parse(atob(token.split(".")[1]!.replace(/-/g, "+").replace(/_/g, "/"))) as { role: string }).role;
}

class FakeWriter implements GroupsWriterBinding {
  readonly calls: { op: string; token: string; input: unknown }[] = [];
  next: WebWriteResult | null = null;
  /** Como el gateway: solo el rol propio de la web escribe. */
  private gate(token: string): WebWriteResult | null {
    if (role(token) !== "yala_web") return { ok: false, error: "role" };
    return this.next;
  }
  async addExpense(token: string, input: WebExpenseInput): Promise<WebWriteResult> {
    this.calls.push({ op: "gasto", token, input });
    return this.gate(token) ?? { ok: true, status: "applied" };
  }
  async addSettlement(token: string, input: WebSettlementInput): Promise<WebWriteResult> {
    this.calls.push({ op: "pago", token, input });
    return this.gate(token) ?? { ok: true, status: "applied" };
  }
  async createInvite(token: string, groupId: string): Promise<WebInviteResult> {
    this.calls.push({ op: "invitar", token, input: groupId });
    const g = this.gate(token);
    if (g && !g.ok) return g;
    return { ok: true, url: `https://yala-app.pe/invite?g=${groupId}&t=abc`, expiresAt: "2026-11-21T00:00:00.000Z" };
  }
}

async function post(b: Browser, path: string, body: unknown, origin = BASE) {
  const raw = JSON.stringify(body);
  return b.request(path, {
    method: "POST",
    body: raw,
    headers: { "Content-Type": "application/json", "Content-Length": String(new TextEncoder().encode(raw).length), Origin: origin },
  });
}

const GASTO = {
  grupo: "g-viaje",
  id: "0F8E2C1A-1111-4222-8333-444455556666",
  descripcion: " Cena ",
  importe: 60,
  divisa: "PEN",
  pagadoPor: "m-ana",
  fecha: "2026-11-14T15:30:00.000Z",
  participantes: ["m-ana", "m-beto"],
};
const PAGO = { grupo: "g-viaje", id: "0f8e2c1a-2222-4222-8333-444455556666", de: "m-beto", a: "m-ana", importe: 45, divisa: "PEN", fecha: "2026-11-14T15:30:00.000Z", nota: "" };

async function setup(opts: { writer?: boolean; kind?: "complete" | "groups_only"; oldRole?: boolean } = {}): Promise<{ w: World; writer: FakeWriter; reader: FakeReader }> {
  const writer = new FakeWriter();
  const reader = new FakeReader();
  const w = await world({ GATEWAY_GROUPS: reader, ...(opts.writer === false ? {} : { GATEWAY_GROUPS_WRITER: writer }) });
  w.supabase.oldWebRole = opts.oldRole === true;
  const ana = w.supabase.addUser({ email: "ana@yala.test", kind: opts.kind ?? "complete" });
  await w.socialLogin(ana);
  return { w, writer, reader };
}

describe("lote 3 · escribir en Grupos (opción A)", () => {
  it("el detalle dice qué se puede hacer: escribir, invitar (admin), las divisas del grupo y las claves de cada persona", async () => {
    const { w } = await setup();
    const d = (await (await w.browser.request("/api/grupos/detalle?id=g-viaje")).json()) as {
      puedeEscribir: boolean;
      puedeInvitar: boolean;
      divisas: string[];
      miembros: { clave: string; esTu: boolean }[];
      deudas: { deClave: string; aClave: string }[];
    };
    expect(d.puedeEscribir).toBe(true);
    expect(d.puedeInvitar).toBe(true);
    expect(d.divisas.sort()).toEqual(["PEN", "USD"]);
    expect(d.miembros.map((m) => [m.clave, m.esTu])).toEqual([
      ["m-ana", true],
      ["m-beto", false],
    ]);
    expect(d.deudas[0]).toEqual(expect.objectContaining({ deClave: "m-beto", aClave: "m-ana" }));
  });

  it("sin la entrada de escritura, ni se ofrece ni se acepta", async () => {
    const { w } = await setup({ writer: false });
    const d = (await (await w.browser.request("/api/grupos/detalle?id=g-viaje")).json()) as { puedeEscribir: boolean; puedeInvitar: boolean };
    expect([d.puedeEscribir, d.puedeInvitar]).toEqual([false, false]);
    const res = await post(w.browser, "/api/grupos/gasto", GASTO);
    expect(res.status).toBe(409);
    expect(await res.json()).toEqual({ error: "escritura_apagada" });
  });

  it("un grupo archivado no ofrece escribir; un miembro sin «miembros pueden invitar», tampoco invitar", async () => {
    const { w, reader } = await setup();
    reader.group.group = { ...reader.group.group, is_archived: true };
    let d = (await (await w.browser.request("/api/grupos/detalle?id=g-viaje")).json()) as { puedeEscribir: boolean; puedeInvitar: boolean };
    expect([d.puedeEscribir, d.puedeInvitar]).toEqual([false, false]);
    reader.group = viaje();
    reader.group.members[0]!.role = "member";
    d = (await (await w.browser.request("/api/grupos/detalle?id=g-viaje")).json()) as { puedeEscribir: boolean; puedeInvitar: boolean };
    expect([d.puedeEscribir, d.puedeInvitar]).toEqual([true, false]);
  });

  it("añadir un gasto: pasa el formulario al gateway con el token del rol propio", async () => {
    const { w, writer } = await setup();
    const res = await post(w.browser, "/api/grupos/gasto", GASTO);
    expect(res.status).toBe(201);
    expect(await res.json()).toEqual({ estado: "hecho" });
    expect(writer.calls).toHaveLength(1);
    expect(role(writer.calls[0]!.token)).toBe("yala_web");
    expect(writer.calls[0]!.input).toEqual({
      groupId: "g-viaje",
      id: "0f8e2c1a-1111-4222-8333-444455556666",
      description: "Cena",
      amount: 60,
      currency: "PEN",
      paidBy: "m-ana",
      date: "2026-11-14T15:30:00.000Z",
      participants: ["m-ana", "m-beto"],
    });
  });

  it("saldar e invitar", async () => {
    const { w, writer } = await setup();
    const pago = await post(w.browser, "/api/grupos/pago", PAGO);
    expect(pago.status).toBe(201);
    expect(writer.calls[0]!.input).toEqual({ groupId: "g-viaje", id: PAGO.id, from: "m-beto", to: "m-ana", amount: 45, currency: "PEN", date: PAGO.fecha });
    const inv = await post(w.browser, "/api/grupos/invitar", { grupo: "g-viaje" });
    expect(inv.status).toBe(201);
    expect(await inv.json()).toEqual({ enlace: "https://yala-app.pe/invite?g=g-viaje&t=abc", caduca: "2026-11-21T00:00:00.000Z" });
  });

  it("lo que no tiene forma no llega al gateway; sin el mismo origen, tampoco", async () => {
    const { w, writer } = await setup();
    const cases: [Record<string, unknown>, string][] = [
      [{ ...GASTO, id: "x" }, "id"],
      [{ ...GASTO, descripcion: "  " }, "descripcion"],
      [{ ...GASTO, importe: -1 }, "importe"],
      [{ ...GASTO, divisa: "soles" }, "divisa"],
      [{ ...GASTO, participantes: [] }, "participantes"],
      [{ ...GASTO, fecha: "mañana" }, "fecha"],
    ];
    for (const [body, campo] of cases) {
      const res = await post(w.browser, "/api/grupos/gasto", body);
      expect(res.status, campo).toBe(400);
      expect(await res.json()).toEqual({ error: "entrada", campo });
    }
    const pago = await post(w.browser, "/api/grupos/pago", { ...PAGO, a: "m-beto" });
    expect(await pago.json()).toEqual({ error: "entrada", campo: "personas" });
    expect((await post(w.browser, "/api/grupos/gasto", GASTO, "https://otro.example")).status).toBe(403);
    expect(writer.calls).toHaveLength(0);
  });

  it("traduce las respuestas del gateway", async () => {
    const { w, writer } = await setup();
    const cases: [WebWriteResult, number, Record<string, unknown>][] = [
      [{ ok: false, error: "invalid", detail: "participants" }, 400, { error: "entrada", campo: "participantes" }],
      [{ ok: false, error: "rate" }, 429, { error: "limite" }],
      [{ ok: false, error: "not_allowed", detail: "archived" }, 403, { error: "no_permitido", motivo: "archivado" }],
      [{ ok: false, error: "not_found" }, 404, { error: "no_existe" }],
      [{ ok: false, error: "upstream" }, 503, { error: "grupos_no_disponible", motivo: "upstream" }],
      [{ ok: true, status: "already" }, 200, { estado: "ya_estaba" }],
    ];
    for (const [next, status, body] of cases) {
      writer.next = next;
      const res = await post(w.browser, "/api/grupos/gasto", GASTO);
      expect(res.status, JSON.stringify(next)).toBe(status);
      expect(await res.json()).toEqual(body);
    }
  });

  it("un token de antes de web3_02 (solo lectura) lee, y al escribir se renueva una vez, escribe y queda guardado", async () => {
    const { w, writer } = await setup({ oldRole: true });
    expect((await w.browser.request("/api/grupos")).status).toBe(200);
    w.supabase.oldWebRole = false; // se aplica web3_02: el hook ya da `yala_web`
    const res = await post(w.browser, "/api/grupos/gasto", GASTO);
    expect(res.status).toBe(201);
    expect(writer.calls.map((c) => role(c.token))).toEqual(["yala_mcp_reader", "yala_web"]);
    // El token renovado se guardó: la siguiente escritura sale ya con él, sin otra renovación.
    await post(w.browser, "/api/grupos/pago", PAGO);
    expect(writer.calls.map((c) => role(c.token))).toEqual(["yala_mcp_reader", "yala_web", "yala_web"]);
    expect(writer.calls[2]!.token).toBe(writer.calls[1]!.token);
  });

  it("una cuenta «solo Grupos» también escribe", async () => {
    const { w, writer } = await setup({ kind: "groups_only" });
    expect((await post(w.browser, "/api/grupos/gasto", GASTO)).status).toBe(201);
    expect(writer.calls).toHaveLength(1);
  });
});
