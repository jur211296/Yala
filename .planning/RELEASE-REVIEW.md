# Release Day Review — Yala 1.0

**Fecha:** 2026-02-23
**Objetivo:** Revisión exhaustiva de cada flujo antes de release

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
- [ ] **Archivo:** `App/Views/Panel/ScheduledPaymentsWidget.swift:96-152`
- **Impacto:** 2 fetch queries en cada render de la vista
- **Fix:** Mover a `onAppear`/`onChange` con `@State` caching

### HIGH-2: `loadData()` carga TODAS las transacciones sin límite
- [ ] **Archivo:** `App/ViewModels/PanelViewModel.swift:143-155`
- **Impacto:** Con miles de transacciones, cada recalculación es costosa
- **Fix:** Filtrar por período + transacciones históricas solo para balance

### HIGH-3: Recalculaciones redundantes en cascada
- [ ] **Archivos:** `App/Views/Panel/PanelView.swift` (PanelDataObservers + PanelSessionObservers)
- **Impacto:** `recalculateData()` se dispara 4-5 veces por acción que modifica múltiples filtros (ej: applyBudgetFilters)
- **Fix:** Implementar debouncing con el `calculationTask` existente (actualmente dead code)

### HIGH-4: `calculateExchangeRateData` computa tasas para 48 monedas
- [ ] **Archivo:** `App/ViewModels/PanelViewModel.swift:1456`
- **Impacto:** Calcula chart points para 47 monedas cuando solo se muestran 2
- **Fix:** Computar lazily al seleccionar moneda

---

## 1.3 DS — Violaciones Design System

### DS-1: BalanceStatusIndicator usa colores raw
- [ ] **Archivo:** `App/Views/Panel/BalanceStatusIndicator.swift:50-66`
- **Detalle:**
  - `.green` → `DS.Semantic.successForeground`
  - `.red` → `DS.Semantic.errorForeground`
  - `.gray` → `DS.Semantic.disabledForeground`

### DS-2: Hexadecimales hardcodeados en múltiples archivos
- [ ] **Archivos y valores:**
  - `App/ViewModels/PanelViewModel.swift:1709, 1726` → `#6366F1` (electricIndigo)
  - `App/Views/Panel/RecentRecordsWidget.swift:182` → `#6366F1`
  - `App/Views/Panel/CategoriesPieWidget.swift:687` → `#8E8E93` ("Others")
  - `App/Views/Panel/SubcategoriesPieWidget.swift:690` → `#8E8E93` ("Restante")
  - `App/Views/Panel/TopSubcategoriesWidget.swift:322` → `#888888`

### DS-3: `Color(.tertiarySystemFill)` en ScheduledPaymentsWidget
- [ ] **Archivo:** `App/Views/Panel/ScheduledPaymentsWidget.swift:598`
- **Fix:** Reemplazar con token DS

### DS-4: `Color.primary.opacity(0.06)` para border de AccountCard
- [ ] **Archivo:** `App/Views/Panel/AccountCardView.swift:90`
- **Fix:** Usar `DS.Card.borderOpacity`

### DS-5: FAB dimensión hardcodeada `56`
- [ ] **Archivo:** `App/Views/Panel/PanelView.swift:385, 408`
- **Fix:** Crear token DS o constante

### DS-6: Chevron `Color.gray.opacity(0.7)` en todos los widgets
- [ ] **Archivos:** CashFlowWidget, CategoriesPieWidget, SubcategoriesPieWidget, TopCategoriesWidget, TopSubcategoriesWidget, NatureTrendWidget, TrendWidget, ExchangeRateWidget, BudgetsWidget, RecentRecordsWidget, ScheduledPaymentsWidget
- **Fix:** Token DS para color de chevron secundario

### DS-7: Padding mágico `44` en WidgetPreferencesView
- [ ] **Archivo:** `App/Views/Panel/WidgetPreferencesView.swift:161, 178`
- **Fix:** Usar DS.Spacing o calcular desde icon width + spacing

---

## 1.4 A11Y — Accesibilidad

### A11Y-1: AccountsCarouselView usa `.onTapGesture` en vez de `Button`
- [ ] **Archivo:** `App/Views/Panel/AccountsCarouselView.swift:85-91`
- **Impacto:** No keyboard-navigable, no se anuncia como botón en VoiceOver
- **Regla violada:** UI-PATTERNS "Filas clicables con `Button` + `contentShape(Rectangle())`"

### A11Y-2: BudgetsWidget usa `.onTapGesture` en vez de `Button`
- [ ] **Archivo:** `App/Views/Panel/BudgetsWidget.swift:106-109`
- **Impacto:** Mismo que A11Y-1

### A11Y-3: FAB animación "breathing" ignora Reduce Motion
- [ ] **Archivo:** `App/Views/Panel/PanelView.swift:456-461`
- **Impacto:** Usuarios con Reduce Motion ven animación perpetua
- **Fix:** Condicionar `.phaseAnimator` con `@Environment(\.accessibilityReduceMotion)`

### A11Y-4: AccountCardView sin accessibility label combinado
- [ ] **Archivo:** `App/Views/Panel/AccountCardView.swift`
- **Fix:** Añadir `.accessibilityLabel("Cuenta \(name), saldo \(balance)")` combinado

### A11Y-5: AccountCardView botón editar sin accessibility label
- [ ] **Archivo:** `App/Views/Panel/AccountCardView.swift:93-105`
- **Fix:** `.accessibilityLabel(L10n.editAccount)` o similar

### A11Y-6: Page indicator dots sin accessibility
- [ ] **Archivo:** `App/Views/Panel/AccountsCarouselView.swift:50-63`
- **Fix:** `.accessibilityLabel("Página \(current) de \(total)")`

### A11Y-7: WidgetPreferencesView Toggle con `labelsHidden()` sin label alternativo
- [ ] **Archivo:** `App/Views/Panel/WidgetPreferencesView.swift:133-141`
- **Fix:** Añadir `.accessibilityLabel(widgetName)`

