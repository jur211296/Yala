import type { Context } from "hono";
import type { Env } from "./env";
import { jsonError } from "./errors";

type Ctx = Context<{ Bindings: Env }>;

/**
 * POST /metrics — ingestión PÚBLICA de telemetría propia mínima (sustituye a TelemetryDeck, 2026-07-17).
 *
 * Tres eventos y nada más: `ping` (usuarios activos/día — el cliente garantiza ≤1/día con guard local),
 * `register` (altas/día, n = local|cloud) y `canary` (diagnósticos operativos del gate de Modo Nube —
 * la condición de encendido "canarios en cero" se lee de aquí). Escribe a Workers Analytics Engine
 * (binding METRICS; dataset yala_metrics_staging / yala_metrics).
 *
 * Sin auth/attest (molde GET /config): el ping diario corre pre-sesión y los canarios no pueden
 * depender de una sesión viva. Anti-abuso: whitelist de eventos + regex de nombres + caps de tamaño
 * (la cardinalidad de AE es barata y un atacante no puede escribir más que strings acotados).
 * `install` es un hash SHA-256 truncado del seed local del cliente — no reversible, no enlazable a
 * cuenta; JAMÁS llega aquí un userID, email ni dato financiero.
 *
 * Mapeo AE por evento: blobs [e, n, d, appVersion, install], doubles [x], indexes [install]
 * (sampling por instalación — preserva counts distintos). Queries de referencia en qa/cloud/README
 * (§ /metrics): SIEMPRE sum(_sample_interval), jamás count() a secas.
 *
 * Binding ausente (env sin configurar / tests): 200 igualmente — el cliente NO debe reintentar en
 * bucle por un fallo de config server-side (molde no-op de fanOutGroupPush).
 */

const EVENT_KINDS = new Set(["ping", "register", "canary"]);
const NAME_RE = /^[A-Za-z0-9_.-]{1,64}$/;
const INSTALL_RE = /^[0-9a-f]{16,64}$/;
const MAX_EVENTS = 25;
const MAX_BODY_BYTES = 8192;
const MAX_DETAIL_CHARS = 128;
const MAX_APP_CHARS = 32;

interface MetricsEventWire {
  e: string;
  n?: string;
  d?: string;
  x?: number;
}

interface MetricsBodyWire {
  v: number;
  install: string;
  app?: string;
  events: MetricsEventWire[];
}

let warnedMissingBinding = false;

function isValidEvent(ev: unknown): ev is MetricsEventWire {
  if (typeof ev !== "object" || ev === null) return false;
  const e = ev as Record<string, unknown>;
  if (typeof e.e !== "string" || !EVENT_KINDS.has(e.e)) return false;
  if (e.n !== undefined && (typeof e.n !== "string" || !NAME_RE.test(e.n))) return false;
  if (e.d !== undefined && (typeof e.d !== "string" || e.d.length === 0 || e.d.length > MAX_DETAIL_CHARS)) return false;
  if (e.x !== undefined && (typeof e.x !== "number" || !Number.isFinite(e.x))) return false;
  return true;
}

/** Valida el body completo; devuelve el body tipado o un string con el motivo del rechazo. */
export function parseMetricsBody(raw: string): MetricsBodyWire | string {
  if (raw.length > MAX_BODY_BYTES) return "body too large";
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return "invalid JSON";
  }
  if (typeof parsed !== "object" || parsed === null) return "body must be an object";
  const body = parsed as Record<string, unknown>;
  if (body.v !== 1) return "unsupported version";
  if (typeof body.install !== "string" || !INSTALL_RE.test(body.install)) return "invalid install";
  if (body.app !== undefined && (typeof body.app !== "string" || body.app.length > MAX_APP_CHARS)) {
    return "invalid app";
  }
  if (!Array.isArray(body.events) || body.events.length === 0) return "events must be a non-empty array";
  if (body.events.length > MAX_EVENTS) return "too many events";
  if (!body.events.every(isValidEvent)) return "invalid event";
  return body as unknown as MetricsBodyWire;
}

export async function handleMetrics(c: Ctx): Promise<Response> {
  const raw = await c.req.text();
  const body = parseMetricsBody(raw);
  if (typeof body === "string") {
    return jsonError("yala_bad_input", `metrics: ${body}`, 400);
  }

  const dataset = c.env.METRICS;
  if (!dataset) {
    if (!warnedMissingBinding) {
      warnedMissingBinding = true;
      console.log("[metrics] METRICS binding ausente — datapoints descartados (config del env)");
    }
    return c.json({ ok: true, accepted: 0 });
  }

  for (const ev of body.events) {
    dataset.writeDataPoint({
      blobs: [ev.e, ev.n ?? "", ev.d ?? "", body.app ?? "", body.install],
      doubles: [ev.x ?? 1],
      indexes: [body.install],
    });
  }
  return c.json({ ok: true, accepted: body.events.length });
}
