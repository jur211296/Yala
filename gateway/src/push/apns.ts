/**
 * APNs desde el Worker — spike G0 de Grupos→backend (semilla del módulo real de G8).
 *
 * Objetivo del spike: verificar empíricamente que el `fetch` de Workers negocia el
 * transporte contra APNs (api.push.apple.com exige HTTP/2). Por eso la firma pública
 * separa DIAGNÓSTICO de fallo: si `fetch` RESUELVE, el transporte negoció (status +
 * apns-id + body con el `reason` de APNs); si `fetch` LANZA, es fallo de transporte
 * (el caso "no HTTP/2") y viaja como `transportError` — sendPush NUNCA rechaza.
 *
 * JWT de provider: ES256 con la APNs Auth Key (.p8, PKCS8 PEM). APNs exige tokens de
 * <1h y desaconseja re-firmar más de 1 vez cada 20 min → cache en module scope con
 * TTL 50 min. Cada isolate firma el suyo en cold start: tokens concurrentes válidos
 * del mismo key id son aceptables (la guía de Apple es de cadencia de refresh, no un
 * límite de tokens vivos); a volumen de spike es irrelevante.
 */
import { importPKCS8, SignJWT } from "jose";
import type { Env } from "../env";
import { acceptedBundleIDs } from "../env";

export interface ApnsPushRequest {
  deviceToken: string; // hex de 64 chars
  sandbox: boolean; // true → api.sandbox.push.apple.com (builds con aps-environment=development)
  pushType?: "background" | "alert";
  payload?: Record<string, unknown>;
}

export interface ApnsPushResult {
  delivered: boolean; // status === 200
  status?: number; // status HTTP de APNs (ausente si fetch lanzó)
  apnsId?: string; // header apns-id de la respuesta
  body?: string; // cuerpo raw de APNs ({"reason":"BadDeviceToken"} etc.)
  transportError?: string; // fetch lanzó — el caso "no negocia HTTP/2"
  host: string;
  topic: string;
}

/** El .p8 pegado como secret puede llegar con `\n` literales; normalizar a saltos reales. */
function normalizePem(pem: string): string {
  return pem.replace(/\\n/g, "\n").trim();
}

/** Firma el JWT de provider de APNs. Claims: solo iss (team id) + iat; APNs no pide exp. */
export async function signApnsJwt(p8Pem: string, keyId: string, teamId: string): Promise<string> {
  const key = await importPKCS8(normalizePem(p8Pem), "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(key);
}

const JWT_TTL_MS = 50 * 60 * 1000; // <1h que exige APNs, >20min entre re-firmas
let jwtCache: { token: string; issuedAtMs: number; keyId: string } | null = null;

/** Solo para tests (expiry con fake timers). */
export function _resetJwtCacheForTests(): void {
  jwtCache = null;
}

async function getApnsJwt(env: Env): Promise<string> {
  const now = Date.now();
  if (jwtCache && jwtCache.keyId === env.APNS_KEY_ID && now - jwtCache.issuedAtMs < JWT_TTL_MS) {
    return jwtCache.token;
  }
  // El guard por keyId invalida el cache si se rota la key sin redeploy.
  const token = await signApnsJwt(env.APNS_AUTH_KEY!, env.APNS_KEY_ID!, env.APPLE_TEAM_ID);
  jwtCache = { token, issuedAtMs: now, keyId: env.APNS_KEY_ID! };
  return token;
}

/** Payload default del spike: silent push + contrato de clasificación con el cliente (key top-level "yala"). */
function defaultPayload(): Record<string, unknown> {
  return {
    aps: { "content-available": 1 },
    yala: { kind: "g0-spike", sentAt: new Date().toISOString() },
  };
}

export async function sendPush(env: Env, req: ApnsPushRequest): Promise<ApnsPushResult> {
  const host = req.sandbox ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
  // Para push background el topic es el bundle id sin sufijo. Staging tiene un solo id,
  // pero el parsing tolera lista CSV (mismo helper que attest).
  const topic = acceptedBundleIDs(env)[0];
  const jwt = await getApnsJwt(env);
  const pushType = req.pushType ?? "background";

  try {
    const res = await fetch(`${host}/3/device/${req.deviceToken}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": topic,
        "apns-push-type": pushType,
        // background exige priority 5 (10 está prohibido); expiration 0 = no reintentar si offline.
        "apns-priority": pushType === "background" ? "5" : "10",
        "apns-expiration": "0",
        "content-type": "application/json",
      },
      body: JSON.stringify(req.payload ?? defaultPayload()),
    });
    const body = await res.text();
    return {
      delivered: res.status === 200,
      status: res.status,
      apnsId: res.headers.get("apns-id") ?? undefined,
      body: body.length > 0 ? body : undefined,
      host,
      topic,
    };
  } catch (err) {
    // Fallo de TRANSPORTE (probable negociación ALPN/HTTP-2) — el veredicto del spike.
    return { delivered: false, transportError: String(err), host, topic };
  }
}
