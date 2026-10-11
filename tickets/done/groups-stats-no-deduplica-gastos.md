---
id: groups-stats-no-deduplica-gastos
status: qa
priority: medium
area: "groups, stats"
created: 2026-09-07
updated: 2026-10-08
qa-status: needs-testing
source: hallazgo de la review adversarial de groups-budget (2026-09-07)
---

# Estadísticas del grupo no deduplica los gastos, y ahora se contradice con la barra de presupuesto

## Qué ve el usuario

Dos números distintos para lo mismo, en la misma pantalla y a un tap de distancia. En un grupo con un
gasto duplicado de S/ 400 y un presupuesto de S/ 3.000:

- pestaña **Registros** → «S/ 2.100 de S/ 3.000»
- pestaña **Estadísticas** → «Total gastado: S/ 2.500»

La que está mal es la de Estadísticas.

## Por qué pasa

`GroupStatsViewModel.periodExpenses` agrupa y suma sobre `GroupDetailViewModel.expenses` **tal cual**,
sin deduplicar por `id`. Todos sus vecinos sí lo hacen, con el mismo molde
(`Dictionary(grouping:by:\.id).values.compactMap(\.first)`):

| | dedup por `id` | excluye `isOpeningBalance` |
|---|---|---|
| `GroupBalanceService.calculateBalances` | sí | no (usa otro filtro) |
| `GroupShareableSummaryLogic` | sí | sí |
| `GroupBudgetLogic.progress` (nuevo) | sí | sí |
| **`GroupStatsViewModel.periodExpenses`** | **NO** | sí |

Los duplicados llegan por merges del canal de sync; es la misma premisa que justifica el dedup en los
otros tres, y está escrita en `GroupBalanceService`.

## Por qué se abre AHORA si es preexistente

Porque hasta ahora nadie ponía las dos cifras a la vista a la vez. Con la barra de presupuesto en
Registros, el mismo grupo enseña dos totales que se contradicen — y eso deja de ser deuda silenciosa
para convertirse en algo que un usuario reporta.

## Qué hacer

Deduplicar en `GroupStatsViewModel.periodExpenses`, con el mismo molde que los otros tres, y un test que
muera si se revierte (el de `GroupBudgetLogicTests.duplicadosPorIdNoInflanElTotal` sirve de plantilla).

**No se hizo en `groups-budget` a propósito**: ese ticket tenía alcance «un límite por grupo», y tocar el
cálculo de otra pantalla es ampliar a otro objeto. Se abre aparte, que es donde se decide con su propio
device-QA.

## Qué cambia para el usuario (2026-10-08)

Estadísticas cuenta cada gasto del grupo una sola vez, aunque el sync lo haya dejado repetido. En un
grupo de una sola moneda, «Total gastado» (período «Todo») y la barra de presupuesto de Registros
enseñan la misma cifra. «Quién paga», el donut de categorías, la tendencia, las tarjetas por moneda y
el selector de monedas salen de la misma lista sin duplicados.

## Qué se hizo

- `GroupStatsViewModel.loadStats` deduplica los gastos por `id` con el molde de los otros tres
  (`Dictionary(grouping:by:\.id).values.compactMap(\.first)`), y después `periodExpenses` quita los
  saldos de apertura: el mismo orden que `GroupBudgetLogic.progress`. No había helper compartido.
- **Se deduplica en `loadStats` y no en `periodExpenses`**, que es lo que decía el ticket: la lista de
  monedas (`availableCurrencies`) se calcula en `loadStats` y no pasa por `periodExpenses`. Deduplicar
  solo ahí habría dejado un selector con una moneda cuyo único gasto es la copia descartada.
- Cinco tests nuevos en `GroupStatsViewModelTests`: total, desgloses en moneda única, modo «Todas»,
  lista de monedas y coincidencia con `GroupBudgetLogic.progress` (con un saldo de apertura y un
  duplicado cuyas copias difieren, para fijar que las dos pantallas se quedan con la misma copia).

## Verificado

- **Control rojo con el código anterior** (823cb3b79): los 5 tests nuevos fallan y los 21 de antes
  pasan. El de coincidencia da Estadísticas 2.630 frente a presupuesto 2.150.
- Con el arreglo: 26/26 en `GroupStatsViewModelTests` + 4/4 en `GroupBudgetLogicExistenceTests`.
- **Mutante «deduplicar solo en `periodExpenses`»**: cae únicamente `monedasSalenDeLaListaDeduplicada`.
- Sin capturas: un gasto duplicado por `id` solo lo produce un merge del sync, y ni la interfaz ni los
  `DevSeed` lo pueden sembrar sin inventar datos.

## Guion de QA en iPhone (opcional; no bloquea)

No se puede forzar un duplicado a mano. Esto comprueba que no se rompió nada:

1. Abre Grupos y entra en un grupo de **una sola moneda** que tenga presupuesto (si no tiene:
   ajustes del grupo → «Presupuesto del grupo» → pon uno, por ejemplo 3.000).
2. En la pestaña **Registros**, apunta la cifra de la barra: «S/ X de S/ 3.000».
3. Ve a **Estadísticas**, elige el período **Todo** y mira **Total gastado**.
4. Esperado: las dos cifras son iguales. Si el grupo tiene saldos de apertura, no cuentan en ninguna.
5. Entra en un grupo con **varias monedas**, modo «Todas»: el carrusel por moneda y el donut se ven
   como antes.

## Fuera de alcance (anotado)

- «Mi parte» suma los repartos (`SplitShare`) sin deduplicarlos por su propio `id`: un reparto
  repetido la dobla. Es el mismo hueco que `group-balance-service-shares-not-deduped`, y allí queda
  anotado.
