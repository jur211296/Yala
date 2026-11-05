---
id: gateway-does-not-record-ai-token-usage
status: done
priority: medium
area: gateway, ai, cost
created: 2026-10-07
updated: 2026-11-04
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

## Medido en 2.1 (triage 2026-10-08)

- Avance parcial, de `cef2a467f` (07-oct): el proxy ya no vive en `gateway/src/proxy/openai.ts` sino en `gateway/src/ai/handler.ts`. `passthrough()` (`:131-147`) ya extrae `usage` (`openAIUsage`, `ai/providers/openai.ts:39`), y `logRoute()` (`:70-104`) lo escribe con categoría, modelo, status e `in`/`cached`/`out`/`reasoning`.
- Lo que falta: `logRoute` es un `console.log`. No hay `writeDataPoint` (el único sigue en `metrics.ts:102`) ni `[observability]` en `gateway/wrangler.toml`, así que el dato muere al cerrar `wrangler tail`.
- Tampoco hay `finish_reason`, test del datapoint ni consulta guardada. La transcripción registra `usage: null` (`handler.ts:250`, `:258`), que basta para su punto 2 si se persiste.

Triage 2026-10-08: abierto · medium → medium · desde `cef2a467f` el gateway lee `usage` y lo escribe en `console.log` (`ai/handler.ts:70-104`), pero no lo persiste en Analytics Engine ni guarda `finish_reason`.

## Cierre 2026-11-04

Decisión de Jürgen (2026-11-04): **Analytics Engine, dataset propio** (`yala_ai_usage`, `_staging` en staging). Guarda 90
días; si hiciera falta más historia, se guarda aparte un resumen mensual.

- `src/ai/usage.ts`: una fila por llamada con tarea, cubo, proveedor, modelo, estado, `finish_reason`, tokens de entrada,
  caché, salida y razonamiento, ms e intentos. Las columnas, en `README.md` («Uso de tokens por llamada»), con la
  consulta de tokens medios por función, % cacheado y respuestas cortadas por el tope.
- Lo escriben los cuatro caminos: managed, `chat.explore`, passthrough y transcripción (esta sin tokens: la API no los da).
- La respuesta a la app no cambia: `test/ai.routing.test.ts` sigue comparando bytes.
- `test/ai.caps-and-usage.test.ts`: el registro trae esos campos y ninguno de texto ni del dispositivo; un error también
  se registra; un fallo al guardar no tumba la respuesta; las columnas de Analytics Engine están fijadas.

**Medido en staging** (versión `f48d2794`, `scripts/verify-ai.ts --headers`, 2026-11-05 UTC): las diez llamadas
llegaron al dataset.

| hora (UTC) | función | modelo | fin | estado | entrada | caché | salida | razonamiento | ms |
|---|---|---|---|---|---|---|---|---|---|
| 02:31:41 | photo.read | gpt-6-luna | stop | 200 | 4157 | 0 | 99 | 0 | 4074 |
| 02:31:42 | chat.intent | gpt-6-luna | stop | 200 | 750 | 0 | 17 | 0 | 844 |
| 02:31:46 | chat.suggestions | gpt-6-luna | stop | 200 | 339 | 0 | 303 | 0 | 3291 |
| 02:31:49 | text.parse | gpt-6-luna | stop | 200 | 182 | 0 | 143 | 54 | 2601 |
| 02:31:50 | chat.answer | gpt-6-luna | stop | 200 | 34 | 0 | 12 | 0 | 1280 |
| 02:31:52 | insights.cards | gpt-6-luna | stop | 200 | 46 | 0 | 81 | 30 | 1694 |
| 02:31:53 | insights.cashflow | gpt-6-luna | stop | 200 | 51 | 0 | 25 | 0 | 986 |
| 02:31:55 | insights.deviation | gpt-6-luna | stop | 200 | 56 | 0 | 31 | 0 | 1393 |
| 02:31:58 | trends.summary | gpt-6.1-sol | stop | 200 | 59 | 0 | 73 | 0 | 2956 |
| 02:32:00 | chat.rewrite | gpt-6-luna | stop | 200 | 42 | 0 | 20 | 0 | 1157 |

**Queda:** desplegar producción (Jürgen, `gateway/RUNBOOK.md`) y, tras una semana, leer el coste medio por pregunta, foto
y nota de voz con la consulta del README.
