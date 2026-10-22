---
id: panel-lee-el-filtro-de-cuentas-en-singular-fuera-del-saldo
status: backlog
priority: medium
area: panel
created: 2026-09-07
updated: 2026-10-08
source: review adversarial de panel-colapsa-la-seleccion-de-cuentas-a-la-primera
---

# Dos sitios del Panel siguen leyendo el filtro de cuentas como si fuera una

## Qué pasa

`panel-colapsa-la-seleccion-de-cuentas-a-la-primera` puso el **saldo** del Panel a respetar el
conjunto de cuentas. Quedaron dos lecturas fuera de ese objeto que siguen tratándolo como «una o
ninguna». Las dos son **preexistentes** —no las introdujo aquel cambio— y las dos son visibles.

### 1. El subtítulo del panorama cuenta cuentas que no suma

`Yala/App/Views/Panel/Sections/PanelPanoramaSection.swift` · `totalAccountsCount`

Pasa `hasSelectedAccount: true` a `PanelTotalAccountsLogic.accountsForTotal`, cuyo primer statement
es `guard !hasSelectedAccount, !includeGroups else { return accounts }`: con cualquier filtro activo
devuelve **todas** las cuentas activas. El saldo, en cambio, sí filtra.

Con 5 cuentas activas y dos filtradas, el subtítulo dice **«Tienes S/ ⟨A+B⟩ en 5 cuentas»**. Pasaba
igual antes con una cuenta filtrada (`selectedAccountID != nil` y `!selectedAccountIDs.isEmpty` son
el mismo booleano), así que no es una regresión — es el mismo defecto que el ticket madre atacaba,
en la línea de al lado.

### 2. El prefill del formulario precarga una cuenta arbitraria

`Yala/App/Views/Panel/PanelSheetsModifier.swift:78` — `prefillAccountID: viewModel.selectedAccountID`

Es la única **lectura** en singular que queda, y `selectedAccountID` es `selectedAccountIDs.first`:
inestable.

- Con dos cuentas filtradas, el formulario de nueva transacción llega precargado con una de las dos,
  arbitrariamente, y puede no ser la misma tras relanzar la app.
- **En modo excluir precarga la cuenta que el usuario acaba de excluir**, que es el peor caso
  posible.

## Por qué no se arregló en el ticket madre

El objeto de la decisión de Jürgen (2026-09-06) era el saldo del Panel y su filtro. Estos dos son
consumidores adyacentes, preexistentes, y ninguno empeoró con aquel cambio. Además el (1) no es un
fix mecánico: hay que decidir **por dónde viaja el conteo** para que no pueda volver a divergir del
número —lo natural sería que saliera del mismo cálculo que el saldo, no de una segunda composición
en la vista—, y eso es diseño.

## Qué hay que decidir

- **(1)** ¿El conteo sale de `LiveBalanceCalculator.Breakdown` (un campo nuevo, mismo cálculo que el
  número, imposible que diverjan) o de una función pura al lado de `accountsForTotal` que la vista
  compone? Lo primero es más robusto y toca el ViewModel; lo segundo es más barato y deja dos sitios
  donde la regla puede separarse.
- **(2)** El prefill con `count != 1` debería ser `nil`, y en `isExcludeMode` siempre `nil`. ¿O se
  prefiere prefill estable «la primera por nombre» en vez de ninguna?

## Acceptance Criteria

- [ ] El subtítulo del panorama nombra el número de cuentas que realmente suman el saldo mostrado,
      con filtro de una, de varias y en modo excluir.
- [ ] El prefill del formulario no propone una cuenta arbitraria, y nunca una excluida.
- [ ] Unit del conteo con las tres formas de filtro.
- [ ] Device-QA: 5 cuentas, filtrar 2, leer el subtítulo; y abrir «+» en modo excluir.

## Medido en 2.1 (triage 2026-10-08)

- (1) Sigue. `PanelPanoramaSection.totalAccountsCount` (`:66-75`) pasa `hasAccountFilter(...)` a `accountsForTotal`. Con cualquier filtro en modo incluir, el `guard` de `PanelTotalAccountsLogic.swift:40` devuelve todas las cuentas que cuentan. b8a371f9d (archivar = excluir de estadísticas) cambió qué cuentas cuentan, pero no esto.
- (2) Sigue. `PanelSheetsModifier.swift:93` pasa `prefillAccountID: viewModel.selectedAccountID`, que es `selectedAccountIDs.first` (`PanelViewModel.swift:331-332`), también en modo excluir.

## Pregunta para Jürgen (triage 2026-10-08)

Sobre el (2), cuando hay más de una cuenta filtrada o se está en modo excluir:

- **A** (recomendada): el formulario abre sin cuenta precargada. Nunca propone una cuenta excluida.
- **B**: precarga la primera por nombre de las incluidas.
- **C**: precarga la última cuenta usada.

Con A, la prioridad es `medium`. El (1) es técnico, y lo natural es que el conteo salga del mismo `Breakdown` que el saldo.

Triage 2026-10-08: abierto · medium → medium · el conteo de `PanelPanoramaSection.totalAccountsCount` ignora el filtro, y `PanelSheetsModifier.swift:93` precarga `selectedAccountIDs.first`, también en modo excluir.
