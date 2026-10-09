---
id: budget-days-left-counts-today
status: done
priority: low
area: budgets
created: 2026-09-06
updated: 2026-10-09
source: decisión de Jürgen del 2026-09-06 sobre tickets/qa/undercount-dias-intervalos-cerrados.md
---

# Un presupuesto que acaba hoy tiene 1 día por delante, no 0

## Qué le pasa al usuario

El último día de un presupuesto la app le dice «te quedan 0 días» y el promedio diario disponible
divide entre cero o se apaga. Pero hoy todavía es un día entero para gastar.

## Decisión Jürgen (2026-09-06)

**Queda 1: hoy todavía cuenta.** Elegida entre eso y «quedan 0, con copy de "último día"». Motivo, tal como se le puso delante y ratificó: el
último día es un día entero, «te queda 1 día» es lo que cualquiera espera leer, y es coherente con que
los intervalos del repo cierran a 23:59:59 (regla de `CLAUDE.md` sobre `DateInterval`).

## Punto de partida (del ticket de origen, NO re-medido — greppear antes)

`FullFinancialContextBuilder:627` calcula `daysLeft` con `from: now, to: interval.end` y trunca. La
trampa gemela está escrita en `CLAUDE.md`: `dateComponents([.day])` TRUNCA sobre un intervalo que
cierra en 23:59:59 — normalizar (`end.addingTimeInterval(1)`) antes de contar, o contar desde
`startOfDay(now)`.

## Criterio de hecho (AC)

- [ ] Con un presupuesto que termina hoy, `daysLeft` = 1; que termina mañana, 2; que terminó ayer, 0.
- [ ] El promedio diario disponible divide entre ese número y nunca entre cero.
- [ ] Barrido de **todos** los sitios que cuentan «días que quedan» (no solo el citado): mismo
      resultado en todos, fijado por test parametrizado.
- [ ] El copy «te queda 1 día» existe en singular en los 16 `.lproj` (plural/singular correcto).

## Relacionados

- [[undercount-dias-intervalos-cerrados]] — el bug de conteo del que salió, en `qa/`.

## Resolución (2026-10-09)

- [x] `BudgetPeriodInterval.daysLeft` cuenta desde hoy hasta el último día, los dos incluidos: 1 si acaba hoy,
      2 si acaba mañana, 0 si acabó ayer.
- [x] Promedio diario: medido, la app no lo calcula en ningún sitio; lo deriva el modelo del chat de `days_left`,
      que dentro del periodo ya nunca es 0 (test que recorre cada hora de un mes).
- [x] Barrido: Presupuestos y Panel (`summaryDaysRemaining`, que conserva −1 = «Finalizado» y 0 = aún no
      empieza) y el chat pasan por el mismo helper. Test parametrizado con los tres casos en los cuatro sitios.
- [x] Singular: `budgets.days.remaining.one` en los 16 `.lproj`; las tres vistas eligen con
      `L10n.Budgets.daysRemaining(_:)`.

Fuera, a propósito: `HeroMonthCalculator.daysRemaining` (no es de presupuestos y no se pinta) y el conector
`mcp/` (sigue diciendo 0 el último día; divergencia anotada en el PR).
