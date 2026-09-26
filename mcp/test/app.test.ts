import { describe, expect, it } from "vitest";
import { createApp } from "../src/index";
import { ENV, keys, READER_CLAIMS } from "./helpers";
import { account, tx, uuid } from "./fixtures";

const BASE = "https://mcp.yala.test";

type Rows = Record<string, unknown[]>;

/** PostgREST falso: responde por tabla y apunta cada petición para poder mirar qué se pidió y con qué token. */
function fakePostgrest(rows: Rows, opts: { status?: number } = {}) {
  const calls: { method: string; url: URL; auth: string | null; apikey: string | null }[] = [];
  const fetcher = async (input: Request | string | URL, init?: RequestInit) => {
    const url = new URL(typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url);
    const headers = new Headers(init?.headers);
    calls.push({ method: init?.method ?? "GET", url, auth: headers.get("Authorization"), apikey: headers.get("apikey") });
    if (opts.status) return new Response("{}", { status: opts.status });
    const table = url.pathname.replace("/rest/v1/", "");
    const all = rows[table] ?? [];
    const offset = Number(url.searchParams.get("offset") ?? 0);
    const limit = Number(url.searchParams.get("limit") ?? all.length);
    return Response.json(all.slice(offset, offset + limit));
  };
  return { fetcher, calls };
}

async function rpc(app: ReturnType<typeof createApp>, token: string | null, body: unknown) {
  const headers: Record<string, string> = { "Content-Type": "application/json", Accept: "application/json, text/event-stream" };
  if (token) headers.Authorization = `Bearer ${token}`;
  return app.fetch(new Request(`${BASE}/mcp`, { method: "POST", headers, body: JSON.stringify(body) }), ENV);
}

const INIT = {
  jsonrpc: "2.0",
  id: 1,
  method: "initialize",
  params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "0" } },
};

describe("metadatos y 401", async () => {
  const { verifier, sign } = await keys();
  const app = createApp({ verifier, fetcher: fakePostgrest({}).fetcher });

  it("publica los metadatos del recurso protegido apuntando a Supabase Auth", async () => {
    for (const path of ["/.well-known/oauth-protected-resource", "/.well-known/oauth-protected-resource/mcp"]) {
      const res = await app.fetch(new Request(`${BASE}${path}`), ENV);
      expect(res.status).toBe(200);
      expect(await res.json()).toMatchObject({
        resource: `${BASE}/mcp`,
        authorization_servers: ["https://proyecto.supabase.co/auth/v1"],
        bearer_methods_supported: ["header"],
      });
    }
  });

  it("sin token responde 401 con WWW-Authenticate que apunta a los metadatos", async () => {
    const res = await rpc(app, null, INIT);
    expect(res.status).toBe(401);
    expect(res.headers.get("WWW-Authenticate")).toBe(`Bearer resource_metadata="${BASE}/.well-known/oauth-protected-resource/mcp"`);
  });

  it("GET y DELETE en /mcp dan 405: sin estado no hay stream SSE que reabrir", async () => {
    for (const method of ["GET", "DELETE"]) {
      const res = await app.fetch(new Request(`${BASE}/mcp`, { method, headers: { Accept: "text/event-stream" } }), ENV);
      expect(res.status).toBe(405);
      expect(res.headers.get("Allow")).toBe("POST");
    }
  });

  it("con un token de la app o sin rol de lectura responde 401 invalid_token", async () => {
    const { client_id: _, ...app_ } = READER_CLAIMS;
    for (const claims of [{ ...app_, role: "authenticated" }, { ...READER_CLAIMS, role: "authenticated" }]) {
      const res = await rpc(app, await sign(claims), INIT);
      expect(res.status).toBe(401);
      expect(res.headers.get("WWW-Authenticate")).toContain('error="invalid_token"');
    }
  });
});

