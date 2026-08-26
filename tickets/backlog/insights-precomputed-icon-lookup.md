---
id: insights-precomputed-icon-lookup
status: backlog
priority: low
area: insights
created: 2026-05-25
updated: 2026-08-26
source: YalaWiki/Backlog/insights-calculator-iconlookup-precomputed.md
---


# InsightsCalculator: pasar iconLookup precomputado para budgets at risk

## Problema

`InsightsCalculator.calculateCommitments` (`Yala/App/Logic/Calculators/InsightsCalculator.swift:578-617`) genera `budgetsAtRisk` para la tab Insights. Para cada budget at risk lee `budget.displayProperties.icon` (línea 609) — el TODO inline en el propio código lo confirma: *"Icon genérico en cold launch si M2M lazy nil — se auto-cura via hot path upstream. Refactor con iconLookup precomputado: ver Backlog."* (líneas 604-605).

`Budget.displayProperties` (`Budget.swift:117-124`) es el path **legacy** — lee la relación M2M `subcategories` directo, vulnerable a la ventana lazy de CloudKit. Existe un path SSOT nuevo, `Budget.computeDisplayProperties(for:in:)` (`Budget.swift:126-148`), que lee el CSV mirror primero (`resolvedSubcategoryIDs`) y solo cae al M2M si el CSV viene vacío — pero es `@MainActor` porque necesita `ModelContext.fetch(...)` para resolver `Subcategory` por `shortcutID`.

`InsightsCalculator` es un `struct` **puro, sin `@MainActor`** (solo `import Foundation` + `import SwiftData`, sin ningún aislamiento de actor) — no puede invocar `computeDisplayProperties(for:in:)` directamente sin volverse `@MainActor` él mismo, lo cual violaría la separación UI/lógica del proyecto.

## Por qué es baja prioridad

El fallback (`displayProperties` legacy, icon genérico `chart.pie.fill` si M2M viene lazy-nil) ya existe y se auto-cura — es un defecto visual cosmético y transitorio en cold launch, no un bug de cálculo (los montos/porcentajes de `budgetsAtRisk` no dependen del icon).

## Solución propuesta

**Quién construye el lookup: la View (`DetailContainerView`), no el ViewModel.** Investigación confirmada: `InsightsViewModel` (`Yala/App/ViewModels/InsightsViewModel.swift`, `@MainActor @Observable`) **no tiene `ModelContext` ni `@Query<Budget>`** — recibe `budgets: [Budget]` como parámetro plano en `calculateInsightsData(...)` (líneas 60-109), sin fetchear nada él mismo. Quien SÍ tiene ambas piezas (`modelContext` + `budgets` ya cargados) es `DetailContainerView.swift` (`@Environment(\.modelContext)` línea 18; `dataViewModel.budgets` vía `DetailContainerViewModel`, `@MainActor`, línea 27) — es la View quien debe precomputar el lookup ANTES de llamar `insightsViewModel.calculateInsightsData(...)` (invocado desde `calculateInsightsData()` en `DetailContainerView.swift:584-597`), y pasarlo como parámetro nuevo hasta el calculator.

```swift
// En DetailContainerView, antes de invocar insightsViewModel.calculateInsightsData(...):
let iconLookup: [PersistentIdentifier: (icon: String, color: String)] = Dictionary(
    uniqueKeysWithValues: dataViewModel.budgets.map { budget in
        (budget.persistentModelID, Budget.computeDisplayProperties(for: budget, in: modelContext))
    }
)
```

`InsightsViewModel.calculateInsightsData(...)` recibe y reenvía el lookup sin tocarlo (no necesita `ModelContext` él mismo, solo pasar el dict hasta el calculator):

```swift
insightsViewModel.calculateInsightsData(
    // ...params existentes...,
    iconLookup: iconLookup
)
```

`InsightsCalculator.calculate(...)` y `calculateCommitments(...)` reciben `iconLookup: [PersistentIdentifier: (icon: String, color: String)] = [:]` (default vacío, backward-compat) y hacen lookup en vez de leer `displayProperties`:

