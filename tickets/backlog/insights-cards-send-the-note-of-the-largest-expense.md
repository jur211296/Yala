---
id: insights-cards-send-the-note-of-the-largest-expense
status: backlog
priority: low
area: insights, privacidad
created: 2026-10-20
updated: 2026-10-20
source: revisión de Yala IA 2.2 (docs/ai/revision-ia-2-2.md §1)
---

# Observaciones manda la nota libre del gasto más alto

## Qué pasa

`InsightsViewModel.swift:424` escribe `highest_expense = { amount, description: highest.note }` en los datos que van a
`insights.cards`. La nota es texto libre de la persona. El propio servicio dice que manda «aggregated stats (never
individual transactions)» (`InsightsLLMService.swift:101`), y el permiso de Observaciones habla de agregados.

## Qué hay que hacer

Decidir si se manda la subcategoría en vez de la nota (recomendado: es lo que ya cuenta el permiso), o si el permiso
pasa a decirlo. Medir en el banco de `insights.cards` que la tarjeta del gasto más alto no pierde calidad.