### A11Y-8: ScheduledPaymentsWidget filtros y calendar sin labels
- [ ] **Archivo:** `App/Views/Panel/ScheduledPaymentsWidget.swift`
- **Fix:** Labels en botones de filtro y celdas de calendario

### A11Y-9: RecentRecordsWidget filas sin accessibility labels
- [ ] **Archivo:** `App/Views/Panel/RecentRecordsWidget.swift`
- **Fix:** Label semántico por fila ("Café, 15 soles, hace 2 horas")

### A11Y-10: SiriTipCard botón cerrar con touch target pequeño
- [ ] **Archivo:** `App/Views/Panel/PanelView.swift:1441-1449`
- **Fix:** `.frame(minWidth: 44, minHeight: 44)`

---

## 1.5 L10N — Localización

### L10N-1: Accessibility labels en español hardcodeado (10+ instancias)
- [ ] **Archivos:**
  - `PanelView.swift:393` → "Cerrar menú" / "Nuevo registro"
  - `PanelView.swift:708` → "Limpiar filtros"
  - `CashFlowWidget.swift:497` → "Gráfica de flujo de caja"
  - `CategoriesPieWidget.swift:570` → "Gráfica circular de gastos por categoría"
  - `SubcategoriesPieWidget.swift:568` → "Gráfica circular por subcategoría"
  - `NatureTrendWidget.swift:469` → "Gráfica de gastos por naturaleza"
  - `ExchangeRateWidget.swift:122` → "Gráfica de tipo de cambio"
  - `WidgetPreferencesView.swift:142` → "Widget fijo, siempre visible"
- **Fix:** Migrar todos a `L10n.*`

### L10N-2: BudgetsWidget usa `NSLocalizedString()` en vez de `L10n.*`
- [ ] **Archivo:** `App/Views/Panel/BudgetsWidget.swift:125, 130, 148, 153`
- **Fix:** Migrar a pattern `L10n.*`

### L10N-3: ScheduledPaymentsWidget usa `NSLocalizedString()` en vez de `L10n.*`
- [ ] **Archivo:** `App/Views/Panel/ScheduledPaymentsWidget.swift:264, 324, 329, 451-465`
- **Fix:** Migrar a pattern `L10n.*`

### L10N-4: BalanceStatusIndicator strings hardcodeados
- [ ] **Archivo:** `App/Views/Panel/BalanceStatusIndicator.swift:41-48`
- **Detalle:** "Bueno", "Crítico", "Normal" sin L10n

---

## 1.6 EMPTY — Estados vacíos

### EMPTY-1: Ningún widget usa `YalaEmptyState`
- [ ] **Archivos:** Todos los 11 widgets
- **Regla violada:** UI-PATTERNS "SIEMPRE usar YalaEmptyState para estados vacíos"
- **Nota:** Los empty states custom funcionan; la inconsistencia es visual/de mantenimiento

### EMPTY-2: CashFlowWidget renderiza `EmptyView()` cuando no hay datos
- [ ] **Archivo:** `App/Views/Panel/PanelView.swift:961-963`
- **Impacto:** Hueco visual en el grid layout

### EMPTY-3: 0 cuentas muestra header "Accounts" sin guía
- [ ] **Archivo:** `App/Views/Panel/PanelView.swift:464-488`
- **Fix:** Añadir mensaje guía o YalaEmptyState para usuarios nuevos

---

## 1.7 CODE — Calidad/Mantenimiento

### CODE-1: `calculationTask` declarado pero nunca usado
- [ ] **Archivo:** `App/Views/Panel/PanelView.swift:70`
- **Detalle:** `@State private var calculationTask: Task<Void, Never>?` — dead code

### CODE-2: `trendDetailType` con comment "to be removed"
- [ ] **Archivo:** `App/Views/Panel/PanelView.swift:54-55`
- **Detalle:** No parece usarse en PanelView actual

### CODE-3: Doc comments duplicados en PanelViewModel
- [ ] **Archivo:** `App/ViewModels/PanelViewModel.swift:440-443, 458-460`
- **Detalle:** Copy-paste artifact — mismos comments repetidos

### CODE-4: `hasMultipleInputs` nombre misleading
- [ ] **Archivo:** `App/Views/Panel/PanelView.swift:309-311`
- **Detalle:** La expresión simplifica a `voiceInputEnabled || imageInputEnabled` — debería llamarse `hasAlternativeInputs`

### CODE-5: Init de PanelView modifica UIKit appearance global
- [ ] **Archivo:** `App/Views/Panel/PanelView.swift:16-27`
- **Impacto:** Afecta TODOS los UIPageViewControllers, se ejecuta en cada init
- **Fix:** Mover a app delegate o one-time setup

### CODE-6: `DispatchQueue.main.asyncAfter(0.3)` frágil
- [ ] **Archivo:** `App/Views/Panel/PanelView.swift:1325`
- **Impacto:** Timing hack para secuenciar sheets — puede fallar con Reduce Motion
- **Fix:** Usar `onDismiss` callback chaining

### CODE-7: `processChartData()` como computed property en 3 pie widgets
- [ ] **Archivos:** CategoriesPieWidget, SubcategoriesPieWidget, TagsPieWidget
- **Impacto:** Recalcula ángulos en cada render
- **Fix:** `@State` o memoización

### CODE-8: `NumberFormatter` creado en cada llamada
- [ ] **Archivos:** `TopSubcategoriesWidget.swift:409`, `PanelView.swift:776`
- **Fix:** Usar `static let` formatter

### CODE-9: Filtro duplicado 4 veces en `buildCalculationContext`
- [ ] **Archivo:** `App/ViewModels/PanelViewModel.swift:746-1027`
- **Impacto:** 4 bloques de filtrado casi idénticos — riesgo de mantenimiento
- **Fix:** Extraer helper de filtrado común

### CODE-10: `CurrencyConverter.shared` directo en ScheduledPaymentsWidget
- [ ] **Archivo:** `App/Views/Panel/ScheduledPaymentsWidget.swift:268`
- **Impacto:** Bypasea dependency injection
- **Fix:** Usar instancia inyectada