describe("protocolo MCP", async () => {
  const { verifier, sign } = await keys();
  const token = await sign(READER_CLAIMS);

  it("initialize y tools/list: seis herramientas de solo lectura, con título y nombres cortos", async () => {
    const app = createApp({ verifier, fetcher: fakePostgrest({}).fetcher });
    const init = await rpc(app, token, INIT);
    expect(init.status).toBe(200);
    expect(((await init.json()) as { result: { serverInfo: { name: string } } }).result.serverInfo.name).toBe("yala");

    const res = await rpc(app, token, { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} });
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

  it("listar_cuentas lee con el token del USUARIO, solo GET, y devuelve saldos calculados", async () => {
    const acc = uuid(9001);
    const pg = fakePostgrest({
      accounts: [account({ sync_id: acc, name: "BCP" })],
      tx_items: [
        { account_ref: acc, amount: 500, currency_code: "PEN" },
        { account_ref: acc, amount: -120, currency_code: "PEN" },
      ],
      user_preferences: [{ key: "defaultCurrencyCode", value: "PEN" }],
      exchange_rates: [],
    });
    const app = createApp({ verifier, fetcher: pg.fetcher });
    const res = await rpc(app, token, { jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "listar_cuentas", arguments: {} } });
    const body = (await res.json()) as { result: { content: { text: string }[]; isError?: boolean } };
    expect(body.result.isError).toBeFalsy();
    const data = JSON.parse(body.result.content[0]!.text);
    expect(data.cuentas[0]).toMatchObject({ nombre: "BCP", saldo: 380 });
    expect(data.total).toMatchObject({ divisa: "PEN", importe: 380 });
    expect(pg.calls.length).toBeGreaterThan(0);
    for (const c of pg.calls) {
      expect(c.method).toBe("GET");
      expect(c.auth).toBe(`Bearer ${token}`);
      expect(c.apikey).toBe("anon-publica");
      // user_preferences es un KV sin lápidas (supabase-staging.ddl:427): no tiene `deleted`.
      if (!c.url.pathname.endsWith("/user_preferences")) expect(c.url.searchParams.getAll("deleted")).toContain("is.false");
    }
  });

  it("buscar_movimientos pagina con cursor y escapa el texto libre", async () => {
    const rows = Array.from({ length: 3 }, (_, i) =>
      tx({ sync_id: uuid(9100 + i), date: `2026-09-1${i}T15:00:00+00:00`, note: `Compra ${i}`, amount: -i }),
    );
    const pg = fakePostgrest({ tx_items: rows, accounts: [], categories: [], subcategories: [], tags: [], user_preferences: [] });
    const app = createApp({ verifier, fetcher: pg.fetcher });
    const res = await rpc(app, token, {
      jsonrpc: "2.0",
      id: 4,
      method: "tools/call",
      params: { name: "buscar_movimientos", arguments: { limite: 2, texto: "caf*é%),(x" } },
    });
    const data = JSON.parse(((await res.json()) as { result: { content: { text: string }[] } }).result.content[0]!.text);
    expect(data.movimientos).toHaveLength(2);
    expect(data.siguiente_cursor).toBeTruthy();
    const txCall = pg.calls.find((c) => c.url.pathname.endsWith("/tx_items"))!;
    expect(txCall.url.searchParams.get("note")).toBe("ilike.*caf é x*");
    expect(txCall.url.searchParams.get("limit")).toBe("3");

    const next = await rpc(app, token, {
      jsonrpc: "2.0",
      id: 5,
      method: "tools/call",
      params: { name: "buscar_movimientos", arguments: { limite: 2, cursor: data.siguiente_cursor } },
    });
    expect(next.status).toBe(200);
    const lastCall = pg.calls.filter((c) => c.url.pathname.endsWith("/tx_items")).at(-1)!;
    expect(lastCall.url.searchParams.get("and")).toContain(`sync_id.lt.${uuid(9101)}`);
  });

  it("un cursor manipulado es un error de entrada, no una consulta", async () => {
    const pg = fakePostgrest({ tx_items: [], accounts: [], categories: [], subcategories: [], tags: [], user_preferences: [] });
    const app = createApp({ verifier, fetcher: pg.fetcher });
    const id = uuid(9200);
    // El segundo lo acepta `Date.parse` de V8 y su «\\» final escaparía la comilla de cierre en PostgREST.
    for (const d of ["x),or(id.gt.0", "2026-01-01 (x\\"]) {
      const res = await rpc(app, token, {
        jsonrpc: "2.0",
        id: 6,
        method: "tools/call",
        params: { name: "buscar_movimientos", arguments: { cursor: btoa(JSON.stringify({ d, id })) } },
      });
      const body = (await res.json()) as { result: { isError: boolean; content: { text: string }[] } };
      expect(body.result.isError, d).toBe(true);
      expect(body.result.content[0]!.text).toMatch(/cursor/);
    }
    expect(pg.calls.some((c) => c.url.pathname.endsWith("/tx_items"))).toBe(false);
  });

  it("si Supabase rechaza el token, la herramienta pide reconectar sin filtrar detalles", async () => {
    const app = createApp({ verifier, fetcher: fakePostgrest({}, { status: 401 }).fetcher });
    const res = await rpc(app, token, { jsonrpc: "2.0", id: 7, method: "tools/call", params: { name: "listar_categorias", arguments: {} } });
    const body = (await res.json()) as { result: { isError: boolean; content: { text: string }[] } };
    expect(body.result.isError).toBe(true);
    expect(body.result.content[0]!.text).toMatch(/Vuelve a conectar/);
  });
});
