/**
 * La lista de sesiones web de una cuenta: lo que enseñan «Navegadores conectados» en el iPhone y «Sesiones» en la web.
 *
 * Vive en un Durable Object por cuenta (`SessionIndex`, `sessionIndex.ts`), no en el KV: el `list` del KV es de
 * consistencia eventual y una sesión recién abierta tardaba hasta un minuto en aparecer (medido en staging el
 * 2026-11-14), así que «Cerrar todas» desde el iPhone podía no cerrar la que se acababa de abrir. El objeto de la cuenta
 * es uno solo en todo el mundo: lo que se escribe se lee en el acto.
 *
 * Qué guarda, en claro: el navegador y el sistema (del User-Agent), la ciudad aproximada (la que Cloudflare deduce de la
 * IP, nunca la IP), las fechas, si es un equipo compartido, la clave del KV de la sesión (el SHA-256 de su cookie, que no
 * permite presentarse como nadie) y el `session_id` de Supabase, para cerrarla también allí. Ningún token.
 *
 * Caduca con la sesión: cada entrada lleva su `expira`, que se mueve cuando la sesión mueve «último uso».
 */
import type { Env } from "./env";

export interface SessionEntry {
  /** Id público, el que viaja a la página y al iPhone. */
  pid: string;
  /** Clave de la sesión en el KV (`s:<sha256>`). */
  k: string;
  /** `session_id` de la sesión de solo lectura de Supabase. */
  sid: string;
  creada: number;
  uso: number;
  compartido: boolean;
  navegador: string;
  sistema: string;
  ciudad: string | null;
}

/** Lo que el Worker le pide al objeto de una cuenta (métodos RPC de `SessionIndex`). `now`/`expira`: epoch en segundos. */
export interface SessionIndexApi {
  put(entry: SessionEntry, expira: number): Promise<void>;
  remove(pid: string): Promise<void>;
  /** Las vivas, de la usada más recientemente a la menos. Las caducadas se borran al leer. */
  list(now: number): Promise<SessionEntry[]>;
  touch(pid: string, uso: number, sid: string, expira: number): Promise<void>;
  /** ¿Sigue esta sesión en la lista (viva y sin cerrar)? La lista manda: una sesión que no está, no lee. */
  has(pid: string, now: number): Promise<boolean>;
  /**
   * Reserva un borrador de «Apuntar» en el cupo del día (`dia` = YYYY-MM-DD UTC). Atómico, y no lo vacía el `ack` del
   * gateway, que borra de la cola lo que el iPhone ya recogió. `false` si el cupo está gastado.
   */
  takeDraftSlot(dia: string, max: number): Promise<boolean>;
}

const PID_RE = /^[A-Za-z0-9_-]{12}$/;

export function isPid(raw: unknown): raw is string {
  return typeof raw === "string" && PID_RE.test(raw);
}

/** El objeto de la lista de esta cuenta. */
export function sessionIndex(env: Env, sub: string): SessionIndexApi {
  const ns = env.SESSION_INDEX;
  return ns.get(ns.idFromName(sub)) as unknown as SessionIndexApi;
}

/** Valida una entrada leída del almacenamiento: lo que no tenga forma de entrada no se enseña. */
export function asEntry(raw: unknown): SessionEntry | null {
  if (!raw || typeof raw !== "object") return null;
  const m = raw as Partial<SessionEntry>;
  if (!isPid(m.pid) || typeof m.k !== "string" || typeof m.sid !== "string") return null;
  if (typeof m.creada !== "number" || typeof m.uso !== "number") return null;
  return {
    pid: m.pid,
    k: m.k,
    sid: m.sid,
    creada: m.creada,
    uso: m.uso,
    compartido: m.compartido === true,
    navegador: typeof m.navegador === "string" ? m.navegador : "",
    sistema: typeof m.sistema === "string" ? m.sistema : "",
    ciudad: typeof m.ciudad === "string" && m.ciudad ? m.ciudad : null,
  };
}

/** Lo que ve el cliente de cada sesión: sin la clave del KV ni el `session_id`. */
export interface PublicSession {
  id: string;
  navegador: string;
  sistema: string;
  ciudad: string | null;
  creada: number;
  ultimoUso: number;
  equipoCompartido: boolean;
  esta: boolean;
}

export function toPublic(e: SessionEntry, currentPid: string | null): PublicSession {
  return {
    id: e.pid,
    navegador: e.navegador,
    sistema: e.sistema,
    ciudad: e.ciudad,
    creada: e.creada,
    ultimoUso: e.uso,
    equipoCompartido: e.compartido,
    esta: e.pid === currentPid,
  };
}
