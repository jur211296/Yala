---
id: groups-in-group-search
status: backlog
priority: medium
area: groups
created: 2026-07-01
updated: 2026-08-26
source: YalaWiki/Backlog/groups-busqueda-interna.md
---


# Búsqueda dentro de un grupo (descripción, monto, miembro, categoría)

## Problema

La búsqueda de Grupos hoy es **solo por nombre de grupo**, en la lista de grupos (`GroupsContainerView`). Una vez dentro de un grupo con muchos gastos (ej. un viaje largo, un grupo de gastos compartidos de casa con meses de historial), no hay forma de buscar un gasto específico por descripción, monto, quién pagó, o categoría — hay que scrollear toda la lista agrupada por fecha.

## Solución

Añadir un `.searchable()` sobre `GroupRecordsView`/`GroupDetailView`, replicando el patrón de filtrado en memoria que ya usa `GlobalSearchView` para transacciones personales, adaptado a `SplitExpense`.

## Por qué es Tier 1 (bajo riesgo)

No toca el schema CloudKit — es un filtro puramente en memoria sobre datos que `GroupDetailViewModel` **ya tiene cargados** como arrays (no requiere ningún fetch nuevo, ni tocar `SplitExpense`/`SplitGroup`/etc.).

## Estado actual confirmado en el código (2026-07-01)

**Confirmado: la búsqueda de grupos es solo por nombre**, en `GroupsViewModel.swift:75-80`:
```swift
var filteredGroups: [SplitGroup] {
    let base = activeGroups
    guard !searchText.isEmpty else { return base }
    let query = searchText.lowercased()
    return base.filter { $0.name.lowercased().contains(query) }
}
```
Alimentado por `.searchable(text: $viewModel.searchText, ...)` en `GroupsContainerView.swift:103-107`. Esto filtra la **lista de grupos**, no el contenido de un grupo abierto.

**`GroupRecordsView.swift` no tiene ningún filtro hoy** — solo agrupa por fecha (`groupedByDate`, líneas 271-285). No importa ni referencia `FilterControlBar` ni ningún componente de filtro-por-chips. No hay infraestructura de filtro en el subsistema de Grupos más allá de la búsqueda por nombre de la lista.

**El patrón de referencia (`GlobalSearchView.swift`) es directamente portable**: es un `.filter { }` en memoria con `.lowercased().contains()` — sin `#Predicate` ni SwiftData query-level filtering. Matchea `note`, `category?.name`, `subcategory?.name`, `account?.name`, y tags (vía `tagCatalog`), sobre un array ya materializado por `@Query`. **No matchea monto** (dato a considerar si se replica).

**`GroupDetailViewModel.loadData()` ya carga en memoria todo lo necesario, sin fetches nuevos**: `expenses: [SplitExpense]`, `shares: [SplitShare]`, `memberNameLookup: [String: String]`, `txBridgeMap: [String: TransactionItem]` (subcategoría real vía bridge, cuando existe), `mySharesByExpense: [UUID: SplitShare]`, `currentMemberID: String?` — todo pasado como props `let` inmutables a `GroupRecordsView`. El mismo patrón `.filter{}` de `GlobalSearchView` aplicaría idéntico sobre `expenses`.

**Modelo `SplitExpense` — campos disponibles para matchear** (`Yala/Models/SplitExpense.swift`):
- `expenseDescription: String` (nunca nil, default `""`) — es el título mostrado en la fila. Existe también `note: String?` pero **no se renderiza hoy** en `GroupRecordsView` (solo se muestra `expenseDescription`).
- `amount: Double` + `currencyCode: String`
- `date: Date`
- `paidByMemberID: String` (String plano, uuidString de `SplitMember.id` — se resuelve vía `memberNameLookup`, NO es una relación `@Relationship`)
- **Sin campo de categoría/subcategoría directo** — solo `subcategoryName: String?` (texto libre capturado al crear, usado para auto-match del bridge). La subcategoría *real* con icono/color visible en el feed viene del bridge (`txBridgeMap[expense.id.uuidString]?.subcategory`) — **no todos los expenses la tienen** (solo si el auto-match del bridge tuvo éxito, y es per-usuario: cada miembro puede tener su propia subcategoría personal para el mismo gasto de grupo, o ninguna).

