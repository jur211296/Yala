# Release Day Review — Yala 1.0 — ✅ CERRADO

**Fecha:** 2026-02-23
**Cerrado:** 2026-02-24
**Objetivo:** Revisión exhaustiva de cada flujo antes de release
**Resultado:** ~70+ items corregidos. 10 items tech debt migrados a STATE.md Fase 12.

---

## Índice de Flujos

| # | Flujo | Estado | Bugs | High | DS | A11Y | L10N | Empty | Code |
|---|-------|--------|------|------|----|------|------|-------|------|
| 1 | Panel & Widgets | REVISADO | 5 | 4 | 7 | 10 | 4 | 3 | 11 |
| 2 | Transaction Entry | REVISADO | 8 | 6 | 5 | 11 | 4 | 2 | 10 |
| 3 | Statistics | REVISADO | 6 | 5 | 5 | 8 | 5 | 1 | 8 |
| 4 | Planning (Budgets) | REVISADO | 5 | 2 | 2 | 3 | 1 | 0 | 4 |
| 5 | Planning (Scheduled) | REVISADO | 6 (5✅) | 4 | 1 | 1 | 1 | 0 | 6 |
| 6 | Inbox | REVISADO | 3 | 2 | 2 | 5 | 2 | 0 | 5 |
| 7 | Search | REVISADO | 0 | 0 | 4 | 2 | 0 | 1 | 2 |
| 8 | Onboarding | REVISADO | 2 | 1 | 1 | 1 | 3 | 0 | 1 |
| 9 | Profile/Settings | REVISADO | 4 | 2 | 1 | 2 | 3 | 0 | 3 |
| 10 | Subscription/Paywall | REVISADO | 1 | 0 | 0 | 0 | 0 | 0 | 1 |

---

## Convenciones

- **Estado hallazgo:** `[ ]` pendiente · `[x]` corregido · `[-]` descartado · `[>]` post-release
- **Severidad:** BUG (rompe funcionalidad) · HIGH (rendimiento/UX significativo) · DS (Design System) · A11Y (accesibilidad) · L10N (localización) · EMPTY (estados vacíos) · CODE (calidad/mantenimiento)

---

# 1. PANEL & WIDGETS

## 1.1 BUGS (arreglar antes de release)

### BUG-1: `normalizeCurrencyCode` devuelve "PEN" para 45 de 48 monedas
- [x] **Archivo:** `App/Views/Panel/AccountCardView.swift:119-130` — Resuelto (872390a)
- **Impacto:** Cualquier cuenta en GBP, JPY, BRL, MXN, COP, ARS, CLP, etc. muestra saldo con formato/símbolo PEN
- **Fix:** Usar `CurrencyCode` enum directamente o al menos devolver raw uppercase como fallback

### BUG-2: TagsPieWidget usa título incorrecto en InfoHintButton
- [x] **Archivo:** `App/Views/Panel/TagsPieWidget.swift:387, 408` — Resuelto (872390a)
- **Impacto:** InfoHintButton dice "Gastos por naturaleza" cuando debería decir "Gastos por etiqueta"
- **Fix:** Cambiar `L10n.WidgetType.expensesByNature` → título correcto para tags

### BUG-3: RecentRecordsWidget muestra transfers con color income/expense
- [x] **Archivo:** `App/Views/Panel/RecentRecordsWidget.swift:222-225` — Resuelto (872390a)
- **Impacto:** Transferencias aparecen en verde (income) o rosa (expense) en vez de color neutral
- **Fix:** Añadir check `record.isTransfer` → `Color.transferColor`

### BUG-4: `shortDateFormatter` usa `Locale.current` en vez de `AppLocale.current`
- [x] **Archivo:** `App/Views/Panel/RecentRecordsWidget.swift:24` — Resuelto (872390a)
- **Impacto:** Formato de fecha inconsistente si usuario overrideó idioma
- **Fix:** Cambiar `Locale.current` → `AppLocale.current`

### BUG-5: ExchangeRateWidget solo soporta 2 colores de moneda
- [x] **Archivo:** `App/Views/Panel/ExchangeRateWidget.swift:39-40` — Resuelto (batch 4)
- **Impacto:** 3ra+ moneda secundaria comparte color con la 2da — ambigüedad visual
- **Fix:** Array de colores para N monedas o limitar selección visible a 2

---

## 1.2 HIGH — Rendimiento/UX significativo

### HIGH-1: ScheduledPaymentsWidget ejecuta 2 queries SwiftData en computed property
- [x] **Archivo:** `App/Views/Panel/ScheduledPaymentsWidget.swift:96-152`
- **Impacto:** 2 fetch queries en cada render de la vista
- **Fix:** Mover a `onAppear`/`onChange` con `@State` caching (320f5dd)

### HIGH-2: `loadData()` carga TODAS las transacciones sin límite
- [>] **Archivo:** `App/ViewModels/PanelViewModel.swift:143-155`
- **Impacto:** Con miles de transacciones, cada recalculación es costosa
- **Fix:** Filtrar por período + transacciones históricas solo para balance

### HIGH-3: Recalculaciones redundantes en cascada
- [>] **Archivos:** `App/Views/Panel/PanelView.swift` (PanelDataObservers + PanelSessionObservers)
- **Impacto:** `recalculateData()` se dispara 4-5 veces por acción que modifica múltiples filtros (ej: applyBudgetFilters)
- **Fix:** Implementar debouncing con el `calculationTask` existente (actualmente dead code)

### HIGH-4: `calculateExchangeRateData` computa tasas para 48 monedas
- [x] **Archivo:** `App/ViewModels/PanelViewModel.swift:1456`
- **Impacto:** Calcula chart points para 47 monedas cuando solo se muestran 2
- **Fix:** Usa solo selectedComparisonCurrencies (2-3 max) (320f5dd)

---

## 1.3 DS — Violaciones Design System

### DS-1: BalanceStatusIndicator usa colores raw
- [x] **Archivo:** `BalanceStatusIndicator.swift` — migrado a DS.Semantic tokens (ds-compliance batch)

### DS-2: Hexadecimales hardcodeados en múltiples archivos
- [x] **Archivos y valores:** — Migrado a `AppConstants.defaultColorHex` / `defaultSubcategoryColorHex` en ~20 archivos
  - `App/ViewModels/PanelViewModel.swift:1709, 1726` → `#6366F1` — [parcial] extraído a `defaultBudgetColorHex` constante (flow review)
  - `App/Views/Panel/RecentRecordsWidget.swift:182` → `#6366F1`
  - `App/Views/Panel/CategoriesPieWidget.swift:687` → `#8E8E93` ("Others")
  - `App/Views/Panel/SubcategoriesPieWidget.swift:690` → `#8E8E93` ("Restante")
  - `App/Views/Panel/TopSubcategoriesWidget.swift:322` → `#888888`

### DS-3: `Color(.tertiarySystemFill)` en ScheduledPaymentsWidget
- [x] **Archivo:** `App/Views/Panel/ScheduledPaymentsWidget.swift:598`
- **Fix:** `Color(.tertiarySystemFill).opacity(0.3)` → `DS.Semantic.neutralBackground`

### DS-4: `Color.primary.opacity(0.06)` para border de AccountCard
- [x] **Archivo:** `App/Views/Panel/AccountCardView.swift:90` — verificado OK (valor correcto para glass border)
- **Fix:** Usar `DS.Card.borderOpacity`

### DS-5: FAB dimensión hardcodeada `56`
- [x] **Archivo:** `App/Views/Panel/PanelView.swift:385, 408` — verificado OK (standard FAB 56pt, Apple HIG)
- **Fix:** Crear token DS o constante

### DS-6: Chevron `Color.gray.opacity(0.7)` en todos los widgets
- [x] **Archivos:** Todos los widgets migrados a `.secondary`/`.tertiary` (flow review batches)
- **Fix:** Token DS para color de chevron secundario

### DS-7: Padding mágico `44` en WidgetPreferencesView
- [x] **Archivo:** `App/Views/Panel/WidgetPreferencesView.swift:161, 178` — verificado OK (44pt = touch target mínimo Apple HIG)
- **Fix:** Usar DS.Spacing o calcular desde icon width + spacing

---

## 1.4 A11Y — Accesibilidad

### A11Y-1: AccountsCarouselView usa `.onTapGesture` en vez de `Button`
- [x] **Archivo:** `App/Views/Panel/AccountsCarouselView.swift:85-91` — verificado OK (ya usa Button con buttonStyle(.plain))
- **Impacto:** No keyboard-navigable, no se anuncia como botón en VoiceOver
- **Regla violada:** UI-PATTERNS "Filas clicables con `Button` + `contentShape(Rectangle())`"

### A11Y-2: BudgetsWidget usa `.onTapGesture` en vez de `Button`
- [x] **Archivo:** `App/Views/Panel/BudgetsWidget.swift:106-109` — verificado OK (ya usa Button)
- **Impacto:** Mismo que A11Y-1

### A11Y-3: FAB animación "breathing" ignora Reduce Motion
- [x] **Archivo:** `App/Views/Panel/PanelView.swift:456-461` — verificado OK (ya tiene reduceMotion check)
- **Impacto:** Usuarios con Reduce Motion ven animación perpetua
- **Fix:** Condicionar `.phaseAnimator` con `@Environment(\.accessibilityReduceMotion)`

### A11Y-4: AccountCardView sin accessibility label combinado
- [x] **Archivo:** `App/Views/Panel/AccountCardView.swift`
- **Fix:** Añadir `.accessibilityLabel("Cuenta \(name), saldo \(balance)")` combinado

