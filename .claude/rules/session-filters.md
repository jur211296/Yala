---
description: Los filtros de SessionState son conjuntos compartidos por cuatro pantallas. Cómo leerlos sin que dos pantallas den números distintos.
paths:
  - "Yala/App/Models/SessionState.swift"
  - "Yala/App/ViewModels/PanelViewModel.swift"
  - "Yala/App/ViewModels/StatisticsViewModel.swift"
  - "Yala/App/ViewModels/RecordsViewModel.swift"
  - "Yala/App/ViewModels/FinancialReportViewModel.swift"
  - "Yala/App/Logic/Calculators/**"
  - "Yala/App/Views/Panel/**"
  - "Yala/App/Views/Records/RecordsFiltersView.swift"
  - "Yala/App/Views/Statistics/CategoriesTabView.swift"
  - "Yala/App/Views/Filters/**"
  - "Yala/Services/FilterService.swift"
  - "Yala/App/Logic/EntityFilter.swift"
  - "Yala/App/Views/ExportWizard/**"
  - "Yala/Utils/TransactionsExportService.swift"
---
# Filtros de sesión

`SessionState.shared` es **estado global compartido** por Panel, Estadísticas, Registros e
Informes. Sus filtros de entidad (`selectedAccountIDs`, `selectedCategoryIDs`,
`selectedSubcategoryIDs`, `selectedNeeds`, `selectedTags`, `selectedCurrencies`) son `Set`, no
opcionales.

## No colapses un conjunto a `.first` para calcular

`Set.first` **no es estable**: con dos elementos devuelve uno arbitrario, y puede cambiar entre
dos lecturas del mismo conjunto. Un cálculo que lo use da un número que ni el usuario ni tú
podéis predecir.

Costó el bug del 2026-09-07: el Panel exponía
`var selectedAccountID { SessionState.shared.selectedAccountIDs.first }` y lo consumía en el filtro
de elegibilidad y en el saldo grande. Con las cuentas A=10.000 y B=5.000 seleccionadas, el Panel
mostraba 10.000 y Distribución 15.000 — y cuál de las dos enseñaba el Panel no era determinista.

**Un accessor singular sobre un `Set` es legítimo solo para acciones que son de un elemento por
diseño** (el tap del carrusel, un prefill de formulario, limpiar el filtro). Para filtrar o sumar,
lee el conjunto.

**Y para PINTAR también (2026-11-04, card 2y7e).** El Panel exponía `selectedNeed = selectedNeeds.first`: el cálculo
usaba las dos necesidades filtradas desde Registros, pero el chip y el widget de necesidades enseñaban una, y
Estadísticas la copiaba a un `@State` que con dos no se actualizaba. Ya no hay accessor singular de necesidades: un chip
por valor y el widget resalta y suma todas (`NeedSelectionLogic`). Lo fija `PanelNeedsSetViewModelTests`.

## «Es single-select» es una propiedad del escritor, no del estado

`SessionState.toggleAccountFilter` y `toggleCategoryFilter` hacen `removeAll()` antes de insertar,
así que *por ese camino* nunca hay dos. Eso no acota el estado: **no son los únicos escritores**.

- `RecordsFiltersView.accountChip` hace `insert` sin `removeAll` → multi-select real.
- `RecordsFiltersView.commitToViewModel` vuelca el conjunto entero a la clave global.
- `SessionState.applyBudgetFilters` escribe el conjunto resuelto de un presupuesto.

Antes de asumir «aquí solo puede haber uno», busca **todos** los escritores de esa clave. La
comprobación cuesta un grep y el bug de arriba vivió porque nadie la hizo.

## Incluidos y excluidos viajan juntos

Desde el 2026-10-25 (opción B de Jürgen, ticket `stats-filter-segment-tap-should-ask-include-or-exclude`) cada
dimensión tiene **dos** conjuntos: los `selected*` son los INCLUIDOS («Solo X») y los `excluded*` los EXCLUIDOS
(«Sin X»), en `SessionState`, en `FilterCriteria` y en `Filterable`. Ya no hay modo global (`isExcludeMode` se borró):
«Solo Comida» y «Sin Uber» conviven. La regla de coincidencia es UNA, `EntityFilter.matches`: si hay incluidos, el id
tiene que estar; nunca puede estar en excluidos. Un mismo id no puede estar en los dos conjuntos: `SessionState` lo
saca del otro al escribirlo (el último gana; `performBatchFilterUpdate` lo apaga mientras la hoja de Registros vuelca
las dos listas, ya disjuntas).

