/** El binding Rate Limiting de Workers (`[[ratelimits]]`), con la forma que documenta Cloudflare. */
export interface RateLimiter {
  limit(options: { key: string }): Promise<{ success: boolean }>;
}

export interface Env {
  /** "staging" o "production". El login con contraseña (pruebas de punta a punta) solo existe en staging. */
  ENVIRONMENT: string;
  /** Origen público de la web, sin barra final. Base de la cookie, de las vueltas y del control de `Origin`. */
  PUBLIC_URL: string;
  /** https://<ref>.supabase.co — sin barra final. */
  SUPABASE_URL: string;
  /** Clave pública (anon). No es un secreto: RLS y el token del usuario son el control. */
  SUPABASE_ANON_KEY: string;
  /** El cliente OAuth CONFIDENCIAL de la web en el servidor OAuth de Supabase. Su token sale de solo lectura. */
  SUPABASE_OAUTH_CLIENT_ID: string;
  /** Su secreto: `wrangler secret put`, nunca en `wrangler.toml` ni en el repo. */
  SUPABASE_OAUTH_CLIENT_SECRET: string;
  /** Clave pública del widget de Turnstile (la ve el navegador). */
  TURNSTILE_SITE_KEY: string;
  /** Su secreto, con el que el Worker verifica el desafío. `wrangler secret put`. */
  TURNSTILE_SECRET_KEY: string;
  /** Sesiones web y logins a medias. Todo va por el hash de la cookie y los tokens, cifrados (`session.ts`). */
  WEB_KV: KVNamespace;
  /** La página (Vite) que sirve el Worker. */
  ASSETS: Fetcher;
  /**
   * La cola de borradores COMÚN (decisión D9): el D1 del gateway del mismo entorno, tabla `mail_drafts`. La web solo
   * inserta filas suyas (`source: "web"`) y cuenta las de hoy; el iPhone las recoge por `GET /mail/drafts` del gateway.
   */
  DRAFTS_DB: D1Database;
  /** La lista de sesiones web de cada cuenta: un Durable Object por cuenta (`sessionIndex.ts`). */
  SESSION_INDEX: DurableObjectNamespace;
  /** Los códigos de «Entrar con tu iPhone» (QR): un Durable Object por código (`qrPairing.ts`, lote 2). */
  QR_PAIRING: DurableObjectNamespace;
  /**
   * Grupos (lote 3): service binding al gateway del mismo entorno, entrada `WebGroupsReader`. Lee los grupos con el
   * token de solo lectura de la sesión; la llave del cifrado de Grupos no sale del gateway. Opcional: sin él, Grupos
   * responde 503 y lo demás sigue.
   */
  GATEWAY_GROUPS?: import("./groups").GroupsReaderBinding;
  /** IANA. La zona con la que se decide qué día es hoy si la app nunca subió la suya (como el conector). */
  DEFAULT_TIMEZONE: string;
  /** Límite por IP en `/auth/*` (lo abre el navegador). Opcional en los tests; en producción, obligatorio. */
  RL_AUTH?: RateLimiter;
  /** Límite por sesión en `/api/*`. */
  RL_API?: RateLimiter;
  /** Límite por IP en `/auth/qr/estado` y `/auth/qr/renovar`, que el navegador pregunta cada pocos segundos. */
  RL_QR?: RateLimiter;
}

function trimSlash(url: string): string {
  return url.replace(/\/+$/, "");
}

export function publicOrigin(env: Env): string {
  return trimSlash(env.PUBLIC_URL);
}

/** Emisor de los tokens de Supabase Auth. */
export function authIssuer(env: Env): string {
  return `${trimSlash(env.SUPABASE_URL)}/auth/v1`;
}

/** Adonde vuelve el navegador después de entrar con Apple o Google. Tiene que estar en `uri_allow_list` de Supabase. */
export function loginReturnUrl(env: Env): string {
  return `${publicOrigin(env)}/auth/callback`;
}

/**
 * La vuelta registrada del cliente OAuth de la web. El navegador nunca pasa por ella: el servidor pide y aprueba el
 * permiso él solo y lee el código de la respuesta (`supabase.ts`). Tiene que coincidir con la registrada en Supabase.
 */
export function oauthRedirectUri(env: Env): string {
  return `${publicOrigin(env)}/auth/supabase/callback`;
}

export function isStaging(env: Env): boolean {
  return env.ENVIRONMENT === "staging";
}