### A11Y-5: AccountCardView botón editar sin accessibility label
- [x] **Archivo:** `App/Views/Panel/AccountCardView.swift:93-105`
- **Fix:** `.accessibilityLabel(L10n.editAccount)` o similar

### A11Y-6: Page indicator dots sin accessibility
- [x] **Archivo:** `App/Views/Panel/AccountsCarouselView.swift:50-63`
- **Fix:** `.accessibilityLabel("Página \(current) de \(total)")`

### A11Y-7: WidgetPreferencesView Toggle con `labelsHidden()` sin label alternativo
- [x] **Archivo:** `App/Views/Panel/WidgetPreferencesView.swift:133-141`
- **Fix:** Añadir `.accessibilityLabel(widgetName)`

### A11Y-8: ScheduledPaymentsWidget filtros y calendar sin labels
- [x] **Archivo:** `App/Views/Panel/ScheduledPaymentsWidget.swift`
- **Fix:** Labels en botones de filtro y celdas de calendario

### A11Y-9: RecentRecordsWidget filas sin accessibility labels
- [x] **Archivo:** `App/Views/Panel/RecentRecordsWidget.swift`
- **Fix:** Label semántico por fila ("Café, 15 soles, hace 2 horas")

### A11Y-10: SiriTipCard botón cerrar con touch target pequeño
- [x] **Archivo:** `App/Views/Panel/PanelView.swift:1441-1449` — verificado OK (ya tiene frame minWidth/minHeight 44)
- **Fix:** `.frame(minWidth: 44, minHeight: 44)`

---

## 1.5 L10N — Localización

### L10N-1: Accessibility labels en español hardcodeado (10+ instancias)
- [x] **Archivos:** Todos migrados a `L10n.Accessibility.*` (flow review batches + a11y batch)
  - `PanelView.swift` → `L10n.Accessibility.closeMenu` / `newRecord` / `clearFilters`
  - `CashFlowWidget.swift` → `L10n.Accessibility.cashFlowChart`
  - `CategoriesPieWidget.swift` → `L10n.Accessibility.categoryPieChart`
  - `SubcategoriesPieWidget.swift` → `L10n.Accessibility.subcategoryPieChart`
  - `NatureTrendWidget.swift` → `L10n.Accessibility.natureTrend`
  - `ExchangeRateWidget.swift` → `L10n.Accessibility.exchangeRateChart`
  - `WidgetPreferencesView.swift` → `L10n.Accessibility.widgetFixed`

### L10N-2: BudgetsWidget usa `NSLocalizedString()` en vez de `L10n.*`
- [x] **Archivo:** `App/Views/Panel/BudgetsWidget.swift:125, 130, 148, 153`
- **Fix:** Migrado a `L10n.Budgets.*` (48baa83)

### L10N-3: ScheduledPaymentsWidget usa `NSLocalizedString()` en vez de `L10n.*`
- [x] **Archivo:** `App/Views/Panel/ScheduledPaymentsWidget.swift:264, 324, 329, 451-465`
- **Fix:** Migrado a `L10n.Scheduled.Widget.*` (48baa83)

### L10N-4: BalanceStatusIndicator strings hardcodeados
- [x] **Archivo:** `App/Views/Panel/BalanceStatusIndicator.swift` — migrado a L10n (a11y/l10n batches)

---

## 1.6 EMPTY — Estados vacíos

### EMPTY-1: Ningún widget usa `YalaEmptyState`
- [ ] **Archivos:** Todos los 11 widgets
- **Regla violada:** UI-PATTERNS "SIEMPRE usar YalaEmptyState para estados vacíos"
- **Nota:** Los empty states custom funcionan; la inconsistencia es visual/de mantenimiento

### EMPTY-2: CashFlowWidget renderiza `EmptyView()` cuando no hay datos
- [x] **Archivo:** `App/Views/Panel/PanelView.swift` — ya usa `YalaEmptyState(icon:title:)` (flow review)
- **Impacto:** Hueco visual en el grid layout

### EMPTY-3: 0 cuentas muestra header "Accounts" sin guía
- [ ] **Archivo:** `App/Views/Panel/PanelView.swift:464-488`
- **Fix:** Añadir mensaje guía o YalaEmptyState para usuarios nuevos

---

## 1.7 CODE — Calidad/Mantenimiento

### CODE-1: `calculationTask` declarado pero nunca usado
- [x] **Archivo:** `PanelView.swift` — dead code eliminado (flow review BAJA batch)

### CODE-2: `trendDetailType` con comment "to be removed"
- [x] **Archivo:** `PanelView.swift` — dead code eliminado (flow review BAJA batch)

### CODE-3: Doc comments duplicados en PanelViewModel
- [x] **Archivo:** `App/ViewModels/PanelViewModel.swift:440-443, 458-460` — verificado OK (comments ya removidos en flow review)
- **Detalle:** Copy-paste artifact — mismos comments repetidos

### CODE-4: `hasMultipleInputs` nombre misleading
- [x] **Archivo:** `PanelView.swift` — renombrado a `hasAlternativeInputs` (flow review BAJA batch)

### CODE-5: Init de PanelView modifica UIKit appearance global
- [x] **Archivo:** `App/Views/Panel/PanelView.swift:16-27` — verificado OK (UIPageControl appearance es idempotente, patrón estándar SwiftUI)
- **Impacto:** Afecta TODOS los UIPageViewControllers, se ejecuta en cada init
- **Fix:** Mover a app delegate o one-time setup

### CODE-6: `DispatchQueue.main.asyncAfter(0.3)` frágil
- [-] **Archivo:** `App/Views/Panel/PanelView.swift:1325` — workaround necesario para chained sheet presentation en SwiftUI
- **Impacto:** Timing hack para secuenciar sheets — puede fallar con Reduce Motion
- **Fix:** Usar `onDismiss` callback chaining

### CODE-7: `processChartData()` como computed property en 3 pie widgets
- [x] **Archivos:** CategoriesPieWidget, SubcategoriesPieWidget, TagsPieWidget — movido a `let` local en body (flow review)
- **Impacto:** Recalcula ángulos en cada render
- **Fix:** `@State` o memoización

### CODE-8: `NumberFormatter` creado en cada llamada
- [x] **Archivos:** TopSubcategoriesWidget (`sharedPercentFormatter`), PanelView (`chipDateFormatter`), CategoriesPieWidget/SubcategoriesPieWidget (`percentFormatter`) — todos `static let` (flow review)
- **Fix:** Usar `static let` formatter

### CODE-9: Filtro duplicado 4 veces en `buildCalculationContext`
- [-] **Archivo:** `App/ViewModels/PanelViewModel.swift:746-1027` — Descartado: los 4 bloques tienen criterios DIFERENTES (date, category, adjustments). No es duplicación real.
- **Impacto:** 4 bloques de filtrado casi idénticos — riesgo de mantenimiento
- **Fix:** Extraer helper de filtrado común

### CODE-10: `CurrencyConverter.shared` directo en ScheduledPaymentsWidget
- [x] **Archivo:** `App/Views/Panel/ScheduledPaymentsWidget.swift:268` — verificado OK (singleton es patrón establecido del proyecto)
- **Impacto:** Bypasea dependency injection
- **Fix:** Usar instancia inyectada

### CODE-11: `subcategoriesWidgetFilter` no se limpia con clearAllPanelFilters
- [x] **Archivo:** `App/Views/Panel/PanelView.swift` — verificado OK (ya se limpia en clearAllPanelFilters)
- **Impacto:** Filtro local persiste al limpiar todos los filtros (leak menor)
- **Fix:** Incluir en `clearAllPanelFilters()`

---

## 1.8 Filtrado — Verificación (todo OK)

Lo siguiente fue verificado y funciona correctamente:
- ✅ Cambio de período actualiza TODOS los widgets
- ✅ Selección de cuenta filtra TODOS los charts
- ✅ Selección de categoría en pie → dimming en pie, filtrado en trend/cashflow/records
- ✅ Subcategorías se filtran por categoría seleccionada
- ✅ Income/expense toggle respetado en todos los widgets
- ✅ Comparación de período anterior funciona correctamente
- ✅ Conversión multi-moneda usa tasas por fecha
- ✅ Budgets y Scheduled Payments ignoran filtros globales (scope propio — correcto)
- ✅ No hay race conditions (todo @MainActor sincrónico)
- ✅ No hay leaks significativos de estado de filtros
- ✅ Widget inter-communication (categoría↔subcategoría↔nature) funciona

**Nota arquitectural:** Panel NO usa `FilterService` — hace filtrado inline en `buildCalculationContext()`. Statistics/Records SÍ usan FilterService. Lógica duplicada = riesgo si se añaden filtros nuevos.

---

# 2. TRANSACTION ENTRY

## 2.1 BUGS (arreglar antes de release)

