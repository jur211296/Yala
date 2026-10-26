/**
 * Avisos de errores del gateway en Sentry (proyecto `yala-gateway`).
 *
 * El DSN es un secret (`wrangler secret put SENTRY_DSN`; `.dev.vars` en local). Sin DSN el SDK no arranca y el
 * Worker se comporta exactamente igual que antes.
 *
 * Lo que sale hacia Sentry pasa por `scrubEvent` / `scrubBreadcrumb`: el gateway ve importes, correos, nombres de
 * grupos y transcripciones, y ninguno de esos datos puede llegar a un evento. La regla es por lista blanca: del
 * request solo viajan el método y la ruta; de un breadcrumb HTTP, el método, la URL sin query y el status. Los
 * textos libres (mensaje de la excepción, consola) pasan por `scrubText`, que tapa correos, tokens e importes.
 */
import type { Breadcrumb, CloudflareOptions, ErrorEvent } from "@sentry/cloudflare";
import type { Env } from "./env";

/** Opciones del SDK, o `undefined` sin DSN: `withSentry` entonces no inicializa nada. */
export function sentryOptions(env: Env): CloudflareOptions | undefined {
  const dsn = env.SENTRY_DSN?.trim();
  if (!dsn) return undefined;
  return {
    dsn,
    environment: env.ENVIRONMENT ?? "unknown",
    // El equivalente de `sendDefaultPii: false` en el SDK 11: no se recoge nada del usuario ni del tráfico.
    dataCollection: {
      userInfo: false,
      cookies: false,
      httpHeaders: false,
      httpBodies: [],
      urlQueryParams: false,
      databaseQueryData: false,
      queues: false,
      stackFrameVariables: false,
      genAI: { inputs: false, outputs: false },
      mcp: { inputs: false, outputs: false },
      graphQL: { document: false, variables: false },
    },
    // Solo errores: sin trazas de rendimiento, que llevarían URLs y tiempos por petición.
    tracesSampleRate: 0,
    beforeSend: scrubEvent,
    beforeBreadcrumb: scrubBreadcrumb,
  };
}

const EMAIL_RE = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
const JWT_RE = /\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)?/g;
const BEARER_RE = /\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+/gi;
const SECRET_KEY_RE = /\b(?:sk|pk|rk)-[A-Za-z0-9_-]{8,}/g;
// Importes: un símbolo o código de divisa pegado a una cifra, o una cifra con decimales («12.50», «1,234.5»).
const CURRENCY_AMOUNT_RE = /(?:[$€£¥₹]|S\/\.?|\b[A-Z]{3}\s?)\s?-?\d[\d.,]*/g;
const DECIMAL_AMOUNT_RE = /-?\b\d{1,3}(?:[.,]\d{3})*[.,]\d{1,2}\b/g;

/** Tapa en un texto libre lo que puede ser un dato personal o financiero. */
export function scrubText(text: string): string {
  return text
    .replace(JWT_RE, "[token]")
    .replace(BEARER_RE, "$1 [token]")
    .replace(SECRET_KEY_RE, "[token]")
    .replace(EMAIL_RE, "[email]")
    .replace(CURRENCY_AMOUNT_RE, "[monto]")
    .replace(DECIMAL_AMOUNT_RE, "[monto]");
}

/** La URL sin query ni fragmento: las queries llevan fechas, divisas y cursores del usuario. */
export function stripQuery(url: string): string {
  const cut = url.search(/[?#]/);
  return cut === -1 ? url : url.slice(0, cut);
}

export function scrubEvent(event: ErrorEvent): ErrorEvent {
  if (event.request) {
    const { method, url } = event.request;
    event.request = { method, url: url ? stripQuery(url) : undefined };
  }
  delete event.user;
  // Sin esto Sentry toma la IP de quien le envía el evento y la geolocaliza (medido: «Lima» en el primer evento).
  if (event.sdk) event.sdk = { ...event.sdk, settings: { ...event.sdk.settings, infer_ip: "never" } };
  delete event.extra;
  delete event.server_name;
  if (event.message) event.message = scrubText(event.message);
  if (event.logentry?.message) event.logentry = { message: scrubText(event.logentry.message) };
  for (const exception of event.exception?.values ?? []) {
    if (exception.value) exception.value = scrubText(exception.value);
    for (const frame of exception.stacktrace?.frames ?? []) {
      // Las variables locales de un frame pueden ser el body entero de una petición.
      delete frame.vars;
    }
  }
  if (event.breadcrumbs) {
    event.breadcrumbs = event.breadcrumbs
      .map((crumb) => scrubBreadcrumb(crumb))
      .filter((crumb): crumb is Breadcrumb => crumb !== null);
  }
  return event;
}

export function scrubBreadcrumb(crumb: Breadcrumb): Breadcrumb | null {
  const scrubbed: Breadcrumb = { ...crumb };
  if (scrubbed.message) scrubbed.message = scrubText(scrubbed.message);
  const data = crumb.data;
  if (crumb.category === "fetch" || crumb.category === "http" || crumb.type === "http") {
    scrubbed.data = data
      ? {
          method: data.method,
          url: typeof data.url === "string" ? stripQuery(data.url) : undefined,
          status_code: data.status_code,
        }
      : undefined;
  } else {
    // Consola y demás: los argumentos pueden ser objetos con el payload. Fuera.
    delete scrubbed.data;
  }
  return scrubbed;
}
