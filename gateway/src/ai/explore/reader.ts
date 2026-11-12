import { YalaReader, type Fetcher } from "../../../../mcp/src/data";
import type { SupabaseEnv } from "../../../../mcp/src/supabaseEnv";

/**
 * Lectura de las tablas del usuario para el camino ampliado de Yala IA, con el JWT de Supabase del USUARIO (RLS filtra
 * a sus filas). Nunca `service_role`.
 *
 * Lista cerrada propia, más estrecha que la del conector (`mcp/src/egress.ts`, que además permite el login de su
 * pantalla): solo `GET` a las tablas que leen las seis herramientas. El JWT del usuario sí puede escribir por
 * PostgREST; esta lista hace que ningún camino del gateway pueda hacerlo con él, ni por un bug ni porque el modelo
 * convenza a una herramienta de pedir otra cosa.
 */
export const EXPLORE_TABLES: ReadonlySet<string> = new Set([
  "accounts",
  "categories",
  "subcategories",
  "tags",
  "tx_items",
  "budgets",
  "scheduled_payments",
  "exchange_rates",
  "user_preferences",
]);

/**
 * Tope de filas por consulta. El conector lee hasta 20 000 porque no tiene prisa; aquí cada pregunta tiene unos
 * segundos. Si se alcanza, la herramienta lo dice en sus `avisos` («la cifra puede quedarse corta»).
 */
export const EXPLORE_MAX_ROWS = 5_000;

export class ExploreEgressDenied extends Error {
  constructor(readonly method: string, readonly path: string) {
    super(`Salida no permitida desde el camino ampliado: ${method} ${path}`);
    this.name = "ExploreEgressDenied";
  }
}

/** ¿Puede salir esta petición? `GET` a `/rest/v1/<tabla de la lista>` del proyecto, y nada más. */
export function isAllowedExploreRead(env: SupabaseEnv, method: string, url: URL): boolean {
  if (method !== "GET") return false;
  if (url.origin !== new URL(env.SUPABASE_URL).origin) return false;
  if (url.username || url.password || url.hash) return false;
  const m = url.pathname.match(/^\/rest\/v1\/([a-z_]+)$/);
  return !!m && EXPLORE_TABLES.has(m[1]);
}

export function guardExploreReads(env: SupabaseEnv, base: Fetcher): Fetcher {
  return async (input, init) => {
    const raw = input instanceof Request ? input.url : String(input);
    const method = (init?.method ?? (input instanceof Request ? input.method : "GET")).toUpperCase();
    const url = new URL(raw);
    if (!isAllowedExploreRead(env, method, url)) throw new ExploreEgressDenied(method, url.pathname);
    return base(input, init);
  };
}

/** El lector de las herramientas, con la lista cerrada del gateway por fuera de la del conector. */
export function exploreReader(env: SupabaseEnv, userJWT: string, base: Fetcher = (i, init) => fetch(i, init)): YalaReader {
  return new YalaReader(env, userJWT, guardExploreReads(env, base), EXPLORE_MAX_ROWS);
}
