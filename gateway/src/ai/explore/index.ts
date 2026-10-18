import { decodeJwt } from "jose";
import type { Env } from "../../env";
import { parseRolloutPercent } from "../../config";
import { verifyUserToken } from "../../sync/userauth";
import { assertTimeZone, InvalidInputError } from "../../../../mcp/src/logic/dates";
import type { ToolContext } from "../../../../mcp/src/toolCore";
import { exploreReader } from "./reader";

/**
 * El camino ampliado de Yala IA en modo nube (`docs/ai-cloud-vs-private-2026-10.md`): qué hace falta para que una
 * pregunta `chat.explore` use herramientas. Si falta algo, la pregunta sale como `chat.answer`, sin herramientas, y el
 * usuario recibe su respuesta igual: este camino nunca es un error nuevo.
 */

/** El JWT de Supabase del usuario. `Authorization` ya lo ocupa el token de sesión de App Attest. */
export const USER_TOKEN_HEADER = "X-Yala-User-Token";
/** Zona horaria IANA del teléfono: decide qué día es hoy y dónde empieza cada mes en las herramientas. */
export const TIME_ZONE_HEADER = "X-Yala-Time-Zone";

/**
 * Por qué una pregunta `chat.explore` sale con o sin herramientas. Va al log (`ai_route.explore`), nunca al cliente.
 * - `off`: el flag del gateway está a 0 (el estado por defecto, también en staging).
 * - `no_user`: no vino el JWT del usuario, o no verifica.
 * - `tools`: con herramientas.
 */
export type ExploreGate =
  | { readonly mode: "off" }
  | { readonly mode: "no_user" }
  | { readonly mode: "tools"; readonly toolContext: ToolContext; readonly timeZone: string; readonly timeZoneAssumed: boolean };

/**
 * El flag del gateway. Es un porcentaje porque la app lo lee de `/config` con su cohorte; el gateway solo distingue 0
 * (apagado) de cualquier otro valor, que es su interruptor de corte sin release.
 */
export function exploreEnabled(env: Env): boolean {
  return parseRolloutPercent(env.AI_CLOUD_EXPLORE_ROLLOUT_PERCENT) > 0;
}

/** Zona válida del teléfono; si falta o no existe, UTC (y se anota). */
export function exploreTimeZone(header: string | null | undefined): { timeZone: string; assumed: boolean } {
  const value = header?.trim();
  if (!value) return { timeZone: "UTC", assumed: true };
  try {
    return { timeZone: assertTimeZone(value.slice(0, 64)), assumed: false };
  } catch (err) {
    if (err instanceof InvalidInputError) return { timeZone: "UTC", assumed: true };
    throw err;
  }
}

/** Vida mínima del JWT del usuario para empezar una pregunta con herramientas (la app espera 30 s como mucho). */
export const EXPLORE_MIN_TOKEN_LIFE_MS = 60_000;

/** ¿Caduca el JWT antes de `ms`? Sin `exp` legible, sí (falla hacia el camino de siempre). */
export function expiresWithin(token: string, now: Date, ms: number): boolean {
  try {
    const exp = decodeJwt(token).exp;
    return typeof exp !== "number" || exp * 1000 - now.getTime() < ms;
  } catch {
    return true;
  }
}

export async function gateExplore(
  env: Env,
  headers: { userToken: string | null | undefined; timeZone: string | null | undefined },
  verify: typeof verifyUserToken = verifyUserToken,
  now: () => Date = () => new Date(),
): Promise<ExploreGate> {
  if (!exploreEnabled(env)) return { mode: "off" };
  const token = headers.userToken?.trim();
  if (!token) return { mode: "no_user" };
  const user = await verify(env, token);
  if (!user) return { mode: "no_user" };
  // Un JWT que caduca durante la pregunta haría fallar las lecturas a mitad: con menos de un minuto, sin herramientas.
  if (expiresWithin(user.token, now(), EXPLORE_MIN_TOKEN_LIFE_MS)) return { mode: "no_user" };
  const tz = exploreTimeZone(headers.timeZone);
  return {
    mode: "tools",
    timeZone: tz.timeZone,
    timeZoneAssumed: tz.assumed,
    toolContext: {
      reader: exploreReader(env, user.token),
      env: { SUPABASE_URL: env.SUPABASE_URL, SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY, DEFAULT_TIMEZONE: tz.timeZone },
      now: now(),
    },
  };
}
