import type { Context } from "hono";
import type { Env } from "../env";
import { requireSession } from "../auth";
import { gateRequest } from "../ratelimit";

type Ctx = Context<{ Bindings: Env }>;

const RATES_BASE = "https://api.exchangerate.host";
const TTL_LIVE = 6 * 60 * 60; // 6h
const TTL_TIMEFRAME = 24 * 60 * 60; // histórico: cache duro

/**
 * Proxy a exchangerate.host con la key server-side. Las tasas NO son por-usuario → se cachean en
 * el edge (Cache API) y se sirven a todos desde ahí, colapsando N llamadas de usuarios en pocas.
 * Conserva la forma JSON original → el cliente decodifica sin cambios.
 */
async function proxyRates(c: Ctx, endpoint: "live" | "timeframe", ttl: number): Promise<Response> {
  const claims = await requireSession(c);
  if (claims instanceof Response) return claims;
  const blocked = await gateRequest(c.env, claims, "rates");
  if (blocked) return blocked;

  const url = new URL(c.req.url);
  const clientParams = new URLSearchParams(url.search);
  clientParams.delete("access_key"); // nunca confiar en la key del cliente; usar la del Worker

  // Clave de cache SIN el secret (compartida entre usuarios).
  const cacheKey = new Request(`https://rates-cache/${endpoint}?${clientParams.toString()}`);
  const cache = caches.default;
  const hit = await cache.match(cacheKey);
  if (hit) return hit;

  const upstreamParams = new URLSearchParams(clientParams);
  upstreamParams.set("access_key", c.env.EXCHANGE_RATE_API_KEY);
  const resp = await fetch(`${RATES_BASE}/${endpoint}?${upstreamParams.toString()}`);
  if (!resp.ok) {
    return new Response(resp.body, { status: resp.status, headers: { "content-type": "application/json" } });
  }

  // exchangerate.host devuelve 200 con {"success":false,...} en errores de cuota/símbolo.
  // NO cachear esos cuerpos: si no, un error transitorio envenena el edge por horas para todos.
  const text = await resp.text();
  let cacheable = true;
  try {
    if ((JSON.parse(text) as { success?: boolean }).success === false) cacheable = false;
  } catch {
    cacheable = false;
  }
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (cacheable) headers["cache-control"] = `public, max-age=${ttl}`;
  const out = new Response(text, { status: 200, headers });
  if (cacheable) c.executionCtx.waitUntil(cache.put(cacheKey, out.clone()));
  return out;
}

export function handleRatesLive(c: Ctx): Promise<Response> {
  return proxyRates(c, "live", TTL_LIVE);
}

export function handleRatesTimeframe(c: Ctx): Promise<Response> {
  return proxyRates(c, "timeframe", TTL_TIMEFRAME);
}
