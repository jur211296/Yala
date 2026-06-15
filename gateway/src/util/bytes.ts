/** Utilidades de bytes/crypto (WebCrypto). Sin dependencias de Node. */

export function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export function bytesToB64(bytes: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

export function b64urlToBytes(b64url: string): Uint8Array {
  const b64 = b64url.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(b64url.length / 4) * 4, "=");
  return b64ToBytes(b64);
}

export function bytesToB64url(bytes: Uint8Array): string {
  return bytesToB64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function utf8(s: string): Uint8Array {
  return new TextEncoder().encode(s);
}

export function concat(...arrays: Uint8Array[]): Uint8Array {
  const total = arrays.reduce((n, a) => n + a.length, 0);
  const out = new Uint8Array(total);
  let off = 0;
  for (const a of arrays) {
    out.set(a, off);
    off += a.length;
  }
  return out;
}

/** Comparación en tiempo ~constante (longitudes ya conocidas; sin early-return por byte). */
export function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

export async function sha256(data: Uint8Array): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", data));
}

export function readUint16BE(b: Uint8Array, offset: number): number {
  return (b[offset] << 8) | b[offset + 1];
}

export function readUint32BE(b: Uint8Array, offset: number): number {
  return ((b[offset] << 24) | (b[offset + 1] << 16) | (b[offset + 2] << 8) | b[offset + 3]) >>> 0;
}

function stripLeadingZeros(b: Uint8Array): Uint8Array {
  let i = 0;
  while (i < b.length - 1 && b[i] === 0) i++;
  return b.subarray(i);
}

function leftPad(b: Uint8Array, size: number): Uint8Array {
  if (b.length === size) return b;
  if (b.length > size) throw new Error("integer larger than expected size");
  const out = new Uint8Array(size);
  out.set(b, size - b.length);
  return out;
}

/**
 * Convierte una firma ECDSA en DER (SEQUENCE{INTEGER r, INTEGER s}) al formato crudo
 * IEEE P-1363 (r||s, 2*size bytes) que espera WebCrypto subtle.verify.
 */
export function derEcdsaToRaw(der: Uint8Array, size = 32): Uint8Array {
  let off = 0;
  if (der[off++] !== 0x30) throw new Error("DER: SEQUENCE esperado");
  let seqLen = der[off++];
  if (seqLen & 0x80) {
    const n = seqLen & 0x7f;
    seqLen = 0;
    for (let i = 0; i < n; i++) seqLen = (seqLen << 8) | der[off++];
  }
  if (der[off++] !== 0x02) throw new Error("DER: INTEGER r esperado");
  const rLen = der[off++];
  const r = der.subarray(off, off + rLen);
  off += rLen;
  if (der[off++] !== 0x02) throw new Error("DER: INTEGER s esperado");
  const sLen = der[off++];
  const s = der.subarray(off, off + sLen);
  return concat(leftPad(stripLeadingZeros(r), size), leftPad(stripLeadingZeros(s), size));
}
