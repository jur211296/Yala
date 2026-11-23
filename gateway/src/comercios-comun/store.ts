/**
 * «Comercios en común» — lo que toca D1 y KV. Las reglas puras viven en `rules.ts`.
 *
 * Nada de aquí guarda la cuenta, la IP, la hora ni importes. El teléfono entra como huella (`deviceHash`) y el voto
 * lleva la semana ISO. Ningún log nombra un comercio.
 */
import { decide, isoWeek, retentionCutoffWeek, utcDay, WEEKLY_CAP } from "./rules";

export interface Contribution {
  merchant: string;
  kind: string;
}

/** Huella del teléfono: HMAC-SHA256 del keyId de App Attest con una llave del servidor, en base64url (16 bytes). */
export async function deviceHash(secret: string, keyId: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(`comercios-comun:v1:${secret}`),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(keyId)));
  let bin = "";
  for (const b of mac.subarray(0, 16)) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/**
 * Guarda los votos de un lote, con el tope semanal. Devuelve cuántos entraron en el cupo (los que coinciden con lo ya
 * publicado cuentan pero no se guardan: no harían nada).
 */
export async function ingest(
  db: D1Database,
  hash: string,
  items: readonly Contribution[],
  nowMs: number,
): Promise<number> {
  const week = isoWeek(nowMs);
  const used = await db
    .prepare("SELECT count FROM cc_device_week WHERE device_hash = ?1 AND week = ?2")
    .bind(hash, week)
    .first<{ count: number }>();
  const room = Math.max(0, WEEKLY_CAP - (used?.count ?? 0));
  const taken = items.slice(0, room);
  if (taken.length === 0) return 0;

  const published = new Map<string, string>();
  for (const item of taken) {
    const row = await db
      .prepare("SELECT kind FROM cc_published WHERE merchant = ?1")
      .bind(item.merchant)
      .first<{ kind: string }>();
    if (row) published.set(item.merchant, row.kind);
  }

  const statements = taken
    .filter((item) => published.get(item.merchant) !== item.kind)
    .map((item) =>
      db
        .prepare(
          "INSERT INTO cc_votes (merchant, device_hash, kind, week) VALUES (?1, ?2, ?3, ?4) " +
            "ON CONFLICT(merchant, device_hash) DO UPDATE SET kind = excluded.kind, week = excluded.week",
        )
        .bind(item.merchant, hash, item.kind, week),
    );
  statements.push(
    db
      .prepare(
        "INSERT INTO cc_device_week (device_hash, week, count) VALUES (?1, ?2, ?3) " +
          "ON CONFLICT(device_hash, week) DO UPDATE SET count = count + excluded.count",
      )
      .bind(hash, week, taken.length),
  );
  await db.batch(statements);
  return taken.length;
}

/**
 * El cálculo del día: borra lo caducado, publica lo que cumple la regla y borra los votos de lo que entró.
 * Devuelve cuántos comercios entraron o cambiaron.
 */
export async function recompute(db: D1Database, nowMs: number): Promise<number> {
  const cutoff = retentionCutoffWeek(nowMs);
  await db.batch([
    db.prepare("DELETE FROM cc_votes WHERE week < ?1").bind(cutoff),
    db.prepare("DELETE FROM cc_device_week WHERE week < ?1").bind(cutoff),
  ]);

  const { results } = await db
    .prepare(
      "SELECT v.merchant AS merchant, v.kind AS kind, COUNT(*) AS n, p.kind AS published " +
        "FROM cc_votes v LEFT JOIN cc_published p ON p.merchant = v.merchant GROUP BY v.merchant, v.kind",
    )
    .all<{ merchant: string; kind: string; n: number; published: string | null }>();

  const byMerchant = new Map<string, { counts: Map<string, number>; published: string | null }>();
  for (const row of results ?? []) {
    const entry = byMerchant.get(row.merchant) ?? { counts: new Map(), published: row.published ?? null };
    entry.counts.set(row.kind, Number(row.n));
    byMerchant.set(row.merchant, entry);
  }

  const writes: D1PreparedStatement[] = [];
  for (const [merchant, { counts, published }] of byMerchant) {
    const kind = decide(counts, published);
    if (!kind) continue;
    writes.push(
      db
        .prepare(
          "INSERT INTO cc_published (merchant, kind) VALUES (?1, ?2) ON CONFLICT(merchant) DO UPDATE SET kind = excluded.kind",
        )
        .bind(merchant, kind),
      db.prepare("DELETE FROM cc_votes WHERE merchant = ?1").bind(merchant),
    );
  }
  if (writes.length > 0) await db.batch(writes);
  return writes.length / 2;
}

export interface PublishedList {
  day: string;
  etag: string;
  body: string;
}

const KV_KEY = "cc:list";

/** El cuerpo de la descarga: `{ "version": …, "items": [["TAMBO", "supermarket"], …] }`, ordenado por comercio. */
async function buildList(db: D1Database, day: string): Promise<PublishedList> {
  const { results } = await db
    .prepare("SELECT merchant, kind FROM cc_published ORDER BY merchant")
    .all<{ merchant: string; kind: string }>();
  const items = (results ?? []).map((r) => [r.merchant, r.kind]);
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(JSON.stringify(items))));
  const etag = [...digest.subarray(0, 8)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return { day, etag, body: JSON.stringify({ version: etag, items }) };
}

/**
 * La lista de hoy. La primera petición de cada día UTC hace el cálculo y la deja en KV; las demás la leen de ahí. Dos
 * peticiones a la vez pueden calcular las dos: el cálculo es idempotente.
 */
export async function todaysList(db: D1Database, kv: KVNamespace, nowMs: number): Promise<PublishedList> {
  const day = utcDay(nowMs);
  const cached = await kv.get<PublishedList>(KV_KEY, "json");
  if (cached && cached.day === day) return cached;
  await recompute(db, nowMs);
  const list = await buildList(db, day);
  await kv.put(KV_KEY, JSON.stringify(list), { expirationTtl: 2 * 24 * 60 * 60 });
  return list;
}