```swift
icon: iconLookup[budget.persistentModelID]?.icon ?? budget.displayProperties.icon,
```

**Patrón de naming a seguir**: el codebase ya tiene la convención `*ByID`/`*Map`/`byIDLookup` para lookups precomputados (`Tag.byIDLookup(_:)` en `Tag.swift:63-68`, `SankeyFlowCalculator`'s `incomeSubcatMap`/`incomeCatMap`/`expenseCatMap`, `TopSpendingCategoriesCalculator`'s `categoryMap`) — pero en TODOS esos casos el Calculator recibe el **array crudo** (ej. `allTags: [Tag]`) y construye el `Dictionary` él mismo dentro del método puro, porque `Tag` no requiere `ModelContext` para resolverse. **Este ticket sería la primera instancia** de un Calculator recibiendo el `Dictionary` YA ARMADO desde un caller `@MainActor` — necesario aquí porque, a diferencia de `Tag`, `computeDisplayProperties` sí requiere `ModelContext.fetch(...)`.

## Plan técnico

### Archivos involucrados

| Archivo | Acción | Qué cambia |
|---|---|---|
| `Yala/App/Logic/Calculators/InsightsCalculator.swift:180-197` | Editar | Añadir param `iconLookup: [PersistentIdentifier: (icon: String, color: String)] = [:]` a `calculate(...)` |
| `Yala/App/Logic/Calculators/InsightsCalculator.swift:537-628` | Editar | `calculateCommitments(...)` recibe y usa `iconLookup` en vez de `budget.displayProperties.icon` (línea 609) |
| `Yala/App/ViewModels/InsightsViewModel.swift:60-109` | Editar | `calculateInsightsData(...)` recibe `iconLookup` y lo reenvía a `InsightsCalculator.calculate(...)` — considerar si entra al hash `lastInputsSignature` (línea ~70): probablemente NO, depende de los mismos `budgets` que ya están cubiertos indirectamente vía `dataVersion` |
| `Yala/App/Views/Statistics/DetailContainerView.swift:584-597` | Editar | Precomputa `iconLookup` iterando `dataViewModel.budgets` + `Budget.computeDisplayProperties(for:in:)` (usa `modelContext` de línea 18), lo pasa a `calculateInsightsData(...)` |

### Incrementos de implementación

1. Añadir el parámetro `iconLookup` con default `[:]` en `InsightsCalculator.calculate`/`calculateCommitments` — build verde sin cambiar ningún callsite todavía (backward-compat).
2. Cablear `InsightsViewModel.calculateInsightsData` para reenviar el parámetro.
3. Precomputar en `DetailContainerView` y pasar el lookup real — verificar en simulador con cold launch (`-uitest-seed pesado` o cuenta con CloudKit lazy) que el icon del budget at risk ya no muestra `chart.pie.fill` genérico en el primer render.

## Acceptance Criteria

- [ ] `InsightsCalculator.calculate`/`calculateCommitments` aceptan `iconLookup` con default `[:]` (sin romper ningún callsite existente).
- [ ] `DetailContainerView` precomputa el lookup usando `Budget.computeDisplayProperties(for:in:)` (SSOT, CSV-first) antes de invocar `insightsViewModel.calculateInsightsData(...)`.
- [ ] Verificado en simulador que el icon de `budgetsAtRisk` no muestra el genérico `chart.pie.fill` en cold launch con CloudKit lazy (requiere reproducir la ventana lazy — considerar seed con M2M poblado tras el primer render, no antes).
- [ ] Build verde + test-smart.

## Origen

TODO inline en `InsightsCalculator.swift:604-605`, removido del texto del comentario durante /refine post-épico CSV mirror pero preservado como este ticket de Backlog.

migrated from YalaWiki Backlog/insights-calculator-iconlookup-precomputed.md @ 1934e8ad
