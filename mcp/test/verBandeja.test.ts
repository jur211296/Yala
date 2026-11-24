/**
 * Lote 5 de «Bandeja sin duplicados»: `ver_bandeja`, la `referencia` y el aviso de posible duplicado, del lado del
 * conector. La regla y la cola de verdad se prueban en el gateway (`gateway/test/connector.dedup.test.ts`); aquí, lo que
 * pone el conector. Lo que fija, por gravedad si se rompiera:
 *  - `ver_bandeja` solo lee las columnas de Yala web (nunca `raw_text`), deja fuera Grupos, y sale con la misma
 *    condición que `apuntar_movimiento` (cola enlazada + permiso que lo nombra);
 *  - `apuntar_movimiento` manda al gateway los pendientes de la Bandeja y lo guardado de ±3 días (sin transferencias,
 *    ajustes ni Grupos), y con `forzar` no manda nada que comparar;
 *  - `posible_duplicado` y `ya_apuntado` llegan a la IA como respuestas normales, con lo encontrado en palabras, no como
 *    errores; y ninguna de las dos dice que se creó algo.
 */
import { describe, expect, it } from "vitest";
import { account, category, subcategory, tx, uuid } from "./fixtures";
import { callTool, connect, rpc, world } from "./helpers";
import { USER_A } from "./supabase-fake";
import { FakeQueue } from "./fakeQueue";

const BCP = uuid(8001);
const GRUPO = uuid(8002);
const COMIDA = uuid(8101);
const CAFES = uuid(8201);

const NOW = () => new Date("2026-11-15T20:00:00Z"); // 15:00 en Lima

function inbox(p: Record<string, unknown>) {
  return {
    sync_id: uuid(),
    note: "",
    amount: -10,
    date: "2026-11-15T18:05:00Z",
    cached_currency_code: "PEN",
    cached_account_name: null,
    cached_subcategory_name: null,
    source_type_raw: "applePay",
    evidence: null,
    created_at: "2026-11-15T18:05:10Z",
    needs_user_input: [],
    status_raw: "pending",
    deleted: false,
    ...p,
  };
}

function rows(extra: Record<string, unknown[]> = {}) {
  return {
    accounts: [account({ sync_id: BCP, name: "BCP Visa" }), account({ sync_id: GRUPO, name: "Viaje a Cusco", is_system_account: true })],
    categories: [category({ sync_id: COMIDA, name: "Comida" })],
    subcategories: [subcategory({ sync_id: CAFES, name: "Cafés", category_ref: COMIDA })],
    tags: [],
    user_preferences: [
      { key: "defaultCurrencyCode", value: "PEN" },
      { key: "timeZoneIdentifier", value: "America/Lima" },
    ],
    inbox_drafts: [
      inbox({ note: "Starbucks", amount: -42.5, cached_account_name: "BCP Visa", evidence: "Starbucks" }),
      inbox({ note: "Sueldo", amount: 3500, source_type_raw: "emailAlert", evidence: "BCP · ****4321", needs_user_input: ["subcategory"] }),
      inbox({ note: "Cena del grupo", amount: -80, source_type_raw: "groupExpense" }),
      inbox({ note: "Ya confirmado", amount: -5, status_raw: "approved" }),
    ],
    tx_items: [
      tx({ amount: -42.5, note: "Café", account_ref: BCP, local_day: "2026-11-14", date: "2026-11-14T15:00:00Z" }),
      tx({ amount: -100, note: "A Yape", account_ref: BCP, local_day: "2026-11-15", transfer_pair_id: uuid(9001) }),
      tx({ amount: -60, note: "Parte del viaje", account_ref: GRUPO, local_day: "2026-11-15" }),
      tx({ amount: -20, note: "Hace un mes", account_ref: BCP, local_day: "2026-10-15", date: "2026-10-15T15:00:00Z" }),
    ],
    ...extra,
  };
}

async function connected(opts: { queue?: FakeQueue | null } = {}) {
  const queue = opts.queue === undefined ? new FakeQueue() : opts.queue;
  const w = await world({ env: queue ? { CONNECTOR_DRAFTS: queue } : {}, now: NOW });
  const { tokens } = await connect(w);
  w.supabase.rows = rows();
  return { w, token: tokens.access_token, queue };
}

function parse(body: { result: { isError?: boolean; content: { text: string }[] } } | null) {
  const text = body?.result.content[0]?.text ?? "";
  return { isError: !!body?.result.isError, text, data: body?.result.isError ? null : JSON.parse(text) };
}

