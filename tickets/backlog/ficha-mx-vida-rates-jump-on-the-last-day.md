---
id: ficha-mx-vida-rates-jump-on-the-last-day
status: backlog
priority: low
area: seed
created: 2026-10-16
updated: 2026-10-16
source: capturas de panel-balance-chart-contradicts-its-own-figure (2026-10-16)
---

# Con la semilla `ficha-mx-vida`, el saldo cae de golpe el último día

## Qué se ve

En el Panel, «Este mes», la curva del Saldo baja de ~190K a ~170K solo en el último día. Desde que cada punto se
valora a la tasa de su día (`panel-balance-chart-contradicts-its-own-figure`), el salto es el del dólar entre ayer y
hoy, y aquí es artificial: afea las capturas de la ficha.

## Causa probable [inferido, sin medir]

La semilla escribe una fila de tasas por día con el peso derivado del sol (`× 5`, ~17,5-19,5 por dólar), y al
arrancar la app pide la tasa real de hoy (`ExchangeRateService.updateTodayIfNeeded`), que sustituye la fila sembrada
de hoy con ~18,30. Medir: tasas de las filas de ayer y de hoy en el store tras sembrar.

## Arreglo posible

Que la semilla ancle la serie a la tasa real de hoy, o que en `-uitest` no se pida la tasa del día. Las capturas de la
App Store son de Lola: avisarle antes de cambiar la semilla.