### CODE-11: `subcategoriesWidgetFilter` no se limpia con clearAllPanelFilters
- [ ] **Archivo:** `App/Views/Panel/PanelView.swift`
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
- [ ] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift:487-493`
- **Impacto:** Si `context.save()` falla (disco lleno, error SwiftData), usuario no ve ningún mensaje. Botón Save se re-habilita silenciosamente
- **Fix:** Añadir `@Published var saveError: String?` y mostrar alert

### HIGH-6: Sin validación de monto máximo
- [ ] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift:234-236`
- **Impacto:** Un monto como `99999999999999.99` puede causar overflow en exchange rates y problemas de precisión Double
- **Fix:** Limitar a un máximo razonable (ej: 999,999,999)

### HIGH-7: `loadData()` en ViewModel carga TODAS las transacciones para sugerencias
- [ ] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift:220-229`
- **Impacto:** Sin `fetchLimit`, carga historia completa en memoria solo para autocomplete
- **Fix:** Añadir `fetchLimit = 100`

### HIGH-8: Transfer sin validación visible de cuentas iguales
- [ ] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift:245-251`
- **Impacto:** `isTransferAccountsValid` bloquea Save pero no hay mensaje explicando por qué. `accountValidation.errorMessage` existe pero nunca se muestra en UI
- **Fix:** Mostrar error inline cuando source == destination

### HIGH-9: `filterAmountInput` duplicado en 2 archivos
- [ ] **Archivos:** `NewTransactionView.swift:521-558` y `TransferAmountInputView.swift:214-249`
- **Impacto:** Misma función copiada — divergirán en futuras correcciones
- **Fix:** Extraer a utility compartido

### HIGH-10: Preferencia de moneda inconsistente entre normal y transfer
- [x] **Archivos:** `NewTransactionViewModel.swift:505` usa `CurrencyDefaults.currentPreferred`, línea 569 usa `UserDefaults.standard.string(forKey: "defaultCurrencyCode") ?? "PEN"` — Resuelto (872390a)
- **Impacto:** Dos paths diferentes para obtener la misma información. Fallback "PEN" hardcodeado
- **Fix:** Usar `CurrencyDefaults.currentPreferred` en ambos

---

## 2.3 DS — Violaciones Design System

### DS-8: Colores UIKit hardcodeados en NewTransactionView
- [ ] **Archivo:** `App/Views/Transactions/NewTransactionView.swift`
- **Detalle:**
  - Línea 150, 153, 379: `Color(UIColor.label)` → `.primary`
  - Línea 294: `Color(UIColor.darkGray)` → token DS semántico
  - Línea 364: `Color(UIColor.label).opacity(0.08)` → `DS.Semantic.neutralBackground`

### DS-9: Hex fallback `"6366F1"` hardcodeado
- [ ] **Archivos:** `NewTransactionView.swift:1043`, `TransactionSuccessView.swift:451`
- **Fix:** Usar `Color.electricIndigo` o constante DS

### DS-10: Color de transfer inconsistente
- [ ] **Archivo:** `App/Models/TransactionFormModels.swift:35`
- **Detalle:** `case .transfer: return Color(.label)` — debería ser `Color.transferColor` per UI-PATTERNS

### DS-11: Empty states en selectores no usan `YalaEmptyState`
- [ ] **Archivos:** `SubcategorySelectorSheet.swift:39`, `TagSelectorSheet.swift:81`
- **Fix:** Migrar a componente estándar

### DS-12: Popover autocomplete con ancho hardcodeado
- [ ] **Archivo:** `NewTransactionView.swift:934`
- **Detalle:** `.frame(width: 220)` — magic number

---

## 2.4 A11Y — Accesibilidad

### A11Y-11: "Cerrar" hardcodeado en todos los selectors (6 instancias)
- [ ] **Archivos:** `NewTransactionView.swift:139`, `AccountSelectorSheet.swift:64`, `SubcategorySelectorSheet.swift:107`, `TagSelectorSheet.swift:44`, `DatePickerSheet.swift:38`, `NatureSelectorSheet.swift:41`
- **Fix:** Usar `L10n.Action.close`

### A11Y-12: "Plantillas favoritas" hardcodeado
- [ ] **Archivo:** `NewTransactionView.swift:152`

### A11Y-13: "Eliminar etiqueta" hardcodeado
- [ ] **Archivo:** `NewTransactionView.swift:803`

### A11Y-14: Hint de validación hardcodeado
- [ ] **Archivo:** `NewTransactionView.swift:1017`
- **Detalle:** "Para guardar, completa monto, cuenta y categoría"

### A11Y-15: TransactionTypeSelectorView sin `.isSelected` trait
- [ ] **Archivo:** `App/Views/Transactions/Components/TransactionTypeSelectorView.swift`
- **Fix:** Añadir `.accessibilityAddTraits(selectedType == type ? .isSelected : [])`

### A11Y-16: AccountSelectorRow sin label combinado
- [ ] **Archivo:** `App/Views/Transactions/AccountSelectorSheet.swift`
- **Fix:** Label "Cuenta BCP, moneda PEN, seleccionada"

### A11Y-17: SubcategoryGridItem sin label con contexto de categoría
- [ ] **Archivo:** `App/Views/Transactions/SubcategorySelectorSheet.swift`

### A11Y-18: TagSelectorRow sin label combinado
- [ ] **Archivo:** `App/Views/Transactions/TagSelectorSheet.swift`

### A11Y-19: TransferAmountInputView sin labels en campos source/dest/rate
- [ ] **Archivo:** `App/Views/Transactions/Components/TransferAmountInputView.swift`

### A11Y-20: SelectionChip sin label con estado de selección
- [ ] **Archivo:** `App/Views/Transactions/Components/SelectionChip.swift`

### A11Y-21: NatureEditChip sin label ni hint de editabilidad
- [ ] **Archivo:** `App/Views/Transactions/Components/NatureEditChip.swift`

---

## 2.5 L10N — Localización

