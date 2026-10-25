---
id: ficha-mx-vida-rates-jump-on-the-last-day
status: done
priority: low
area: seed
created: 2026-10-16
updated: 2026-10-25
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

## Cerrado (cola 2.2 · lote 12.5, 2026-10-25)

**La causa inferida no era la real.** Medido: la fila sembrada de hoy NO la sustituye la tasa real (sigue en 18,30). Lo que caía era el punto de hoy: el saldo vivo se convertía con la tabla estática (14.835 USD × 17,2 − 61.850 MXN = 193.312, la cifra exacta que enseñaba el Panel) porque la semilla escribía las tasas sin avisar al conversor (`.yalaExchangeRatesUpdated`), que se quedaba con lo resuelto antes de sembrar. Arreglo en `DevSeedService`: avisa tras sembrar (también en el camino corto de cuenta con movimientos). Después: 209.630,50, sin caída. Solo afecta a las semillas (DEBUG); el cambio no toca la semilla, solo el aviso. Test: `DevSeedNotifiesExchangeRatesTests`. Capturas `antes-5`/`despues-5` del PR.
