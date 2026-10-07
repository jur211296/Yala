---
id: free-voice-quota-counts-each-dictation-twice
status: backlog
priority: medium
area: voice, gateway, monetization
created: 2026-10-07
updated: 2026-10-07
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H13)
---

# El plan free da «5 usos de voz», pero cada nota de voz gasta 2

> **Grupo: para Jürgen.** Decisión de producto y de coste (cuota del plan free).

## Qué le pasa al usuario

Un usuario sin Pro registra por voz dos veces en el día y a la tercera recibe el límite diario. La
tercera nota incluso se transcribe y luego falla al leerla, gastando la quinta unidad.

## Lo medido (2026-10-07, en este árbol)

- `gateway/src/policy.ts`: free → `voice: { daily: 5 }`.
- `VoiceRecordingView.understand` (`Yala/App/Views/Voice/VoiceRecordingView.swift` ≈615-627) llama a
  `transcribe` (cuota `voice`) y luego a `parseMultiple` (cuota `voice`): **2 unidades por nota**.
- El atajo de Siri (`QuickExpenseIntent`) gasta 1 (solo el parser).
- El comentario de `policy.ts` dice que la cuota free «cubre el setup-checklist sin suscripción».

## Opciones

| | Qué se hace | A favor | En contra | Coste |
|---|---|---|---|---|
| **A** | Subir free `voice` a 10 (5 notas reales) | Lo que el usuario entiende por «5» | Dobla el gasto máximo de voz por free | Por nota ≈$0,002 (estimado): 5 notas más ≈$0,01/día por usuario free activo |
| **B** | El parser deja de contar en `voice` y cuenta en una categoría propia sin tope separado (o con el mismo 5) | Una nota = una unidad, sin tocar el número | Requiere tocar app y gateway |
| **C** | Dejarlo como está y documentar que son 2 notas | Cero trabajo | El usuario choca con un límite que no se explica |

## Recomendación

**B**: una nota de voz es una acción para el usuario y debe contar como una. Si se quiere algo para ya,
A es un cambio de una línea en el gateway.

## Hecho cuando

- Decisión anotada aquí.
- Test del gateway: una nota de voz completa (transcribir + leer) descuenta 1 unidad del free.
