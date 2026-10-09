/**
 * Puerta de los goldens que hablan con STAGING real (`account.goldens`, `groups.goldens`, `push.fanout`,
 * `sync.goldens`). El job `gateway` del CI corre `npm test` sin ninguna credencial de staging, y esos
 * ficheros lanzaban en su `beforeAll` («Falta USER_A_PASS…»): el job salía rojo por configuración, no
 * por código. Con esta puerta se saltan y la parte offline de la suite decide el color.
 *
 * Se saltan SOLO si no hay NINGUNA credencial. Con alguna puesta y otra no, siguen corriendo y el
 * `beforeAll` lanza con el nombre de la que falta: un entorno a medias es un error de quien lanza los
 * goldens a mano, y saltárselo en silencio le daría un verde que no probó staging.
 */
import { describe } from "vitest";

const CREDENCIALES_STAGING = [
  "USER_A_PASS",
  "USER_B_PASS",
  "USER_C_PASS",
  "GROUPS_ENC_KEY",
  "PUSH_ROLE_JWT",
] as const;

export const SIN_STAGING = CREDENCIALES_STAGING.every((nombre) => !process.env[nombre]);

/** `describe` de un bloque que habla con staging: se salta entero cuando `SIN_STAGING`. */
export const describeStaging = describe.skipIf(SIN_STAGING);
