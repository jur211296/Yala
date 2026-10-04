---
id: trends-hero-keeps-the-previous-period-after-changing-it-on-trends
status: backlog
priority: medium
area: statistics
created: 2026-10-03
updated: 2026-10-03
source: hallazgo de trends-insight-card-v2-bullets (simulador, 2026-10-03)
---

# El número grande de Tendencias se queda con el período anterior al cambiarlo desde Tendencias

## Qué pasa

En Estadísticas › Tendencias, si cambias el período desde esa misma pestaña, el hero (cifra grande,
ingresos, gastos y la frase de debajo) sigue mostrando el período de antes. Las gráficas sí cambian.

**Medido el 2026-10-03** en el simulador, seed `realista`: Estadísticas → Tendencias con «Todo el
tiempo» → elegir «Mes pasado». Las gráficas pasan a septiembre (Comparativa «+5,1 % vs Ago 26») y el
hero sigue en S/ 63.193 / 270.163 / 206.970 con «Aumento +0 %», que son las cifras de «Todo el
tiempo». Si el cambio se hace en Resumen y luego se va a Tendencias, el hero sale bien (S/ 3.292).

## Por qué (leído en el código, no medido con traza)

El hero de Tendencias lee `insightsViewModel.insightData`, y `DetailContainerView.performCalculation`
solo llama a `calculateInsightsData()` con `selectedTab == .insights || .categories`
(`DetailContainerView.swift`, `performCalculation` y `calculateInsightsData`). En Tendencias el
cambio de período recalcula la tendencia pero no `insightData`.

El Trend Insight Card tenía el mismo problema en su gate de «≥ 5 movimientos»; en
`trends-insight-card-v2-bullets` el gate pasó a un conteo propio (`StatisticsViewModel.periodTransactionCount`).
El hero no se tocó: fuera de alcance.

## Qué hay que decidir

Recalcular `insightData` también en Tendencias (coste: el cálculo de Resumen y la Salud Financiera
en cada cambio) o derivar el hero de Tendencias de lo que ya calcula `StatisticsViewModel`.
