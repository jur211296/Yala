---
id: trends-cards-ignore-an-in-place-amount-edit
status: backlog
priority: medium
area: statistics
created: 2026-10-09
updated: 2026-10-09
source: hallazgo de el-saldo-de-distribucion-no-se-entera-de-un-registro-nuevo (punto 3 del encargo)
---

# Tendencias no se entera de que editaste el importe de un movimiento

## Qué ve el usuario

Estás en **Estadísticas → Tendencias** y el importe de un movimiento cambia sin que la pestaña se desmonte: llega
una edición por sync desde otro dispositivo, la haces en otra ventana del iPad, o te la hace el chat de Yala IA con la
hoja abierta encima. El hero se pone al día (lo calcula el contenedor), pero las tarjetas de debajo —Flujo de
efectivo, la comparativa con el período anterior y el gasto por día de la semana— siguen con el número viejo hasta
que tocas un filtro o cambias de pestaña.

## Causa (medida leyendo el código de `2.1`, `f9e693e06`)

`TrendsTabView` precalcula esas tres tarjetas en `@State` propios (`calculateCashFlowData`,
`calculatePeriodComparisonData`, `calculateWeekdayData`). Sus disparadores son de filtro y uno de datos:
`.onChange(of: allTransactions.count)` (`TrendsTabView.swift:188`). Editar un importe deja las mismas filas, así que
ese observador no salta. Es el mismo agujero que tenía Distribución hasta el 2026-10-09.

**Lo que no pasa** (medido en el simulador, iPhone 17 Pro, iOS 27.0): editar desde otra pestaña principal y volver.
Cambiar de pestaña principal remonta Estadísticas y el `onAppear` recalcula. Por eso no se ve en el uso normal de un
iPhone; se ve con la pestaña montada.

## Cómo arreglarlo

El contenedor ya publica la señal: `DetailContainerViewModel.dataGeneration` avanza cuando una recarga trae algo
nuevo (otro `dataVersion` o arrays distintos), una vez por pasada del debounce de 150 ms. Distribución ya cuelga de
ella (`CategoriesTabView`, `recalculateAfterDataReload`). Tendencias puede sustituir su `.count` por ese contador y
pasar por su propio `scheduleTrendsRecalc`. Medir antes y después las veces por gesto, como se hizo en Distribución.

## Acceptance Criteria

- [ ] Editar el importe de un movimiento con Tendencias montada actualiza las tres tarjetas.
- [ ] Un alta las sigue actualizando una vez, no dos.
- [ ] No se recalcula más veces por gesto que ahora (medido).
