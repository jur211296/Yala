/**
 * Lote 2: Estadísticas y Pagos planificados (lectura, con el núcleo compartido) y entrar con el iPhone por QR. Las cifras
 * se prueban contra la app en `mcp/test/golden.test.ts`; aquí, que las rutas las sirven con la sesión de solo lectura y
 * que el QR no deja entrar a quien no debe.
 */
import { describe, expect, it } from "vitest";
import { BASE, TURNSTILE_OK, WEB_CLIENT, world, type Browser, type World } from "./fakes";
import { QR_CHAIN_SECONDS, QR_CODE_TTL_SECONDS, QR_CONFIRM_SECONDS, normalizeCode } from "../src/worker/pairing";

const ACC = "11111111-1111-4111-8111-111111111111";
const CAT = "33333333-3333-4333-8333-333333333333";
const PAY = "55555555-5555-4555-8555-555555555555";

function seed(w: World, user: Parameters<World["supabase"]["seed"]>[1]) {
  const now = new Date(w.clock.now * 1000);
  w.supabase.seed("accounts", user, [
    { sync_id: ACC, name: "BCP", currency_code: "PEN", type: "bank", is_archived: false, exclude_from_statistics: false, is_system_account: false, parent_account_id: null },
  ]);
  w.supabase.seed("categories", user, [{ sync_id: CAT, name: "Comida", is_income: false, is_visible: true, sort_order: 1 }]);
  w.supabase.seed("user_preferences", user, [
    { key: "defaultCurrencyCode", value: "PEN" },
    { key: "timeZoneIdentifier", value: "America/Lima" },
  ]);
  const tx = (id: string, amount: number, category: string | null, account: string | null) => ({
    sync_id: id,
    date: new Date(now.getTime() - 3600_000).toISOString(),
    local_day: null,
    amount,
    currency_code: "PEN",
    note: null,
    category_ref: category,
    subcategory_ref: null,
    account_ref: account,
    tag_refs: [],
    amount_in_preferred_currency: amount,
    preferred_currency_code: "PEN",
    is_exchange_rate_provisional: false,
    need_override: null,
    scheduled_payment_ref: null,
    balance_adjustment_type: null,
    transfer_pair_id: null,
    split_expense_id: null,
    split_lines_raw: null,
  });
  w.supabase.seed("tx_items", user, [
    tx("aaaaaaaa-0000-4000-8000-000000000001", -40, CAT, ACC),
    tx("aaaaaaaa-0000-4000-8000-000000000002", -10, null, ACC),
    // Sin cuenta: el chat lo cuenta, Estadísticas del iPhone no (`filterForTrends`).
    tx("aaaaaaaa-0000-4000-8000-000000000003", -500, CAT, null),
  ]);
  w.supabase.seed("scheduled_payments", user, [
    {
      sync_id: PAY,
      name: "Netflix",
      amount: 44.9,
      currency_code: "PEN",
      transaction_type: "expense",
      is_recurring: true,
      recurrence_type: "monthly",
      recurrence_interval: 1,
      next_due_date: new Date(now.getTime() + 3 * 86_400_000).toISOString(),
      end_date: null,
      payment_category: "subscription",
      is_active: true,
      last_paid_date: null,
      subcategory_ref: null,
      account_ref: ACC,
      created_at: "2026-01-01T12:00:00Z",
      day_of_month: null,
      selected_weekdays: null,
      yearly_month: null,
      yearly_day: null,
      skipped_dates_raw: [],
    },
  ]);
}

async function postJson(b: Browser, path: string, body: unknown, headers: Record<string, string> = {}) {
  const raw = JSON.stringify(body);
  return b.request(path, {
    method: "POST",
    body: raw,
    headers: { "Content-Type": "application/json", "Content-Length": String(new TextEncoder().encode(raw).length), Origin: BASE, ...headers },
  });
}

async function device(w: World, path: string, token: string, body?: unknown) {
  const headers = new Headers({ Authorization: `Bearer ${token}`, "User-Agent": "Yala/2.3 iPhone" });
  let raw: string | undefined;
  if (body !== undefined) {
    raw = JSON.stringify(body);
    headers.set("Content-Type", "application/json");
    headers.set("Content-Length", String(new TextEncoder().encode(raw).length));
  }
  return w.call(new Request(`${BASE}${path}`, { method: body === undefined ? "GET" : "POST", headers, body: raw }));
}

