import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from "jose";
import type { Env } from "./env";

/**
 * Cloudflare Access delante del panel (decisión 2). Access corta en el borde a quien no inicie sesión, pero el Worker
 * también se puede alcanzar por su `*.workers.dev` o por un error de configuración de la aplicación de Access. Por eso
 * el Worker verifica él mismo el JWT que Access le pasa en `Cf-Access-Jwt-Assertion` —firma con las llaves del equipo,
 * emisor, audiencia— y exige un correo de la lista. **Falla cerrado**: sin `ACCESS_TEAM_DOMAIN` y `ACCESS_AUD`, nadie
 * entra (503), salvo en `ENVIRONMENT = "local"` (`wrangler dev`).
 */
export type AccessVerdict = { ok: true; email: string | null } | { ok: false; status: 401 | 403 | 503; reason: string };

const jwksCache = new Map<string, JWTVerifyGetKey>();

function jwksFor(teamDomain: string): JWTVerifyGetKey {
  let jwks = jwksCache.get(teamDomain);
  if (!jwks) {
    jwks = createRemoteJWKSet(new URL(`https://${teamDomain}/cdn-cgi/access/certs`));
    jwksCache.set(teamDomain, jwks);
  }
  return jwks;
}

export function allowedEmails(env: Pick<Env, "ALLOWED_EMAILS">): string[] {
  return (env.ALLOWED_EMAILS ?? "")
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter((s) => s.length > 0);
}

export async function checkAccess(
  request: Request,
  env: Pick<Env, "ENVIRONMENT" | "ACCESS_TEAM_DOMAIN" | "ACCESS_AUD" | "ALLOWED_EMAILS">,
  getKey?: JWTVerifyGetKey,
): Promise<AccessVerdict> {
  if (env.ENVIRONMENT === "local") return { ok: true, email: null };
  const team = env.ACCESS_TEAM_DOMAIN?.trim();
  const aud = env.ACCESS_AUD?.trim();
  if (!team || !aud) return { ok: false, status: 503, reason: "panel sin Cloudflare Access configurado" };

  const token = request.headers.get("Cf-Access-Jwt-Assertion");
  if (!token) return { ok: false, status: 401, reason: "sin sesión de Access" };
  try {
    const { payload } = await jwtVerify(token, getKey ?? jwksFor(team), { issuer: `https://${team}`, audience: aud });
    const email = typeof payload.email === "string" ? payload.email.toLowerCase() : null;
    if (!email || !allowedEmails(env).includes(email)) return { ok: false, status: 403, reason: "correo sin permiso" };
    return { ok: true, email };
  } catch {
    return { ok: false, status: 401, reason: "sesión de Access inválida" };
  }
}
