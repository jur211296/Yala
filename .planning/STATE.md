# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** V1.0 Release Complete — Listo para TestFlight

## Current Position

Version: 1.0 (RELEASE READY)
Phase: 7.1 of 7.1 en V1.0 (Acciones Rápidas en Transacciones) ✅ COMPLETADA
Spec: None
Plan: Complete
Status: **V1.0 en TestFlight** — Soporte XLSX completo agregado
Last activity: 2026-01-24 — Soporte XLSX (6 commits): import fecha fix, XLSXWriter, plantilla XLSX, export XLSX

Progress: ██████████████ 100% (V1.0 Completa)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-01-25] 0a203f0 feat(voice,image): add specific error handling with user actions
- [2026-01-25] 8b4f8cb feat(voice,inbox): UX refinements for draft flow
- [2026-01-25] fbff205 feat(image): redesign image flow with preview countdown and unified styling
- [2026-01-25] 70b05ab feat(inbox): add success screens after approving drafts
- [2026-01-25] 38a2b62 feat(inbox): add expandable rawText in draft edit sheet
- [2026-01-25] 7b65b05 feat(image): add result screen with transaction count before navigation
- [2026-01-25] d3e8c17 feat(inbox): navigate to Inbox when closing draft edit sheet
- [2026-01-25] 49c7abc feat(inbox): add validation message and capsule buttons in edit sheet
- [2026-01-25] f2040bd chore: improve commit-one to update work documents and mark 6.3 complete
- [2026-01-25] 1312846 feat(inbox): add discard changes confirmation when closing edit sheet

## Completed in Current Phase

- **Subfase 7.1: Code Quality & Cleanup** - TODOs eliminados, código muerto limpiado, referencias legacy (FIN-XX) removidas, 0 warnings
- **Subfase 7.2: Performance & Optimización** - Auditoría de código OK (N+1, lazy loading, memory leaks)
- **Subfase 7.3: Localizaciones y Monedas** - 7 monedas (PEN, USD, EUR, MXN, COP, BRL, GBP), strings hardcodeados corregidos
- **Subfase 7.4: Testing & QA** - QA-SCENARIOS.md exhaustivo (15 secciones, ~120 escenarios, ~250 validaciones), CSVs de prueba para import (7 archivos)
- **Subfase 7.5: UX para Nuevos Usuarios** - Empty states estandarizados, InfoHintButton en 12 widgets con toggle, FilterBlockedPopover, empty states en TrendsTabView
- **Subfase 7.7: Estabilidad Pre-Release** - Error handling en persistencia (13 try? → do/catch con alertas), validaciones auditadas OK
- **Subfase 7.8: Primer Uso y Onboarding** - Onboarding 4 pasos (nombre, moneda, secundarias, periodo), 7 monedas, sección divisas secundarias en Settings
- **Fix urgente: Edición masiva** - BulkEditSheet completo con 5 opciones (cuenta, subcategoría, tags, nota, monto), barra de selección rediseñada estilo iOS 18, métodos bulk update en RecordsViewModel, localizaciones en 6 idiomas, 9 escenarios QA nuevos
- **Subfase 7.6: App Store Preparation** - Metadata en 6 idiomas (nombre, subtitle, keywords, descripción completa), Privacy Policy (ES/EN), demo-data.csv para screenshots; documentado en .planning/appstore/
- **Bugfixes TestFlight V1.0** - Subcategorías recientes de 4→8, icono correcto en TagSelectorSheet, estilos consistentes en tag selector de quick actions, DatePicker save button fix, localización de tipo transacción en success view
- **Fase 7.1: Acciones Rápidas en Transacciones** - Barra de 4 botones (duplicar, eliminar, favorito, recurrente) debajo del monto en NewTransactionView; duplicar crea nueva transacción con datos prefilled; eliminar con confirmación; guardar como favorito/recurrente con alerts y toasts; localizaciones completas en 6 idiomas; 7 escenarios QA nuevos
- **Bugfixes TestFlight Ronda 2** - SSOT para filtros, smart alignment para gráficas comparativas, clasificación correcta de transferencias (entrantes a Ingresos, salientes a Otros), protección de categorías/subcategorías del sistema, migración automática de transferencias existentes, 4 escenarios QA nuevos
- **Soporte XLSX completo** - Fix importación de fechas Excel (números seriales a ISO), XLSXWriter para crear archivos Excel usando ZIPFoundation, descarga de plantilla en CSV o XLSX, exportación de datos en CSV o XLSX, localizaciones actualizadas en 6 idiomas
- **Subfase 8.4: Imágenes MVP** - Toggle imagen input en Settings, opción FAB imagen (naranja), ImageSelectionView con PhotosPicker, Vision OCR (VNRecognizeTextRequest), clasificador heurístico (screenshotSingle/List/receiptPhoto), AmountParser ($€£, europeo/americano, negativos), DateParser (relativas/absolutas), ScreenshotSingleExtractor (alertas bancarias), RowClusterer + ScreenshotListExtractor (listas de transacciones), navegación automática a Inbox, localizaciones en 6 idiomas, 40 escenarios QA (Sección 18)

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
  - Shared/: YalaEmptyState, YalaBadge, StandardButtons, YalaLoadingOverlay, SectionBox, CurrencySelectorView, IconColorPickerSheet, SkeletonView
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