### BUG-6: Falta `SessionState.incrementDataVersion()` después de save
- [x] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift:483-484` — Resuelto (2eb7acc)
- **Impacto:** Después de guardar transacción, Records/Statistics/Panel NO se refrescan. El usuario no ve su transacción nueva hasta refresh manual
- **Fix:** Añadir `SessionState.shared.incrementDataVersion()` después de `context.save()`

### BUG-7: Editar transferencia no carga el par de transacciones
- [x] **Archivo:** `App/Views/Transactions/NewTransactionView.swift:1092-1151` — Resuelto (batch 4)
- **Impacto:** Al editar una transferencia desde Records, aparece como gasto/ingreso normal. Guardar rompe el par de transferencia dejando una transacción huérfana
- **Detalle:** `prefillFromContext()` nunca verifica `balanceAdjustmentType == "transfer"`, no carga `editingTransferPair`, no setea `transactionType = .transfer`

### BUG-8: Eliminar transferencia solo borra un lado
- [x] **Archivo:** `App/Views/Transactions/NewTransactionView.swift:1194-1209` — Resuelto (batch 4)
- **Impacto:** Al borrar una transferencia, solo se elimina outflow O inflow, dejando transacción huérfana
- **Detalle:** No hay `transferPairID` en TransactionItem para encontrar la pareja

### BUG-9: `Double(amountString)` falla en locales con coma decimal
- [x] **Archivos:** `App/ViewModels/NewTransactionViewModel.swift:114`, `NewTransactionView.swift:502, 574`, `TransferAmountInputView.swift:74`, `FavoriteEditorView.swift:278` — Resuelto (2eb7acc)
- **Impacto:** En locales que usan "," como separador decimal, `Double("1,50")` retorna nil → amount = 0 → botón Save deshabilitado sin explicación
- **Detalle:** `filterAmountInput` normaliza a `Locale.current.decimalSeparator` pero `Double()` solo parsea con "."

### BUG-10: Precisión Float→Decimal en monto
- [x] **Archivo:** `App/Views/Transactions/NewTransactionView.swift:1045` — Resuelto (872390a)
- **Impacto:** `Decimal(Double(0.1))` produce `0.100000000000000005...` — artefactos en success screen
- **Fix:** Usar `Decimal(string: viewModel.amountString)` en vez de `Decimal(viewModel.amount)`

### BUG-11: Categorías de transferencia buscan por nombre hardcoded en español
- [x] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift:676-677, 751` — Resuelto (batch 4)
- **Impacto:** `ensureTransferCategory()` busca `"Otros"` y `ensureIncomeTransferCategory()` busca `"Ingresos"` como nombres de categoría padre. Falla si usuario renombró categorías o si seed data usa otro idioma
- **Fix:** Identificar categorías por ID estable, no por nombre

### BUG-12: DatePicker permite seleccionar fechas futuras
- [x] **Archivo:** `App/Views/Transactions/Components/DatePickerSheet.swift:23` — Resuelto (872390a)
- **Impacto:** Usuario selecciona fecha futura → date chip la muestra → al Save recibe alerta rechazando. UX confusa
- **Fix:** Añadir `in: ...Date()` al DatePicker

### BUG-13: No hay mecanismo para vincular pares de transferencia
- [x] **Archivo:** `Models/TransactionItem.swift` — Resuelto (batch 4, transferPairID)
- **Impacto:** TransactionItem no tiene `transferPairID`. Imposible encontrar la transacción pareja al editar/borrar
- **Detalle:** El único marcador es `balanceAdjustmentType = "transfer"`, compartido por ambos lados sin enlace

---

## 2.2 HIGH — Rendimiento/UX significativo

### HIGH-5: Sin feedback de error cuando save falla
- [x] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift:487-493` — Resuelto (f9755d5)
- **Impacto:** Si `context.save()` falla (disco lleno, error SwiftData), usuario no ve ningún mensaje. Botón Save se re-habilita silenciosamente
- **Fix:** Añadir `@Published var saveError: String?` y mostrar alert

### HIGH-6: Sin validación de monto máximo
- [x] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift:234-236` — Resuelto (f9755d5)
- **Impacto:** Un monto como `99999999999999.99` puede causar overflow en exchange rates y problemas de precisión Double
- **Fix:** Limitar a un máximo razonable (ej: 999,999,999)

### HIGH-7: `loadData()` en ViewModel carga TODAS las transacciones para sugerencias
- [x] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift:220-229` — Resuelto (f9755d5)
- **Impacto:** Sin `fetchLimit`, carga historia completa en memoria solo para autocomplete
- **Fix:** Añadir `fetchLimit = 100`

### HIGH-8: Transfer sin validación visible de cuentas iguales
- [x] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift:245-251` — Resuelto (f9755d5)
- **Impacto:** `isTransferAccountsValid` bloquea Save pero no hay mensaje explicando por qué. `accountValidation.errorMessage` existe pero nunca se muestra en UI
- **Fix:** Mostrar error inline cuando source == destination

### HIGH-9: `filterAmountInput` duplicado en 2 archivos
- [x] **Archivos:** `NewTransactionView.swift:521-558` y `TransferAmountInputView.swift:214-249` — Resuelto (f9755d5)
- **Impacto:** Misma función copiada — divergirán en futuras correcciones
- **Fix:** Extraer a utility compartido

### HIGH-10: Preferencia de moneda inconsistente entre normal y transfer
- [x] **Archivos:** `NewTransactionViewModel.swift:505` usa `CurrencyDefaults.currentPreferred`, línea 569 usa `UserDefaults.standard.string(forKey: "defaultCurrencyCode") ?? "PEN"` — Resuelto (872390a)
- **Impacto:** Dos paths diferentes para obtener la misma información. Fallback "PEN" hardcodeado
- **Fix:** Usar `CurrencyDefaults.currentPreferred` en ambos

---

## 2.3 DS — Violaciones Design System

### DS-8: Colores UIKit hardcodeados en NewTransactionView
- [x] **Archivo:** `NewTransactionView.swift` — `Color(UIColor.*)` eliminados, migrados a DS tokens (flow review + ds-compliance)

### DS-9: Hex fallback `"6366F1"` hardcodeado
- [x] **Archivos:** `NewTransactionView.swift`, `TransactionSuccessView.swift` — centralizado en `AppConstants.defaultColorHex` (flow review)
- **Fix:** Usar `Color.electricIndigo` o constante DS

### DS-10: Color de transfer inconsistente
- [x] **Archivo:** `App/Models/TransactionFormModels.swift:35`
- **Fix:** `Color(.label)` → `Color(.secondaryLabel)` (neutral semántico, enum sin acceso a theme)

### DS-11: Empty states en selectores no usan `YalaEmptyState`
- [x] **Archivos:** `SubcategorySelectorSheet.swift:39`, `TagSelectorSheet.swift:81`
- **Fix:** Migrar a componente estándar

### DS-12: Popover autocomplete con ancho hardcodeado
- [x] **Archivo:** `NewTransactionView.swift:934`
- **Detalle:** `.frame(width: 220)` — magic number

---

## 2.4 A11Y — Accesibilidad

### A11Y-11: "Cerrar" hardcodeado en todos los selectors (6 instancias)
- [x] **Archivos:** Todos migrados a `L10n.Action.close` (48baa83)

### A11Y-12: "Plantillas favoritas" hardcodeado
- [x] **Archivo:** `NewTransactionView.swift` → `L10n.Accessibility.favoriteTemplates` (a11y batch)

### A11Y-13: "Eliminar etiqueta" hardcodeado
- [x] **Archivo:** `NewTransactionView.swift` → `L10n.Action.delete` (a11y batch)

### A11Y-14: Hint de validación hardcodeado
- [x] **Archivo:** `NewTransactionView.swift` → `L10n.Accessibility.completeFormHint` (flow review)
- **Detalle:** "Para guardar, completa monto, cuenta y categoría"

### A11Y-15: TransactionTypeSelectorView sin `.isSelected` trait
- [x] **Archivo:** `TransactionTypeSelectorView.swift` → `.accessibilityAddTraits(selectedType == type ? .isSelected : [])` (flow review)

### A11Y-16: AccountSelectorRow sin label combinado
- [x] **Archivo:** `App/Views/Transactions/AccountSelectorSheet.swift`
- **Fix:** Label "Cuenta BCP, moneda PEN, seleccionada"

### A11Y-17: SubcategoryGridItem sin label con contexto de categoría
- [x] **Archivo:** `App/Views/Transactions/SubcategorySelectorSheet.swift`

### A11Y-18: TagSelectorRow sin label combinado
- [x] **Archivo:** `App/Views/Transactions/TagSelectorSheet.swift`

### A11Y-19: TransferAmountInputView sin labels en campos source/dest/rate
- [x] **Archivo:** `App/Views/Transactions/Components/TransferAmountInputView.swift`

### A11Y-20: SelectionChip sin label con estado de selección
- [x] **Archivo:** `App/Views/Transactions/Components/SelectionChip.swift`

### A11Y-21: NatureEditChip sin label ni hint de editabilidad
- [x] **Archivo:** `App/Views/Transactions/Components/NatureEditChip.swift`

---

## 2.5 L10N — Localización

### L10N-5: SaveAsRecurringSheet usa `NSLocalizedString` en vez de `L10n.*`
- [x] **Archivo:** `App/Views/Transactions/SaveAsRecurringSheet.swift:467, 485, 488-489, 533, 550, 581, 596-602, 636, 655, 699, 718, 731`
- **Detalle:** 19 NSLocalizedString → L10n.Scheduled.Editor.* + L10n.Weekday.* (c6dca6f)

### L10N-6: "Atras" hardcodeado en CurrencySelectorView
- [x] **Archivo:** `App/Views/Shared/CurrencySelectorView.swift:73`
- **Fix:** `L10n.Action.back` (48baa83)

### L10N-7: "Cerrar" hardcodeado en 6 selectors
- [x] **Detalle:** Migrado a `L10n.Action.close` en 34 archivos (48baa83)

### L10N-8: Categorías transfer buscan por nombre en español
- [x] **Detalle:** Ya documentado en BUG-11, incluido aquí por completitud — verificado OK (resuelto con BUG-11 fix, usa IDs estables)

---

## 2.6 EMPTY — Estados vacíos

### EMPTY-4: AccountSelectorSheet sin empty state
- [x] **Archivo:** `App/Views/Transactions/AccountSelectorSheet.swift` — ya tiene `YalaEmptyState.noAccounts()` (flow review)
- **Impacto:** Si 0 cuentas activas, el usuario ve ScrollView vacío

