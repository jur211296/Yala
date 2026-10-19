---
id: balance-figure-counts-future-dated-rows-the-curve-never-draws
status: done
priority: medium
area: panel/currency
created: 2026-10-16
updated: 2026-10-19
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

## Decisión y cierre (2026-10-18/19)

Jürgen eligió la opción A el 2026-10-18: el saldo de hoy deja fuera lo fechado después de hoy hasta su fecha. Hecho en
el lote decidido 2.2 · 01 con un solo corte (`LiveBalanceCalculator.TodayCutoff`) para el Panel, «¿Cuánto tienes hoy?»,
el widget, las tarjetas y la ficha de cuenta, el formulario, Estadísticas y el P&L cambiario. Review adversarial de tres
lentes; lo que quedó fuera va en sus tickets (`mcp-connector-counts-future-dated-rows-in-todays-balance`,
`period-totals-count-a-row-dated-at-tomorrows-midnight`, `widget-balance-figure-and-curve-count-different-rows-for-accountless-movements`,
`chat-context-balances-only-read-the-last-13-months`). Medido en el simulador con `-uitest-seed-future-movement`:
antes S/ 73,567.25 en la cifra (con el gasto de mañana) y la curva sin él; después S/ 73,817.25 en cifra, curva y hoja.