### Mejoras Vision API + Inbox (pendiente de refinamiento)

Implementación base completada (d9cfe97). Mejoras pendientes para próxima sesión:
- [ ] Testing manual con imágenes reales de diferentes bancos
- [ ] Ajustar prompt de Vision para mejor precisión en fechas relativas
- [ ] Considerar fallback cuando Vision no detecta currency
- [ ] UX: feedback visual mientras procesa imagen
- [ ] Edge cases: qué pasa si InboxDraftEditSheet se cierra sin guardar

---

### Fase 7.1: Acciones Rápidas en Transacciones ✅ COMPLETADA

- [x] UI Base: Barra de acciones debajo del monto (4 botones con iconos)
- [x] Duplicar: Crea copia de transacción actual (solo edición)
- [x] Eliminar: Elimina con confirmación (solo edición)
- [x] Guardar como favorito: Crea FavoritePayment desde transacción
- [x] Guardar como recurrente: Crea ScheduledPayment desde transacción
- [x] Localizaciones en 6 idiomas
- [x] QA-SCENARIOS.md actualizado con 7 escenarios nuevos

---

### Bugs TestFlight V1.0 - Ronda 2 (2026-01-21)

| # | Bug | Complejidad | Estado |
|---|-----|-------------|--------|
| 1 | Gráfica naturaleza en CategoriesTabView no filtra por categoría/subcategoría | Media | ✅ Completado (0c0b938) |
| 2 | Comparativa vs periodo anterior - fechas descuadradas | Media-Alta | ✅ Completado (4433200) |
| 3 | Transferencias entrantes no se ven como ingreso en registros | Alta | ✅ Completado (b57c916) |
| 4 | Saldo en RecordsTabView no cuadra con diferencia ingresos-egresos | Media | ✅ Completado (implícito con Bug 3) |
| 5 | Preferencias widgets default desactualizadas | Baja | ✅ Completado (7fdb536) |

**Todos los bugs de Ronda 2 completados.** La app está lista para validación manual.

---

### Post V1.0 — Opciones

1. Resolver bugs Ronda 2 arriba
2. Capturar screenshots manuales con demo-data.csv
3. Iniciar V1.1 (Fase 8: Registro Inteligente)

---

### Fase 7: Beta Preparation (V1.0 Release) ✅ COMPLETADA

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

**Subfase 7.6: App Store Preparation** ✅
- [x] Metadata en 6 idiomas (nombre, subtitle, keywords, descripción)
- [x] Privacy Policy (ES/EN)
- [x] demo-data.csv para screenshots
- [x] Documentado en .planning/appstore/
- [ ] Screenshots (pendiente - captura manual en Xcode)

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

Last session: 2026-01-25
Stopped at: Error handling completo para voz e imagen (commit 0a203f0)
Next step: Items pendientes de REFINAMIENTO: 2.4 múltiples drafts voz, 3.5 selección múltiple imágenes, UI polish (10.x)
Resume file: N/A
Resume context:
- Errores completados: API key, permisos micrófono, sin conexión, imagen corrupta
- NetworkMonitor.swift nuevo para detectar conectividad
- Botones de acción según tipo de error (Settings, Retry, Usar imagen)
- Localizaciones en 6 idiomas para todos los errores
- REFINAMIENTO-8.3-8.4.md sección 9 completada

## V1.1 (Futuro)

Registro Inteligente y Plataforma diferidos. Ver:
- .planning/PHASE8-REGISTRO-SPEC.md
- ROADMAP.md (Fases 8-9)
