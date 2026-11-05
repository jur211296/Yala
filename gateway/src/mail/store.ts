import type { Env } from "../env";
import { generateCode } from "./address";

/** D1 del correo del banco (`migrations/0003_mail_forwarding.sql`). */

export const TRIAL_LIMIT = 5;
export const DAILY_CAP = 50;
export const DRAFT_TTL_MS = 30 * 24 * 3600 * 1000;
/** Un código de Gmail es útil unas horas: pasado un día ya no se enseña. */
export const GMAIL_CODE_TTL_MS = 24 * 3600 * 1000;

export interface MailAddressRow {
  user_id: string;
  code: string;
  created_at: number;
  trial_used: number;
  skipped_quota: number;
  gmail_code: string | null;
  gmail_code_at: number | null;
  last_received_at: number | null;
  day_key: string | null;
  day_count: number;
}

export async function getAddressByUser(env: Env, userId: string): Promise<MailAddressRow | null> {
  return env.DB.prepare("SELECT * FROM mail_addresses WHERE user_id = ?").bind(userId).first<MailAddressRow>();
}

export async function getAddressByCode(env: Env, code: string): Promise<MailAddressRow | null> {
  return env.DB.prepare("SELECT * FROM mail_addresses WHERE code = ?").bind(code).first<MailAddressRow>();
}

/** La dirección de la cuenta, creándola si no existe. Idempotente: dos llamadas a la vez dejan una sola fila. */
export async function getOrCreateAddress(env: Env, userId: string, now = Date.now()): Promise<MailAddressRow> {
  const existing = await getAddressByUser(env, userId);
  if (existing) return existing;
  for (let attempt = 0; attempt < 3; attempt++) {
    const code = generateCode();
    try {
      await env.DB.prepare("INSERT OR IGNORE INTO mail_addresses (user_id, code, created_at) VALUES (?, ?, ?)")
        .bind(userId, code, now)
        .run();
    } catch {
      continue; // choque del UNIQUE de `code` (≈0): otro código
    }
    const row = await getAddressByUser(env, userId);
    if (row) return row;
  }
  throw new Error("mail: no se pudo crear la dirección");
}

/** Cuenta un correo recibido contra el techo diario. `false` si ya se pasó (no se lee). */
export async function countReceived(env: Env, userId: string, now = Date.now()): Promise<boolean> {
  const day = new Date(now).toISOString().slice(0, 10);
  const res = await env.DB.prepare(
    `UPDATE mail_addresses
        SET day_count = CASE WHEN day_key = ?1 THEN day_count + 1 ELSE 1 END,
            day_key = ?1,
            last_received_at = ?2
      WHERE user_id = ?3 AND (day_key IS NOT ?1 OR day_count < ?4)`,
  )
    .bind(day, now, userId, DAILY_CAP)
    .run();
  return (res.meta?.changes ?? 0) > 0;
}

/** `true` la primera vez que se ve este aviso; `false` si es repetido. */
export async function markSeen(env: Env, userId: string, messageHash: string, now = Date.now()): Promise<boolean> {
  const res = await env.DB.prepare("INSERT OR IGNORE INTO mail_seen (user_id, message_hash, seen_at) VALUES (?, ?, ?)")
    .bind(userId, messageHash, now)
    .run();
  return (res.meta?.changes ?? 0) > 0;
}

export async function forgetSeen(env: Env, userId: string, messageHash: string): Promise<void> {
  await env.DB.prepare("DELETE FROM mail_seen WHERE user_id = ? AND message_hash = ?").bind(userId, messageHash).run();
}

/** Reserva un uso del cupo de prueba. `false` si ya se gastaron los 5. */
export async function reserveTrial(env: Env, userId: string): Promise<boolean> {
  const res = await env.DB.prepare("UPDATE mail_addresses SET trial_used = trial_used + 1 WHERE user_id = ? AND trial_used < ?")
    .bind(userId, TRIAL_LIMIT)
    .run();
  return (res.meta?.changes ?? 0) > 0;
}

export async function refundTrial(env: Env, userId: string): Promise<void> {
  await env.DB.prepare("UPDATE mail_addresses SET trial_used = trial_used - 1 WHERE user_id = ? AND trial_used > 0").bind(userId).run();
}

export async function countSkipped(env: Env, userId: string): Promise<void> {
  await env.DB.prepare("UPDATE mail_addresses SET skipped_quota = skipped_quota + 1 WHERE user_id = ?").bind(userId).run();
}

export async function saveGmailCode(env: Env, userId: string, code: string, now = Date.now()): Promise<void> {
  await env.DB.prepare("UPDATE mail_addresses SET gmail_code = ?, gmail_code_at = ? WHERE user_id = ?").bind(code, now, userId).run();
}

export interface DraftPayload {
  kind: "expense" | "income" | null;
  amount: number;
  currency: string | null;
  merchant: string | null;
  date: string | null;
  bank: string | null;
  account_last4: string | null;
}

export async function insertDraft(env: Env, userId: string, payload: DraftPayload, now = Date.now()): Promise<string> {
  const id = crypto.randomUUID();
  await env.DB.prepare("INSERT INTO mail_drafts (id, user_id, created_at, payload) VALUES (?, ?, ?, ?)")
    .bind(id, userId, now, JSON.stringify(payload))
    .run();
  return id;
}

export interface StoredDraft {
  id: string;
  created_at: number;
  payload: DraftPayload;
}

/** Los borradores de la cuenta, del más viejo al más nuevo. Los de más de 30 días se borran antes de leer. */
export async function listDrafts(env: Env, userId: string, now = Date.now()): Promise<StoredDraft[]> {
  await env.DB.prepare("DELETE FROM mail_drafts WHERE user_id = ? AND created_at < ?").bind(userId, now - DRAFT_TTL_MS).run();
  const res = await env.DB.prepare("SELECT id, created_at, payload FROM mail_drafts WHERE user_id = ? ORDER BY created_at LIMIT 100")
    .bind(userId)
    .all<{ id: string; created_at: number; payload: string }>();
  const out: StoredDraft[] = [];
  for (const row of res.results ?? []) {
    try {
      out.push({ id: row.id, created_at: row.created_at, payload: JSON.parse(row.payload) as DraftPayload });
    } catch {
      // Una fila ilegible no tumba la lista; se va con el TTL.
    }
  }
  return out;
}

/** Borra los borradores que la app ya creó. Solo los de ESTA cuenta: un id ajeno no hace nada. */
export async function ackDrafts(env: Env, userId: string, ids: string[]): Promise<number> {
  if (ids.length === 0) return 0;
  const stmts = ids.map((id) => env.DB.prepare("DELETE FROM mail_drafts WHERE id = ? AND user_id = ?").bind(id, userId));
  const results = await env.DB.batch(stmts);
  return results.reduce((n, r) => n + (r.meta?.changes ?? 0), 0);
}

/** Borrado de cuenta: dirección, cola y vistos. Lo llama `/account/delete`. */
export async function deleteMailData(env: Env, userId: string): Promise<void> {
  await env.DB.batch([
    env.DB.prepare("DELETE FROM mail_drafts WHERE user_id = ?").bind(userId),
    env.DB.prepare("DELETE FROM mail_seen WHERE user_id = ?").bind(userId),
    env.DB.prepare("DELETE FROM mail_addresses WHERE user_id = ?").bind(userId),
  ]);
}
