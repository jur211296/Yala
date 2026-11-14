/**
 * Lote 3: Grupos en lectura (por la entrada interna del gateway), las cuentas «solo Grupos» y editar o descartar los
 * borradores de la web que el iPhone aún no recogió. Los saldos se prueban contra la app en
 * `mcp/test/groups-parity.test.ts`; aquí, que las rutas los sirven con el token de solo lectura y a quien deben.
 */
import { describe, expect, it } from "vitest";
import { BASE, world, type Browser, type World } from "./fakes";
import type { GroupsReaderBinding, WebGroupRows, WebGroupsResult } from "../src/worker/groups";

function viaje(): WebGroupRows {
  return {
    group_id: "g-viaje",
    me: "m-ana",
    group: { group_id: "g-viaje", name: "Viaje a Cusco", currency_code: "PEN", simplify_debts: true, show_debts_in_single_currency: false, is_archived: false, is_hidden_for_all: false },
    members: [
      { member_key: "m-ana", display_name: "Ana", role: "admin", status: "active" },
      { member_key: "m-beto", display_name: "Beto", role: "member", status: "active" },
      { member_key: "m-caro", display_name: "Caro", role: "member", status: "active" },
    ],
    expenses: [
      { sync_id: "e1", amount: "90.0000", currency_code: "PEN", paid_by_member_key: "m-ana", is_settled: false, expense_description: "Hotel", date: "2026-11-10T12:00:00Z" },
      { sync_id: "e2", amount: "30.0000", currency_code: "PEN", paid_by_member_key: "m-beto", is_settled: false, expense_description: "Taxi", date: "2026-11-11T12:00:00Z" },
    ],
    shares: [
      { expense_id: "e1", member_key: "m-ana", amount: "30.0000" },
      { expense_id: "e1", member_key: "m-beto", amount: "30.0000" },
      { expense_id: "e1", member_key: "m-caro", amount: "30.0000" },
      { expense_id: "e2", member_key: "m-beto", amount: "15.0000" },
      { expense_id: "e2", member_key: "m-caro", amount: "15.0000" },
    ],
    settlements: [{ sync_id: "p1", from_member_key: "m-caro", to_member_key: "m-ana", amount: "10.0000", currency_code: "PEN", is_confirmed: true, date: "2026-11-12T12:00:00Z" }],
  };
}

class FakeGateway implements GroupsReaderBinding {
  readonly tokens: string[] = [];
  result: WebGroupsResult = { ok: true, groups: [viaje(), { ...viaje(), group_id: "g-oculto", group: { ...viaje().group, is_hidden_for_all: true } }], truncated: false };
  readonly asked: (string | undefined)[] = [];
  async snapshot(token: string, only?: string): Promise<WebGroupsResult> {
    this.tokens.push(token);
    this.asked.push(only);
    if (!this.result.ok || !only) return this.result;
    return { ...this.result, groups: this.result.groups.filter((g) => g.group_id === only) };
  }
}

async function post(b: Browser, path: string, body: unknown) {
  const raw = JSON.stringify(body);
  return b.request(path, {
    method: "POST",
    body: raw,
    headers: { "Content-Type": "application/json", "Content-Length": String(new TextEncoder().encode(raw).length), Origin: BASE },
  });
}

function claims(token: string): Record<string, unknown> {
  return JSON.parse(atob(token.split(".")[1]!.replace(/-/g, "+").replace(/_/g, "/"))) as Record<string, unknown>;
}

async function setup(kind: "complete" | "groups_only" = "complete"): Promise<{ w: World; gw: FakeGateway; userId: string }> {
  const gw = new FakeGateway();
  const w = await world({ GATEWAY_GROUPS: gw });
  const ana = w.supabase.addUser({ email: "ana@yala.test", kind });
  await w.socialLogin(ana);
  return { w, gw, userId: ana.id };
}

