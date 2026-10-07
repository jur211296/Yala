import type { Env } from "./env";

interface DOState {
  day: string; // 'YYYY-MM-DD' UTC
  counts: Record<string, number>; // por categoría, se reponen cada día
  burst: number[]; // timestamps ms en los últimos 60s (global, anti-flood)
  /** Cupo de prueba usado por categoría. NUNCA se repone (sesión 2). Ausente en estados de antes = 0. */
  trial?: Record<string, number>;
  /**
   * Notas de voz abiertas: un timestamp por transcripción que todavía no se ha leído. Leer una nota con una
   * abierta no gasta otro uso (una nota = un uso). Ausente en estados de antes = ninguna.
   */
  notes?: number[];
}

/** Una nota se lee segundos después de transcribirse; 10 min cubre un reintento sin dejar créditos colgados. */
export const NOTE_CREDIT_MS = 10 * 60_000;
const MAX_OPEN_NOTES = 10;

export interface CheckRequest {
  op?: "check";
  category: string;
  /** Exactamente uno de los dos (ver `Limits` en policy.ts). */
  daily?: number;
  trial?: number;
  burstPerMin: number;
  /** `grant`: esta llamada abre una nota. `consume`: la lee; si hay una abierta, no gasta. */
  notePairing?: "grant" | "consume";
}

export interface RefundRequest {
  op: "refund";
  category: string;
  /** Lo que devolvió el `check` que se deshace. */
  ticket: QuotaTicket;
}

/** Qué gastó un `check` permitido, para poder devolverlo si el proveedor falla. */
export interface QuotaTicket {
  counted: "daily" | "trial" | null; // null = no gastó (leyó una nota abierta)
  grantedNoteAt: number | null; // la nota que abrió
  consumedNoteAt: number | null; // la nota que cerró
}

export interface RateLimitResult {
  allowed: boolean;
  reason: "daily" | "trial" | "burst" | null;
  ticket?: QuotaTicket;
}

/** Lógica pura del limitador (testeable sin Durable Object). Muta `stored`. */
export function applyCheck(stored: DOState, req: CheckRequest, now: number): RateLimitResult {
  const today = new Date(now).toISOString().slice(0, 10);
  if (stored.day !== today) {
    stored.day = today;
    stored.counts = {};
  }
  stored.burst = stored.burst.filter((t) => now - t < 60_000);
  const notes = (stored.notes ?? []).filter((t) => now - t < NOTE_CREDIT_MS);
  stored.notes = notes;
  stored.trial = stored.trial ?? {};

  const burstExceeded = stored.burst.length >= req.burstPerMin;

  // Leer una nota abierta: la nota ya gastó su uso —y su hueco de ráfaga— al transcribirse. Ni el día, ni el cupo, ni
  // la ráfaga se miran: la 5.ª nota tiene que poder leerse aunque el cupo esté en 5, y contar la lectura en la ráfaga
  // hacía que dos notas seguidas (4 llamadas) rozaran el tope de 5 por minuto del plan free. No abre un flood: cada
  // lectura sin gasto consume una nota, y las notas solo las abre una transcripción, que sí cuenta.
  if (req.notePairing === "consume" && notes.length > 0) {
    const consumedNoteAt = notes.shift() ?? null;
    return { allowed: true, reason: null, ticket: { counted: null, grantedNoteAt: null, consumedNoteAt } };
  }

  // Chequear ANTES de incrementar: un request bloqueado no debe consumir cuota
  // (si no, los reintentos del cliente amplifican su propio lockout).
  const isTrial = req.trial !== undefined;
  const used = isTrial ? (stored.trial[req.category] ?? 0) : (stored.counts[req.category] ?? 0);
  const limit = isTrial ? (req.trial as number) : (req.daily ?? 0);
  const quotaExceeded = used >= limit;
  if (quotaExceeded || burstExceeded) {
    return { allowed: false, reason: quotaExceeded ? (isTrial ? "trial" : "daily") : "burst" };
  }
  if (isTrial) stored.trial[req.category] = used + 1;
  else stored.counts[req.category] = used + 1;
  stored.burst.push(now);
  let grantedNoteAt: number | null = null;
  if (req.notePairing === "grant") {
    grantedNoteAt = now;
    notes.push(now);
    if (notes.length > MAX_OPEN_NOTES) notes.splice(0, notes.length - MAX_OPEN_NOTES);
  }
  return { allowed: true, reason: null, ticket: { counted: isTrial ? "trial" : "daily", grantedNoteAt, consumedNoteAt: null } };
}

/**
 * Deshace un `check` permitido cuyo proveedor falló (5xx, red): con 5 usos en total, perder uno por un fallo ajeno se
 * nota. Devuelve el uso, cierra la nota que abrió y reabre la que cerró.
 */
export function applyRefund(stored: DOState, req: RefundRequest, now: number): void {
  const { ticket } = req;
  if (ticket.counted === "trial") {
    stored.trial = stored.trial ?? {};
    stored.trial[req.category] = Math.max(0, (stored.trial[req.category] ?? 0) - 1);
  } else if (ticket.counted === "daily") {
    const today = new Date(now).toISOString().slice(0, 10);
    // Un uso de ayer ya se repuso solo: no hay nada que devolver.
    if (stored.day === today) stored.counts[req.category] = Math.max(0, (stored.counts[req.category] ?? 0) - 1);
  }
  const notes = stored.notes ?? [];
  if (ticket.grantedNoteAt !== null) {
    const i = notes.indexOf(ticket.grantedNoteAt);
    if (i >= 0) notes.splice(i, 1);
  }
  if (ticket.consumedNoteAt !== null && now - ticket.consumedNoteAt < NOTE_CREDIT_MS) {
    notes.unshift(ticket.consumedNoteAt);
  }
  stored.notes = notes;
}

/**
 * Durable Object: contador de cuota por keyId (consistencia fuerte, single-threaded → sin races).
 * Cuenta por categoría (reset diario UTC), el cupo de prueba sin reset, las notas de voz abiertas y la ráfaga
 * global en ventana de 60 s.
 */
export class RateLimiter {
  constructor(
    private state: DurableObjectState,
    private env: Env,
  ) {}

  async fetch(request: Request): Promise<Response> {
    const req = (await request.json()) as CheckRequest | RefundRequest;
    const now = Date.now();
    const today = new Date(now).toISOString().slice(0, 10);
    const stored: DOState = (await this.state.storage.get<DOState>("s")) ?? { day: today, counts: {}, burst: [] };

    if (req.op === "refund") {
      applyRefund(stored, req, now);
      await this.state.storage.put("s", stored);
      return Response.json({ ok: true });
    }
    const result = applyCheck(stored, req, now);
    await this.state.storage.put("s", stored);
    return Response.json(result);
  }
}
