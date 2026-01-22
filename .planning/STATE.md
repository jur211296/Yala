# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** V1.1 Desarrollo — Fase 8: Registro Inteligente

## Current Position

Version: 1.1 (IN DEVELOPMENT)
Phase: 8 - Registro Inteligente (Subfase 8.1 ✅, trabajando en 8.2)
Spec: .planning/PHASE8-REGISTRO-SPEC.md
Plan: In progress
Status: **V1.1 en desarrollo** — Bandeja de entrada implementada, siguiente: edición y aprobación
Last activity: 2026-01-22 — Subfase 8.1 completada

Progress: █░░░░░░░░░░░░░ 10% (V1.1 - Fase 8 iniciada)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-01-22T12:45:00-05:00] a939ee3 fix(transaction-ui): match tag chip size with other selection chips
- [2026-01-22T12:42:00-05:00] cac01fc fix(transaction-ui): improve category and tag chips styling
- [2026-01-22T12:38:00-05:00] 5e401b9 fix(transaction-ui): improve amount, tags, date chip and toast
- [2026-01-22T12:30:00-05:00] f1051ac fix(period): prevent ViewModels from overwriting period selection
- [2026-01-22T12:00:00-05:00] c6294fa fix(records): balance now equals income minus expense
- [2026-01-22T11:45:00-05:00] 50e542c fix(filters): prevent auto-expense when selecting income categories
- [2026-01-22T10:45:00-05:00] 3361855 fix(tests): update currency count test to expect 7 currencies
- [2026-01-22T10:44:00-05:00] cbfe355 docs(qa): add transfer classification test scenarios
- [2026-01-22T10:40:00-05:00] 80ac396 feat(migration): migrate positive transfers to Income category
- [2026-01-22T10:38:00-05:00] c1c8a4d fix(import): use isSystemSubcategory for transfer detection
- [2026-01-22T10:36:00-05:00] 2a4b80e fix(subcategories): protect system subcategories from deletion
- [2026-01-22T10:35:00-05:00] fe0b54c fix(categories): protect Otros category from deletion
- [2026-01-22T10:34:00-05:00] b57c916 feat(transfers): classify incoming transfers under Income category
- [2026-01-22T10:33:00-05:00] e13bbc2 feat(seed): add transfer subcategory to Income category
- [2026-01-22T10:32:00-05:00] 4433200 feat(charts): add smart alignment for period comparison

## Completed in Current Phase (V1.1)

### Subfase 8.1: Infraestructura Base ✅
- **Modelo InboxDraft** - SwiftData model con campos para draft, metadatos de origen, confianza por campo, estado y validación
- **Enums** - DraftSourceType (voice, receiptPhoto, screenshotList, screenshotSingle, emailAlert) y DraftStatus (pending, approved, rejected)
- **InboxView** - Vista de bandeja con filtros (Pendientes/Archivados), lista de drafts, swipe to delete, empty states
- **InboxDraftRowView** - Celda con icono de fuente, nota, indicadores de campos faltantes, fecha relativa, monto con indicador de confianza
- **Navegación** - Botón en PanelView toolbar (lado izquierdo) con badge de contador de pendientes
- **Localizaciones** - 12 keys en 6 idiomas (es, en, de, fr, it, pt)
- **Registro en ModelContainer** - InboxDraft añadido al schema en NetoApp.swift

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

### Subfase 8.2: Edición y Aprobación (En progreso)

- [ ] Sheet de edición rápida (InboxDraftEditSheet)
- [ ] Validación de campos requeridos (account, amount, subcategory)
- [ ] Flujo de aprobación → crear TransactionItem
- [ ] Acciones en lote (asignar cuenta, subcategoría, aprobar, eliminar)
- [ ] Localizaciones en 6 idiomas
- [ ] QA-SCENARIOS.md actualizado

### Subfases siguientes (Fase 8)

- **8.3: Voz MVP** - OpenAI SDK, STT, LLM parser
- **8.4: Imágenes MVP** - OCR Vision, clasificación, extractores
- **8.5: Merchant Memory** - Canonicalización, sugerencias
- **8.6: Refinamiento** - Sistema confianza, fallbacks
- **8.7: Cloud Fallback** - (Opcional) AWS/GCP para recibos

---

### V1.0 Completado (Archivado)

V1.0 fue completada el 2026-01-21 y está en TestFlight. Incluye:
- Fases 1-7.1 completadas
- Fase 7: Beta Preparation con todas las subfases (7.1-7.8)
- Bugfixes TestFlight Ronda 1 y 2
- Ver detalles en commits de branch `1.0`

## Parking Lot

### Ideas Capturadas

- **2026-01-21 [Feature] [Business Logic] [Low]: Split de transacción (1.1)**
  Contexto: Funcionalidad aparte para dividir una transacción en múltiples partes
  Estado: Por definir, no está claro el alcance ni implementación
  Dependencias: Por determinar cuando se defina el alcance

### Notas Técnicas

(Items movidos a Fase 5.1)

- `iconName` en Tag tiene default `"tag.fill"` para migración
- `TagsPieWidget` sigue patrón de CategoriesPieWidget/SubcategoriesPieWidget
- Sincronización bidireccional pie ↔ filtros usa flag `isSyncingFilters`
- Tags existentes migran automáticamente con icono por defecto
- Design System (DS) en `DesignTokens.swift` con: Spacing, Radius, FormRow, ListRow, Typography
- SwiftData N:N requiere `@Relationship(inverse:)` explícito en un lado; arrays sin inverse se tratan como 1:N

## Session Continuity

Last session: 2026-01-22
Stopped at: Subfase 8.1 completada, iniciando 8.2
Next step: Implementar Subfase 8.2 (Edición y Aprobación)
Resume file: .claude/sessions/2026-01-22-131941.log
Resume context:
- Subfase 8.1 (Infraestructura Base) completada
- InboxDraft model, InboxView, InboxDraftRowView implementados
- Navegación desde PanelView con badge funcionando
- Localizaciones completas en 6 idiomas

## Referencias

- Spec Fase 8: .planning/PHASE8-REGISTRO-SPEC.md
- ROADMAP: .planning/ROADMAP.md (Fases 8-9 para V1.1)
