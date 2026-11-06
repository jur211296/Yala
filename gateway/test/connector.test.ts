/**
 * Tu IA registra en Yala (2.3): la cola del gateway donde el conector deja lo que apunta Claude/ChatGPT/Grok. Lo que fija,
 * por gravedad si se rompiera:
 *  - encolar no tiene ruta pública: solo la clase RPC `ConnectorDrafts` (la alcanza el service binding del conector);
 *  - la cola es de la CUENTA: listar y `ack` usan el `sub` del JWT, y un id de otra cuenta no borra nada;
 *  - el payload se valida otra vez aquí (frontera del gateway): un campo malo y no entra nada;
 *  - techos: 50 al día por cuenta y 100 esperando a la app;
 *  - borrar la cuenta borra la cola.
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
  deleteConnectorData,
  enqueueConnectorDraft,
  listConnectorDrafts,
  validateConnectorPayload,
} from "../src/connector/store";
import { makeMailD1 } from "./mail.fakeD1";

const SUB = "11111111-2222-3333-4444-555555555555";
const OTHER = "99999999-8888-7777-6666-555555555555";
const ACCOUNT = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
const SUBCAT = "12345678-1234-4234-8234-123456789abc";
const MIGRATION = readFileSync(fileURLToPath(new URL("../migrations/0004_connector_drafts.sql", import.meta.url)), "utf8");

function setup() {
  const { db, sqlite } = makeMailD1([MIGRATION]);
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

describe("la cola", () => {
  it("encola por la clase RPC y la app lo lee con su id", async () => {
    const { env } = setup();
    const rpc = new ConnectorDrafts({} as never, env);
    const out = await rpc.enqueue(SUB, almuerzo);
    expect(out.ok).toBe(true);
    const list = await listConnectorDrafts(env, SUB);
    expect(list).toHaveLength(1);
    expect(list[0]).toMatchObject({ id: out.ok ? out.id : "", payload: { amount: 25, note: "Almuerzo", client: "Claude" } });
    expect(await listConnectorDrafts(env, OTHER)).toEqual([]);
  });

  it("un payload inválido no entra ni gasta cupo", async () => {
    const { env, sqlite } = setup();
    expect(await enqueueConnectorDraft(env, SUB, { ...almuerzo, amount: -1 })).toEqual({ ok: false, reason: "invalid" });
    expect(await enqueueConnectorDraft(env, "no-es-uuid", almuerzo)).toEqual({ ok: false, reason: "invalid" });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM connector_quota").get()).toEqual({ n: 0 });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM connector_drafts").get()).toEqual({ n: 0 });
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

  it("con 100 esperando a la app no entra uno más", async () => {
    const { env, sqlite } = setup();
    const now = Date.now();
    for (let i = 0; i < CONNECTOR_MAX_PENDING; i++) {
      sqlite.prepare("INSERT INTO connector_drafts VALUES (?, ?, ?, '{}')").run(crypto.randomUUID(), SUB, now);
    }
    expect(await enqueueConnectorDraft(env, SUB, almuerzo, now)).toEqual({ ok: false, reason: "queue_full" });
  });

  it("lo de más de 30 días se va antes de contar y de leer", async () => {
    const { env, sqlite } = setup();
    const now = Date.now();
    sqlite
      .prepare("INSERT INTO connector_drafts VALUES (?, ?, ?, ?)")
      .run(crypto.randomUUID(), SUB, now - CONNECTOR_DRAFT_TTL_MS - 1, JSON.stringify(almuerzo));
    expect(await listConnectorDrafts(env, SUB, now)).toEqual([]);
  });

  it("borrar la cuenta borra la cola y el contador", async () => {
    const { env, sqlite } = setup();
    await enqueueConnectorDraft(env, SUB, almuerzo);
    await deleteConnectorData(env, SUB);
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM connector_drafts").get()).toEqual({ n: 0 });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM connector_quota").get()).toEqual({ n: 0 });
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

  it("sin JWT válido, 401", async () => {
    const { call } = await appWith();
    expect((await call("GET", "/connector/drafts", "malo")).status).toBe(401);
    expect((await call("POST", "/connector/drafts/ack", "malo", { ids: [ACCOUNT] })).status).toBe(401);
  });

  it("encolar no tiene ruta", async () => {
    const { call } = await appWith();
    for (const path of ["/connector/drafts", "/connector/enqueue", "/connector/drafts/enqueue"]) {
      expect((await call("POST", path, "jwt-a", almuerzo)).status).toBe(404);
    }
  });

  it("la app lee lo suyo y el ack de otra cuenta no borra nada", async () => {
    const { call, env } = await appWith();
    const out = await enqueueConnectorDraft(env, SUB, almuerzo);
    if (!out.ok) throw new Error("no encoló");
    const list = (await (await call("GET", "/connector/drafts", "jwt-a")).json()) as { drafts: Record<string, unknown>[] };
    expect(list.drafts).toEqual([
      expect.objectContaining({ id: out.id, amount: 25, kind: "expense", account_id: ACCOUNT, subcategory_id: SUBCAT, client: "Claude" }),
    ]);
    expect(typeof list.drafts[0]?.received_at_ms).toBe("number");
    const ajena = (await (await call("GET", "/connector/drafts", "jwt-b")).json()) as { drafts: unknown[] };
    expect(ajena.drafts).toEqual([]);
    const other = (await (await call("POST", "/connector/drafts/ack", "jwt-b", { ids: [out.id] })).json()) as { deleted: number };
    expect(other.deleted).toBe(0);
    const mine = (await (await call("POST", "/connector/drafts/ack", "jwt-a", { ids: [out.id.toUpperCase()] })).json()) as { deleted: number };
    expect(mine.deleted).toBe(1);
  });

  it("ack sin ids, 400", async () => {
    const { call } = await appWith();
    expect((await call("POST", "/connector/drafts/ack", "jwt-a", { ids: [] })).status).toBe(400);
    expect((await call("POST", "/connector/drafts/ack", "jwt-a", { ids: ["x"] })).status).toBe(400);
  });
});
