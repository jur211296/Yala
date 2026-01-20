# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 7 — Beta Preparation (V1.0 Release)

## Current Position

Version: 1.0 (preparando release)
Phase: 7 of 7 en V1.0 (Beta Preparation)
Spec: .planning/PHASE7-BETAPREP-SPEC.md
Plan: Not started
Status: Features V1.0 completas, preparando para TestFlight beta pública
Last activity: 2026-01-20 — Reorganización de roadmap (V1.0 vs V1.1)

Progress: █████████████░ 85% (Fase 7 - Subfases 7.1-7.5, 7.7, 7.8 completadas)

---

## ⚠️ FIX URGENTE V1.0 (PRIORIDAD MÁXIMA)

### Edición masiva de transacciones

**Problema:** El botón "Editar" en modo selección múltiple muestra "Coming Soon" en lugar de funcionar.

**Estado actual (qué SÍ funciona):**
- ✅ Entrar en modo selección (botón checkmark en toolbar de Records)
- ✅ Seleccionar/deseleccionar transacciones individuales
- ✅ Seleccionar todos
- ✅ Eliminar seleccionados (botón trash) — FUNCIONA
- ✅ Editar 1 registro (abre formulario de edición) — FUNCIONA

**Lo que NO funciona:**
- ❌ Editar múltiples registros → muestra alert "Coming Soon"

**Archivos clave:**
| Archivo | Líneas | Descripción |
|---------|--------|-------------|
| `DetailContainerView.swift` | 388-401 | `handleEditAction()` — tiene el placeholder |
| `DetailContainerView.swift` | 327-357 | `selectionActionBar` — UI de acciones |
| `DetailContainerView.swift` | 669-672 | Alert "Coming Soon" a reemplazar |
| `RecordsViewModel.swift` | 319-336 | `editSelectedRecords()` — devuelve `.multiple` |

**Implementación requerida:**

1. **Crear `BulkEditSheet.swift`** en `Views/Records/`
   - Opciones: "Cambiar cuenta", "Cambiar categoría"
   - Usar DS tokens y patrones de UI existentes
   - Cada opción abre un picker (reutilizar existentes)

2. **Agregar métodos en `RecordsViewModel.swift`:**
   ```swift
   func bulkUpdateAccount(_ accountID: PersistentIdentifier, context: ModelContext)
   func bulkUpdateSubcategory(_ subcategoryID: PersistentIdentifier, context: ModelContext)
   ```

3. **En `DetailContainerView.swift`:**
   - Agregar `@State private var showBulkEditSheet = false`
   - En `handleEditAction()` case `.multiple`: cambiar `showMultiEditPlaceholder = true` por `showBulkEditSheet = true`
   - Agregar `.sheet(isPresented: $showBulkEditSheet)`

**Flujo esperado:**
```
1. Usuario entra en modo selección (checkmark button)
2. Selecciona múltiples transacciones (tap en cada una)
3. Toca botón "Editar" (pencil) en barra inferior
4. Aparece sheet: "Cambiar cuenta" | "Cambiar categoría"
5. Selecciona opción → aparece picker correspondiente
6. Confirma → se aplica cambio a TODOS los seleccionados
7. Sale del modo selección automáticamente
```

**Definition of Done:**
- [ ] `BulkEditSheet.swift` creado con diseño consistente
- [ ] Cambiar cuenta funciona para N transacciones
- [ ] Cambiar subcategoría funciona para N transacciones
- [ ] Feedback visual después de aplicar cambios
- [ ] Build compila sin warnings
- [ ] Verificar con 1, 5, y 20+ transacciones seleccionadas

**Estimación:** 3-4 incrementos pequeños

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-01-20T14:52:00-05:00] 220e8ad chore(qa): add test CSV files for import testing
- [2026-01-20T14:51:00-05:00] 416bbd9 docs(qa): rewrite QA-SCENARIOS.md with exhaustive coverage
- [2026-01-20T11:40:00-05:00] 90c083f fix(persistence): add error handling for SwiftData save/delete operations
- [2026-01-20T11:30:00-05:00] f6cd20a feat(currency): expand to 7 currencies with settings UI
- [2026-01-20T11:28:00-05:00] d7c5ce7 feat(onboarding): add first-time setup flow with currency selection
- [2026-01-20T11:26:00-05:00] b8e1d43 feat(widgets): add InfoHintButton with toggle and empty states
- [2026-01-20T11:24:00-05:00] af9896c feat(ui): add FilterBlockedPopover component
- [2026-01-20T11:22:00-05:00] 016261e fix(ui): standardize empty state icons across app
- [2026-01-20T07:30:00-05:00] fa7c052 feat(i18n): add 4 currencies and fix hardcoded strings
- [2026-01-20T07:05:00-05:00] c0e407a chore(cleanup): remove TODOs, dead code, and legacy FIN-XX references

