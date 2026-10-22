import type { ImageDetail, ProviderId, ReasoningEffort } from "../src/ai/routes";

/**
 * Candidatos del banco. Precios en USD por 1M tokens, tarifa estándar, COMPROBADOS en la página oficial
 * el día que se corre (`checked`). Si cambian, se cambian aquí y se vuelve a correr: el informe dice con
 * qué precio se decidió.
 *
 * Fuentes (2026-10-07):
 * - OpenAI: https://developers.openai.com/api/docs/pricing
 * - Google: https://ai.google.dev/gemini-api/docs/pricing (nivel de pago; el gratuito entrena con los datos)
 * - Anthropic: skill claude-api, tabla cacheada el 2026-09-25 (platform.claude.com/docs/en/about-claude/pricing)
 * - Workers AI: https://developers.cloudflare.com/workers-ai/platform/pricing/
 * - xAI: https://docs.x.ai/docs/models (precio < 200k tokens de prompt; la caché no está publicada: se cobra entera)
 */
export interface Price {
  input: number;
  cachedInput: number;
  output: number;
}

export interface Candidate {
  /** Identificador estable en resultados: `proveedor:modelo[:esfuerzo]`. */
  id: string;
  provider: ProviderId;
  model: string;
  price: Price;
  /** Modelos de razonamiento: se prueban con estos esfuerzos (el encargo: bajo y ninguno). */
  efforts?: ReasoningEffort[];
  /** ¿Acepta temperatura? Los de razonamiento de OpenAI y Sonnet 5.5 no (o solo la de por defecto). */
  temperature: boolean;
  vision: boolean;
  /** Para la foto: `detail` que se prueban. */
  details?: ImageDetail[];
  note?: string;
}

export const CHECKED = "2026-10-07";

