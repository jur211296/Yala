/**
 * `apuntar_movimiento`: «apunta 25 soles de almuerzo» deja un borrador en la cola de la Bandeja. Lo que fija, por gravedad
 * si se rompiera:
 *  - nunca escribe en Supabase: todas sus salidas a la nube son GET con la sesión de solo lectura; lo único que «escribe»
 *    es la llamada a la cola del gateway (service binding), con el `sub` de la sesión verificada;
 *  - sin la cola enlazada, el conector sigue siendo de solo lectura (seis herramientas, ninguna de escritura);
 *  - la cuenta y la subcategoría se resuelven contra las del usuario: lo que no existe o es ambiguo es un error con las
 *    opciones, y un gasto no va a una subcategoría de ingreso;
 *  - la cola llena o el techo diario se dicen en palabras, sin borrador a medias.
 */
import { describe, expect, it } from "vitest";
import { account, category, subcategory, uuid } from "./fixtures";
import { BASE, Browser, callTool, connect, isDataRead, register, rpc, world, authorizeUrl } from "./helpers";
import { USER_A } from "./supabase-fake";
import {
  clientLabelFromRedirects,
  resolveAccount,
  resolveSubcategory,
  type ConnectorDraftPayload,
  type ConnectorDraftsBinding,
  type EnqueueOutcome,
} from "../src/writeTool";

class FakeQueue implements ConnectorDraftsBinding {
  calls: { userId: string; payload: ConnectorDraftPayload }[] = [];
  next: EnqueueOutcome | Error = { ok: true, id: "11111111-1111-4111-8111-111111111111" };
  async enqueue(userId: string, payload: ConnectorDraftPayload): Promise<EnqueueOutcome> {
    this.calls.push({ userId, payload });
    if (this.next instanceof Error) throw this.next;
    return this.next;
  }
}

const BCP = uuid(7001);
const YAPE = uuid(7002);
const USD = uuid(7003);
const COMIDA = uuid(7101);
const SUELDO_CAT = uuid(7102);
const RESTAURANTES = uuid(7201);
const MERCADO = uuid(7202);
const SUELDO = uuid(7203);

function rows(extra: Record<string, unknown[]> = {}) {
  return {
    accounts: [
      account({ sync_id: BCP, name: "BCP Soles" }),
      account({ sync_id: YAPE, name: "Yape" }),
      account({ sync_id: USD, name: "Interbank Dólares", currency_code: "USD" }),
    ],
    categories: [category({ sync_id: COMIDA, name: "Comida" }), category({ sync_id: SUELDO_CAT, name: "Ingresos", is_income: true })],
    subcategories: [
      subcategory({ sync_id: RESTAURANTES, name: "Restaurantes", category_ref: COMIDA }),
      subcategory({ sync_id: MERCADO, name: "Mercado", category_ref: COMIDA }),
      subcategory({ sync_id: SUELDO, name: "Sueldo", category_ref: SUELDO_CAT }),
    ],
    tags: [],
    user_preferences: [
      { key: "defaultCurrencyCode", value: "PEN" },
      { key: "timeZoneIdentifier", value: "America/Lima" },
    ],
    ...extra,
  };
}

const NOW = () => new Date("2026-11-05T20:00:00Z"); // 15:00 en Lima

async function connected(opts: { queue?: FakeQueue | null; data?: Record<string, unknown[]> } = {}) {
  const queue = opts.queue === undefined ? new FakeQueue() : opts.queue;
  const w = await world({ env: queue ? { CONNECTOR_DRAFTS: queue } : {}, now: NOW });
  const { tokens } = await connect(w);
  w.supabase.rows = opts.data ?? rows();
  return { w, token: tokens.access_token, queue };
}

function parse(body: { result: { isError?: boolean; content: { text: string }[] } } | null) {
  return { isError: !!body?.result.isError, text: body?.result.content[0]?.text ?? "" };
}

