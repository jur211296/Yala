import { describe, expect, it } from "vitest";
import {
  b64ToBytes,
  b64urlToBytes,
  bytesEqual,
  bytesToB64,
  bytesToB64url,
  concat,
  derEcdsaToRaw,
  readUint16BE,
  readUint32BE,
  sha256,
} from "../src/util/bytes";

describe("base64", () => {
  it("roundtrip estándar", () => {
    const data = new Uint8Array([0, 1, 2, 250, 255, 128]);
    expect([...b64ToBytes(bytesToB64(data))]).toEqual([...data]);
  });
  it("roundtrip base64url sin padding", () => {
    const data = new Uint8Array([251, 255, 191, 0, 1]);
    const s = bytesToB64url(data);
    expect(s).not.toContain("=");
    expect(s).not.toContain("+");
    expect(s).not.toContain("/");
    expect([...b64urlToBytes(s)]).toEqual([...data]);
  });
});

describe("helpers", () => {
  it("concat", () => {
    expect([...concat(new Uint8Array([1, 2]), new Uint8Array([3]))]).toEqual([1, 2, 3]);
  });
  it("bytesEqual", () => {
    expect(bytesEqual(new Uint8Array([1, 2]), new Uint8Array([1, 2]))).toBe(true);
    expect(bytesEqual(new Uint8Array([1, 2]), new Uint8Array([1, 3]))).toBe(false);
    expect(bytesEqual(new Uint8Array([1]), new Uint8Array([1, 2]))).toBe(false);
  });
  it("readUint16BE / readUint32BE", () => {
    expect(readUint16BE(new Uint8Array([0x12, 0x34]), 0)).toBe(0x1234);
    expect(readUint32BE(new Uint8Array([0x00, 0x00, 0x01, 0x00]), 0)).toBe(256);
    expect(readUint32BE(new Uint8Array([0xff, 0xff, 0xff, 0xff]), 0)).toBe(0xffffffff);
  });
  it("sha256 vector conocido (abc)", async () => {
    const h = await sha256(new TextEncoder().encode("abc"));
    expect(bytesToB64(h)).toBe("ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=");
  });
});

describe("derEcdsaToRaw", () => {
  it("vector simple r=1 s=2", () => {
    const der = new Uint8Array([0x30, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01, 0x02]);
    const raw = derEcdsaToRaw(der);
    expect(raw.length).toBe(64);
    expect(raw[31]).toBe(1);
    expect(raw[63]).toBe(2);
    expect(raw.slice(0, 31).every((b) => b === 0)).toBe(true);
  });

  it("integer con bit alto (00 ff)", () => {
    const der = new Uint8Array([0x30, 0x07, 0x02, 0x02, 0x00, 0xff, 0x02, 0x01, 0x7f]);
    const raw = derEcdsaToRaw(der);
    expect(raw[31]).toBe(0xff); // se quita el 0x00 de relleno DER
    expect(raw[63]).toBe(0x7f);
  });

  it("roundtrip con firma ECDSA P-256 real (mismo path que verifyAssertion)", async () => {
    const kp = (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, [
      "sign",
      "verify",
    ])) as CryptoKeyPair;
    const msg = new TextEncoder().encode("yala");
    const rawSig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, kp.privateKey, msg));
    const der = rawToDer(rawSig);
    const backToRaw = derEcdsaToRaw(der);

    // Reimporta como SPKI (igual que el Worker reimporta la clave guardada) y verifica.
    const spki = new Uint8Array((await crypto.subtle.exportKey("spki", kp.publicKey)) as ArrayBuffer);
    const pub = await crypto.subtle.importKey("spki", spki, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
    const ok = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, pub, backToRaw, msg);
    expect(ok).toBe(true);
  });
});

/** Codifica r||s crudo a DER (solo para el test). */
function rawToDer(raw: Uint8Array): Uint8Array {
  const enc = (i: Uint8Array): number[] => {
    let n = 0;
    while (n < i.length - 1 && i[n] === 0) n++;
    let v = [...i.slice(n)];
    if (v[0] & 0x80) v = [0x00, ...v];
    return [0x02, v.length, ...v];
  };
  const body = [...enc(raw.slice(0, 32)), ...enc(raw.slice(32, 64))];
  return new Uint8Array([0x30, body.length, ...body]);
}
