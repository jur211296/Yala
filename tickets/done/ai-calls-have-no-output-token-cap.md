---
id: ai-calls-have-no-output-token-cap
status: done
priority: low
area: ai
created: 2026-10-07
updated: 2026-11-04
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H7)
---

# Ninguna llamada de IA pone tope a la longitud de la respuesta

> **Reescrita el 2026-11-04 (sesión «Control del coste de la IA»).** La premisa de abajo era de 2.1: desde la sesión 2
> el gateway decide los parámetros, y nueve filas ya tenían tope. Lo que faltaba y cómo se cerró va en
> «Cierre 2026-11-04», al final.

> **Grupo: autónomo.** Parámetro de petición. No cambia modelo ni proveedor; solo acota el peor caso.

## Qué pasa

Ninguna de las once llamadas de chat pasa `maxCompletionTokens`. El prompt pide «máximo 3-4 oraciones»
o «150 caracteres», pero eso es una petición, no un límite. Una respuesta desbocada cuesta tokens de
salida (los caros) y tiempo: el cliente corta a los 20 s (`ProxyClientFactory.swift:27`) y en el chat
el usuario ve un error en vez de una respuesta larga.

## Lo medido (2026-10-07, en este árbol)

`grep -rn "maxCompletionTokens\|maxTokens" Yala` → 0 resultados en servicios de IA. El SDK 0.4.7 tiene
`maxCompletionTokens` (y `maxTokens` deprecado).

## Qué hay que hacer

Un tope por llamada, holgado respecto a lo que pide su prompt (orientativo: clasificador ≈ 50, comentario
de una frase ≈ 150, chat ≈ 600, Insights ≈ 1200, parser e imagen según el máximo de registros). Los
números se fijan midiendo con `gateway-does-not-record-ai-token-usage`, no a ojo.

Si la respuesta llega cortada (`finish_reason == "length"`), tratarlo como error tipado, no como JSON roto.

## Hecho cuando

- Cada `ChatQuery` lleva `maxCompletionTokens` (test por servicio).
- `finish_reason == "length"` tiene su rama y su copy.

## Medido en 2.1 (triage 2026-10-08)

- `git grep "maxCompletionTokens\|maxTokens" -- Yala` sigue dando 0 resultados; el gateway tampoco impone `max_tokens` fuera de `gateway/bench/`.

Triage 2026-10-08: abierto · low → low · sigue sin `maxCompletionTokens` en ninguna llamada; es coste y peor caso, no datos ni bloqueo.

## Cierre 2026-11-04

**Inventario medido en `gateway/src/ai/routes.ts`:**

| Fila | Antes | Ahora | De dónde sale |
|---|---|---|---|
| `chat.answer`, `chat.explore`, `chat.rewrite`, `text.parse`, `insights.cards`, `insights.cashflow`, `insights.deviation`, `trends.summary` | 512 · 512 · 300 · 1500 · 2020 · 256 · 256 · 1020 | igual | banco del 2026-10-07 |
| `photo.read` | sin tope | **6000** | máximo medido 2564 (extractos de varias páginas), ×2 |
| `chat.intent` | sin tope | **200** | máximo 86 en 259 respuestas |
| `chat.suggestions` | sin tope | **1000** | máximo 415 en 48 respuestas, ×2 |
| `insights.hero`, `legacy.passthrough` (versiones anteriores al 2026-10-03) | sin tope | **4096** si la app no fijó uno | máximo de `gpt-4.1-mini` en la foto: 1431 |
| `voice.transcribe` | — | — | la API de audio no tiene tope de salida |
| Gemini preparada de Tendencias (`PREPARED_ROUTES`) | 460 | igual | ya llegaba como `maxOutputTokens` y `MAX_TOKENS` ya se traducía a `length` |

- Las passthrough siguen saliendo byte a byte: solo se antepone `"max_completion_tokens":4096,` tras la `{`.
- `test/ai.caps-and-usage.test.ts` exige tope en toda fila managed (activas, preparadas y `LEGACY_OVERRIDES`) y que
  llegue a cada proveedor con su nombre. Mutante (quitar el de `chat.intent`): rojo.
- **Fuera:** la rama de `finish_reason == "length"` en la app (error tipado y copy). El encargo no tocaba la app iOS.
  El gateway ya registra el `finish_reason` de cada llamada, que dirá si hace falta.
