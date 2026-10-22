/**
 * G7 — punto ÚNICO de decisión sobre `GROUPS_ENC_KEY`, la llave simétrica de pgcrypto que cifra/descifra
 * las columnas † de grupos.
 *
 * La llave viaja SIEMPRE como argumento `p_key` de un RPC (jamás a URL/query), y todos los caminos que la
 * inyectan comprueban su presencia AQUÍ: sin llave el request no se puede cumplir (leer serviría
 * ciphertext; escribir mandaría `undefined` al RPC), así que se corta con un 503 tipado que NOMBRA el
 * secreto ausente.
 *
 * Por qué existe este módulo en vez de repetir el `if`: hasta el 2026-07-31 solo `/groups/pull` y
 * `/groups/merkle` comprobaban. Los caminos de ESCRITURA —`/groups/push` y `/groups/rpc/:fn`— inyectaban
 * `p_key: env.GROUPS_ENC_KEY` a pelo, así que con el secreto ausente PostgREST recibía `p_key: undefined`
 * y devolvía un error de firma de función que no menciona el secreto por ningún lado. La asimetría (un
 * camino se explica, el otro no) es lo que cuesta el diagnóstico, y solo se elimina si el mensaje sale de
 * un único sitio: cuatro literales iguales divergen; una constante, no.
 */
import type { Env } from "../env";
import { jsonError } from "../errors";

/**
 * Mensaje único de los 503 por llave ausente. Nombra el secreto y dónde se pone: un error que no se
 * explica a sí mismo obliga a leer el código del gateway para entenderlo. No hay fuga — el NOMBRE de un
 * secret del Worker no es su valor.
 */
export const ENC_KEY_MISSING_MESSAGE =
  "GROUPS_ENC_KEY no configurada (secret del Worker: `wrangler secret put GROUPS_ENC_KEY`)";

/**
 * La llave, o la `Response` 503 lista para devolver si falta. El caller discrimina con `instanceof
 * Response` (mismo molde que `requireUserAndAttest`).
 *
 * Trata `""` como ausente: un secret puesto a cadena vacía es tan inservible como no ponerlo, y pgcrypto
 * lo rechazaría con un error tan opaco como el de `undefined`.
 */
export function requireEncKey(env: Env): string | Response {
  const key = env.GROUPS_ENC_KEY;
  if (!key) return jsonError("yala_unavailable", ENC_KEY_MISSING_MESSAGE, 503);
  return key;
}
