/**
 * La sesión web: una cookie que la página no puede leer y, en el KV, los tokens de solo lectura cifrados.
 *
 * - La cookie (`__Host-yala-web`) lleva 32 bytes al azar. `HttpOnly`, `Secure`, `SameSite=Lax`, `Path=/`, sin dominio:
 *   ningún script de la página la lee y solo viaja a este origen.
 * - En el KV la clave es el SHA-256 de ese valor, y los tokens van cifrados con AES-GCM con una clave derivada (HKDF)
 *   del mismo valor. Quien lea el KV no tiene la cookie: no puede descifrar nada ni presentarse como nadie. Es el mismo
 *   principio que el conector de Claude, donde la clave envuelve el propio token.
 * - Lo que va en claro es solo lo que hace falta para decidir si la sesión sigue viva (fechas y «equipo compartido»).
 *
 * Cuánto dura (decisión D4):
 * - Equipo propio: 30 días desde el último uso (deslizante), y nunca más de 90 desde que se entró.
 * - Equipo compartido: la cookie es de sesión del navegador (sin `Max-Age`: se borra al cerrarlo) y la sesión muere a
 *   los 30 minutos sin uso.
 */

export const SESSION_COOKIE = "__Host-yala-web";
export const OWN_IDLE_SECONDS = 30 * 86_400;
export const MAX_AGE_SECONDS = 90 * 86_400;
export const SHARED_IDLE_SECONDS = 30 * 60;
/** Cada cuánto, como mucho, se reescribe la sesión solo para mover «último uso». El KV no está para una escritura por clic. */
export const TOUCH_EVERY_SECONDS = 60;
const MIN_KV_TTL = 60;

export interface SessionSecrets {
  sub: string;
  sid: string;
  access: string;
  accessExp: number;
  refresh: string;
}

interface StoredSession {
  v: 1;
  createdAt: number;
  lastSeen: number;
  shared: boolean;
  iv: string;
  ct: string;
}

export interface Session extends SessionSecrets {
  createdAt: number;
  lastSeen: number;
  shared: boolean;
}

// ─── bytes ─────────────────────────────────────────────────────────────────────────────────────────────────────

export function b64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromB64url(s: string): Uint8Array<ArrayBuffer> {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (s.length % 4)) % 4);
  const bin = atob(b64);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export function randomToken(bytes = 32): string {
  return b64url(crypto.getRandomValues(new Uint8Array(bytes)));
}

const TOKEN_RE = /^[A-Za-z0-9_-]{43}$/;

export async function sha256Hex(text: string): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)));
  return [...digest].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function s256(verifier: string): Promise<string> {
  return b64url(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier))));
}

async function kvKey(token: string): Promise<string> {
  return `s:${await sha256Hex(token)}`;
}

async function aesKey(token: string): Promise<CryptoKey> {
  const ikm = await crypto.subtle.importKey("raw", fromB64url(token), "HKDF", false, ["deriveKey"]);
  return crypto.subtle.deriveKey(
    { name: "HKDF", hash: "SHA-256", salt: new TextEncoder().encode("yala-web"), info: new TextEncoder().encode("sesion-v1") },
    ikm,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
}

// ─── vida ──────────────────────────────────────────────────────────────────────────────────────────────────────

/** Segundos que le quedan a la sesión si se usa ahora. ≤ 0: está muerta. */
export function remainingSeconds(s: { createdAt: number; lastSeen: number; shared: boolean }, nowSec: number): number {
  const idle = s.shared ? SHARED_IDLE_SECONDS : OWN_IDLE_SECONDS;
  return Math.min(s.lastSeen + idle, s.createdAt + MAX_AGE_SECONDS) - nowSec;
}

export function sessionCookie(token: string, shared: boolean, maxAgeSeconds: number): string {
  const base = `${SESSION_COOKIE}=${token}; Path=/; Secure; HttpOnly; SameSite=Lax`;
  // Equipo compartido: cookie de sesión del navegador, sin Max-Age. Se va al cerrarlo.
  return shared ? base : `${base}; Max-Age=${Math.max(0, Math.floor(maxAgeSeconds))}`;
}

export function clearSessionCookie(): string {
  return `${SESSION_COOKIE}=; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0`;
}

export function readCookie(request: Request, name: string): string | null {
  const cookie = request.headers.get("Cookie") ?? "";
  for (const part of cookie.split(/;\s*/)) {
    const eq = part.indexOf("=");
    if (eq > 0 && part.slice(0, eq) === name) return part.slice(eq + 1);
  }
  return null;
}

// ─── KV ────────────────────────────────────────────────────────────────────────────────────────────────────────

async function write(kv: KVNamespace, token: string, meta: Omit<StoredSession, "v" | "iv" | "ct">, secrets: SessionSecrets, nowSec: number) {
  const key = await kvKey(token);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  // El AAD ata el cifrado a ESTA entrada: un texto cifrado copiado a otra clave del KV no descifra.
  const ct = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv, additionalData: new TextEncoder().encode(key) },
    await aesKey(token),
    new TextEncoder().encode(JSON.stringify(secrets)),
  );
  const stored: StoredSession = { v: 1, ...meta, iv: b64url(iv), ct: b64url(new Uint8Array(ct)) };
  const ttl = Math.max(MIN_KV_TTL, remainingSeconds(meta, nowSec));
  await kv.put(key, JSON.stringify(stored), { expirationTtl: ttl });
}