describe("lote 3: Grupos en lectura", () => {
  it("la lista: resumen y tarjetas con los saldos del núcleo, sin los grupos ocultos, con el token de solo lectura", async () => {
    const { w, gw } = await setup();
    const res = await w.browser.request("/api/grupos");
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      resumen: { teDeben: { divisa: string; importe: number }[]; debes: unknown[] };
      grupos: { id: string; nombre: string; banda: { estado: string }; personas: { nombre: string; sentido: string; importe: number }[] }[];
    };
    // Ana pagó 90 (le tocan 30) y Caro le pagó 10: con «Menos pagos», Beto le debe 15 y Caro 35.
    expect(body.resumen.teDeben).toEqual([{ divisa: "PEN", importe: 50 }]);
    expect(body.resumen.debes).toEqual([]);
    expect(body.grupos.map((g) => g.id)).toEqual(["g-viaje"]);
    expect(body.grupos[0]!.banda.estado).toBe("theyOweMe");
    expect(body.grupos[0]!.personas).toEqual([
      { nombre: "Caro", sentido: "teDebe", importe: 35, divisa: "PEN" },
      { nombre: "Beto", sentido: "teDebe", importe: 15, divisa: "PEN" },
    ]);
    expect(gw.tokens).toHaveLength(1);
    expect(claims(gw.tokens[0]!).role).toBe("yala_mcp_reader");
  });

  it("el detalle: deudas, saldos por persona, gastos con tu parte y pagos; un grupo ajeno es 404", async () => {
    const { w, gw } = await setup();
    const res = await w.browser.request("/api/grupos/detalle?id=g-viaje");
    expect(res.status).toBe(200);
    const d = (await res.json()) as {
      deudas: { de: string; a: string; aTi: boolean; importe: number }[];
      saldos: { nombre: string; neto: number }[];
      gastos: { id: string; tuParte: number | null; pagasteTu: boolean }[];
      pagos: { de: string; confirmado: boolean }[];
      miembros: { nombre: string; esTu: boolean }[];
    };
    expect(d.deudas).toEqual([
      expect.objectContaining({ de: "Beto", a: "Ana", aTi: true, importe: 15 }),
      expect.objectContaining({ de: "Caro", a: "Ana", aTi: true, importe: 35 }),
    ]);
    expect(d.saldos.find((s) => s.nombre === "Ana")?.neto).toBe(50);
    expect(d.gastos.map((g) => [g.id, g.tuParte, g.pagasteTu])).toEqual([
      ["e2", null, false],
      ["e1", 30, true],
    ]);
    expect(d.pagos).toEqual([expect.objectContaining({ de: "Caro", confirmado: true })]);
    expect(d.miembros[0]).toEqual(expect.objectContaining({ nombre: "Ana", esTu: true }));
    expect(gw.asked).toEqual(["g-viaje"]);
    expect((await w.browser.request("/api/grupos/detalle?id=g-otro")).status).toBe(404);
    expect((await w.browser.request("/api/grupos/detalle?id=g-oculto")).status).toBe(404);
    expect((await w.browser.request("/api/grupos/detalle")).status).toBe(400);
  });

  it("si el gateway no lee, 503 y la página lo dice; sin binding, también", async () => {
    const { w, gw } = await setup();
    gw.result = { ok: false, error: "upstream" };
    const res = await w.browser.request("/api/grupos");
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ error: "grupos_no_disponible", motivo: "upstream" });
    const sin = await world();
    const beto = sin.supabase.addUser({ email: "beto@yala.test" });
    await sin.socialLogin(beto);
    expect((await sin.browser.request("/api/grupos")).status).toBe(503);
  });

  it("un grupo archivado sale al final con su marca y no suma al resumen ni a los pagos por confirmar", async () => {
    const { w, gw } = await setup();
    const archivado = { ...viaje(), group_id: "g-viejo", group: { ...viaje().group, name: "Viejo", is_archived: true } };
    archivado.settlements = [...archivado.settlements, { sync_id: "p9", from_member_key: "m-beto", to_member_key: "m-ana", amount: "5.0000", currency_code: "PEN", is_confirmed: false }];
    gw.result = { ok: true, groups: [archivado, viaje()], truncated: false };
    const body = (await (await w.browser.request("/api/grupos")).json()) as {
      resumen: { teDeben: { importe: number }[]; pagosPorConfirmar: number };
      grupos: { id: string; archivado: boolean }[];
    };
    expect(body.resumen.teDeben).toEqual([{ divisa: "PEN", importe: 50 }]);
    expect(body.resumen.pagosPorConfirmar).toBe(0);
    expect(body.grupos.map((g) => [g.id, g.archivado])).toEqual([["g-viaje", false], ["g-viejo", true]]);
  });

  it("un grupo cortado por el gateway lo dice en el detalle", async () => {
    const { w, gw } = await setup();
    gw.result = { ok: true, groups: [viaje()], truncated: true };
    const d = (await (await w.browser.request("/api/grupos/detalle?id=g-viaje")).json()) as { incompleto: boolean };
    expect(d.incompleto).toBe(true);
  });

  it("sin sesión, 401", async () => {
    const gw = new FakeGateway();
    const w = await world({ GATEWAY_GROUPS: gw });
    expect((await w.browser.request("/api/grupos")).status).toBe(401);
    expect(gw.tokens).toHaveLength(0);
  });
});