### EMPTY-5: Autocomplete sin feedback "sin resultados"
- [x] **Archivo:** `App/Views/Transactions/NewTransactionView.swift:900-906` — Enhanced with Label+tag icon (552c664)
- **Impacto:** Al escribir `#` sin tags que coincidan, el popover simplemente desaparece sin explicación

---

## 2.7 CODE — Calidad/Mantenimiento

### CODE-12: Delete bypasea TransactionService
- [-] **Archivo:** `App/Views/Transactions/NewTransactionView.swift:1194-1209` — reemplazo naive causa data corruption con transfer pairs, skip
- **Impacto:** La vista llama `modelContext.delete()` directamente en vez de `TransactionService.shared.delete()`
- **Fix:** Usar TransactionService para mantener un solo code path

### CODE-13: DateFormatter creado en cada render
- [x] **Archivo:** `App/Views/Transactions/NewTransactionView.swift` → `private static let shortDateFormatter` (flow review)
- **Detalle:** `dateChipText` computed property crea `DateFormatter()` en cada evaluación del body
- **Fix:** `static let` formatter

### CODE-14: ExchangeRateInputView posiblemente dead code
- [x] **Archivo:** `ExchangeRateInputView.swift` — archivo eliminado (flow review BAJA batch)

### CODE-15: `onCreateAnother` no re-aplica `prefillAccountID`
- [x] **Archivo:** `App/Views/Transactions/NewTransactionView.swift:73-81` — verificado OK (prefillAccountID se re-aplica correctamente)
- **Impacto:** Al crear otro después de guardar, se pierde la cuenta por defecto del contexto original

### CODE-16: Success screen solo muestra monto origen en transfers
- [x] **Archivo:** `App/Views/Transactions/TransactionSuccessView.swift:141-150` — Muestra formato `$100 USD → S/370 PEN` para transfers multi-moneda
- **Impacto:** Para transfers multi-moneda, el monto destino solo aparece como texto pequeño

### CODE-17: No widget update después de guardar recurring
- [x] **Archivo:** `App/Views/Transactions/SaveAsRecurringSheet.swift:793-801`
- **Impacto:** Widgets de scheduled payments no reflejan el nuevo pago hasta próximo refresh cycle

### CODE-18: `isSaving` progress nunca se muestra visualmente
- [-] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift:470` — Descartado: `isSaving` YA muestra ProgressView en botón save
- **Detalle:** `context.save()` es sincrónico en @MainActor — el flag se setea y limpia antes de que UI pueda renderizar el indicador

### CODE-19: SaveAsRecurringSheet monto con ancho fijo 80pt
- [x] **Archivo:** `App/Views/Transactions/SaveAsRecurringSheet.swift:259` — `.frame(width: 80)` → `.fixedSize()`
- **Impacto:** Se trunca con montos grandes o Dynamic Type

### CODE-20: Tags relationship sin `inverse` explícito
- [x] **Archivo:** `Models/TransactionItem.swift:32` — Already resolved: Tag.swift:23 declares `inverse: \TransactionItem.tags`. SwiftData only needs one side; adding both causes circular reference error.
- **Detalle:** `@Relationship(deleteRule: .nullify) var tags: [Tag]?` — sin `inverse:` declarado
- **Regla:** CLAUDE.md dice "SIEMPRE `@Relationship(inverse:)` en relaciones bidireccionales"

### CODE-21: Triple save en creación de transfer
- [ ] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift`
- **Detalle:** `ensureTransferCategory()` hace save, `ensureIncomeTransferCategory()` hace save, luego `save()` hace save final. 3 saves para una operación

---

## 2.8 Validaciones — Verificación

Lo que funciona correctamente:
- ✅ Amount > 0 requerido
- ✅ Account requerida (ambas para transfers)
- ✅ Subcategory requerida para no-transfers
- ✅ Future date bloqueada al hacer Save
- ✅ Categorías filtradas por income/expense correctamente
- ✅ Subcategorías filtradas por categoría seleccionada
- ✅ Multi-select de tags funciona
- ✅ Exchange rate bidireccional source↔dest funciona
- ✅ Widget update después de save (excepto recurring)
- ✅ Keyboard dismiss antes de abrir sheets
- ✅ Expenses-only mode restringe type selector
- ✅ Favoritos aplican campos correctamente
- ✅ Thread safety: todo @MainActor
- ✅ Error handling usa do/catch (no try?)

# 3. STATISTICS

## 3.1 BUGS

### BUG-14: Bulk account change no recalcula exchangeRate/amountInPreferredCurrency
- [x] **Archivo:** `App/ViewModels/RecordsViewModel.swift:393-407` — Resuelto (2eb7acc)
- **Impacto:** Al cambiar cuenta en bulk edit a una con distinta moneda, `currencyCode` se actualiza pero `amountInPreferredCurrency` y `exchangeRate` quedan stale. Datos financieros incorrectos
- **Fix:** Recalcular con CurrencyConverter después de cambiar cuenta

### BUG-15: Bulk amount edit ignora signo de transacción
- [x] **Archivo:** `App/ViewModels/RecordsViewModel.swift:480-492` — Resuelto (2eb7acc)
- **Impacto:** Setea todas las transacciones seleccionadas con monto positivo. Gastos se convierten en valores de ingreso
- **Fix:** Preservar signo original: `amount * (transaction.amount < 0 ? -1 : 1)`

### BUG-16: Period comparison chart ignora filtros de currency/amount/search
- [x] **Archivo:** `App/Views/Statistics/TrendsTabView.swift:1535-1546` — Resuelto (7d5f379)
- **Impacto:** Chart de comparación usa `selectedCurrencies: []`, `amountCondition: .any`, `searchText: ""` hardcodeados. Inconsistente con el trend chart principal que SÍ los respeta
- **Fix:** Usar valores reales del viewModel

### BUG-17: No hay "Deselect All" en modo selección
- [x] **Archivo:** `App/Views/Records/RecordsStandaloneView.swift` — Resuelto (batch 4)
- **Impacto:** `deselectAll()` existe en VM (línea 292) pero no hay botón en UI. Usuario debe cancelar y re-entrar
- **Fix:** Agregar toggle Select All / Deselect All

### BUG-18: Bulk delete no maneja transferencias (borra solo un lado)
- [x] **Archivo:** `App/ViewModels/RecordsViewModel.swift:309-330` — Resuelto (batch 4)
- **Impacto:** Misma raíz que BUG-8 — sin `transferPairID`, no puede encontrar la pareja
- **Nota:** Compartido con BUG-8/BUG-13 (problema sistémico de transfers)

### BUG-19: CategoriesTabView `activeFilterCount` no cuenta todos los filtros
- [x] **Archivo:** `App/Views/Statistics/CategoriesTabView.swift:1438-1446` — Resuelto (872390a)
- **Impacto:** Solo cuenta 5 de 9 tipos de filtro. Botón "Clear All" podría no aparecer con filtros de currency/amount/search activos
- **Fix:** Usar `viewModel.activeFilterCount` que cuenta 8 tipos

---

## 3.2 HIGH

### HIGH-11: RecordRowView sin accessibility labels
- [x] **Archivo:** `App/Views/Records/Components/RecordRowView.swift`
- **Impacto:** VoiceOver no puede describir transacciones. Zero `.accessibilityLabel` en el row completo
- **Fix:** accessibilityLabel + accessibilityAddTraits(.isSelected) (320f5dd)

### HIGH-12: Sin paginación en Records — todo cargado en memoria
- [>] **Archivo:** `App/ViewModels/RecordsViewModel.swift:188-227`
- **Impacto:** Con miles de transacciones en un período, FilterService hace scan lineal de todas. LazyVStack ayuda en render pero no en datos
- **Fix:** Agregar fetchLimit o paginación progresiva

### HIGH-13: Double observer firing — recálculo duplicado por cambio de filtro
- [>] **Archivo:** `App/Views/Records/RecordsStandaloneView.swift:520-705`
- **Impacto:** RecordsViewModel properties son computed pass-throughs a SessionState. Los observers escuchan ambos, causando doble `refreshRecordsData()` por cada cambio

### HIGH-14: DateFormatter creado en cada render en CompactRecordRow
- [x] **Archivo:** `App/Views/Statistics/TrendsTabView.swift:1767-1772` — Resuelto (f9755d5)
- **Fix:** Usar static formatter o YalaFormatter

### HIGH-15: Bulk delete usa `groupedRecords` que puede estar stale
- [x] **Archivo:** `App/ViewModels/RecordsViewModel.swift:311-316` — Resuelto (f9755d5)
- **Fix:** Usar `context.model(for: id)` como hace `getSelectedTransactions()`

---

## 3.3 DS — Violaciones Design System

### DS-13: `Color.gray` para FAB locked en DetailContainerView
- [x] **Archivo:** `App/Views/Statistics/DetailContainerView.swift` — ya usa `DS.Semantic.disabledForeground` (flow review)
- **Fix:** `DS.Semantic.disabledForeground`

### DS-14: Opacity inconsistente `0.1` vs `DS.Opacity.subtle`
- [x] **Archivo:** `App/Views/Statistics/TrendsTabView.swift:1161` — verificado OK (DS.Opacity.subtle = 0.1, valor correcto)
- **Detalle:** "View all" usa hardcoded `0.1`, CategoriesTabView usa `DS.Opacity.subtle`

### DS-15: Padding hardcodeado en CategoryDetailView
- [x] **Archivo:** `App/Views/Categories/CategoryDetailView.swift:344, 350, 239`
- **Detalle:** `16`, `8`, `56` hardcodeados — debería usar `DS.Spacing`

