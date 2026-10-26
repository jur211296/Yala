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
  en Distribución y en el Panel). Un gesto nuevo que escriba el filtro pasa por ahí, no por un toggle propio.
- **Los filtros de sesión no se guardan en disco** (medido el 2026-10-25): no hay migración de estado. El asistente de
  Exportar conserva su propio «Mostrar solo / Ocultar» local, a propósito.

La paridad de pantallas con los dos tipos a la vez la fija `CombinedFiltersScreenParityTests`.

## Las dos pantallas resuelven la elegibilidad igual

`PanelViewModel.computeEligibleAccounts` y `StatisticsViewModel.computeEligibleAccounts` deben
seguir siendo la misma regla:

```swift
guard !account.excludeFromStatistics else { return false }
return EntityFilter(included: selectedAccountIDs, excluded: excludedAccountIDs)
    .matches(account.persistentModelID)
```

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

## Archivar no decide la suma: la decide «Excluir de las estadísticas»

Decisión de Jürgen (2026-10-03): una cuenta suma o no según `excludeFromStatistics`, nunca según
`isArchived`. Archivar desde el formulario de cuenta solo **enciende** ese toggle y lo avisa
(`AccountFormViewModel.setArchived`); el usuario puede volver a incluirla a mano. Por eso:

- **Excluir no es solo «no suma»: también oculta sus movimientos en Registros** (`RecordsViewModel`
  descarta las transacciones de cuentas excluidas). Un aviso que hable de excluir tiene que decirlo.
- **Desarchivar no re-incluye.** Solo se deshace la auto-exclusión si el usuario desarchiva en la
  misma edición en que archivó y no tocó el toggle entre medias.
- **Un conteo de «cuentas que suman» filtra por el toggle, no por archivada**
  (`PanelTotalAccountsLogic.countableAccounts`, el «en N cuentas» del panorama), salvo las cuentas
  sistema de Grupos que archiva la propia app. Archivar sigue escondiendo la cuenta de listas y
  selectores; eso no cambia.
- **Yala IA y el conector de Claude siguen la misma regla desde el 2026-10-09**: el contexto del chat
  (`FullFinancialContextBuilder`) suma por el toggle y lista las cuentas de `countableAccounts`, y `mcp/` lo porta
  (`balances.ts`, `summary.ts`). `MCPAppParityGoldenTests` ata los dos: si cambias la regla en uno, regenera el golden
  y cambia el otro. Archivar sigue escondiendo la cuenta de `listar_cuentas` del conector, como de las listas de la app.
- **Dos sitios archivan SIN excluir, a propósito**: el downgrade de plan
  (`DowngradeResolutionSheet.archiveExcessItems`; excluir ahí ocultaría el historial y nada lo
  re-incluye al volver a Pro, decisión pendiente de Jürgen) y `GroupBridgeSystemEntities` (cuentas
  sistema, que se desarchivan solas). Igual que las cuentas archivadas antes del 2026-10-03, que no
  se migraron: si no están excluidas, siguen sumando y contando, coherentes entre sí.

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
