---
id: panel-balance-curve-parity-test-depends-on-the-day
status: done
priority: low
area: tests, panel
created: 2026-10-20
updated: 2026-10-20
source: gate de la revisión de Yala IA 2.2
---

# `PanelBalanceFigureCurveParityTests` sale rojo según el día

## Qué pasa

El 2026-10-20, `everyPastPoint_isThatDaysBalanceAtThatDaysRate(.realista)` falla en
`PanelBalanceFigureCurveParityTests.swift:140` (`!close(first.value, todaysRate)`), también corriendo la suite sola.
Medido también sobre `origin/2.2` limpio (`f0d948468`), en un worktree aparte: el mismo rojo, así que no viene de la sesión que lo vio.
Inferido, sin medir: la comprobación final pide que el primer punto del mes no valga lo mismo con la tasa de su día
que con la de hoy, y las tasas de la semilla `realista` se generan por día (`DevSeedExchangeRates`, aleatorio con
semilla): algún día del mes la tasa del día 1 coincide con la de hoy a los decimales que compara.

## Qué hay que hacer

Medir las dos tasas el día que falle. Si es eso, elegir como control un punto cuya tasa difiera de la de hoy en vez del
primero.

## Resuelto (2026-10-20)

Medido: la semilla redondea la tasa del PEN a dos decimales (`DevSeedExchangeRates`), así que algún día la del día 1 es
la de hoy. El control ya no se fija en el primer punto: basta con que ALGÚN punto pasado no valga lo mismo con la tasa de
hoy, que es lo que el test quería probar (las tasas cambian por día). Verde con `realista` y `ficha-mx-vida`.

## Sustituido (2026-10-20, merge de 2.1 en 2.2)

Al fundir `2.1` en `2.2`, el test se quedó con la versión de 2.1 (PR #569, ticket
`panel-balance-curve-parity-test-depends-on-the-clock`): sube la tasa de ayer a mano y no depende del paseo aleatorio de
la semilla ni de que el mes tenga días pasados. El control de «algún punto pasado distingue» de este ticket ya no está en
el código.
