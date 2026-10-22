---
id: aligned-previous-interval-counts-the-next-midnight
status: backlog
priority: medium
area: statistics, panel
created: 2026-10-09
updated: 2026-10-09
source: encargo chat-context-archived-accounts-and-mtd (Frank, 2026-10-09), al reusar el helper para el chat
---

# El «vs mes pasado» de los heros cuenta un día de más cuando el gasto se fechó a medianoche

## Qué le pasa al usuario

El día 6, el hero de Tendencias y el del Panel comparan lo que va del mes con el mes pasado hasta el día 6. Un gasto
del 7 del mes pasado que se apuntó solo con fecha (el `DatePicker` de fecha guarda la medianoche exacta) entra también
en «el mes pasado hasta hoy». La variación sale con un día de más en el lado del mes pasado.

## Medido el 2026-10-09

- `DateAlignmentHelper.alignedPreviousInterval` cierra en la **medianoche del día siguiente** al equivalente
  (`endOfEquivalentDay = mapped + 1 día`), salvo cuando hace clamp al fin del mes pasado.
- `DateInterval.contains` es cerrado en los dos extremos, y los dos llamadores filtran con él:
  `InsightsCalculator` (`alignedPrevInterval.contains($0.date)`, hero de Tendencias) y `HeroBucketsCalculator`
  (`prevInterval.contains(tx.date)`, hero del Panel).
- `DateAlignmentHelperTests.alignedPreviousInterval_thisMonthMidMonth_trunca` afirma `end == jun 7 00:00` y comprueba
  `!contains(jun 7 00:01)`: el minuto de después, justo no la medianoche. El borde está sin fijar.
- Es la trampa de `CLAUDE.md` («Cálculos con fechas»): el `end` que coincide con el `start` del día siguiente se cuenta
  en los dos lados.

## Qué hacer

Restar 1 s al `end` del helper cuando no es el clamp (como hace ya `FullFinancialContextBuilder.lastMonthToDateInterval`,
que lo corrige en local por no tocar los heros en su encargo), o filtrar con `< end` en los dos llamadores. Test con la
transacción a medianoche exacta del día siguiente, en los dos heros. Revisar el `DateIntervalDayCount` de quien cuente
días sobre ese intervalo.
