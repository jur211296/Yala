/**
 * Entrar con el iPhone por QR (lote 2, «Vincular con el iPhone»). El flujo:
 *
 * 1. **El navegador pide un código** (`POST /auth/qr/start`, con Turnstile). El Worker guarda un secreto en una cookie
 *    propia (`__Host-yala-web-qr`, `HttpOnly`, `SameSite=Strict`) y, en el objeto del código, solo su SHA-256 y el
 *    `code_challenge` de un PKCE cuyo `verifier` sale de ese secreto. El código (8 caracteres) va en el QR y en claro.
 *    Dura 60 s y el navegador lo renueva (`/auth/qr/renovar`) hasta 10 minutos desde que se pidió el primero.
 * 2. **El iPhone lo lee** (`GET /api/dispositivo/vincular?codigo=`, con el token de su sesión): el código queda suyo
 *    (nadie más puede aprobarlo) y recibe el navegador, el sistema y la ciudad aproximada para enseñarlos.
 * 3. **La persona confirma con Face ID** y el iPhone aprueba (`POST /api/dispositivo/vincular`). El Worker comprueba que
 *    la cuenta usa la nube y pide el permiso de solo lectura de la web CON LA SESIÓN DEL IPHONE, con el `challenge`
 *    guardado. Guarda solo el código de autorización: sin el `verifier`, que solo deriva la cookie del navegador, no
 *    sirve para nada.
 * 4. **El navegador pregunta** (`POST /auth/qr/estado`, cada pocos segundos). Aprobado: deriva el `verifier` de su
 *    cookie, canjea el código y abre la sesión web de siempre (`createSession` y la lista de sesiones).
 *
 * Por qué así: un código ajeno no abre nada (hace falta la cookie del navegador que lo pidió), el objeto no guarda
 * nada que sirva para entrar, y contra el «QR que te enseña otro» el iPhone enseña qué navegador y desde dónde antes
 * de Face ID. La sesión de la app nunca sale del iPhone: el Worker la usa para aprobar y no la guarda.
 */
import type { Env } from "./env";
import { b64url, s256 } from "./session";

export const QR_COOKIE = "__Host-yala-web-qr";
/** Lo que vive cada código antes de renovarse. */
export const QR_CODE_TTL_SECONDS = 60;
/** Lo que tiene el iPhone desde que lee el código para confirmar con Face ID. */
export const QR_CONFIRM_SECONDS = 120;
/** Cuánto se renueva un código sin volver a pasar por Turnstile. */
export const QR_CHAIN_SECONDS = 600;

/** Sin 0/O ni 1/I: se escribe a mano en el iPhone. 32 símbolos, 8 caracteres = 40 bits. */
const ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
const CODE_RE = /^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{8}$/;

export function newPairingCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  let out = "";
  for (const b of bytes) out += ALPHABET[b & 31];
  return out;
}

/** El código tal como lo escribe o lo lee el iPhone: sin guiones ni espacios, en mayúsculas. `null` si no lo es. */
export function normalizeCode(raw: unknown): string | null {
  if (typeof raw !== "string" || raw.length > 64) return null;
  let c = raw.trim();
  // Del QR llega la dirección entera: `https://…/v/K7Q4MD2X`.
  const m = /\/v\/([A-Za-z0-9-]+)\/?$/.exec(c);
  if (m) c = m[1]!;
  // Solo letras y dígitos: el separador que ponga el teclado («-», «'», «·», un espacio) no cuenta.
  c = c.replace(/[^A-Za-z0-9]/g, "").toUpperCase();
  return CODE_RE.test(c) ? c : null;
}

/** «K7Q4-MD2X», como en la maqueta. */
export function displayCode(code: string): string {
  return `${code.slice(0, 4)}-${code.slice(4)}`;
}

/** El `verifier` del PKCE sale del secreto de la cookie: el objeto guarda el `challenge`, nunca el `verifier`. */
export async function qrVerifier(secret: string): Promise<string> {
  return b64url(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`yala-web-qr-pkce:${secret}`))));
}

export async function qrChallenge(secret: string): Promise<string> {
  return s256(await qrVerifier(secret));
}

export async function browserHash(secret: string): Promise<string> {
  return b64url(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`yala-web-qr-browser:${secret}`))));
}

export function qrCookie(secret: string, maxAge: number): string {
  return `${QR_COOKIE}=${secret}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${maxAge}`;
}

