import type { Tier } from "./attest/session";

/** Categorías de uso (cada endpoint de IA mapea a una). `sync` = tráfico de Modo Nube. */
export type Category = "chat" | "vision" | "voice" | "insights" | "suggestions" | "rates" | "sync";

/**
 * Límites de un (tier × categoría). Exactamente uno de `daily` o `trial`:
 * - `daily`: cuota que se repone cada día UTC.
 * - `trial`: cupo de prueba EN TOTAL por instalación (keyId de App Attest), sin reinicio (sesión 2, decisión de
 *   Jürgen del 2026-10-07, opción B). Reinstalar la app da otra identidad y otro cupo (aceptado el mismo día).
 */
export interface Limits {
  daily?: number;
  trial?: number;
  burstPerMin: number;
}

/**
 * Política de cuota por (tier × categoría). `null` = no permitido para ese tier → Pro requerido.
 * Editable sin release del cliente (cambia el Worker y se redespliega).
 *
 * - Pro: cuota completa (chat 75/día como el límite histórico del cliente + el resto generoso).
 * - Free: SOLO voz/imagen, como cupo de prueba de 5 notas y 5 fotos en total (la práctica de «Configura tu Yala»);
 *   chat/insights/suggestions → Pro requerido. Tasas: abiertas a cualquier device atestado.
 * - Una nota de voz cuenta UNA vez en `voice` aunque haga dos llamadas (transcribir + leer): ver `notePairing` en
 *   `ai/tasks.ts` y el crédito de `rate_limiter.ts`.
 */
const TABLE: Record<Tier, Partial<Record<Category, Limits>>> = {
  pro: {
    chat: { daily: 75, burstPerMin: 20 },
    vision: { daily: 50, burstPerMin: 15 },
    voice: { daily: 100, burstPerMin: 20 },
    insights: { daily: 60, burstPerMin: 15 },
    suggestions: { daily: 300, burstPerMin: 30 },
    rates: { daily: 2000, burstPerMin: 60 },
    sync: { daily: 20000, burstPerMin: 240 },
  },
  free: {
    vision: { trial: 5, burstPerMin: 5 },
    voice: { trial: 5, burstPerMin: 5 },
    rates: { daily: 2000, burstPerMin: 60 },
    // Modo Nube es GRATIS (decisión 4, §j.1) → sync abierto a cualquier device atestado, incl. free.
    // Generoso: un catch-up masivo tras offline drena por lotes; el burst acota el flood.
    sync: { daily: 20000, burstPerMin: 240 },
  },
};

export function limitsFor(tier: Tier, category: Category): Limits | null {
  return TABLE[tier][category] ?? null;
}
