/**
 * Lote 1 (la beta): mirar (Panel, Registros, Bandeja), apuntar a la cola común y las sesiones web, cerrables desde la
 * propia web y desde el iPhone.
 */
import { describe, expect, it } from "vitest";
import { BASE, WEB_CLIENT, world, type Browser, type World } from "./fakes";
import { describeBrowser } from "../src/worker/ua";
import { WEB_DRAFTS_PER_DAY } from "../src/worker/drafts";

const ACC = "11111111-1111-4111-8111-111111111111";
const ACC_USD = "22222222-2222-4222-8222-222222222222";
const CAT = "33333333-3333-4333-8333-333333333333";
const SUB = "44444444-4444-4444-8444-444444444444";

/** Una cuenta con dos cuentas (soles y dólares), una categoría y tres movimientos de este mes. */
function seedAccount(w: World, user: Parameters<World["supabase"]["seed"]>[1]) {
  const now = new Date(w.clock.now * 1000);
  const day = now.toISOString().slice(0, 10);
  w.supabase.seed("accounts", user, [
    { sync_id: ACC, name: "BCP Ahorros", currency_code: "PEN", type: "bank", is_archived: false, exclude_from_statistics: false, is_system_account: false, parent_account_id: null },
    { sync_id: ACC_USD, name: "BBVA dólares", currency_code: "USD", type: "bank", is_archived: false, exclude_from_statistics: false, is_system_account: false, parent_account_id: null },
  ]);
  w.supabase.seed("categories", user, [{ sync_id: CAT, name: "Comida", is_income: false, is_visible: true, sort_order: 1 }]);
  w.supabase.seed("subcategories", user, [
    { sync_id: SUB, name: "Restaurantes", category_ref: CAT, nature_raw_value: "optional", is_visible: true, sort_order: 1, is_system: false, is_default_seed: false },
  ]);
  w.supabase.seed("user_preferences", user, [
    { key: "defaultCurrencyCode", value: "PEN" },
    { key: "timeZoneIdentifier", value: "America/Lima" },
  ]);
  const tx = (id: string, amount: number, account: string, currency: string, note: string, hoursAgo: number) => ({
    sync_id: id,
    date: new Date(now.getTime() - hoursAgo * 3600_000).toISOString(),
    local_day: day,
    amount,
    currency_code: currency,
    note,
    category_ref: amount < 0 ? CAT : null,
    subcategory_ref: amount < 0 ? SUB : null,
    account_ref: account,
    tag_refs: [],
    amount_in_preferred_currency: currency === "PEN" ? amount : null,
    preferred_currency_code: currency === "PEN" ? "PEN" : null,
    is_exchange_rate_provisional: false,
    need_override: null,
    scheduled_payment_ref: null,
    balance_adjustment_type: null,
    transfer_pair_id: null,
    split_expense_id: null,
    split_lines_raw: null,
  });
  w.supabase.seed("tx_items", user, [
    tx("aaaaaaaa-0000-4000-8000-000000000001", 1000, ACC, "PEN", "Sueldo", 3),
    tx("aaaaaaaa-0000-4000-8000-000000000002", -42.5, ACC, "PEN", "Almuerzo", 2),
    tx("aaaaaaaa-0000-4000-8000-000000000003", 100, ACC_USD, "USD", "Saldo inicial", 1),
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

async function deviceCall(w: World, path: string, token: string | null, init: { method?: string; body?: unknown } = {}) {
  const headers = new Headers();
  if (token) headers.set("Authorization", `Bearer ${token}`);
  let body: string | undefined;
  if (init.body !== undefined) {
    body = JSON.stringify(init.body);
    headers.set("Content-Type", "application/json");
    headers.set("Content-Length", String(new TextEncoder().encode(body).length));
  }
  return w.call(new Request(`${BASE}${path}`, { method: init.method ?? "GET", headers, body }));
}

const draft = (over: Record<string, unknown> = {}) => ({
  tipo: "gasto",
  importe: 25,
  divisa: "PEN",
  descripcion: "Almuerzo",
  fecha: "2027-01-15",
  cuenta: ACC,
  subcategoria: SUB,
  ...over,
});

describe("mirar: Panel, Registros y Bandeja", () => {
  it("el Panel trae saldos de hoy, el mes y los últimos registros, calculados por el núcleo compartido", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    seedAccount(w, ana);
    await w.socialLogin(ana);
    const res = await w.browser.request("/api/panel");
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      cuentas: { cuentas: { id: string; saldo: number; divisa: string }[]; total: { divisa: string } };
      mes: { ingresos: number; gastos: number; divisa: string };
      ultimos: { movimientos: { nota: string }[] };
    };
    const pen = body.cuentas.cuentas.find((c) => c.id === ACC)!;
    expect(pen.saldo).toBe(957.5);
    expect(body.cuentas.cuentas.find((c) => c.id === ACC_USD)!.saldo).toBe(100);
    expect(body.cuentas.total.divisa).toBe("PEN");
    expect(body.mes.divisa).toBe("PEN");
    expect(body.mes.gastos).toBe(42.5);
    expect(body.ultimos.movimientos.length).toBe(3);
    expect(res.headers.get("Cache-Control")).toBe("no-store");
  });

  it("lee con el token de SOLO LECTURA de la web, nunca con otro", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    seedAccount(w, ana);
    await w.socialLogin(ana);
    w.supabase.calls.length = 0;
    await w.browser.request("/api/panel");
    const reads = w.supabase.calls.filter((c) => c.path.startsWith("/rest/v1/"));
    expect(reads.length).toBeGreaterThan(0);
    for (const c of reads) {
      const claims = JSON.parse(atob(c.auth!.replace("Bearer ", "").split(".")[1]!.replace(/-/g, "+").replace(/_/g, "/"))) as { role: string; client_id: string };
      expect(claims.role).toBe("yala_mcp_reader");
      expect(claims.client_id).toBe(WEB_CLIENT);
    }
  });

  it("sin sesión, 401; con una fecha mal escrita en Registros, 400", async () => {
    const w = await world();
    expect((await w.browser.request("/api/panel")).status).toBe(401);
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    seedAccount(w, ana);
    await w.socialLogin(ana);
    expect((await w.browser.request("/api/registros")).status).toBe(200);
    expect((await w.browser.request("/api/registros?desde=ayer")).status).toBe(400);
  });

  it("la Bandeja enseña lo pendiente en el iPhone y lo enviado que aún no recogió", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    w.supabase.seed("inbox_drafts", ana, [
      { sync_id: "b1", note: "Tambo", amount: -8.5, status_raw: "pending", source_type_raw: "applePay" },
      { sync_id: "b2", note: "Ya aprobado", amount: -3, status_raw: "approved", source_type_raw: "voice" },
    ]);
    await w.socialLogin(ana);
    w.clock.now = Date.UTC(2027, 0, 15, 15) / 1000;
    expect((await postJson(w.browser, "/api/borradores", draft())).status).toBe(201);
    const body = (await (await w.browser.request("/api/bandeja")).json()) as { pendientes: { sync_id: string }[]; enviados: { descripcion: string; importe: number }[] };
    expect(body.pendientes.map((p) => p.sync_id)).toEqual(["b1"]);
    expect(body.enviados).toEqual([expect.objectContaining({ descripcion: "Almuerzo", importe: 25 })]);
  });
});