### L10N-5: SaveAsRecurringSheet usa `NSLocalizedString` en vez de `L10n.*`
- [ ] **Archivo:** `App/Views/Transactions/SaveAsRecurringSheet.swift:467, 485, 488-489, 533, 550, 581, 596-602, 636, 655, 699, 718, 731`
- **Detalle:** 13+ instancias de `NSLocalizedString(...)` inconsistentes con el resto del proyecto

### L10N-6: "Atras" hardcodeado en CurrencySelectorView
- [ ] **Archivo:** `App/Views/Shared/CurrencySelectorView.swift:73`
- **Fix:** Usar `L10n.Action.back`

### L10N-7: "Cerrar" hardcodeado en 6 selectors
- [ ] **Detalle:** Ya documentado en A11Y-11, incluido aquí por completitud

### L10N-8: Categorías transfer buscan por nombre en español
- [ ] **Detalle:** Ya documentado en BUG-11, incluido aquí por completitud

---

## 2.6 EMPTY — Estados vacíos

### EMPTY-4: AccountSelectorSheet sin empty state
- [ ] **Archivo:** `App/Views/Transactions/AccountSelectorSheet.swift:33-58`
- **Impacto:** Si 0 cuentas activas, el usuario ve ScrollView vacío

### EMPTY-5: Autocomplete sin feedback "sin resultados"
- [ ] **Archivo:** `App/Views/Transactions/NewTransactionView.swift:900-906`
- **Impacto:** Al escribir `#` sin tags que coincidan, el popover simplemente desaparece sin explicación

---

## 2.7 CODE — Calidad/Mantenimiento

### CODE-12: Delete bypasea TransactionService
- [ ] **Archivo:** `App/Views/Transactions/NewTransactionView.swift:1194-1209`
- **Impacto:** La vista llama `modelContext.delete()` directamente en vez de `TransactionService.shared.delete()`
- **Fix:** Usar TransactionService para mantener un solo code path

### CODE-13: DateFormatter creado en cada render
- [ ] **Archivo:** `App/Views/Transactions/NewTransactionView.swift:823-834`
- **Detalle:** `dateChipText` computed property crea `DateFormatter()` en cada evaluación del body
- **Fix:** `static let` formatter

### CODE-14: ExchangeRateInputView posiblemente dead code
- [ ] **Archivo:** `App/Views/Transactions/ExchangeRateInputView.swift`
- **Detalle:** Comment en NewTransactionView dice "Exchange rate section removed - integrated into centralContent". La UI de exchange rate real está en TransferAmountInputView

### CODE-15: `onCreateAnother` no re-aplica `prefillAccountID`
- [ ] **Archivo:** `App/Views/Transactions/NewTransactionView.swift:73-81`
- **Impacto:** Al crear otro después de guardar, se pierde la cuenta por defecto del contexto original

### CODE-16: Success screen solo muestra monto origen en transfers
- [ ] **Archivo:** `App/Views/Transactions/TransactionSuccessView.swift:141-150`
- **Impacto:** Para transfers multi-moneda, el monto destino solo aparece como texto pequeño

### CODE-17: No widget update después de guardar recurring
- [ ] **Archivo:** `App/Views/Transactions/SaveAsRecurringSheet.swift:793-801`
- **Impacto:** Widgets de scheduled payments no reflejan el nuevo pago hasta próximo refresh cycle

### CODE-18: `isSaving` progress nunca se muestra visualmente
- [ ] **Archivo:** `App/ViewModels/NewTransactionViewModel.swift:470`
- **Detalle:** `context.save()` es sincrónico en @MainActor — el flag se setea y limpia antes de que UI pueda renderizar el indicador

### CODE-19: SaveAsRecurringSheet monto con ancho fijo 80pt
- [ ] **Archivo:** `App/Views/Transactions/SaveAsRecurringSheet.swift:259`
- **Impacto:** Se trunca con montos grandes o Dynamic Type

### CODE-20: Tags relationship sin `inverse` explícito
- [ ] **Archivo:** `Models/TransactionItem.swift:32`
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
- [ ] **Archivo:** `App/Views/Records/Components/RecordRowView.swift`
- **Impacto:** VoiceOver no puede describir transacciones. Zero `.accessibilityLabel` en el row completo
- **Fix:** Label combinado "Café, 15 soles, 12 diciembre, Alimentación"

### HIGH-12: Sin paginación en Records — todo cargado en memoria
- [ ] **Archivo:** `App/ViewModels/RecordsViewModel.swift:188-227`
- **Impacto:** Con miles de transacciones en un período, FilterService hace scan lineal de todas. LazyVStack ayuda en render pero no en datos
- **Fix:** Agregar fetchLimit o paginación progresiva

### HIGH-13: Double observer firing — recálculo duplicado por cambio de filtro
- [ ] **Archivo:** `App/Views/Records/RecordsStandaloneView.swift:520-705`
- **Impacto:** RecordsViewModel properties son computed pass-throughs a SessionState. Los observers escuchan ambos, causando doble `refreshRecordsData()` por cada cambio

### HIGH-14: DateFormatter creado en cada render en CompactRecordRow
- [ ] **Archivo:** `App/Views/Statistics/TrendsTabView.swift:1767-1772`
- **Fix:** Usar static formatter o YalaFormatter

### HIGH-15: Bulk delete usa `groupedRecords` que puede estar stale
- [ ] **Archivo:** `App/ViewModels/RecordsViewModel.swift:311-316`
- **Fix:** Usar `context.model(for: id)` como hace `getSelectedTransactions()`

---

## 3.3 DS — Violaciones Design System

### DS-13: `Color.gray` para FAB locked en DetailContainerView
- [ ] **Archivo:** `App/Views/Statistics/DetailContainerView.swift:515`
- **Fix:** `DS.Semantic.disabledForeground`

### DS-14: Opacity inconsistente `0.1` vs `DS.Opacity.subtle`
- [ ] **Archivo:** `App/Views/Statistics/TrendsTabView.swift:1161`
- **Detalle:** "View all" usa hardcoded `0.1`, CategoriesTabView usa `DS.Opacity.subtle`

