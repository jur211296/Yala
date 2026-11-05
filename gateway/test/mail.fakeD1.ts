/**
 * D1 de verdad (SQLite en memoria, `node:sqlite`) con la migración del correo aplicada. Los tests del correo comprueban
 * SQL que cuenta (cupo, techo diario, «visto»), así que un fake que solo registre statements no probaría nada.
 */
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { fileURLToPath } from "node:url";

type Row = Record<string, unknown>;

export function makeMailD1(extraSql: string[] = []): { db: D1Database; sqlite: DatabaseSync } {
  const sqlite = new DatabaseSync(":memory:");
  const migration = readFileSync(fileURLToPath(new URL("../migrations/0003_mail_forwarding.sql", import.meta.url)), "utf8");
  sqlite.exec(migration);
  sqlite.exec(
    "CREATE TABLE account_entitlements (user_id TEXT PRIMARY KEY, entitlement_product TEXT, entitlement_expires_at INTEGER, original_transaction_id TEXT NOT NULL, bound_via TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)",
  );
  for (const s of extraSql) sqlite.exec(s);

  const prepare = (sql: string) => {
    let params: unknown[] = [];
    // SQLite de node no acepta `?1`… mezclado con `?`; D1 sí. Se traducen los numerados a nombrados.
    const numbered = /\?(\d+)/.test(sql);
    const text = numbered ? sql.replace(/\?(\d+)/g, (_, n: string) => `:p${n}`) : sql;
    const args = () => {
      if (!numbered) return params as never[];
      const named: Record<string, unknown> = {};
      params.forEach((v, i) => (named[`p${i + 1}`] = v));
      return [named] as never[];
    };
    const stmt = {
      bind(...p: unknown[]) {
        params = p.map((v) => (v === undefined ? null : v));
        return stmt;
      },
      async first<T = Row>() {
        return (sqlite.prepare(text).get(...args()) as T | undefined) ?? null;
      },
      async all<T = Row>() {
        return { results: sqlite.prepare(text).all(...args()) as T[], success: true, meta: {} };
      },
      async run() {
        const r = sqlite.prepare(text).run(...args());
        return { success: true, meta: { changes: Number(r.changes) } };
      },
    };
    return stmt;
  };
  const db = {
    prepare,
    async batch(stmts: { run: () => Promise<unknown> }[]) {
      const out = [];
      for (const s of stmts) out.push(await s.run());
      return out;
    },
  } as unknown as D1Database;
  return { db, sqlite };
}
