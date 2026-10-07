---
id: chat-sends-every-past-turn-to-the-model
status: backlog
priority: low
area: chat, ai
created: 2026-10-07
updated: 2026-10-07
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H8)
---

# El chat manda todos los turnos anteriores en cada pregunta

> **Grupo: autónomo.** Recorte de contexto. No cambia modelo ni proveedor; baja tokens de entrada.

## Qué pasa

Cada pregunta nueva del chat reenvía el system prompt (≈1,5 k tokens de reglas, estimado), el JSON
financiero completo y **todos** los turnos anteriores de la conversación. La pregunta 30 lleva 29 pares
pregunta-respuesta delante. El propio prompt pide al modelo que **ignore** los turnos que no tienen que
ver con la pregunta nueva, así que la mayoría se pagan para no usarse.

## Lo medido (2026-10-07, en este árbol)

- `ChatAssistantService.buildMessages` (≈338-360) recorre `turns` entero.
- `ChatAssistantViewModel.sendMessage` pasa `allTurns` (≈222) sin recortar.
- El límite diario es 75 preguntas (`ChatAssistantService.dailyLimit` y `gateway/src/policy.ts`).

## Qué hay que hacer

Mandar solo los últimos N turnos (propuesta: 6) y dejar el historial completo en pantalla como está.
Los follow-ups («¿y eso?») solo necesitan los últimos.

## Hecho cuando

- Test: con 20 turnos, `buildMessages` produce system + 6 pares + la pregunta.
- El historial visible del chat no cambia.
