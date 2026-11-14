/**
 * Lista cerrada de lo que la web puede pedir a Supabase y a Turnstile. Todo `fetch` de salida del Worker pasa por
 * aquí, y lo que no está en la lista se rechaza ANTES de salir (mismo patrón que `shared-core/src/egress.ts`).
 *
 * Por qué una lista propia y no la del conector: la web pide el permiso OAuth ella sola (`GET /auth/v1/oauth/authorize`
 * con su propio `client_id`), cosa que el conector no hace, y no tiene nada que hacer con el resto. Cada Worker
 * permite lo mínimo que usa.
 *
 * Lo permitido, y para qué:
 * - PostgREST: `GET` a una tabla (`profiles` para saber si la cuenta usa la nube; con el token de solo lectura, lo que
 *   leen el Panel, Registros y la Bandeja) y `POST` a UNA función, `yala_web_close_session` (cerrar una sesión web).
 * - Auth con la sesión NORMAL del login social, que se cierra en la misma petición: canjear el código del login
 *   (`grant_type=pkce`), contraseña (SOLO staging), leer y aprobar la autorización que la propia web pidió, y salir.
 * - Auth como cliente OAuth de la web: pedir la autorización (solo con su `client_id`), canjear el código y refrescar.
 * - Auth con la sesión de solo lectura: `GET /user` (nombre de la cuenta y sesión viva) y salir (`scope=local`).
 * - Turnstile: verificar el desafío anti-bots.
 */
import { oauthRedirectUri, type Env } from "./env";

export type Fetcher = (input: Request | string | URL, init?: RequestInit) => Promise<Response>;

export const TURNSTILE_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify";

export class EgressDenied extends Error {
  constructor(
    readonly method: string,
    readonly target: string,
  ) {
    super(`Salida no permitida: ${method} ${target}`);
    this.name = "EgressDenied";
  }
}

const AUTH_ID = "[A-Za-z0-9_-]{8,128}";

const exactly = (q: URLSearchParams, name: string, value: string) =>
  [...q.keys()].length === 1 && q.getAll(name).length === 1 && q.get(name) === value;

/** La petición de autorización del servidor OAuth: estos parámetros, una vez cada uno, y el `client_id` de la web. */
const AUTHORIZE_PARAMS = ["response_type", "client_id", "redirect_uri", "code_challenge", "code_challenge_method", "state"];
function isOwnAuthorize(env: Env, q: URLSearchParams): boolean {
  const keys = [...q.keys()];
  if (keys.length !== AUTHORIZE_PARAMS.length) return false;
  if (!AUTHORIZE_PARAMS.every((k) => q.getAll(k).length === 1)) return false;
  return (
    q.get("response_type") === "code" &&
    q.get("client_id") === env.SUPABASE_OAUTH_CLIENT_ID &&
    q.get("redirect_uri") === oauthRedirectUri(env) &&
    q.get("code_challenge_method") === "S256"
  );
}

interface Rule {
  method: string;
  path: RegExp;
  query: (q: URLSearchParams, env: Env) => boolean;
  stagingOnly?: boolean;
}

const none = (q: URLSearchParams) => [...q.keys()].length === 0;

export const SUPABASE_RULES: readonly Rule[] = [
  { method: "GET", path: /^\/rest\/v1\/[a-z_]+$/, query: () => true },
  // Cerrar a distancia una sesión web (lote 1). Sin parámetros: el id va en el cuerpo y la función filtra por cuenta.
  { method: "POST", path: /^\/rest\/v1\/rpc\/yala_web_close_session$/, query: none },
  { method: "POST", path: /^\/auth\/v1\/token$/, query: (q) => exactly(q, "grant_type", "pkce") },
  { method: "POST", path: /^\/auth\/v1\/token$/, query: (q) => exactly(q, "grant_type", "password"), stagingOnly: true },
  { method: "GET", path: /^\/auth\/v1\/oauth\/authorize$/, query: (q, env) => isOwnAuthorize(env, q) },
  { method: "GET", path: new RegExp(`^/auth/v1/oauth/authorizations/${AUTH_ID}$`), query: none },
  { method: "POST", path: new RegExp(`^/auth/v1/oauth/authorizations/${AUTH_ID}/consent$`), query: none },
  { method: "POST", path: /^\/auth\/v1\/oauth\/token$/, query: none },
  { method: "GET", path: /^\/auth\/v1\/user$/, query: none },
  { method: "POST", path: /^\/auth\/v1\/logout$/, query: (q) => exactly(q, "scope", "local") },
];

function describe(input: Request | string | URL, init?: RequestInit): { method: string; url: URL } {
  const raw = input instanceof Request ? input.url : String(input);
  const method = (init?.method ?? (input instanceof Request ? input.method : "GET")).toUpperCase();
  return { method, url: new URL(raw) };
}

export function isAllowedEgress(env: Env, method: string, url: URL): boolean {
  if (url.username || url.password || url.hash) return false;
  if (`${url.origin}${url.pathname}` === TURNSTILE_VERIFY_URL) return method === "POST" && none(url.searchParams);
  if (url.origin !== new URL(env.SUPABASE_URL).origin) return false;
  return SUPABASE_RULES.some((r) => {
    if (r.method !== method || !r.path.test(url.pathname)) return false;
    if (r.stagingOnly && env.ENVIRONMENT !== "staging") return false;
    return r.query(url.searchParams, env);
  });
}

/** Envuelve el `fetch` de salida: lo que no está en la lista lanza `EgressDenied` sin tocar la red. */
export function guardEgress(env: Env, base: Fetcher): Fetcher {
  return async (input, init) => {
    const { method, url } = describe(input, init);
    if (!isAllowedEgress(env, method, url)) throw new EgressDenied(method, `${url.origin}${url.pathname}`);
    // Sin seguir redirecciones: un 307/308 reenviaría el cuerpo (refresh, código, secreto) a otro sitio sin pasar por
    // la lista. Quien llama trata un 3xx como fallo, salvo `GET /oauth/authorize`, que espera justo ese 302.
    return base(input, { ...init, redirect: "manual" });
  };
}

/** El `fetch` global envuelto: guardado tal cual y llamado como método, el runtime de Workers lo rechaza. */
export const defaultFetch: Fetcher = (input, init) => fetch(input, init);
