/**
 * La configuración se comprueba ANTES de atender nada, y si está mal el Worker responde 503 a todo: falla cerrado.
 * Mismo criterio que el conector (`mcp/src/config.ts`): los errores de una configuración copiada a mano no rompen el
 * despliegue, rompen la seguridad más tarde. Aquí se cazan en la primera petición, con un log que dice QUÉ falla y sin
 * enseñar ningún valor.
 */
import type { Env } from "./env";

/** El proyecto de Supabase de staging. Una web de producción que apunte a él está mal configurada. */
export const STAGING_SUPABASE_REF = "fostjbbwstyuunmmefuk";

/**
 * Claves de prueba que publica Cloudflare para Turnstile: siempre pasan (o siempre fallan) y no protegen de nada.
 * Valen en staging mientras no exista el widget real; en producción se rechazan.
 * https://developers.cloudflare.com/turnstile/troubleshooting/testing/
 */
const TURNSTILE_TEST_KEY_RE = /^[123]x0{10,}/;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SUPABASE_HOST_RE = /^([a-z0-9]{20})\.supabase\.co$/;

function httpsOrigin(raw: string | undefined): URL | null {
  if (!raw) return null;
  let u: URL;
  try {
    u = new URL(raw);
  } catch {
    return null;
  }
  if (u.protocol !== "https:") return null;
  if (raw.replace(/\/+$/, "") !== u.origin) return null;
  return u;
}

function jwtClaims(token: string): Record<string, unknown> | null {
  const part = token.split(".")[1];
  if (!part) return null;
  try {
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/");
    const parsed: unknown = JSON.parse(atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4)));
    return parsed && typeof parsed === "object" ? (parsed as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

export function isTurnstileTestKey(key: string | undefined): boolean {
  return !!key && TURNSTILE_TEST_KEY_RE.test(key);
}

/** Qué está mal, en frases cortas y sin valores. Vacío = se puede atender. */
export function configProblems(env: Partial<Env>): string[] {
  const problems: string[] = [];
  const environment = env.ENVIRONMENT ?? "";
  if (environment !== "staging" && environment !== "production") problems.push("ENVIRONMENT no es staging ni production");

  const publicUrl = httpsOrigin(env.PUBLIC_URL);
  if (!publicUrl) problems.push("PUBLIC_URL no es un origen https (sin ruta, query ni fragmento)");
  const supabaseUrl = httpsOrigin(env.SUPABASE_URL);
  if (!supabaseUrl) problems.push("SUPABASE_URL no es un origen https");
  if (!env.SUPABASE_ANON_KEY) problems.push("falta SUPABASE_ANON_KEY");
  if (!env.SUPABASE_OAUTH_CLIENT_ID || !UUID_RE.test(env.SUPABASE_OAUTH_CLIENT_ID)) {
    problems.push("SUPABASE_OAUTH_CLIENT_ID no es un uuid (¿sigue PENDIENTE?)");
  }
  if (!env.SUPABASE_OAUTH_CLIENT_SECRET) problems.push("falta el secreto SUPABASE_OAUTH_CLIENT_SECRET");
  if (!env.TURNSTILE_SITE_KEY) problems.push("falta TURNSTILE_SITE_KEY");
  if (!env.TURNSTILE_SECRET_KEY) problems.push("falta el secreto TURNSTILE_SECRET_KEY");
  if (!env.WEB_KV) problems.push("falta el KV WEB_KV");
  if (!env.ASSETS) problems.push("falta el binding ASSETS");

  // Staging tiene el login con contraseña y acepta las claves de prueba de Turnstile: solo vale contra el Supabase de
  // staging. Un Worker de producción copiado a mano con ENVIRONMENT=staging no atiende.
  if (environment === "staging" && supabaseUrl && SUPABASE_HOST_RE.exec(supabaseUrl.hostname)?.[1] !== STAGING_SUPABASE_REF) {
    problems.push("ENVIRONMENT es staging pero SUPABASE_URL no es el proyecto de staging");
  }

  if (environment === "production") {
    const ref = supabaseUrl ? SUPABASE_HOST_RE.exec(supabaseUrl.hostname)?.[1] : undefined;
    if (supabaseUrl && !ref) problems.push("SUPABASE_URL no es un proyecto <ref>.supabase.co");
    if (ref === STAGING_SUPABASE_REF) problems.push("SUPABASE_URL apunta al proyecto de STAGING");
    if (ref && env.SUPABASE_ANON_KEY) {
      const claims = jwtClaims(env.SUPABASE_ANON_KEY);
      if (!claims || claims["ref"] !== ref || claims["role"] !== "anon") {
        problems.push("SUPABASE_ANON_KEY no es la anon key del proyecto de SUPABASE_URL");
      }
    }
    if (publicUrl && /staging/i.test(publicUrl.hostname)) problems.push("PUBLIC_URL es de staging");
    if (isTurnstileTestKey(env.TURNSTILE_SITE_KEY) || isTurnstileTestKey(env.TURNSTILE_SECRET_KEY)) {
      problems.push("Turnstile usa las claves de prueba de Cloudflare");
    }
    if (!env.RL_AUTH || !env.RL_API) problems.push("faltan los límites de peticiones (RL_AUTH, RL_API)");
  }
  return problems;
}
