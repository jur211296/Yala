/**
 * La configuración del Worker se comprueba ANTES de atender nada, y si está mal el Worker no atiende: responde 503 a
 * todo. Falla cerrado.
 *
 * Por qué. La configuración de producción se escribe a mano en `wrangler.toml`, copiando de staging. Los errores que
 * eso deja son silenciosos y caros: la anon key de staging con la URL de producción, una URL pública con ruta (el
 * emisor OAuth deja de cuadrar), un id de cliente que se quedó en «PENDIENTE», o un despliegue sin los límites de
 * peticiones. Ninguno rompe el despliegue; todos rompen la seguridad o el login más tarde. Aquí se cazan en la
 * primera petición, con un log que dice QUÉ falla y sin enseñar ningún valor.
 */
import type { Env } from "./env";

/** El proyecto de Supabase de staging. Un Worker de producción que apunte a él está mal configurado. */
export const STAGING_SUPABASE_REF = "fostjbbwstyuunmmefuk";

export const ENVIRONMENTS = ["staging", "production"] as const;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SUPABASE_HOST_RE = /^([a-z0-9]{20})\.supabase\.co$/;

/** Una URL que solo es un origen https: sin ruta, query, fragmento ni credenciales. */
function httpsOrigin(raw: string | undefined): URL | null {
  if (!raw) return null;
  let u: URL;
  try {
    u = new URL(raw);
  } catch {
    return null;
  }
  if (u.protocol !== "https:") return null;
  // `new URL` normaliza y acepta rutas, queries o credenciales: solo vale si lo escrito ES el origen.
  if (raw.replace(/\/+$/, "") !== u.origin) return null;
  return u;
}

function validTimezone(tz: string | undefined): boolean {
  if (!tz) return false;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

/** El payload de un JWT sin verificar. Solo para leer `ref` y `role` de la anon key, que es pública. */
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

/**
 * Qué está mal en la configuración, en frases cortas y sin valores. Vacío = se puede atender.
 *
 * En todos los entornos: entorno conocido, URLs como orígenes https, cliente de Supabase con id y secreto, zona
 * horaria válida y KV enlazado. Además, en producción: que Supabase sea un proyecto real y NO el de staging, que la
 * anon key sea de ese mismo proyecto, que la URL pública no diga «staging», y que los tres límites de peticiones
 * estén enlazados.
 */
export function configProblems(env: Partial<Env>): string[] {
  const problems: string[] = [];
  const environment = env.ENVIRONMENT ?? "";
  if (!(ENVIRONMENTS as readonly string[]).includes(environment)) problems.push("ENVIRONMENT no es staging ni production");

  const publicUrl = httpsOrigin(env.PUBLIC_URL);
  if (!publicUrl) problems.push("PUBLIC_URL no es un origen https (sin ruta, query ni fragmento)");
  const supabaseUrl = httpsOrigin(env.SUPABASE_URL);
  if (!supabaseUrl) problems.push("SUPABASE_URL no es un origen https");
  if (!env.SUPABASE_ANON_KEY) problems.push("falta SUPABASE_ANON_KEY");
  if (!env.SUPABASE_OAUTH_CLIENT_ID || !UUID_RE.test(env.SUPABASE_OAUTH_CLIENT_ID)) {
    problems.push("SUPABASE_OAUTH_CLIENT_ID no es un uuid (¿sigue PENDIENTE?)");
  }
  if (!env.SUPABASE_OAUTH_CLIENT_SECRET) problems.push("falta el secreto SUPABASE_OAUTH_CLIENT_SECRET (wrangler secret put)");
  if (!validTimezone(env.DEFAULT_TIMEZONE)) problems.push("DEFAULT_TIMEZONE no es una zona IANA válida");
  if (!env.OAUTH_KV) problems.push("falta el KV OAUTH_KV");
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
    if (!env.RL_BROWSER || !env.RL_OAUTH || !env.RL_MCP) problems.push("faltan los límites de peticiones (RL_BROWSER, RL_OAUTH, RL_MCP)");
  }
  return problems;
}

/** La respuesta de un Worker mal configurado. No dice qué falla: eso va al log, no a quien llama. */
export function misconfiguredResponse(): Response {
  return Response.json(
    { error: "temporarily_unavailable", error_description: "Servicio no disponible" },
    { status: 503, headers: { "Retry-After": "300", "Cache-Control": "no-store" } },
  );
}
