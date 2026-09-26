import { jwtPayload } from "./b64";
import { describe, expect, it } from "vitest";
import { callTool, connect, INIT, rpc, world, type World } from "./helpers";
import { account, tx, uuid } from "./fixtures";
import { USER_A } from "./supabase-fake";

async function connected(rows: Record<string, unknown[]> = {}) {
  const w = await world();
  const { tokens } = await connect(w);
  w.supabase.rows = rows;
  return { w, token: tokens.access_token };
}

function reads(w: World) {
  return w.supabase.calls.filter((c) => c.path.startsWith("/rest/v1/")).map((c) => ({ ...c, url: new URL(`https://x${c.path}${c.search}`) }));
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
