# Bug Fix: Tags KPI no respeta filtros de categoría/subcategoría

## Problema
En `CategoriesTabView.swift`, `tagSpending` (en `calculateData()`) usa `pieFiltered`, que se construye con `selectedCategories: []` y `selectedSubcategories: []`. Esto causa que al filtrar subcategoría "Delivery", el pie de tags muestre tags de TODAS las transacciones en vez de solo las de Delivery.

Mismo problema en `calculatePreviousPeriodTotals()` para `previousTagSpending`.

## Solución

### En `calculateData()` (~línea 1089)

Reemplazar:
```swift
// Calculate tag spending (show ALL tags, dim applied in widget)
tagSpending = TagSpendingCalculator.calculateTopSpending(
    transactions: pieFiltered,
    interval: interval,
    currencyCode: defaultCurrencyCode,
    transactionNatures: naturesFilter
)
```

Con:
```swift
// Calculate tag spending — respects category/subcategory filters but shows ALL tags
let tagCriteria = FilterCriteria(
    selectedAccounts: viewModel.selectedAccounts,
    selectedCategories: viewModel.selectedCategories,
    selectedSubcategories: viewModel.selectedSubcategories,
    selectedTags: [],  // Don't filter by tag — show all with dim
    selectedNatures: viewModel.selectedNatures,
    selectedTransactionNatures: viewModel.selectedTransactionNatures,
    selectedCurrencies: viewModel.selectedCurrencies,
    isExcludeMode: viewModel.isExcludeMode,
    transactionTypeFilter: .all,
    amountCondition: viewModel.amountCondition,
    searchText: viewModel.searchText,
    dateInterval: interval
)
let tagFiltered = FilterService.filterForTrends(
    transactions: allTransactions, accounts: accounts, criteria: tagCriteria
)
tagSpending = TagSpendingCalculator.calculateTopSpending(
    transactions: tagFiltered,
    interval: interval,
    currencyCode: defaultCurrencyCode,
    transactionNatures: naturesFilter
)
```

### En `calculatePreviousPeriodTotals()` (~línea 1212)

Reemplazar:
```swift
// Calculate previous period tag spending
let previousTagSpending = TagSpendingCalculator.calculateTopSpending(
    transactions: previousFiltered,
    interval: previousInterval,
    currencyCode: defaultCurrencyCode,
    transactionNatures: naturesFilter
)
```

Con:
```swift
// Calculate previous period tag spending — respects category/subcategory filters
let prevTagCriteria = FilterCriteria(
    selectedAccounts: viewModel.selectedAccounts,
    selectedCategories: viewModel.selectedCategories,
    selectedSubcategories: viewModel.selectedSubcategories,
    selectedTags: [],  // Don't filter by tag — show all
    selectedNatures: viewModel.selectedNatures,
    selectedTransactionNatures: viewModel.selectedTransactionNatures,
    selectedCurrencies: viewModel.selectedCurrencies,
    isExcludeMode: viewModel.isExcludeMode,
    transactionTypeFilter: .all,
    amountCondition: viewModel.amountCondition,
    searchText: viewModel.searchText,
    dateInterval: previousInterval
)
let prevTagFiltered = FilterService.filterForTrends(
    transactions: allTransactions, accounts: accounts, criteria: prevTagCriteria
)
let previousTagSpending = TagSpendingCalculator.calculateTopSpending(
    transactions: prevTagFiltered,
    interval: previousInterval,
    currencyCode: defaultCurrencyCode,
    transactionNatures: naturesFilter
)
```

## Causa raíz
`pieChartCriteria` vacía `selectedCategories` y `selectedSubcategories` intencionalmente (para que el pie de categorías muestre TODAS las categorías con dim). Pero luego se reutiliza `pieFiltered` para calcular tags, cuando tags SÍ necesita respetar esos filtros.

## Verificación
- Filtrar subcategoría "Delivery" → pie de tags muestra SOLO tags de transacciones de Delivery
- Sin filtro → pie de tags muestra todos los tags (sin cambio)
