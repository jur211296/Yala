---
id: stats-per-account-branch-keeps-stale-live-anchor
status: backlog
priority: very-low
area: statistics
created: 2026-09-09
source: hallazgo de camino en fx-approximate-mark-missing-on-secondary-surfaces (2026-09-09)
updated: 2026-10-08
---

# La rama por-cuenta de Estadísticas se queda con el saldo vivo del cálculo anterior

## Qué le pasa al usuario

En Tendencias, al pasar a una vista por cuenta, el punto «hoy» del gráfico y la hoja educativa que
abre pueden seguir mostrando el saldo del cálculo ANTERIOR — el agregado— en vez de recalcularse o
desaparecer.

## Dónde, medido el 2026-09-09

`StatisticsViewModel.calculateTrendData` tiene dos ramas. La primera llama a
`TrendDataProcessor.processTrendData` y asigna `trendLiveAnchor`, `trendLiveAnchorBreakdown` y
—desde hoy— `trendLiveAnchorIsApproximate`. La segunda, `calculatePerAccountTrend`, **no toca
ninguna de las tres**: se quedan con el valor que dejó la pasada anterior.

Es preexistente y afecta por igual a los tres campos, así que la señal de aproximado que se añadió
el 2026-09-09 hereda exactamente el mismo comportamiento que el valor que describe — no lo empeora
ni lo delata: acompaña al número correcto o al número viejo, siempre a la vez.

## Qué falta por medir

No está comprobado que la hoja llegue a abrirse en esa rama; si `TrendChartView` recibe
`showTodayIndicators: false` ahí, el residual sería inalcanzable. **Eso se mide antes de arreglar
nada** — y si resulta inalcanzable, el arreglo es un `nil` explícito con su comentario, no dejarlo
como está.

## Criterio de hecho (AC)

- [ ] Medido si el anchor pegado llega a verse en la rama por-cuenta.
- [ ] `calculatePerAccountTrend` limpia los tres campos (o los calcula), y un test lo fija.

## Medido en 2.1 (triage 2026-10-08)

- Medido el primer criterio: la rama es **inalcanzable**. `StatisticsViewModel.isAggregatedView` nace en `true` y nada en `Yala/` lo pone a `false` (solo lo leen la propia rama y un `.onChange` en `DetailContainerView`), y así estaba ya el 2026-09-09.
- `calculatePerAccountTrend` sigue sin tocar `trendLiveAnchor`, `trendLiveAnchorBreakdown` ni `trendLiveAnchorIsApproximate`. Según el propio ticket, lo que queda es el `nil` explícito con su comentario, o retirar la rama muerta.

Triage 2026-10-08: abierto · low → very-low · el saldo pegado sigue en el código, pero ninguna pantalla puede poner Tendencias en vista por cuenta (isAggregatedView nunca pasa a false), así que nadie lo ve.
