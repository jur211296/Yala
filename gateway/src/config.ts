import type { Context } from "hono";
import type { Env } from "./env";

type Ctx = Context<{ Bindings: Env }>;

/**
 * GET /config — remote-config PÚBLICA del cliente (DIFERIDOS #34, §j.1/§j.2).
 *
 * Kill-switch sin release del CLIENTE: los valores viven en wrangler.toml [vars] (patrón ENFORCE
 * de §j.2 — flip = editar la var + `wrangler deploy`, versionado en git). Sin auth/attest y sin
 * bindings (ni D1 ni KV): es config pre-sesión que las superficies de ENTRADA leen antes de que
 * exista usuario, y un kill-switch no puede caerse por una dependencia.
 *
 * Percent 0-100 por flag (decisión owner 2026-07-17): 0 = OFF, 100 = ON; el cliente computa un
 * bucket estable por instalación y queda dentro si bucket < percent (escalón gradual §j.2 desde
 * el día 1). Ausente/inválido → 0 (fail-closed server-side). Cache pública corta: gobierna el
 * cache CLIENT-side (URLCache del device — Cloudflare NO cachea en el edge respuestas generadas
 * por Workers sin Cache API, y a ≤1 req/instalación/6h el costo de invocación es trivial); un
 * flip tarda ≤ CONFIG_CACHE_MAX_AGE en propagar (aceptado: el kill corta ENTRADAS, no runtime).
 */
const CONFIG_CACHE_MAX_AGE = 300;

/** Parse fail-closed de un percent de rollout: entero clampeado a [0,100]; ausente/inválido → 0. */
export function parseRolloutPercent(raw: string | undefined): number {
  if (raw === undefined) return 0;
  const n = Number.parseInt(raw, 10);
  if (Number.isNaN(n)) return 0;
  return Math.min(100, Math.max(0, n));
}

/**
 * Parse fail-closed del umbral de forzado (min-version): número de BUILD (CFBundleVersion) por
 * debajo del cual el cliente muestra la pantalla bloqueante. Piso 0 = desactivado (ningún build < 0).
 * Ausente/inválido → 0. SIN clamp superior: los builds crecen sin techo (≠ percents).
 */
export function parseMinBuild(raw: string | undefined): number {
  if (raw === undefined) return 0;
  const n = Number.parseInt(raw, 10);
  if (Number.isNaN(n)) return 0;
  return Math.max(0, n);
}

export function handleConfig(c: Ctx): Response {
  const body = {
    v: 1,
    flags: {
      cloudModeRolloutPercent: parseRolloutPercent(c.env.CLOUD_MODE_ROLLOUT_PERCENT),
      cloudOnboardingChoiceRolloutPercent: parseRolloutPercent(c.env.CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT),
      groupsBackendRolloutPercent: parseRolloutPercent(c.env.GROUPS_BACKEND_ROLLOUT_PERCENT),
    },
    // Forzado de actualización (min-version). DARK en prod: el cliente prod no fetchea /config
    // (CloudBackendConfig.isConfigured == false) → inerte hasta el encendido (D9). 0 = desactivado.
    forceUpdate: {
      minSupportedBuild: parseMinBuild(c.env.MIN_SUPPORTED_BUILD),
    },
  };
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {
      "content-type": "application/json",
      "cache-control": `public, max-age=${CONFIG_CACHE_MAX_AGE}`,
    },
  });
}
