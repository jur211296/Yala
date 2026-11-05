---
id: statistics-and-records-filter-onchange-may-fall-asleep-like-the-panel
status: backlog
priority: low
area: "statistics, records"
created: 2026-11-05
updated: 2026-11-05
source: hallazgo del lote P3 de 2.3 (ticket panel-stayed-filtered-after-removing-the-account-chip)
---

# Estadísticas y Registros recalculan por filtros con `onChange`, el mismo patrón que dejó el Panel filtrado

## Qué se midió en el Panel (2026-11-05)

Con un conductor XCUITest de 10 rondas (filtrar por una cuenta desde su menú y quitar el chip, con idas a inicio y
vueltas), 3 de 7 corridas dejaban el Panel con las cifras filtradas y el chip ya quitado: tras volver a primer plano,
SwiftUI dejó de reevaluar el modificador de `onChange` de `PanelShell` cuando cambiaba solo `selectedAccountIDs`. Se
arregló moviendo la observación al ViewModel (`PanelViewModel.observeSessionFilters`).

## Lo que no se midió

`DetailContainerView` (`SessionStateObservers`), `CategoriesTabView`, `TrendsTabView` y `RecordsStandaloneView`
recalculan con `onChange(of: sessionState.…)`, el mismo molde. No se sabe si se duermen igual.

## Hecho cuando

El mismo conductor (en el PR del lote P3 está descrito) adaptado a Distribución y a Registros: si no cae en 5 corridas,
se cierra con esa medida; si cae, se mueve la observación como en el Panel.