## Completed in Current Phase

- **Subfase 7.1: Code Quality & Cleanup** - TODOs eliminados, código muerto limpiado, referencias legacy (FIN-XX) removidas, 0 warnings
- **Subfase 7.2: Performance & Optimización** - Auditoría de código OK (N+1, lazy loading, memory leaks)
- **Subfase 7.3: Localizaciones y Monedas** - 7 monedas (PEN, USD, EUR, MXN, COP, BRL, GBP), strings hardcodeados corregidos
- **Subfase 7.4: Testing & QA** - QA-SCENARIOS.md exhaustivo (15 secciones, ~120 escenarios, ~250 validaciones), CSVs de prueba para import (7 archivos)
- **Subfase 7.5: UX para Nuevos Usuarios** - Empty states estandarizados, InfoHintButton en 12 widgets con toggle, FilterBlockedPopover, empty states en TrendsTabView
- **Subfase 7.7: Estabilidad Pre-Release** - Error handling en persistencia (13 try? → do/catch con alertas), validaciones auditadas OK
- **Subfase 7.8: Primer Uso y Onboarding** - Onboarding 4 pasos (nombre, moneda, secundarias, periodo), 7 monedas, sección divisas secundarias en Settings

### Fase 6 (archivado)
- **Var% vs periodo anterior completo** - Pie charts, Top widgets, listas, CashFlow cards, Nature widget; selector M/A; chips inline alineados derecha; oculto para All Time
- **"vs [amount]" en KPI** - Todas las cards muestran monto del periodo anterior al lado del KPI
- **"vs [period]" debajo de chips** - Texto de periodo de comparación debajo de variation chips
- **Balance calculation fix** - PanelView ahora calcula balance correctamente (igual que TrendsTabView)
- **Variation chip colors** - Colores corregidos para contexto de gastos (+% pink, -% purple)
- **Carrusel naturaleza con variación** - Widget compacto con Var% por naturaleza, dimming visual
- **Migración Design System (DS tokens)** completa en todas las vistas
  - Panel/: PanelView, widgets, AccountCardView
  - Statistics/: TrendsTabView, RecordsTabView, CategoriesTabView, DetailContainerView
  - Settings/: Todas las vistas de configuración
  - Records/: RecordsFiltersView, RecordRowView
  - Transactions/: NewTransactionView, SelectionChip
  - Shared/: NetoEmptyState, NetoBadge, StandardButtons, NetoLoadingOverlay, SectionBox, CurrencySelectorView, IconColorPickerSheet, SkeletonView
  - Planning/: PlanningView
  - Profile/: ProfileView
  - Tags/: TagFormView
  - Filters/: FilterChipsSection, FilterControlBar
- **Pie chart de etiquetas** en carrusel CategoriesTabView (tercer slide)
- **Tags con iconos y colores editables** (IconColorPickerSheet)
- **Paleta de 15 colores únicos** para nuevos tags (nunca negro)
- **Import asigna colores únicos** a tags nuevos
- **Interactividad del pie**: click filtra todas las vistas
- **Filter chips muestran icono** del tag (no solo color)
- **Lista de tags con iconos** en ProfileView (no puntos)
- **Migración SwiftData** con valor por defecto para iconName
- **Tooltip dinámico en gráficas** - Posición arriba/abajo según altura del punto (evita clipping)
- **Keyboard dismiss en formularios** - Tap fuera, scroll, sheets/NavigationLinks cierran teclado correctamente
- **Filas clickables con Button** - categoriesContent en filtros convertido de onTapGesture a Button
- **Auto-focus completo** - Todos los formularios de creación con auto-focus en campo nombre
- **Filtro Ingresos/Gastos completo** - Chips inline, sincronización bidireccional SessionState, totales clicables en RecordsTabView con dimming, chip visible en PanelView
- **Gráficas de ingresos completas** - Selector unificado (chip = fuente de verdad), calculadores parametrizados, CategoriesTabView adapta pie charts y lista, PanelView widgets adaptativos, NatureTrendWidget muestra mensaje en modo ingresos, CashFlowWidget con color teal y dimming, título dinámico "Análisis del ingreso", localizaciones completas (6 idiomas)
- **Importación multimoneda** - Auto-detecta monedas en CSV, permite asignar cuenta por divisa, fix parsing de campos con newlines embebidos
- **Primer día de semana** - Nueva preferencia en Personalización (Domingo/Lunes)
- **FavoritePayment ↔ Tag N:N** - Relación muchos-a-muchos correcta con @Relationship(inverse:), fix DataWipeService
- **Optimización de cálculos** - N+1 queries eliminados en TrendsTabView, TagSpendingCalculator extraído como servicio, recordsSummary cacheado en ViewModel, onChange handlers consolidados

