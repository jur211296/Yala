import type { OAuthHelpers } from "@cloudflare/workers-oauth-provider";

export interface Env {
  /** "staging" en la fase 0. La página de inicio de sesión solo ofrece email y contraseña en staging. */
  ENVIRONMENT: string;
  /** https://<ref>.supabase.co — sin barra final. */
  SUPABASE_URL: string;
  /** Clave pública (anon). No es un secreto: RLS y el token del usuario son el control. */
  SUPABASE_ANON_KEY: string;
  /** IANA. Se usa cuando Claude no pasa `zona_horaria`. */
  DEFAULT_TIMEZONE: string;
  /**
   * URL pública de este Worker, sin barra final. Es el emisor OAuth que ve Claude, la base del recurso `/mcp` y la
   * vuelta que tiene registrada su cliente en Supabase. Se fija en configuración, no se deduce de la petición.
   */
  PUBLIC_URL: string;
  /** El cliente OAuth (confidencial) de este Worker en el servidor OAuth de Supabase. El id no es secreto. */
  SUPABASE_OAUTH_CLIENT_ID: string;
  /** Su secreto. `wrangler secret`, nunca en `wrangler.toml` ni en el repo. */
  SUPABASE_OAUTH_CLIENT_SECRET: string;
  /**
   * KV de la librería OAuth: clientes de Claude, grants y tokens (solo por hash), y las transacciones de
   * consentimiento. Los tokens de Supabase viven dentro de los `props`, cifrados con una clave que envuelve el
   * propio token de Claude: leer el KV no los revela.
   */
  OAUTH_KV: KVNamespace;
  /** Lo inyecta la librería en los handlers. */
  OAUTH_PROVIDER?: OAuthHelpers;
}

function trimSlash(url: string): string {
  return url.replace(/\/+$/, "");
}

/** Emisor de los tokens de Supabase Auth. Es el servidor de autorización AGUAS ARRIBA, no el que ve Claude. */
export function authIssuer(env: Env): string {
  return `${trimSlash(env.SUPABASE_URL)}/auth/v1`;
}

/** Origen público del Worker: emisor OAuth para Claude. */
export function publicOrigin(env: Env): string {
  return trimSlash(env.PUBLIC_URL);
}

/** El recurso protegido (RFC 8707/9728): la audiencia de todo token que emite este Worker. */
export function mcpResource(env: Env): string {
  return `${publicOrigin(env)}/mcp`;
}

/** Donde RFC 9728 manda buscar los metadatos del recurso `/mcp`. */
export function resourceMetadataUrl(env: Env): string {
  return `${publicOrigin(env)}/.well-known/oauth-protected-resource/mcp`;
}

/** La única vuelta registrada del cliente del Worker en Supabase. */
export function upstreamCallbackUrl(env: Env): string {
  return `${publicOrigin(env)}/oauth/supabase/callback`;
}
