/**
 * Precio de los modelos que usa el gateway, en USD por millón de tokens. Copiados de `gateway/bench/candidates.ts`
 * (que cita la página de precios de cada proveedor) el 2026-11-06. **Si `gateway/src/ai/routes.ts` o
 * `gateway/src/mail/read.ts` cambian de modelo, añade aquí su precio**: un modelo sin precio no se inventa, el panel lo
 * cuenta aparte y lo dice («N llamadas sin precio»). `test/prices.test.ts` exige que todo modelo de esas filas esté.
 *
 * La transcripción (`gpt-transcribe`) se cobra por minuto de audio y el registro de uso no guarda la duración del
 * audio: queda sin precio a propósito.
 */
export interface Price {
  input: number;
  cachedInput: number;
  output: number;
}

export const PRICES: Record<string, Price> = {
  "gpt-6-luna": { input: 0.1, cachedInput: 0.01, output: 0.5 },
  "gpt-6.1-sol": { input: 2.0, cachedInput: 0.1, output: 10.0 },
  "gpt-4.1-mini": { input: 0.4, cachedInput: 0.1, output: 1.6 },
  "gemini-3.8-flash": { input: 0.75, cachedInput: 0.075, output: 3.75 },
};

/** Modelos que no se cobran por tokens: no cuentan como «sin precio» en el aviso del panel. */
export const PRICED_OUTSIDE_TOKENS = new Set(["gpt-transcribe"]);

/** Costo en USD, o `null` si el modelo no tiene precio. Fórmula de `costUSD` del banco. */
export function costUSD(model: string, usage: { inputTokens: number; cachedTokens: number; outputTokens: number }): number | null {
  const price = PRICES[model];
  if (!price) return null;
  const fresh = Math.max(0, usage.inputTokens - usage.cachedTokens);
  return (fresh * price.input + usage.cachedTokens * price.cachedInput + usage.outputTokens * price.output) / 1_000_000;
}
