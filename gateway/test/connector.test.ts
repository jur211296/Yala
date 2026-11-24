/**
 * Tu IA registra en Yala (2.3): lo que el conector apunta (Claude/ChatGPT/Grok) entra en la cola COMÚN de borradores
 * (`mail_drafts`, decisión D9), con `source: "ai"`. Lo que fija, por gravedad si se rompiera:
 *  - encolar no tiene ruta pública: solo la clase RPC `ConnectorDrafts` (la alcanza el service binding del conector);
 *  - la app lo lee por `/mail/drafts` con el `sub` del JWT, y un id de otra cuenta no borra nada;
 *  - el payload se valida otra vez aquí (frontera del gateway): un campo malo y no entra nada;
 *  - techos: 50 al día por cuenta y 100 de la IA esperando a la app (lo del correo y la web no cuenta);
 *  - borrar la cuenta borra el contador (la cola la vacía `deleteMailData`).
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";
import { ConnectorDrafts } from "../src/connector/entrypoint";
import {
  CONNECTOR_DAILY_CAP,
  CONNECTOR_DRAFT_TTL_MS,
  CONNECTOR_MAX_PENDING,
  CONNECTOR_SOURCE,
  deleteConnectorData,
  enqueueConnectorDraft,
  validateConnectorPayload,
} from "../src/connector/store";
import { deleteMailData, insertDraft, listDrafts } from "../src/mail/store";
import { makeMailD1 } from "./mail.fakeD1";

const SUB = "11111111-2222-3333-4444-555555555555";
const OTHER = "99999999-8888-7777-6666-555555555555";
const ACCOUNT = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
const SUBCAT = "12345678-1234-4234-8234-123456789abc";
const MIGRATION = readFileSync(fileURLToPath(new URL("../migrations/0004_connector_quota.sql", import.meta.url)), "utf8");
const MIGRATION_REFS = readFileSync(fileURLToPath(new URL("../migrations/0007_connector_refs.sql", import.meta.url)), "utf8");

function setup() {
  const { db, sqlite } = makeMailD1([MIGRATION, MIGRATION_REFS]);
  const env = { DB: db, ENFORCE: "observe" } as unknown as Env;
  return { env, sqlite };
}

const almuerzo = {
  kind: "expense",
  amount: 25,
  currency: "PEN",
  note: "Almuerzo",
  date: "2026-11-05",
  account_id: ACCOUNT,
  account_name: "BCP Soles",
  subcategory_id: SUBCAT,
  subcategory_name: "Restaurantes",
  client: "Claude",
};

describe("validateConnectorPayload", () => {
  it("acepta el almuerzo y normaliza ids e importe", () => {
    const p = validateConnectorPayload({ ...almuerzo, amount: 25.004, account_id: ACCOUNT.toUpperCase() });
    expect(p).toMatchObject({ kind: "expense", amount: 25, account_id: ACCOUNT, client: "Claude" });
  });

  it("lo opcional puede faltar", () => {
    expect(validateConnectorPayload({ kind: "income", amount: 100 })).toEqual({
      kind: "income",
      amount: 100,
      currency: null,
      note: null,
      date: null,
      account_id: null,
      account_name: null,
      subcategory_id: null,
      subcategory_name: null,
      client: null,
    });
  });

  it.each([
    ["sin tipo", { ...almuerzo, kind: "transfer" }],
    ["importe cero", { ...almuerzo, amount: 0 }],
    ["importe negativo", { ...almuerzo, amount: -25 }],
    ["importe enorme", { ...almuerzo, amount: 2_000_000_000 }],
    ["importe en texto", { ...almuerzo, amount: "25" }],
    ["divisa en minúsculas", { ...almuerzo, currency: "pen" }],
    ["fecha imposible", { ...almuerzo, date: "2026-02-30" }],
    ["fecha con hora", { ...almuerzo, date: "2026-11-05T10:00" }],
    ["cuenta que no es UUID", { ...almuerzo, account_id: "BCP" }],
    ["nota que no es texto", { ...almuerzo, note: 25 }],
    ["un array", [almuerzo]],
  ])("rechaza %s", (_label, raw) => {
    expect(validateConnectorPayload(raw)).toBeNull();
  });

  it("limpia caracteres de control y recorta a 80", () => {
    const p = validateConnectorPayload({ ...almuerzo, note: `  Almuerzo\n\u0000con\tamigos ${"x".repeat(200)}` });
    expect(p?.note?.startsWith("Almuerzo con amigos")).toBe(true);
    expect(p?.note?.length).toBe(80);
    expect(validateConnectorPayload({ ...almuerzo, note: "   " })?.note).toBeNull();
  });
});

const aiRows = (sqlite: { prepare: (q: string) => { get: (...a: unknown[]) => unknown } }) =>
  sqlite.prepare("SELECT COUNT(*) AS n FROM mail_drafts WHERE json_extract(payload, '$.source') = 'ai'").get();

describe("la cola común", () => {
  it("encola por la clase RPC en mail_drafts, con la forma del correo y source ai", async () => {
    const { env } = setup();
    const rpc = new ConnectorDrafts({} as never, env);
    const out = await rpc.enqueue(SUB, almuerzo);
    expect(out.ok).toBe(true);
    const list = await listDrafts(env, SUB);
    expect(list).toHaveLength(1);
    expect(list[0]).toMatchObject({
      id: out.ok ? out.id : "",
      payload: {
        kind: "expense",
        amount: 25,
        currency: "PEN",
        merchant: "Almuerzo",
        date: "2026-11-05",
        bank: null,
        account_last4: null,
        source: CONNECTOR_SOURCE,
        account_ref: ACCOUNT,
        subcategory_ref: SUBCAT,
        account_name: "BCP Soles",
        subcategory_name: "Restaurantes",
        client: "Claude",
      },
    });
    expect(CONNECTOR_SOURCE).toBe("ai");
    expect(await listDrafts(env, OTHER)).toEqual([]);
  });

  it("un payload inválido no entra ni gasta cupo", async () => {
    const { env, sqlite } = setup();
    expect(await enqueueConnectorDraft(env, SUB, { ...almuerzo, amount: -1 })).toEqual({ ok: false, reason: "invalid" });
    expect(await enqueueConnectorDraft(env, "no-es-uuid", almuerzo)).toEqual({ ok: false, reason: "invalid" });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM connector_quota").get()).toEqual({ n: 0 });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM mail_drafts").get()).toEqual({ n: 0 });
  });

  it("corta en 50 al día por cuenta, y al día siguiente vuelve a dejar", async () => {
    const { env } = setup();
    const day = Date.UTC(2026, 10, 5, 12);
    for (let i = 0; i < CONNECTOR_DAILY_CAP; i++) {
      expect((await enqueueConnectorDraft(env, SUB, almuerzo, day)).ok).toBe(true);
    }
    expect(await enqueueConnectorDraft(env, SUB, almuerzo, day)).toEqual({ ok: false, reason: "daily_cap" });
    expect((await enqueueConnectorDraft(env, OTHER, almuerzo, day)).ok).toBe(true);
    expect((await enqueueConnectorDraft(env, SUB, almuerzo, day + 24 * 3600 * 1000)).ok).toBe(true);
  });

  it("el cupo diario no se recupera porque la app recoja la cola", async () => {
    const { env, sqlite } = setup();
    const day = Date.UTC(2026, 10, 5, 12);
    for (let i = 0; i < CONNECTOR_DAILY_CAP; i++) await enqueueConnectorDraft(env, SUB, almuerzo, day);
    sqlite.prepare("DELETE FROM mail_drafts").run();
    expect(await enqueueConnectorDraft(env, SUB, almuerzo, day)).toEqual({ ok: false, reason: "daily_cap" });
  });

  it("con 100 de la IA esperando a la app no entra uno más", async () => {
    const { env, sqlite } = setup();
    const now = Date.now();
    const ia = JSON.stringify({ source: "ai" });
    for (let i = 0; i < CONNECTOR_MAX_PENDING; i++) {
      sqlite.prepare("INSERT INTO mail_drafts VALUES (?, ?, ?, ?)").run(crypto.randomUUID(), SUB, now, ia);
    }
    expect(await enqueueConnectorDraft(env, SUB, almuerzo, now)).toEqual({ ok: false, reason: "queue_full" });
    // Los de otra cuenta no cuentan.
    expect((await enqueueConnectorDraft(env, OTHER, almuerzo, now)).ok).toBe(true);
  });

  it("lo del correo, lo de la web y lo caducado no cuentan para el techo de la IA", async () => {
    const { env, sqlite } = setup();
    const now = Date.now();
    for (let i = 0; i < CONNECTOR_MAX_PENDING; i++) {
      await insertDraft(env, SUB, { kind: "expense", amount: 1, currency: null, merchant: null, date: null, bank: null, account_last4: null }, now);
      sqlite
        .prepare("INSERT INTO mail_drafts VALUES (?, ?, ?, ?)")
        .run(crypto.randomUUID(), SUB, now, JSON.stringify({ source: "web" }));
      sqlite
        .prepare("INSERT INTO mail_drafts VALUES (?, ?, ?, ?)")
        .run(crypto.randomUUID(), SUB, now - CONNECTOR_DRAFT_TTL_MS - 1, JSON.stringify({ source: "ai" }));
    }
    expect((await enqueueConnectorDraft(env, SUB, almuerzo, now)).ok).toBe(true);
    expect(aiRows(sqlite)).toEqual({ n: CONNECTOR_MAX_PENDING + 1 });
  });

  it("borrar la cuenta borra la cola, el contador y las referencias", async () => {
    const { env, sqlite } = setup();
    await enqueueConnectorDraft(env, SUB, almuerzo, Date.now(), { referencia: "msg-1", candidatos: [] });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM connector_refs").get()).toEqual({ n: 1 });
    await deleteMailData(env, SUB);
    await deleteConnectorData(env, SUB);
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM mail_drafts").get()).toEqual({ n: 0 });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM connector_quota").get()).toEqual({ n: 0 });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM connector_refs").get()).toEqual({ n: 0 });
  });
});

describe("las rutas de la app", () => {
  async function appWith() {
    vi.resetModules();
    vi.doMock("../src/sync/userauth", async (importOriginal) => {
      const actual = await importOriginal<typeof import("../src/sync/userauth")>();
      return {
        ...actual,
        verifyUserToken: vi.fn(async (_env: Env, token: string) =>
          token === "jwt-a" ? { sub: SUB, token } : token === "jwt-b" ? { sub: OTHER, token } : null,
        ),
      };
    });
    const { default: app } = await import("../src/index");
    const { env, sqlite } = setup();
    const call = (method: string, path: string, jwt: string, body?: unknown) =>
      app.request(
        path,
        { method, headers: { authorization: `Bearer ${jwt}`, "content-type": "application/json" }, body: body ? JSON.stringify(body) : undefined },
        env,
      );
    return { call, env, sqlite };
  }

  it("encolar no tiene ruta, y la cola paralela ya no existe", async () => {
    const { call } = await appWith();
    for (const path of ["/connector/drafts", "/connector/enqueue", "/connector/drafts/enqueue", "/mail/drafts"]) {
      expect((await call("POST", path, "jwt-a", almuerzo)).status).toBe(404);
    }
    expect((await call("GET", "/connector/drafts", "jwt-a")).status).toBe(404);
    expect((await call("POST", "/connector/drafts/ack", "jwt-a", { ids: [ACCOUNT] })).status).toBe(404);
  });

  it("la app lo lee por /mail/drafts con lo demás, y el ack de otra cuenta no borra nada", async () => {
    const { call, env } = await appWith();
    const out = await enqueueConnectorDraft(env, SUB, almuerzo);
    if (!out.ok) throw new Error("no encoló");
    const list = (await (await call("GET", "/mail/drafts", "jwt-a")).json()) as { drafts: Record<string, unknown>[] };
    expect(list.drafts).toEqual([
      expect.objectContaining({
        id: out.id,
        amount: 25,
        kind: "expense",
        merchant: "Almuerzo",
        source: "ai",
        account_ref: ACCOUNT,
        subcategory_ref: SUBCAT,
        account_name: "BCP Soles",
        subcategory_name: "Restaurantes",
        client: "Claude",
      }),
    ]);
    expect(typeof list.drafts[0]?.received_at_ms).toBe("number");
    const ajena = (await (await call("GET", "/mail/drafts", "jwt-b")).json()) as { drafts: unknown[] };
    expect(ajena.drafts).toEqual([]);
    const other = (await (await call("POST", "/mail/drafts/ack", "jwt-b", { ids: [out.id] })).json()) as { deleted: number };
    expect(other.deleted).toBe(0);
    const mine = (await (await call("POST", "/mail/drafts/ack", "jwt-a", { ids: [out.id] })).json()) as { deleted: number };
    expect(mine.deleted).toBe(1);
  });
});
