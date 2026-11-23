/**
 * «Comercios en común» (2.3, 2026-11-22). Lo que fija, por gravedad si se rompiera:
 *
 * 1. Lo que se guarda es lo mínimo: comercio, tipo, semana y una huella que no es el keyId. Ni cuenta, ni día.
 * 2. La regla de la variante B: 3 teléfonos, ≥75 %, dos de ventaja; cambiar uno publicado pide 5.
 * 3. Un teléfono cuenta una vez por comercio, aporta con 7 días o más y como mucho 30 por semana.
 * 4. Los votos caducan a las 13 semanas y se borran al entrar el comercio en la lista.
 * 5. La lista se baja entera, con ETag, y solo con el token de App Attest.
 *
 * D1 de verdad (SQLite en memoria) con las migraciones 0001 y 0005.
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import app from "../../src/index";
import type { Env } from "../../src/env";
import { issueSessionToken } from "../../src/attest/session";
import {
  decide,
  isoWeek,
  normalizeKind,
  normalizeMerchant,
  retentionCutoffWeek,
  SHAREABLE_KINDS,
} from "../../src/comercios-comun/rules";
import { clock } from "../../src/comercios-comun/routes";
import { deviceHash } from "../../src/comercios-comun/store";
import { makeMailD1 } from "../mail.fakeD1";

const SECRET = "test-secret";
const DAY = 86_400_000;
const NOW = Date.UTC(2026, 10, 22, 15, 0, 0); // domingo 22-nov-2026

function migration(name: string): string {
  return readFileSync(fileURLToPath(new URL(`../../migrations/${name}`, import.meta.url)), "utf8");
}

function fakeKV(): KVNamespace {
  const store = new Map<string, string>();
  return {
    async get(key: string, type?: string) {
      const v = store.get(key);
      if (v === undefined) return null;
      return type === "json" ? JSON.parse(v) : v;
    },
    async put(key: string, value: string) {
      store.set(key, value);
    },
  } as unknown as KVNamespace;
}

function setup(environment = "staging") {
  const { db, sqlite } = makeMailD1([migration("0001_init.sql"), migration("0005_comercios_comun.sql")]);
  const env = { DB: db, KV: fakeKV(), ENVIRONMENT: environment, JWT_SIGNING_SECRET: SECRET } as unknown as Env;
  const addDevice = (keyId: string, ageDays: number) =>
    sqlite
      .prepare(
        "INSERT INTO attest_keys (key_id, public_key, attest_env, created_at, updated_at) VALUES (?, x'00', 'production', ?, ?)",
      )
      .run(keyId, NOW - ageDays * DAY, NOW - ageDays * DAY);
  const token = async (keyId: string) => (await issueSessionToken(env, { keyId, tier: "free" })).token;
  const aportar = async (keyId: string, items: unknown[]) =>
    app.request(
      "/comercios-comun/aportes",
      {
        method: "POST",
        headers: { authorization: `Bearer ${await token(keyId)}`, "content-type": "application/json" },
        body: JSON.stringify({ items }),
      },
      env,
    );
  const lista = async (keyId: string, etag?: string) =>
    app.request(
      "/comercios-comun/lista",
      { headers: { authorization: `Bearer ${await token(keyId)}`, ...(etag ? { "if-none-match": etag } : {}) } },
      env,
    );
  return { env, sqlite, addDevice, aportar, lista };
}

function withClock<T>(ms: number, fn: () => Promise<T>): Promise<T> {
  const before = clock.now;
  clock.now = () => ms;
  return fn().finally(() => {
    clock.now = before;
  });
}

describe("reglas puras", () => {
  it("la variante B: 3 teléfonos, ≥75 % y dos de ventaja", () => {
    expect(decide(new Map([["supermarket", 3]]), null)).toBe("supermarket");
    expect(decide(new Map([["supermarket", 2]]), null)).toBeNull();
    // 3 contra 1: 75 % justo y dos de ventaja.
    expect(decide(new Map([["supermarket", 3], ["restaurant", 1]]), null)).toBe("supermarket");
    // 4 contra 2: 67 %, no llega.
    expect(decide(new Map([["supermarket", 4], ["restaurant", 2]]), null)).toBeNull();
  });

  it("cambiar uno ya publicado pide 5", () => {
    expect(decide(new Map([["bar", 4]]), "pharmacy")).toBeNull();
    expect(decide(new Map([["bar", 5]]), "pharmacy")).toBe("bar");
    // Lo que ya dice la lista no cambia nada.
    expect(decide(new Map([["pharmacy", 9]]), "pharmacy")).toBeNull();
  });

  it("el nombre se normaliza y lo que no vale se descarta", () => {
    expect(normalizeMerchant("  tambo+  ")).toBe("TAMBO");
    expect(normalizeMerchant("Botica  San José")).toBe("BOTICA SAN JOSÉ");
    expect(normalizeMerchant("12345")).toBeNull();
    expect(normalizeMerchant("A")).toBeNull();
    expect(normalizeMerchant("X".repeat(41))).toBeNull();
    expect(normalizeMerchant(42)).toBeNull();
  });

  it("alquiler e impuestos nunca se comparten, ni un tipo inventado", () => {
    expect(normalizeKind("supermarket")).toBe("supermarket");
    expect(normalizeKind("rent")).toBeNull();
    expect(normalizeKind("taxes")).toBeNull();
    expect(normalizeKind("casino")).toBeNull();
    expect(SHAREABLE_KINDS.size).toBe(32);
  });

  it("la semana ISO ordena como texto y cruza el año", () => {
    expect(isoWeek(NOW)).toBe("2026-W47");
    expect(isoWeek(Date.UTC(2027, 0, 1))).toBe("2026-W53");
    expect(isoWeek(Date.UTC(2027, 0, 4))).toBe("2027-W01");
    expect(retentionCutoffWeek(NOW) < isoWeek(NOW)).toBe(true);
  });

  it("la huella no es el keyId y es estable", async () => {
    const a = await deviceHash(SECRET, "key-1");
    expect(a).not.toContain("key-1");
    expect(await deviceHash(SECRET, "key-1")).toBe(a);
    expect(await deviceHash(SECRET, "key-2")).not.toBe(a);
    expect(await deviceHash("otra-llave", "key-1")).not.toBe(a);
  });
});

describe("las rutas", () => {
  it("sin token, 401 en las dos", async () => {
    const { env } = setup();
    expect((await app.request("/comercios-comun/lista", {}, env)).status).toBe(401);
    const post = await app.request("/comercios-comun/aportes", { method: "POST", body: "{}" }, env);
    expect(post.status).toBe(401);
  });

  it("guarda solo comercio, tipo, semana y huella", async () => {
    const { sqlite, addDevice, aportar } = setup();
    addDevice("k1", 30);
    const res = await withClock(NOW, () =>
      aportar("k1", [{ merchant: "Tambo", kind: "supermarket", amount: 12.5, date: "2026-11-22" }]),
    );
    expect(await res.json()).toEqual({ status: "ok", accepted: 1 });
    const rows = sqlite.prepare("SELECT * FROM cc_votes").all() as Record<string, unknown>[];
    expect(rows).toHaveLength(1);
    expect(Object.keys(rows[0]).sort()).toEqual(["device_hash", "kind", "merchant", "week"]);
    expect(rows[0]).toMatchObject({ merchant: "TAMBO", kind: "supermarket", week: "2026-W47" });
    expect(rows[0].device_hash).not.toBe("k1");
  });

  it("un teléfono con menos de 7 días no aporta (y lo dice)", async () => {
    const { sqlite, addDevice, aportar } = setup();
    addDevice("nuevo", 3);
    const res = await withClock(NOW, () => aportar("nuevo", [{ merchant: "TAMBO", kind: "supermarket" }]));
    expect(await res.json()).toEqual({ status: "too_new", accepted: 0 });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM cc_votes").get()).toEqual({ n: 0 });
  });

  it("sin fila de App Attest: vale en staging (token de desarrollo), no en producción", async () => {
    const staging = setup("staging");
    const r1 = await withClock(NOW, () => staging.aportar("dev:shared", [{ merchant: "TAMBO", kind: "supermarket" }]));
    expect(((await r1.json()) as { status: string }).status).toBe("ok");
    const prod = setup("production");
    const r2 = await withClock(NOW, () => prod.aportar("dev:shared", [{ merchant: "TAMBO", kind: "supermarket" }]));
    expect(((await r2.json()) as { status: string }).status).toBe("too_new");
  });

  it("un teléfono cuenta una vez por comercio: votar dos veces no suma", async () => {
    const { sqlite, addDevice, aportar } = setup();
    addDevice("k1", 30);
    await withClock(NOW, () => aportar("k1", [{ merchant: "TAMBO", kind: "supermarket" }]));
    await withClock(NOW + DAY, () => aportar("k1", [{ merchant: "TAMBO", kind: "restaurant" }]));
    const rows = sqlite.prepare("SELECT kind FROM cc_votes").all();
    expect(rows).toEqual([{ kind: "restaurant" }]);
  });

  it("tope de 30 por semana; lo que sobra se descarta", async () => {
    const { sqlite, addDevice, aportar } = setup();
    addDevice("k1", 30);
    const lote = (desde: number) =>
      Array.from({ length: 20 }, (_, i) => ({ merchant: `COMERCIO ${String.fromCharCode(65 + ((desde + i) % 26))}${desde + i}X`, kind: "bar" }));
    const a = await withClock(NOW, () => aportar("k1", lote(0)));
    expect(await a.json()).toEqual({ status: "ok", accepted: 20 });
    const b = await withClock(NOW, () => aportar("k1", lote(20)));
    expect(await b.json()).toEqual({ status: "capped", accepted: 10 });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM cc_votes").get()).toEqual({ n: 30 });
  });

  it("más de 30 en un lote: 400", async () => {
    const { addDevice, aportar } = setup();
    addDevice("k1", 30);
    const items = Array.from({ length: 31 }, (_, i) => ({ merchant: `TIENDA ${i}A`, kind: "bar" }));
    expect((await withClock(NOW, () => aportar("k1", items))).status).toBe(400);
  });

  it("tres teléfonos que coinciden publican; la lista sale entera y con ETag", async () => {
    const { sqlite, addDevice, aportar, lista } = setup();
    for (const k of ["a", "b", "c"]) addDevice(k, 30);
    await withClock(NOW, async () => {
      await aportar("a", [{ merchant: "TAMBO", kind: "supermarket" }]);
      await aportar("b", [{ merchant: "TAMBO", kind: "supermarket" }]);
    });
    // Con dos, nada.
    const day1 = await withClock(NOW, () => lista("a"));
    expect(((await day1.json()) as { items: unknown[] }).items).toEqual([]);

    await withClock(NOW, () => aportar("c", [{ merchant: "TAMBO", kind: "supermarket" }]));
    // El mismo día sigue la lista calculada (se recalcula una vez al día).
    const sameDay = await withClock(NOW, () => lista("a"));
    expect(((await sameDay.json()) as { items: unknown[] }).items).toEqual([]);

    const day2 = await withClock(NOW + DAY, () => lista("a"));
    expect(day2.status).toBe(200);
    const body = (await day2.json()) as { version: string; items: [string, string][] };
    expect(body.items).toEqual([["TAMBO", "supermarket"]]);
    // Al entrar, sus votos se borran.
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM cc_votes").get()).toEqual({ n: 0 });

    const etag = day2.headers.get("etag") ?? "";
    expect(etag).toBe(`"${body.version}"`);
    const again = await withClock(NOW + DAY, () => lista("b", etag));
    expect(again.status).toBe(304);
  });

  it("cambiar un comercio publicado pide 5 teléfonos", async () => {
    const { sqlite, addDevice, aportar, lista } = setup();
    sqlite.prepare("INSERT INTO cc_published VALUES ('MIFARMA', 'pharmacy')").run();
    for (const k of ["a", "b", "c", "d", "e"]) addDevice(k, 30);
    await withClock(NOW, async () => {
      for (const k of ["a", "b", "c", "d"]) await aportar(k, [{ merchant: "MIFARMA", kind: "bar" }]);
    });
    const four = (await (await withClock(NOW + DAY, () => lista("a"))).json()) as { items: [string, string][] };
    expect(four.items).toEqual([["MIFARMA", "pharmacy"]]);
    await withClock(NOW + DAY, () => aportar("e", [{ merchant: "MIFARMA", kind: "bar" }]));
    const five = (await (await withClock(NOW + 2 * DAY, () => lista("a"))).json()) as { items: [string, string][] };
    expect(five.items).toEqual([["MIFARMA", "bar"]]);
  });

  it("los votos que confirman lo publicado no se guardan", async () => {
    const { sqlite, addDevice, aportar } = setup();
    sqlite.prepare("INSERT INTO cc_published VALUES ('MIFARMA', 'pharmacy')").run();
    addDevice("a", 30);
    const res = await withClock(NOW, () => aportar("a", [{ merchant: "MIFARMA", kind: "pharmacy" }]));
    expect(await res.json()).toEqual({ status: "ok", accepted: 1 });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM cc_votes").get()).toEqual({ n: 0 });
  });

  it("los votos y los contadores caducan a las 13 semanas", async () => {
    const { sqlite, addDevice, aportar, lista } = setup();
    for (const k of ["a", "b"]) addDevice(k, 30);
    await withClock(NOW, async () => {
      await aportar("a", [{ merchant: "BODEGA LUCHO", kind: "supermarket" }]);
      await aportar("b", [{ merchant: "BODEGA LUCHO", kind: "supermarket" }]);
    });
    await withClock(NOW + 12 * 7 * DAY, () => lista("a"));
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM cc_votes").get()).toEqual({ n: 2 });
    await withClock(NOW + 14 * 7 * DAY, () => lista("a"));
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM cc_votes").get()).toEqual({ n: 0 });
    expect(sqlite.prepare("SELECT COUNT(*) AS n FROM cc_device_week").get()).toEqual({ n: 0 });
  });
});