describe("ver_bandeja", () => {
  it("se ofrece de solo lectura con la cola enlazada, y sin ella no existe", async () => {
    const { w, token } = await connected();
    const res = await rpc(w, token, { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} });
    const { result } = (await res.json()) as { result: { tools: { name: string; annotations?: Record<string, unknown> }[] } };
    const tool = result.tools.find((t) => t.name === "ver_bandeja");
    expect(tool?.annotations).toMatchObject({ readOnlyHint: true, destructiveHint: false, idempotentHint: true });

    const solo = await connected({ queue: null });
    const res2 = await rpc(solo.w, solo.token, { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} });
    const list2 = (await res2.json()) as { result: { tools: { name: string }[] } };
    expect(list2.result.tools.map((t) => t.name)).not.toContain("ver_bandeja");
  });

  it("los pendientes de la Bandeja sin Grupos ni lo ya confirmado, y lo que espera en la cola con su cuenta", async () => {
    const { w, token, queue } = await connected();
    queue!.queued = [
      {
        fuente: "web",
        ia: null,
        kind: "expense",
        amount: 15,
        currency: "PEN",
        merchant: "Menú",
        date: "2026-11-15",
        account_ref: BCP,
        account_name: null,
        subcategory_ref: CAFES,
        subcategory_name: null,
        bank: null,
        account_last4: null,
        created_at: "2026-11-15T19:00:00.000Z",
      },
      {
        fuente: "correo",
        ia: null,
        kind: "expense",
        amount: 89.9,
        currency: "PEN",
        merchant: "Wong",
        date: null,
        account_ref: null,
        account_name: null,
        subcategory_ref: null,
        subcategory_name: null,
        bank: "BCP",
        account_last4: "4321",
        created_at: "2026-11-15T04:30:00.000Z",
      },
    ];
    const out = parse((await callTool(w, token, "ver_bandeja", {})).body);
    expect(out.isError, out.text).toBe(false);
    expect(out.data.pendientes).toEqual([
      expect.objectContaining({ fuente: "Apple Pay", tipo: "gasto", importe: 42.5, divisa: "PEN", nota: "Starbucks", fecha: "2026-11-15", cuenta: "BCP Visa", falta: [] }),
      expect.objectContaining({ fuente: "Correo del banco", detalle: "BCP · ****4321", tipo: "ingreso", importe: 3500, falta: ["categoría"] }),
    ]);
    expect(out.data.en_cola).toEqual([
      expect.objectContaining({ fuente: "Yala web", importe: 15, nota: "Menú", cuenta: "BCP Visa", categoria: "Cafés", fecha: "2026-11-15" }),
      // Sin fecha, el día de llegada en la zona del usuario (23:30 del 14 en Lima).
      expect.objectContaining({ fuente: "Correo del banco", detalle: "BCP · ****4321", fecha: "2026-11-14", cuenta: null }),
    ]);
    expect(queue!.pendingCalls).toEqual([USER_A.id]);
  });

  it("pide solo las columnas de Yala web: nunca el texto original", async () => {
    const { w, token } = await connected();
    await callTool(w, token, "ver_bandeja", {});
    const read = w.supabase.calls.find((c) => c.path === "/rest/v1/inbox_drafts");
    const select = new URLSearchParams(read!.search).get("select")!;
    expect(select.split(",")).toEqual([
      "sync_id",
      "note",
      "amount",
      "date",
      "cached_currency_code",
      "cached_account_name",
      "cached_subcategory_name",
      "source_type_raw",
      "evidence",
      "created_at",
      "needs_user_input",
    ]);
    expect(read!.search).toContain("status_raw=eq.pending");
    expect(w.supabase.calls.every((c) => c.method === "GET" || !c.path.startsWith("/rest/v1/"))).toBe(true);
  });

  it("si la cola no responde, lo dice y enseña la Bandeja igual", async () => {
    const { w, token, queue } = await connected();
    queue!.queued = null;
    const out = parse((await callTool(w, token, "ver_bandeja", {})).body);
    expect(out.data.pendientes).toHaveLength(2);
    expect(out.data.avisos).toContain("No se pudo leer lo que espera a que la app lo recoja.");
  });
});

