---
id: ai-calls-have-no-output-token-cap
status: backlog
priority: low
area: ai
created: 2026-10-07
updated: 2026-10-08
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H7)
---

# Ninguna llamada de IA pone tope a la longitud de la respuesta

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
