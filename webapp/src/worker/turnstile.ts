/**
 * Defensa anti-bots al entrar (Cloudflare Turnstile). Un navegador no puede demostrar que es Yala como lo hace el iPhone
 * con App Attest, así que antes de mandar a nadie al login social el Worker verifica el desafío en el servidor.
 * Falla cerrado: sin respuesta de Cloudflare, no se entra.
 */
import type { Env } from "./env";
import { TURNSTILE_VERIFY_URL, type Fetcher } from "./egress";

export async function verifyTurnstile(env: Env, fetcher: Fetcher, token: string | null, ip: string | null): Promise<boolean> {
  if (!token || token.length > 2048) return false;
  const form = new URLSearchParams({ secret: env.TURNSTILE_SECRET_KEY, response: token });
  if (ip) form.set("remoteip", ip);
  try {
    const res = await fetcher(TURNSTILE_VERIFY_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form.toString(),
    });
    if (!res.ok) return false;
    const body = (await res.json()) as { success?: unknown };
    return body.success === true;
  } catch {
    return false;
  }
}
