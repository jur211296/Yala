/**
 * El Durable Object de la lista de sesiones web de UNA cuenta (`idFromName(<user id>)`), con su SQLite. Ver
 * `sessions.ts` para qué guarda y por qué no va en el KV. Solo lo importa la entrada del Worker (`index.ts`): las
 * pruebas usan un doble con los mismos métodos.
 */
import { DurableObject } from "cloudflare:workers";
import { asEntry, type SessionEntry, type SessionIndexApi } from "./sessions";

/** Más de 50 sesiones abiertas no es una persona: se conservan las 50 usadas más recientemente. */
const MAX_ENTRIES = 50;

export class SessionIndex extends DurableObject implements SessionIndexApi {
  private readonly sql: SqlStorage;

  constructor(ctx: DurableObjectState, env: unknown) {
    super(ctx, env as never);
    this.sql = ctx.storage.sql;
    this.sql.exec("CREATE TABLE IF NOT EXISTS sesiones (pid TEXT PRIMARY KEY, datos TEXT NOT NULL, uso INTEGER NOT NULL, expira INTEGER NOT NULL)");
    this.sql.exec("CREATE TABLE IF NOT EXISTS cupo (dia TEXT PRIMARY KEY, n INTEGER NOT NULL)");
  }

  async has(pid: string, now: number): Promise<boolean> {
    return [...this.sql.exec("SELECT 1 AS x FROM sesiones WHERE pid = ? AND expira > ?", pid, Math.floor(now))].length > 0;
  }

  async takeDraftSlot(dia: string, max: number): Promise<boolean> {
    this.sql.exec("DELETE FROM cupo WHERE dia <> ?", dia);
    const row = [...this.sql.exec<{ n: number }>("SELECT n FROM cupo WHERE dia = ?", dia)][0];
    const n = row?.n ?? 0;
    if (n >= max) return false;
    this.sql.exec("INSERT OR REPLACE INTO cupo (dia, n) VALUES (?, ?)", dia, n + 1);
    return true;
  }

  async put(entry: SessionEntry, expira: number): Promise<void> {
    this.sql.exec(
      "INSERT OR REPLACE INTO sesiones (pid, datos, uso, expira) VALUES (?, ?, ?, ?)",
      entry.pid,
      JSON.stringify(entry),
      entry.uso,
      Math.floor(expira),
    );
    this.sql.exec(`DELETE FROM sesiones WHERE pid NOT IN (SELECT pid FROM sesiones ORDER BY uso DESC LIMIT ${MAX_ENTRIES})`);
  }

  async remove(pid: string): Promise<void> {
    this.sql.exec("DELETE FROM sesiones WHERE pid = ?", pid);
  }

  async list(now: number): Promise<SessionEntry[]> {
    this.sql.exec("DELETE FROM sesiones WHERE expira <= ?", Math.floor(now));
    const out: SessionEntry[] = [];
    for (const row of this.sql.exec<{ datos: string }>("SELECT datos FROM sesiones ORDER BY uso DESC")) {
      try {
        const e = asEntry(JSON.parse(row.datos));
        if (e) out.push(e);
      } catch {
        // Una fila ilegible no tumba la lista.
      }
    }
    return out;
  }

  async touch(pid: string, uso: number, sid: string, expira: number): Promise<void> {
    const row = [...this.sql.exec<{ datos: string }>("SELECT datos FROM sesiones WHERE pid = ?", pid)][0];
    if (!row) return;
    let e: SessionEntry | null = null;
    try {
      e = asEntry(JSON.parse(row.datos));
    } catch {
      e = null;
    }
    if (!e) return;
    const next = { ...e, uso, sid };
    this.sql.exec("UPDATE sesiones SET datos = ?, uso = ?, expira = ? WHERE pid = ?", JSON.stringify(next), uso, Math.floor(expira), pid);
  }
}
