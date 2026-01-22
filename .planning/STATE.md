# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** V1.1 Desarrollo — Fase 8: Registro Inteligente

## Current Position

Version: 1.1 (IN DEVELOPMENT)
Phase: 8 - Registro Inteligente (Subfase 8.1 ✅, 8.2 ✅, 8.3 ✅, siguiente: 8.4)
Spec: .planning/PHASE8-REGISTRO-SPEC.md
Plan: In progress
Status: **V1.1 en desarrollo** — Voz MVP completado, siguiente: Imágenes MVP
Last activity: 2026-01-22 — Subfase 8.3 completada

Progress: ███░░░░░░░░░░░ 25% (V1.1 - Fase 8 en progreso)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-01-22T18:08:00-05:00] 41ac5d3 feat(voice): add smart entity extraction and improved instructions UI
- [2026-01-22T17:10:00-05:00] 58aab0f feat(import): add XLSX file support for transaction import
- [2026-01-22T17:03:00-05:00] 3fc8428 feat(voice): add voice recording UI and complete input flow
- [2026-01-22T16:55:00-05:00] a070ac1 fix(panel): remove duplicate onChange handlers
- [2026-01-22T16:54:00-05:00] 6482862 feat(voice): add voice input toggle and conditional FAB menu
- [2026-01-22T16:40:00-05:00] 1cac316 feat(settings): add voice language preference in personalization
- [2026-01-22T16:30:00-05:00] bd67105 feat(voice): add OpenAI integration for voice transcription
- [2026-01-22T14:25:00-05:00] cbe38f8 docs: update state and QA for inbox subfase 8.2
- [2026-01-22T14:24:00-05:00] d557621 chore(l10n): add inbox localization keys in 6 languages
- [2026-01-22T14:23:00-05:00] 62d32dd feat(inbox): add draft editing and bulk actions

## Completed in Current Phase (V1.1)

### Subfase 8.1: Infraestructura Base ✅
- **Modelo InboxDraft** - SwiftData model con campos para draft, metadatos de origen, confianza por campo, estado y validación
- **Enums** - DraftSourceType (voice, receiptPhoto, screenshotList, screenshotSingle, emailAlert) y DraftStatus (pending, approved, rejected)
- **InboxView** - Vista de bandeja con filtros (Pendientes/Archivados), lista de drafts, swipe to delete, empty states
- **InboxDraftRowView** - Celda con icono de fuente, nota, indicadores de campos faltantes, fecha relativa, monto con indicador de confianza
- **Navegación** - Botón en PanelView toolbar (lado izquierdo) con badge de contador de pendientes
- **Localizaciones** - 12 keys en 6 idiomas (es, en, de, fr, it, pt)
- **Registro en ModelContainer** - InboxDraft añadido al schema en NetoApp.swift

### Subfase 8.2: Edición y Aprobación ✅
- **InboxDraftEditSheet** - Formulario de edición con mismo diseño que NewTransactionView, prefilled desde draft
- **Flujo de aprobación** - Validación de campos requeridos (account, amount, subcategory), crea TransactionItem
- **Swipe actions** - Swipe right to approve (drafts válidos), swipe left to delete
- **Modo selección múltiple** - Selection circles, barra de selección con contador
- **InboxBulkActionsSheet** - Acciones en lote: asignar cuenta, subcategoría, aprobar válidos, eliminar
- **Localizaciones** - 13 nuevas keys en 6 idiomas
- **QA-SCENARIOS** - Sección 16 con 29 escenarios de prueba

### Subfase 8.3: Voz MVP ✅
- **OpenAI SDK** - MacPaw/OpenAI v0.4.7 integrado via Swift Package Manager
- **API Key segura** - xcconfig con Secrets.xcconfig (git-ignored), APIKeyService lee desde Info.plist
- **VoiceTranscriptionService** - Whisper STT a 16kHz, VoiceLanguage enum (system/es/en)
- **TranscriptionParserService** - GPT-4o-mini extrae amount, date, note, isExpense con confidence scores
- **AudioRecorderService** - AVAudioRecorder en m4a mono, permisos micrófono, estados (idle/recording/processing)
- **VoiceRecordingView** - UI con círculo pulsante, duración en tiempo real, estados de procesamiento
- **Toggle en ProfileView** - "Entrada por voz con IA" con selector de idioma inline
- **FAB condicional** - Menu Voz/Manual en PanelView y DetailContainerView cuando voice está habilitado
- **Flujo completo** - Grabar → Transcribir → Parsear → Crear InboxDraft con confidence
- **Localizaciones** - 9 nuevas keys voice.* en 6 idiomas

### Mejoras adicionales (V1.1)
- **Importación XLSX** - Soporte para archivos Excel (.xlsx) además de CSV
  - XLSXReader usando CoreXLSX para parsear primera hoja
  - Tipos genéricos (ImportError, ImportColumn, TransactionImportResult) compartidos
  - RawImportRow struct y validateAndCreateDraft() para validación compartida
  - importXLSX() e importXLSXMultiCurrency() métodos
  - scanCurrenciesFromFile() detecta monedas en ambos formatos
  - ImportIntroSheet acepta UTType.spreadsheet

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

### Subfase 8.4: Imágenes MVP (Siguiente)

- [ ] OCR con Vision API (OpenAI)
- [ ] Clasificación de imágenes (recibo, screenshot lista, screenshot individual)
- [ ] Extractores especializados por tipo de imagen
- [ ] Crear InboxDraft(s) desde imagen
- [ ] UI para capturar/seleccionar foto

### Subfases siguientes (Fase 8)

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
Stopped at: Subfase 8.3 completada
Next step: Implementar Subfase 8.4 (Imágenes MVP)
Resume context:
- Subfase 8.3 (Voz MVP) completada
- OpenAI SDK integrado, API key via xcconfig
- VoiceTranscriptionService (Whisper) y TranscriptionParserService (GPT-4o-mini)
- AudioRecorderService y VoiceRecordingView implementados
- FAB condicional en PanelView y DetailContainerView
- Flujo completo: grabar → transcribir → parsear → InboxDraft

## Referencias

- Spec Fase 8: .planning/PHASE8-REGISTRO-SPEC.md
- ROADMAP: .planning/ROADMAP.md (Fases 8-9 para V1.1)