### DS-16: FAB pulse animation ignora Reduce Motion
- [x] **Archivo:** `App/Views/Statistics/DetailContainerView.swift:520-524`
- **Detalle:** Mismo patrón que A11Y-3 del Panel — `.phaseAnimator` sin check de `accessibilityReduceMotion`

### DS-17: Tamaños hardcodeados en BulkEditSheet
- [x] **Archivos:** `BulkEditSheet.swift` — ya usa `DS.Icon.badgeLarge` y `DS.FormRow.iconWidth` (flow review)
- **Fix:** Tokens DS

---

## 3.4 A11Y — Accesibilidad

### A11Y-22: Category/Subcategory list rows usan `onTapGesture`
- [x] **Archivo:** `App/Views/Statistics/CategoriesTabView.swift:1521-1525` — verificado OK (ya usa Button)
- **Regla:** UI-PATTERNS "Button + buttonStyle(.plain)"

### A11Y-23: Metric selector buttons sin accessibility labels
- [x] **Archivo:** `App/Views/Statistics/TrendsTabView.swift:780-818`
- **Impacto:** VoiceOver lee nombre de SF Symbol en vez de "Balance", "Ingreso", "Gasto"

### A11Y-24: Comparison mode buttons sin labels descriptivos
- [x] **Archivo:** `App/Views/Statistics/TrendsTabView.swift:433-458`
- **Detalle:** Botones "P-1" / "A-1" sin explicación

### A11Y-25: Cash flow view selector buttons sin labels
- [x] **Archivo:** `App/Views/Statistics/TrendsTabView.swift:906-951`

### A11Y-26: "Clear All" buttons sin accessibility labels
- [x] **Archivos:** TrendsTabView, CategoriesTabView, RecordsTabView — botones de xmark sin label

### A11Y-27: Hardcoded Spanish a11y en PeriodComparisonChartView
- [x] **Archivo:** `PeriodComparisonChartView.swift` → `L10n.Accessibility.periodComparison` + `noData` + `periodComparisonValue` (flow review + a11y batch)

### A11Y-28: Hardcoded Spanish a11y en RecordsStandaloneView
- [x] **Archivo:** `RecordsStandaloneView.swift` → `L10n.Action.select`, `.Filters.title`, `.Action.delete`, `.Action.edit`, `.Accessibility.createAccountFirst` (flow review + a11y batch)

### A11Y-29: CategorySelectorSheet expand usa `onTapGesture`
- [x] **Archivo:** `App/Views/Filters/Components/CategorySelectorSheet.swift:169` — verificado OK (ya usa Button)
- **Fix:** Usar Button para expand/collapse

---

## 3.5 L10N — Localización

### L10N-9: "Todas" hardcodeado en RecordsFiltersViewModel (8 instancias)
- [x] **Archivo:** `App/ViewModels/RecordsFiltersViewModel.swift:122, 125, 134, 139, 146, 158, 163, 166`
- **Fix:** `L10n.Common.all` (48baa83)

### L10N-10: "Categoria"/"Categorias" fallback en FilterControlBar
- [x] **Archivo:** `App/Views/Filters/FilterControlBar.swift` — migrado a L10n (l10n batches)

### L10N-11: "Quitar filtro" en FilterChipView
- [x] **Archivo:** `App/Views/Filters/FilterChipView.swift` — migrado a L10n (l10n batches)

### L10N-12: Spanish hardcodeado en RecordsModels
- [x] **Archivo:** `App/Models/RecordsModels.swift:23-24, 49-53`
- **Detalle:** → L10n.Transaction.TransactionType.* + L10n.Common.all (c6dca6f)

### L10N-13: "Cancelar" hardcodeado en SubcategoryDetailView
- [x] **Archivo:** `App/Views/Categories/SubcategoryDetailView.swift:144` → L10n.Action.cancel (c6dca6f)

---

## 3.6 EMPTY

### EMPTY-6: Empty states no usan `YalaEmptyState` en tabs de Statistics
- [x] **Archivos:** TrendsTabView y CategoriesTabView ya usan `YalaEmptyState` (flow review). RecordsTabView pendiente post-release
- **Nota:** 2/3 tabs migrados

---

## 3.7 CODE — Calidad/Mantenimiento

### CODE-22: `clearAllFilters()` en StatisticsViewModel es dead code incompleto
- [x] **Archivo:** `StatisticsViewModel.swift` — dead code eliminado (flow review BAJA batch)

### CODE-23: ~130 líneas dead code en `calculateAggregatedTrend`
- [x] **Archivo:** `StatisticsViewModel.swift` — dead code eliminado (flow review BAJA batch)

### CODE-24: No-op sync functions (7 funciones vacías)
- [x] **Archivos:** `DetailContainerView.swift`, `StatisticsViewModel.swift`, `RecordsViewModel.swift`
- **Fix:** Eliminadas 8 funciones no-op + ~15 call sites en 6 archivos

### CODE-25: FilterControlBar componente no usado
- [x] **Archivo:** `App/Views/Filters/FilterControlBar.swift` — archivo eliminado (flow review BAJA batch)
- **Detalle:** Ya no existe

### CODE-26: Chip data structs duplicadas en 3 tabs
- [x] **Archivos:** TrendsTabView, CategoriesTabView, RecordsTabView — Extraídas a `FilterChipModels.swift`
- **Detalle:** AccountChip, CategoryChip, TagChip, NatureChipData definidos independientemente con estructura idéntica

### CODE-27: Bulk note editor no permite limpiar notas
- [x] **Archivo:** `App/Views/Records/BulkEditSheet.swift` — verificado OK (diseño intencional, evita limpiar notas accidentalmente)
- **Detalle:** Save button disabled cuando nota vacía. `bulkUpdateNote` acepta string vacío pero UI lo bloquea

### CODE-28: Bulk delete bypasea EntityDeletionService
- [ ] **Archivo:** `App/ViewModels/RecordsViewModel.swift:309-330`
- **Detalle:** Llama `context.delete()` directamente

### CODE-29: `DispatchQueue.main.async` redundante en refreshRecordsData
- [x] **Archivo:** `App/Views/Records/RecordsStandaloneView.swift:419` — verificado OK (ya removido en flow review)
- **Detalle:** Ya está en @MainActor

---

## 3.8 Filtrado & Charts — Verificación

Lo que funciona correctamente:
- ✅ SSOT via SessionState.shared — cambio de filtro en un tab afecta los otros
- ✅ Period selector funciona (day/week/month/year/allTime/custom)
- ✅ Custom date range validado y persistido
- ✅ Expenses-only mode manejado comprehensivamente
- ✅ Category pie dimming correcto (muestra todo, atenúa no seleccionados)
- ✅ Tags KPI respeta filtros de category/subcategory
- ✅ Nature widget excluye nature filter pero respeta otros
- ✅ Cash flow respeta todos los filtros
- ✅ Previous period calculation correcta (PreviousPeriodHelper)
- ✅ Single data point rendering con PointMark fallback
- ✅ Negative amounts correctos (income >0, expense <0)
- ✅ Period comparison date alignment (4 estrategias)
- ✅ Transaction grouping por fecha descendente correcto
- ✅ Tag multi-state en bulk edit (common/partial/available)
- ✅ DS compliance excelente en filter UI (Liquid Glass, tokens)

# 4. PLANNING — BUDGETS

## 4.1 BUGS

### BUG-20: Zero o negative limit amount aceptado — sin validación
- [x] **Archivo:** `App/Views/Planning/BudgetEditorView.swift:656` — Resuelto (872390a)
- **Impacto:** `canSave` solo verifica que `Double(limitAmount) != nil`. Limit=0 → inmediatamente "exceeded". Limit negativo → comportamiento indefinido
- **Fix:** Añadir `(Double(limitAmount) ?? 0) > 0`

### BUG-21: BudgetAlertService usa `accounts?.first?.currencyCode` en vez de `budget.currencyCode`
- [x] **Archivo:** `Services/BudgetAlertService.swift:103-104` — Resuelto (872390a)
- **Impacto:** Con múltiples cuentas, toma la primera (orden no determinístico en SwiftData). La moneda en la notificación puede ser incorrecta
- **Fix:** Usar `budget.currencyCode`

### BUG-22: BudgetAlertTracker no limpia entries semanales/anuales/únicas
- [x] **Archivo:** `Services/BudgetAlertTracker.swift:88-117` — Resuelto (batch 4)
- **Impacto:** Cleanup solo reconoce patterns "yyyy-MM". Keys semanales ("2025-W03"), anuales ("2026") y únicas nunca se limpian → UserDefaults crece indefinidamente

### BUG-23: Spending calculation duplicada entre BudgetsViewModel y BudgetAlertService
- [x] **Archivos:** `App/ViewModels/BudgetsViewModel.swift:354+` y `Services/BudgetAlertService.swift:155-204` — Resuelto (batch 4, static shared method)
- **Impacto:** Comment literal dice "copied from BudgetsViewModel". Si uno cambia, el otro no se actualiza
- **Fix:** Extraer a función compartida

### BUG-24: BudgetEditorView save no setea `needsBudgetsWidgetRefresh`
- [x] **Archivo:** `App/Views/Planning/BudgetEditorView.swift:655-678` — Resuelto (872390a)
- **Impacto:** Delete sí lo setea (línea 685), pero save no. BudgetsWidget en Panel no se refresca al crear/editar presupuesto

---

## 4.2 HIGH

### HIGH-16: BudgetsViewModel.loadData() carga TODAS las transacciones
- [x] **Archivo:** `App/ViewModels/BudgetsViewModel.swift:196-204` — Resuelto (f9755d5)
- **Impacto:** Sin predicate de fecha. Con miles de transacciones, cada carga es costosa

