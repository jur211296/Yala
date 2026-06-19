import { decodeCBOR } from "@levischuck/tiny-cbor";

/** Decodifica un mapa CBOR (attestation object / assertion). tiny-cbor devuelve Map. */
export function decodeCborMap(bytes: Uint8Array): Map<string, unknown> {
  const decoded = decodeCBOR(bytes);
  if (!(decoded instanceof Map)) throw new Error("CBOR: se esperaba un mapa");
  return decoded as Map<string, unknown>;
}

export function getBytes(map: Map<string, unknown>, key: string): Uint8Array {
  const v = map.get(key);
  if (!(v instanceof Uint8Array)) throw new Error(`CBOR: '${key}' no es byte string`);
  return v;
}

export function getString(map: Map<string, unknown>, key: string): string {
  const v = map.get(key);
  if (typeof v !== "string") throw new Error(`CBOR: '${key}' no es string`);
  return v;
}