export const CANDIDATES: Candidate[] = [
  // --- OpenAI ---
  { id: "openai:gpt-4.1-nano", provider: "openai", model: "gpt-4.1-nano", price: { input: 0.1, cachedInput: 0.025, output: 0.4 }, temperature: true, vision: true, details: ["auto"], note: "línea base de hoy; se apaga el 2026-10-23" },
  { id: "openai:gpt-4.1-mini", provider: "openai", model: "gpt-4.1-mini", price: { input: 0.4, cachedInput: 0.1, output: 1.6 }, temperature: true, vision: true, details: ["low", "high"] },
  { id: "openai:gpt-6-luna", provider: "openai", model: "gpt-6-luna", price: { input: 0.1, cachedInput: 0.01, output: 0.5 }, efforts: ["none", "low"], temperature: false, vision: true, details: ["low", "high"] },
  { id: "openai:gpt-5.6-luna", provider: "openai", model: "gpt-5.6-luna", price: { input: 0.2, cachedInput: 0.02, output: 1.2 }, efforts: ["none", "low"], temperature: false, vision: true, details: ["low", "high"], note: "sustituto oficial de nano" },
  { id: "openai:gpt-5.4-mini", provider: "openai", model: "gpt-5.4-mini", price: { input: 0.75, cachedInput: 0.075, output: 4.5 }, efforts: ["none", "low"], temperature: false, vision: true, details: ["low", "high"] },
  { id: "openai:gpt-5.4-nano", provider: "openai", model: "gpt-5.4-nano", price: { input: 0.2, cachedInput: 0.02, output: 1.25 }, efforts: ["none", "low"], temperature: false, vision: true, details: ["low", "high"], note: "se apaga el 2027-04-01" },
  { id: "openai:gpt-5.6-terra", provider: "openai", model: "gpt-5.6-terra", price: { input: 2.0, cachedInput: 0.2, output: 12.0 }, efforts: ["none", "low"], temperature: false, vision: true, details: ["low", "high"] },

  // --- Google ---
  { id: "gemini:gemini-3.5-flash-lite", provider: "gemini", model: "gemini-3.5-flash-lite", price: { input: 0.3, cachedInput: 0.03, output: 2.5 }, efforts: ["none", "low"], temperature: true, vision: true, details: ["low", "high"] },
  { id: "gemini:gemini-3.1-flash-lite", provider: "gemini", model: "gemini-3.1-flash-lite", price: { input: 0.25, cachedInput: 0.025, output: 1.5 }, temperature: true, vision: true, details: ["low", "high"] },
  { id: "gemini:gemini-3.8-flash", provider: "gemini", model: "gemini-3.8-flash", price: { input: 0.75, cachedInput: 0.075, output: 3.75 }, efforts: ["low"], temperature: true, vision: true, details: ["low", "high"], note: "precio de lanzamiento hasta el 2026-12-31; luego ×2" },

  // --- Anthropic ---
  { id: "anthropic:claude-haiku-4-5", provider: "anthropic", model: "claude-haiku-4-5", price: { input: 1.0, cachedInput: 0.1, output: 5.0 }, efforts: ["none"], temperature: true, vision: true, details: ["auto"] },
  { id: "anthropic:claude-sonnet-5-5", provider: "anthropic", model: "claude-sonnet-5-5", price: { input: 2.0, cachedInput: 0.2, output: 10.0 }, efforts: ["none", "low"], temperature: false, vision: true, details: ["auto"] },

  // --- xAI (Grok) — añadido a petición de Jürgen (2026-10-07). Precios de docs.x.ai/docs/models ---
  { id: "xai:grok-4.20-non-reasoning", provider: "xai", model: "grok-4.20-0309-non-reasoning", price: { input: 1.25, cachedInput: 1.25, output: 2.5 }, temperature: true, vision: true, details: ["high"] },
  { id: "xai:grok-4.3", provider: "xai", model: "grok-4.3", price: { input: 1.25, cachedInput: 1.25, output: 2.5 }, temperature: true, vision: true, details: ["high"] },

  // --- Modelos abiertos alojados en Cloudflare (Workers AI) ---
  { id: "workersai:llama-4-scout", provider: "workersai", model: "@cf/meta/llama-4-scout-17b-16e-instruct", price: { input: 0.27, cachedInput: 0.27, output: 0.85 }, temperature: true, vision: true, details: ["auto"] },
  { id: "workersai:mistral-small-3.1", provider: "workersai", model: "@cf/mistralai/mistral-small-3.1-24b-instruct", price: { input: 0.351, cachedInput: 0.351, output: 0.555 }, temperature: true, vision: true, details: ["auto"] },
  { id: "workersai:gpt-oss-20b", provider: "workersai", model: "@cf/openai/gpt-oss-20b", price: { input: 0.2, cachedInput: 0.2, output: 0.3 }, efforts: ["low"], temperature: false, vision: false },

  // --- sesión 2 (trabajador B) ---
  // Vigentes el 2026-10-07 que faltaban. Precios de las páginas oficiales de ese día: OpenAI (developers.openai.com/api/docs/pricing;
  // ninguno con apagado anunciado en /deprecations), Anthropic (platform.claude.com/docs/en/about-claude/pricing; Haiku 5.5 hasta
  // 100k tokens de prompt; retirada «no antes de» sep-oct 2027), xAI (docs.x.ai/docs/models, < 200k tokens) y Workers AI
  // (developers.cloudflare.com/workers-ai/platform/pricing). `vision: false` en los abiertos: no se han medido con la foto.
  // `none` no existe en gpt-6.1-sol ni gpt-6-astra (la API solo admite low/medium/high/xhigh). Haiku 5.5 y Opus 5.5 van con
  // `low` porque el adaptador mandaba `between_tools` con `none` y lo rechazaban; el trabajador A lo corrigió el mismo día
  // (`thinking: disabled`) y Haiku 5.5 sin razonamiento es su línea `:none`, más abajo. Medidos y descartados ese día:
  // DeepSeek V4 Flash y Gemma 4 26B de Workers AI (2048 tokens razonando, contenido vacío, 31 y 72 s).
  { id: "openai:gpt-6.1-sol", provider: "openai", model: "gpt-6.1-sol", price: { input: 2.0, cachedInput: 0.1, output: 10.0 }, efforts: ["low"], temperature: false, vision: true, details: ["low", "high"] },
  { id: "openai:gpt-5.5", provider: "openai", model: "gpt-5.5", price: { input: 5.0, cachedInput: 0.5, output: 30.0 }, efforts: ["none", "low"], temperature: false, vision: true, details: ["low", "high"] },
  { id: "openai:gpt-6-astra", provider: "openai", model: "gpt-6-astra", price: { input: 10.0, cachedInput: 1.0, output: 50.0 }, efforts: ["low"], temperature: false, vision: true, details: ["low", "high"] },
  { id: "anthropic:claude-haiku-5-5", provider: "anthropic", model: "claude-haiku-5-5", price: { input: 0.1, cachedInput: 0.01, output: 0.5 }, efforts: ["low"], temperature: false, vision: true, details: ["auto"] },
  { id: "anthropic:claude-opus-5-5", provider: "anthropic", model: "claude-opus-5-5", price: { input: 4.0, cachedInput: 0.2, output: 20.0 }, efforts: ["low"], temperature: false, vision: true, details: ["auto"] },
  { id: "xai:grok-4.7", provider: "xai", model: "grok-4.7", price: { input: 2.0, cachedInput: 0.5, output: 6.0 }, temperature: true, vision: true, details: ["high"] },
  { id: "workersai:gpt-oss-120b", provider: "workersai", model: "@cf/openai/gpt-oss-120b", price: { input: 0.35, cachedInput: 0.35, output: 0.75 }, efforts: ["low"], temperature: false, vision: false },

  // --- sesión 2 (trabajador A) ---
  // Lo que faltaba del mercado ya lo añadió el bloque de arriba. Aquí solo Claude Haiku 5.5 SIN razonamiento: el adaptador
  // de Anthropic lo apaga desde el 2026-10-07 con `thinking: disabled` (`between_tools` es solo de Sonnet 5.5; test en
  // test/ai.anthropic.thinking.test.ts). Mismo precio que la línea de `low` (platform.claude.com/docs, ≤ 100k tokens de prompt).
  { id: "anthropic:claude-haiku-5-5:none", provider: "anthropic", model: "claude-haiku-5-5", price: { input: 0.1, cachedInput: 0.01, output: 0.5 }, efforts: ["none"], temperature: false, vision: true, details: ["auto"], note: "sin razonamiento (thinking: disabled)" },
];

export function costUSD(price: Price, usage: { inputTokens: number; cachedInputTokens: number; outputTokens: number } | null): number | null {
  if (!usage) return null;
  const fresh = Math.max(0, usage.inputTokens - usage.cachedInputTokens);
  return (fresh * price.input + usage.cachedInputTokens * price.cachedInput + usage.outputTokens * price.output) / 1_000_000;
}