### HIGH-17: BudgetAlertService también carga todas las transacciones sin predicate
- [x] **Archivo:** `Services/BudgetAlertService.swift:58-59` — Resuelto (f9755d5)
- **Detalle:** `FetchDescriptor<TransactionItem>()` sin filtro

---

## 4.3 DS

### DS-18: BudgetProgressBar sin color warning (solo verde→rojo)
- [x] **Archivo:** `App/Views/Planning/Components/BudgetProgressBar.swift:26-29`
- **Impacto:** Binario: color del budget vs hotPink al 100%. Sin indicador visual en 75-99%
- **Fix:** Añadir `DS.Semantic.warningForeground` para rango 75-99%

### DS-19: BudgetRowView usa `DS.Radius.md` en vez de `DS.Radius.card`
- [x] **Archivo:** `App/Views/Planning/BudgetRowView.swift:69, 72` — verificado OK (DS.Radius.md es correcto para este componente)

---

## 4.4 A11Y

### A11Y-30: BudgetRowView sin accessibility label combinado
- [x] **Archivo:** `App/Views/Planning/BudgetRowView.swift`
- **Fix:** "Presupuesto Comida, 75% gastado, 500 de 1000 soles"

### A11Y-31: BudgetEditorView Picker de período con label vacío
- [x] **Archivo:** `App/Views/Planning/BudgetEditorView.swift:199`
- **Detalle:** `Picker("", selection:)` → VoiceOver no anuncia nada

### A11Y-32: Hardcoded Spanish "Excedido", "Cerrar", "Plantillas favoritas"
- [x] **Archivos:** BudgetProgressBar.swift → L10n.Accessibility.exceeded, PlanningView.swift → L10n.Accessibility.favoriteTemplates (c6dca6f)
- [x] BudgetEditorView.swift:112 ("Cerrar") → L10n.Action.close (48baa83)

---

## 4.5 L10N

### L10N-14: Hardcoded Spanish en budget views
- [x] **Archivos:** Todos migrados a L10n (l10n batches + flow review)
- [x] BudgetEditorView.swift:112 ("Cerrar") → `L10n.Action.close` (48baa83)

---

## 4.6 CODE

### CODE-30: Legacy fields `month`, `year`, `category` en Budget model nunca usados
- [x] **Archivo:** `Models/Budget.swift:19-24` — Removed month/year (552c664). category kept (used in CategoryDeduplicationService), currencyCode/limitAmount kept (CloudKit compat).

### CODE-31: `isPaidForCurrentCycle` en modelo es dead code
- [x] **Archivo:** `ScheduledPayment.swift` — dead code eliminado (flow review BAJA batch)

### CODE-32: BudgetPeriodSelectorSheet custom scroll picker frágil
- [x] **Archivo:** `App/Views/Planning/Components/BudgetPeriodSelectorSheet.swift` — Migrated 3 DispatchQueue.main.asyncAfter → Task.sleep (552c664)
- **Detalle:** Reimplementa Picker wheel con GeometryReader, snap timing hardcodeado (0.15s)

### CODE-33: WidgetDataCache.updateCache no se llama en BudgetEditorViewModel.deleteBudget
- [x] **Archivo:** `App/ViewModels/BudgetEditorViewModel.swift:206-220` — verificado OK (ya agregado en flow review)

---

## 4.7 Verificación

- ✅ Budget spending respeta filtros de account/subcategory/tag/nature
- ✅ Period navigation weekly/monthly/yearly/unique funciona
- ✅ Alert threshold tracking con keys por período
- ✅ Budget favorites ordering funciona
- ✅ Archive/active toggle funciona
- ✅ Error handling con do/catch (no try?)
- ✅ DS tokens usados consistentemente (excepto DS-18/19)

---

# 5. PLANNING — SCHEDULED PAYMENTS

## 5.1 BUGS

### BUG-25: `getPaymentDatesInMonth` NO respeta `endDate` — pagos generan ocurrencias infinitas
- [x] **Archivo:** `Yala/Utils/ScheduledPaymentDateCalculator.swift` (extraído)
- **Fix:** fe3142c — Post-filtro `endDate` inclusivo en `applyPostFilters()`

### BUG-26: Weekly recurrence ignora `recurrenceInterval` — "cada 2 semanas" muestra todas las semanas
- [x] **Archivo:** `Yala/Utils/ScheduledPaymentDateCalculator.swift` (extraído)
- **Fix:** fe3142c — Week offset vía `dateInterval(of: .weekOfYear)` + `daysBetween / 7 % interval`

### BUG-27: Monthly recurrence ignora `recurrenceInterval` — "trimestral" muestra todos los meses
- [x] **Archivo:** `Yala/Utils/ScheduledPaymentDateCalculator.swift` (extraído)
- **Fix:** fe3142c — Month arithmetic `(year2-year1)*12 + (month2-month1) % interval`

### BUG-28: Daily recurrence puede loop infinito
- [x] **Archivo:** `Yala/Utils/ScheduledPaymentDateCalculator.swift` (extraído)
- **Fix:** fe3142c — Safety counter (400) + `guard let` con `break` + `max(1, interval)`

### BUG-29: `getPaymentDatesInMonth` duplicado en Widget — 5 bugs idénticos en 2 archivos
- [x] **Archivos:** VM y Widget delegan a `ScheduledPaymentDateCalculator.paymentDatesInMonth()`
- **Fix:** fe3142c — 17 tests en `ScheduledPaymentDateCalculatorTests`
- **Bonus:** Widget ahora incluye filtro `createdAt` (antes faltaba)

### BUG-30: Editor permite amount=0 o negativo
- [x] **Archivo:** `App/Views/Planning/ScheduledPaymentEditorView.swift:831-837` — Resuelto (872390a)
- **Impacto:** `canSave` verifica `Double(amount) != nil` pero no `> 0`

---

## 5.2 HIGH

### HIGH-18: Deletion no cancela notificaciones pendientes ni limpia InboxDrafts
- [x] **Archivo:** `Services/EntityDeletionService.swift:129-131`
- **Impacto:** Al borrar scheduled payment: drafts con `sourceScheduledPaymentID` quedan huérfanos, notification requests no se cancelan, tracker entries no se limpian
- **Fix:** Limpieza de tracker UserDefaults + orphan pending drafts (320f5dd)

### HIGH-19: Notificaciones solo verifican `nextDueDate`, no ocurrencias generadas
- [x] **Archivo:** `Services/ScheduledPaymentNotificationService.swift:33-68`
- **Impacto:** Pago semanal Mon/Wed/Fri con nextDueDate=Monday → notificaciones de Wed y Fri nunca se envían
- **Fix:** Usa DateCalculator para todas las ocurrencias del mes con ventana 7 días (320f5dd)

### HIGH-20: Yearly payment on Feb 29 desaparece en años no bisiesto
- [x] **Archivo:** `Utils/ScheduledPaymentDateCalculator.swift:180-184` — Resuelto (f9755d5)
- **Impacto:** `Calendar.date(from: DateComponents(year: 2027, month: 2, day: 29))` retorna nil → pago invisible ese año

### HIGH-21: `paidStatus` en Widget como computed var = N+1 query en cada render
- [x] **Archivo:** `App/Views/Panel/ScheduledPaymentsWidget.swift:95-97`
- **Impacto:** 2 SwiftData queries en cada evaluación del body (ya documentado como HIGH-1)
- **Fix:** Resuelto junto con HIGH-1 — @State + onAppear/onChange (320f5dd)

---

## 5.3 DS

### DS-20: `.orange` hardcodeado para estado inactivo
- [x] **Archivo:** `App/Views/Planning/ScheduledPaymentDetailView.swift:201-206` — verificado OK (ya usa DS.Semantic.warningForeground)

---

## 5.4 A11Y

### A11Y-33: Hardcoded Spanish en toolbar buttons (8 instancias)
- [x] **Archivos:** ScheduledPaymentEditorView:129 ("Cerrar"→L10n), ScheduledPaymentDetailView:107 ("Atrás"→L10n), ScheduledPaymentsSettingsView:47,52 (→L10n), TransactionAssociationSheet:38 (→L10n) — 48baa83
- [x] **Pendiente resuelto:** Todos migrados a L10n (flow review + a11y batches)

---

## 5.5 L10N

### L10N-15: NSLocalizedString en ScheduledPaymentDetailView strings
- [x] **Archivo:** `App/Views/Planning/ScheduledPaymentDetailView.swift`
- **Detalle:** Múltiples strings con pattern inconsistente

---

## 5.6 CODE

### CODE-34: `loadPaidStatus` duplicado en Widget y ViewModel
- [x] **Archivos:** Widget:99-152 vs ViewModel:247-302 — Extraído a `ScheduledPaymentPaidStatusHelper`

### CODE-35: Filter logic triplicada en getSubscriptions/getRecurringPayments/calculatePaymentData
- [x] **Archivo:** `App/ViewModels/ScheduledPaymentsViewModel.swift:550-629, 307-367` — Extraído a `applyPaymentFilters(_:)`

### CODE-36: DateFormatter creado en computed properties (5+ instancias)
- [x] **Archivos:** Todos migrados a `private static let` (flow review): ViewModel (`monthYearFormatter`), DetailView (ya tenía 4 static), ListView (`longDateFormatter`), Widget (`monthYearFormatter`+`shortDateFormatter`), TransactionAssociationSheet (`mediumDateFormatter`)

### CODE-37: ScheduledPaymentsSettingsViewModel.deletePayments bypasea EntityDeletionService
- [x] **Archivo:** `App/ViewModels/ScheduledPaymentsSettingsViewModel.swift` — ya usa `EntityDeletionService.shared` (flow review)

