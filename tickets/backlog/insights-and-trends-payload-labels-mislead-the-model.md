---
id: insights-and-trends-payload-labels-mislead-the-model
status: backlog
priority: low
area: insights, trends, ai
created: 2026-10-07
updated: 2026-10-08
source: banco de Insights y Tendencias (sesión 2 del gateway de IA, gateway/bench/results/2026-10-07/REPORT-insights-y-tendencias.md)
---

# Tres etiquetas de los datos que la app manda a la IA llevan a error

## Lo medido (2026-10-07)

1. **`monthsPositive` y `monthsNegative` cuentan el saldo ACUMULADO**, y los modelos lo leen como flujo del mes («flujo
   positivo los 6 meses»). Conviene renombrarlo (`monthsWithPositiveBalance`) o mandar el flujo.
2. **La etiqueta de mes «Sept 26» / «9月 26»** se lee como el día 26. Mejor «sep 2026» o el año con cuatro cifras.
3. **El enfoque de Tendencias menciona «cards» y «hero»**, que no existen en esa pantalla.

## Hecho cuando

- Las tres etiquetas cambiadas y `npm run bench -- --task insights.cards,trends.summary` igual o mejor que el 2026-10-07.

## Medido en 2.1 (triage 2026-10-08)

- `InsightsLLMService.buildCashFlowPayload` sigue contando `monthsNegative` sobre `accumulatedBalance`. `be06b429e` (2026-10-07) arregló el idioma de esos comentarios, no estas etiquetas.
- La etiqueta corta sale de `PreviousPeriodHelper` (`dateFormat = "MMM yy"`, ramas `.thisMonth/.lastMonth`) y viaja como `comparison_label` desde `InsightsViewModel`. Los nombres de mes del flujo de caja ya van con año completo (`.year()`).
- `TrendsAIService` sigue llamando a `InsightsLLMService.focusInstruction(for:)`, cuyo texto habla del hero y de cards.

Triage 2026-10-08: abierto · low → low · Las tres siguen vivas: `monthsPositive/monthsNegative` sobre saldo acumulado (InsightsLLMService.buildCashFlowPayload), «MMM yy» en `PreviousPeriodHelper` → `comparison_label`, y `TrendsAIService` reusa `focusInstruction` con hero y cards.
