# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 8 — Registro Inteligente (V1.1)

## Current Position

Version: 1.1 (en desarrollo)
Phase: 8 of 9 en V1.1 (Registro Inteligente)
Spec: .planning/PHASE8-REGISTRO-SPEC.md
Plan: In progress
Status: Subfase 8.1 completada — Infraestructura base de Inbox
Last activity: 2026-01-20 — Subfase 8.1 completada (InboxDraft model, InboxView, navegación)

Progress: █░░░░░░░░░░░░░░░ 10% (Fase 8 - Subfase 8.1 completada)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-01-20T17:00:00-05:00] 5597718 feat(inbox): add InboxDraft model and basic inbox UI (Subfase 8.1)
- [2026-01-20T14:52:00-05:00] 220e8ad chore(qa): add test CSV files for import testing
- [2026-01-20T14:51:00-05:00] 416bbd9 docs(qa): rewrite QA-SCENARIOS.md with exhaustive coverage
- [2026-01-20T11:40:00-05:00] 90c083f fix(persistence): add error handling for SwiftData save/delete operations
- [2026-01-20T11:30:00-05:00] f6cd20a feat(currency): expand to 7 currencies with settings UI
- [2026-01-20T11:28:00-05:00] d7c5ce7 feat(onboarding): add first-time setup flow with currency selection
- [2026-01-20T11:26:00-05:00] b8e1d43 feat(widgets): add InfoHintButton with toggle and empty states
- [2026-01-20T11:24:00-05:00] af9896c feat(ui): add FilterBlockedPopover component
- [2026-01-20T11:22:00-05:00] 016261e fix(ui): standardize empty state icons across app
- [2026-01-20T07:30:00-05:00] fa7c052 feat(i18n): add 4 currencies and fix hardcoded strings

## Completed in Current Phase

- **Subfase 8.1: Infraestructura Base** - InboxDraft model con enums, InboxView con filtros, InboxDraftRowView, badge en PanelView, localizaciones 6 idiomas

### Fase 7 (archivado - V1.0)
- **Subfase 7.1: Code Quality & Cleanup** - TODOs eliminados, código muerto limpiado, referencias legacy (FIN-XX) removidas, 0 warnings
- **Subfase 7.2: Performance & Optimización** - Auditoría de código OK (N+1, lazy loading, memory leaks)
- **Subfase 7.3: Localizaciones y Monedas** - 7 monedas (PEN, USD, EUR, MXN, COP, BRL, GBP), strings hardcodeados corregidos
- **Subfase 7.4: Testing & QA** - QA-SCENARIOS.md exhaustivo (15 secciones, ~120 escenarios, ~250 validaciones), CSVs de prueba para import (7 archivos)
- **Subfase 7.5: UX para Nuevos Usuarios** - Empty states estandarizados, InfoHintButton en 12 widgets con toggle, FilterBlockedPopover, empty states en TrendsTabView
- **Subfase 7.7: Estabilidad Pre-Release** - Error handling en persistencia (13 try? → do/catch con alertas), validaciones auditadas OK
- **Subfase 7.8: Primer Uso y Onboarding** - Onboarding 4 pasos (nombre, moneda, secundarias, periodo), 7 monedas, sección divisas secundarias en Settings
- **Subfase 7.6: App Store Preparation** - Metadata completa (6 idiomas), descripciones, keywords, Privacy Policy (ES+EN). Screenshots pendientes (trabajo manual en Xcode)

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

### Fase 8: Registro Inteligente (V1.1)

**Subfase 8.1: Infraestructura Base** ✅
- [x] Modelo InboxDraft (SwiftData)
- [x] Vista de bandeja (lista, filtros, badge)
- [x] Acciones básicas (ver detalle, eliminar)
- [x] Navegación desde Panel toolbar

**Subfase 8.2: Edición y Aprobación** ← Siguiente
- [ ] Sheet de edición rápida
- [ ] Validación de campos requeridos
- [ ] Flujo de aprobación → crear TransactionItem
- [ ] Acciones en lote

**Subfase 8.3: Voz (MVP)**
- [ ] Integración OpenAI SDK
- [ ] STT con gpt-4o-mini-transcribe
- [ ] LLM parser básico
- [ ] Configuración de idioma en Settings

**Subfase 8.4: Imágenes (MVP)**
- [ ] Pipeline OCR con Vision
- [ ] Clasificación heurística
- [ ] Extractor ScreenshotSingle
- [ ] Extractor ScreenshotList básico

**Subfase 8.5: Merchant Memory**
- [ ] Modelo MerchantMemory
- [ ] Canonicalización
- [ ] Actualización al aprobar
- [ ] Sugerencia de subcategoría

**Subfase 8.6: Refinamiento**
- [ ] Sistema de confianza completo
- [ ] Fallback STT premium
- [ ] Extractor ReceiptPhoto
- [ ] Métricas locales

**Subfase 8.7: Cloud Fallback (Opcional)**
- [ ] Investigar proveedor (AWS vs GCP)
- [ ] Implementar fallback cloud para recibos
- [ ] Configuración de privacidad

## Parking Lot

(Items movidos a Fase 5.1)

- `iconName` en Tag tiene default `"tag.fill"` para migración
- `TagsPieWidget` sigue patrón de CategoriesPieWidget/SubcategoriesPieWidget
- Sincronización bidireccional pie ↔ filtros usa flag `isSyncingFilters`
- Tags existentes migran automáticamente con icono por defecto
- Design System (DS) en `DesignTokens.swift` con: Spacing, Radius, FormRow, ListRow, Typography
- SwiftData N:N requiere `@Relationship(inverse:)` explícito en un lado; arrays sin inverse se tratan como 1:N

## Fixes Pendientes V1.0

**[URGENTE] Edición masiva de transacciones**
- UI de selección existe pero funcionalidad no implementada
- Ubicación: RecordsTabView (modo selección)
- Pendiente: acciones de edición masiva (cambiar categoría, cuenta, eliminar, etc.)

## Session Continuity

Last session: 2026-01-20
Stopped at: Subfase 8.1 completada — Pausado para fix urgente en 1.0
Next step: Fix edición masiva en 1.0, luego retomar Subfase 8.2
Resume file: None

## V1.1 (Futuro)

Registro Inteligente y Plataforma diferidos. Ver:
- .planning/PHASE8-REGISTRO-SPEC.md
- ROADMAP.md (Fases 8-9)
