---
id: insights-rate-limit-runs-before-the-cache
status: backlog
priority: low
area: insights, ai
created: 2026-10-07
updated: 2026-10-08
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H3)
---

# Insights rechaza por «demasiado rápido» una respuesta que ya tiene en caché

> **Grupo: autónomo.** Bug acotado de orden de comprobaciones. No cambia modelo ni proveedor.

## Qué le pasa al usuario

Pide el análisis de IA, sale de la pantalla y vuelve en menos de 5 segundos. La respuesta está en la
caché, pero en vez de mostrarla la tarjeta enseña el error de «rate limited».

## Lo medido (2026-10-07, en este árbol)

`InsightsLLMService.generateInsights` (≈108-128) hace, en este orden: pedir el cliente al gateway (App
Attest), comprobar el intervalo de 5 s y **después** mirar la caché. `generateContextualInsight`,
`generateCashFlowInsight` y `generateDeviationInsight` repiten el mismo orden. `TrendsAIService.generate`
(≈90-107) ya lo hace bien: caché primero, intervalo después y cliente al final.

Efecto secundario: un acierto de caché sigue pasando por App Attest, que puede ir a la red.

## Qué hay que hacer

Copiar el orden de `TrendsAIService`: caché → intervalo → cliente, en los cuatro métodos.

## Hecho cuando

- Test: dos llamadas con la misma clave separadas por menos de 5 s devuelven la caché sin error.
- Test: un acierto de caché no llama a `ProxyClientFactory`.

## Medido en 2.1 (triage 2026-10-08)

- `InsightsLLMService.generateInsights` mantiene el orden `ProxyClientFactory.makeOpenAI` → `lastCallTime` < 5 s → `rateLimited` → caché. Los dos commits posteriores al 2026-10-07 sobre el fichero (`3a0090cab`, `be06b429e`) no lo tocan.

Triage 2026-10-08: abierto · low → low · `InsightsLLMService.generateInsights` sigue pidiendo el cliente, luego el intervalo de 5 s y al final la caché; `TrendsAIService.generate` ya lo hace en el orden bueno.