## Next Steps

### Fase 7: Beta Preparation (V1.0 Release)

**Subfase 7.1: Code Quality & Cleanup** ✅
- [x] Revisar TODOs/FIXMEs en el código
- [x] Eliminar código muerto o comentado
- [x] Eliminar referencias legacy (FIN-XX)
- [x] Imports no usados (verificado)
- [x] Warnings del compilador a cero

**Subfase 7.2: Performance & Optimización** ✅
- [x] Auditoría de código (N+1, lazy loading, view bodies)
- [x] Memory leaks (sin retain cycles detectados)
- [x] Nota: Profiling con Instruments pendiente (manual en Xcode)

**Subfase 7.3: Localizaciones y Monedas** ✅
- [x] Auditoría de strings hardcodeados (3 títulos corregidos)
- [x] Nuevas keys en 6 idiomas (filters.title, iconPicker.title)
- [x] Añadir monedas: MXN, COP, BRL, GBP (7 monedas total)

**Subfase 7.4: Testing & QA** ✅
- [x] Documento QA-SCENARIOS.md exhaustivo (reescritura completa)
- [x] 15 secciones con orden de dependencias
- [x] ~120 escenarios detallados con precondiciones
- [x] ~250+ validaciones específicas
- [x] CSVs de prueba en .qa-test-data/ (7 archivos)
- [x] screenshot_data_pen.csv para capturas App Store

**Subfase 7.5: UX para Nuevos Usuarios** ✅
- [x] Empty states informativos (auditados, iconos estandarizados)
- [x] Textos de ayuda en Settings (verificados)
- [x] InfoHintButton en 12 widgets con toggle showWidgetHints
- [x] FilterBlockedPopover para mensajes de bloqueo de filtros
- [x] Empty states en TrendsTabView (gráfica trend y cashflow)

**Subfase 7.6: App Store Preparation** ← Siguiente
- [ ] Screenshots, descripción, metadata

**Subfase 7.7: Estabilidad Pre-Release** ✅
- [x] Error handling consistente (13 operaciones de persistencia con alertas)
- [x] Validaciones de datos (auditadas - todas OK)

**Subfase 7.8: Primer Uso y Onboarding** ✅
- [x] Onboarding de 4 pasos (nombre, moneda preferida, secundarias, periodo)
- [x] Integración con ContentView (fullScreenCover)
- [x] Reactivo a data wipe (muestra onboarding automáticamente)
- [x] 7 monedas soportadas (PEN, USD, EUR, MXN, COP, BRL, GBP)
- [x] Sección divisas secundarias en CurrencySettingsView

## Parking Lot

(Items movidos a Fase 5.1)

- `iconName` en Tag tiene default `"tag.fill"` para migración
- `TagsPieWidget` sigue patrón de CategoriesPieWidget/SubcategoriesPieWidget
- Sincronización bidireccional pie ↔ filtros usa flag `isSyncingFilters`
- Tags existentes migran automáticamente con icono por defecto
- Design System (DS) en `DesignTokens.swift` con: Spacing, Radius, FormRow, ListRow, Typography
- SwiftData N:N requiere `@Relationship(inverse:)` explícito en un lado; arrays sin inverse se tratan como 1:N

## Session Continuity

Last session: 2026-01-20
Stopped at: Subfase 7.7 completada (Estabilidad Pre-Release)
Next step: Subfase 7.6 (App Store Preparation) — última subfase pendiente
Resume file: None

## V1.1 (Futuro)

Registro Inteligente y Plataforma diferidos. Ver:
- .planning/PHASE8-REGISTRO-SPEC.md
- ROADMAP.md (Fases 8-9)