- **Un conjunto sin su gemelo pierde la mitad del filtro.** Al construir un `FilterCriteria` a mano pasa los `excluded*`
  (o usa `SessionState.applyEntityFilters(to:)`), y las etiquetas con `populateTagUUIDs(fromCatalog:)`, que rellena las
  dos listas; `populateTagUUIDs(from:)` solo rellena las incluidas. Un calculador recibe el `EntityFilter` o los dos
  conjuntos, nunca uno solo. `LiveBalanceCalculator` toma `selectedAccountIDs` y `excludedAccountIDs`.
- **«Hay filtro de cuentas» para el interruptor de Grupos cuenta solo las INCLUIDAS** (`hasAccountFilter`): «todas menos
  éstas» sigue siendo un agregado. Igual que hacía el modo excluir.
- **En las tartas y tops, lo incluido de categoría/subcategoría atenúa y lo excluido sale de los datos**, en el Panel
  (`buildPieContextTransactions`) y en Distribución (`calculateData`), período actual y anterior igual. Los widgets ya
  no conocen ningún modo: reciben los datos sin lo oculto.
- **Tocar un segmento pregunta** «Ver solo X / Ocultar X» (`SegmentFilterChoiceSheet`, host `.segmentFilterChoiceHost()`
  en Distribución y en el Panel) **solo si hay algo oculto** en alguna dimensión (`hasExcludedFilters`; Jürgen,
  2026-10-26). Sin nada oculto el toque no pregunta: ve solo lo tocado, o quita el filtro si ya se veía solo
  (`SegmentFilterChoiceLogic.directAction`). Un gesto nuevo que escriba el filtro pasa por ese host, no por un toggle
  propio: así hereda las dos ramas.
- **Los filtros de sesión no se guardan en disco** (medido el 2026-10-25): no hay migración de estado. El asistente de
  Exportar conserva su propio «Mostrar solo / Ocultar» local, a propósito.
- **Borrar un valor lo quita del filtro** (2026-10-28): categorías, subcategorías y etiquetas pasan por
  `SessionState.forgetDeletedFilterValues` en los borrados de la persona (`EntityDeletionService` y la lista de Categorías
  de Ajustes), como las cuentas. Un borrador nuevo pasa por ahí; lo que borra otro dispositivo o el deduplicador deja el id.
- **Una línea suelta oculta con su tarjeta en «Solo» NO existe**: la normalización de `selectedAccountIDs` la vuelve a
  meter. Hoy ningún gesto la ofrece (ningún segmento crea `.account`; la hoja no ofrece líneas de una tarjeta elegida).
  Quien abra ese gesto arregla antes `AccountCardLogic.normalizedSelection` Y el volcado en bloque de la hoja, que
  normaliza las cuentas con la otra lista todavía vieja (ticket `combined-filters-edge-cases-after-option-b`, borde 3).

La paridad de pantallas con los dos tipos a la vez la fija `CombinedFiltersScreenParityTests`; la de las tartas del Panel
con Registros en moneda y monto, `PanelPiesFilterParityTests`.

## El monto: sin signo y en UNA moneda

- **Compara el importe sin signo**, en la moneda del registro: `AmountFilterCondition.matches(signedAmount:)`, que usan
  `FilterService`, las tartas del Panel y Exportar. Con signo, «Mayor a 100» deja fuera todos los gastos.