describe("apuntar_movimiento por MCP", () => {
  it("se ofrece como la única de escritura, sin destruir nada y no idempotente", async () => {
    const { w, token } = await connected();
    const res = await rpc(w, token, { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} });
    const { result } = (await res.json()) as { result: { tools: { name: string; annotations?: Record<string, unknown> }[] } };
    const writers = result.tools.filter((t) => t.annotations?.readOnlyHint !== true);
    expect(writers.map((t) => t.name)).toEqual(["apuntar_movimiento"]);
    expect(writers[0]!.annotations).toMatchObject({ readOnlyHint: false, destructiveHint: false, idempotentHint: false });
    expect(result.tools).toHaveLength(7);
  });

  it("sin la cola enlazada no existe: el conector sigue siendo de solo lectura", async () => {
    const { w, token } = await connected({ queue: null });
    const res = await rpc(w, token, { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} });
    const { result } = (await res.json()) as { result: { tools: { name: string }[] } };
    expect(result.tools.map((t) => t.name)).not.toContain("apuntar_movimiento");
  });

  it("«apunta 25 soles de almuerzo en Restaurantes» deja el borrador completo en la cola, para el usuario de la sesión", async () => {
    const { w, token, queue } = await connected();
    const { body } = await callTool(w, token, "apuntar_movimiento", { importe: 25, nota: "Almuerzo", divisa: "PEN", cuenta: "bcp", categoria: "restaurantes" });
    const out = parse(body);
    expect(out.isError, out.text).toBe(false);
    expect(queue!.calls).toEqual([
      {
        userId: USER_A.id,
        payload: {
          kind: "expense",
          amount: 25,
          currency: "PEN",
          note: "Almuerzo",
          date: "2026-11-05",
          account_id: BCP,
          account_name: "BCP Soles",
          subcategory_id: RESTAURANTES,
          subcategory_name: "Restaurantes",
          client: "Claude",
        },
      },
    ]);
    const data = JSON.parse(out.text);
    expect(data).toMatchObject({
      resultado: "borrador_en_bandeja",
      borrador: { tipo: "gasto", importe: 25, divisa: "PEN", cuenta: "BCP Soles", categoria: "Comida › Restaurantes", fecha: "2026-11-05" },
      falta: [],
    });
    // Ni una escritura a la nube: solo lecturas con la sesión de solo lectura.
    for (const c of w.supabase.calls.filter(isDataRead)) expect(c.method).toBe("GET");
  });

  it("sin cuenta ni divisa, con dos cuentas en soles: el borrador la pide", async () => {
    const { w, token, queue } = await connected();
    const out = parse((await callTool(w, token, "apuntar_movimiento", { importe: 25, nota: "Almuerzo" })).body);
    expect(out.isError, out.text).toBe(false);
    expect(queue!.calls[0]!.payload).toMatchObject({ currency: "PEN", account_id: null, subcategory_id: null });
    expect(JSON.parse(out.text).falta).toEqual(["cuenta", "categoría"]);
  });

  it("en dólares va a la única cuenta en dólares", async () => {
    const { w, token, queue } = await connected();
    const out = parse((await callTool(w, token, "apuntar_movimiento", { importe: 12.5, divisa: "usd" })).body);
    expect(out.isError, out.text).toBe(false);
    expect(queue!.calls[0]!.payload).toMatchObject({ currency: "USD", account_id: USD, amount: 12.5 });
  });

  it("un ingreso busca entre las subcategorías de ingreso", async () => {
    const { w, token, queue } = await connected();
    const ok = parse((await callTool(w, token, "apuntar_movimiento", { importe: 3000, tipo: "ingreso", categoria: "Sueldo", cuenta: "BCP Soles" })).body);
    expect(ok.isError, ok.text).toBe(false);
    expect(queue!.calls[0]!.payload).toMatchObject({ kind: "income", subcategory_id: SUELDO });
    const mal = parse((await callTool(w, token, "apuntar_movimiento", { importe: 30, categoria: "Sueldo" })).body);
    expect(mal.isError).toBe(true);
    expect(mal.text).toContain("Comida › Restaurantes");
    expect(queue!.calls).toHaveLength(1);
  });

  it("una cuenta que no existe es un error con las opciones, y no encola nada", async () => {
    const { w, token, queue } = await connected();
    const out = parse((await callTool(w, token, "apuntar_movimiento", { importe: 25, cuenta: "Scotiabank" })).body);
    expect(out.isError).toBe(true);
    expect(out.text).toContain("BCP Soles");
    expect(out.text).toContain("Yape");
    expect(queue!.calls).toHaveLength(0);
  });

  it("una fecha futura —también mañana— es un error; hoy y ayer valen", async () => {
    const { w, token, queue } = await connected();
    expect(parse((await callTool(w, token, "apuntar_movimiento", { importe: 5, fecha: "2026-11-08" })).body).isError).toBe(true);
    const manana = parse((await callTool(w, token, "apuntar_movimiento", { importe: 5, fecha: "2026-11-06" })).body);
    expect(manana).toMatchObject({ isError: true });
    expect(manana.text).toContain("hoy es 2026-11-05");
    expect(parse((await callTool(w, token, "apuntar_movimiento", { importe: 5, fecha: "2026-11-05" })).body).isError).toBe(false);
    expect(parse((await callTool(w, token, "apuntar_movimiento", { importe: 5, fecha: "2026-11-04" })).body).isError).toBe(false);
    expect(queue!.calls.map((c) => c.payload.date)).toEqual(["2026-11-05", "2026-11-04"]);
  });

  it("una conexión aprobada como solo lectura no gana la herramienta al enlazar la cola después", async () => {
    const { w, token } = await connected({ queue: null });
    w.env.CONNECTOR_DRAFTS = new FakeQueue();
    const res = await rpc(w, token, { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} });
    const { result } = (await res.json()) as { result: { tools: { name: string }[] } };
    expect(result.tools.map((t) => t.name)).not.toContain("apuntar_movimiento");
    // Y llamarla a pelo no la encuentra.
    expect(parse((await callTool(w, token, "apuntar_movimiento", { importe: 5 })).body).isError).toBe(true);
    expect((w.env.CONNECTOR_DRAFTS as FakeQueue).calls).toHaveLength(0);
  });

  it("la cola llena y el techo diario se dicen en palabras", async () => {
    const { w, token, queue } = await connected();
    queue!.next = { ok: false, reason: "queue_full" };
    expect(parse((await callTool(w, token, "apuntar_movimiento", { importe: 5 })).body).text).toContain("100 movimientos esperando");
    queue!.next = { ok: false, reason: "daily_cap" };
    expect(parse((await callTool(w, token, "apuntar_movimiento", { importe: 5 })).body).text).toContain("50 movimientos hoy");
    queue!.next = new Error("binding caído");
    const caido = parse((await callTool(w, token, "apuntar_movimiento", { importe: 5 })).body);
    expect(caido).toEqual({ isError: true, text: "No se pudo dejar el movimiento en Yala. Prueba de nuevo en un momento." });
  });

  it("un importe negativo o cero lo rechaza el esquema", async () => {
    const { w, token, queue } = await connected();
    expect(parse((await callTool(w, token, "apuntar_movimiento", { importe: -25 })).body).isError).toBe(true);
    expect(parse((await callTool(w, token, "apuntar_movimiento", { importe: 0 })).body).isError).toBe(true);
    expect(queue!.calls).toHaveLength(0);
  });
});

