/**
 * merkle.ts — el ENSAMBLADO Merkle de dos canales (I8f-3, §d.7). Regla A-4 CONGELADA (cross-lenguaje,
 * fijada por `merkle_fixtures.json` — el mini-golden que consumen este lado y `SyncMerkleTests` Swift):
 *
 *   leaf   = sha256( utf8(sync_id_lowercase_36) ‖ sha256(utf8(payload_c1)) )            (Canal 1, SIN hlc)
 *   entity = sha256( concat( leaves ordenados por sync_id bytes UTF-8 asc ) )
 *            entidad sin filas → sha256("") (cadena vacía)
 *   root   = sha256( concat( entityHash de las 16 tablas en orden UTF-8 asc de nombre ) )
 *   leaf2  = sha256( utf8(sync_id) ‖ utf8(hlc) ‖ sha256(utf8(payload_full)) )            (Canal 2, interno)
 *
 * Los digests se concatenan CRUDOS (32 bytes), nunca su hex. Buckets POR ENTIDAD (A-1): la detección
 * es exacta a nivel tabla; el trie fino por-sync_id queda DIFERIDO (gatillo: volumen). El Canal 2 es
 * informativo en v1 (el cliente NO lo recomputa) — auditoría full-row server-side, INCLUYE filas
 * `deleted=true` (el Canal 1 las EXCLUYE: A-2, el cliente no tiene fila local que hashear para un
 * tombstone aplicado → incluirlas garantizaría divergencia falsa permanente).
 */
import { utf8Compare } from "./canon";

const utf8 = new TextEncoder();

/** SHA-256 (WebCrypto — disponible en Workers y en Node ≥20 para los tests offline). */
export async function sha256(bytes: Uint8Array): Promise<Uint8Array> {
  const digest = await crypto.subtle.digest("SHA-256", bytes as unknown as ArrayBuffer);
  return new Uint8Array(digest);
}

export function hex(bytes: Uint8Array): string {
  let out = "";
  for (const b of bytes) out += b.toString(16).padStart(2, "0");
  return out;
}

function concatBytes(parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const p of parts) {
    out.set(p, offset);
    offset += p.length;
  }
  return out;
}

/** Canal 1: leaf = sha256(utf8(sync_id) ‖ sha256(utf8(payload))). `syncId` DEBE venir lowercase-36. */
export async function leafChannel1(syncId: string, payload: string): Promise<Uint8Array> {
  const payloadDigest = await sha256(utf8.encode(payload));
  return sha256(concatBytes([utf8.encode(syncId), payloadDigest]));
}

/** Canal 2: leaf2 = sha256(utf8(sync_id) ‖ utf8(hlc) ‖ sha256(utf8(payload_full))). */
export async function leafChannel2(syncId: string, hlc: string, payload: string): Promise<Uint8Array> {
  const payloadDigest = await sha256(utf8.encode(payload));
  return sha256(concatBytes([utf8.encode(syncId), utf8.encode(hlc), payloadDigest]));
}

/** entityHash = sha256(concat(leaves ordenados por sync_id bytes UTF-8 asc)); vacía → sha256(""). */
export async function entityHash(leaves: Array<{ syncId: string; leaf: Uint8Array }>): Promise<Uint8Array> {
  const sorted = [...leaves].sort((a, b) => utf8Compare(a.syncId, b.syncId));
  return sha256(concatBytes(sorted.map((l) => l.leaf)));
}

/** root = sha256(concat(entityHash en orden UTF-8 asc del nombre de tabla)). SIEMPRE todas las tablas. */
export async function merkleRoot(entityHashes: Map<string, Uint8Array>): Promise<Uint8Array> {
  const tables = [...entityHashes.keys()].sort(utf8Compare);
  return sha256(concatBytes(tables.map((t) => entityHashes.get(t)!)));
}
