/**
 * Cabeceras de seguridad que el Worker pone a TODO lo que sirve, página incluida (por eso `run_worker_first`).
 *
 * - CSP cerrada: scripts solo de aquí y de Turnstile; ningún `fetch` fuera de este origen; no se puede incrustar en
 *   otra página (`frame-ancestors 'none'`: incrustar en Claude es del lote 5). `form-action` deja que el formulario de
 *   entrar siga la redirección a Supabase y de ahí a Apple o Google.
 * - `Referrer-Policy: no-referrer`: la vuelta del login lleva un código en la URL, y no debe viajar a ningún sitio.
 * - `Cache-Control: no-store` en todo menos los ficheros con huella de `/assets/`: ninguna página ni respuesta con datos
 *   se guarda en la caché del navegador.
 */
import type { Env } from "./env";

export function securityHeaders(env: Env, pathname: string): Record<string, string> {
  const supabase = new URL(env.SUPABASE_URL).origin;
  const csp = [
    "default-src 'none'",
    "script-src 'self' https://challenges.cloudflare.com",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data:",
    "font-src 'self'",
    "connect-src 'self'",
    "frame-src https://challenges.cloudflare.com",
    `form-action 'self' ${supabase} https://appleid.apple.com https://accounts.google.com`,
    "base-uri 'none'",
    "frame-ancestors 'none'",
    "manifest-src 'self'",
  ].join("; ");
  return {
    "Content-Security-Policy": csp,
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Cross-Origin-Opener-Policy": "same-origin",
    "Strict-Transport-Security": "max-age=31536000",
    "Permissions-Policy": "camera=(), microphone=(), geolocation=(), payment=()",
    "Cache-Control": pathname.startsWith("/assets/") ? "public, max-age=31536000, immutable" : "no-store",
  };
}

export function withHeaders(env: Env, pathname: string, res: Response): Response {
  const out = new Response(res.body, res);
  for (const [k, v] of Object.entries(securityHeaders(env, pathname))) out.headers.set(k, v);
  return out;
}
