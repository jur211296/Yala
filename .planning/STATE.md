# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-13)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 4 — Panel y Navegación — Widget de Presupuestos

## Current Position

Phase: 4 of 8 (Panel y Navegación)
Plan: In progress
Status: 2/3 items done (Widget de Presupuestos en progreso)
Last activity: 2026-01-15 — Incrementos 1-3 del Widget de Presupuestos completados

Progress: ██████░░░░ 60%

## Feature en progreso: Widget de Presupuestos en PanelView

### Commits realizados
1. `c75f634` - feat(budgets): Añadir modelo y tipo de widget para presupuestos
2. `17498fd` - feat(budgets): Crear vistas BudgetsWidget y BudgetWidgetRow
3. `ff47c75` - feat(budgets): Integrar widget en PanelView con cálculo de datos

### Incrementos completados

**Incremento 1: Modelo + Widget Type** ✅
- `Budget.swift`: añadido `isFavorite: Bool = false`, `favoriteOrder: Int = 0`
- `WidgetModels.swift`: añadido `case .budgets` con sizes `[.medium, .large]` (top 3 / top 5)
- `L10n.swift` + `Localizable.strings`: añadido `widgetType.budgets`

**Incremento 2: Vista del Widget** ✅
- `BudgetsWidget.swift`: widget con header, lista, empty states diferenciados
- `BudgetWidgetRow.swift`: fila compacta con icono, progreso, días restantes
- Empty states: "Sin presupuestos" vs "Sin favoritos" (guía a Ajustes)
- Soporte `.medium` (top 3) y `.large` (top 5)

**Incremento 3: Datos en PanelViewModel + integración** ✅
- `PanelViewModel.swift`: añadido `calculateBudgetsWidget()` con lógica completa de filtros
- `PanelViewModel.swift`: propiedades `topBudgetSummaries`, `hasBudgetsButNoFavorites`
- `PanelView.swift`: añadido `@Query` de budgets activos
- `PanelView.swift`: caso `.budgets` en `actualWidgetView(for:)`
- Navegación: chevron → `sessionState.selectedMainTab = .planning`

### Incrementos pendientes

**Incremento 4: Navegación a Budgets** (opcional, chevron ya funciona)
- Actualmente navega a tab Planning completa
- Podría añadir navegación directa a Budgets si se requiere

**Incremento 5: Interactividad (aplicar filtros del budget)**
- `SessionState.swift`: añadir `applyBudgetFilters(budget: Budget)`
- `BudgetsWidget.swift`: conectar tap en row con aplicación de filtros
- Al tocar un budget, aplicar sus filtros (accounts, subcategories, tags, natures)

**Incremento 6: Gestión de Favoritos en Profile**
- Crear `BudgetsFavoritesSettingsView.swift` (secciones por periodType, toggle favoritos, reordenar)
- `ProfileView.swift`: añadir entrada en sección Organización
- Mensaje: "En el orden que estén los budgets aquí se verán en los widgets (top 3 y top 5)"

**Incremento 7: Strings de localización adicionales**
- Añadir keys para sección de favoritos en Profile
- Ya completadas: `budgets.widget.noFavorites.title/message`, `widgetType.budgets`

### Archivos clave modificados/creados

```
Neto/Models/Budget.swift                           # +isFavorite, +favoriteOrder
Neto/App/Models/WidgetModels.swift                 # +case budgets
Neto/App/Views/Panel/BudgetsWidget.swift           # NUEVO
Neto/App/Views/Panel/BudgetWidgetRow.swift         # NUEVO
Neto/App/ViewModels/PanelViewModel.swift           # +calculateBudgetsWidget()
Neto/App/Views/Panel/PanelView.swift               # +@Query budgets, +caso .budgets
Neto/Utils/L10n.swift                              # +WidgetType.budgets
Neto/Resources/*/Localizable.strings               # +widgetType.budgets, +noFavorites
```

### Lógica de selección de budgets para widget
1. Mostrar budgets favoritos (`isFavorite == true`) ordenados por `favoriteOrder`
2. Si no hay favoritos pero hay budgets → empty state "Sin favoritos" con guía a configuración
3. Si no hay budgets → empty state "Sin presupuestos"
4. Límite: 3 en `.medium`, 5 en `.large`

### Para retomar
1. Activar widget en Preferencias de Widgets (Panel → gear icon)
2. Marcar budgets como favoritos (pendiente Incremento 6)
3. Probar interactividad (pendiente Incremento 5)