### DS-15: Padding hardcodeado en CategoryDetailView
- [ ] **Archivo:** `App/Views/Categories/CategoryDetailView.swift:344, 350, 239`
- **Detalle:** `16`, `8`, `56` hardcodeados — debería usar `DS.Spacing`

### DS-16: FAB pulse animation ignora Reduce Motion
- [ ] **Archivo:** `App/Views/Statistics/DetailContainerView.swift:520-524`
- **Detalle:** Mismo patrón que A11Y-3 del Panel — `.phaseAnimator` sin check de `accessibilityReduceMotion`

### DS-17: Tamaños hardcodeados en BulkEditSheet
- [ ] **Archivos:** `BulkEditSheet.swift` → circle 36pt (línea 309), tag icon 28pt (línea 545)
- **Fix:** Tokens DS

---

## 3.4 A11Y — Accesibilidad

### A11Y-22: Category/Subcategory list rows usan `onTapGesture`
- [ ] **Archivo:** `App/Views/Statistics/CategoriesTabView.swift:1521-1525`
- **Regla:** UI-PATTERNS "Button + buttonStyle(.plain)"

### A11Y-23: Metric selector buttons sin accessibility labels
- [ ] **Archivo:** `App/Views/Statistics/TrendsTabView.swift:780-818`
- **Impacto:** VoiceOver lee nombre de SF Symbol en vez de "Balance", "Ingreso", "Gasto"

### A11Y-24: Comparison mode buttons sin labels descriptivos
- [ ] **Archivo:** `App/Views/Statistics/TrendsTabView.swift:433-458`
- **Detalle:** Botones "P-1" / "A-1" sin explicación

### A11Y-25: Cash flow view selector buttons sin labels
- [ ] **Archivo:** `App/Views/Statistics/TrendsTabView.swift:906-951`

### A11Y-26: "Clear All" buttons sin accessibility labels
- [ ] **Archivos:** TrendsTabView, CategoriesTabView, RecordsTabView — botones de xmark sin label

### A11Y-27: Hardcoded Spanish a11y en PeriodComparisonChartView
- [ ] **Archivo:** `App/Views/Statistics/PeriodComparisonChartView.swift:237`
- **Detalle:** "Gráfica de comparación entre periodos", "Sin datos"

### A11Y-28: Hardcoded Spanish a11y en RecordsStandaloneView
- [ ] **Archivo:** `App/Views/Records/RecordsStandaloneView.swift:150, 160, 382, 404`
- **Detalle:** "Seleccionar", "Filtros", "Eliminar", "Editar"

### A11Y-29: CategorySelectorSheet expand usa `onTapGesture`
- [ ] **Archivo:** `App/Views/Filters/Components/CategorySelectorSheet.swift:169`
- **Fix:** Usar Button para expand/collapse

---

## 3.5 L10N — Localización

### L10N-9: "Todas" hardcodeado en RecordsFiltersViewModel (8 instancias)
- [ ] **Archivo:** `App/ViewModels/RecordsFiltersViewModel.swift:122, 125, 134, 139, 146, 158, 163, 166`
- **Fix:** `L10n.Common.all`

### L10N-10: "Categoria"/"Categorias" fallback en FilterControlBar
- [ ] **Archivo:** `App/Views/Filters/FilterControlBar.swift:156, 158`

### L10N-11: "Quitar filtro" en FilterChipView
- [ ] **Archivo:** `App/Views/Filters/FilterChipView.swift:45`

### L10N-12: Spanish hardcodeado en RecordsModels
- [ ] **Archivo:** `App/Models/RecordsModels.swift:23-24, 49-53`
- **Detalle:** "Ingresos", "Gastos", "Transferencias", "Todos" sin L10n

### L10N-13: "Cancelar" hardcodeado en SubcategoryDetailView
- [ ] **Archivo:** `App/Views/Categories/SubcategoryDetailView.swift:144`

---

## 3.6 EMPTY

### EMPTY-6: Empty states no usan `YalaEmptyState` en tabs de Statistics
- [ ] **Archivos:** TrendsTabView:584, CategoriesTabView:964, RecordsTabView:381
- **Nota:** Funcionan pero son custom inline en vez del componente estándar

---

## 3.7 CODE — Calidad/Mantenimiento

### CODE-22: `clearAllFilters()` en StatisticsViewModel es dead code incompleto
- [ ] **Archivo:** `App/ViewModels/StatisticsViewModel.swift:684`
- **Detalle:** No limpia currencies/amount/search. No se llama desde ningún lugar
- **Fix:** Eliminar o unificar con `clearFilters()`

### CODE-23: ~130 líneas dead code en `calculateAggregatedTrend`
- [ ] **Archivo:** `App/ViewModels/StatisticsViewModel.swift:437-566`
- **Detalle:** Reemplazado por TrendDataProcessor pero nunca eliminado

### CODE-24: No-op sync functions (7 funciones vacías)
- [ ] **Archivos:** `DetailContainerView.swift:630-652`, `StatisticsViewModel.swift:719-733`
- **Detalle:** Mantenidas "por backward compatibility" pero vacías

### CODE-25: FilterControlBar componente no usado
- [ ] **Archivo:** `App/Views/Filters/FilterControlBar.swift`
- **Detalle:** Existe pero ningún tab lo usa — cada tab implementa su propia control bar

### CODE-26: Chip data structs duplicadas en 3 tabs
- [ ] **Archivos:** TrendsTabView, CategoriesTabView, RecordsTabView
- **Detalle:** AccountChip, CategoryChip, TagChip, NatureChipData definidos independientemente con estructura idéntica

### CODE-27: Bulk note editor no permite limpiar notas
- [ ] **Archivo:** `App/Views/Records/BulkEditSheet.swift`
- **Detalle:** Save button disabled cuando nota vacía. `bulkUpdateNote` acepta string vacío pero UI lo bloquea

### CODE-28: Bulk delete bypasea EntityDeletionService
- [ ] **Archivo:** `App/ViewModels/RecordsViewModel.swift:309-330`
- **Detalle:** Llama `context.delete()` directamente