/** Crea una sesión y devuelve el valor de la cookie. */
export async function createSession(kv: KVNamespace, secrets: SessionSecrets, shared: boolean, nowSec: number): Promise<string> {
  const token = randomToken();
  await write(kv, token, { createdAt: nowSec, lastSeen: nowSec, shared }, secrets, nowSec);
  return token;
}

/** La sesión de esta cookie, si existe y sigue viva. Una muerta se borra al encontrarla. */
export async function loadSession(kv: KVNamespace, token: string | null, nowSec: number): Promise<Session | null> {
  if (!token || !TOKEN_RE.test(token)) return null;
  const key = await kvKey(token);
  const raw = await kv.get(key);
  if (!raw) return null;
  let stored: StoredSession;
  try {
    stored = JSON.parse(raw) as StoredSession;
  } catch {
    await kv.delete(key);
    return null;
  }
  if (stored.v !== 1 || remainingSeconds(stored, nowSec) <= 0) {
    await kv.delete(key);
    return null;
  }
  let secrets: SessionSecrets;
  try {
    const plain = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: fromB64url(stored.iv), additionalData: new TextEncoder().encode(key) },
      await aesKey(token),
      fromB64url(stored.ct),
    );
    secrets = JSON.parse(new TextDecoder().decode(plain)) as SessionSecrets;
  } catch {
    // No descifra: no es de esta cookie o está corrupta. No se puede usar para nada.
    await kv.delete(key);
    return null;
  }
  return { ...secrets, createdAt: stored.createdAt, lastSeen: stored.lastSeen, shared: stored.shared };
}

/**
 * Guarda lo que cambió (tokens rotados) y mueve «último uso». Sin cambios de tokens, solo reescribe si pasó
 * `TOUCH_EVERY_SECONDS`. Devuelve `true` si escribió: entonces conviene renovar el `Max-Age` de la cookie.
 */
export async function saveSession(kv: KVNamespace, token: string, session: Session, nowSec: number, tokensChanged: boolean): Promise<boolean> {
  if (!tokensChanged && nowSec - session.lastSeen < TOUCH_EVERY_SECONDS) return false;
  const { createdAt, shared, sub, sid, access, accessExp, refresh } = session;
  await write(kv, token, { createdAt, lastSeen: nowSec, shared }, { sub, sid, access, accessExp, refresh }, nowSec);
  session.lastSeen = nowSec;
  return true;
}

export async function deleteSession(kv: KVNamespace, token: string): Promise<void> {
  if (!TOKEN_RE.test(token)) return;
  await kv.delete(await kvKey(token));
}

// ─── login a medias ────────────────────────────────────────────────────────────────────────────────────────────

/** Cookie que liga la vuelta del login social a ESTE navegador. Solo lleva un identificador al azar. */
export const LOGIN_COOKIE = "__Host-yala-web-login";
export const LOGIN_TTL_SECONDS = 600;

export interface PendingLogin {
  verifier: string;
  shared: boolean;
}

export function loginCookie(nonce: string, maxAge: number): string {
  // Lax: la vuelta desde Supabase es una navegación GET de primer nivel, así que viaja; un POST de otro sitio, no.
  return `${LOGIN_COOKIE}=${nonce}; Path=/auth; Secure; HttpOnly; SameSite=Lax; Max-Age=${maxAge}`;
}

export async function savePendingLogin(kv: KVNamespace, pending: PendingLogin): Promise<string> {
  const nonce = randomToken();
  await kv.put(`l:${await sha256Hex(nonce)}`, JSON.stringify(pending), { expirationTtl: LOGIN_TTL_SECONDS });
  return nonce;
}

/** Recupera y BORRA el login a medias: el código de vuelta se canjea una sola vez. */
export async function takePendingLogin(kv: KVNamespace, nonce: string | null): Promise<PendingLogin | null> {
  if (!nonce || !TOKEN_RE.test(nonce)) return null;
  const key = `l:${await sha256Hex(nonce)}`;
  const raw = await kv.get(key);
  if (!raw) return null;
  await kv.delete(key);
  try {
    const p = JSON.parse(raw) as Partial<PendingLogin>;
    if (typeof p.verifier !== "string" || typeof p.shared !== "boolean") return null;
    return { verifier: p.verifier, shared: p.shared };
  } catch {
    return null;
  }
}