describe("apuntar: la cola común de borradores (D9)", () => {
  async function ready() {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    w.clock.now = Date.UTC(2027, 0, 15, 15) / 1000;
    return { w, ana };
  }

  it("deja la fila en mail_drafts con la forma del correo y source web, para el iPhone de ESA cuenta", async () => {
    const { w, ana } = await ready();
    const res = await postJson(w.browser, "/api/borradores", draft({ descripcion: "  Almuerzo   con Ana " }));
    expect(res.status).toBe(201);
    const rows = w.d1.rows();
    expect(rows.length).toBe(1);
    expect(rows[0]!.user_id).toBe(ana.id);
    expect(rows[0]!.payload).toEqual({
      kind: "expense",
      amount: 25,
      currency: "PEN",
      merchant: "Almuerzo con Ana",
      date: "2027-01-15",
      bank: null,
      account_last4: null,
      source: "web",
      account_ref: ACC,
      subcategory_ref: SUB,
    });
  });

  it("valida cada campo y dice cuál falla", async () => {
    const { w } = await ready();
    const bad: [Record<string, unknown>, string][] = [
      [{ importe: 0 }, "importe"],
      [{ importe: -5 }, "importe"],
      [{ importe: "25" }, "importe"],
      [{ divisa: "soles" }, "divisa"],
      [{ fecha: "2027-02-30" }, "fecha"],
      [{ fecha: "2027-01-20" }, "fecha"],
      [{ cuenta: "no-es-un-id" }, "cuenta"],
      [{ subcategoria: 7 }, "subcategoria"],
      [{ descripcion: "x".repeat(121) }, "descripcion"],
      [{ importe: 0.001 }, "importe"],
      [{ divisa: "XYZ" }, "divisa"],
      [{ fecha: "2027-01-17" }, "fecha"],
      [{ tipo: "transferencia" }, "tipo"],
    ];
    for (const [over, campo] of bad) {
      const res = await postJson(w.browser, "/api/borradores", draft(over));
      expect(res.status, JSON.stringify(over)).toBe(400);
      expect(((await res.json()) as { campo: string }).campo).toBe(campo);
    }
    expect(w.d1.rows().length).toBe(0);
    // Ingreso, sin cuenta ni subcategoría ni descripción: vale.
    expect((await postJson(w.browser, "/api/borradores", draft({ tipo: "ingreso", cuenta: null, subcategoria: null, descripcion: "" }))).status).toBe(201);
    expect(w.d1.rows()[0]!.payload).toMatchObject({ kind: "income", merchant: null, account_ref: null, subcategory_ref: null });
  });

  it("quita de la descripción los controles y las marcas de dirección (U+202E)", async () => {
    const { w } = await ready();
    expect((await postJson(w.browser, "/api/borradores", draft({ descripcion: "Al\u202Emuerzo\u0007" }))).status).toBe(201);
    expect(w.d1.rows()[0]!.payload.merchant).toBe("Almuerzo");
  });

  it("lo enviado hace más de 30 días ya no sale como «esperando»: el iPhone ya no lo recibiría", async () => {
    const { w } = await ready();
    expect((await postJson(w.browser, "/api/borradores", draft())).status).toBe(201);
    // Usándola a mitad de camino, la sesión sigue viva (30 días sin uso la cierran).
    w.clock.now += 20 * 86_400;
    expect((await w.browser.request("/api/me")).status).toBe(200);
    w.clock.now += 11 * 86_400;
    const res = await w.browser.request("/api/bandeja");
    expect(res.status).toBe(200);
    const body = (await res.json()) as { enviados: unknown[] };
    expect(body.enviados).toEqual([]);
  });

  it("el cupo no se reinicia cuando el iPhone recoge (el ack borra de la cola lo recogido)", async () => {
    const { w } = await ready();
    for (let i = 0; i < WEB_DRAFTS_PER_DAY; i++) expect((await postJson(w.browser, "/api/borradores", draft())).status).toBe(201);
    w.d1.db.exec("DELETE FROM mail_drafts");
    expect((await postJson(w.browser, "/api/borradores", draft())).status).toBe(429);
  });

  it(`tope de ${WEB_DRAFTS_PER_DAY} al día por cuenta; al día siguiente se puede otra vez`, async () => {
    const { w } = await ready();
    for (let i = 0; i < WEB_DRAFTS_PER_DAY; i++) expect((await postJson(w.browser, "/api/borradores", draft())).status).toBe(201);
    const over = await postJson(w.browser, "/api/borradores", draft());
    expect(over.status).toBe(429);
    expect(((await over.json()) as { error: string }).error).toBe("tope_diario");
    w.clock.now += 86_401;
    expect((await postJson(w.browser, "/api/borradores", draft({ fecha: "2027-01-16" }))).status).toBe(201);
  });

  it("sin cookie no apunta, y un formulario de otro sitio tampoco", async () => {
    const { w } = await ready();
    const stranger = w.newBrowser();
    expect((await postJson(stranger, "/api/borradores", draft())).status).toBe(401);
    expect((await postJson(w.browser, "/api/borradores", draft(), { Origin: "https://otro.test" })).status).toBe(403);
    const raw = JSON.stringify(draft());
    const noLen = await w.browser.request("/api/borradores", { method: "POST", body: raw, headers: { "Content-Type": "application/json", Origin: BASE } });
    expect(noLen.status).toBe(400);
    const asForm = await w.browser.request("/api/borradores", { form: { importe: "25" } });
    expect(asForm.status).toBe(400);
    expect(w.d1.rows().length).toBe(0);
  });
});