### CODE-29: `DispatchQueue.main.async` redundante en refreshRecordsData
- [ ] **Archivo:** `App/Views/Records/RecordsStandaloneView.swift:419`
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
- [ ] **Archivo:** `App/ViewModels/BudgetsViewModel.swift:196-204`
- **Impacto:** Sin predicate de fecha. Con miles de transacciones, cada carga es costosa

### HIGH-17: BudgetAlertService también carga todas las transacciones sin predicate
- [ ] **Archivo:** `Services/BudgetAlertService.swift:58-59`
- **Detalle:** `FetchDescriptor<TransactionItem>()` sin filtro

---

## 4.3 DS

### DS-18: BudgetProgressBar sin color warning (solo verde→rojo)
- [ ] **Archivo:** `App/Views/Planning/Components/BudgetProgressBar.swift:26-29`
- **Impacto:** Binario: color del budget vs hotPink al 100%. Sin indicador visual en 75-99%
- **Fix:** Añadir `DS.Semantic.warningForeground` para rango 75-99%

### DS-19: BudgetRowView usa `DS.Radius.md` en vez de `DS.Radius.card`
- [ ] **Archivo:** `App/Views/Planning/BudgetRowView.swift:69, 72`

---

## 4.4 A11Y

### A11Y-30: BudgetRowView sin accessibility label combinado
- [ ] **Archivo:** `App/Views/Planning/BudgetRowView.swift`
- **Fix:** "Presupuesto Comida, 75% gastado, 500 de 1000 soles"

### A11Y-31: BudgetEditorView Picker de período con label vacío
- [ ] **Archivo:** `App/Views/Planning/BudgetEditorView.swift:199`
- **Detalle:** `Picker("", selection:)` → VoiceOver no anuncia nada

### A11Y-32: Hardcoded Spanish "Excedido", "Cerrar", "Plantillas favoritas"
- [ ] **Archivos:** BudgetProgressBar.swift:33, BudgetEditorView.swift:112, PlanningView.swift:75

---

## 4.5 L10N

### L10N-14: Hardcoded Spanish en budget views
- [ ] **Archivos:** BudgetsListView.swift:230 ("No hay presupuestos inactivos"), BudgetEditorView.swift:112 ("Cerrar"), PlanningView.swift:75 ("Plantillas favoritas")

---

## 4.6 CODE

### CODE-30: Legacy fields `month`, `year`, `category` en Budget model nunca usados
- [ ] **Archivo:** `Models/Budget.swift:19-24`

### CODE-31: `isPaidForCurrentCycle` en modelo es dead code
- [ ] **Archivo:** `Models/ScheduledPayment.swift:229-253` (nota: está en el modelo compartido)
- **Detalle:** VM usa su propia lógica via queries, nunca usa esta computed property

### CODE-32: BudgetPeriodSelectorSheet custom scroll picker frágil
- [ ] **Archivo:** `App/Views/Planning/Components/BudgetPeriodSelectorSheet.swift`
- **Detalle:** Reimplementa Picker wheel con GeometryReader, snap timing hardcodeado (0.15s)

### CODE-33: WidgetDataCache.updateCache no se llama en BudgetEditorViewModel.deleteBudget
- [ ] **Archivo:** `App/ViewModels/BudgetEditorViewModel.swift:206-220`

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
- [ ] **Archivo:** `Services/EntityDeletionService.swift:129-131`
- **Impacto:** Al borrar scheduled payment: drafts con `sourceScheduledPaymentID` quedan huérfanos, notification requests no se cancelan, tracker entries no se limpian

### HIGH-19: Notificaciones solo verifican `nextDueDate`, no ocurrencias generadas
- [ ] **Archivo:** `Services/ScheduledPaymentNotificationService.swift:33-68`
- **Impacto:** Pago semanal Mon/Wed/Fri con nextDueDate=Monday → notificaciones de Wed y Fri nunca se envían

### HIGH-20: Yearly payment on Feb 29 desaparece en años no bisiesto
- [ ] **Archivo:** `App/ViewModels/ScheduledPaymentsViewModel.swift:733-749`
- **Impacto:** `Calendar.date(from: DateComponents(year: 2027, month: 2, day: 29))` retorna nil → pago invisible ese año

### HIGH-21: `paidStatus` en Widget como computed var = N+1 query en cada render
- [ ] **Archivo:** `App/Views/Panel/ScheduledPaymentsWidget.swift:95-97`
- **Impacto:** 2 SwiftData queries en cada evaluación del body (ya documentado como HIGH-1)

---

## 5.3 DS

### DS-20: `.orange` hardcodeado para estado inactivo
- [ ] **Archivo:** `App/Views/Planning/ScheduledPaymentDetailView.swift:201-206`
- **Fix:** `DS.Semantic.warningForeground`

---

## 5.4 A11Y

### A11Y-33: Hardcoded Spanish en toolbar buttons (8 instancias)
- [ ] **Archivos:** ScheduledPaymentEditorView:129 ("Cerrar"), :136,354 ("Crea una cuenta primero"), ScheduledPaymentDetailView:107 ("Atrás"), :112 ("Editar"), ScheduledPaymentsSettingsView:47,52, TransactionAssociationSheet:38

---

## 5.5 L10N

### L10N-15: NSLocalizedString en ScheduledPaymentDetailView strings
- [ ] **Archivo:** `App/Views/Planning/ScheduledPaymentDetailView.swift`
- **Detalle:** Múltiples strings con pattern inconsistente

---

## 5.6 CODE

### CODE-34: `loadPaidStatus` duplicado en Widget y ViewModel
- [ ] **Archivos:** Widget:99-152 vs ViewModel:247-302

### CODE-35: Filter logic triplicada en getSubscriptions/getRecurringPayments/calculatePaymentData
- [ ] **Archivo:** `App/ViewModels/ScheduledPaymentsViewModel.swift:550-629, 307-367`

### CODE-36: DateFormatter creado en computed properties (5+ instancias)
- [ ] **Archivos:** ViewModel:95-97, DetailView:507-518, ListView:554-564, Widget:201-203, TransactionAssociationSheet:120-121

