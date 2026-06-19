import { AttestError } from "./verifyAttestation";
import { decodeCborMap, getBytes } from "./cbor";
import { b64ToBytes, bytesEqual, concat, derEcdsaToRaw, readUint32BE, sha256, utf8 } from "../util/bytes";

export interface AssertionResult {
  newCounter: number;
}

/**
 * Verifica una assertion de App Attest (refresh de sesión).
 *
 * @param assertion        CBOR base64 de DCAppAttestService.generateAssertion ({ signature, authenticatorData })
 * @param challenge        challenge string emitido (cliente firma SHA256(utf8(challenge)))
 * @param publicKeySpki    SPKI DER guardado en el register
 * @param storedCounter    último counter conocido (anti-replay)
 * @param appIds           ["TeamID.BundleID", …] aceptados (rpId)
 */
export async function verifyAssertion(
  assertion: string,
  challenge: string,
  publicKeySpki: Uint8Array,
  storedCounter: number,
  appIds: string[],
): Promise<AssertionResult> {
  const obj = decodeCborMap(b64ToBytes(assertion));
  const signature = getBytes(obj, "signature");
  const authenticatorData = getBytes(obj, "authenticatorData");

  // nonce = SHA256(authenticatorData || SHA256(utf8(challenge)))
  const clientDataHash = await sha256(utf8(challenge));
  const nonce = await sha256(concat(authenticatorData, clientDataHash));

  // Verificar firma ECDSA P-256 (DER -> raw r||s para WebCrypto).
  const key = await crypto.subtle.importKey(
    "spki",
    publicKeySpki,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["verify"],
  );
  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    derEcdsaToRaw(signature),
    nonce,
  );
  if (!valid) throw new AttestError("firma de assertion inválida");

  // rpId + counter monotónico (anti-replay).
  const rpIdHash = authenticatorData.subarray(0, 32);
  let rpOk = false;
  for (const appId of appIds) {
    if (bytesEqual(rpIdHash, await sha256(utf8(appId)))) {
      rpOk = true;
      break;
    }
  }
  if (!rpOk) throw new AttestError("rpId de assertion no coincide");

  const newCounter = readUint32BE(authenticatorData, 33);
  if (newCounter <= storedCounter) throw new AttestError("counter no creció (posible replay)");

  return { newCounter };
}
