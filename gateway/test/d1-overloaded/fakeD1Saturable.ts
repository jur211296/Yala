/**
 * D1 de verdad (SQLite en memoria, `node:sqlite`) con la migración de `account_entitlements` aplicada y un punto
 * donde inyectar el error que Cloudflare devolvió el 2026-11-25: `D1_ERROR: D1 DB is overloaded. Requests queued for
 * too long.`, con la causa encadenada como la trae el runtime. Un fallo inyectado NO ejecuta la sentencia (eso es lo
 * que significa «queued for too long»), y el batch es atómico, como en D1.
 */
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { fileURLToPath } from "node:url";

export type Operacion = "first" | "run" | "batch";

/** Devuelve el error que debe lanzar esta llamada, o `null` para ejecutarla. */
export type Inyector = (op: Operacion, sql: string) => Error | null;

export function errorSaturada(): Error {
  const causa = new Error("D1 DB is overloaded. Requests queued for too long.");
  return new Error("D1_ERROR: D1 DB is overloaded. Requests queued for too long.", { cause: causa });
}

export interface D1Saturable {
  db: D1Database;
  sqlite: DatabaseSync;
  /** Llamadas que llegaron al D1 (ejecutadas o fallidas), en orden. */
  llamadas: { op: Operacion; sql: string; fallo: boolean }[];
  /** Batches que se ejecutaron de verdad (sin fallo inyectado). */
  batchesEjecutados: () => number;
  inyectar: (i: Inyector | null) => void;
}

export function makeD1Saturable(): D1Saturable {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(
    readFileSync(fileURLToPath(new URL("../../migrations/0002_account_entitlements.sql", import.meta.url)), "utf8"),
  );
  const llamadas: D1Saturable["llamadas"] = [];
  let inyector: Inyector | null = null;

  const pasar = (op: Operacion, sql: string) => {
    const err = inyector ? inyector(op, sql) : null;
    llamadas.push({ op, sql, fallo: err != null });
    if (err) throw err;
  };

  const prepare = (sql: string) => {
    let params: unknown[] = [];
    const stmt = {
      __sql: sql,
      bind(...p: unknown[]) {
        params = p.map((v) => (v === undefined ? null : v));
        return stmt;
      },
      __run() {
        sqlite.prepare(sql).run(...(params as never[]));
      },
      async first<T>() {
        pasar("first", sql);
        return (sqlite.prepare(sql).get(...(params as never[])) as T | undefined) ?? null;
      },
      async run() {
        pasar("run", sql);
        const r = sqlite.prepare(sql).run(...(params as never[]));
        return { success: true, meta: { changes: Number(r.changes) } };
      },
    };
    return stmt;
  };

  const db = {
    prepare,
    async batch(stmts: { __sql: string; __run: () => void }[]) {
      pasar("batch", stmts.map((s) => s.__sql).join(" ;; "));
      sqlite.exec("BEGIN");
      try {
        for (const s of stmts) s.__run();
        sqlite.exec("COMMIT");
      } catch (e) {
        sqlite.exec("ROLLBACK");
        throw e;
      }
      return stmts.map(() => ({ success: true }));
    },
  } as unknown as D1Database;

  return {
    db,
    sqlite,
    llamadas,
    batchesEjecutados: () => llamadas.filter((l) => l.op === "batch" && !l.fallo).length,
    inyectar: (i) => {
      inyector = i;
    },
  };
}
