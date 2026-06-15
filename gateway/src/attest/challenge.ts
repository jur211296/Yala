import type { Env } from "../env";
import { b64urlToBytes, bytesToB64url, concat } from "../util/bytes";

/**
 * Challenge stateless (HMAC + timestamp). No usa KV → evita la consistencia eventual de KV
 * entre PoPs (el /challenge y el /register/assert pueden caer en regiones distintas).
 *
 * No requiere uso-único almacenado: en register el nonce queda ligado a una attestation de
 * llave de un solo uso; en assert el counter monotónico de App Attest es la defensa anti-replay.
 *
 * El cliente trata el `challenge` como string opaco y firma SHA256(utf8(challenge)) dentro de
 * la attestation/assertion. El server recibe el mismo string de vuelta, valida su HMAC+frescura
 * y recomputa el clientDataHash con sus bytes.
 */
const CHALLENGE_TTL_MS = 120_000;
const PAYLOAD_LEN = 24; // 16 nonce + 8 timestamp

async function hmacKey(env: Env): Promise<CryptoKey> {
  // Separación de dominio respecto al firmado de JWT, reusando el mismo secret.
  const raw = new TextEncoder().encode("yala-challenge-v1:" + env.JWT_SIGNING_SECRET);
  return crypto.subtle.importKey("raw", raw, { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]);
}

export async function issueChallenge(env: Env): Promise<{ challenge: string; ttlMs: number }> {
  const nonce = crypto.getRandomValues(new Uint8Array(16));
  const tsBuf = new Uint8Array(8);
  new DataView(tsBuf.buffer).setBigUint64(0, BigInt(Date.now()));
  const payload = concat(nonce, tsBuf);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", await hmacKey(env), payload));
  return { challenge: `${bytesToB64url(payload)}.${bytesToB64url(mac)}`, ttlMs: CHALLENGE_TTL_MS };
}

export async function verifyChallenge(env: Env, challenge: string): Promise<boolean> {
  const parts = challenge.split(".");
  if (parts.length !== 2) return false;
  let payload: Uint8Array;
  let mac: Uint8Array;
  try {
    payload = b64urlToBytes(parts[0]);
    mac = b64urlToBytes(parts[1]);
  } catch {
    return false;
  }
  if (payload.length !== PAYLOAD_LEN) return false;
  const ok = await crypto.subtle.verify("HMAC", await hmacKey(env), mac, payload);
  if (!ok) return false;
  const tsMs = Number(new DataView(payload.buffer, payload.byteOffset + 16, 8).getBigUint64(0));
  return Date.now() - tsMs <= CHALLENGE_TTL_MS;
}
