import type { Tier } from "./attest/session";

/** Categorías de uso (cada endpoint de IA mapea a una). */
export type Category = "chat" | "vision" | "voice" | "insights" | "suggestions" | "rates";

export interface Limits {
  daily: number;
  burstPerMin: number;
}

/**
 * Política de cuota por (tier × categoría). `null` = no permitido para ese tier → Pro requerido.
 * Editable sin release del cliente (cambia el Worker y se redespliega).
 *
 * - Pro: cuota completa (chat 75/día como el límite histórico del cliente + el resto generoso).
 * - Free: SOLO voz/imagen con cuota de trial pequeña (cubre el setup-checklist sin suscripción);
 *   chat/insights/suggestions → Pro requerido. Tasas: abiertas a cualquier device atestado.
 */
const TABLE: Record<Tier, Partial<Record<Category, Limits>>> = {
  pro: {
    chat: { daily: 75, burstPerMin: 20 },
    vision: { daily: 50, burstPerMin: 15 },
    voice: { daily: 100, burstPerMin: 20 },
    insights: { daily: 60, burstPerMin: 15 },
    suggestions: { daily: 300, burstPerMin: 30 },
    rates: { daily: 2000, burstPerMin: 60 },
  },
  free: {
    vision: { daily: 5, burstPerMin: 5 },
    voice: { daily: 5, burstPerMin: 5 },
    rates: { daily: 2000, burstPerMin: 60 },
  },
};

export function limitsFor(tier: Tier, category: Category): Limits | null {
  return TABLE[tier][category] ?? null;
}
