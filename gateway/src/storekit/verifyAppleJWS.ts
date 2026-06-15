import * as x509 from "@peculiar/x509";
import { APPLE_ROOT_CA_G3_PEM } from "./appleRootG3";
import { b64ToBytes, b64urlToBytes, utf8 } from "../util/bytes";

x509.cryptoProvider.set(crypto as Crypto);

/**
 * Verifica un JWS firmado por Apple (transacciones StoreKit 2 y App Store Server Notifications V2),
 * OFFLINE: cadena x5c [leaf, intermediate] contra el Apple Root CA - G3 embebido + firma ES256.
 * Devuelve el payload decodificado si todo valida, o null.
 */
export async function verifyAppleJWS(jws: string): Promise<Record<string, unknown> | null> {
  const parts = jws.split(".");
  if (parts.length !== 3) return null;
  const [headerB64, payloadB64, sigB64] = parts;

  let header: { alg?: string; x5c?: string[] };
  try {
    header = JSON.parse(new TextDecoder().decode(b64urlToBytes(headerB64)));
  } catch {
    return null;
  }
  if (header.alg !== "ES256" || !Array.isArray(header.x5c) || header.x5c.length < 2) return null;

  const leaf = new x509.X509Certificate(b64ToBytes(header.x5c[0]));
  const intermediate = new x509.X509Certificate(b64ToBytes(header.x5c[1]));
  const g3 = new x509.X509Certificate(APPLE_ROOT_CA_G3_PEM);
  const now = new Date();
  if (!(await leaf.verify({ publicKey: intermediate.publicKey, date: now }))) return null;
  if (!(await intermediate.verify({ publicKey: g3.publicKey, date: now }))) return null;
  if (now < leaf.notBefore || now > leaf.notAfter) return null;
  if (now < intermediate.notBefore || now > intermediate.notAfter) return null;

  const key = await crypto.subtle.importKey(
    "spki",
    leaf.publicKey.rawData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["verify"],
  );
  // La firma JWS ES256 ya viene en formato crudo r||s.
  const sigValid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    b64urlToBytes(sigB64),
    utf8(`${headerB64}.${payloadB64}`),
  );
  if (!sigValid) return null;

  try {
    return JSON.parse(new TextDecoder().decode(b64urlToBytes(payloadB64)));
  } catch {
    return null;
  }
}