describe("apuntar_movimiento contra lo que ya está", () => {
  it("manda al gateway la Bandeja y lo guardado de ±3 días, sin Grupos, transferencias ni lo viejo", async () => {
    const { w, token, queue } = await connected();
    const out = parse((await callTool(w, token, "apuntar_movimiento", { importe: 42.5, nota: "Starbucks", cuenta: "BCP" })).body);
    expect(out.isError, out.text).toBe(false);
    const opts = queue!.options[0]!;
    expect(opts.referencia).toBeNull();
    expect(opts.forzar).toBe(false);
    expect(opts.candidatos).toEqual([
      { donde: "bandeja", fuente: "applePay", kind: "expense", amount: 42.5, currency: "PEN", day: "2026-11-15", account_id: null, account_name: "BCP Visa", merchant: "Starbucks" },
      { donde: "bandeja", fuente: "emailAlert", kind: "income", amount: 3500, currency: "PEN", day: "2026-11-15", account_id: null, account_name: null, merchant: "Sueldo" },
      { donde: "guardado", fuente: "guardado", kind: "expense", amount: 42.5, currency: "PEN", day: "2026-11-14", account_id: BCP, account_name: "BCP Visa", merchant: "Café" },
    ]);
  });

  it("lo que apuntó una IA en la Bandeja lleva su nombre como fuente", async () => {
    const { w, token, queue } = await connected();
    w.supabase.rows = rows({ inbox_drafts: [inbox({ amount: -12, source_type_raw: "aiConnector", evidence: "ChatGPT" })] });
    await callTool(w, token, "apuntar_movimiento", { importe: 12 });
    expect(queue!.options[0]!.candidatos[0]).toMatchObject({ fuente: "ai:ChatGPT" });
  });

  it("la referencia viaja recortada; con forzar no se lee nada que comparar", async () => {
    const { w, token, queue } = await connected();
    const before = w.supabase.calls.length;
    await callTool(w, token, "apuntar_movimiento", { importe: 42.5, referencia: "  <CAJ8x@mail.bcp.com.pe> ", forzar: true });
    expect(queue!.options[0]).toEqual({ referencia: "<CAJ8x@mail.bcp.com.pe>", forzar: true, candidatos: [] });
    const reads = w.supabase.calls.slice(before).map((c) => c.path);
    expect(reads).not.toContain("/rest/v1/inbox_drafts");
    expect(reads).not.toContain("/rest/v1/tx_items");
  });

  it("posible_duplicado: no es un error, no dice que se creó nada y enseña lo encontrado en palabras", async () => {
    const { w, token, queue } = await connected();
    queue!.next = {
      ok: false,
      reason: "possible_duplicate",
      matches: [
        { donde: "bandeja", fuente: "applePay", kind: "expense", amount: 42.5, currency: "PEN", day: "2026-11-15", account_id: null, account_name: "BCP Visa", merchant: "Starbucks", nivel: "fuerte" },
        { donde: "cola", fuente: "ai:ChatGPT", kind: "expense", amount: 43, currency: "PEN", day: "2026-11-15", account_id: null, account_name: null, merchant: null, nivel: "dudosa" },
        { donde: "guardado", fuente: "guardado", kind: "expense", amount: 42.5, currency: "PEN", day: "2026-11-14", account_id: BCP, account_name: "BCP Visa", merchant: "Café", nivel: "dudosa" },
      ],
    };
    const out = parse((await callTool(w, token, "apuntar_movimiento", { importe: 42.5, nota: "Starbucks", cuenta: "BCP" })).body);
    expect(out.isError).toBe(false);
    expect(out.data.resultado).toBe("posible_duplicado");
    expect(out.data.borrador).toMatchObject({ importe: 42.5, cuenta: "BCP Visa", fecha: "2026-11-15" });
    expect(out.data.coincidencias).toEqual([
      { donde: "pendiente en la Bandeja", fuente: "Apple Pay", parecido: "casi seguro el mismo", tipo: "gasto", importe: 42.5, divisa: "PEN", nota: "Starbucks", fecha: "2026-11-15", cuenta: "BCP Visa" },
      { donde: "esperando a que la app lo recoja", fuente: "ChatGPT", parecido: "parecido", tipo: "gasto", importe: 43, divisa: "PEN", nota: null, fecha: "2026-11-15", cuenta: null },
      { donde: "ya guardado", fuente: null, parecido: "parecido", tipo: "gasto", importe: 42.5, divisa: "PEN", nota: "Café", fecha: "2026-11-14", cuenta: "BCP Visa" },
    ]);
    expect(out.data.avisos[0]).toMatch(/^No se creó nada\..*forzar=true/);
    expect(out.text).not.toContain("borrador_en_bandeja");
  });

  it("ya_apuntado: la referencia se repitió y no se creó otro", async () => {
    const { w, token, queue } = await connected();
    queue!.next = { ok: true, id: uuid(9100), repeated: true, first_at: Date.parse("2026-11-12T15:00:00Z") };
    const out = parse((await callTool(w, token, "apuntar_movimiento", { importe: 42.5, referencia: "msg-1" })).body);
    expect(out.isError).toBe(false);
    expect(out.data.resultado).toBe("ya_apuntado");
    expect(out.data.avisos[0]).toContain("ya se apuntó el 2026-11-12: no se creó otro borrador");
  });

  it("una referencia de más de 200 la rechaza el esquema", async () => {
    const { w, token, queue } = await connected();
    expect(parse((await callTool(w, token, "apuntar_movimiento", { importe: 5, referencia: "x".repeat(201) })).body).isError).toBe(true);
    expect(queue!.calls).toHaveLength(0);
  });
});