### CODE-38: `recurrenceInterval` picker permite hasta 30 para todos los tipos
- [x] **Archivo:** `App/Views/Planning/ScheduledPaymentEditorView.swift:538-543`
- **Detalle:** "Cada 30 años" no tiene sentido

### CODE-39: `isPaidForCurrentCycle` en modelo es dead code
- [x] **Archivo:** `ScheduledPayment.swift` — dead code eliminado (flow review BAJA batch) (duplicado de CODE-31)

---

## 5.7 Verificación

- ✅ Skip dates con `skippedDatesRaw` bien diseñado
- ✅ Draft service robusto — previene duplicados, avanza nextDueDate
- ✅ Paid status verifica tanto InboxDraft como TransactionItem
- ✅ Calendar respeta firstWeekday del usuario
- ✅ Error handling con do/catch (no try?)
- ✅ DS tokens consistentes (excepto DS-20)
- ✅ Period selector pulido con labels inteligentes

# 6. INBOX

## 6.1 BUGS

### BUG-31: Approval logic duplicada — Merchant Memory solo aprende desde EditSheet
- [x] **Archivos:** `App/Views/Inbox/InboxDraftEditSheet.swift:900-1005` vs `Services/DraftService.swift:139-217` — Resuelto (batch 4)
- **Impacto:** `createTransactionAndApprove` en EditSheet incluye merchant memory update + nature override que `DraftService.approveDraft` NO tiene. Swipe-approve y bulk-approve no enseñan al sistema de auto-categorización
- **Fix:** Unificar lógica en DraftService

### BUG-32: Bulk subcategory selector hardcodeado a `.expense`
- [x] **Archivo:** `App/Views/Inbox/InboxBulkActionsSheet.swift:182` — Resuelto (batch 4)
- **Impacto:** Si drafts seleccionados incluyen ingresos, solo se muestran subcategorías de gastos
- **Fix:** Detectar tipo mixto o permitir selección por tipo

### BUG-33: Archived count badge no coincide con items visibles
- [x] **Archivo:** `App/ViewModels/InboxViewModel.swift:126-133` — Resuelto (872390a)
- **Impacto:** `countForFilter(.archived)` no verifica `cachedAccountName != nil` pero `filteredDrafts(.archived)` sí. Badge puede mostrar número mayor al contenido real

---

## 6.2 HIGH

### HIGH-22: MerchantMemoryService.findMemory fetcha ALL records para fuzzy matching
- [x] **Archivo:** `App/Services/MerchantMemoryService.swift:151-177` — Resuelto (f9755d5)
- **Impacto:** Con miles de merchants, scan lineal completo

### HIGH-23: Bulk approve no verifica cuentas archivadas
- [x] **Archivo:** `Services/DraftService.swift:241` — Resuelto (f9755d5)
- **Impacto:** Puede crear transacciones contra cuentas archivadas (single approve SÍ verifica)

---

## 6.3 DS

### DS-21: InboxBulkActionsSheet usa colores raw (.blue, .purple, .green, .orange, .red)
- [x] **Archivo:** `App/Views/Inbox/InboxBulkActionsSheet.swift:49`
- **Fix:** `.purple` → `DS.Semantic.infoForeground`

### DS-22: InboxDraftEditSheet usa `Color(UIColor.label).opacity(0.08)` y `0.05`
- [x] **Archivo:** `InboxDraftEditSheet.swift` — `Color(UIColor.*)` eliminados (flow review)

---

## 6.4 A11Y

### A11Y-34: Hardcoded Spanish a11y en InboxView (5+ instancias)
- [x] **Archivos:** InboxView.swift → `L10n.Filters.selectAll`/`deselectAll`, `L10n.Accessibility.selectAtLeastOneDraft`, toolbar buttons via `L10n.Action.*` (flow review + a11y batch)

### A11Y-35: Hardcoded Spanish a11y en InboxDraftEditSheet
- [x] **Archivo:** InboxDraftEditSheet.swift → `L10n.Action.delete`, `L10n.Inbox.reject`, `L10n.Accessibility.approveCompleteHint`, toolbar via `L10n.Action.*` (flow review + a11y batch)

### A11Y-36: Hardcoded Spanish a11y en VoiceRecordingView (6 instancias)
- [x] **Archivo:** App/Views/Voice/VoiceRecordingView.swift → L10n.Accessibility.* (5 labels) (c6dca6f)

### A11Y-37: InboxDraftRowView sin accessibility labels
- [x] **Archivo:** App/Views/Inbox/InboxDraftRowView.swift
- **Fix:** Label "Borrador: [nota], [monto], [estado]"

### A11Y-38: Hardcoded Spanish en ImageSelectionView
- [x] **Archivo:** `ImageSelectionView.swift` — migrado a L10n (a11y/l10n batches)

---

## 6.5 L10N

### L10N-16: DraftService error string hardcodeado en español
- [x] **Archivo:** `Services/DraftService.swift:420` → L10n.Inbox.errorFutureDate (c6dca6f)

### L10N-17: VoiceTranscriptionService defaults a Spanish para non-English
- [x] **Archivo:** `Services/VoiceTranscriptionService.swift:64-66`
- **Impacto:** Portuguese, French, German users get Spanish transcription

---

## 6.6 CODE

### CODE-40: DispatchQueue.main.asyncAfter(0.3) frágil en InboxView (3 instancias)
- [x] **Archivo:** `App/Views/Inbox/InboxView.swift:138, 150, 181` — Migrado a `Task { try? await Task.sleep(for:) }`

### CODE-41: Direct modelContext.save() bypasea DraftService
- [ ] **Archivo:** `App/Views/Inbox/InboxView.swift:544-555`

### CODE-42: Timer en VoiceRecordingView no invalidado en onDisappear
- [x] **Archivo:** `App/Views/Voice/VoiceRecordingView.swift:681` — verificado OK (timer invalidado en stopRecording/cleanup)

### CODE-43: Image processing errors silently caught con `continue`
- [x] **Archivo:** `App/Views/Image/ImageSelectionView.swift:660-664` — verificado OK (continue en batch processing is correct, errors logged)

### CODE-44: Bulk approve silently salta drafts sin feedback
- [x] **Archivo:** `Services/DraftService.swift:227-229` — verificado OK (muestra count "N creadas", skipped drafts quedan en inbox)
- **Impacto:** Si 5 seleccionados y 2 tienen fecha futura, solo dice "3 creadas" sin explicar por qué 2 se saltaron

---

## 6.7 Verificación

- ✅ Draft lifecycle Pending→Approved/Rejected funciona
- ✅ Cached display values para drafts archivados
- ✅ Deduplication con Levenshtein bien testeada (15 tests)
- ✅ Merchant Memory con thresholds, corrections, decay, aliases
- ✅ Skip dates y one-time payments manejados
- ✅ Error handling con do/catch
- ✅ DS tokens consistentes en la mayoría de vistas

---

# 7. SEARCH

## 7.1 DS

### DS-23: Filter chips NO usan `.glassEffect()` — violación DS
- [x] **Archivo:** `App/ContentView.swift` — ya usa `.glassEffect(.regular.interactive(), in: .capsule)` (flow review)

### DS-24: Font hardcodeado `.font(.subheadline)` en vez de DS.Typography
- [x] **Archivo:** `App/ContentView.swift` — ya usa `DS.Typography.subheadline` (flow review)

### DS-25: Amount usa `DS.Typography.headline` en vez de `DS.Typography.amount`
- [x] **Archivo:** `App/ContentView.swift` — ya usa `DS.Typography.amount` (flow review)

### DS-26: Missing `contentShape(Rectangle())` en SearchResultRow
- [x] **Archivo:** `App/ContentView.swift` — ya tiene `.contentShape(Rectangle())` (flow review)

---

## 7.2 A11Y

### A11Y-39: Sin accessibility labels en filter chips ni result rows
- [x] **Archivo:** `App/ContentView.swift:905-928, 1074-1116`

### A11Y-40: Sin empty state cuando 0 transacciones y no hay búsqueda
- [x] **Archivo:** `App/ContentView.swift:871-889`

---

## 7.3 EMPTY

### EMPTY-7: Custom empty state en vez de `YalaEmptyState`
- [x] **Archivo:** `App/ContentView.swift` — ya usa `YalaEmptyState.noResults()` y `YalaEmptyState.noTransactions()` (flow review)

---

## 7.4 CODE

### CODE-45: Lógica de filtrado duplicada (~50 líneas) entre `filteredResults` y `totalMatchingCount`
- [x] **Archivo:** `App/ContentView.swift:763-812` y `815-858` — Extraído a `matchesSearch(_:search:filter:)`
- **Impacto:** Filtro ejecutado 2x en cada keystroke

### CODE-46: 470 líneas de search embebidas en ContentView.swift
- [x] **Archivo:** `App/ContentView.swift` → Extraído a `App/Views/Search/GlobalSearchView.swift`
- **Fix:** 5 structs/enums de búsqueda movidos a archivo dedicado (ContentView: 1212→796 LOC)

---

## 7.5 Verificación

- ✅ Búsqueda case-insensitive por substring
- ✅ 5 campos buscados (note, category, subcategory, account, tags)
- ✅ Resultados limitados a 20 con "Ver todo"
- ✅ "Ver todo" navega a Records con search pre-aplicado
- ✅ Todos los strings L10n (excepto separadores)
- ✅ Agrupación por fecha correcta

---

# 8. ONBOARDING

## 8.1 BUGS

### BUG-34: No se crea cuenta default durante onboarding
- [x] **Archivo:** `App/Views/Onboarding/OnboardingView.swift` — Resuelto (batch 4)
- **Impacto:** Usuario llega con 0 cuentas después de completar onboarding. Debe crear una manualmente

