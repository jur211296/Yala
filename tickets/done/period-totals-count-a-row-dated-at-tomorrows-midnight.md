---
id: period-totals-count-a-row-dated-at-tomorrows-midnight
status: done
priority: low
area: panel, statistics, widgets
created: 2026-10-19
updated: 2026-10-25
source: review adversarial del saldo de hoy con fechas futuras (lote decidido 2.2 · 01, 2026-10-18)
---

# Los totales de «Este mes» cuentan un movimiento fechado mañana a las 00:00

## Qué le pasa al usuario

Los períodos en curso cierran en el inicio de mañana y `DateInterval` incluye su final. Un gasto fechado mañana a las
00:00 (la hora que guarda el selector de fecha) entra en «Entró» y «Salió» de este mes, mientras el saldo de hoy ya lo
deja fuera (`LiveBalanceCalculator.TodayCutoff`, 2026-10-18). Ejemplo: la ficha de una cuenta dice «Salió 200» junto
a «Saldo hoy 1.000».

## Dónde (leído, sin medir en pantalla)

- `WidgetDataCache.buildPeriodSummary`: `tx.date <= periodEnd`.
- `AccountDetailCalculator.summary` (entró, salió, últimos).
- `StatisticsViewModel.calculatePerAccountTrend`: el bucle de días con `<=` crea el día de mañana para ingresos y
  gastos.
- Los totales del Panel y de Estadísticas que filtran con `interval.contains`.

Ya existía antes del corte del saldo; lo hace visible. Es la trampa de «Cálculos con fechas» del `CLAUDE.md`.

## Cerrado (cola 2.2 · lote 12.5, 2026-10-25)

Arreglado en la fuente: los períodos en curso de `DetailPeriod.dateInterval` y `WidgetPeriod.dateInterval` cierran a las 23:59:59 de hoy, como los cerrados. Una auditoría de los ~84 usos encontró un daño real (el anterior de «Últimos 7/30 días» y de un rango propio se anclaba por duración y perdía la medianoche de su primer día; ahora se ancla por días de calendario, `PreviousPeriodHelper.previousStartByDays`, que además aguanta un cambio de hora dentro de los dos tramos, lo que cazó la review adversarial) y cuatro construcciones a mano con el mismo borde: «Todo» del Panel, el mes del hero, los compromisos del mes y del año, los planificados del Sankey (`plannedInterval`, cazado por la review) y el informe diario lanzado a medianoche. Los filtros semiabiertos (pagos pagados, saldo del período del widget) toleran los dos bordes, y «llega a hoy» compara con el inicio de hoy. Tests: `PeriodEndsBeforeTomorrowMidnightTests`, `DetailPeriodDateIntervalMoreTests` y `WidgetDataServiceIntervalTests` (los dos últimos fijaban el borde viejo y se actualizaron a propósito). Cambio visible menor: un pago que vence mañana deja de contar como pendiente del período en Observaciones.
