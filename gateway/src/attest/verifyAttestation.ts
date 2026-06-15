import * as x509 from "@peculiar/x509";
import { APPLE_APP_ATTEST_ROOT_CA_PEM } from "./appleRootCA";
import { decodeCborMap, getBytes, getString } from "./cbor";
import { b64ToBytes, bytesEqual, concat, readUint16BE, readUint32BE, sha256, utf8 } from "../util/bytes";

x509.cryptoProvider.set(crypto as Crypto);

export class AttestError extends Error {}

const NONCE_OID = "1.2.840.113635.100.8.2";
const AAGUID_DEV = utf8("appattestdevelop"); // 16 bytes
const AAGUID_PROD = concat(utf8("appattest"), new Uint8Array(7)); // "appattest" + 7×0x00

export interface AttestationResult {
  publicKeySpki: ArrayBuffer; // para almacenar y reimportar en assertions
  signCount: number;
  matchedAppId: string;
}

/**
 * Verifica una attestation de App Attest siguiendo los pasos de Apple
 * ("Validating Apps That Connect to Your Server").
 *
 * @param attestationObject CBOR base64 devuelto por DCAppAttestService.attestKey
 * @param keyId             keyId base64 del device
 * @param challenge         el challenge string que emitimos (el cliente firma SHA256(utf8(challenge)))
 * @param appIds            ["TeamID.BundleID", …] aceptados (rpId)
 * @param expectedEnv       "development" | "production"
 */
export async function verifyAttestation(
  attestationObject: string,
  keyId: string,
  challenge: string,
  appIds: string[],
  expectedEnv: string,
): Promise<AttestationResult> {
  // 1. Decodificar el attestation object CBOR.
  const att = decodeCborMap(b64ToBytes(attestationObject));
  if (getString(att, "fmt") !== "apple-appattest") throw new AttestError("fmt inválido");
  const attStmt = att.get("attStmt");
  if (!(attStmt instanceof Map)) throw new AttestError("attStmt ausente");
  const authData = getBytes(att, "authData");
  const x5c = attStmt.get("x5c");
  if (!Array.isArray(x5c) || x5c.length < 2) throw new AttestError("x5c inválido");

  // 2. Verificar la cadena credCert -> intermediate -> Apple Root CA (embebido).
  const credCert = new x509.X509Certificate(x5c[0] as Uint8Array);
  const intermediate = new x509.X509Certificate(x5c[1] as Uint8Array);
  const root = new x509.X509Certificate(APPLE_APP_ATTEST_ROOT_CA_PEM);
  const now = new Date();
  const chainOk =
    (await credCert.verify({ publicKey: intermediate.publicKey, date: now })) &&
    (await intermediate.verify({ publicKey: root.publicKey, date: now }));
  if (!chainOk) throw new AttestError("cadena de certificados inválida");
  assertValidityWindow(credCert, now);
  assertValidityWindow(intermediate, now);

  // 3. nonce = SHA256(authData || SHA256(utf8(challenge))).
  const clientDataHash = await sha256(utf8(challenge));
  const expectedNonce = await sha256(concat(authData, clientDataHash));

  // 4. Comparar contra el nonce embebido en la extensión OID 1.2.840.113635.100.8.2 del credCert.
  const certNonce = extractNonceExtension(credCert);
  if (!bytesEqual(certNonce, expectedNonce)) throw new AttestError("nonce no coincide");

  // 5. keyId == SHA256(punto público sin comprimir).
  const spki = credCert.publicKey.rawData;
  const spkiBytes = new Uint8Array(spki);
  const rawPoint = spkiBytes.subarray(spkiBytes.length - 65); // P-256: 0x04 || X || Y al final del SPKI
  if (rawPoint[0] !== 0x04) throw new AttestError("punto público inesperado");
  if (!bytesEqual(await sha256(rawPoint), b64ToBytes(keyId))) throw new AttestError("keyId no coincide con la clave");

  // 6. authData: rpIdHash, signCount, AAGUID (env), credentialId.
  const rpIdHash = authData.subarray(0, 32);
  const matchedAppId = await matchRpId(rpIdHash, appIds);
  if (!matchedAppId) throw new AttestError("rpId no coincide");

  const aaguid = authData.subarray(37, 53);
  const envOk = expectedEnv === "production" ? bytesEqual(aaguid, AAGUID_PROD) : bytesEqual(aaguid, AAGUID_DEV);
  if (!envOk) throw new AttestError(`AAGUID no corresponde al entorno '${expectedEnv}'`);

  const credIdLen = readUint16BE(authData, 53);
  const credId = authData.subarray(55, 55 + credIdLen);
  if (!bytesEqual(credId, b64ToBytes(keyId))) throw new AttestError("credentialId no coincide con keyId");

  const signCount = readUint32BE(authData, 33);
  return { publicKeySpki: spki, signCount, matchedAppId };
}

function assertValidityWindow(cert: x509.X509Certificate, now: Date): void {
  if (now < cert.notBefore || now > cert.notAfter) throw new AttestError("certificado fuera de su período de validez");
}

async function matchRpId(rpIdHash: Uint8Array, appIds: string[]): Promise<string | null> {
  for (const appId of appIds) {
    if (bytesEqual(rpIdHash, await sha256(utf8(appId)))) return appId;
  }
  return null;
}

/** Extrae el nonce de 32 bytes de la extensión Apple: SEQUENCE { [1] EXPLICIT OCTET STRING(32) }. */
function extractNonceExtension(cert: x509.X509Certificate): Uint8Array {
  const ext = cert.getExtension(NONCE_OID);
  if (!ext) throw new AttestError("falta la extensión de nonce");
  const v = new Uint8Array(ext.value);
  // 30 LL  A1 LL  04 20  <32 bytes>
  if (v[0] !== 0x30 || v[2] !== 0xa1 || v[4] !== 0x04 || v[5] !== 0x20) {
    throw new AttestError("formato de extensión de nonce inesperado");
  }
  const nonce = v.subarray(6, 6 + 32);
  if (nonce.length !== 32) throw new AttestError("longitud de nonce inesperada");
  return nonce;
}
