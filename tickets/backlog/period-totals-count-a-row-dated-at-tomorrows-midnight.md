---
id: period-totals-count-a-row-dated-at-tomorrows-midnight
status: backlog
priority: low
area: panel, statistics, widgets
created: 2026-10-19
updated: 2026-10-19
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