/** Lo que el objeto de un código guarda. Nada de esto permite entrar: ni tokens ni el `verifier`. */
export interface PairingRecord {
  /** SHA-256 (con dominio) del secreto de la cookie del navegador que lo pidió. */
  bh: string;
  challenge: string;
  /** Cuándo se pidió el PRIMER código de la cadena (las renovaciones lo heredan). */
  inicio: number;
  creada: number;
  expira: number;
  compartido: boolean;
  navegador: string;
  sistema: string;
  ciudad: string | null;
  /** La cuenta del iPhone que lo leyó. Desde ahí, solo ella puede aprobarlo. */
  sub?: string;
  visto?: number;
  /** Código de autorización de Supabase, tras aprobar. Sin el `verifier` no se canjea. */
  auth?: string;
}

export interface PairingInfo {
  navegador: string;
  sistema: string;
  ciudad: string | null;
  creada: number;
  expira: number;
}

export type PairingStatus =
  | { estado: "esperando"; expira: number }
  | { estado: "visto"; expira: number }
  | { estado: "aprobado"; auth: string; sub: string; compartido: boolean }
  | { estado: "caducado" };

/** Los métodos RPC del objeto de un código (`QrPairing`). `now`: epoch en segundos. */
export interface PairingApi {
  /** `false` si el código ya existía (choque: el Worker pide otro). */
  create(rec: PairingRecord): Promise<boolean>;
  /** El iPhone lo lee: queda suyo. `null` si caducó, se aprobó o lo leyó otra cuenta. */
  claim(sub: string, now: number): Promise<{ info: PairingInfo; challenge: string } | null>;
  /** El iPhone lo aprueba con el código de autorización. Solo la cuenta que lo leyó, y sin caducar. */
  approve(sub: string, auth: string, now: number): Promise<boolean>;
  /** El navegador pregunta. Solo responde al que tiene la cookie; «aprobado» se entrega UNA vez y el objeto se vacía. */
  status(bh: string, now: number): Promise<PairingStatus>;
  /** Para renovar: devuelve lo que hereda el código siguiente y retira este. `null` si no es de este navegador. */
  retire(bh: string, now: number): Promise<Pick<PairingRecord, "inicio" | "compartido" | "navegador" | "sistema" | "ciudad"> | null>;
}

export function pairing(env: Env, code: string): PairingApi {
  const ns = env.QR_PAIRING;
  return ns.get(ns.idFromName(code)) as unknown as PairingApi;
}

/** Dónde guarda una celda su registro: el almacenamiento del Durable Object, o un `Map` en las pruebas. */
export interface PairingStore {
  read(): Promise<PairingRecord | null>;
  write(rec: PairingRecord): Promise<void>;
  drop(): Promise<void>;
}

/** La lógica del objeto de un código, sin Cloudflare. Cada método corre entero dentro del objeto (sin carreras). */
export class PairingCell implements PairingApi {
  constructor(private readonly store: PairingStore) {}

  async create(rec: PairingRecord): Promise<boolean> {
    if (await this.store.read()) return false;
    await this.store.write(rec);
    return true;
  }

  async claim(sub: string, now: number): Promise<{ info: PairingInfo; challenge: string } | null> {
    const rec = await this.store.read();
    if (!rec || rec.expira <= now || rec.auth) return null;
    if (rec.sub && rec.sub !== sub) return null;
    if (!rec.sub) {
      rec.sub = sub;
      rec.visto = now;
      // Desde que el iPhone lo lee, tiene tiempo de confirmar aunque el código «cambiara» en la pantalla.
      rec.expira = Math.max(rec.expira, now + QR_CONFIRM_SECONDS);
      await this.store.write(rec);
    }
    return {
      info: { navegador: rec.navegador, sistema: rec.sistema, ciudad: rec.ciudad, creada: rec.creada, expira: rec.expira },
      challenge: rec.challenge,
    };
  }

  async approve(sub: string, auth: string, now: number): Promise<boolean> {
    const rec = await this.store.read();
    if (!rec || rec.expira <= now || rec.auth || rec.sub !== sub) return false;
    rec.auth = auth;
    await this.store.write(rec);
    return true;
  }

  async status(bh: string, now: number): Promise<PairingStatus> {
    const rec = await this.store.read();
    if (!rec || rec.bh !== bh) return { estado: "caducado" };
    if (rec.auth && rec.sub) {
      await this.store.drop();
      return { estado: "aprobado", auth: rec.auth, sub: rec.sub, compartido: rec.compartido };
    }
    if (rec.expira <= now) {
      await this.store.drop();
      return { estado: "caducado" };
    }
    return rec.sub ? { estado: "visto", expira: rec.expira } : { estado: "esperando", expira: rec.expira };
  }

  async retire(bh: string, _now: number) {
    const rec = await this.store.read();
    if (!rec || rec.bh !== bh || rec.sub || rec.auth) return null;
    await this.store.drop();
    return { inicio: rec.inicio, compartido: rec.compartido, navegador: rec.navegador, sistema: rec.sistema, ciudad: rec.ciudad };
  }
}