describe("resolución por nombre", () => {
  const accounts = rows().accounts as ReturnType<typeof account>[];

  it("sin tildes ni mayúsculas; el exacto gana al que lo contiene", () => {
    expect(resolveAccount(accounts, "interbank dolares", null)?.sync_id).toBe(USD);
    expect(resolveAccount([...accounts, account({ sync_id: uuid(7004), name: "Yape Empresa" })], "yape", null)?.sync_id).toBe(YAPE);
  });

  it("ambigua: error con las que encajan", () => {
    const two = [account({ sync_id: uuid(1), name: "BBVA Soles" }), account({ sync_id: uuid(2), name: "BBVA Ahorros" })];
    expect(() => resolveAccount(two, "bbva", null)).toThrow(/BBVA Ahorros, BBVA Soles/);
  });

  it("cuenta en otra divisa: error; la tarjeta con línea en esa divisa va a la línea", () => {
    expect(() => resolveAccount(accounts, "BCP Soles", "USD")).toThrow(/es en PEN/);
    const line = account({ sync_id: uuid(3), name: "BCP Soles USD", currency_code: "USD", parent_account_id: BCP });
    expect(resolveAccount([...accounts, line], "BCP Soles", "USD")?.sync_id).toBe(line.sync_id);
  });

  it("archivadas y de sistema no se eligen", () => {
    const archived = account({ sync_id: uuid(4), name: "Vieja", is_archived: true });
    const system = account({ sync_id: uuid(5), name: "Grupos", is_system_account: true });
    expect(() => resolveAccount([archived, system], "Vieja", null)).toThrow(/No hay ninguna cuenta/);
    expect(resolveAccount([system, account({ sync_id: uuid(6), name: "Única" })], undefined, "PEN")?.name).toBe("Única");
  });

  it("subcategoría repetida: hace falta «Categoría › Subcategoría»; una categoría de una sola subcategoría vale", () => {
    const cats = new Map([
      [COMIDA, category({ sync_id: COMIDA, name: "Comida" })],
      [uuid(8), category({ sync_id: uuid(8), name: "Hogar" })],
      [uuid(9), category({ sync_id: uuid(9), name: "Mascotas" })],
    ]);
    const subs = [
      subcategory({ sync_id: uuid(10), name: "Otros", category_ref: COMIDA }),
      subcategory({ sync_id: uuid(11), name: "Otros", category_ref: uuid(8) }),
      subcategory({ sync_id: uuid(12), name: "Veterinario", category_ref: uuid(9) }),
    ];
    expect(() => resolveSubcategory(cats, subs, "otros", false)).toThrow(/Comida › Otros, Hogar › Otros/);
    expect(resolveSubcategory(cats, subs, "Hogar › Otros", false).sub.sync_id).toBe(uuid(11));
    expect(resolveSubcategory(cats, subs, "hogar/otros", false).sub.sync_id).toBe(uuid(11));
    expect(resolveSubcategory(cats, subs, "Mascotas", false).sub.sync_id).toBe(uuid(12));
  });

  it("una subcategoría con «/» en el nombre se elige por su nombre y por la etiqueta que dan los errores", () => {
    const cats = new Map([[uuid(20), category({ sync_id: uuid(20), name: "Servicios" })]]);
    const subs = [
      subcategory({ sync_id: uuid(21), name: "Luz/Agua", category_ref: uuid(20) }),
      subcategory({ sync_id: uuid(22), name: "Internet", category_ref: uuid(20) }),
    ];
    expect(resolveSubcategory(cats, subs, "luz/agua", false).sub.sync_id).toBe(uuid(21));
    expect(resolveSubcategory(cats, subs, "Servicios › Luz/Agua", false).sub.sync_id).toBe(uuid(21));
    expect(resolveSubcategory(cats, subs, "servicios/internet", false).sub.sync_id).toBe(uuid(22));
  });

  it("la IA se reconoce por su vuelta, no por el nombre que se puso", () => {
    expect(clientLabelFromRedirects(["https://claude.ai/api/mcp/auth_callback"])).toBe("Claude");
    expect(clientLabelFromRedirects(["http://localhost:4000/callback"])).toBe("Claude");
    expect(clientLabelFromRedirects(["https://chatgpt.com/connector_platform_oauth_redirect"])).toBe("ChatGPT");
    expect(clientLabelFromRedirects(["https://grok.com/oauth/callback"])).toBe("Grok");
    expect(clientLabelFromRedirects(["https://otra.example/cb"])).toBeNull();
  });
});

