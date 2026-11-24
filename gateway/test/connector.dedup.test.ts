/**
 * Lote 5 de «Bandeja sin duplicados» (`docs/propuestas/bandeja-sin-duplicados/README.md`): lo que la IA apunta por el
 * conector, contra lo que ya está. Escenarios de la propuesta sobre el D1 de verdad (`node:sqlite`). Lo que fija, por
 * gravedad si se rompiera:
 *  - E5: la misma `referencia` no crea un segundo borrador, ni gasta cupo, ni siquiera después de que la app lo recoja,
 *    ni con dos llamadas a la vez; y nunca se confunde con la de otra cuenta;
 *  - E4 y E6: lo que ya espera en la cola (correo, web, otra IA), en la Bandeja o guardado vuelve como
 *    `possible_duplicate` sin crear nada, y con `forzar` se crea;
 *  - dos de la misma fuente nunca casan; un ingreso no casa con un gasto (E9);
 *  - sin opciones, todo como antes: un conector anterior no cambia de comportamiento.
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import type { Env } from "../src/env";
import { ConnectorDrafts } from "../src/connector/entrypoint";
import { CONNECTOR_DAILY_CAP, enqueueConnectorDraft, listQueuedForConnector, validateEnqueueOptions } from "../src/connector/store";
import type { MatchCandidate } from "../src/connector/match";
import { insertDraft, listDrafts } from "../src/mail/store";
import { makeMailD1 } from "./mail.fakeD1";

const SUB = "11111111-2222-3333-4444-555555555555";
const OTHER = "99999999-8888-7777-6666-555555555555";
const BCP = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
const NOW = Date.UTC(2026, 10, 15, 20); // 15:00 en Lima
const MIGRATIONS = ["0004_connector_quota.sql", "0007_connector_refs.sql"].map((f) =>
  readFileSync(fileURLToPath(new URL(`../migrations/${f}`, import.meta.url)), "utf8"),
);

function setup() {
  const { db, sqlite } = makeMailD1(MIGRATIONS);
  const env = { DB: db, ENFORCE: "observe" } as unknown as Env;
  const count = (sql: string) => (sqlite.prepare(sql).get() as { n: number }).n;
  return { env, sqlite, drafts: () => count("SELECT COUNT(*) AS n FROM mail_drafts"), quota: () => count("SELECT COALESCE(SUM(day_count), 0) AS n FROM connector_quota") };
}

/** «Apunta el café de Starbucks de 42.50 del correo del BCP». */
const cafe = {
  kind: "expense",
  amount: 42.5,
  currency: "PEN",
  note: "Starbucks",
  date: "2026-11-15",
  account_id: BCP,
  account_name: "BCP Visa",
  subcategory_id: null,
  subcategory_name: null,
  client: "Claude",
};

const check = (over: Record<string, unknown> = {}) => ({ referencia: null, forzar: false, candidatos: [], ...over });

const applePayPendiente: MatchCandidate = {
  donde: "bandeja",
  fuente: "applePay",
  kind: "expense",
  amount: 42.5,
  currency: "PEN",
  day: "2026-11-15",
  account_id: null,
  account_name: "BCP Visa",
  merchant: "Starbucks",
};

