---
id: balance-figure-counts-future-dated-rows-the-curve-never-draws
status: backlog
priority: medium
area: panel/currency
created: 2026-10-16
updated: 2026-10-16
source: review adversarial de panel-balance-chart-contradicts-its-own-figure (2026-10-16)
---

# El saldo cuenta los movimientos con fecha futura y la curva no los dibuja

## Qué le pasa al usuario

Apunta un gasto de 200 con fecha de mañana. El widget Saldo del Panel dice 800, y la curva acaba en 1.000: la curva
llega hasta hoy y el saldo vivo suma todas las filas, también las de mañana. Es la misma contradicción que cerró
`panel-balance-chart-contradicts-its-own-figure`, por otra puerta.

## Dónde (leído, sin medir en pantalla)

`LiveBalanceCalculator.liveBalanceBreakdown` suma todas las transacciones de las cuentas elegibles sin mirar la
fecha. `TrendDataProcessor` construye buckets hasta el final de hoy (`effectiveEnd`). Las semillas no tienen filas
futuras, así que `PanelBalanceFigureCurveParityTests` no lo ve.

## Decisión que pide

Qué es «el saldo de hoy» con un movimiento futuro apuntado: lo que hay hoy (la cifra deja fuera lo futuro) o lo que
habrá (la curva se alarga hasta la fecha del movimiento). Decide Jürgen; afecta al hero del Panel, a la hoja «¿Cuánto
tienes hoy?» y al widget de inicio.