describe("sesiones web: ver y cerrar", () => {
  async function twoBrowsers() {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    const mac = w.browser;
    await w.socialLogin(ana, { browser: mac });
    const otro = w.newBrowser();
    await w.socialLogin(ana, { browser: otro, compartido: true });
    return { w, ana, mac, otro };
  }

  it("la lista enseña las dos, marca esta y no lleva tokens ni la clave del KV", async () => {
    const { w, mac } = await twoBrowsers();
    const res = await mac.request("/api/sesiones");
    const raw = await res.text();
    const { sesiones } = JSON.parse(raw) as { sesiones: { id: string; esta: boolean; equipoCompartido: boolean }[] };
    expect(sesiones.length).toBe(2);
    expect(sesiones.filter((s) => s.esta).length).toBe(1);
    expect(sesiones.find((s) => !s.esta)!.equipoCompartido).toBe(true);
    expect(raw).not.toContain("eyJ");
    expect(raw).not.toMatch(/"k"|s:[0-9a-f]{64}|"sid"/);
    expect(w.kv.sessionCount()).toBe(2);
  });

  it("cerrar la otra la deja sin datos al momento y cierra su sesión de Supabase", async () => {
    const { w, ana, mac, otro } = await twoBrowsers();
    expect(w.supabase.openSessions(ana.id).web).toBe(2);
    const { sesiones } = (await (await mac.request("/api/sesiones")).json()) as { sesiones: { id: string; esta: boolean }[] };
    const other = sesiones.find((s) => !s.esta)!;
    const res = await postJson(mac, "/api/sesiones/cerrar", { id: other.id });
    expect(((await res.json()) as { cerradas: number }).cerradas).toBe(1);
    expect(w.supabase.openSessions(ana.id).web).toBe(1);
    expect(w.kv.sessionCount()).toBe(1);
    expect((await otro.request("/api/panel")).status).toBe(401);
    expect((await mac.request("/api/me")).status).toBe(200);
  });

  it("aunque el KV aún devuelva la sesión cerrada (propagación), la pestaña deja de leer: manda Supabase", async () => {
    const { w, mac, otro } = await twoBrowsers();
    const saved = new Map(w.kv.data);
    const { sesiones } = (await (await mac.request("/api/sesiones")).json()) as { sesiones: { id: string; esta: boolean }[] };
    await postJson(mac, "/api/sesiones/cerrar", { id: sesiones.find((s) => !s.esta)!.id });
    // Simula un KV que todavía sirve la copia vieja en el punto de presencia de la otra pestaña.
    for (const [k, v] of saved) if (k.startsWith("s:") && !w.kv.data.has(k)) w.kv.data.set(k, v);
    expect((await otro.request("/api/panel")).status).toBe(401);
  });

  it("si cerrar en Supabase falla, la pestaña cerrada tampoco lee: la lista manda (no hay sesión fantasma)", async () => {
    const { w, mac, otro } = await twoBrowsers();
    const saved = new Map(w.kv.data);
    const { sesiones } = (await (await mac.request("/api/sesiones")).json()) as { sesiones: { id: string; esta: boolean }[] };
    w.supabase.closeRpcDown = true;
    await postJson(mac, "/api/sesiones/cerrar", { id: sesiones.find((s) => !s.esta)!.id });
    // Otro punto de presencia aún sirve la copia vieja de la sesión, y su sesión de Supabase sigue viva.
    for (const [k, v] of saved) if (k.startsWith("s:") && !w.kv.data.has(k)) w.kv.data.set(k, v);
    expect((await otro.request("/api/panel")).status).toBe(401);
    expect((await otro.request("/api/panel")).status).toBe(401);
    expect(((await (await mac.request("/api/sesiones")).json()) as { sesiones: unknown[] }).sesiones.length).toBe(1);
  });

  it("una sesión sin id en la lista (las del lote 0) se cierra y pide volver a entrar", async () => {
    const { w, ana, mac } = await twoBrowsers();
    const index = w.env.SESSION_INDEX as unknown as { byUser: Map<string, Map<string, unknown>> };
    index.byUser.get(ana.id)!.clear();
    expect((await mac.request("/api/me")).status).toBe(401);
    expect(w.kv.sessionCount()).toBe(1);
  });

  it("esta misma no se cierra con «Cerrar» (para eso está «Salir»); «cerrar las demás» deja solo esta", async () => {
    const { w, ana, mac, otro } = await twoBrowsers();
    const tercero = w.newBrowser();
    await w.socialLogin(ana, { browser: tercero });
    const { sesiones } = (await (await mac.request("/api/sesiones")).json()) as { sesiones: { id: string; esta: boolean }[] };
    expect((await postJson(mac, "/api/sesiones/cerrar", { id: sesiones.find((s) => s.esta)!.id })).status).toBe(409);
    const res = await postJson(mac, "/api/sesiones/cerrar-otras", {});
    expect(((await res.json()) as { cerradas: number }).cerradas).toBe(2);
    expect((await otro.request("/api/me")).status).toBe(401);
    expect((await tercero.request("/api/me")).status).toBe(401);
    expect((await mac.request("/api/me")).status).toBe(200);
    expect(w.supabase.openSessions(ana.id).web).toBe(1);
  });

  it("una sesión de OTRA cuenta no aparece ni se puede cerrar", async () => {
    const { w, mac } = await twoBrowsers();
    const beto = w.supabase.addUser({ email: "beto@yala.test" });
    const ajeno = w.newBrowser();
    await w.socialLogin(beto, { browser: ajeno });
    const betoList = (await (await ajeno.request("/api/sesiones")).json()) as { sesiones: { id: string }[] };
    const res = await postJson(mac, "/api/sesiones/cerrar", { id: betoList.sesiones[0]!.id });
    expect(((await res.json()) as { cerradas: number }).cerradas).toBe(0);
    expect((await ajeno.request("/api/me")).status).toBe(200);
    expect(((await (await mac.request("/api/sesiones")).json()) as { sesiones: unknown[] }).sesiones.length).toBe(2);
  });

  it("«Salir» también la quita de la lista", async () => {
    const { mac, otro } = await twoBrowsers();
    await otro.request("/auth/logout", { form: {} });
    const { sesiones } = (await (await mac.request("/api/sesiones")).json()) as { sesiones: unknown[] };
    expect(sesiones.length).toBe(1);
  });
});