- **Solo vale con una moneda a la vista** (`RecordsAmountFilterCurrencyLogic`). La hoja aplica el monto con su moneda
  (`SessionState.applyAmountFilter`) y `revalidateAmountCurrency` lo VACÍA si deja de ser la única a la vista, lo cambie
  quien lo cambie: las dos listas de monedas, el fin de `performBatchFilterUpdate` e `incrementDataVersion` (el primer
  registro en una moneda nueva). Las monedas con registros salen de `CurrenciesWithRecords`, la misma cuenta que la hoja:
  si divergen, la guarda vacía el monto que la hoja acaba de aplicar. **Un escritor nuevo de un monto activo pasa por
  `applyAmountFilter`**: sin moneda apuntada la guarda no lo toca.

## Las dos pantallas resuelven la elegibilidad igual

`PanelViewModel.computeEligibleAccounts` y `StatisticsViewModel.computeEligibleAccounts` deben
seguir siendo la misma regla:

```swift
guard account.keepsHistory else { return false }
return EntityFilter(included: selectedAccountIDs, excluded: excludedAccountIDs)
    .matches(account.persistentModelID)
```

Es la regla del HISTORIAL (ingresos y gastos): una cuenta archivada entra. El saldo la deja fuera en sus piezas base
(sección «Archivar saca del saldo…», abajo).

Si tocas una, toca la otra. `BalanceKPIParityTests` fija la paridad y falla si divergen.

**Una selección que no resuelve a ninguna cuenta contable da 0 en las dos** —p. ej. la única elegida está excluida de
estadísticas—. Hasta el 2026-10-23 el Panel hacía **fallback al total agregado** (herencia de
`BalanceHelper.displayedBalance`) y su saldo grande contradecía a sus propios widgets; decisión A de Jürgen del
2026-10-08, ticket `saldo-con-seleccion-no-contable-diverge-entre-panel-y-estadisticas`. Lo fija
`liveBalance_selectedAccountIDExcluded_isZero_likeStatistics`. **No devuelvas un fallback** sin reabrir esa decisión.

**Borrar una cuenta la quita del filtro** (`EntityDeletionService.deleteAccount` → `SessionState.forgetDeletedAccount`).
Un borrador de cuentas nuevo pasa por ese embudo: un ID que sobrevive a su cuenta deja el Panel en 0 sin chip que lo
explique. Lo que NO cubre: una cuenta que borra OTRO dispositivo y llega por sync deja su ID en la sesión hasta que
cambie el filtro.

## Archivar saca del saldo y conserva el historial: dos preguntas, `AccountScopeLogic`

Decisión de Jürgen (opción A del 2026-10-08, adelantada a 2.3 en la decisión 6 del 2026-11-09; sustituye a la del
2026-10-03, «archivar solo enciende Excluir»). Una cuenta contesta DOS preguntas, y cada pantalla hace la suya:

- **¿Suma en un saldo?** `Account.sumsInBalance`: ni excluida ni archivada por la persona. La leen las piezas base del saldo, así que
  lo heredan todos sus consumidores: `LiveBalanceCalculator` (sus cuentas contables y `entersBalance`, la regla de filas
  de la curva y el saldo de período del widget), la curva de saldo (`TrendDataProcessor.fillBalanceBuckets`), el
  «en N cuentas» (`PanelTotalAccountsLogic.countableAccounts`) y las cuentas del saldo del Panel
  (`PanelBalanceScopeLogic.accounts`: cifra, curva, hoja «¿Cuánto tienes hoy?» y proyección). Las piezas que ya reciben
  filas filtradas por historial quitan solo `isArchivedByThePerson` (la curva, la proyección del saldo de Estadísticas
  con sus pagos planificados y la del widget).
- **¿Se ven sus movimientos?** `Account.keepsHistory`: archivada siempre; activa, si no está excluida. Registros, la
  elegibilidad del Panel y de Estadísticas (ingresos y gastos de cualquier período), `FilterService.filterForTrends`,
  el día más caro, los widgets, Spotlight, Yala IA y el aviso de informe.

Cinco cosas que no se tocan sin reabrirlo:

- **Archivar no toca «Excluir»**, ni en el formulario ni en las líneas de la tarjeta (`AccountLineService.archiveLines`
  ya no tiene ese parámetro). Con la cuenta archivada el formulario no enseña «Excluir» (no haría nada) y el aviso dice
  lo que pasa (`account.archiveKeepsHistoryNotice`).
