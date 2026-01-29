# Progreso Refactoring Arquitectural

**Inicio:** 2026-01-29
**Objetivo:** Mejorar testabilidad y separación de capas

## Estado Actual

**Fase:** A - Servicios Stateless → @Environment
**Incremento:** A.1 - CurrencyConverter
**Status:** 🔄 En progreso

## Resumen de Fases

| Fase | Descripción | Incrementos | Estado |
|------|-------------|-------------|--------|
| A | Singletons → @Environment | 3 | ✅ Completada |
| B | SessionState consistente | 2 | ✅ Completada |
| C | Services para ModelContext | 3 | ⏳ Pendiente |
| D | @Query → ViewModels | 7 | ⏳ Pendiente |

## Fase A: Servicios Stateless → @Environment

### A.1: CurrencyConverter (33 usos en 17 archivos)
- **Estado:** ✅ Completado (e095c93)
- **Views migradas:** InboxDraftEditSheet, InboxBulkActionsSheet, InboxView, CurrencySettingsView
- **Nota:** Services/ViewModels siguen usando .shared (backward compatible)
- **Archivos a modificar:**
  - [ ] `CurrencyConverter.swift` - Agregar @Observable, remover .shared
  - [ ] `YalaApp.swift` - Agregar .environment(CurrencyConverter())
  - [ ] 17 archivos que usan CurrencyConverter.shared

**Patrón de cambio:**
```swift
// ANTES
CurrencyConverter.shared.convert(...)

// DESPUÉS
@Environment(CurrencyConverter.self) private var currencyConverter
currencyConverter.convert(...)
```

### A.2: ExchangeRateService (16 usos)
- **Estado:** ✅ Completado (451f1dd)
- **Views migradas:** ImportIntroSheet, UserDataResetView, CurrencySettingsView
- **Nota:** Services/ViewModels siguen usando .shared (backward compatible)

### A.3: Vision/Voice Services (3 usos)
- **Estado:** ✅ Completado (d955c88)
- **Services migrados:** ImageVisionService, VoiceTranscriptionService, TranscriptionParserService
- **Views migradas:** ImageSelectionView, VoiceRecordingView
- **Nota:** lazy var → @ObservationIgnored manual cache

## Fase B: SessionState.shared → @Environment

### B.1: Widget refresh flags (5 Views)
- **Estado:** ✅ Completado (c19f0e8)
- **Views migradas:** ImportIntroSheet, UserDataResetView, BudgetsFavoritesSettingsView, BudgetEditorView, PersonalizationSettingsView

### B.2: Otros accesos (2 Views)
- **Estado:** ✅ Completado (c19f0e8)
- **Views migradas:** OnboardingView, StatisticsView

## Fase C: Services para ModelContext

### C.1: DraftService
- **Estado:** ✅ Completado
- **Archivos creados:** `Yala/Services/DraftService.swift`
- **Views migradas:** InboxView, InboxBulkActionsSheet, InboxDraftEditSheet
- **Nota:** VoiceRecordingView e ImageSelectionView siguen usando lógica inline por complejidad adicional (Merchant Memory, OCR processing)

### C.2: EntityDeletionService
- **Estado:** ⏳ Pendiente

### C.3: TransactionService
- **Estado:** ⏳ Pendiente

## Fase D: @Query → ViewModels

### D.1-D.7: 48 Views total
- **Estado:** ⏳ Pendiente

## Commits Realizados

(Se actualiza automáticamente)

## Notas Técnicas

- CurrencyConverter es stateless, ideal para @Environment
- Mantener backward compatibility durante migración
- Verificar que no hay dependencias circulares
