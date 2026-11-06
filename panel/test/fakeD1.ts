import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";

/**
 * Una D1 de verdad en SQL (SQLite de Node), con la migración real aplicada: lo que se prueba es el SQL del panel, no
 * un doble que acepta cualquier cosa. Implementa lo que usa src/store.ts: prepare/bind/run/first/all y batch.
 */
export function fakeD1(): D1Database {
  const db = new DatabaseSync(":memory:");
  db.exec(readFileSync(new URL("../migrations/0001_daily.sql", import.meta.url), "utf8"));
  const stmt = (sql: string, params: unknown[] = []) => ({
    bind: (...p: unknown[]) => stmt(sql, p),
    run: async () => {
      db.prepare(sql).run(...params);
      return { success: true };
    },
    first: async () => db.prepare(sql).get(...params) ?? null,
    all: async () => ({ results: db.prepare(sql).all(...params).map((r) => ({ ...r })) }),
    _exec: () => db.prepare(sql).run(...params),
  });
  return {
    prepare: (sql: string) => stmt(sql),
    batch: async (stmts: { _exec: () => unknown }[]) => {
      db.exec("BEGIN");
      try {
        for (const s of stmts) s._exec();
        db.exec("COMMIT");
      } catch (e) {
        db.exec("ROLLBACK");
        throw e;
      }
      return [];
    },
  } as unknown as D1Database;
}