describe("el permiso y las vueltas de ChatGPT y Grok", () => {
  it("ChatGPT se registra con su vuelta estable o la de id de callback; sus primas no", async () => {
    const w = await world();
    for (const ok of ["https://chatgpt.com/connector_platform_oauth_redirect", "https://chatgpt.com/connector/oauth/abc_123-XYZ"]) {
      const { res } = await register(w, [ok], "ChatGPT");
      expect(res.status, ok).toBe(201);
    }
    for (const bad of [
      "https://chatgpt.com/connector/oauth/abc/../../evil",
      "https://chatgpt.com/connector/oauth/abc?x=1",
      "https://chatgpt.com.evil.example/connector_platform_oauth_redirect",
      "https://evil.chatgpt.com/connector_platform_oauth_redirect",
      "http://chatgpt.com/connector_platform_oauth_redirect",
    ]) {
      const { res } = await register(w, [bad], "ChatGPT");
      expect(res.status, bad).toBe(400);
    }
  });

  it("una vuelta desconocida se rechaza y queda en el log para fijarla; con EXTRA_REDIRECT_URIS entra", async () => {
    const logs: string[] = [];
    const original = console.log;
    console.log = (line: unknown) => void logs.push(String(line));
    try {
      const w = await world();
      const { res } = await register(w, ["https://grok.com/connectors/oauth/callback?state=x"], "Grok");
      expect(res.status).toBe(400);
    } finally {
      console.log = original;
    }
    const line = logs.map((l) => JSON.parse(l) as Record<string, string>).find((l) => l.motivo === "vuelta_no_permitida");
    // Sin la query (puede llevar datos), pero diciendo que la traía: la lista compara la URL entera.
    expect(line?.resultado).toBe("https://grok.com/connectors/oauth/callback +query");

    const w2 = await world({ env: { EXTRA_REDIRECT_URIS: "https://grok.com/connectors/oauth/callback" } });
    expect((await register(w2, ["https://grok.com/connectors/oauth/callback"], "Grok")).res.status).toBe(201);
    expect((await register(w2, ["https://grok.com/connectors/oauth/callback2"], "Grok")).res.status).toBe(400);
  });

  it("una errata en EXTRA_REDIRECT_URIS no tumba el conector: Claude sigue entrando y la errata no abre nada", async () => {
    const w = await world({ env: { EXTRA_REDIRECT_URIS: "https://grok.com, grok.com/cb" } });
    expect((await register(w)).res.status).toBe(201);
    expect((await register(w, ["https://grok.com"], "Grok")).res.status).toBe(400);
    expect((await register(w, ["https://grok.com/"], "Grok")).res.status).toBe(400);
    expect((await register(w, ["https://grok.com/cb"], "Grok")).res.status).toBe(400);
  });

  it("con la cola enlazada, el permiso dice que puede apuntar borradores y que no confirma nada", async () => {
    const w = await world({ env: { CONNECTOR_DRAFTS: new FakeQueue() } });
    const { body } = await register(w);
    const html = await (await new Browser(w).fetch(authorizeUrl(body.client_id!, "x".repeat(43), "st"))).text();
    expect(html).toContain("quiere usar tus datos de Yala");
    expect(html).toContain("<strong>apuntar</strong> gastos e ingresos como borradores en tu Bandeja");
    expect(html).toContain("ni confirmar un borrador");
    expect(BASE).toBeTruthy();
  });
});
