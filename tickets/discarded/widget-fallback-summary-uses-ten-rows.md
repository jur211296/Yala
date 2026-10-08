---
id: widget-fallback-summary-uses-ten-rows
status: discarded
priority: low
area: "widgets, currency"
created: 2026-09-09
updated: 2026-10-08
source: hallazgo de camino en bridge-de-grupos-pierde-la-marca-de-sus-patas (2026-09-09)
---

Why: Discarded 2026-10-08. El camino de emergencia es inalcanzable en cualquier build publicado. Desde `919166a2d` (2026-02-04, antes de `v1.0.0`) `WidgetDataCache` escribe `periodSummaries` con los ocho períodos (`thisWeek` … `allTime`), con los mismos `rawValue` que `WidgetPeriod`, y `WidgetDataService.calculateSummary` lo devuelve en su primer `if`. Un snapshot que no se deja leer devuelve `nil`, no el cálculo. Lo que queda es código muerto, no un número falso en pantalla.

# El widget puede presentar el total del mes calculado sobre diez transacciones

## Qué le pasa al usuario

Si el snapshot del App Group no trae el resumen precalculado del período que el widget pide, el
widget **no se queda vacío**: recalcula el total y lo pinta como si fuera bueno. Y lo recalcula sobre
las últimas **diez** transacciones, que es lo único que viaja en el snapshot. Un usuario con 200
gastos en el mes ve un gasto mensual que sale de diez filas, sin ninguna señal de que está mirando
una muestra.

## Dónde, medido el 2026-09-09

- `WidgetDataService.calculateSummary(for:)` (`:459-463`): agotados los dos caminos precalculados,
  cae a `buildPeriodSummary(from: snapshot.transactions.filter { interval.contains($0.date) })`.
- `WidgetDataCache.swift:384`: `snapshot.transactions` es
  `Array(eligibleRecentTransactions.prefix(10))` — diez filas, pensadas para la lista de «últimos
  registros», no para agregar.
- Además esas diez filas viajan **crudas** (`tx.amount`, `tx.amountInPreferredCurrency`,
  `tx.isExchangeRateProvisional`, `WidgetDataCache.swift:385-399`): sin el ajuste del bridge de
  grupos. En ese camino un gasto de grupo Caso A sale inflado a `-total` y su pata de préstamo
  cuenta como ingreso. Importe y marca son **coherentes entre sí** (crudo con crudo), así que la
  marca no miente sobre lo que suma — pero lo que suma no es lo que el usuario cree.

## Qué habría que decidir

Si un resumen de período que no se pudo precalcular debe **mostrarse igual** (hoy) o **decir que no
hay dato**. La app ya tiene resuelto el caso hermano: `periodBalance` devuelve `nil` cuando no hay
con qué calcularlo, y el widget lo respeta. Diez filas no son una muestra representativa de un mes,
y un número presentado sin salvedad es peor que un hueco.

## Criterio de hecho (AC)

- [ ] Decidido si el camino de emergencia se retira, se limita a los períodos que sus filas sí
      cubren, o marca el resultado como parcial.
- [ ] Si se conserva, queda escrito en el código por qué diez filas bastan para ese caso.

## Relacionados

- [[widget-period-balance-ignores-group-bridge-adjustment]] — el otro desajuste de conjunto del mismo
  snapshot, en el bucle del saldo.

Triage 2026-10-08: descartado · low → — · el cálculo sobre diez filas no se alcanza con ningún snapshot que haya escrito un build publicado.
