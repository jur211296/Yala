export interface Env {
  /** "staging" en la fase 0. La página de consentimiento solo ofrece email y contraseña en staging. */
  ENVIRONMENT: string;
  /** https://<ref>.supabase.co — sin barra final. */
  SUPABASE_URL: string;
  /** Clave pública (anon). No es un secreto: RLS y el token del usuario son el control. */
  SUPABASE_ANON_KEY: string;
  /** IANA. Se usa cuando Claude no pasa `zona_horaria`. */
  DEFAULT_TIMEZONE: string;
}

/** Emisor de los tokens de Supabase Auth. Es también el identificador del servidor de autorización. */
export function authIssuer(env: Env): string {
  return `${env.SUPABASE_URL.replace(/\/+$/, "")}/auth/v1`;
}