### CODE-37: ScheduledPaymentsSettingsViewModel.deletePayments bypasea EntityDeletionService
- [ ] **Archivo:** `App/ViewModels/ScheduledPaymentsSettingsViewModel.swift:73-89`

### CODE-38: `recurrenceInterval` picker permite hasta 30 para todos los tipos
- [ ] **Archivo:** `App/Views/Planning/ScheduledPaymentEditorView.swift:538-543`
- **Detalle:** "Cada 30 años" no tiene sentido

### CODE-39: `isPaidForCurrentCycle` en modelo es dead code
- [ ] **Archivo:** `Models/ScheduledPayment.swift:229-253`

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
- [ ] **Archivo:** `App/Services/MerchantMemoryService.swift:151-177`
- **Impacto:** Con miles de merchants, scan lineal completo

### HIGH-23: Bulk approve no verifica cuentas archivadas
- [ ] **Archivo:** `App/Views/Inbox/InboxBulkActionsSheet.swift:318-338`
- **Impacto:** Puede crear transacciones contra cuentas archivadas (single approve SÍ verifica)

---

## 6.3 DS

### DS-21: InboxBulkActionsSheet usa colores raw (.blue, .purple, .green, .orange, .red)
- [ ] **Archivo:** `App/Views/Inbox/InboxBulkActionsSheet.swift:46-55`
- **Fix:** DS.Semantic tokens

### DS-22: InboxDraftEditSheet usa `Color(UIColor.label).opacity(0.08)` y `0.05`
- [ ] **Archivo:** `App/Views/Inbox/InboxDraftEditSheet.swift:402, 517`

---

## 6.4 A11Y

### A11Y-34: Hardcoded Spanish a11y en InboxView (5+ instancias)
- [ ] **Archivos:** InboxView.swift:112 ("Cerrar"), :118 ("Aprobar todo"), :238 ("Deseleccionar"), :262 hint

### A11Y-35: Hardcoded Spanish a11y en InboxDraftEditSheet
- [ ] **Archivo:** InboxDraftEditSheet.swift:318 ("Cerrar"), :335 ("Eliminar"), :344 ("Rechazar"), :705 hint

### A11Y-36: Hardcoded Spanish a11y en VoiceRecordingView (6 instancias)
- [ ] **Archivo:** App/Views/Voice/VoiceRecordingView.swift:504-602

### A11Y-37: InboxDraftRowView sin accessibility labels
- [ ] **Archivo:** App/Views/Inbox/InboxDraftRowView.swift
- **Fix:** Label "Borrador: [nota], [monto], [estado]"

### A11Y-38: Hardcoded Spanish en ImageSelectionView
- [ ] **Archivo:** App/Views/Image/ImageSelectionView.swift:75

---

## 6.5 L10N

### L10N-16: DraftService error string hardcodeado en español
- [ ] **Archivo:** `Services/DraftService.swift:420`
- **Detalle:** "No se pueden aprobar transacciones con fecha futura"

### L10N-17: VoiceTranscriptionService defaults a Spanish para non-English
- [ ] **Archivo:** `Services/VoiceTranscriptionService.swift:64-66`
- **Impacto:** Portuguese, French, German users get Spanish transcription

---

## 6.6 CODE

### CODE-40: DispatchQueue.main.asyncAfter(0.3) frágil en InboxView (3 instancias)
- [ ] **Archivo:** `App/Views/Inbox/InboxView.swift:138, 150, 181`

### CODE-41: Direct modelContext.save() bypasea DraftService
- [ ] **Archivo:** `App/Views/Inbox/InboxView.swift:544-555`

### CODE-42: Timer en VoiceRecordingView no invalidado en onDisappear
- [ ] **Archivo:** `App/Views/Voice/VoiceRecordingView.swift:681`

### CODE-43: Image processing errors silently caught con `continue`
- [ ] **Archivo:** `App/Views/Image/ImageSelectionView.swift:660-664`

### CODE-44: Bulk approve silently salta drafts sin feedback
- [ ] **Archivo:** `Services/DraftService.swift:227-229`
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
- [ ] **Archivo:** `App/ContentView.swift:905-928`
- **Regla:** UI-PATTERNS requiere `.glassEffect(.regular.interactive(), in: .capsule)`

### DS-24: Font hardcodeado `.font(.subheadline)` en vez de DS.Typography
- [ ] **Archivo:** `App/ContentView.swift:914`

### DS-25: Amount usa `DS.Typography.headline` en vez de `DS.Typography.amount`
- [ ] **Archivo:** `App/ContentView.swift:1107`

### DS-26: Missing `contentShape(Rectangle())` en SearchResultRow
- [ ] **Archivo:** `App/ContentView.swift:1114`

---

## 7.2 A11Y

### A11Y-39: Sin accessibility labels en filter chips ni result rows
- [ ] **Archivo:** `App/ContentView.swift:905-928, 1074-1116`

### A11Y-40: Sin empty state cuando 0 transacciones y no hay búsqueda
- [ ] **Archivo:** `App/ContentView.swift:871-889`

---

## 7.3 EMPTY

### EMPTY-7: Custom empty state en vez de `YalaEmptyState`
- [ ] **Archivo:** `App/ContentView.swift:982-997`

---

## 7.4 CODE

### CODE-45: Lógica de filtrado duplicada (~50 líneas) entre `filteredResults` y `totalMatchingCount`
- [ ] **Archivo:** `App/ContentView.swift:763-812` y `815-858`
- **Impacto:** Filtro ejecutado 2x en cada keystroke

### CODE-46: 470 líneas de search embebidas en ContentView.swift
- [ ] **Archivo:** `App/ContentView.swift:692-1152`
- **Fix:** Extraer a archivos separados con SearchViewModel

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
- [ ] **Archivos:** OnboardingView.swift, LanguageSelectionView.swift, SplashScreenView.swift
- **Impacto:** VoiceOver: progress dots sin descripción, radio buttons sin toggle semantics, currency rows sin contexto

---

