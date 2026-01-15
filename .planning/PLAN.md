# Plan: Auditoría de Localización

## Objetivo
Revisar todos los archivos Swift del proyecto para encontrar y corregir textos hardcodeados que deberían estar localizados (español e inglés).

## Metodología
1. Revisar archivos por carpeta/grupo
2. Identificar strings hardcodeados en UI (Text(), placeholder, title, message, etc.)
3. Agregar entradas a Localizable.strings (es/en) y L10n.swift
4. Build + verify después de cada grupo
5. Commit atómico por grupo

## Grupos de Trabajo (por orden)

### Grupo 1: Views/Transactions + Components (~15 archivos)
- NewTransactionView.swift
- TransactionSuccessView.swift
- TransactionFormRow.swift
- AccountSelectorSheet.swift
- SubcategorySelectorSheet.swift
- TagSelectorSheet.swift
- ExchangeRateInputView.swift
- Components/*.swift

### Grupo 2: Views/Panel (~12 archivos)
- PanelView.swift
- AccountCardView.swift
- AccountsCarouselView.swift
- CategoriesPieWidget.swift
- SubcategoriesPieWidget.swift
- TopCategoriesWidget.swift
- TopSubcategoriesWidget.swift
- NatureTrendWidget.swift
- CashFlowWidget.swift
- RecentRecordsWidget.swift
- ExchangeRateWidget.swift
- WidgetPreferencesView.swift

### Grupo 3: Views/Statistics (~5 archivos)
- StatisticsView.swift
- DetailContainerView.swift
- TrendsTabView.swift
- CategoriesTabView.swift
- RecordsTabView.swift

### Grupo 4: Views/Settings (~10 archivos)
- CategoriesSettingsListView.swift
- AccountsSettingsListView.swift
- TagsSettingsListView.swift
- ThemeSettingsView.swift
- CurrencySettingsView.swift
- PersonalizationSettingsView.swift
- AppIconSettingsView.swift
- UserDataResetView.swift
- SettingsPlaceholderView.swift

### Grupo 5: Views/Categories + Tags (~6 archivos)
- CategoryDetailView.swift
- SubcategoryDetailView.swift
- SubcategoryTransferSheet.swift
- SubcategoryNatureSelectorView.swift
- TagFormView.swift

### Grupo 6: Views/Planning (~5 archivos)
- PlanningView.swift
- BudgetEditorView.swift
- BudgetRowView.swift
- Components/*.swift

### Grupo 7: Views/Favorites + Import + Export (~8 archivos)
- FavoritesListView.swift
- FavoriteEditorView.swift
- FavoriteRowView.swift
- ImportIntroSheet.swift
- ImportAccountPickerSheet.swift
- ExportFiltersStepView.swift
- ExportColumnsStepView.swift
- ExportSummaryStepView.swift

### Grupo 8: Views/Accounts + Profile + Shared (~10 archivos)
- AccountFormView.swift
- AdjustmentModeSelectorView.swift
- AccountTypeSelectorView.swift
- ProfileView.swift
- PersonalDetailsView.swift
- Shared/*.swift (SectionBox, IconColorPickerSheet, etc.)

### Grupo 9: Views/Filters + Records (~8 archivos)
- FilterControlBar.swift
- FilterChipsSection.swift
- FilterChipView.swift
- PeriodSelectorLabel.swift
- CategorySelectorSheet.swift
- RecordRowView.swift
- RecordDateSectionView.swift

### Grupo 10: ContentView + Main + Otros (~5 archivos)
- ContentView.swift
- MainTabView (en ContentView)
- GlobalSearchView.swift
- Otros archivos restantes

## Criterios de Búsqueda
Buscar patterns como:
- `Text("...")`  donde el string no es L10n
- `placeholder: "..."`
- `title: "..."`
- `.navigationTitle("...")`
- `.alert("...")`
- `Button("...")`
- Cualquier string literal visible al usuario

## Exclusiones
- Strings técnicos (keys, identifiers)
- SF Symbols names
- Format strings que ya usan variables
- Strings en Preview/Debug code

## Commits
Un commit por grupo completado con formato:
`chore(l10n): Localizar textos en [NombreGrupo]`
