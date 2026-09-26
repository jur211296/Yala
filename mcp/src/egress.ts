/**
 * Lista cerrada de lo que este Worker puede pedir a Supabase. Toda petición del Worker a Supabase pasa por aquí, y lo
 * que no está en la lista se rechaza ANTES de salir.
 *
 * Por qué existe. Desde que Claude recibe un token propio del Worker (ver `authorize.ts`), el único que tiene en la
 * mano una sesión de Supabase es este Worker. Esa sesión es de solo lectura en la base (`yala_mcp_reader`), pero
 * GoTrue no mira el rol: con ella se podría cambiar la cuenta (`PUT /auth/v1/user`, `POST /auth/v1/factors`…). Que
 * el código no lo haga hoy no basta; esta lista hace que ningún camino del código PUEDA hacerlo, ni por un bug ni
 * porque alguien convenza a una herramienta de pedir otra URL.
 *
 * Lo permitido, y para qué:
 * - PostgREST: solo `GET` a una tabla. `/rest/v1/rpc/*` no cabe en el patrón.
 * - Auth, con la sesión web de la pantalla de login (staging): iniciar sesión con contraseña, leer y aprobar la
 *   autorización OAuth que el propio Worker pidió, y cerrar esa sesión (`scope=local`).
 * - Auth, como cliente OAuth del Worker: canjear el código y refrescar.
 * - Auth, con la sesión de solo lectura: `GET /user`, para saber si sigue viva (revocación al momento).
 */
import type { Env } from "./env";

export type Fetcher = (input: Request | string | URL, init?: RequestInit) => Promise<Response>;

export class EgressDenied extends Error {
  constructor(
    readonly method: string,
    readonly target: string,
  ) {
    super(`Salida a Supabase no permitida: ${method} ${target}`);
    this.name = "EgressDenied";
  }
}

interface Rule {
  method: string;
  path: RegExp;
  /** Si está, la query tiene que cumplirla. Si no está, la query tiene que venir vacía… salvo en PostgREST. */
  query?: (q: URLSearchParams) => boolean;
  anyQuery?: boolean;
}

const onlyParam = (name: string, value: string) => (q: URLSearchParams) =>
  [...q.keys()].length === 1 && q.getAll(name).length === 1 && q.get(name) === value;

const AUTH_ID = "[A-Za-z0-9_-]{8,128}";

export const EGRESS_RULES: readonly Rule[] = [
  { method: "GET", path: /^\/rest\/v1\/[a-z_]+$/, anyQuery: true },
  { method: "POST", path: /^\/auth\/v1\/token$/, query: onlyParam("grant_type", "password") },
  { method: "GET", path: new RegExp(`^/auth/v1/oauth/authorizations/${AUTH_ID}$`) },
  { method: "POST", path: new RegExp(`^/auth/v1/oauth/authorizations/${AUTH_ID}/consent$`) },
  { method: "POST", path: /^\/auth\/v1\/oauth\/token$/ },
  { method: "GET", path: /^\/auth\/v1\/user$/ },
  { method: "POST", path: /^\/auth\/v1\/logout$/, query: onlyParam("scope", "local") },
];

function describe(input: Request | string | URL, init?: RequestInit): { method: string; url: URL } {
  const raw = input instanceof Request ? input.url : String(input);
  const method = (init?.method ?? (input instanceof Request ? input.method : "GET")).toUpperCase();
  return { method, url: new URL(raw) };
}

export function isAllowedEgress(env: Env, method: string, url: URL): boolean {
  if (url.origin !== new URL(env.SUPABASE_URL).origin) return false;
  if (url.username || url.password || url.hash) return false;
  return EGRESS_RULES.some((r) => {
    if (r.method !== method || !r.path.test(url.pathname)) return false;
    if (r.anyQuery) return true;
    if (r.query) return r.query(url.searchParams);
    return [...url.searchParams.keys()].length === 0;
  });
}

/** Envuelve el `fetch` de salida: lo que no está en la lista lanza `EgressDenied` sin tocar la red. */
export function guardSupabase(env: Env, base: Fetcher): Fetcher {
  return async (input, init) => {
    const { method, url } = describe(input, init);
    if (!isAllowedEgress(env, method, url)) throw new EgressDenied(method, `${url.origin}${url.pathname}`);
    return base(input, init);
  };
}

/**
 * El `fetch` global, envuelto a propósito: guardado tal cual y llamado como método, el runtime de Workers lo rechaza
 * («Illegal invocation»). Lo cazó el e2e de la fase 0 (2026-09-26).
 */
export const defaultFetch: Fetcher = (input, init) => fetch(input, init);