## 8.3 DS

### DS-27: Frame sizes hardcodeados (52x52, 40x40, 100x100, 36x36)
- [ ] **Archivo:** `App/Views/Onboarding/OnboardingView.swift:965, 670, 847, 886`
- **Fix:** @ScaledMetric o tokens DS

---

## 8.4 A11Y

### A11Y-41: Zero accessibility labels en onboarding completo
- [ ] **Detalle:** Ya documentado en HIGH-24

---

## 8.5 L10N

### L10N-18: SeedCategoryPreview con nombres hardcodeados en español
- [ ] **Archivo:** `App/Views/Onboarding/OnboardingView.swift:1286-1298`
- **Impacto:** 11 categorías ("Alimentación", "Compras", "Transporte"...) visibles para todos los idiomas
- **Fix:** Usar `L10n.Category.*`

### L10N-19: "Usuario" hardcodeado como nombre default
- [ ] **Archivos:** OnboardingView.swift:1140, ProfileView.swift:30, PersonalDetailsView.swift:18,304, PanelView.swift:75
- **Fix:** `L10n.Onboarding.defaultName` o string vacío

### L10N-20: Tiempo de notificación en formato 12h hardcodeado ("8:00 PM", "1:30 PM")
- [ ] **Archivo:** `App/Views/Onboarding/OnboardingView.swift:826-828`
- **Impacto:** Locales 24h (Alemania, Francia) ven formato anglosajón

---

## 8.6 CODE

### CODE-47: DispatchQueue.main.asyncAfter para splash dismiss (inconsistente con structured concurrency)
- [ ] **Archivo:** `App/ContentView.swift:236`

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
- [ ] **Archivo:** `App/Views/Profile/ProfileView.swift:32`
- **Impacto:** Foto 2-5MB en UserDefaults puede causar slowdowns. Anti-pattern de Apple
- **Fix:** Guardar en Documents directory, solo path en UserDefaults

### HIGH-26: Data wipe no advierte sobre eliminación de datos iCloud
- [ ] **Archivo:** `App/Views/Settings/UserDataResetView.swift`
- **Impacto:** Borrar local propaga a iCloud, afecta otros dispositivos sin aviso

---

## 9.3 DS

### DS-28: `Typography.title2` vs `DS.Typography.title2` inconsistente
- [ ] **Archivos:** CurrencySettingsView.swift:71-76, ImportIntroSheet.swift, ThemeSettingsView.swift:44

---

## 9.4 A11Y

### A11Y-42: Toggle labels vacíos en todas las settings views
- [ ] **Patrón:** `Toggle("", isOn:).labelsHidden()` — VoiceOver dice solo "toggle" sin contexto
- **Fix:** `Toggle(L10n.Settings.xxx, isOn:).labelsHidden()`

### A11Y-43: Color picker en TagFormView sin labels de selección
- [ ] **Archivo:** `App/Views/Tags/TagFormView.swift:193-209`
- **Impacto:** Solo indicadores visuales de selección, inaccesible para VoiceOver

---

## 9.5 L10N

### L10N-21: Hardcoded Spanish en ~46 toolbar a11y labels ("Cerrar", "Atrás", "Agregar")
- [ ] **Archivos:** ~35+ archivos de settings
- **Detalle:** Patrón sistémico `YalaToolbarButton(label: "Cerrar")` en toda la app

### L10N-22: Date format hardcodeado en español en CurrencySettingsView
- [ ] **Archivo:** `App/Views/Settings/CurrencySettingsView.swift:344`
- **Detalle:** `"d 'de' MMMM yyyy, HH:mm"` — "de" es español

### L10N-23: Múltiples strings de settings sin L10n
- [ ] **Archivos:** AccountsSettingsListView:76-77 ("Listo", "Reordenar"), CategoriesSettingsListView:128,188, NotificationsSettingsView:49, UserDataResetView:72

---

## 9.6 CODE

### CODE-48: Dead code `notificationsList` en NotificationsSettingsView
- [ ] **Archivo:** `App/Views/Settings/NotificationsSettingsView.swift:199-254`
- **Detalle:** Marcado como "Legacy, not used"

### CODE-49: DispatchQueue.main.asyncAfter en ~10 locations de Profile/Import
- [ ] **Archivos:** ProfileView:148, ImportIntroSheet:366,464,499,522,627,731, ThemeSettingsView:94

### CODE-50: Unused @AppStorage("defaultPeriod") en ProfileView
- [ ] **Archivo:** `App/Views/Profile/ProfileView.swift:237-238`

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
- [ ] **Archivo:** `App/Views/Subscription/DowngradeResolutionSheet.swift:37-38, 44-45`
- **Detalle:** `accountsToKeep: 2`, `budgetsToKeep: 3` — debería leer de FeatureGateService

---

## 10.3 Verificación

- ✅ UpgradePromptSheet contextual con feature description
- ✅ FeatureGateService con devSimulatePro para testing
- ✅ Pro trial offer después de onboarding
- ✅ Downgrade resolution con archive de excesos

---

## Resumen Global

| Flujo | BUG | HIGH | DS | A11Y | L10N | EMPTY | CODE | Total |
|-------|-----|------|----|------|------|-------|------|-------|
| 1. Panel | 5 | 4 | 7 | 10 | 4 | 3 | 11 | **44** |
| 2. Transaction | 8 | 6 | 5 | 11 | 4 | 2 | 10 | **46** |
| 3. Statistics | 6 | 5 | 5 | 8 | 5 | 1 | 8 | **38** |
| 4. Budgets | - | - | - | - | - | - | - | - |
| 5. Scheduled | - | - | - | - | - | - | - | - |
| 6. Inbox | - | - | - | - | - | - | - | - |
| 7. Search | - | - | - | - | - | - | - | - |
| 8. Onboarding | - | - | - | - | - | - | - | - |
| 9. Profile | - | - | - | - | - | - | - | - |
| 10. Subscription | - | - | - | - | - | - | - | - |
| **TOTAL** | **40** | **26** | **27** | **42** | **23** | **7** | **46** | **211** |