describe("lote 2: Estadísticas y Pagos planificados", () => {
  it("Estadísticas: las tres pestañas en una lectura, sin los movimientos sin cuenta, con el token de solo lectura", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    seed(w, ana);
    await w.socialLogin(ana);
    w.supabase.calls.length = 0;
    const res = await w.browser.request("/api/estadisticas?periodo=mes_actual");
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      resumen: { gastos: number; top_categorias: { categoria: string | null; porcentaje: number }[]; gasto_mas_alto: { importe: number } | null };
      distribucion: { total: number; categorias: { categoria: string | null; importe: number; porcentaje: number }[] };
      tendencias: { mes: string; gastos: number }[];
    };
    expect(body.resumen.gastos).toBe(50);
    expect(body.resumen.gasto_mas_alto?.importe).toBe(40);
    expect(body.distribucion.total).toBe(50);
    expect(body.distribucion.categorias).toEqual([
      expect.objectContaining({ categoria: "Comida", importe: 40, porcentaje: 80 }),
      expect.objectContaining({ categoria: null, importe: 10, porcentaje: 20 }),
    ]);
    expect(body.tendencias.length).toBe(6);
    expect(body.tendencias.at(-1)?.gastos).toBe(50);
    for (const c of w.supabase.calls.filter((x) => x.path.startsWith("/rest/v1/"))) {
      const claims = JSON.parse(atob(c.auth!.replace("Bearer ", "").split(".")[1]!.replace(/-/g, "+").replace(/_/g, "/"))) as { role: string; client_id: string };
      expect(claims.role).toBe("yala_mcp_reader");
      expect(claims.client_id).toBe(WEB_CLIENT);
    }
  });

  it("Estadísticas: un período desconocido es 400; sin sesión, 401", async () => {
    const w = await world();
    expect((await w.browser.request("/api/estadisticas")).status).toBe(401);
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    expect((await w.browser.request("/api/estadisticas?periodo=siempre")).status).toBe(400);
    expect((await w.browser.request("/api/estadisticas?periodo=anio_actual")).status).toBe(200);
  });

  it("Pagos: el próximo cobro dentro de 30 días y la suscripción con su equivalente mensual", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    seed(w, ana);
    await w.socialLogin(ana);
    const res = await w.browser.request("/api/pagos");
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      proximos: { id: string; en_dias: number; importe: number }[];
      total_gastos: number;
      suscripciones: { id: string }[];
      suscripciones_mensual: number;
    };
    expect(body.proximos).toEqual([expect.objectContaining({ id: PAY, en_dias: 3, importe: 44.9 })]);
    expect(body.total_gastos).toBe(44.9);
    expect(body.suscripciones.map((s) => s.id)).toEqual([PAY]);
    expect(body.suscripciones_mensual).toBe(44.9);
  });
});