describe("el iPhone: «Navegadores conectados»", () => {
  it("con el token de la app ve las sesiones web de su cuenta, sin ninguna marcada como «esta»", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    const res = await deviceCall(w, "/api/dispositivo/sesiones", await w.supabase.appToken(ana));
    expect(res.status).toBe(200);
    const { sesiones } = (await res.json()) as { sesiones: { esta: boolean }[] };
    expect(sesiones.length).toBe(1);
    expect(sesiones[0]!.esta).toBe(false);
  });

  it("cierra una o todas, y la pestaña abierta deja de leer", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    const otro = w.newBrowser();
    await w.socialLogin(ana, { browser: otro });
    const app = await w.supabase.appToken(ana);
    const { sesiones } = (await (await deviceCall(w, "/api/dispositivo/sesiones", app)).json()) as { sesiones: { id: string }[] };
    expect((await deviceCall(w, "/api/dispositivo/sesiones/cerrar", app, { method: "POST", body: { id: sesiones[0]!.id } })).status).toBe(200);
    expect(w.supabase.openSessions(ana.id).web).toBe(1);
    const all = await deviceCall(w, "/api/dispositivo/sesiones/cerrar-todas", app, { method: "POST", body: {} });
    expect(((await all.json()) as { cerradas: number }).cerradas).toBe(1);
    expect(w.supabase.openSessions(ana.id).web).toBe(0);
    expect(w.supabase.openSessions(ana.id).normal).toBe(1); // la sesión de la app sigue: solo se cierran las web
    expect((await w.browser.request("/api/panel")).status).toBe(401);
    expect((await otro.request("/api/panel")).status).toBe(401);
  });

  it("el token de una sesión de la app ya cerrada no vale, aunque su firma siga vigente", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    const app = await w.supabase.appToken(ana);
    expect((await deviceCall(w, "/api/dispositivo/sesiones", app)).status).toBe(200);
    for (const [id, s] of w.supabase.sessions) if (!s.clientId) w.supabase.sessions.delete(id);
    expect((await deviceCall(w, "/api/dispositivo/sesiones", app)).status).toBe(401);
  });

  it("no vale el token de la web (solo lectura), ni la cookie sola, ni nada", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    await w.socialLogin(ana);
    const webSession = [...w.supabase.sessions.values()].find((s) => s.clientId === WEB_CLIENT)!;
    const webToken = await (w.supabase as unknown as { sign(s: unknown): Promise<string> }).sign(webSession);
    expect((await deviceCall(w, "/api/dispositivo/sesiones", webToken)).status).toBe(401);
    expect((await deviceCall(w, "/api/dispositivo/sesiones", null)).status).toBe(401);
    expect((await w.browser.request("/api/dispositivo/sesiones")).status).toBe(401);
    expect((await deviceCall(w, "/api/dispositivo/sesiones", "a.b.c")).status).toBe(401);
  });
});

describe("navegador y sistema del User-Agent", () => {
  it("reconoce los comunes y no confunde Edge ni Chrome con Safari", () => {
    expect(describeBrowser("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36")).toEqual({ navegador: "Chrome", sistema: "Mac" });
    expect(describeBrowser("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0")).toEqual({ navegador: "Edge", sistema: "Windows" });
    expect(describeBrowser("Mozilla/5.0 (iPhone; CPU iPhone OS 27_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.2 Mobile/15E148 Safari/604.1")).toEqual({ navegador: "Safari", sistema: "iPhone" });
    expect(describeBrowser("Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0")).toEqual({ navegador: "Firefox", sistema: "Linux" });
    expect(describeBrowser(null)).toEqual({ navegador: "", sistema: "" });
  });
});