describe("lote 3: cuentas «solo Grupos»", () => {
  it("entran, `me` lo dice, ven Grupos y lo de la nube completa responde 409 solo_grupos", async () => {
    const { w } = await setup("groups_only");
    const me = (await (await w.browser.request("/api/me")).json()) as { soloGrupos: boolean };
    expect(me.soloGrupos).toBe(true);
    expect((await w.browser.request("/api/grupos")).status).toBe(200);
    for (const path of ["/api/panel", "/api/registros", "/api/categorias", "/api/bandeja", "/api/estadisticas", "/api/pagos"]) {
      const res = await w.browser.request(path);
      expect(res.status, path).toBe(409);
      expect(await res.json()).toEqual({ error: "solo_grupos" });
    }
    const draft = await post(w.browser, "/api/borradores", { importe: 10, divisa: "PEN", descripcion: "x", fecha: new Date(w.clock.now * 1000).toISOString().slice(0, 10) });
    expect(draft.status).toBe(409);
    expect(w.d1.rows()).toHaveLength(0);
  });

  it("una cuenta completa sigue viendo todo y `me` dice que no es «solo Grupos»", async () => {
    const { w } = await setup();
    const me = (await (await w.browser.request("/api/me")).json()) as { soloGrupos: boolean };
    expect(me.soloGrupos).toBe(false);
    expect((await w.browser.request("/api/panel")).status).toBe(200);
  });
});

describe("lote 3: editar y descartar borradores de la web", () => {
  const today = (w: World) => new Date(w.clock.now * 1000).toISOString().slice(0, 10);

  it("edita en sitio (mismo id y misma fecha de alta) lo que el iPhone aún no recogió", async () => {
    const { w } = await setup();
    const sent = await post(w.browser, "/api/borradores", { importe: 25, divisa: "PEN", descripcion: "Almuerzo", fecha: today(w) });
    const { id } = (await sent.json()) as { id: string };
    const before = w.d1.rows()[0]!;
    w.clock.now += 60;
    const res = await post(w.browser, "/api/borradores/editar", { id, importe: 32.5, divisa: "PEN", descripcion: "Almuerzo y café", fecha: today(w) });
    expect(res.status).toBe(200);
    const after = w.d1.rows();
    expect(after).toHaveLength(1);
    expect(after[0]!.id).toBe(id);
    expect(after[0]!.created_at).toBe(before.created_at);
    expect(after[0]!.payload).toEqual(expect.objectContaining({ amount: 32.5, merchant: "Almuerzo y café", source: "web" }));
    const bandeja = (await (await w.browser.request("/api/bandeja")).json()) as { enviados: { id: string; importe: number; cuenta: string | null }[] };
    expect(bandeja.enviados).toEqual([expect.objectContaining({ id, importe: 32.5, cuenta: null })]);
  });

  it("descarta, y un borrador ya recogido (o de otra persona, o del correo) da 409 sin tocar nada", async () => {
    const { w, userId } = await setup();
    const sent = await post(w.browser, "/api/borradores", { importe: 25, divisa: "PEN", descripcion: "Almuerzo", fecha: today(w) });
    const { id } = (await sent.json()) as { id: string };
    expect((await post(w.browser, "/api/borradores/descartar", { id })).status).toBe(200);
    expect(w.d1.rows()).toHaveLength(0);
    // Ya no está (el iPhone lo confirmó y se borró): 409.
    expect((await post(w.browser, "/api/borradores/descartar", { id })).status).toBe(409);
    expect((await post(w.browser, "/api/borradores/editar", { id, importe: 1, divisa: "PEN", descripcion: "", fecha: today(w) })).status).toBe(409);
    // Uno del correo del banco, de la misma persona: la web no lo toca.
    const mailId = crypto.randomUUID();
    await w.env.DRAFTS_DB.prepare("INSERT INTO mail_drafts (id, user_id, created_at, payload) VALUES (?, ?, ?, ?)")
      .bind(mailId, userId, w.clock.now * 1000, JSON.stringify({ kind: "expense", amount: 9, currency: "PEN", merchant: "Banco" }))
      .run();
    expect((await post(w.browser, "/api/borradores/descartar", { id: mailId })).status).toBe(409);
    // Uno de otra persona.
    const otherId = crypto.randomUUID();
    await w.env.DRAFTS_DB.prepare("INSERT INTO mail_drafts (id, user_id, created_at, payload) VALUES (?, ?, ?, ?)")
      .bind(otherId, crypto.randomUUID(), w.clock.now * 1000, JSON.stringify({ kind: "expense", amount: 9, currency: "PEN", source: "web" }))
      .run();
    expect((await post(w.browser, "/api/borradores/descartar", { id: otherId })).status).toBe(409);
    expect(w.d1.rows().map((r) => r.id).sort()).toEqual([mailId, otherId].sort());
  });

  it("un id que no es un UUID es 400, y la edición valida como al apuntar", async () => {
    const { w } = await setup();
    expect((await post(w.browser, "/api/borradores/descartar", { id: "../x" })).status).toBe(400);
    const sent = await post(w.browser, "/api/borradores", { importe: 25, divisa: "PEN", descripcion: "Almuerzo", fecha: today(w) });
    const { id } = (await sent.json()) as { id: string };
    const bad = await post(w.browser, "/api/borradores/editar", { id, importe: -3, divisa: "PEN", descripcion: "", fecha: today(w) });
    expect(bad.status).toBe(400);
    expect(await bad.json()).toEqual({ error: "entrada", campo: "importe" });
  });
});
