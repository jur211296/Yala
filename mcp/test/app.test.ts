import { jwtPayload } from "./b64";
import { describe, expect, it } from "vitest";
import { callTool, connect, INIT, isDataRead, rpc, world, type World } from "./helpers";
import { account, tx, uuid } from "./fixtures";
import { USER_A } from "./supabase-fake";

async function connected(rows: Record<string, unknown[]> = {}) {
  const w = await world();
  const { tokens } = await connect(w);
  w.supabase.rows = rows;
  return { w, token: tokens.access_token };
}

function reads(w: World) {
  return w.supabase.calls.filter(isDataRead).map((c) => ({ ...c, url: new URL(`https://x${c.path}${c.search}`) }));
}

describe("protocolo MCP", () => {
  it("initialize y tools/list: seis herramientas de solo lectura, con título y nombres cortos", async () => {
    const { w, token } = await connected();
    const init = await rpc(w, token, INIT);
    expect(init.status).toBe(200);
    expect(((await init.json()) as { result: { serverInfo: { name: string } } }).result.serverInfo.name).toBe("yala");

    const res = await rpc(w, token, { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} });
    const { result } = (await res.json()) as { result: { tools: { name: string; title?: string; annotations?: Record<string, unknown> }[] } };
    expect(result.tools.map((t) => t.name).sort()).toEqual(
      ["buscar_movimientos", "estado_presupuestos", "listar_categorias", "listar_cuentas", "listar_recurrentes", "resumen_periodo"].sort(),
    );
    for (const t of result.tools) {
      expect(t.name.length).toBeLessThanOrEqual(64);
      expect(t.title).toBeTruthy();
      expect(t.annotations).toMatchObject({ readOnlyHint: true, destructiveHint: false });
    }
  });

  it("listar_cuentas lee con la sesión de solo lectura del USUARIO, solo GET, y devuelve saldos calculados", async () => {
    const acc = uuid(9001);
    const { w, token } = await connected({
      accounts: [account({ sync_id: acc, name: "BCP" })],
      tx_items: [
        { account_ref: acc, amount: 500, currency_code: "PEN" },
        { account_ref: acc, amount: -120, currency_code: "PEN" },
      ],
      user_preferences: [{ key: "defaultCurrencyCode", value: "PEN" }],
      exchange_rates: [],
    });
    const { body } = await callTool(w, token, "listar_cuentas");
    expect(body!.result.isError).toBeFalsy();
    const data = JSON.parse(body!.result.content[0]!.text);
    expect(data.cuentas[0]).toMatchObject({ nombre: "BCP", saldo: 380 });
    expect(data.total).toMatchObject({ divisa: "PEN", importe: 380 });
    const upstream = w.supabase.oauthSessions(USER_A.id)[0]!;
    const calls = reads(w);
    expect(calls.length).toBeGreaterThan(0);
    for (const c of calls) {
      expect(c.method).toBe("GET");
      // El token de Supabase de la sesión OAuth del Worker, nunca el de Claude.
      const payload = jwtPayload(c.auth!.replace("Bearer ", ""));
      expect(payload).toMatchObject({ role: "yala_mcp_reader", session_id: upstream.id });
      expect(c.auth).not.toContain(token);
      // user_preferences es un KV sin lápidas (supabase-staging.ddl:427): no tiene `deleted`.
      if (!c.url.pathname.endsWith("/user_preferences")) expect(c.url.searchParams.getAll("deleted")).toContain("is.false");
    }
  });

  it("listar_cuentas deja fuera del saldo lo fechado después de hoy, lo dice, y pide la columna de fecha", async () => {
    const acc = uuid(9002);
    const { w, token } = await connected({
      accounts: [account({ sync_id: acc, name: "BCP" })],
      tx_items: [
        { account_ref: acc, amount: 1000, currency_code: "PEN", date: "2020-01-01T12:00:00Z", local_day: "2020-01-01" },
        { account_ref: acc, amount: -200, currency_code: "PEN", date: "2099-01-01T12:00:00Z", local_day: "2099-01-01" },
      ],
      user_preferences: [{ key: "defaultCurrencyCode", value: "PEN" }],
      exchange_rates: [],
    });
    const sinZona = JSON.parse((await callTool(w, token, "listar_cuentas")).body!.result.content[0]!.text);
    expect(sinZona.cuentas[0]).toMatchObject({ saldo: 1000, movimientos: 1 });
    expect(sinZona.total.importe).toBe(1000);
    expect(sinZona.futuros_excluidos).toBe(1);
    expect(sinZona.avisos).toContain("Hay 1 movimiento con fecha posterior a hoy: no está en los saldos, igual que en la app.");
    expect(sinZona.avisos.some((a: string) => a.startsWith("No se indicó zona horaria"))).toBe(true);
    const conZona = JSON.parse((await callTool(w, token, "listar_cuentas", { zona_horaria: "Europe/Madrid" })).body!.result.content[0]!.text);
    expect(conZona.avisos.some((a: string) => a.startsWith("No se indicó zona horaria"))).toBe(false);
    // Sin futuros, el aviso de zona sigue saliendo si se supuso: una zona por delante metería de más sin delatarse.
    w.supabase.rows.tx_items = [w.supabase.rows.tx_items![0]!];
    const sinFuturos = JSON.parse((await callTool(w, token, "listar_cuentas")).body!.result.content[0]!.text);
    expect(sinFuturos.futuros_excluidos).toBe(0);
    expect(sinFuturos.avisos.some((a: string) => a.startsWith("No se indicó zona horaria"))).toBe(true);
    const txRead = reads(w).find((c) => c.url.pathname.endsWith("/tx_items"))!;
    expect(txRead.url.searchParams.get("select")).toBe("account_ref,amount,currency_code,date,local_day");
  });

  it("la zona: la de Claude manda; si no, la que subió la app; si tampoco (o no es válida), Lima y se avisa", async () => {
    const base = { tx_items: [], accounts: [], categories: [], subcategories: [], tags: [], exchange_rates: [] };
    const { w, token } = await connected({ ...base, user_preferences: [{ key: "timeZoneIdentifier", value: "Europe/Madrid" }] });
    const zoneOf = async (args: Record<string, unknown> = {}) => JSON.parse((await callTool(w, token, "buscar_movimientos", args)).body!.result.content[0]!.text);
    const deLaApp = await zoneOf();
    expect(deLaApp.zona_horaria).toBe("Europe/Madrid");
    expect(deLaApp.avisos.some((a: string) => a.startsWith("No se indicó zona horaria"))).toBe(false);
    expect((await zoneOf({ zona_horaria: "Asia/Tokyo" })).zona_horaria).toBe("Asia/Tokyo");
    const prefsRead = reads(w).find((c) => c.url.pathname.endsWith("/user_preferences"))!;
    expect(prefsRead.url.searchParams.get("key")).toBe("in.(defaultCurrencyCode,firstWeekday,timeZoneIdentifier)");

    w.supabase.rows.user_preferences = [{ key: "timeZoneIdentifier", value: "Marte/Olimpo" }];
    const ilegible = await zoneOf();
    expect(ilegible.zona_horaria).toBe("America/Lima");
    expect(ilegible.avisos.some((a: string) => a.startsWith("No se indicó zona horaria"))).toBe(true);
    w.supabase.rows.user_preferences = [];
    expect((await zoneOf()).zona_horaria).toBe("America/Lima");
  });

  it("buscar_movimientos pagina con cursor y escapa el texto libre", async () => {
    const rows = Array.from({ length: 3 }, (_, i) =>
      tx({ sync_id: uuid(9100 + i), date: `2026-09-1${i}T15:00:00+00:00`, note: `Compra ${i}`, amount: -i }),
    );
    const { w, token } = await connected({ tx_items: rows, accounts: [], categories: [], subcategories: [], tags: [], user_preferences: [] });
    const { body } = await callTool(w, token, "buscar_movimientos", { limite: 2, texto: "caf*é%),(x" });
    const data = JSON.parse(body!.result.content[0]!.text);
    expect(data.movimientos).toHaveLength(2);
    expect(data.siguiente_cursor).toBeTruthy();
    const txCall = reads(w).find((c) => c.url.pathname.endsWith("/tx_items"))!;
    expect(txCall.url.searchParams.get("note")).toBe("ilike.*caf é x*");
    expect(txCall.url.searchParams.get("limit")).toBe("3");

    const next = await callTool(w, token, "buscar_movimientos", { limite: 2, cursor: data.siguiente_cursor });
    expect(next.res.status).toBe(200);
    const lastCall = reads(w).filter((c) => c.url.pathname.endsWith("/tx_items")).at(-1)!;
    expect(lastCall.url.searchParams.get("and")).toContain(`sync_id.lt.${uuid(9101)}`);
  });

  it("buscar_movimientos no enseña como importe un convertido sin escribir (0 con nativo distinto de 0)", async () => {
    const sinConvertir = uuid(9150);
    const convertido = uuid(9151);
    const cero = uuid(9152);
    const rows = [
      tx({ sync_id: sinConvertir, date: "2026-09-12T15:00:00+00:00", amount: -50, currency_code: "USD", amount_in_preferred_currency: 0, preferred_currency_code: "PEN" }),
      tx({ sync_id: convertido, date: "2026-09-11T15:00:00+00:00", amount: -50, currency_code: "USD", amount_in_preferred_currency: -185, preferred_currency_code: "PEN" }),
      tx({ sync_id: cero, date: "2026-09-10T15:00:00+00:00", amount: 0, currency_code: "USD", amount_in_preferred_currency: 0, preferred_currency_code: "PEN" }),
    ];
    const { w, token } = await connected({
      tx_items: rows, accounts: [], categories: [], subcategories: [], tags: [],
      user_preferences: [{ key: "defaultCurrencyCode", value: "PEN" }],
    });
    const { body } = await callTool(w, token, "buscar_movimientos", {});
    const data = JSON.parse(body!.result.content[0]!.text);
    const byId = new Map<string, { importe_en_divisa_preferida: number | null }>(
      data.movimientos.map((m: { id: string; importe_en_divisa_preferida: number | null }) => [m.id, m]),
    );
    // Con el bug: 0, que parece un importe real.
    expect(byId.get(sinConvertir)!.importe_en_divisa_preferida).toBeNull();
    // Controles: el convertido escrito se enseña, y un importe de 0 de verdad sigue siendo 0.
    expect(byId.get(convertido)!.importe_en_divisa_preferida).toBe(-185);
    expect(byId.get(cero)!.importe_en_divisa_preferida).toBe(0);
  });

  it("un cursor manipulado es un error de entrada, no una consulta", async () => {
    const { w, token } = await connected({ tx_items: [], accounts: [], categories: [], subcategories: [], tags: [], user_preferences: [] });
    const id = uuid(9200);
    // El segundo lo acepta `Date.parse` de V8 y su «\\» final escaparía la comilla de cierre en PostgREST.
    for (const d of ["x),or(id.gt.0", "2026-01-01 (x\\"]) {
      const { body } = await callTool(w, token, "buscar_movimientos", { cursor: btoa(JSON.stringify({ d, id })) });
      expect(body!.result.isError, d).toBe(true);
      expect(body!.result.content[0]!.text).toMatch(/cursor/);
    }
    expect(reads(w).some((c) => c.url.pathname.endsWith("/tx_items"))).toBe(false);
  });

  it("si PostgREST rechaza la sesión, la herramienta pide reconectar sin filtrar detalles", async () => {
    const { w, token } = await connected();
    w.supabase.postgrestStatus = 401;
    const { body } = await callTool(w, token, "listar_categorias");
    expect(body!.result.isError).toBe(true);
    expect(body!.result.content[0]!.text).toMatch(/Vuelve a conectar/);
  });
});
