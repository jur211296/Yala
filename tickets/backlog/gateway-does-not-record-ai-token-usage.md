---
id: gateway-does-not-record-ai-token-usage
status: backlog
priority: medium
area: gateway, ai, cost
created: 2026-10-07
updated: 2026-10-07
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H9)
---

# Nadie sabe cuántos tokens gasta cada función de IA

> **Grupo: autónomo.** Medición. No cambia modelo, proveedor ni comportamiento de la app. Es requisito
> de las decisiones de coste que están en los tickets «para Jürgen».

## Qué pasa

El gateway reenvía la respuesta de OpenAI tal cual (`gateway/src/proxy/openai.ts`, `proxy()`), sin leer
el bloque `usage`. Así que no hay respuesta a «¿cuánto cuesta una pregunta del chat?», «¿qué parte del
prompt se sirve de caché?» o «¿cuántas respuestas llegan cortadas?». La revisión del 2026-10-07 tuvo que
**estimar** desde el código, y el encargo prohibía medir con llamadas de pago.

Relacionado, no duplicado: `gateway-has-no-telemetry` trata el gateway sin ningún `writeDataPoint`
(canarios de push). Este ticket es el caso concreto de IA y tiene su propio criterio de hecho.

## Lo medido (2026-10-07, en este árbol)

- Todas las llamadas de chat son `stream: false`, así que la respuesta es un JSON entero con `usage`.
- `gateway/src/metrics.ts` ya escribe en Analytics Engine (`dataset.writeDataPoint`, ≈102).
- La categoría de cuota (`X-Yala-Category`) ya distingue chat, vision, voice, insights y suggestions.

## Qué hay que hacer

1. En `/v1/chat/completions`, leer el cuerpo de la respuesta (no el de la petición) y escribir un punto
   con: categoría, `model`, `prompt_tokens`, `prompt_tokens_details.cached_tokens`,
   `completion_tokens`, `finish_reason` y status. **Nada del contenido.**
2. En `/v1/audio/transcriptions`, la categoría y el status (la duración del audio no viaja en la
   respuesta de `whisper-1`).
3. Devolver al cliente exactamente la misma respuesta.
4. Una consulta guardada en la doc del gateway: tokens medios por categoría y % cacheado.

## Hecho cuando

- Test del gateway: una respuesta con `usage` produce un datapoint con esos campos y ninguno de texto.
- La respuesta al cliente es byte a byte la de OpenAI.
- Tras una semana en producción hay coste medio por pregunta de chat, por foto y por nota de voz.