## Pending (Fase 4 - resto)

- Home configurable (tabs desde personalización)

## Completed (Fase 4)

- Chevron en widgets para redirigir a detalle (SessionState.navigateToDetail, 7 widgets conectados)
- Widget de Presupuestos - Incrementos 1-3 (modelo, vistas, integración)

## i18n (Trabajo paralelo completado)

- Localización completa ES/EN de toda la app
- Fechas con AppLocale.current (no hardcoded "es")
- Nombres de moneda localizados (currencyInfo → L10n.Currency.*)
- Tipos de cuenta con localizedName
- Formularios de cuentas, tags, categorías localizados
- SearchView, Statistics, RecordsTabView localizados
- Chips de filtros y secciones localizadas

## Bug Fixes (Sesión actual)

- Fix: Animación suave al mostrar pantalla de éxito en transacciones (transition opacity + scale)
- Fix: Crash al acceder categoría eliminada (cascade delete en Category.swift)
- Fix: Posición incorrecta de pantalla éxito con teclado abierto (dismiss + delay 150ms)
- Fix: Teclado se cierra al abrir selectores de cuenta/categoría/tags en NewTransactionView
- Fix: Widgets de gastos en Panel excluyen ajustes y saldos iniciales (expenseFilteredTransactions)
- Fix: TagSelectorSheet permite crear etiquetas + diseño mejorado de filas
- Fix: "Crear otra transacción" tras editar no precarga datos (isCreatingAnother flag)
- Fix: ImportAccountPickerSheet dark mode (fondo negro → netoCard con ScrollView)
- Fix: FavoriteRowView ancho completo (.frame(maxWidth: .infinity))
- Fix: CashFlow eje en TrendsTabView usa intervalo efectivo basado en transacciones reales
- Fix: Crash al vaciar datos (SessionState.isWipingData + TabView unmount durante wipe)

## Completed (Fase 3) ✅

- Eliminación sin transacciones (botón eliminar con validación de transacciones asociadas)
- Transferencia de transacciones al eliminar (sheet con 3 opciones: transferir a específica, mover a Sin asignar, eliminar transacciones)
- Edición masiva de categorías/subcategorías (modo editar con botones delete en CategoriesSettingsListView y CategoryDetailView)

## Completed (Fase 2) ✅

- Periodo Personalizado en PeriodSelector (CustomPeriodPickerSheet, sincronización global, persistencia UserDefaults)
- Sincronización de filtros Statistics/Panel (Tags, Currency, Amount, Note + chips en todas las vistas)
- Filtro por nota: chips de búsqueda (searchText sincronizado, chip visible, filtrado aplicado)
- Fix: Chips subcategoría/categoría ahora aparecen correctamente en todas las vistas
- Fix: "Seleccionar todo" en CategorySelectorSheet funciona correctamente
- Fix: Resumen de categorías muestra "Todas" cuando todo seleccionado
- Fix: Selección manual de subcategorías funciona sin comportamiento inesperado

## Completed (Fase 1) ✅

- Fix: Saldo inicial ahora es transacción (no propiedad de Account)
- Fix: Leyenda centrada en CashFlowWidget (Ingreso/Egreso/Flujo neto)
- Fix: Colores hover del tooltip coinciden con barras/líneas
- Fix: Título dinámico en TrendsTabView (cuenta/moneda)
- Fix: Carruseles ordenados por Profile y monto
- Fix: Crash en TrendDataProcessor (DateInterval validation)
- Fix: Bug tipo de cambio en transferencias

## Risk/Notes

- Orden de cuentas usa `@AppStorage("accountsSortOrderNames")`
- DateInterval crash si start > end; siempre validar
- customTitle en CashFlowWidget tiene prioridad sobre displayMode
- Anti-loop flags (`isSyncingFilters`, `isSyncingState`) previenen ciclos de sincronización
- `SessionState.shared` controla navegación entre tabs (selectedMainTab, selectedDetailTab)
- Budget: `isFavorite` y `favoriteOrder` deben tener valores por defecto para migración SwiftData

## Session Continuity

Last session: 2026-01-15 08:00
Stopped at: Widget de Presupuestos - Incrementos 1-3 completados, pendientes 4-7
Next step: Incremento 5 (interactividad) o Incremento 6 (gestión favoritos en Profile)
Resume file: None