describe("E5 · la IA lee el mismo correo dos veces", () => {
  it("con la misma referencia, un solo borrador y un solo cupo; la segunda dice cuándo fue la primera", async () => {
    const { env, drafts, quota } = setup();
    const first = await enqueueConnectorDraft(env, SUB, cafe, NOW, check({ referencia: "<CAJ8x@mail.bcp.com.pe>" }));
    expect(first).toMatchObject({ ok: true });
    const second = await enqueueConnectorDraft(env, SUB, cafe, NOW + 60_000, check({ referencia: "  <CAJ8x@mail.bcp.com.pe> " }));
    expect(second).toEqual({ ok: true, id: first.ok ? first.id : "", repeated: true, first_at: NOW });
    expect(drafts()).toBe(1);
    expect(quota()).toBe(1);
  });

  it("también después de que la app recogiera el primero, y también con forzar", async () => {
    const { env, sqlite, drafts } = setup();
    await enqueueConnectorDraft(env, SUB, cafe, NOW, check({ referencia: "msg-1" }));
    sqlite.prepare("DELETE FROM mail_drafts").run(); // el ack de la app
    const again = await enqueueConnectorDraft(env, SUB, cafe, NOW + 3600_000, check({ referencia: "msg-1", forzar: true }));
    expect(again).toMatchObject({ ok: true, repeated: true });
    expect(drafts()).toBe(0);
  });

  it("dos llamadas a la vez con la misma referencia dejan uno", async () => {
    const { env, drafts } = setup();
    const [a, b] = await Promise.all([
      enqueueConnectorDraft(env, SUB, cafe, NOW, check({ referencia: "msg-1" })),
      enqueueConnectorDraft(env, SUB, cafe, NOW, check({ referencia: "msg-1" })),
    ]);
    expect(drafts()).toBe(1);
    expect([a, b].filter((o) => o.ok && "repeated" in o)).toHaveLength(1);
  });

  it("la referencia es por cuenta, y se guarda solo su huella", async () => {
    const { env, sqlite } = setup();
    expect(await enqueueConnectorDraft(env, SUB, cafe, NOW, check({ referencia: "msg-1" }))).not.toHaveProperty("repeated");
    expect(await enqueueConnectorDraft(env, OTHER, cafe, NOW, check({ referencia: "msg-1" }))).not.toHaveProperty("repeated");
    const rows = sqlite.prepare("SELECT ref_hash FROM connector_refs").all() as { ref_hash: string }[];
    expect(rows).toHaveLength(2);
    expect(rows[0]!.ref_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(JSON.stringify(rows)).not.toContain("msg-1");
  });

  it("caduca a los 90 días", async () => {
    const { env, drafts } = setup();
    await enqueueConnectorDraft(env, SUB, cafe, NOW, check({ referencia: "msg-1" }));
    const later = NOW + 91 * 24 * 3600_000;
    expect(await enqueueConnectorDraft(env, SUB, cafe, later, check({ referencia: "msg-1", forzar: true }))).not.toHaveProperty("repeated");
    expect(drafts()).toBe(2);
  });

  it("si no se creó (techo diario), la referencia no queda reservada", async () => {
    const { env, sqlite, drafts } = setup();
    for (let i = 0; i < CONNECTOR_DAILY_CAP; i++) await enqueueConnectorDraft(env, SUB, { ...cafe, amount: i + 1 }, NOW);
    expect(await enqueueConnectorDraft(env, SUB, cafe, NOW, check({ referencia: "msg-1", forzar: true }))).toEqual({ ok: false, reason: "daily_cap" });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM connector_refs").get()).toEqual({ n: 0 });
    const tomorrow = NOW + 24 * 3600_000;
    expect(await enqueueConnectorDraft(env, SUB, cafe, tomorrow, check({ referencia: "msg-1", forzar: true }))).not.toHaveProperty("repeated");
    expect(drafts()).toBe(CONNECTOR_DAILY_CAP + 1);
  });

  it("sin referencia, la misma IA dos veces no es «posible duplicado»: es la misma fuente", async () => {
    const { env, drafts } = setup();
    await enqueueConnectorDraft(env, SUB, cafe, NOW, check());
    expect((await enqueueConnectorDraft(env, SUB, cafe, NOW, check())).ok).toBe(true);
    expect(drafts()).toBe(2);
  });
});

describe("E4 y E6 · lo que la IA apunta ya está en Yala", () => {
  it("pendiente en la Bandeja por Apple Pay: possible_duplicate con lo encontrado, sin crear ni gastar cupo", async () => {
    const { env, drafts, quota } = setup();
    const out = await enqueueConnectorDraft(env, SUB, cafe, NOW, check({ candidatos: [applePayPendiente] }));
    expect(out).toEqual({ ok: false, reason: "possible_duplicate", matches: [{ ...applePayPendiente, nivel: "fuerte" }] });
    expect(drafts()).toBe(0);
    expect(quota()).toBe(0);
  });

  it("con forzar (el usuario dijo que es otro), se crea", async () => {
    const { env, drafts } = setup();
    const out = await enqueueConnectorDraft(env, SUB, cafe, NOW, check({ candidatos: [applePayPendiente], forzar: true }));
    expect(out).toMatchObject({ ok: true });
    expect(out).not.toHaveProperty("repeated");
    expect(drafts()).toBe(1);
  });

  it("ya guardado a mano (E6)", async () => {
    const { env } = setup();
    const guardado: MatchCandidate = { ...applePayPendiente, donde: "guardado", fuente: "guardado", account_id: BCP, account_name: null, merchant: "Café" };
    const out = await enqueueConnectorDraft(env, SUB, cafe, NOW, check({ candidatos: [guardado] }));
    expect(out).toMatchObject({ ok: false, reason: "possible_duplicate", matches: [{ donde: "guardado", nivel: "dudosa" }] });
  });

  it("esperando en la cola: el correo del banco (sin cuenta → dudosa), Yala web y otra IA", async () => {
    const { env, sqlite } = setup();
    await insertDraft(env, SUB, { kind: "expense", amount: 42.5, currency: "PEN", merchant: "STARBUCKS", date: "2026-11-15", bank: "BCP", account_last4: "4321" }, NOW - 3600_000);
    const correo = await enqueueConnectorDraft(env, SUB, cafe, NOW, check());
    expect(correo).toMatchObject({ ok: false, reason: "possible_duplicate", matches: [{ donde: "cola", fuente: "correo", nivel: "dudosa" }] });

    sqlite.prepare("DELETE FROM mail_drafts").run();
    sqlite
      .prepare("INSERT INTO mail_drafts VALUES (?, ?, ?, ?)")
      .run(crypto.randomUUID(), SUB, NOW, JSON.stringify({ kind: "expense", amount: 42.5, currency: "PEN", merchant: "Starbucks", date: "2026-11-16", source: "web", account_ref: BCP }));
    expect(await enqueueConnectorDraft(env, SUB, cafe, NOW, check())).toMatchObject({ reason: "possible_duplicate", matches: [{ fuente: "web", nivel: "fuerte" }] });

    sqlite.prepare("DELETE FROM mail_drafts").run();
    await enqueueConnectorDraft(env, SUB, { ...cafe, client: "ChatGPT" }, NOW, check());
    expect(await enqueueConnectorDraft(env, SUB, cafe, NOW, check())).toMatchObject({ reason: "possible_duplicate", matches: [{ fuente: "ai:ChatGPT" }] });
  });

  it("lo de otra cuenta en la cola no cuenta", async () => {
    const { env } = setup();
    await enqueueConnectorDraft(env, OTHER, { ...cafe, client: "ChatGPT" }, NOW, check());
    expect(await enqueueConnectorDraft(env, SUB, cafe, NOW, check())).toMatchObject({ ok: true });
  });

  it("un reembolso el mismo día (E9) y otro importe no son duplicados", async () => {
    const { env } = setup();
    const reembolso = { ...applePayPendiente, kind: "income" as const };
    const otroImporte = { ...applePayPendiente, amount: 12 };
    expect(await enqueueConnectorDraft(env, SUB, cafe, NOW, check({ candidatos: [reembolso, otroImporte] }))).toMatchObject({ ok: true });
  });

  it("sin opciones (un conector anterior), ni comprobación ni referencia: como antes", async () => {
    const { env, drafts } = setup();
    await insertDraft(env, SUB, { kind: "expense", amount: 42.5, currency: "PEN", merchant: "Starbucks", date: "2026-11-15", bank: "BCP", account_last4: null }, NOW);
    expect((await enqueueConnectorDraft(env, SUB, cafe, NOW)).ok).toBe(true);
    expect((await new ConnectorDrafts({} as never, env).enqueue(SUB, cafe)).ok).toBe(true);
    expect(drafts()).toBe(3);
  });
});

describe("validateEnqueueOptions", () => {
  it.each([
    ["no es objeto", "msg-1"],
    ["referencia que no es texto", { referencia: 12 }],
    ["referencia de más de 200", { referencia: "x".repeat(201) }],
    ["forzar que no es booleano", { forzar: "sí" }],
    ["candidatos que no son lista", { candidatos: {} }],
    ["un candidato sin fuente", { candidatos: [{ ...applePayPendiente, fuente: "" }] }],
    ["un candidato con importe en texto", { candidatos: [{ ...applePayPendiente, amount: "42.5" }] }],
    ["un candidato de otro sitio", { candidatos: [{ ...applePayPendiente, donde: "grupo" }] }],
  ])("rechaza %s, y no entra nada", async (_label, raw) => {
    expect(validateEnqueueOptions(raw)).toBeNull();
    const { env, drafts } = setup();
    expect(await enqueueConnectorDraft(env, SUB, cafe, NOW, raw)).toEqual({ ok: false, reason: "invalid" });
    expect(drafts()).toBe(0);
  });

  it("sin opciones es undefined; una referencia vacía es ninguna", () => {
    expect(validateEnqueueOptions(undefined)).toBeUndefined();
    expect(validateEnqueueOptions({ referencia: "   " })).toEqual({ referencia: null, forzar: false, candidatos: [] });
  });
});

describe("pending · lo que espera en la cola, para ver_bandeja", () => {
  it("solo de esa cuenta, del más nuevo al más viejo, con su fuente y sin ids", async () => {
    const { env } = setup();
    await insertDraft(env, SUB, { kind: "expense", amount: 89.9, currency: "PEN", merchant: "Wong", date: "2026-11-14", bank: "BCP", account_last4: "4321" }, NOW - 7200_000);
    await enqueueConnectorDraft(env, SUB, cafe, NOW - 3600_000, check());
    await enqueueConnectorDraft(env, OTHER, cafe, NOW, check());
    const rpc = new ConnectorDrafts({} as never, env);
    const list = await rpc.pending(SUB);
    expect(list).toHaveLength(2);
    expect(list![0]).toMatchObject({ fuente: "ia", ia: "Claude", amount: 42.5, merchant: "Starbucks", account_ref: BCP, account_name: "BCP Visa" });
    expect(list![1]).toMatchObject({ fuente: "correo", ia: null, merchant: "Wong", bank: "BCP", account_last4: "4321", date: "2026-11-14" });
    expect(JSON.stringify(list)).not.toMatch(/"id"/);
    expect(await listQueuedForConnector(env, "no-es-uuid")).toBeNull();
    // Leer no recoge: la cola sigue entera para la app.
    expect(await listDrafts(env, SUB, NOW)).toHaveLength(2);
  });
});