/** El navegador pide un código; devuelve el código tal cual lo pinta la página. */
async function qrStart(b: Browser, opts: { compartido?: boolean; turnstile?: string } = {}) {
  const res = await postJson(b, "/auth/qr/start", { turnstile: opts.turnstile ?? TURNSTILE_OK, compartido: opts.compartido ?? false }, { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15" });
  return { res, body: (await res.json()) as { codigo?: string; url?: string; expira?: number; error?: string } };
}

async function qrState(b: Browser, codigo: string) {
  const res = await postJson(b, "/auth/qr/estado", { codigo });
  return { res, body: (await res.json()) as { estado: string } };
}

describe("lote 2: entrar con el iPhone por QR", () => {
  async function ready() {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    const iphone = await w.supabase.appToken(ana);
    return { w, ana, iphone };
  }

  it("de punta a punta: el navegador pide, el iPhone lee y aprueba, el navegador entra con una sesión de SOLO LECTURA", async () => {
    const { w, iphone } = await ready();
    const { res, body } = await qrStart(w.browser);
    expect(res.status).toBe(200);
    expect(body.codigo).toMatch(/^[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}$/);
    expect(body.url).toBe(`${BASE}/v/${body.codigo!.replace("-", "")}`);
    expect((await qrState(w.browser, body.codigo!)).body.estado).toBe("esperando");

    // El iPhone lee el QR (la dirección entera) y ve qué navegador lo pidió.
    const peek = await device(w, `/api/dispositivo/vincular?codigo=${encodeURIComponent(body.url!)}`, iphone);
    expect(peek.status).toBe(200);
    expect(await peek.json()).toEqual(expect.objectContaining({ codigo: body.codigo, navegador: "Safari", sistema: "Mac" }));
    expect((await qrState(w.browser, body.codigo!)).body.estado).toBe("visto");

    const ok = await device(w, "/api/dispositivo/vincular", iphone, { codigo: body.codigo });
    expect(ok.status).toBe(200);

    const done = await qrState(w.browser, body.codigo!);
    expect(done.body.estado).toBe("dentro");
    const me = await w.browser.request("/api/me");
    expect(me.status).toBe(200);
    // La sesión que se guarda es la de la web (rol de solo lectura), no la del iPhone, que sigue viva.
    w.supabase.calls.length = 0;
    await w.browser.request("/api/panel");
    const reads = w.supabase.calls.filter((c) => c.path.startsWith("/rest/v1/"));
    expect(reads.length).toBeGreaterThan(0);
    for (const c of reads) {
      const claims = JSON.parse(atob(c.auth!.replace("Bearer ", "").split(".")[1]!.replace(/-/g, "+").replace(/_/g, "/"))) as { role: string; client_id: string };
      expect(claims.role).toBe("yala_mcp_reader");
      expect(claims.client_id).toBe(WEB_CLIENT);
    }
    expect((await device(w, "/api/dispositivo/sesiones", iphone)).status).toBe(200);
    // La cookie del QR se fue: el código no se puede volver a canjear.
    expect([...w.browser.jar.keys()]).not.toContain("__Host-yala-web-qr");
  });

  it("otro navegador con el mismo código no entra: hace falta la cookie del que lo pidió", async () => {
    const { w, iphone } = await ready();
    const { body } = await qrStart(w.browser);
    const intruso = w.newBrowser();
    // El intruso pide su propio código para tener una cookie de QR, y pregunta por el de la víctima.
    await qrStart(intruso);
    await device(w, `/api/dispositivo/vincular?codigo=${body.codigo}`, iphone);
    expect((await device(w, "/api/dispositivo/vincular", iphone, { codigo: body.codigo })).status).toBe(200);
    expect((await qrState(intruso, body.codigo!)).body.estado).toBe("caducado");
    expect((await intruso.request("/api/me")).status).toBe(401);
    // La víctima sí entra (el intruso no le gastó la aprobación).
    expect((await qrState(w.browser, body.codigo!)).body.estado).toBe("dentro");
  });

  it("un código leído por una cuenta no lo puede aprobar otra", async () => {
    const { w, iphone } = await ready();
    const bea = w.supabase.addUser({ email: "bea@yala.test" });
    const iphoneBea = await w.supabase.appToken(bea);
    const { body } = await qrStart(w.browser);
    expect((await device(w, `/api/dispositivo/vincular?codigo=${body.codigo}`, iphone)).status).toBe(200);
    expect((await device(w, `/api/dispositivo/vincular?codigo=${body.codigo}`, iphoneBea)).status).toBe(404);
    expect((await device(w, "/api/dispositivo/vincular", iphoneBea, { codigo: body.codigo })).status).toBe(404);
  });

  it("sin Turnstile no hay código; sin Origin, tampoco", async () => {
    const { w } = await ready();
    expect((await qrStart(w.browser, { turnstile: "bot" })).res.status).toBe(403);
    const raw = JSON.stringify({ turnstile: TURNSTILE_OK });
    const noOrigin = await w.browser.request("/auth/qr/start", { method: "POST", body: raw, headers: { "Content-Type": "application/json", "Content-Length": String(raw.length) } });
    expect(noOrigin.status).toBe(403);
  });

  it("el código caduca a los 60 s; se renueva sin Turnstile hasta 10 minutos, y no después", async () => {
    const { w, iphone } = await ready();
    const first = await qrStart(w.browser);
    w.clock.now += QR_CODE_TTL_SECONDS + 1;
    expect((await device(w, `/api/dispositivo/vincular?codigo=${first.body.codigo}`, iphone)).status).toBe(404);
    let codigo = first.body.codigo!;
    const renew = await postJson(w.browser, "/auth/qr/renovar", { codigo });
    expect(renew.status).toBe(200);
    codigo = ((await renew.json()) as { codigo: string }).codigo;
    // El viejo ya no existe; el nuevo sí.
    expect((await qrState(w.browser, first.body.codigo!)).body.estado).toBe("caducado");
    expect((await qrState(w.browser, codigo)).body.estado).toBe("esperando");
    // Otro navegador no puede renovar un código ajeno.
    expect((await postJson(w.newBrowser(), "/auth/qr/renovar", { codigo })).status).toBe(410);
    w.clock.now += QR_CHAIN_SECONDS;
    expect((await postJson(w.browser, "/auth/qr/renovar", { codigo })).status).toBe(410);
  });

  it("desde que el iPhone lo lee, tiene 2 minutos para confirmar aunque el código ya «cambiara»", async () => {
    const { w, iphone } = await ready();
    const { body } = await qrStart(w.browser);
    await device(w, `/api/dispositivo/vincular?codigo=${body.codigo}`, iphone);
    w.clock.now += QR_CONFIRM_SECONDS - 5;
    expect((await device(w, "/api/dispositivo/vincular", iphone, { codigo: body.codigo })).status).toBe(200);
    expect((await qrState(w.browser, body.codigo!)).body.estado).toBe("dentro");
  });

  it("un código leído no se renueva (el navegador sigue esperando al iPhone)", async () => {
    const { w, iphone } = await ready();
    const { body } = await qrStart(w.browser);
    await device(w, `/api/dispositivo/vincular?codigo=${body.codigo}`, iphone);
    expect((await postJson(w.browser, "/auth/qr/renovar", { codigo: body.codigo })).status).toBe(410);
    expect((await qrState(w.browser, body.codigo!)).body.estado).toBe("visto");
  });

  it("una cuenta sin la nube no aprueba (409) y el navegador no entra", async () => {
    const w = await world();
    const leo = w.supabase.addUser({ email: "leo@yala.test", kind: null });
    const iphone = await w.supabase.appToken(leo);
    const { body } = await qrStart(w.browser);
    const res = await device(w, "/api/dispositivo/vincular", iphone, { codigo: body.codigo });
    expect(res.status).toBe(409);
    expect(await res.json()).toEqual({ error: "sin_nube" });
    expect((await qrState(w.browser, body.codigo!)).body.estado).toBe("visto");
  });

  it("solo el token de la APP aprueba: el de la web o el del conector no sirven", async () => {
    const { w, ana } = await ready();
    await w.socialLogin(ana, { browser: w.newBrowser() });
    const { body } = await qrStart(w.browser);
    // Un token de cliente OAuth (el de la web) lleva `client_id`: la ruta del iPhone lo rechaza.
    const webToken = await w.supabase.clientToken(ana, WEB_CLIENT);
    expect((await device(w, "/api/dispositivo/vincular", webToken, { codigo: body.codigo })).status).toBe(401);
  });

  it("el equipo compartido viaja con el código y la sesión abierta lo es", async () => {
    const { w, iphone } = await ready();
    const { body } = await qrStart(w.browser, { compartido: true });
    await device(w, "/api/dispositivo/vincular", iphone, { codigo: body.codigo });
    expect((await qrState(w.browser, body.codigo!)).body.estado).toBe("dentro");
    const me = (await (await w.browser.request("/api/me")).json()) as { equipoCompartido: boolean };
    expect(me.equipoCompartido).toBe(true);
  });

  it("el código se escribe a mano: sin guion, en minúsculas o la dirección del QR", () => {
    expect(normalizeCode("k7q4-md2x")).toBe("K7Q4MD2X");
    expect(normalizeCode(" K7Q4 MD2X ")).toBe("K7Q4MD2X");
    expect(normalizeCode("K7q4'MD2X")).toBe("K7Q4MD2X"); // un teclado que cambia el guion por un apóstrofo
    expect(normalizeCode(`${BASE}/v/K7Q4MD2X`)).toBe("K7Q4MD2X");
    expect(normalizeCode("K7Q4MD2")).toBeNull();
    expect(normalizeCode("K7Q4MD2O")).toBeNull(); // la O no existe en el alfabeto
    expect(normalizeCode(42)).toBeNull();
  });
});
