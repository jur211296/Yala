---
id: insights-cards-send-the-note-of-the-largest-expense
status: done
priority: low
area: insights, privacidad
created: 2026-10-20
updated: 2026-10-25
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

## Hecho (2026-10-25, lote 12.7, card ve42)

Opción recomendada: viaja la subcategoría (o la categoría, o «Sin categoría»), nunca la nota. `HighestExpenseInfo` gana
`categoryLabel` y `InsightsViewModel.buildAggregatedData` lo manda en `highest_expense.description`; la pantalla sigue
enseñando la nota (no sale del teléfono). Así el payload casa con lo que promete el permiso de Observaciones.
Test: `YalaTests/InsightsHighestExpenseNoNoteTests` (con el código viejo la nota «Regalo para Ana» viajaba).
Sin banco de `insights.cards`: el campo pasa de un texto libre a una etiqueta de la misma lista que ya viaja en
`category_tree`, y el prompt solo lo nombra como «gasto atípico». El fixture del banco (`gateway/bench/lib/insightsRequests.ts`)
ya usa etiquetas sintéticas en ese campo.