**No existe `FilterCriteria` para grupos** — el `FilterCriteria` de `FilterService.swift` es exclusivo de `TransactionItem` (usa `PersistentIdentifier`/`selectedTagUUIDs` que no aplican a `SplitExpense`, que no tiene `@Relationship`). Habría que construir un struct/helper nuevo — pero el approach `.filter{}` en memoria es directamente portable sin necesitar ese struct completo.

**No existe un `SearchLogic.swift` pure-logic** — el matching de `GlobalSearchView` vive inline en la vista como métodos privados. Dado que el proyecto ya tiene el patrón de helpers pure-logic testeables en `Yala/App/Logic/` (`RecordsMotivationalLogic`, `FilterControlBarLogic`, etc.), esta sería la oportunidad de extraer un helper nuevo (`GroupExpenseSearchLogic.swift`) en vez de replicar el antipatrón inline — más testeable, sin necesidad de `makeTestContext()`.

## Plan técnico

### Servicios/vistas existentes a reutilizar

| Archivo | Qué aporta |
|---|---|
| `GlobalSearchView.swift` (líneas 86-108, `matchesSearch`) | Patrón de matching a replicar — filtro en memoria, sin debounce explícito (usa `.searchable()` nativo reactivo) |
| `GroupDetailViewModel` | Ya carga `expenses`/`shares`/`memberNameLookup`/`txBridgeMap` en memoria — sin fetch nuevo necesario |
| `GroupRecordsView` | Punto de inserción del `.searchable()` — hoy sin ningún filtro |

### Qué falta construir

1. **Helper pure-logic nuevo** (`Yala/App/Logic/GroupExpenseSearchLogic.swift` o similar) con una función `matches(expense:, query:, memberNameLookup:, txBridgeMap:) -> Bool` — testeable sin SwiftData ni contexto (evita el flake R8 de `makeTestContext()`).
2. **Campos a matchear** (decisión de producto, ver Notas): mínimo viable = `expenseDescription` + nombre del pagador (vía `memberNameLookup`) + monto formateado como string. Opcional = subcategoría vía `txBridgeMap` (con el caveat de que no todos los expenses la tienen).
3. **`@State searchText` + `.searchable()`** en `GroupDetailView` o `GroupRecordsView` (hoy inexistente en ese árbol de vistas).
4. **Decisión de scope**: ¿la búsqueda vive en `GroupRecordsView` (solo la tab de registros del detalle) o en todo `GroupDetailView` (incluyendo balances/stats)? Recomendado: solo Records, análogo a cómo `GlobalSearchView` es una vista dedicada, no parte de otra.

## Acceptance Criteria

- [ ] `GroupRecordsView` (o `GroupDetailView`) tiene un `.searchable()` que filtra los gastos mostrados por descripción, monto, y nombre de quien pagó.
- [ ] La búsqueda opera sobre los datos ya cargados en memoria — sin ningún fetch nuevo a SwiftData ni a CloudKit.
- [ ] Comportamiento consistente con `GlobalSearchView`: case-insensitive, `contains` (no exact match).
- [ ] Empty state claro cuando la búsqueda no encuentra resultados (distinto del empty state de "grupo sin gastos").
- [ ] Si se extrae un helper pure-logic, tiene tests unitarios sin `ModelContext`.

## Notas

- **Monto como texto a matchear**: decidir si se busca por el monto formateado (ej. usuario escribe "120" y matchea "S/ 120.00") o se omite en v1 — `GlobalSearchView` NO matchea monto hoy, así que omitirlo en v1 mantiene paridad con el patrón de referencia; añadirlo sería una mejora sobre el propio `GlobalSearchView` a considerar para ambos a la vez.
- **Categoría/subcategoría vía bridge es inconsistente entre miembros** (per-usuario, no siempre poblada) — si se incluye en el matching, documentar que dos miembros del mismo grupo podrían obtener resultados de búsqueda distintos para el mismo gasto según si SU bridge personal tiene la subcategoría resuelta. Puede ser aceptable, pero vale la pena decidirlo consciente, no por accidente.

migrated from YalaWiki Backlog/groups-busqueda-interna.md @ 1934e8ad
