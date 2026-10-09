---
id: distribution-sankey-recomputes-on-every-render-with-all-time
status: backlog
priority: low
area: statistics
created: 2026-10-09
updated: 2026-10-09
source: hallazgo de el-saldo-de-distribucion-no-se-entera-de-un-registro-nuevo (medición de veces por gesto)
---

# Con «Todo el tiempo», el Sankey de Distribución se recalcula en cada repintado

## Qué se midió

Con contadores temporales en `CategoriesTabView` (simulador, iPhone 17 Pro, iOS 27.0, seed `minimal`, 26
movimientos), registrar un movimiento desde Distribución:

| Período | `recomputeSankey()` durante el alta |
|---|---|
| Todo el tiempo | 6 |
| Este mes | 1 |

Con «Todo el tiempo» el Sankey se recalculaba también mientras se escribía en el formulario, sin ningún dato nuevo.

## Causa probable (inferida, no instrumentada)

`DetailPeriod.dateInterval` para `.allTime` empieza en `now − 10 años` (`SharedModels.swift:248-251`), no en el
inicio de un día. `StatisticsViewModel.sankeyInputKey` incluye `panelDateInterval`, así que la clave cambia en cada
evaluación del body y `.onChange(of: viewModel.sankeyInputKey)` recalcula en cada repintado. `.custom` sin rango
(`end: now`) tiene la misma forma.

Con 26 movimientos no se nota. Con miles, cada repintado de la pestaña paga el Sankey entero.

## Qué mirar

Anclar el inicio de `.allTime` a `startOfToday` (o al inicio del día de hace 10 años) quitaría la deriva. Antes,
comprobar quién más lee ese intervalo: hay tests de fechas y paridades con el widget
(`WidgetDataService` replica `dateInterval`).

## Acceptance Criteria

- [ ] Con «Todo el tiempo», el Sankey se recalcula solo cuando cambian filtros o datos (medido).