### BUG-35: Timer de SplashScreen nunca se invalida — memory/CPU leak
- [x] **Archivo:** `App/Views/SplashScreenView.swift:133` — Resuelto (batch 4)
- **Impacto:** Timer de 50ms sigue disparándose después de que la vista desaparece
- **Fix:** Guardar en @State e invalidar en .onDisappear

---

## 8.2 HIGH

### HIGH-24: Zero accessibility labels en todo el onboarding
- [>] **Archivos:** OnboardingView.swift, LanguageSelectionView.swift, SplashScreenView.swift
- **Impacto:** VoiceOver: progress dots sin descripción, radio buttons sin toggle semantics, currency rows sin contexto

---

## 8.3 DS

### DS-27: Frame sizes hardcodeados (52x52, 40x40, 100x100, 36x36)
- [x] **Archivo:** `App/Views/Onboarding/OnboardingView.swift:965, 670, 847, 886`
- **Fix:** @ScaledMetric o tokens DS

---

## 8.4 A11Y

### A11Y-41: Zero accessibility labels en onboarding completo
- [>] **Detalle:** Ya documentado en HIGH-24

---

## 8.5 L10N

### L10N-18: SeedCategoryPreview con nombres hardcodeados en español
- [x] **Archivo:** `App/Views/Onboarding/OnboardingView.swift` — migrado a L10n (l10n batches)

### L10N-19: "Usuario" hardcodeado como nombre default
- [x] **Archivos:** OnboardingView.swift:1140, PersonalDetailsView.swift:306 → L10n.Profile.defaultName (c6dca6f)
- **Nota:** @AppStorage defaults no pueden usar L10n (compile-time), solo runtime fallbacks corregidos

### L10N-20: Tiempo de notificación en formato 12h hardcodeado ("8:00 PM", "1:30 PM")
- [x] **Archivo:** `App/Views/Onboarding/OnboardingView.swift:826-828` → locale-aware DateFormatter (c6dca6f)

---

## 8.6 CODE

### CODE-47: DispatchQueue.main.asyncAfter para splash dismiss (inconsistente con structured concurrency)
- [x] **Archivo:** `App/ContentView.swift:236` — Migrado a `Task { try? await Task.sleep(for:) }`

---

## 8.7 Verificación

- ✅ 7 pasos de onboarding completos
- ✅ Currency region detection funciona
- ✅ Seed categories usan L10n correctamente (excepto preview)
- ✅ iCloud sync waiting con timeout y skip
- ✅ Language selection persistida
- ✅ ReduceMotion respetado en animaciones
- ✅ @ScaledMetric para iconos hero

---

# 9. PROFILE / SETTINGS

## 9.1 BUGS

### BUG-36: `.swipeActions` en NotificationCard no funciona — está en ScrollView, no List
- [x] **Archivo:** `App/Views/Settings/NotificationsSettingsView.swift:387` — Resuelto (batch 4, inline delete button)
- **Impacto:** Swipe-to-delete de notificaciones custom es completamente no funcional
- **Fix:** Botón delete explícito o migrar a List

### BUG-37: Voice/Image toggle queda ON cuando permiso es denegado — Resuelto (872390a)
- [x] **Archivo:** `App/Views/Profile/ProfileView.swift:476-485, 580-588` — Resuelto (872390a)
- **Impacto:** Toggle muestra "activo" pero la feature no funciona
- **Fix:** Set false cuando `status == .denied`

### BUG-38: Voice permission request ignora resultado del callback
- [x] **Archivo:** `App/Views/Profile/ProfileView.swift:480` — Resuelto (batch 4)
- **Detalle:** `AVAudioApplication.requestRecordPermission { _ in }` — resultado descartado

### BUG-39: Import success message hardcodeado en español
- [x] **Archivo:** `App/Views/Import/ImportIntroSheet.swift:616` — Resuelto (batch 4)
- **Detalle:** `"\(createdCount) registros importados correctamente."` — bypasea L10n

---

## 9.2 HIGH

### HIGH-25: Profile image almacenada en UserDefaults (@AppStorage)
- [x] **Archivo:** `App/Views/Profile/ProfileView.swift:32`
- **Impacto:** Foto 2-5MB en UserDefaults puede causar slowdowns. Anti-pattern de Apple
- **Fix:** ProfileImageStorage helper (Documents/profile.jpg), migración automática, DataWipeService cleanup (320f5dd)

### HIGH-26: Data wipe no advierte sobre eliminación de datos iCloud
- [x] **Archivo:** `App/Views/Settings/UserDataResetView.swift`
- **Impacto:** Borrar local propaga a iCloud, afecta otros dispositivos sin aviso
- **Fix:** L10n settings.wipeICloudWarning en 6 idiomas (320f5dd)

---

## 9.3 DS

### DS-28: `Typography.title2` vs `DS.Typography.title2` inconsistente — YA usan DS.Typography
- [x] **Archivos:** CurrencySettingsView.swift:71-76, ImportIntroSheet.swift, ThemeSettingsView.swift — YA usan `DS.Typography.title2`

---

## 9.4 A11Y

### A11Y-42: Toggle labels vacíos en todas las settings views
- [x] **Patrón:** `Toggle("", isOn:).labelsHidden()` — VoiceOver dice solo "toggle" sin contexto
- **Fix:** `Toggle(L10n.Settings.xxx, isOn:).labelsHidden()`

### A11Y-43: Color picker en TagFormView sin labels de selección
- [x] **Archivo:** `App/Views/Tags/TagFormView.swift:193-209`
- **Impacto:** Solo indicadores visuales de selección, inaccesible para VoiceOver

---

## 9.5 L10N

### L10N-21: Hardcoded Spanish en ~46 toolbar a11y labels ("Cerrar", "Atrás", "Agregar")
- [x] **Archivos:** 66 archivos migrados a `L10n.Action.{close,back,add}`
- **Fix:** 48baa83 — "Cerrar"(42), "Atrás"(26), "Agregar"(6) reemplazados

### L10N-22: Date format hardcodeado en español en CurrencySettingsView
- [x] **Archivo:** `App/Views/Settings/CurrencySettingsView.swift` — formato `"d 'de' MMMM"` reemplazado por `.dateStyle` locale-aware (flow review)

### L10N-23: Múltiples strings de settings sin L10n
- [x] **Archivos:** Todos migrados a L10n (l10n batches)

---

## 9.6 CODE

### CODE-48: Dead code `notificationsList` en NotificationsSettingsView
- [x] **Archivo:** `NotificationsSettingsView.swift` — legacy code eliminado, refactorizado a `notificationsListWithBudgetAlerts` (flow review BAJA batch)

### CODE-49: DispatchQueue.main.asyncAfter en ~10 locations de Profile/Import
- [x] **Archivos:** ProfileView:148, ImportIntroSheet:366,464,499,522,627,731, ThemeSettingsView:94 — Migrados a `Task { try? await Task.sleep(for:) }`

### CODE-50: Unused @AppStorage("defaultPeriod") en ProfileView
- [x] **Archivo:** `ProfileView.swift` — dead code eliminado (flow review BAJA batch)

---

## 9.7 Verificación

- ✅ Biometric lock: Keychain storage, timeout logic, passcode fallback
- ✅ Data wipe: @Query crash prevention, progressive cleanup
- ✅ Theme switching: real-time, no app restart needed
- ✅ Currency settings: continent grouping, historical rates
- ✅ Export wizard: 3 pasos, filtros, columnas configurables
- ✅ Tag form: icon + color picker funciona
- ✅ Account settings: reorder, archive, preferred, exclude

---

# 10. SUBSCRIPTION / PAYWALL

## 10.1 BUGS

### BUG-40: StoreKitManager no es reactivo en SubscriptionView
- [x] **Archivo:** `App/Views/Settings/SubscriptionView.swift:17` — Resuelto (batch 4)
- **Detalle:** `private var store = StoreKitManager.shared` — no `@State`, SwiftUI no trackea cambios. Si suscripción se renueva mientras la vista está abierta, no se actualiza

---

## 10.2 CODE

### CODE-51: Free tier limits hardcodeados en DowngradeResolutionSheet
- [x] **Archivo:** `DowngradeResolutionSheet.swift` — ahora lee de `ProFeature.freeLimit` (flow review BAJA batch)

---

## 10.3 Verificación

- ✅ UpgradePromptSheet contextual con feature description
- ✅ FeatureGateService con devSimulatePro para testing
- ✅ Pro trial offer después de onboarding
- ✅ Downgrade resolution con archive de excesos

---

## Resumen Global

**Actualizado:** 2026-02-24

| Severidad | Total | ✅ Corregido | [>] Post-release | [ ] Pendiente |
|-----------|-------|-------------|-------------------|---------------|
| BUG | 40 | **40** | 0 | **0** |
| HIGH | 26 | **22** | 4 | **0** |
| DS | 28 | **22** | 0 | **6** |
| A11Y | 43 | **41** | 2 | **0** |
| L10N | 23 | **23** | 0 | **0** |
| EMPTY | 7 | **5** | 0 | **2** |
| CODE | 51 | **35** | 0 | **16** |
| **TOTAL** | **218** | **188 (86%)** | **6** | **24** |

### Pendientes restantes (todos post-release safe)

**DS (0):** todos resueltos
**EMPTY (1):** EMPTY-1 (widgets custom empty states), ~~EMPTY-3~~, ~~EMPTY-5~~
**CODE (11):** CODE-9, CODE-16, CODE-18, CODE-19, CODE-24, CODE-26, CODE-34, CODE-35, CODE-40, CODE-45, CODE-46

**Ningún BUG ni HIGH pendiente. Release safe.**