- **Una archivada con «Excluir» encendido enseña su historial sin tocar el dato.** Lo dejaba así archivar desde el
  formulario entre el 2026-10-03 y esta decisión, también en la 2.1 publicada, y no se distingue de quien excluyó a mano
  y luego archivó: los dos ven el historial. Al desarchivar, el flag guardado vuelve a mandar (como antes: desarchivar
  nunca re-incluyó). No hay migración. Las archivadas sin excluir —el downgrade de plan, las de antes del 2026-10-03, las
  que la persona volvió a incluir— **dejan de sumar en el saldo**: es la opción A («archivada deja de sumar por sí
  sola»), y su historial sigue.
- **Las cuentas sistema de Grupos que archiva la propia app siguen sumando** (`GroupBridgeSystemEntities` archiva las
  duplicadas tras una carrera entre dispositivos y conservan sus movimientos): no son un archivado de la persona. El
  «en N cuentas» las deja fuera, como siempre (`countableAccounts`).
- **Un consumidor nuevo elige su pregunta**, no lee `excludeFromStatistics` a pelo: con el flag solo, o la archivada
  suma en un saldo o su historial desaparece. Si calcula un saldo con piezas propias, filtra por `sumsInBalance`; si es
  un flujo, por `keepsHistory`. El saldo de UNA cuenta (`AccountBalanceCalculator`: su ficha, Ajustes › Cuentas) no es
  un agregado y sigue con todas.
- **Yala IA y el conector de Claude siguen la misma regla**: `FullFinancialContextBuilder` cuenta los movimientos por
  `keepsHistory`, lista como excluidas solo las que ocultan su historial y suma el saldo con `countableAccounts`;
  `mcp/` lo porta (`balances.ts`, `summary.ts`). `MCPAppParityGoldenTests` ata los dos: si cambias la regla en uno,
  regenera el golden y cambia el otro. Archivar sigue escondiendo la cuenta de listas y selectores, de `listar_cuentas`
  del conector y del carrusel.

Lo fijan `ArchivedAccountKeepsHistoryTests` (las cuatro combinaciones de los dos flags en Registros, Estadísticas, el
saldo del Panel y de Distribución) y el XCUITest `ArchivedAccountKeepsHistoryUITests`.

## El toggle `includeGroupsInPanelTotal` es del total agregado

`PanelTotalAccountsLogic.accountsForTotal(hasSelectedAccount:)` recorta las cuentas sistema de
grupos **solo cuando no hay filtro de cuentas**. `hasSelectedAccount` se calcula
`!selectedAccountIDs.isEmpty` — una cuenta o cinco es igual de «hay filtro».

**Yala IA lo sigue desde el 2026-10-09** (decisión A de Jürgen): `FullFinancialContextBuilder` recibe el ajuste
inyectado (`includeGroupsInTotal`, desde `ChatSheetView` → `ChatAssistantViewModel.setAppPreferences`) y suma con
`accountsForTotal`; las cuentas de Grupos siguen en `balances.accounts` y `balances.total_includes_groups` lo dice.
**El conector `mcp/` no**: no conoce las preferencias del teléfono y suma siempre las cuentas de Grupos (`mcp/src/logic/balances.ts`). Un consumidor nuevo del contexto
pasa el ajuste; el default `true` de `buildFromArrays` es para tests y el golden.

**El interruptor de Estadísticas (`includeGroupTransactionsInStats`) también lo recibe, desde el 2026-10-12**:
`ChatAssistantService.runAskFlow` lo lee como las sugerencias (clave de `UserDefaults`, default ON) y el builder
aplica `BridgedTransactionFilter` una vez, a todo lo que suma movimientos menos **presupuestos** (su pantalla mira el
«incluir gastos compartidos» de cada uno) y **saldos** (montos reales). El conector `mcp/` tampoco lo conoce.

## La UI tiene que decir lo mismo que el número

Si el saldo suma N cuentas, el carrusel marca esas N y el chip dice cuántas son. Un carrusel que
marca una tarjeta sobre un saldo que suma dos es el mismo bug, en la capa de al lado: para el
usuario, la pantalla se contradice.
