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

## `isExcludeMode` viaja con el conjunto

El conjunto no significa nada sin el modo: los mismos IDs significan «solo estas» o «todas menos
estas». Una función que recibe el conjunto y no el modo **invierte el filtro** en cuanto el usuario
activa «excluir» — que se activa desde Registros → Filtros junto con las cuentas, en el mismo
commit.

Al pasar un filtro de entidad a un calculador, pasa los dos. `LiveBalanceCalculator` los toma
juntos por esto.

## Las dos pantallas resuelven la elegibilidad igual

`PanelViewModel.computeEligibleAccounts` y `StatisticsViewModel.computeEligibleAccounts` deben
seguir siendo la misma regla:

```swift
guard !account.excludeFromStatistics else { return false }
if selectedAccountIDs.isEmpty { return true }
return isExcludeMode
    ? !selectedAccountIDs.contains(account.persistentModelID)
    : selectedAccountIDs.contains(account.persistentModelID)
```

Si tocas una, toca la otra. `BalanceKPIParityTests` fija la paridad y falla si divergen.

**Divergencia conocida y viva** (no la «arregles» sin decidirlo): cuando la selección no resuelve a
ninguna cuenta contable —p. ej. la única elegida está excluida de estadísticas— el Panel hace
**fallback al total agregado** y Estadísticas devuelve **0**. Es comportamiento heredado de
`BalanceHelper.displayedBalance`, fijado por
`liveBalance_selectedAccountIDExcluded_fallsBackToTotal`. Ticket:
`saldo-con-seleccion-no-contable-diverge-entre-panel-y-estadisticas`.

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

## La UI tiene que decir lo mismo que el número

Si el saldo suma N cuentas, el carrusel marca esas N y el chip dice cuántas son. Un carrusel que
marca una tarjeta sobre un saldo que suma dos es el mismo bug, en la capa de al lado: para el
usuario, la pantalla se contradice.
