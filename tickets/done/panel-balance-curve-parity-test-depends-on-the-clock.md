---
id: panel-balance-curve-parity-test-depends-on-the-clock
status: done
priority: high
area: tests, panel
created: 2026-10-20
updated: 2026-10-20
source: check `tests` del PR #567 (card tablero-unit-test-de-paridad-de-la-curva-del-pan-xzb7)
---

# `PanelBalanceFigureCurveParityTests` sale rojo según el día del mes (2.1)

## Qué pasaba

El 2026-10-20 el check `tests` del PR #567 —solo docs, base `2.1`— cayó tres veces seguidas en
`everyPastPoint_isThatDaysBalanceAtThatDaysRate(.realista)` (`PanelBalanceFigureCurveParityTests.swift:140`). El control
final pedía que el primer punto pasado del mes no valiera lo mismo con la tasa de su día que con la de hoy. Valía lo
mismo: 66718,85.

## Por qué

El bug era del test, no del código. La aserción principal —cada punto vale el saldo de su día por la tasa de su día—
pasaba; solo caía el control.

- `DevSeedExchangeRates` genera las tasas con un paseo aleatorio de semilla fija (42), anclado a hoy, con pasos de
  ±0,02 y redondeado a dos decimales. Días consecutivos repiten tasa a menudo, y qué día coincide con hoy depende solo
  de cuántos días han pasado del mes. Medido replicando el paseo: con `realista`, la tasa del día 1 es la de hoy los
  días **20 y 27** de cada mes.
- Los días **1 a 3** del mes caía además por otro lado: «Este mes» no tiene tres días pasados y el `#require` del
  principio salía rojo.

## Qué se hizo

Solo el test (`YalaTests/PanelBalanceFigureCurveParityTests.swift`):

1. El control ya no depende de la semilla. El test sube un 10 % la tasa de la divisa preferida en la fila de **ayer**
   y comprueba que el punto de ayer sale distinto con la tasa de hoy. Distingue las dos reglas corra el día que corra.
2. La aserción se mide en «Este mes» y en «Últimos 30 días», que siempre tiene días pasados.
3. El reloj se lee una vez y se pasa a `DetailPeriod.dateInterval(now:)`.

En `2.2`, el PR #568 dejó el control en «algún punto pasado distingue» (ticket
`panel-balance-curve-parity-test-depends-on-the-day`). Eso aguanta con la semilla de hoy, pero sigue dependiendo del
paseo aleatorio y no cubre los días 1 a 3. Al fundir `2.1` en `2.2` este test choca: gana esta versión.

## Lo que queda

La semilla y `TrendDataProcessor` siguen leyendo `Date.now` por su cuenta. Si el test cruza la medianoche mientras
corre, puede salir rojo; es una ventana de segundos. Fijar el reloj entero exige inyectarlo en producción
(`DevSeedService.seed`, `liveBalanceOverride`, `TrendDataProcessor`), y eso no se pidió.
